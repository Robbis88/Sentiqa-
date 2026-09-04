<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Salgstall: les `v_butikksalg`, aldri `daglig_salg`

Drivstoff ligger i `daglig_salg` og er **~68 % av omsetningen**. Det betjener
seg selv på pumpa, bidrar ikke til stasjonens P&L, og skal aldri måles mot
butikkens bemanning, kategorier, målekort eller konkurranser.

**Det er avdelingsnavnet `ENERGI` som identifiserer drivstoff — ikke koden.**
Denne linja sto tidligere som «avdeling `ENERGI`, kode `10`». Målt mot
produksjon 2026-08-28 er avdelingskoden hos Kelsar `1000`; `10` finnes ikke i
data, og den armen av filteret har aldri truffet noe. Behandle kodeverdien som
en observasjon fra én kjede, ikke som en regel — hvilken kode en kjede bruker
er retailer-data, og den mappingen er ikke bygget. Trenger du å kjenne igjen
drivstoff, les `v_butikksalg` i stedet for å skrive et nytt filter.

Det kom inn i salgsstatistikken i løpet av april 2026. Fram til 0084/0085 var
det ikke filtrert noe sted, og ukerapporten sammenlignet årets uke *med*
drivstoff mot fjorårets *uten*: forsiden viste **+216 % vekst som ikke fantes**.

**Regel: alt som summerer kroner eller antall skal lese `v_butikksalg`.**
Den har samme kolonner som `daglig_salg`, minus drivstoff. Trenger du
drivstoff eksplisitt (sjelden), les `daglig_salg` og skriv i kommentaren
hvorfor.

Sjekk før du er ferdig: `grep -rn "from('daglig_salg')" src/` skal ikke gi
treff, og nye SQL-funksjoner skal lese `public.v_butikksalg`.

# Database og RLS

Migrasjonene kjøres **manuelt** i Supabase SQL Editor (prosjekt-ref `ahsetswpwzvcizkurymg`), ikke via `supabase db push`. Det finnes derfor ingen historikk-tabell, og hele settet `0001 →` kjøres av og til om igjen fra bunn.

**Konsekvens: alt må tåle å kjøres om igjen.**

- Struktur: `if not exists` / `or replace` / `drop policy if exists` før `create policy`.
- Alle `insert`/`update` må være vaktet — `not exists`, eller et `where` som blir usant andre gang. Uvaktet `update ... set kolonne = null` er den farligste formen.
- Refererer en migrasjon en kolonne en senere migrasjon dropper, må den vaktes med en `information_schema.columns`-sjekk (se `0026`/`0038`).

**Levering:** skriv `.sql`-fila i `supabase/migrations/` og legg innholdet på utklippstavla med `Get-Content -Raw <fil> | Set-Clipboard`. Strip ikke-ASCII først (`-replace '[^\x00-\x7F]',''`) — innlimingskjeden legger ellers av og til på et stray-tegn foran linje 1 og gir «syntax error at or near».

## RLS-ytelse — den feilen som har rammet produksjon

Hjelpefunksjonene (`gjeldende_rolle()`, `gjeldende_retailer_id()`) er `security definer` og kan ikke inlines. Kalles de **uten** `(select …)` i en policy, evalueres de **per rad** → `statement timeout` → 0 rader returnert. Ser ut som datatap, er det ikke. Slo ut `daglig_salg` 2026-06-16.

Tre regler på tabeller som vokser med drift:

1. **Pakk alltid funksjonskall i `(select …)`** → evalueres én gang som initplan.
2. **Aldri `for all`.** `USING` i en `for all`-policy gjelder også `SELECT`, og permissive policyer OR-es sammen — så en skrivepolicy trekkes inn i hver leseplan og gjør `retailer_id` ikke-sargbar. Splitt i `for insert` / `for update` / `for delete`.
3. **`har_stasjonstilgang(stasjon_id)` kan aldri bli initplan** — den tar en kolonne som argument. Bruk `stasjon_id in (select public.mine_stasjoner())` i stedet.

## Etter hver migrasjon som rører policyer

Kjør `supabase/tests/rls_vakthund.sql`. Den leser kun katalogen, er trygg i produksjon, og kaster exception hvis noen av de tre mønstrene over har sneket seg inn. **Nye transaksjonstabeller skal legges inn i `varme`-arrayet i den fila med én gang de opprettes.**

Ved større endringer i policyer: kjør også `supabase/tests/rls_isolasjon.sql` (kjører i transaksjon, ruller tilbake selv).

Vakthunden fant en ekte regresjon på sin første kjøring, etter tre runder med manuell gjennomlesing som ikke fanget den. Ikke hopp over den.

**Dekningssjekken (punkt 4) er den viktigste.** Hver tabell med policy skal stå i `varme` eller `kalde`. En tabell som faller mellom stolene blir ikke sjekket av de andre punktene, og det ser ut som en tabell uten problemer. 2026-08-18 fant den 47 slike — blant dem 49 partisjoner av `daglig_salg` der `anon` kunne lese alt, forbi forelderens RLS. **Partisjoner arver ikke RLS eller rettigheter:** oppretter du en, må du `revoke all ... from anon, authenticated` eksplisitt (se `0003` og `0105`).

**Views har samme problem, av samme grunn.** Supabase-standarden `alter default privileges in schema public grant all on tables to anon, authenticated, service_role` treffer også hver nye view — `anon` er rollen bak den offentlige nøkkelen i hver sidelast. En ny view skal derfor ha begge linjer:

```sql
grant select on public.v_ny to authenticated;
revoke all on public.v_ny from anon;
```

og alltid `with (security_invoker = true)` — uten den leser viewet som eieren, forbi RLS. **`create or replace view` uten klausulen nullstiller flagget i stillhet**, så en redefinering i en senere migrasjon kan slå av vernet uten at diffen ser farlig ut. Punkt 9 i vakthunden kaster på begge deler (se `0130`).

**Og tabeller, av nøyaktig samme grunn.** En ny tabell skal ha `revoke all on public.ny_tabell from anon;` ved siden av sine grants til `authenticated`. PostgREST-sonden fant 2026-08-25 at 77 tabeller svarte `200 []` for `anon` — ingen lekkasje, men granten lå der og RLS var eneste lag. `0134` tok dem, og punkt 10 i vakthunden holder dem lukket. Kjør `supabase/tests/postgrest_sonde.mjs` når du vil se det gjennom klientflaten i stedet for katalogen.

**Dekningsvakten skal starte fra alle faktiske databaseobjekter, ikke bare de som har policy.** Vakthundens punkt 4 leser `pg_policies` og ser derfor bare tabeller *med* policy — en tabell helt uten policy faller utenfor og ser ut som en tabell uten problemer. `oversettelse_cache` lå slik i to år: RLS på, ingen policy, låst med vilje siden `0037`, men usett av hver liste. `tenant_dekning.sql` starter fra `pg_class`, og **en tabell uten policy er et funn** til noen har kvittert for det med `ingen_policy` i `supabase/tenant-kontrakt.json`. Trygg og sett er to forskjellige ting.

**Å nevne tenantkolonnen er ikke å binde den.** `with check` på
`uke_rapport` inneholdt `retailer_id` — men bare i den ene armen av et
`or`, ved siden av en fri `stasjon_id in (mine_stasjoner())`. Den armen
alene godtar hvilken som helst kjede så lenge stasjonen er min, så raden
kunne flyttes til en annen kjede med stasjonen i behold. Detektoren
`kandidater_with_check.sql` så den aldri: den leter etter *fravær*.
Rettet i `0141`; **punkt 11** i vakthunden krever nå at hver arm på
øverste nivå nevner `retailer_id`. Kun i `with check` — i `using` er en
fri stasjonsarm riktig, siden en rad hvis stasjon er min per definisjon
er min kjedes når den ikke lenger kan flyttes.

**Et flagg i en kolonne er ikke en grense før RLS leser det.** `malekort.vis_tablet` sto i basen fra `0073` og ble bare brukt som visningsvilkår i appen; nettbrettet kunne lese kortet direkte over PostgREST. Rettet i `0134`. Legger du til et slikt flagg, hører det hjemme i policyen — ikke bare i spørringen.

# Tenant-kontrakten og fixture-kontrakten

`supabase/tenant-kontrakt.json` er eneste håndholdte kilde for hvem som når hva. Dekningskontrollen og atferdsmatrisen genereres derfra — `OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant`. Rediger aldri de genererte filene.

**To kontrakter, og de blandes ikke:**

- **Tenant-kontrakten beskriver autorisasjon.** Hvem som når hva, per rolle og operasjon.
- **Fixture-kontrakten beskriver gyldige testdata.** `proberad`, `seed_ekstra` og `business_unik` — det som ikke kan utledes av autorisasjonen.

**Generatoren skal aldri gjette en forretningsnøkkel.** Den kjenner tre: tenantnøkkelen skiller kjeder og stasjoner, primærnøkkelen er en uuid ingen kolliderer på, og `business_unik` er den som gjør at samme identitet to ganger — eller to identiteter på samme stasjon — kolliderer. Står en kolonne i `business_unik`, krever `valider()` at den varierer per forsøk eller kommer fra en fersk forutsetningsrad. Unntak krever en skrevet begrunnelse (`avvik.lopenr` settes av trigger `sett_avvik_lopenr()`).

**`OPPDATER_KONTRAKT` regenererer konsekvenser, aldri klassifiseringer.** En ny tabell må føres inn for hånd av noen som har tatt stilling. En gjettet rad ville gjort dekningssjekken til en formalitet.

## Capability-gjeld

**RLS er radnivå.** Trenger en rolle å skrive én kolonne, får den hele raden. Kolonnegrant hjelper ikke når en annen rolle i samme Postgres-rolle (`authenticated`) skal skrive de øvrige kolonnene — grantet treffer begge.

Slike steder er ikke avvik som kan strammes med et predikat; de er steder RLS ikke rekker. De føres som `capability_gjeld` på ressursen i `supabase/tenant-kontrakt.json`, med navn og utvei, i stedet for å bo i en commit-melding.

**Åpen gjeld: ingen.** Alle tre postene ble gjort opp 2026-09-02:

| | |
|---|---|
| `0165` | nettbrettet leser tallet gjennom en smal funksjon |
| `0167` | `loggLagd` skriver `lagd_hittil`, ikke hele planlinja |
| `0168` | bekreftelsen skrives for én selv, ikke for hvem som helst |

Alle tre har samme form: en `security definer`-funksjon som bærer
tenantpredikatet selv og rører nøyaktig de kolonnene som trengs, og
deretter en strammet policy.

**Listen her skal stemme med `capability_gjeld` i
`supabase/tenant-kontrakt.json`.** 2026-09-04 gjorde den ikke det, i
begge retninger: den nevnte `produksjonsplan_linjer` som åpen tre dager
etter at `0167` lukket den, og den nevnte ikke `kontrolltiltak_bekreftelse`,
som var den eneste posten kontrakten faktisk bar. Kontrakten er kilden;
denne seksjonen er sammendraget.

`skills_score.kommentar` og `pengepremie_bruk.beskrivelse` sto her som
«samme form, ikke klassifisert ennå». **Det var feil, ikke bare
uferdig:** begge har `tablet: "none"` i kontrakten — nettbrettet når dem
ikke i det hele tatt, og capability-gjeld handler nettopp om at
nettbrettet får mer av raden enn det trenger. De er lederflater med
rollekrav i policyen, og hører ikke hjemme her.

## Generatorantakelser skal testes direkte

**Når generatoren har en strukturell antakelse som påvirker flere kallsteder, skal antakelsen ha en rask direkte test. Ikke bruk full CI som første detector.**

Tre slike antakelser har dukket opp, og alle satt på flere steder samtidig:

| antakelse | felt | hva den handler om |
|---|---|---|
| `id_kolonne` | hva som identifiserer én rad | `bemanning_stasjon` har ingen `id` |
| `business_unik` | hva som gjør to rader forskjellige | `unique (rutine_id, dato)` o.l. |
| `en_rad_per_stasjon` | hvor mange rader som kan finnes | `stasjon_id` som primærnøkkel |

Alle tre er antakelser om **skjemaets form**, ikke om autorisasjon — og det er nettopp derfor de gjemmer seg. En autorisasjonsfeil gir `42501` og roper. En formfeil gir `23505` og *later som* den er en avvisning.

`id_kolonne` satt fire steder; jeg fant tre gjennom CI, ett symptom per kjøring, fire minutter hver. Den fjerde ble funnet på millisekunder av en vitest som beviser regelen i stedet for symptomet. Hver slik vakt skal ha en kanarifugl — finnes det ingen ressurs som utløser regelen, måler testen ingenting.

## Hva som teller som en tenant-avvisning

```
42501                        godkjent sikkerhetsavvisning
0 rader + målrad bevist      godkjent — `using` utelukket raden
23505 / 23503 / 23514 / …    FAIL. Domenefeil, ikke sikkerhet.
```

En blokkert `UPDATE` gir 0 rader og *ingen* exception. Det gjør også en feil id, en fixture som aldri ble seedet, og en tom tabell. Derfor godtas 0 rader bare når `pg_temp.finnes()` — security definer, ser forbi RLS — bekrefter at målraden er der.

**En positiv kontroll må lykkes før de negative i samme gruppe er gyldige.** Lykkes ingen tillatt operasjon på en ressurs, vet vi ikke om proberaden er gyldig i domenet — og da beviser ingen av avvisningene noe. Uten den regelen ville en suite der alt er ødelagt sett ut som en suite der alt er trygt.

**`skriv_avvist` og `skriv_tillatt` må være `security invoker`.** Blir de definer, kjører den dynamiske setningen som eier, forbi RLS, og fila blir grønn uansett hva policyen sier.

**Multi-setningsfiler kjøres med `psql -v ON_ERROR_STOP=1`,** ikke `supabase db query --file` — den sender fila som én prepared statement. Uten `ON_ERROR_STOP` returnerer psql 0 selv om en setning feilet.

**Mot produksjon limes matrisen inn i deler.** Hele `rls_kanarifugl_generert.sql` er for stor for Supabase SQL Editor — 1,0 MB ble avvist 2026-08-26 med «Query is too large to be run via the SQL Editor», og fila vokser med hver pulje. `supabase/tests/deler/matrise_NN.sql` genereres i samme slengen: hver del er en komplett kjøring med egen fasitverden, egne forutsetninger, egen oppsummering og egen `rollback`. Delene deler ingen tilstand og kan kjøres i hvilken som helst rekkefølge — men **hele beviset er alle delene**, og hver av dem må si «ingen funn». CI kjører både den fulle fila og delene: vitest beviser at delene *dekker* hver varm ressurs, CI beviser at de *kjører*.

# Arbeidsflyt: `main` er beskyttet

Siden 2026-08-19 kan ingen pushe rett til `main` — heller ikke eieren, heller ikke en agent som bruker eierens rettigheter. Bypass-lista er tom med vilje.

```
git checkout -b <kort-beskrivende-navn>
# ... arbeid, commit ...
git push -u origin <navn>
gh pr create --fill
```

`Vakter`-workflowen kjører på PR-en. Begge jobbene — `vakter` (~1½ min) og `nettleser` (~4 min) — må være grønne før merge er mulig.

**Hvorfor dette ble innført:** infrastrukturen under ble bygget med ni røde kjøringer rett i `main`, fordi den ikke kunne testes lokalt. Feilsøking hører hjemme i en PR. `main` skal være grønn.

# Vaktene i `src/lib/redesign/`

Kjører i vitest, tar 200 ms til sammen. `npx vitest run src/lib/redesign` etter hver side.

- **`vakthund.test.ts`** — ingen rute, rolletilgang eller serverhandling skal forsvinne i stillhet. Seksjoner og lenker måles mykt.
- **`tilgang.test.ts`** — menyen skal ikke love tilgang siden avviser. Leser portneren ut av kilden.
- **`design.test.ts`** — skralle på inline-stiler, emoji, rå `<table>`, rå `<h1>` og hex-farger. Tallene får aldri gå opp.
- **`tokens.test.ts`** — de 33 designtokenene i `globals.css` endrer seg ikke i stillhet. En token treffer hele systemet samtidig.
- **`tilgjengelighet.test.ts`** — axe mot UI-primitivene i jsdom. **Måler ikke kontrast eller treffområder** — det krever layout, altså en ekte nettleser.
- **`monstre.ts`** — hver rute må ha et mønster. Passer ikke mønsteret siden, endre *mønsteret* og skriv hvorfor.

Skal noe faktisk endres: `OPPDATER_FASIT=1 npx vitest run src/lib/redesign`. Da viser git nøyaktig hva som ble gitt slipp på.

## `innerText` og sammenleggbart innhold

**Les aldri `innerText` på en kollapset `<details>`.** `innerText` gir *rendret* tekst når elementet er lagt ut, og faller tilbake til `textContent` når det ikke er det. En påstand som leser den kollapsede delen består altså når siden **ikke** er ferdig, og feiler når den er det. `svinn.spec.ts` flaket slik i ukevis; en lengre timeout ville gjort den rødere, ikke grønnere.

Åpne detaljen først, `toBeVisible()`, og les så. Det er også et sterkere bevis: at tallet er til *å lese*, ikke bare til å finne i DOM-en.

`toContainText` leser `textContent` og ser aldri forskjellen — derfor flaker den ikke, og derfor er det vanskelig å se hvor feilen ligger når bare én linje i en test er rammet.

**Regelen, kort:** en NEGATIV påstand hører til `textContent`, ikke
`innerText`. `innerText` gir bare rendret tekst og kan ikke skille
«finnes ikke» fra «er skjult i en `<details>`». `bolge2-analyse.spec.ts`
og `innlogget.spec.ts` sto en periode med `.not.toMatch` mot
`innerText()`; begge bruker `toContainText` nå, med begrunnelsen skrevet
i testen.

**Hver vakt har en kanarifugl, og det er ikke pynt.** To av dem har vært grønne mens de var i stykker — RLS-vakthunden i månedsvis fordi den forutsatte at det fantes policyer å vurdere, rollevakten fordi regexen ikke tålte parenteser og dermed var blind for `!erLeder(bruker.rolle)`. **En vakt som slutter å se, ser nøyaktig ut som en vakt som ikke finner noe.** Legger du til en ny kontroll, legg til noe som feiler når den slutter å måle.


# Onboarding skal holdes levende

Onboarding skal beskrive hva en ny retailer trenger i **dagens** Sentiqa —
ikke hva som var nødvendig da onboarding først ble skrevet. En onboarding
som er sann den dagen den lages og usann tre måneder senere er verre enn
ingen: den ser komplett ut mens den er det ikke.

**Etter hver endring i funksjon, datamodell, innstilling, import,
integrasjon eller modul skal du svare eksplisitt på:**

> Påvirker denne endringen hva en helt ny retailer trenger for å starte fra
> tom konto og få denne funksjonen til å virke *korrekt*?

Svaret skrives i klartekst før oppgaven regnes som ferdig — ikke som en
antakelse, og ikke bare i en commit-melding:

```
Onboardingpåvirkning: NEI.
Onboardingpåvirkning: JA — <hva som må endres i onboarding>
```

**Gjelder også små endringer.** Det som utløser JA:

| | |
|---|---|
| nytt obligatorisk onboardingsteg | ny fil/datatype som må lastes opp |
| ny valgfri konfigurasjon | endret minimum historikk |
| ny mapping per retailer | endret anbefalt historikk |
| ny mapping per stasjon | ny konfigurasjon per varegruppe |
| nytt krav på ansatte | ny integrasjon |
| nytt Sentiqa-kontrollpunkt | noe retaileren kan gjøre selv |
| noe Sentiqa må gjøre | **en oppgave som nå kan fjernes** |

Den siste er den som glemmes. Automatiserer vi inntaksadressen, skal det
manuelle kontrollpunktet **ut** av onboarding — ellers vokser lista med
arbeid som ikke finnes lenger, og da slutter folk å tro på den.

Gjør vi produksjonsmargin eller start-% konfigurerbart per
retailer/stasjon/varegruppe, er spørsmålet ikke «skal det med i
onboarding», men: **holder en trygg standardverdi, eller må en ny kjede ta
stilling til dette før modulen svarer riktig?** Standardverdi som virker →
ingen onboardingendring. Standardverdi som gir feil tall for en annen
kjede → nytt steg.

## Én sannhet, ikke to

**Onboarding skal ikke være en hardkodet sjekkliste ved siden av modulene.**
Da finnes det to sannheter — hva modulen faktisk krever, og hva onboardingen
tror den krever — og de skiller lag i stillhet. Det er samme form som en
vakt som slutter å se: lista ser like komplett ut dagen den blir feil.

Når dette skal bygges, skal det først undersøkes om onboardingstatus kan
**utledes** av de samme kravene og konfigurasjonene modulene selv leser, i
stedet for å gjentas.

Driften har alt begynt: `KILDER` i `src/lib/onboarding.ts` er håndholdt og
kjenner fem kilder. Kartleggingen 2026-08-28 fant ni, og fant samtidig at
`hentDagskunder` går to kalenderår tilbake mens `KILDER` lover 365 dager for
timesalg. Ingen av delene var feil da de ble skrevet.
