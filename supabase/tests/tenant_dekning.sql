-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEKNINGSKONTROLL. Hver tabell i public skal staa i kontrakten, enten
-- som klassifisert ressurs eller paa lista over uklassifiserte.
--
-- EN NY TABELL STAAR I INGEN AV DEM, og feller derfor denne. Det er
-- meningen: en tabell skal ikke kunne bli usynlig for sikkerhets-
-- systemet fordi ingen husket aa foere den opp.
--
-- Partisjoner er unntatt - de arver forelderens klassifisering, og
-- rettighetene deres vaktes av punkt 10 i rls_vakthund.sql.
do $$
declare
  r record;
  funn text[] := array[]::text[];
  antall_klassifisert int;
begin
  create temp table kontrakt_tabeller (tabell text primary key, klassifisert boolean) on commit drop;

  insert into kontrakt_tabeller (tabell, klassifisert) values
    ('ai_tool_log', false),
    ('ansatt_avtale', false),
    ('ansatt_kontrakt', false),
    ('ansatte', false),
    ('anvisninger', false),
    ('arrangementer', false),
    ('avvik', true),
    ('bemanning_aar', false),
    ('bemanning_budsjett', false),
    ('bemanning_fast_vakt', false),
    ('bemanning_fravaer', false),
    ('bemanning_krav', false),
    ('bemanning_maned', false),
    ('bemanning_stasjon', false),
    ('bemanning_vindu', false),
    ('butikksjef_stasjoner', false),
    ('daglig_salg', false),
    ('fokuspunkter', false),
    ('ik_avlesninger', false),
    ('ik_kontrollpunkter', false),
    ('import_jobber', false),
    ('kalender_kilder', false),
    ('kampanjer', false),
    ('kassererstatistikk', false),
    ('kategori_vaerprofil', false),
    ('konkurranser', false),
    ('kontraktmal', false),
    ('kontrolltiltak_bekreftelse', false),
    ('kunnskap', false),
    ('lederstotte_rapporter', false),
    ('lenker', false),
    ('malekort', true),
    ('malekort_scope', false),
    ('merker', false),
    ('oppgaver', false),
    ('opplaering_oppgave', false),
    ('opplaering_periode', false),
    ('opplaering_skift', false),
    ('opplaering_utfort', true),
    ('oversettelse_cache', true),
    ('pengepremie', false),
    ('pengepremie_bruk', false),
    ('persondata_logg', false),
    ('personlig_kryss', false),
    ('personlig_punkt', false),
    ('pin_forsok', false),
    ('plattform_innlegg', false),
    ('produksjonsplan_hode', false),
    ('produksjonsplan_linjer', false),
    ('profiler', false),
    ('prognose_kalibrering', false),
    ('prognose_treff', false),
    ('puls_runde', false),
    ('puls_sporsmal', false),
    ('puls_svar', false),
    ('push_abonnementer', false),
    ('raa_filer', false),
    ('regnskap_usynlig_svinn', false),
    ('regnskapsanalyser', false),
    ('regnskapslinjer', false),
    ('retailers', false),
    ('rutine_utforinger', true),
    ('rutiner', false),
    ('rutineskjemaer', false),
    ('signal_lukket', false),
    ('sjekkpunkt_svar', false),
    ('sjekkpunkter', false),
    ('skills_score', false),
    ('stasjoner', false),
    ('stempling', false),
    ('stempling_hendelse', true),
    ('synlig_svinn', false),
    ('tablet_meldinger', false),
    ('tilbakemelding', false),
    ('tildelte_merker', false),
    ('timesalg', false),
    ('trafikk', false),
    ('uke_rapport', false),
    ('vaer', false),
    ('varsler', false);

  select count(*) into antall_klassifisert from kontrakt_tabeller where klassifisert;

  -- KANARIFUGL. En kontrakt uten klassifiserte rader ville gjort hele
  -- sjekken stille - og "ingen funn" ser da noeyaktig ut som en base
  -- uten problemer.
  if antall_klassifisert = 0 then
    raise exception 'TENANT-DEKNING: kontrakten har ingen klassifiserte ressurser - maaler denne sjekken noe?';
  end if;

  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (select 1 from kontrakt_tabeller kt where kt.tabell = c.relname)
    order by c.relname
  loop
    funn := funn || format('UKLASSIFISERT  public.%s  - foer den opp i supabase/tenant-kontrakt.json. Gjett aldri klassifiseringen; den skal settes av noen som har tatt stilling.', r.relname);
  end loop;

  -- Motsatt vei: en kontraktrad uten tabell er en fasit som har raatnet.
  for r in
    select kt.tabell
    from kontrakt_tabeller kt
    where to_regclass('public.' || quote_ident(kt.tabell)) is null
    order by kt.tabell
  loop
    funn := funn || format('KONTRAKT UTEN TABELL  %s  - staar i kontrakten, men finnes ikke i basen.', r.tabell);
  end loop;

  if array_length(funn, 1) > 0 then
    raise exception '%', format('TENANT-DEKNING: %s funn%s%s',
      array_length(funn, 1), chr(10) || chr(10), array_to_string(funn, chr(10)));
  end if;

  raise notice '--- Tenant-dekning: ingen funn. % klassifisert, % uklassifiserte staar igjen ---',
    antall_klassifisert, (select count(*) from kontrakt_tabeller where not klassifisert);
end $$;
