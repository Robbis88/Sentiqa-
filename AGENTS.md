<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Salgstall: les `v_butikksalg`, aldri `daglig_salg`

Drivstoff (avdeling `ENERGI`, kode `10`) ligger i `daglig_salg` og er **~68 %
av omsetningen**. Det betjener seg selv på pumpa, bidrar ikke til stasjonens
P&L, og skal aldri måles mot butikkens bemanning, kategorier, målekort eller
konkurranser.

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

**Hver vakt har en kanarifugl, og det er ikke pynt.** To av dem har vært grønne mens de var i stykker — RLS-vakthunden i månedsvis fordi den forutsatte at det fantes policyer å vurdere, rollevakten fordi regexen ikke tålte parenteser og dermed var blind for `!erLeder(bruker.rolle)`. **En vakt som slutter å se, ser nøyaktig ut som en vakt som ikke finner noe.** Legger du til en ny kontroll, legg til noe som feiler når den slutter å måle.
