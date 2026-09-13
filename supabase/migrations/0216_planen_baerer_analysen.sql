-- =====================================================================
-- 0216  PLANEN BAERER ANALYSEN, SOM ET OEYEBLIKKSBILDE
-- =====================================================================
-- `byggMaanedsplan` returnerer `matkast` og `usynlig` etter PR 279, men
-- `lagre.ts` skrev bare `dom`, `ingress`, `punkter` og `merknad`. De to
-- ble kastet, og flaten kunne ikke vise et eneste av tallene.
--
-- ---------------------------------------------------------------------
-- HVORFOR LAGRE, OG IKKE REGNE PAA NYTT NAAR SIDA AAPNES
--
-- To grunner, og den andre er den tyngste:
--
--   1  To sannhetsmotorer. En beregning i UI-et ved siden av den i
--      `kastvurdering.ts` ville drevet fra hverandre.
--
--   2  EN GODKJENT PLAN SKAL IKKE ENDRE INNHOLD. Eieren leser et utkast,
--      tar stilling og slipper det. Regnet vi paa nytt naar e-posten
--      bygges, kunne butikksjefen faatt andre tall enn de eieren
--      godkjente - uten at noen hadde gjort noe galt. En reimport, en ny
--      delingsfil eller en rettet migrasjon holder for aa flytte dem.
--
-- Det som godkjennes, lagres og sendes er samme oeyeblikksbilde.
--
-- ---------------------------------------------------------------------
-- VERSJONSINFORMASJON I SNAPSHOTET
--
-- `analyseversjon`, `beregnet_for_maaned` og `beregnet_tid` ligger inne
-- i jsonb-en. Uten dem kan ingen forklare hvorfor en plan fra august ser
-- annerledes ut enn en fra oktober - og «den er gammel» er ikke et svar
-- man kan handle paa.
--
-- ---------------------------------------------------------------------
-- GAMLE PLANER ER `null`, OG DET ER IKKE DET SAMME SOM BLOKKERT
--
-- En plan uten `matkast` ble aldri analysert med denne motoren. Flaten
-- skal si «Ikke beregnet - planen ble laget foer mat- og svinnanalysen
-- var tilgjengelig», ikke «blokkert»: blokkert betyr at vi proevde og
-- stoppet med en aarsak, og det er en helt annen beskjed.
--
-- ---------------------------------------------------------------------
-- ADDITIV OG BAKOVERKOMPATIBEL. To nullable kolonner. Ingen eksisterende
-- leser roerer dem, og `punkter` staar uendret ved siden av. Kjoeres FOER
-- koden deployes, slik `0213`-`0215` ble.
--
-- Idempotent: `add column if not exists`.
-- =====================================================================

alter table public.maanedsplan
  add column if not exists matkast jsonb,
  add column if not exists usynlig jsonb;

comment on column public.maanedsplan.matkast is
  'Oeyeblikksbilde av synlig matkast mot omsetningsjustert kastbudsjett: '
  '{analyseversjon, beregnetForMaaned, beregnetTid, dom, blokkering}. '
  'NULL betyr at planen ble laget foer analysen fantes - ikke at den er '
  'blokkert.';

comment on column public.maanedsplan.usynlig is
  'Oeyeblikksbilde av uforklart matavvik: {analyseversjon, '
  'beregnetForMaaned, beregnetTid, naaKr, kurs, vindu, usikker, '
  'aarsakUsikker, blokkering}. NULL som over.';

-- ---------------------------------------------------------------------
-- KVITTERING. Rent lesende.
--
-- Ingen eksisterende rad skal ha faatt innhold av denne migrasjonen -
-- den legger bare til kolonnene. `uten_analyse` skal derfor vaere lik
-- `rader` rett etter kjoering, og synke etter hvert som nye planer
-- skrives av den deployede koden.
-- ---------------------------------------------------------------------
select
  case
    when not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'maanedsplan'
         and column_name = 'matkast')
      then 'FEIL: kolonnen matkast finnes ikke'
    when not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'maanedsplan'
         and column_name = 'usynlig')
      then 'FEIL: kolonnen usynlig finnes ikke'
    else 'OK'
  end                                                        as dom,
  (select count(*) from public.maanedsplan)                  as rader,
  (select count(*) from public.maanedsplan where matkast is null) as uten_matkast,
  (select count(*) from public.maanedsplan where usynlig is null) as uten_usynlig,
  (select count(*) from public.maanedsplan where status = 'utkast') as utkast,
  (select count(*) from public.maanedsplan where status <> 'utkast') as avgjort,
  (select coalesce(string_agg(distinct data_type, ', '), '-')
     from information_schema.columns
    where table_schema = 'public' and table_name = 'maanedsplan'
      and column_name in ('matkast', 'usynlig'))             as kolonnetype;
