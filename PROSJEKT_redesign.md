# Redesign: fra administrasjonssystem til driftssystem

Analyse og design. Skrevet 2026-08-17. **Ingen kode ennå** — dette er punkt 17
i bestillingen.

---

## 0. Diagnosen

Forsiden ble redesignet 2026-08-13. Den er allerede oppmerksomhet-først:
signalmotoren (`src/lib/signaler.ts`) rangerer funn etter alvor, konsekvens og
varighet, og butikksjefen møter en prioritert liste, ikke et modulgalleri.

**Problemet er de 60 sidene bak den.**

Brukeren lander i en kommandosentral og faller deretter ned i et
administrasjonssystem. Målt på koden:

| Funn | Tall |
|---|---|
| Beskyttede sider | 61 |
| Sider som pakker alt i `.kort` | 57 |
| Sider som åpner med en tabell | 28 |
| Sider med sin egen stasjonsvelger | 19 |
| CSS-klasser i én fil, uten tokens | 478 |

`/ansatte` er hele diagnosen i én side: den åpner med skjemaet **Ny ansatt** —
den sjeldneste handlingen — og viser lista under. Databasen først, brukeren
etterpå.

Redesignet handler derfor ikke om forsiden. Det handler om å ta filosofien som
allerede er bevist der, og la den gjelde overalt.

---

## 1. Funksjonsinventar

61 beskyttede sider. Gruppert etter hva brukeren prøver å oppnå — ikke etter
dagens meny.

**Drive stasjonen i dag (11)**
`/oversikt` `/rutiner` `/rutiner/min` `/rutiner/oversikt` `/rutiner/oppsett`
`/rutiner/oppsett/[id]` `/sjekkpunkt` `/ikmat` `/ikmat/maaling` `/ikmat/oppsett`
`/oppgaver`

**Selge og produsere (9)**
`/produksjonsplan` `/produksjonsplan/treffsikkerhet` `/utsolgt` `/salg`
`/timesalg` `/salgsprognose` `/svinn` `/kampanjer` `/arrangementer`

**Penger og resultat (7)**
`/regnskap` `/analyse` `/lonn` `/kasserer` `/maaling` `/abonnement` `/avvik`

**Folk (14)**
`/ansatte` `/kontrakt` `/kontrakt/[id]` `/bemanning` `/opplaring` `/skills`
`/merker` `/konkurranser` `/premier` `/puls` `/puls/ny` `/puls/[id]`
`/puls/sporsmal` `/tilbakemeldinger`

**Kommunikasjon (5)**
`/fokus` `/meldinger` `/lederstotte` `/nyheter` `/varsler`

**Data inn og ut (4)**
`/import` `/dekning` `/avtalevokter` `/anvisninger`

**Oppsett og styring (6)**
`/stasjoner` `/brukere` `/persondata` `/mine-opplysninger` `/lenker` `/kunnskap`

**Plattform, egen rolle (5)**
`/plattform` `/trafikk` `/kampanjer` `/redaktor` `/kunnskap`

Ingen av disse skal forsvinne. Se punkt 10.

---

## 2. Rollene

| Rolle | Bruker systemet til | Enhet |
|---|---|---|
| `retailer_admin` (eier) | Sammenligne stasjoner, se penger, styre oppsett | Desktop |
| `butikksjef` | Drive én stasjon, dag for dag | Desktop og mobil |
| `butikkbruker_tablet` | Utføre arbeid: rutiner, temperaturer, sjekkpunkt | Nettbrett i butikken |
| `plattform_redaktor` | Publisere innhold nedover til alle kjeder | Desktop |

**Nettbrettet er en egen verden.** Det returnerer tidlig med `TabletSkall` og
ser aldri hovedmenyen. Robert sa 2026-08-13 eksplisitt at det **ikke skal
røres**. Denne bestillingen nevner nettbrett under responsivitet — det må
avklares før noe gjøres der. Til det er avklart: nettbrettet står urørt.

Eieren og butikksjefen ser i dag **samme sider** med samme oppsett, bare med
ulikt utvalg. Det er en av de større svakhetene: eieren vil sammenligne fem
stasjoner, butikksjefen vil drive én. Samme tabell tjener sjelden begge.

---

## 3. Ny informasjonsarkitektur

Prinsippet: **grupper etter spørsmålet brukeren har, ikke etter modulen svaret
ligger i.**

| Gruppe | Spørsmålet den svarer på |
|---|---|
| **I dag** | Hva skjer nå, og hva må jeg gjøre? |
| **Drift** | Blir arbeidet gjort, og er det dokumentert? |
| **Salg og produksjon** | Hva skal vi lage, og hva selger vi? |
| **Penger** | Tjener vi penger, og hva koster folkene? |
| **Team** | Hvem jobber her, hvordan har de det, hva kan de? |
| **Innsikt** | Hvorfor ser tallene slik ut? |
| **Oppsett** | Hvordan er systemet satt opp? |

To endringer fra dagens gruppering:

**«Resultater» splittes i «Penger» og «Innsikt».** I dag ligger `/salg` og
`/analyse` sammen. Det ene er et tall du sjekker, det andre er en undersøkelse
du gjør. Ulike ærend, ulik hyppighet.

**«Mer» avvikles.** Det er en gruppe uten mening — den sier «vi visste ikke hvor
dette hørte hjemme». `/import` og `/dekning` er datainngang og hører under
Oppsett; `/anvisninger` og `/kunnskap` er oppslagsverk.

---

## 4. Ny hovednavigasjon

Dagens meny har 44 punkter i 5 grupper. Det er for mange på ett nivå, og navnene
er modulnavn.

**Grepet: to nivåer, aldri tre.** Gruppen i menyen, og undersider som faner
inne på siden — ikke som egne menypunkter.

Konkret: `/rutiner`, `/rutiner/min`, `/rutiner/oversikt` og `/rutiner/oppsett`
er fire menypunkter i dag. De er én ting — rutiner — sett fra fire vinkler.
Ett menypunkt, fire faner. Menyen faller fra 44 til rundt 28 uten at én rute
forsvinner.

Samme grep på `/produksjonsplan` + `/treffsikkerhet`, `/ikmat` + `/oppsett`,
`/puls` + `/sporsmal` + `/ny`, `/kontrakt` + `/[id]`.

**Stasjonsvelgeren flyttes ut av sidene og opp i toppstripen.** 19 sider har sin
egen i dag. Butikksjefen har uansett bare én stasjon — hun skal aldri se
velgeren. Eieren velger én gang, og valget følger med.

---

## 5. Dashbordstruktur

Forsiden er allerede signaldrevet og skal beholdes. Det som mangler er at den
samme strukturen gjelder **hver enkelt side**:

```
NIVÅ 1  Status      Ett svar. Hvordan går det, akkurat her?
NIVÅ 2  Handling    Hva bør jeg gjøre nå? Én til tre knapper.
NIVÅ 3  Begrunnelse Hvorfor sier systemet det? Sammenleggbar.
NIVÅ 4  Detaljer    Tabellen. Under, ikke øverst.
```

Testen fra punkt 18 avgjør: forstår en ny butikksjef på fem sekunder hva siden
handler om og hva hun bør gjøre?

---

## 6. Designprinsipper

Bygger på det som allerede ble bestemt 2026-08-13, og som fortsatt gjelder:

- **Kroma er reservert for betydning.** Blått er interaktivt. Rødt og gult
  brukes kun på alvorlighet og status. Aldri dekorasjon.
- **Ingen emoji som ikonografi.** Bestillingens eksempler bruker 🌤 og 📈;
  det gjør vi ikke. Emoji skalerer ikke, oversettes ikke, og aldres dårlig.
  Ikoner tegnes.
- **Funn er rader med alvorlighetsstripe**, ikke kort.
- **Ingen lilla AI-gradienter.** AI-en skal se ut som resten av systemet.

Nytt i denne runden:

- **Ikke pakk alt i et kort.** 57 av 61 sider gjør det i dag, og da betyr kortet
  ingenting. Kort brukes når noe faktisk er en avgrenset enhet.
- **Ett tall er sterkere enn fem.** Nivå 1 er ett svar, ikke en rad med KPI-er.
- **Skriv knappen som handlingen.** «Godkjenn produksjonsplanen», ikke «Lagre».
- **Sammenlign alltid mot noe.** «34 200 kr» sier ingenting. «+7,8 % mot en
  vanlig tirsdag» sier alt. Systemet har allerede grunnlaget — det brukes bare
  ikke konsekvent.
- **Ikke spør om det systemet vet.** Stasjon, dato og periode har fornuftige
  standardverdier i nesten alle tilfeller.

---

## 7. Komponentstruktur

Dette er den største tekniske mangelen: 478 klasser i én CSS-fil, uten
tokens. Samme visuelle idé er skrevet på nytt flere steder, og derfor drifter
sidene fra hverandre.

**Først et tokenlag** — farger, avstander, typografi, radius, som CSS-variabler.
Deretter komponenter som bruker dem:

| Komponent | Erstatter i dag |
|---|---|
| `Sidehode` (tittel, status, handlinger) | håndskrevet `h1` + `p.undertittel` |
| `Nokkeltall` (tall, sammenligning, retning) | `kpi-tall`, `vekst-kort`, ad hoc |
| `Funnrad` (alvorlighetsstripe, tekst, handling) | `varsel`, `driftsstatus-rad` |
| `Datatabell` (sortering, tom tilstand, overflow) | 28 håndskrevne tabeller |
| `Faner` | finnes ikke — derfor er undersider egne menypunkter |
| `Sidepanel` | finnes ikke — derfor er skjemaer alltid inline |
| `Forklaring` (sammenleggbar «Hvorfor?») | finnes som `sammenleggbar.tsx` |
| `Tomtilstand` | finnes ikke — i dag «Ingen data» i grå tekst |

`Sidepanel` og `Faner` er de to som låser opp mest. Uten dem må hvert skjema
ligge åpent på siden, og hver underside bli et menypunkt.

---

## 8. Sidene med dårligst brukeropplevelse

Rangert etter hvor ofte de brukes ganger hvor gale de er.

**1. `/ansatte`** — åpner med skjemaet for ny ansatt før lista. Ingen status,
ingen søk, ingen antydning om hvem som er aktiv.

**2. `/bemanning`** — 1007 linjer, 11 seksjoner på én side. Alt fra
årsfordeling til faste vakter til kontraktdekning i én rull. Hver seksjon er
god; summen er uleselig.

**3. `/produksjonsplan`** — brukeren møter beregningen før anbefalingen.
Bestillingens eksempel er nøyaktig riktig: tallet først, metoden bak «Hvordan
beregnes dette?».

**4. `/lonn`** — 386 linjer, tre store tabeller. Beslutningen («kan fila
sendes?») må hentes ut av dem.

**5. `/kontrakt`** — velger for stasjon, ansatt, form og rolle før noe vises.
Fire valg før første informasjon.

**6. `/regnskap`, `/salg`, `/svinn`, `/analyse`** — alle åpner med tall uten
sammenligning, og med tabellen øverst.

**7. De 19 sidene med egen stasjonsvelger** — samme valg, tatt om igjen.

---

## 9. Hvordan de forbedres

**`/ansatte` → Team.** Øverst: «12 aktive · 2 uten PIN». Deretter lista, med
status per person og siste aktivitet. «+ Ny ansatt» åpner et sidepanel.

**`/bemanning` → fire faner.** *Planen* (dagens forslag), *Folkene* (stillinger
og kontraktdekning), *Ferie*, *Oppsett* (vinduer, krav, faste vakter, tak).
Ingen seksjon fjernes; de slutter bare å ligge i samme rull.

**`/produksjonsplan`.** Nivå 1: «AI anbefaler 130 produkter, +12 % mot en vanlig
tirsdag». Nivå 2: «Godkjenn planen» / «Juster». Nivå 3: årsakene. Nivå 4:
produktlista og beregningen.

**`/lonn`.** Nivå 1: «Klar til sending» eller «3 ansatte mangler lønnsform».
Blokkeringen finnes allerede i logikken — den skal bare være det første man ser.

**`/kontrakt`.** Start på ansattlista med status per person («Mangler avtale»,
«Utkast», «Signert»). Form og rolle velges når man skriver, ikke før man ser.

**Tallsidene.** Hver får en sammenligning ved siden av tallet, og tabellen
flyttes under.

---

## 10. Garantien: ingen funksjoner forsvinner

Punkt 16 er det viktigste kravet, og et løfte er ikke godt nok. Trinn 1 ble
verifisert ved å telle menypunkter før og etter — samme metode, automatisert:

**En vakthund, som `src/app/klientgrense.test.ts`.** Den leser rutetreet og
menydefinisjonen og feiler hvis:

- en rute som fantes før er borte
- et `(sti, roller)`-par har endret seg utilsiktet
- en side har mistet en `<h2>`-seksjon uten at fasiten er oppdatert

Fasiten sjekkes inn nå, før første endring. Da er «ingenting forsvant» noe som
kan kjøres, ikke noe jeg sier.

Samme grep reddet oss to ganger i denne kodebasen: RLS-vakthunden fant en ekte
regresjon på første kjøring, og klientgrense-testen fanget et mønster `tsc`,
`eslint` og `next build` alle var blinde for.

---

## 11. Rekkefølge

Hver av disse er en runde som kan leveres og brukes for seg.

1. **Vakthund + fasit** — før noe endres.
2. **Tokenlag og kjernekomponenter** — `Sidehode`, `Nokkeltall`, `Faner`,
   `Sidepanel`, `Datatabell`, `Tomtilstand`.
3. **Navigasjon** — to nivåer, faner inne på sidene, stasjonsvelger i toppen.
4. **De fem verste sidene** — `/ansatte`, `/bemanning`, `/produksjonsplan`,
   `/lonn`, `/kontrakt`.
5. **Tallsidene** — sammenligning ved siden av hvert tall.
6. **Resten**, i den rekkefølgen irritasjonen tilsier.

---

## 12. Å avklare før start

- **Nettbrettet.** Skal det røres denne gangen? Beskjeden 2026-08-13 var et
  klart nei.
- **Eier mot butikksjef.** Skal de begynne å se ulike sider der ærendet er
  ulikt — sammenligne fem stasjoner mot å drive én?
