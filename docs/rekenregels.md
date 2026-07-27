# Rekenregels

Alle bedragen zijn inclusief BTW, tenzij anders vermeld. De app rekent in euro's met twee
decimalen.

## De formules

```
dagomzet          = omzet 9 % + omzet 21 % + omzet 0 %
contant ontvangen = dagomzet − pin − overig

contant in de la  = beginsaldo
                    + contant ontvangen
                    − contante uitgaven
                    − naar kluis
                    + uit kluis

kasverschil       = geteld − contant in de la
beginsaldo morgen = geteld − naar kluis

kluissaldo        = vorig kluissaldo + naar kluis − afstorting naar bank − terug naar kassa
```

"Overig" is alles wat niet contant en niet pin is: creditcard, cadeaubonnen, op rekening.

## Waarom omzet en betaalwijze apart staan

Een Z-bon geeft twee dingen die niet op elkaar te herleiden zijn:

1. de omzet **per BTW-tarief** — nodig voor de aangifte;
2. het **pintotaal** — nodig om te weten wat er in de la ligt.

Wat de bon níét geeft, is welk deel van het pinbedrag bij het lage en welk deel bij het
hoge tarief hoort. Die verdeling is niet te weten en mag dus ook niet verzonnen worden.

Daarom slaat de app twee soorten regels op:

- **omzetregels** — één per BTW-tarief. Deze bepalen de BTW-aangifte.
- **ontvangstregels** — één per niet-contante betaalwijze. Deze halen het niet-contante
  deel weer uit de kassalade.

Samen leveren ze het juiste kassaldo én de juiste BTW, zonder een verdeling te verzinnen
die er niet is.

## Wat raakt de kassalade

| Boeking | Effect op de la |
| --- | --- |
| Omzet (contant of onbekend gesplitst) | **+** bedrag |
| Niet-contante ontvangst (pin, creditcard, bon, op rekening) | **−** bedrag |
| Uitgave betaald met contant geld | **−** bedrag |
| Uitgave betaald met pin of bank | **geen** |
| Kasstorting / uit de kluis gehaald | **+** bedrag |
| Kasopname / naar de kluis gebracht | **−** bedrag |
| Afstorting van kluis naar bank | **geen** (raakt alleen de kluis) |

Een uitgave die met de bankpas is betaald, hoort dus wel in de boekhouding maar niet in de
kas. Dat onderscheid is het verschil tussen een kloppend en een niet-kloppend kasboek.

## Rekenvoorbeeld

Een gewone zaterdag:

| | |
| --- | --- |
| Beginsaldo (wisselgeld) | € 250,00 |
| Omzet 9 % (keuken) | € 300,00 |
| Omzet 21 % (dranken) | € 700,00 |
| **Dagomzet** | **€ 1.000,00** |
| Waarvan pin | € 600,00 |
| Waarvan overig (bonnen) | € 50,00 |
| **Contant ontvangen** | **€ 350,00** |
| Contante uitgave (bloemen) | € 40,00 |
| Uitgave met bankpas (schoonmaakmiddel) | € 25,00 |

```
contant in de la = 250 + 350 − 40 = € 560,00
```

De uitgave met de bankpas van € 25 telt wél mee in de kosten en de BTW, maar niet in de la.

Aan het eind van de avond wordt € 560 geteld — kasverschil € 0. Er gaat € 310 naar de
kluis, zodat er € 250 wisselgeld achterblijft:

```
beginsaldo morgen = 560 − 310 = € 250,00
kluissaldo        = vorig saldo + € 310,00
```

**Let op de volgorde.** Er wordt geteld vóór het afromen. Het kasverschil wordt bepaald op
de volle la; de kluisstorting gaat daar daarna vanaf. Andersom rekenen levert een
kasverschil op ter grootte van de kluisstorting, terwijl er in werkelijkheid niets mist.

## Een kasverschil is zelf ook een boeking

Blijkt er bij het tellen € 3 te weinig in de la te zitten, dan is dat geen getal dat alleen
op de dagstaat komt te staan — er wordt een boeking van gemaakt: een kasopname van € 3 met
de notitie "Kasverschil bij dagafsluiting".

Dat moet, anders lopen twee dingen uit elkaar. Zonder die boeking zeggen de transacties dat
er € 563 in de la hoort te liggen, terwijl de volgende dag opent met € 560. Dat gat staat
dan nergens verklaard. Mét die boeking geldt altijd:

```
beginsaldo + alle boekingen van de dag = geteld bedrag
geteld bedrag − naar kluis            = beginsaldo van morgen
```

Het grootboek en de dagstaat vertellen zo hetzelfde verhaal, en elk verschil is
terug te vinden als een regel met een reden erbij.

## De horeca-dag

De boekhouddag loopt niet van middernacht tot middernacht, maar begint op een instelbaar
uur (standaard 05:00). Een boeking om 01:30 hoort dus bij de avond ervoor — zoals een
dienst in de horeca ook loopt. De tijd wordt bepaald in de tijdzone `Europe/Amsterdam`,
dus zomer- en wintertijd gaan vanzelf goed.

## Aaneensluiten

Het beginsaldo van een nieuwe dag is het werkelijke restant van de vorige dag na afromen,
niet een vast wisselgeldbedrag. Zo loopt het kasboek onafgebroken door en verdwijnt een
telverschil nergens stilzwijgend. Alleen de allereerste dag start met het ingestelde
wisselgeldbedrag.

Een nieuwe dag kan pas beginnen als de vorige is afgesloten.

## Grenzen die de app bewaakt

- **Nooit negatief.** Een boeking die de kassalade onder nul zou brengen, wordt geweigerd.
  Er kan fysiek niet minder dan niets in een la zitten, en een negatieve kas is een
  klassieke rode vlag bij een controle.
- **Pin nooit groter dan de omzet.** Als pin plus overig de dagomzet overschrijdt, zou
  "contant ontvangen" negatief worden. Dat wordt geweigerd.
- **Kluis nooit negatief.** Je kunt niet meer afstorten dan er in de kluis ligt.
- **Kasverschil boven de drempel** (standaard € 5) wordt expliciet gemeld en vraagt om een
  opmerking.

## BTW

De BTW wordt uit het brutobedrag gerekend:

```
netto = bruto ÷ (1 + tarief)
btw   = bruto − netto
```

Voor de aangifte worden de omzetregels gegroepeerd per tarief:

| Tarief | Rubriek aangifte | Typisch |
| --- | --- | --- |
| 21 % | 1a | dranken, alcohol |
| 9 % | 1b | eten, logies |
| 0 % | — | fooi, doorlopende posten |
