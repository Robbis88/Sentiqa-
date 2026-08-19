-- =====================================================================
-- Sentiqa - RLS-funn, lesbar utgave
--
-- Samme sjekker som rls_vakthund.sql, men som en SPORRING som returnerer
-- radene i stedet for `raise warning`. Grunnen: Supabase SQL Editor viser
-- ikke advarsler i resultatpanelet, bare unntaket til slutt. En vakthund
-- som sier «46 funn» uten aa vise hvilke, er halvveis ubrukelig.
--
-- Bruk denne for aa SE hva som er galt. Bruk rls_vakthund.sql i CI, der
-- exit-koden er det som betyr noe.
--
-- Leser kun katalogen. Trygt i produksjon.
--
-- LISTENE UNDER SKAL VAERE IDENTISKE med dem i rls_vakthund.sql. De to
-- filene er frittstaaende skript som limes inn, saa de kan ikke dele en
-- modul - listene maa staa i begge. `src/lib/rls/lister.test.ts` sammen-
-- ligner dem og feller CI hvis de gaar fra hverandre.
--
-- Hvorfor det er verdt en egen test: 2026-08-19 hadde denne fila blitt
-- staaende igjen. Vakthunden meldte ETT funn, mens denne viste seks -
-- tre av dem oppdiktede, fordi lista manglet stempling_hendelse og
-- personlig_punkt og hadde beholdt tre opplaring_*-navn som ikke finnes.
-- Verktoyet man bruker for aa SE funnene loy om tabeller som var i
-- orden. Da laerer man seg aa avfeie rapporten, og neste gang den melder
-- noe ekte blir det avfeid ogsaa.
-- =====================================================================

with lister as (
  select
    array[
      'daglig_salg', 'timesalg', 'kassererstatistikk', 'synlig_svinn',
      'regnskapslinjer', 'regnskap_usynlig_svinn', 'rutine_utforinger',
      'sjekkpunkt_svar', 'ik_avlesninger', 'ansatte', 'oppgaver',
      'tablet_meldinger', 'skills_score', 'tildelte_merker',
      'opplaering_skift', 'opplaering_utfort', 'avvik', 'malekort',
      'malekort_scope', 'rutiner',
      'bemanning_vindu', 'bemanning_krav', 'bemanning_fast_vakt',
      'bemanning_budsjett', 'bemanning_aar', 'bemanning_maned',
      'bemanning_stasjon', 'stempling', 'stempling_hendelse',
      'ansatt_avtale', 'bemanning_fravaer',
      'signal_lukket', 'ansatt_kontrakt', 'persondata_logg',
      'kontrolltiltak_bekreftelse',
      'produksjonsplan_hode', 'produksjonsplan_linjer',
      'prognose_treff', 'prognose_kalibrering',
      'vaer', 'trafikk', 'uke_rapport',
      'personlig_kryss', 'personlig_punkt', 'puls_svar', 'varsler',
      'import_jobber', 'raa_filer', 'ai_tool_log',
      'opplaering_periode', 'pengepremie_bruk',
      'tilbakemelding', 'regnskapsanalyser', 'lederstotte_rapporter'
    ]::text[] as varme,
    array[
      'retailers', 'stasjoner', 'profiler', 'butikksjef_stasjoner',
      'anvisninger', 'kunnskap', 'merker', 'lenker', 'kampanjer',
      'konkurranser', 'plattform_innlegg', 'fokuspunkter', 'pengepremie',
      'kontraktmal', 'opplaering_oppgave', 'puls_sporsmal', 'puls_runde',
      'sjekkpunkter', 'rutineskjemaer', 'ik_kontrollpunkter',
      'kalender_kilder', 'arrangementer', 'kategori_vaerprofil',
      'push_abonnementer'
    ]::text[] as kalde
)

-- 1) Upakkede hjelpefunksjonskall paa varme tabeller
select '1 PER-RAD-KALL' as funn, p.tablename as tabell, p.policyname as policy,
       p.cmd as kommando,
       'pakk i (select ...) eller bruk mine_stasjoner()' as gjor
from pg_policies p, lister l
where p.schemaname = 'public'
  and p.tablename = any(l.varme)
  and (
    (coalesce(p.qual, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
     and coalesce(p.qual, '') !~ '\( SELECT')
    or
    (coalesce(p.with_check, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
     and coalesce(p.with_check, '') !~ '\( SELECT')
  )

union all

-- 2) "for all"-policyer paa varme tabeller
select '2 FOR ALL', p.tablename, p.policyname, p.cmd,
       'USING gjelder ogsaa SELECT; splitt i insert/update/delete'
from pg_policies p, lister l
where p.schemaname = 'public' and p.tablename = any(l.varme) and p.cmd = 'ALL'

union all

-- 3) Skrivetilgang til profiler
select '3 PROFILER SKRIVBAR', 'profiler', g.grantee, g.privilege_type,
       'rolle/tenant kan PATCHes via PostgREST - fjern rettigheten'
from information_schema.role_table_grants g
where g.table_schema = 'public' and g.table_name = 'profiler'
  and g.grantee = 'authenticated'
  and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE')

union all

-- 4a) Tabell med policy som ikke staar i noen liste
select '4 UTEN TILSYN', p.tablename, '-', '-',
       'legg i varme eller kalde i rls_vakthund.sql'
from (select distinct tablename from pg_policies where schemaname = 'public') p,
     lister l
where p.tablename <> all(l.varme) and p.tablename <> all(l.kalde)

union all

-- 4b) Tabell i lista som ikke lenger har policy
select '5 FINNES IKKE', t, '-', '-',
       'ingen policy i public; fjern fra listene'
from lister l, unnest(l.varme || l.kalde) as t
where not exists (
  select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t)

order by 1, 2, 3;
