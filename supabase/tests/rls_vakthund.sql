-- =====================================================================
-- Sentiqa - RLS-vakthund
-- Kjor denne etter HVER nye migrasjon som rorer policyer. Den tar ikke
-- stilling til om isolasjonen er riktig (det gjor rls_isolasjon.sql) -
-- den fanger de tre monstrene som allerede har gitt produksjonsfeil:
--
--  1) Hjelpefunksjoner kalt UTEN (select ...) -> evalueres per rad ->
--     statement timeout -> 0 rader returnert. Slo ut daglig_salg 2026-06-16,
--     og ble gjeninnfort av 0073 og 0076 etter at 0067 hadde fikset det.
--
--  2) "for all"-policyer paa store tabeller. USING i en FOR ALL-policy
--     gjelder OGSAA select, og permissive policyer OR-es sammen - saa en
--     upakket skrivepolicy trekkes inn i hver eneste leseplan og gjor
--     retailer_id ikke-sargbar. Det gjorde 0067 halvveis virkningslos.
--
--  3) Skrivetilgang til profiler for "authenticated". Rolle og tenant
--     ligger der; kan de PATCHes via PostgREST, er hele RLS-modellen ute
--     av spill (se 0078).
--
-- Kjores mot en base der alle migrasjoner er kjort. Leser kun katalogen -
-- ingen testdata, ingen opprydding, trygt i produksjon.
-- =====================================================================

do $$
declare
  -- Tabeller som vokser med drift. Nye transaksjonstabeller SKAL inn her.
  varme text[] := array[
    'daglig_salg', 'timesalg', 'kassererstatistikk', 'synlig_svinn',
    'regnskapslinjer', 'regnskap_usynlig_svinn', 'rutine_utforinger',
    'sjekkpunkt_svar', 'ik_avlesninger', 'ansatte', 'oppgaver',
    'tablet_meldinger', 'skills_score', 'tildelte_merker',
    'opplaering_skift', 'opplaering_utfort', 'avvik', 'malekort',
    'malekort_scope', 'rutiner',
    -- Oppsett for bemanningsplanleggeren (0081). Faa rader, men de
    -- joines mot timesalg per time - en upakket policy her trekker
    -- per-rad-kall inn i hver eneste planberegning.
    'bemanning_vindu', 'bemanning_krav', 'bemanning_fast_vakt',
    'bemanning_budsjett', 'bemanning_aar', 'bemanning_maned',
    'bemanning_stasjon',
    -- Stemplinger (0088). Vokser med drift: ~130 rader per stasjon per
    -- maaned, og leses per time mot timesalg naar plan males mot faktisk.
    'stempling',
    -- Ansatte og fravaer (0089). Faa rader, men leses i hver planberegning.
    'ansatt_avtale', 'bemanning_fravaer',
    -- Leses paa hver forside for aa filtrere feeden (0083).
    'signal_lukket',
    -- Arbeidsavtaler (0098). Vokser med drift - en rad per generering,
    -- og signerte rader slettes aldri.
    'ansatt_kontrakt',
    -- Tilgangsloggen (0103). Vokser raskest av alle: en rad per oppslag
    -- paa persondata, og den kan aldri slettes.
    'persondata_logg'
  ];
  r record;
  feil int := 0;
begin

  -- --- 1) Upakkede hjelpefunksjonskall paa varme tabeller ---
  for r in
    select tablename, policyname, cmd
    from pg_policies
    where schemaname = 'public'
      and tablename = any(varme)
      -- Vurder USING og WITH CHECK hver for seg: en policy kan ha wrappet
      -- den ene og rå den andre, og da er den fortsatt per-rad på skriv.
      and (
        (coalesce(qual, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(qual, '') !~ '\( SELECT')
        or
        (coalesce(with_check, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(with_check, '') !~ '\( SELECT')
      )
    order by tablename, policyname
  loop
    raise warning 'PER-RAD-KALL  %.% (%) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.tablename, r.policyname, r.cmd;
    feil := feil + 1;
  end loop;

  -- --- 2) "for all"-policyer paa varme tabeller ---
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public' and tablename = any(varme) and cmd = 'ALL'
    order by tablename, policyname
  loop
    raise warning 'FOR ALL  %.% - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.tablename, r.policyname;
    feil := feil + 1;
  end loop;

  -- --- 3) Skrivetilgang til profiler ---
  for r in
    select privilege_type
    from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  loop
    raise warning 'PROFILER SKRIVBAR  authenticated har % - rolle/tenant kan PATCHes via PostgREST',
      r.privilege_type;
    feil := feil + 1;
  end loop;

  -- profiler maa fortsatt kunne LESES, ellers brekker innlogging (dal.ts)
  if not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated' and privilege_type = 'SELECT')
  then
    raise warning 'PROFILER ULESELIG  authenticated mangler SELECT - innlogging vil brekke';
    feil := feil + 1;
  end if;

  if feil > 0 then
    raise exception 'RLS-vakthund: % funn. Se advarslene over.', feil;
  end if;

  raise notice '--- RLS-vakthund: ingen funn paa % varme tabeller ---', array_length(varme, 1);
end $$;
