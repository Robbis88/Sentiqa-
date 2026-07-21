<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

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
