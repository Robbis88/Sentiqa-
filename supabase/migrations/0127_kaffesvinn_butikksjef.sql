-- =====================================================================
-- Butikksjefen skal kunne spoerre om SIN egen kaffe
--
-- `regnskap_usynlig_svinn` er retailer_admin only (0049, 0067). Det er
-- riktig for resten av rapporten - den inneholder hele svinnbildet for
-- kjeden - men det gjoer at `v_kaffe_svinn` returnerer NULL RADER til en
-- butikksjef.
--
-- Og null rader ser noeyaktig ut som «ingen problemer». Spoer hun
-- AI-en «har vi glemt aa slaa inn paafyll?», faar hun et beroligende
-- svar som ikke er en maaling. Det er den samme sykdommen som gaar igjen
-- gjennom hele denne kodebasen: stillhet som likner et godkjent svar.
--
-- Robert 2026-08-23: «kan man ogsaa spoerre AI-chaten? Hver stasjon
-- spoerre om sin egen stasjon?»
--
-- DOEREN ER SMAL MED VILJE. Bare avdeling 130, og bare egne stasjoner.
-- Butikksjefen faar se om hun har slaatt inn koppene sine - ikke resten
-- av svinnrapporten, og ikke naboens tall. Kaffejusteringen er hennes
-- eget arbeid; hele svinnbildet er eierens sak.
--
-- TRE RLS-REGLER FRA AGENTS.md, alle tre i bruk her:
--
--   1. Funksjonskall pakkes i `(select ...)` saa de blir initplan og
--      evalueres én gang - ikke per rad. `regnskap_usynlig_svinn` er i
--      `varme`-arrayet i rls_vakthund.sql fordi den vokser med drift.
--   2. Aldri `for all`. Denne er `for select` alene.
--   3. `har_stasjonstilgang(stasjon_id)` kan aldri bli initplan fordi
--      den tar en kolonne som argument. Bruk
--      `stasjon_id in (select public.mine_stasjoner())`.
--
-- Kjor `supabase/tests/rls_vakthund.sql` etter denne.
-- =====================================================================

drop policy if exists usynlig_svinn_les_kaffe on public.regnskap_usynlig_svinn;
create policy usynlig_svinn_les_kaffe on public.regnskap_usynlig_svinn
  for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'butikksjef'
    -- Kodeprefiks, ikke navn. `navn ilike '%VARM%'` traff `12014
    -- OPPVARMET` da denne analysen ble gjort, og ga et troverdig tall
    -- for feil avdeling.
    and left(kode, 3) = '130'
    and stasjon_id in (select public.mine_stasjoner())
  );

comment on policy usynlig_svinn_les_kaffe on public.regnskap_usynlig_svinn is
  'Butikksjefen ser kaffelinjene (130xx) for sine egne stasjoner, saa '
  'hun kan spoerre om paafyllene er slaatt inn. Resten av '
  'svinnrapporten er fortsatt retailer_admin only.';
