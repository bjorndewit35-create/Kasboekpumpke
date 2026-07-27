-- =========================================================================
-- Kasboek Pumpke — databaseschema (PostgreSQL / Supabase)
--
-- Dit is een momentopname ter documentatie. De app draait in Lovable; daar
-- staan de migraties. Zie docs/rekenregels.md voor de betekenis van de velden.
-- =========================================================================

-- ---- Soorten -------------------------------------------------------------

CREATE TYPE public.app_role AS ENUM ('owner', 'accountant');

-- Hoe iets betaald is. Bepaalt of een boeking de kassalade raakt.
CREATE TYPE public.payment_method AS ENUM
  ('cash', 'pin', 'card', 'voucher', 'invoice', 'other');

-- Soorten boekingen.
--   income               omzet (bepaalt de BTW)
--   cashless_settlement  het niet-contante deel van de omzet; haalt geld uit de la
--   expense              uitgave
--   cash_in / cash_out   losse kasmutatie, o.a. het kasverschil bij afsluiten
--   cash_to_vault        van de kassalade naar de kluis (afromen)
--   vault_to_bank        van de kluis naar de bank (afstorten)
--   vault_to_cash        terug uit de kluis naar de kassalade (wisselgeld)
CREATE TYPE public.tx_type AS ENUM (
  'income', 'expense', 'cash_in', 'cash_out',
  'cash_to_vault', 'vault_to_bank', 'vault_to_cash',
  'cashless_settlement'
);

-- ---- Zaak ----------------------------------------------------------------

CREATE TABLE public.businesses (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                      text NOT NULL,
  -- Wisselgeld waarmee de allereerste dag start.
  default_opening_balance   numeric(10,2) NOT NULL DEFAULT 250,
  -- Lopend kluissaldo, bijgehouden door de trigger apply_vault_movement().
  vault_balance             numeric(12,2) NOT NULL DEFAULT 0,
  -- Uur waarop de horeca-dag begint. Een boeking om 01:30 valt bij dagstart 5
  -- op de avond ervoor.
  day_start_hour            smallint NOT NULL DEFAULT 5
                              CHECK (day_start_hour BETWEEN 0 AND 12),
  -- Vanaf welk kasverschil de app waarschuwt en om uitleg vraagt.
  cash_difference_threshold numeric(10,2) NOT NULL DEFAULT 5,
  created_at                timestamptz NOT NULL DEFAULT now()
);

-- ---- Gebruikers en rollen ------------------------------------------------

CREATE TABLE public.profiles (
  id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id  uuid REFERENCES public.businesses(id) ON DELETE SET NULL,
  display_name text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_roles (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  role        public.app_role NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, business_id, role)
);

-- ---- Categorieën ---------------------------------------------------------

CREATE TABLE public.categories (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id      uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name             text NOT NULL,
  kind             public.tx_type NOT NULL,
  default_vat_rate numeric(5,2) NOT NULL DEFAULT 21,
  sort_order       int NOT NULL DEFAULT 0,
  archived         boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- ---- Dagen ---------------------------------------------------------------

CREATE TABLE public.days (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  date            date NOT NULL,
  opening_balance numeric(12,2) NOT NULL DEFAULT 0,
  expected_close  numeric(12,2),   -- beginsaldo + alle kaseffecten
  counted_close   numeric(12,2),   -- wat er werkelijk geteld is
  difference      numeric(12,2),   -- geteld − verwacht
  -- Wat er na het afromen in de la blijft. Dit is morgen het beginsaldo,
  -- zodat het kasboek onafgebroken doorloopt.
  carry_over      numeric(12,2),
  count_breakdown jsonb,           -- de coupure-telling, voor als een verschil
                                   -- later uitgezocht moet worden
  closed_at       timestamptz,
  closed_by       uuid REFERENCES auth.users(id),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, date)
);

CREATE INDEX days_business_date_idx ON public.days (business_id, date DESC);

-- ---- Boekingen -----------------------------------------------------------

CREATE TABLE public.transactions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id    uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  day_id         uuid NOT NULL REFERENCES public.days(id) ON DELETE RESTRICT,
  type           public.tx_type NOT NULL,
  -- Leeg bij omzetregels uit de Z-bon: die bon geeft de omzet per BTW-tarief
  -- en het pintotaal, maar niet welk deel van het pinbedrag bij welk tarief
  -- hoort. Die verdeling is niet te weten en wordt dus niet verzonnen.
  payment_method public.payment_method,
  category_id    uuid REFERENCES public.categories(id),
  amount_gross   numeric(12,2) NOT NULL,
  vat_rate       numeric(5,2) NOT NULL DEFAULT 0,
  vat_amount     numeric(12,2) NOT NULL DEFAULT 0,
  amount_net     numeric(12,2) NOT NULL,
  -- Aangemaakt door het dagomzet-scherm. Deze regels worden bij het opnieuw
  -- invoeren van de Z-bon vervangen (zie replace_day_revenue).
  is_day_revenue boolean NOT NULL DEFAULT false,
  bank_ref       text,          -- sealbagnummer bij een afstorting
  value_date     date,          -- stortdatum
  confirmed_at   timestamptz,   -- afgevinkt tegen het bankafschrift
  note           text,
  receipt_path   text,
  is_correction  boolean NOT NULL DEFAULT false,
  correction_of  uuid REFERENCES public.transactions(id),
  -- Bewaarplicht: een boeking wordt nooit echt verwijderd, alleen doorgehaald
  -- met een reden erbij.
  voided_at      timestamptz,
  voided_by      uuid REFERENCES auth.users(id),
  voided_reason  text,
  created_by     uuid NOT NULL REFERENCES auth.users(id),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX transactions_business_day_idx  ON public.transactions (business_id, day_id);
CREATE INDEX transactions_day_revenue_idx   ON public.transactions (business_id, day_id)
  WHERE is_day_revenue;

-- ---- Rechten -------------------------------------------------------------
--
-- RLS staat aan op alle tabellen. Leden van een zaak mogen lezen; schrijven
-- gaat via serverfuncties die de rol controleren. De helperfuncties zijn
-- SECURITY DEFINER en niet aanroepbaar voor anon.

ALTER TABLE public.businesses   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.days         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.is_member(_business_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND business_id = _business_id
  )
$$;

CREATE FUNCTION public.has_role(_user_id uuid, _business_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND business_id = _business_id AND role = _role
  )
$$;

CREATE FUNCTION public.current_business_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT business_id FROM public.profiles WHERE id = auth.uid()
$$;

-- Voorbeeld van het patroon dat voor elke tabel geldt:
CREATE POLICY "members view transactions" ON public.transactions
  FOR SELECT TO authenticated USING (public.is_member(business_id));

-- ---- Automatismen --------------------------------------------------------

-- Nieuw account -> profielregel.
CREATE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email));
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Nieuwe zaak -> standaardcategorieën voor een Nederlandse horecazaak
-- (omzet keuken 9 %, dranken 21 %, fooi 0 %, inkoop, schoonmaak, enz.).
CREATE TRIGGER seed_categories_on_business_create
  AFTER INSERT ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.seed_default_categories();

-- Houdt businesses.vault_balance bij: cash_to_vault erbij, vault_to_bank en
-- vault_to_cash eraf. Draait het effect terug als een regel wordt doorgehaald.
CREATE TRIGGER trg_apply_vault_movement
  AFTER INSERT OR UPDATE OR DELETE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.apply_vault_movement();

-- Controle: rekent het kluissaldo opnieuw uit vanuit de boekingen en geeft het
-- verschil met de opgeslagen teller. Een lopend saldo dat alleen door een
-- trigger wordt bijgehouden is niet te verifiëren als het ooit uit de pas
-- loopt — bij geld wil je dat wel kunnen nakijken.
CREATE FUNCTION public.vault_balance_check(_business_id uuid)
RETURNS TABLE (stored numeric, computed numeric, diff numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ ... $$;

-- Vervangt de dagomzet van één dag in één transactie: eerst de bestaande
-- is_day_revenue-regels weg, dan de nieuwe erin. Zo kan een correctie nooit
-- half slagen en kunnen bedragen niet stapelen.
CREATE FUNCTION public.replace_day_revenue(
  _business_id uuid, _day_id uuid, _created_by uuid, _rows jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$ ... $$;

-- ---- Opslag --------------------------------------------------------------
-- Bucket 'receipts' (niet publiek) voor bonfoto's. Pad: <business_id>/<...>,
-- leesbaar en beschrijfbaar voor leden van diezelfde zaak.
