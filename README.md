# Kasboek Pumpke

Digitaal kasboek voor de horecazaak. Vervangt het papieren kasboek: dagomzet invoeren,
uitgaven bijhouden, de kas tellen, geld naar de kluis brengen en afstorten naar de bank —
met een sluitende administratie voor de boekhouder en de Belastingdienst.

## Waar draait de app

De app is gebouwd in [Lovable](https://lovable.dev) en draait daar, met een
Supabase-database (PostgreSQL) erachter.

- **Project:** `Kasboek` (`914dded5-b6ef-4744-a9b7-d2cc108d61f4`)
- **Editor:** https://lovable.dev/projects/914dded5-b6ef-4744-a9b7-d2cc108d61f4
- **App:** https://id-preview--914dded5-b6ef-4744-a9b7-d2cc108d61f4.lovable.app

Deze repository bevat de documentatie: de rekenregels, het databaseschema en de
handleiding voor in de zaak. De applicatiecode staat in het Lovable-project.

## Wat de app doet

| Onderdeel | Toelichting |
| --- | --- |
| **Dagomzet** | Eén scherm per dag waarin de totalen van de Z-bon worden overgetypt, gesplitst naar BTW-tarief (9 % keuken, 21 % dranken). |
| **Waarvan pin** | Het pinbedrag en eventuele andere niet-contante ontvangsten worden apart ingevoerd. Alleen het contante deel komt in de kassalade terecht. |
| **Uitgaven** | Losse boekingen met bedrag, categorie, BTW en een foto van de bon. Per uitgave leg je vast of die contant, met pin of via de bank betaald is — alleen contante uitgaven halen geld uit de la. |
| **Restant cash saldo** | Het actuele bedrag in de kassalade, live meeberekend. |
| **Kluissaldo** | Een tweede "potje": wat er in de kluis ligt, met alle bewegingen erheen en vandaan. |
| **Afstorting naar bank** | Geld van de kluis naar de bank, met sealbagnummer en stortdatum, af te vinken zodra het op het bankafschrift staat. |
| **Dagafsluiting** | De kas tellen (met coupure-hulp), het kasverschil zien en de dag op slot zetten. |
| **Boekhouding** | Maandoverzicht met BTW-splitsing, Excel-export en een ZIP met alle bonnetjes. |

## Twee potjes, één geldstroom

```
       omzet (contant deel)
                │
                ▼
   ┌────────────────────────┐   afromen    ┌───────────┐   afstorten   ┌──────┐
   │      kassalade         │ ───────────► │   kluis   │ ────────────► │ bank │
   └────────────────────────┘              └───────────┘               └──────┘
        │            ▲                           │
        │            └───────────────────────────┘
        ▼                  wisselgeld terug
   contante uitgaven
```

Pinomzet gaat rechtstreeks naar de bank en raakt de kassalade dus nooit. Dat is precies
waarom de app onderscheid maakt tussen omzet en contante ontvangst.

## Documentatie

- [`docs/rekenregels.md`](docs/rekenregels.md) — alle formules, met voorbeelden
- [`docs/handleiding.md`](docs/handleiding.md) — één A4 voor achter de bar
- [`docs/schema.sql`](docs/schema.sql) — het volledige databaseschema

## Rollen

- **Eigenaar** — voert alles in, sluit dagen af, beheert instellingen en gebruikers.
- **Boekhouder** — leest mee, exporteert, en is de enige die een afgesloten dag nog kan
  corrigeren.

## Bewaarplicht

Een boeking wordt nooit echt verwijderd. Wie iets weghaalt, moet een reden opgeven; de
regel blijft zichtbaar als "verwijderd" met die reden erbij. Een afgesloten dag staat op
slot. Zo blijft de administratie controleerbaar.
