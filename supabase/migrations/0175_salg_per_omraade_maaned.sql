-- =====================================================================
-- NEVNEREN BLE HENTET RAD FOR RAD, OG POSTGREST KUTTET DEN
--
-- `/svinn` viste 778,6 % kast av omsetning og et budsjett paa 2 983 kr
-- der kravet er 13,59 % og aarsbudsjettet 238 393. Telleren var riktig -
-- 170 880 kastet, summert av `regnskap_usynlig_svinn`, som har ÉN rad
-- per kode per maaned og ligger godt under enhver grense.
--
-- Nevneren var ikke. `hent-budsjett.ts` leste `v_butikksalg` RAD FOR RAD
-- - én rad per dag per EAN - med `.limit(50000)`. PostgREST svarer med
-- sitt eget tak, og over det taket kommer det ingen feil: bare faerre
-- rader.
--
--     MAT-salget for Boenes 2026:   1 220 436 kr
--     det siden fikk se:               21 950 kr
--
-- Under to prosent av nevneren, og en prosent som blir 778.
--
-- ---------------------------------------------------------------------
-- TREDJE GANG SAMME FEIL
--
-- `0090` rettet den ett sted. `0166` rettet den paa `/regnskap`, der
-- maanedsvelgeren mistet de eldste maanedene fordi `select('periode')`
-- kuttet paa tusen LINJER, ikke tusen maaneder.
--
-- Formen er den samme hver gang: en spoerring som henter detaljrader for
-- aa summere dem i TypeScript. Det gaar bra til datamengden vokser forbi
-- taket, og da svarer den fortsatt - med et mindre tall.
--
-- **En avkortet spoerring ser ut som en liten stasjon.** Det er derfor
-- den er farlig: ingenting feiler, tallet er bare mindre enn det skulle.
--
-- Regelen: SUMMÉR I BASEN. Skal et tall aggregeres over mer enn noen faa
-- hundre rader, hoerer summeringen hjemme i et view eller en funksjon.
--
-- ---------------------------------------------------------------------
-- HVORFOR AVDELING OG VAREOMRAADE I SAMME RAD
--
-- Kastbudsjettet finnes paa to nivaaer, og hvilket avhenger av
-- filvarianten: 2025-fila har de seks undergruppene, 2026-fila bare
-- Mat-totalen. Viewet baerer derfor begge kodene, og kallstedet ruller
-- opp til det nivaaet budsjettet faktisk staar paa.
--
-- Maalt paa produksjon 2026-09-05 er kodene tre og to siffer:
--
--     avdeling_kode     120 MAT, 130 VARM DRIKKE, 210 BILVASK
--     vareomrade_kode   10 BAKERI, 11 POELSE, 15 PAASMURT
--
-- og regnskapets `12010` er nettopp de to satt sammen. Det er koblingen
-- mellom kildene, og den er maalt - ikke antatt.
--
-- ---------------------------------------------------------------------
-- SVINNET ER MED I SAMME VIEW, OG DET ER MED VILJE
--
-- `synlig_svinn` baerer bare EAN. Omraadet maa komme fra salgsdataene,
-- og den koblingen ble ogsaa gjort rad for rad i TypeScript - av de
-- samme avkortede radene. Var EAN-en ikke blant de tusen, ble varen
-- talt som «ikke koblet».
--
-- Ett view som baerer begge sider gjoer at de aldri kan hentes med hvert
-- sitt utvalg.
--
-- Idempotent: `create or replace view`.
-- =====================================================================

create or replace view public.v_salg_omraade_maaned
-- `security_invoker` MAA staa her. Uten den leser viewet som eieren,
-- forbi RLS - og en `create or replace` uten klausulen nullstiller
-- flagget i stillhet. Vakthundens punkt 9 kaster paa begge deler.
with (security_invoker = true) as
with salg as (
  select v.retailer_id,
         v.stasjon_id,
         date_trunc('month', v.dato)::date as maned,
         v.avdeling_kode,
         v.vareomrade_kode,
         sum(v.omsetning_eks_mva) as omsetning_kr
  from public.v_butikksalg v
  where v.dato is not null
  group by v.retailer_id, v.stasjon_id, date_trunc('month', v.dato)::date,
           v.avdeling_kode, v.vareomrade_kode
),
-- EAN til omraade. RLS paa `daglig_salg` avgrenser den til kallerens
-- egen kjede, saa oppslaget er ikke saa bredt som det ser ut.
--
-- `min()` og ikke `distinct`: en EAN som har ligget under to omraader
-- over tid maa gi ÉN rad, ellers dubleres svinnet i joinen under.
ean_omrade as (
  select v.retailer_id,
         v.ean,
         min(v.avdeling_kode)   as avdeling_kode,
         min(v.vareomrade_kode) as vareomrade_kode
  from public.v_butikksalg v
  where v.ean is not null
  group by v.retailer_id, v.ean
),
svinn as (
  select s.retailer_id,
         s.stasjon_id,
         date_trunc('month', s.dato)::date as maned,
         o.avdeling_kode,
         o.vareomrade_kode,
         sum(s.nettopris_total) as svinn_kr
  from public.synlig_svinn s
  join ean_omrade o
    on o.retailer_id = s.retailer_id and o.ean = s.ean
  where s.slettet_tid is null
    and s.dato is not null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.dato)::date,
           o.avdeling_kode, o.vareomrade_kode
)
-- FULL JOIN: en maaned kan ha salg uten svinn (helt normalt) og svinn
-- uten salg (en vare tatt ut av sortimentet). Faller den ene bort, blir
-- broeken feil paa nytt - bare mindre synlig enn 778 %.
select coalesce(sa.retailer_id, sv.retailer_id)         as retailer_id,
       coalesce(sa.stasjon_id, sv.stasjon_id)           as stasjon_id,
       coalesce(sa.maned, sv.maned)                     as maned,
       coalesce(sa.avdeling_kode, sv.avdeling_kode)     as avdeling_kode,
       coalesce(sa.vareomrade_kode, sv.vareomrade_kode) as vareomrade_kode,
       coalesce(sa.omsetning_kr, 0)                     as omsetning_kr,
       coalesce(sv.svinn_kr, 0)                         as svinn_kr
from salg sa
full join svinn sv
  on  sv.stasjon_id = sa.stasjon_id
  and sv.maned = sa.maned
  and sv.avdeling_kode is not distinct from sa.avdeling_kode
  and sv.vareomrade_kode is not distinct from sa.vareomrade_kode;

comment on view public.v_salg_omraade_maaned is
  'Omsetning og synlig svinn per stasjon, maaned, avdeling og vareomraade. '
  'Finnes for at kastbudsjettet skal kunne maales mot salget uten aa hente '
  'detaljrader - PostgREST kuttet det uttrekket paa tusen rader og gjorde '
  'nevneren til under to prosent av seg selv.';

-- BEGGE LINJENE, HVER GANG. Supabase-standarden
-- `alter default privileges in schema public grant all on tables to anon,
-- authenticated, service_role` treffer ogsaa hver ny view - `anon` er
-- rollen bak den offentlige noekkelen i hver sidelast. Se 0130 og 0134.
grant select on public.v_salg_omraade_maaned to authenticated;
revoke all on public.v_salg_omraade_maaned from anon;

-- Kvittering. `raise notice` vises ikke i SQL Editor - se 0145.
select (to_regclass('public.v_salg_omraade_maaned') is not null) as viewet_finnes,
       (select count(*) from pg_views
         where schemaname = 'public'
           and viewname = 'v_salg_omraade_maaned'
           and definition ilike '%v_butikksalg%')                as leser_butikksalg,
       (select count(*) from information_schema.role_table_grants
         where table_schema = 'public'
           and table_name = 'v_salg_omraade_maaned'
           and grantee = 'anon')                                 as anon_skal_vaere_0;
