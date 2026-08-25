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
  create temp table kontrakt_tabeller (
    tabell text primary key, klassifisert boolean, uten_policy_ok boolean
  ) on commit drop;

  insert into kontrakt_tabeller (tabell, klassifisert, uten_policy_ok) values
    ('ai_tool_log', false, false),
    ('ansatt_avtale', false, false),
    ('ansatt_kontrakt', false, false),
    ('ansatte', true, false),
    ('anvisninger', false, false),
    ('arrangementer', false, false),
    ('avvik', true, false),
    ('bemanning_aar', false, false),
    ('bemanning_budsjett', false, false),
    ('bemanning_fast_vakt', false, false),
    ('bemanning_fravaer', false, false),
    ('bemanning_krav', false, false),
    ('bemanning_maned', false, false),
    ('bemanning_stasjon', true, false),
    ('bemanning_vindu', false, false),
    ('butikksjef_stasjoner', false, false),
    ('daglig_salg', false, false),
    ('fokuspunkter', false, false),
    ('ik_avlesninger', false, false),
    ('ik_kontrollpunkter', false, false),
    ('import_jobber', false, false),
    ('kalender_kilder', false, false),
    ('kampanjer', false, false),
    ('kassererstatistikk', false, false),
    ('kategori_vaerprofil', false, false),
    ('konkurranser', false, false),
    ('kontraktmal', false, false),
    ('kontrolltiltak_bekreftelse', false, false),
    ('kunnskap', false, false),
    ('lederstotte_rapporter', false, false),
    ('lenker', false, false),
    ('malekort', true, false),
    ('malekort_scope', false, false),
    ('merker', false, false),
    ('oppgaver', false, false),
    ('opplaering_oppgave', false, false),
    ('opplaering_periode', false, false),
    ('opplaering_skift', false, false),
    ('opplaering_utfort', true, false),
    ('oversettelse_cache', true, true),
    ('pengepremie', false, false),
    ('pengepremie_bruk', true, false),
    ('persondata_logg', false, false),
    ('personlig_kryss', false, false),
    ('personlig_punkt', false, false),
    ('pin_forsok', false, false),
    ('plattform_innlegg', false, false),
    ('produksjonsplan_hode', true, false),
    ('produksjonsplan_linjer', true, false),
    ('profiler', false, false),
    ('prognose_kalibrering', false, false),
    ('prognose_treff', false, false),
    ('puls_runde', false, false),
    ('puls_sporsmal', false, false),
    ('puls_svar', false, false),
    ('push_abonnementer', false, false),
    ('raa_filer', false, false),
    ('regnskap_usynlig_svinn', false, false),
    ('regnskapsanalyser', false, false),
    ('regnskapslinjer', false, false),
    ('retailers', false, false),
    ('rutine_utforinger', true, false),
    ('rutiner', false, false),
    ('rutineskjemaer', false, false),
    ('signal_lukket', false, false),
    ('sjekkpunkt_svar', false, false),
    ('sjekkpunkter', false, false),
    ('skills_score', true, false),
    ('stasjoner', false, false),
    ('stempling', false, false),
    ('stempling_hendelse', true, false),
    ('synlig_svinn', false, false),
    ('tablet_meldinger', true, false),
    ('tilbakemelding', false, false),
    ('tildelte_merker', false, false),
    ('timesalg', false, false),
    ('trafikk', false, false),
    ('uke_rapport', false, false),
    ('vaer', false, false),
    ('varsler', false, false);

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

  -- TABELLER UTEN POLICY SKAL VAERE ET FUNN, IKKE USYNLIGE.
  --
  -- Vakthundens dekningssjekk (punkt 4) starter fra pg_policies og ser
  -- derfor bare tabeller SOM HAR policy. En tabell uten policy faller
  -- utenfor den - og ser da noeyaktig ut som en tabell uten problemer.
  -- Slik havnet oversettelse_cache utenfor hver liste i to aar.
  --
  -- Denne starter fra pg_class: alle faktiske databaseobjekter. Er
  -- fravaeret av policy bevisst, skal det staa som ingen_policy i
  -- kontrakten - da er den sett og begrunnet.
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = c.relname)
      and not exists (
        select 1 from kontrakt_tabeller kt
        where kt.tabell = c.relname and kt.uten_policy_ok)
    order by c.relname
  loop
    funn := funn || format('UTEN POLICY  public.%s  - har ingen policy i det hele tatt. Er det med vilje, sett ingen_policy med begrunnelse i kontrakten. RLS uten policy nekter alt, men det skal staa at noen har bestemt det.', r.relname);
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
