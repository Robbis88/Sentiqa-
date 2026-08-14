# Sentiqa — systemoversikt

Skrevet for å gis videre til noen som skal jobbe med timeplanlegging mot dette
systemet. Beskriver hva som finnes, hvem som ser hva, og hvordan
bemanningsmodulen henger sammen.

---

## 1. Hva Sentiqa er

SaaS for kjeder av bemannede bensinstasjoner/nærbutikker i Norge. Første kunde
er Kelsar Bil AS (St1-stasjoner rundt Bergen: Bønes, Dale, Laguneparken, Lone,
Varden). Systemet er flerleietaker (`retailers`), og alt er skrevet på norsk —
kode, kommentarer, tabellnavn, UI.

Kjernen: stasjonene laster opp rapporter fra kassesystem, regnskap og
timeplansystem. Sentiqa leser dem, finner avvik, og gir butikksjefen konkrete
ting å gjøre.

**Teknisk:** Next.js 16 (App Router, server components, server actions),
Supabase (Postgres + RLS + Storage + Auth), Vercel, TypeScript, Vitest.
Ingen ORM — Supabase-klienten direkte.

---

## 2. Roller

Fire roller. Rollen ligger på `profiler.rolle` og styrer både meny og RLS.

| Rolle | Hvem | Ser |
|---|---|---|
| `retailer_admin` | Eier / driftssjef | Alle stasjoner i kjeden, import, brukere, regnskap |
| `butikksjef` | Butikksjef | Sine egne stasjoner (`butikksjef_stasjoner`) |
| `butikkbruker_tablet` | Delt tablet på stasjonen | Kun driftsflaten, egen meny |
| `plattform_redaktor` | Sentiqa selv | Innhold, trafikk, kampanjer på tvers av kjeder |

`erLeder(rolle)` = `retailer_admin || butikksjef`.

**RLS er den egentlige muren.** Rollesjekker i server actions gir bare
vennligere feilmeldinger. Hjelpefunksjoner: `gjeldende_rolle()`,
`gjeldende_retailer_id()`, `mine_stasjoner()`.

### RLS-konvensjoner (viktig hvis du skriver SQL)

Tre regler, alle lært av produksjonsfeil:

1. **Pakk alltid funksjonskall i `(select …)`** — `security definer`-funksjoner
   kan ikke inlines, og uten `(select …)` evalueres de per rad → statement
   timeout → 0 rader tilbake. Ser ut som datatap.
2. **Aldri `for all`.** `USING` i en `for all`-policy gjelder også `SELECT`, og
   permissive policyer OR-es sammen. Splitt i `for insert` / `for update` /
   `for delete`.
3. **`har_stasjonstilgang(kolonne)` kan aldri bli initplan** — bruk
   `stasjon_id in (select public.mine_stasjoner())`.

`supabase/tests/rls_vakthund.sql` kaster exception hvis noen av mønstrene
sniker seg inn. Kjøres etter hver migrasjon som rører policyer.

---

## 3. Tableten

Delt enhet som står i butikken. Egen konto per stasjon
(`butikkbruker_tablet`), ingen to-faktor (det er en delt enhet).

**Identifikasjon skjer med PIN, ikke innlogging.** `ansatte`-tabellen har navn
+ `pin_hash` per stasjon. Den som skal gjøre noe taster PIN, og en cookie
(`sentiqa_vakt`) holder på hvem som er «aktiv ansatt». Dette er
identifikasjon på kasserernummer-nivå, ikke sikkerhet — RLS styrer all faktisk
tilgang.

**Tableten har fire faner, ikke sidemenyen:**

- **Hjem** — dagens tall, skills-score, premiesaldo, produksjonsplan
- **Rutineskjema** — dagens sjekkliste, avkryssing
- **Anvisninger** — arbeidsbeskrivelser, oversettbare
- **Lenker** — snarveier kjeden har lagt inn

Tableten har **flerspråkstøtte** (`oversett.ts`, `oversettelse_cache`) fordi
mange ansatte ikke har norsk som førstespråk. Språkvalg i cookie.

Tableten skriver til: `rutine_utforinger`, `sjekkpunkt_svar`,
`ik_avlesninger`, `avvik`, `tildelte_merker`, `puls_svar`.

---

## 4. Butikksjefen

Ser sidemenyen, gruppert etter **hva man holder på med** — ikke etter modul.

### Forsiden `/oversikt`

Ikke et widget-rutenett. Rekkefølgen er **oppmerksomhet → forståelse →
handling → oppfølging**: signaler først, rangert etter alvor × konsekvens
(kroner, sqrt-skalert) × varighet. Signalmotoren ligger i `signaler.ts` /
`signalkilder.ts`. Alvorlighet vises i ord («Haster», «Følg med», «Til
orientering»), ikke bare farge.

**Salgstall er aldri sanntid.** De er alltid gårsdagens. `ferskhet()` sier fra
når de er eldre enn det, og forsiden presenterer dem aldri som «i dag».

### Drift

| Rute | Hva |
|---|---|
| `/produksjonsplan` | Hvor mye mat som skal produseres, per dag/vare. Vær og arrangementer som input. `/treffsikkerhet` måler om den traff |
| `/utsolgt` | Varer som sannsynligvis er utsolgt (solgte i går, ikke i dag) |
| `/bemanning` | **Se avsnitt 7** |
| `/salgsprognose` | Salgsprognose per dag |
| `/oppgaver` | Oppgaver til stasjonen |
| `/rutiner`, `/rutiner/oversikt`, `/rutiner/min`, `/rutiner/oppsett` | Rutineskjema: tableten utfører, butikksjefen setter opp og følger opp |
| `/sjekkpunkt` | Enkeltstående kontrollpunkter |
| `/ikmat`, `/ikmat/maaling`, `/ikmat/oppsett` | Internkontroll mat: temperaturmålinger, avvik, dokumentasjon |
| `/svinn` | Synlig svinn (registrert) og usynlig svinn (fra regnskapet) |
| `/arrangementer` | Lokale arrangementer, importeres fra iCal, brukes i prognoser |

### Resultater

`/salg`, `/timesalg`, `/regnskap`, `/analyse` (AI-regnskapsanalyse),
`/maaling` (målekort), `/kasserer` (kassererstatistikk).

### Team

`/fokus` (AI-genererte fokuspunkter), `/tilbakemeldinger`, `/meldinger`
(tablet-meldinger), `/ansatte` (PIN-administrasjon), `/opplaring`, `/skills`,
`/merker`, `/konkurranser`, `/premier`, `/puls` (medarbeiderundersøkelser),
`/lederstotte` (AI-generert lederrapport).

### Mer (eier)

`/import`, `/dekning`, `/stasjoner`, `/brukere`.

---

## 5. Dataflyt

### Import

Alt kommer inn som filer. To veier inn:

1. **Nettleseropplasting** (`/import`). Små xlsx parses i nettleseren og sendes
   som ferdig JSON. **Store filer, PDF og CSV går rett til Supabase Storage**
   og legges i kø — plattformen svarer 413 på kropper over noen MB, før Next
   ser dem, så `serverActions.bodySizeLimit` hjelper ikke.
2. **E-post-inntak** (`/api/epost-inntak`), med avsender-allowlist per kjede.

Køen (`import_jobber`) behandles av `behandleKoen()`, som kjøres **først** i
nattjobben — alt annet leser salgsdata, så en fil som behandles etter
analysene ville gitt forgårsdagens tall hver natt.

**Ruting skjer på innhold, ikke filnavn:** `%PDF` → pdf.js, `PK` → xlsx,
lesbar tekst → CSV.

### Rapporttyper som leses

| Type | Kilde | Innhold |
|---|---|---|
| `st1_salgsstatistikk` | St1 0714, daglig | Salg per varegruppe → `daglig_salg` |
| `st1_salesperhour_inneute` | St1 0603, daglig | Inne-/utekunder per time → `timesalg` |
| `st1_cashierstats` | St1 0018 | Kassererstatistikk |
| `salgsgrid_varetrans` | Salgsgrid 0452 | Synlig svinn |
| `regnskap_resultat` | Regnskapsfører, månedlig | Resultat + nøkkeltall → `regnskapslinjer` |
| `st1_bp` | Kjedens BP-fil, årlig | Budsjett per måned → `bemanning_maned` |
| `easyatwork_stempling` | easy@work «Basis Export» | Faktiske stemplinger → `stempling` |

### To feller som har rammet produksjon

**1. Drivstoff.** Avdeling `ENERGI` (kode `10`) er ~68 % av omsetningen. Den
betjener seg selv på pumpa og skal aldri måles mot butikkens bemanning.
Den kom inn i salgsstatistikken i april 2026 og ga forsiden **+216 % vekst som
ikke fantes**.

> **Regel: alt som summerer kroner eller antall skal lese `v_butikksalg`**,
> ikke `daglig_salg`. Samme kolonner, minus drivstoff.

**2. PostgREST kutter på 1000 rader.** Å hente rå rader til klienten for å
telle eller summere dem gir *stille* gale svar. Det rammet fire tall i
bemanningsplanen samtidig uten å feile.

> **Regel: all telling og summering over transaksjonstabeller skjer i en
> visning i basen.**

### Nattjobb (`/api/cron/natt`)

I rekkefølge: importkø → vær → iCal-arrangementer → trafikk (Vegvesen) →
ukerapport → AI-fokus → lederstøtte → regnskapsanalyse → backtest.
Hvert steg feiler isolert; ett som kaster velter ikke natten.

### Migrasjoner

Kjøres **manuelt i Supabase SQL Editor**, ikke via `supabase db push`. Ingen
historikk-tabell. Hele settet `0001 →` kjøres av og til om igjen fra bunn.

> **Alt må tåle å kjøres om igjen.** `if not exists` / `or replace` /
> `drop policy if exists`. Alle `insert`/`update` må være vaktet.

Høyeste kjørte: **0092**.

---

## 6. AI-bruken

Begrenset og målrettet. Ingen chat-boble, ingen lilla gradienter, ingen lange
avsnitt.

- `ai/fokus.ts` — fokuspunkter per stasjon, regenereres hver natt
- `ai/lederstotte.ts` — lederrapport
- `ai/regnskapsanalyse.ts` — leser regnskapsrapporten og finner avvik
- `ai/verktoy.ts` — verktøy AI-en kan kalle mot databasen
- `ai_tool_log` — logger hva som ble kalt

---

## 7. Bemanningsmodulen (`/bemanning`)

Dette er delen som er mest relevant for timeplanlegging.

### Problemet den løser

Butikksjefene planlegger på hukommelse. De henter aldri reelle tall — det er
arbeid de ikke gjør. Resultatet er at fjorårets turnus kopieres videre uansett
hva budsjettet sier.

Målt på Bønes: januar 2025 = 687 timer, januar 2026 = 688. Gjennom syv måneder
ligger begge stasjonene innenfor noen få prosent av fjoråret. Ny BP, nytt
timebudsjett, samme turnus.

> **Designprinsipp: systemet skal foreslå, ikke spørre.** Alt som kan måles
> måles, og butikksjefen retter det som er feil.

### Kjeden fra budsjett til vaktliste

```
BP-fil (årlig)
   └─ årsramme i timer per stasjon
        └─ fordelt på måneder etter STASJONENS EGNE MÅLTE KUNDER
           (ikke BP-kurven — den gir fjorårets bemanning tilbake)
             └─ gulvet trekkes fra i alle tolv månedene først
                (fordelAaret: en døgnåpen stasjon kan låne fra en roligere måned)
                  └─ resten fordeles per DATO × klokketime
                     · kundeform fra samme måned i fjor, justert for målt formendring
                     · dagfaktor per dato, målt fra stasjonens egen historikk
                     · røde timer koster dobbelt mot rammen
                     · tak per ukedag × time fra stemplingene
                     · minst 5 timers sammenhengende vakter
                       └─ dekomponeres til en VAKTLISTE
```

### Sentrale filer

| Fil | Ansvar |
|---|---|
| `lib/bemanning.ts` | Motoren. `fordelPaaMaaneder`, `maanedsvekter`, `fordelAaret`, `bundneTimer`, `planleggKalender`, `vaktliste` |
| `lib/dagtyper.ts` | Dagtyper og faktorer. `dagsprofiler`, `timekostnad`, `ukerIMaaned` |
| `lib/helligdager.ts` | Norsk helligdagskalender, deterministisk (computus) |
| `lib/bemanningsanalyse.ts` | `takFraUkeprofil`, `formendring`, `justerProfil`, `stillingsanslag`, `kapasitet`, `planMotFaktisk`, `sammenlignStasjoner` |
| `lib/parsere/stempling.ts` | easy@work Basis Export (PDF og CSV) |
| `lib/bemanningsvarsler.ts` | Varsler når regnskapet viser avvik |

### Modellen i detalj

**Bemannet vindu** (`bemanning_vindu`) — per stasjon per ukedag, fra/til og
minimumsbemanning. Merk: *bemannet*, ikke åpningstid. Bønes er åpent 06–24 men
bemannet fra 05, fordi noen smører mat.

**Krav-vinduer** (`bemanning_krav`) — timer der én ikke holder (varemottak).

**Faste vakter** (`bemanning_fast_vakt`) — butikksjef, NK, andre som alltid
står. **`timelonnet` skiller de to slagene:** en fastlønt butikksjef dekker
gulvet uten å koste timerammen; en timelønnet NK med fast vakt dekker gulvet
**og** belaster rammen. Feil her roter budsjettet uten at det synes.

**Fravær** (`bemanning_fravaer`) — matcher `bemanning_fast_vakt.navn`. Er en
fast vakt borte, dekker den ikke gulvet, og timene må kjøpes. **Ferie sparer
ikke timer, den flytter dem fra fastlønn til rammen.**

**Tak** (`bemanning_stasjon.maks_bemanning` + historisk tak) — det fysiske
taket settes manuelt (antall kasser). Det *historiske* taket regnes per ukedag
× klokketime fra stemplingene: nivået må ha forekommet minst to ganger **og** i
minst 10 % av gangene. Gjelder bare det frie laget — gulvet er butikksjefens
beslutning.

**Røde dager** — kalenderen er deterministisk, effekten måles per stasjon.
Skjærtorsdag er faktor 0,74 på Bønes og 0,96 på Laguneparken. En formel som sa
«helligdag = 70 % av normalt» ville tatt feil på begge.

**Aftener** — julaften, nyttårsaften, påskeaften og pinseaften er røde **fra
kl. 15**. Konsekvens: kostnaden er en egenskap ved *timen*, ikke ved dagen.
Dagen før 1. mai og 17. mai har **ikke** halv dag.

**Rødt påslag** — 100 % tillegg betyr at en rød time trekker to fra rammen.
Mai 2026 i et 05–24-vindu: 104 timers påslag, nesten en uke av månedsrammen.

**Vakter, ikke tall.** Rutenettet kan vise 3 personer kl. 12 — det er to
vakter som overlapper (10–15 og 11–16), altså et vaktbytte. `vaktliste()`
dekomponerer rutenettet til vakter man kan skrive av inn i en timeplan.

**Formendring** — jan–juli i fjor mot i år, begge normalisert (vi måler
*form*, ikke nivå; nivået ligger i BP-rammen). Under 8 % drift skjer
ingenting. Utslag vektes med kundetrykk.

**Stillingsprosent** — anslått fra medianmåneden i stemplingene, siste tolv
måneder, rundet til nærmeste 5 %. **Måler arbeidede timer, ikke kontrakt** —
ekstravakter inflaterer, røde dager deflaterer. Et tall butikksjefen skriver
inn overskrives aldri.

**Plan mot virkelighet** — over- og underforbruk holdes fra hverandre. Netto
null er det verste svaret: det ser ut som riktig bemanning og er to feil som
skjuler hverandre.

**Sammenligning mellom stasjoner** — timer per 100 kunder × matandel
(avdeling `120` = tilberedt mat, likt i hele kjeden). Kombinasjonen er poenget:
høye timer + lav matandel = timer å hente; høye timer + høy matandel = noe
annet.

### Relevante tabeller og visninger

```
bemanning_vindu          bemannet vindu per ukedag
bemanning_krav           timer der én ikke holder
bemanning_fast_vakt      faste vakter (+ timelonnet)
bemanning_fravaer        ferie/fravær
bemanning_stasjon        maks_bemanning
bemanning_maned          årsramme fordelt på måneder (fra BP)
bemanning_budsjett       lønn/timer/brutto fra kjeden
ansatt_avtale            bekreftet stillingsprosent
stempling                rå stemplinger fra easy@work

v_stempling_time         bemanning per dato × klokketime
v_stempling_ukeprofil    hvor ofte N personer, per ukedag × time
v_stempling_ansatt_mnd   arbeidede timer per ansatt per måned
v_stasjonsforbruk_mnd    timer, kunder, omsetning, mat per stasjon/måned
v_datadekning            hva som er lastet opp, per kilde og stasjon
v_butikksalg             daglig_salg uten drivstoff
```

### Det som IKKE er bygget

- **Navngivning av vakter.** Planen sier «to personer 12–18», ikke «Sissel
  12–18». Dette er den naturlige neste biten, og den krever at
  stillingsprosentene er bekreftet av butikksjefene først.
- **Skriving tilbake til easy@work.** Vi leser eksportfiler; det finnes ingen
  integrasjon. easy@work har API, men uten offentlig dokumentasjon — tilgang
  går via kundekontakt.
- **Låsing av en plan.** Planen regnes på nytt hver gang siden lastes; den
  lagres ikke som en versjon.
- **Sykefraværsreserve i praksis.** Modellen har `reservePst`, men den settes
  ikke per stasjon fra måledata ennå.

---

## 8. Konvensjoner å kjenne til

- **Alt på norsk.** Ruter, tabeller, variabler, kommentarer, UI.
- **Kommentarer forklarer HVORFOR**, ikke hva. De fleste peker på en konkret
  feil som har skjedd.
- **Parsere er rene funksjoner:** rå input inn, strukturert resultat ut.
  Ingen DB, ingen sideeffekter. Testbare uten filer.
- **Parsere som kan miste rader skal telle sine egne poster og kaste.** En
  parser som mister rader i stillhet er verre enn en som feiler.
- **Ingen emoji som ikonografi** utenfor tableten.
- **Verifiseringstriaden:** `tsc --noEmit`, `eslint`, `vitest`, `next build`.
- Fem parser-tester feiler lokalt fordi de leser `eksempelfiler/`, som ikke
  ligger i repoet. Det er forventet.
