-- =====================================================================
-- Hva ser kassererdataene faktisk ut som?
--
-- REN LESING. Ingen tabeller, views, funksjoner, policyer eller data
-- roeres. Trygg i produksjon.
--
-- HVORFOR DENNE KJOERES FOER NOE BYGGES
--
-- /kasserer viser i dag én dag, i kroner, sortert paa omsetning, med en
-- grense paa 2 % av omsetningen. Ingen av de fire valgene er maalt:
--
--   én dag        en kasserer med én vakt og én retur ser lik ut som et
--                 moenster
--   kroner        den som selger tre ganger saa mye har tre ganger saa
--                 mye retur, uten at noe er galt
--   omsetning     rangeringen svarer paa «hvem selger mest», ikke paa
--                 det sida finnes for
--   2 %           tallet er skrevet av noen, ikke lest ut av data
--
-- Robert, i oppdraget: «Foer vi bestemmer selve flaggterskelen skal du
-- kartlegge fordelingen i ekte data. Ikke finn paa en prosentgrense.»
-- Denne fila er den kartleggingen.
--
-- ---------------------------------------------------------------------
-- KORNET ER (stasjon, kasserer_nr, maaned)
--
-- `kasserer_nr` er en FJERDE identitet, ved siden av de tre i
-- [[sentiqa-tre-identiteter]]: ansatt_nr fra easy@work, ansatte.id fra
-- PIN, og fritekst navn. Den er ikke koblet til noen av dem, og denne
-- sonden kobler den ikke. `kasserer_navn` telles bare for aa se om det
-- samme nummeret har baaret flere navn - ikke for aa peke ut noen.
--
-- ---------------------------------------------------------------------
-- HVA SVARET SKAL BRUKES TIL
--
--   del 2  hvilke numre er system/ukjent, og hvor mye volum har de
--   del 3  hvor stort grunnlag har en kasserer i en maaned - under en
--          viss mengde bonger kan ingen rate tolkes
--   del 4  selve fordelingen: avvik per 100 bonger, og som andel av
--          omsetning. Terskelen skal leses HER, ikke velges.
--   del 5  varierer en kasserer mot SEG SELV fra maaned til maaned?
--          Er spredningen stor, er «egen historikk» ikke et grunnlag
--          heller, og da skal ingenting flagges i det hele tatt.
--   del 6  fortegn og hull - er belop positive, finnes antall uten
--          belop, finnes omsetning uten bonger
--
-- Kolonnene er de samme i hver gren: del, hva, stasjon, maal, verdi,
-- n, p50, p90, p99, maks.
-- =====================================================================

with

stasj as (
  select id, butikknummer || ' ' || navn as stasjon
  from public.stasjoner
  where slettet_tid is null
),

vindu as (
  select (current_date - interval '13 months')::date as fra,
         current_date                                as til
),

-- Én rad per kasserer per maaned. Maaned fordi en dag er for lite til
-- aa si noe, og et aar skjuler naar noe endret seg.
km as (
  select k.stasjon_id,
         nullif(btrim(k.kasserer_nr), '')       as nr,
         date_trunc('month', k.dato)::date      as maned,
         count(distinct k.dato)                 as dager,
         sum(coalesce(k.bonger, 0))             as bonger,
         sum(coalesce(k.omsetning_ink_mva, 0))  as oms,
         sum(coalesce(k.retur_belop, 0))        as retur_kr,
         sum(coalesce(k.makulerte_belop, 0))    as mak_kr,
         sum(coalesce(k.slettede_belop, 0))     as slett_kr,
         sum(coalesce(k.retur_antall, 0))       as retur_ant,
         sum(coalesce(k.makulerte_antall, 0))   as mak_ant,
         sum(coalesce(k.slettede_antall, 0))    as slett_ant
  from public.kassererstatistikk k, vindu v
  where k.slettet_tid is null
    and k.dato between v.fra and v.til
    and nullif(btrim(k.kasserer_nr), '') is not null
  group by k.stasjon_id, nullif(btrim(k.kasserer_nr), ''),
           date_trunc('month', k.dato)::date
),

-- SYSTEMNUMRE SKILLES UT, IKKE SLETTES. 999999 og liknende er kassa
-- selv, ikke en medarbeider, og skal aldri rangeres som en. Men volumet
-- deres maa vi se, ellers vet vi ikke hvor mye av bildet de utgjoer.
km_m as (
  select km.*,
         (km.nr ~ '^9+$' or km.nr ~ '^0+$' or km.nr !~ '^[0-9]+$') as systemaktig,
         km.retur_kr + km.mak_kr + km.slett_kr                     as avvik_kr,
         km.retur_ant + km.mak_ant + km.slett_ant                  as avvik_ant
  from km
),

rate as (
  select m.*,
         m.avvik_kr  / nullif(m.bonger, 0) * 100 as kr_per_100,
         m.avvik_ant / nullif(m.bonger, 0) * 100 as ant_per_100,
         m.avvik_kr  / nullif(m.oms, 0) * 100    as andel_oms
  from km_m m
),

-- NAVN TELLES FRA TABELLEN, ikke fra `km`. Der er navnene allerede
-- aggregert bort per maaned, og «antall distinkte maanedstall» er ikke
-- et svar paa «hvor mange navn har dette nummeret baaret».
navn as (
  select k.stasjon_id,
         nullif(btrim(k.kasserer_nr), '')                    as nr,
         count(distinct nullif(btrim(k.kasserer_navn), ''))  as ulike_navn,
         min(nullif(btrim(k.kasserer_navn), ''))             as ett_navn,
         max(nullif(btrim(k.kasserer_navn), ''))             as et_annet
  from public.kassererstatistikk k, vindu v
  where k.slettet_tid is null
    and k.dato between v.fra and v.til
    and nullif(btrim(k.kasserer_nr), '') is not null
  group by k.stasjon_id, nullif(btrim(k.kasserer_nr), '')
),

-- Kasserere med minst tre maaneder: bare de kan maales mot SEG SELV.
egen as (
  select stasjon_id, nr,
         count(*)                                as maaneder,
         min(kr_per_100)                         as min_rate,
         max(kr_per_100)                         as maks_rate,
         avg(kr_per_100)                         as snitt_rate
  from rate
  where not systemaktig and bonger >= 100 and kr_per_100 is not null
  group by stasjon_id, nr
  having count(*) >= 3
)

-- =====================================================================
-- 1  GRUNNLAG
-- =====================================================================
select 1 as del, 'GRUNNLAG' as hva, st.stasjon as stasjon,
       'kasserer-maaneder' as maal,
       min(r.maned)::text || ' -> ' || max(r.maned)::text as verdi,
       count(*)::numeric as n,
       count(distinct r.nr)::numeric as p50,
       count(distinct r.maned)::numeric as p90,
       sum(r.dager)::numeric as p99,
       null::numeric as maks
from rate r join stasj st on st.id = r.stasjon_id
group by st.stasjon

-- =====================================================================
-- 2  NUMRENE - hvem er ikke en medarbeider
-- =====================================================================
union all
select 2, 'SYSTEMNUMMER', st.stasjon,
       'nr=' || r.nr,
       case when r.systemaktig then 'systemaktig' else 'vanlig' end,
       count(*)::numeric,
       sum(r.bonger)::numeric,
       sum(r.oms)::numeric,
       sum(r.avvik_kr)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
where r.systemaktig
group by st.stasjon, r.nr, r.systemaktig

union all
select 2, 'SYSTEMANDEL', st.stasjon,
       'andel av bonger og avvik som ligger paa systemnumre',
       null::text,
       sum(r.bonger) filter (where r.systemaktig)::numeric,
       sum(r.bonger)::numeric,
       sum(r.avvik_kr) filter (where r.systemaktig)::numeric,
       sum(r.avvik_kr)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
group by st.stasjon

-- SAMME NUMMER, FLERE NAVN. Skjer det, er `kasserer_navn` ikke en
-- identitet - og sida skal ikke vise navnet som om det var én person.
union all
select 2, 'FLERE NAVN', st.stasjon,
       'nr=' || n.nr,
       n.ett_navn || ' / ' || n.et_annet,
       n.ulike_navn::numeric,
       null::numeric, null::numeric, null::numeric, null::numeric
from navn n join stasj st on st.id = n.stasjon_id
where n.ulike_navn > 1

-- OG MOTSATT VEI: samme navn paa flere numre. Da er navnet heller ikke
-- entydig nedover, og en «kasserer» i lista kan vaere to personer -
-- eller én person med to numre. Sida skal uansett ikke koble paa navn.
union all
select 2, 'SAMME NAVN, FLERE NUMRE', st.stasjon,
       'navn=' || y.navnet,
       null::text,
       y.numre::numeric,
       null::numeric, null::numeric, null::numeric, null::numeric
from (
  select k.stasjon_id,
         nullif(btrim(k.kasserer_navn), '')               as navnet,
         count(distinct nullif(btrim(k.kasserer_nr), '')) as numre
  from public.kassererstatistikk k, vindu v
  where k.slettet_tid is null
    and k.dato between v.fra and v.til
    and nullif(btrim(k.kasserer_navn), '') is not null
  group by k.stasjon_id, nullif(btrim(k.kasserer_navn), '')
  having count(distinct nullif(btrim(k.kasserer_nr), '')) > 1
) y join stasj st on st.id = y.stasjon_id

-- =====================================================================
-- 3  GRUNNLAGSSTOERRELSE - naar er en rate i det hele tatt lesbar
-- =====================================================================
union all
select 3, 'BONGER PER MAANED', st.stasjon,
       'fordeling, kasserer-maaneder uten systemnumre',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by r.bonger)::numeric,
       percentile_cont(0.9)  within group (order by r.bonger)::numeric,
       percentile_cont(0.99) within group (order by r.bonger)::numeric,
       max(r.bonger)::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig
group by st.stasjon

union all
select 3, 'FOR LITE GRUNNLAG', st.stasjon,
       'kasserer-maaneder under 50 / 100 / 500 bonger',
       null::text,
       count(*) filter (where r.bonger < 50)::numeric,
       count(*) filter (where r.bonger < 100)::numeric,
       count(*) filter (where r.bonger < 500)::numeric,
       count(*)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig
group by st.stasjon

-- =====================================================================
-- 4  FORDELINGEN - her skal terskelen LESES, ikke velges
-- =====================================================================
union all
select 4, 'AVVIK KR PER 100 BONGER', st.stasjon,
       'kasserer-maaneder med minst 100 bonger',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by r.kr_per_100)::numeric,
       percentile_cont(0.9)  within group (order by r.kr_per_100)::numeric,
       percentile_cont(0.99) within group (order by r.kr_per_100)::numeric,
       max(r.kr_per_100)::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig and r.bonger >= 100 and r.kr_per_100 is not null
group by st.stasjon

union all
select 4, 'AVVIK ANTALL PER 100 BONGER', st.stasjon,
       'kasserer-maaneder med minst 100 bonger',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by r.ant_per_100)::numeric,
       percentile_cont(0.9)  within group (order by r.ant_per_100)::numeric,
       percentile_cont(0.99) within group (order by r.ant_per_100)::numeric,
       max(r.ant_per_100)::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig and r.bonger >= 100 and r.ant_per_100 is not null
group by st.stasjon

-- ER 2 % I NAERHETEN AV NOE? Grensa som staar i sida i dag maales mot
-- den fordelingen den skal dele.
union all
select 4, 'AVVIK SOM ANDEL AV OMSETNING', st.stasjon,
       'prosent - dagens grense i sida er 2',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by r.andel_oms)::numeric,
       percentile_cont(0.9)  within group (order by r.andel_oms)::numeric,
       percentile_cont(0.99) within group (order by r.andel_oms)::numeric,
       max(r.andel_oms)::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig and r.bonger >= 100 and r.andel_oms is not null
group by st.stasjon

union all
select 4, 'OVER 2 PROSENT', st.stasjon,
       'hvor mange kasserer-maaneder dagens grense ville felt',
       null::text,
       count(*) filter (where r.andel_oms > 2)::numeric,
       count(*)::numeric,
       null::numeric, null::numeric, null::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig and r.bonger >= 100 and r.andel_oms is not null
group by st.stasjon

-- De tre typene betyr ikke det samme, og skal kanskje ikke summeres.
union all
select 4, 'TYPEFORDELING KR', st.stasjon,
       'retur / makulert / slettet, sum kroner',
       null::text,
       sum(r.retur_kr)::numeric,
       sum(r.mak_kr)::numeric,
       sum(r.slett_kr)::numeric,
       sum(r.avvik_kr)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
where not r.systemaktig
group by st.stasjon

-- =====================================================================
-- 5  EGEN HISTORIKK - er en kasserer stabil mot seg selv?
-- =====================================================================
union all
select 5, 'EGEN SPREDNING', st.stasjon,
       'maks minus min i egen kr per 100, kasserere med 3+ maaneder',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by e.maks_rate - e.min_rate)::numeric,
       percentile_cont(0.9)  within group (order by e.maks_rate - e.min_rate)::numeric,
       percentile_cont(0.99) within group (order by e.maks_rate - e.min_rate)::numeric,
       max(e.maks_rate - e.min_rate)::numeric
from egen e join stasj st on st.id = e.stasjon_id
group by st.stasjon

union all
select 5, 'EGEN SNITTRATE', st.stasjon,
       'snitt kr per 100 per kasserer - spennet MELLOM kasserere',
       null::text,
       count(*)::numeric,
       percentile_cont(0.5)  within group (order by e.snitt_rate)::numeric,
       percentile_cont(0.9)  within group (order by e.snitt_rate)::numeric,
       percentile_cont(0.99) within group (order by e.snitt_rate)::numeric,
       max(e.snitt_rate)::numeric
from egen e join stasj st on st.id = e.stasjon_id
group by st.stasjon

-- SPREDNING MOT SPENN. Er spredningen INNI én kasserer like stor som
-- spennet MELLOM kasserere, skiller ikke tallet folk fra hverandre - det
-- skiller maaneder fra hverandre. Da skal ingenting flagges.
union all
select 5, 'HVOR MANGE HAR NOK HISTORIKK', st.stasjon,
       'kasserere med 3+ maaneder og 100+ bonger',
       null::text,
       count(*)::numeric,
       (select count(distinct nr) from km_m k2 where k2.stasjon_id = e.stasjon_id
        and not k2.systemaktig)::numeric,
       null::numeric, null::numeric, null::numeric
from egen e join stasj st on st.id = e.stasjon_id
group by st.stasjon, e.stasjon_id

-- =====================================================================
-- 6  FORTEGN OG HULL
-- =====================================================================
union all
select 6, 'FORTEGN', st.stasjon,
       'negative belop: retur / makulert / slettet',
       null::text,
       count(*) filter (where r.retur_kr < 0)::numeric,
       count(*) filter (where r.mak_kr < 0)::numeric,
       count(*) filter (where r.slett_kr < 0)::numeric,
       count(*)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
group by st.stasjon

union all
select 6, 'HULL', st.stasjon,
       'bonger=0 med omsetning / omsetning=0 med bonger / avvik uten bonger',
       null::text,
       count(*) filter (where r.bonger = 0 and r.oms <> 0)::numeric,
       count(*) filter (where r.oms = 0 and r.bonger <> 0)::numeric,
       count(*) filter (where r.avvik_kr <> 0 and r.bonger = 0)::numeric,
       count(*)::numeric,
       null::numeric
from rate r join stasj st on st.id = r.stasjon_id
group by st.stasjon

union all
select 6, 'ANTALL UTEN BELOP', st.stasjon,
       'avvik_antall > 0 men avvik_kr = 0',
       null::text,
       count(*) filter (where r.avvik_ant > 0 and r.avvik_kr = 0)::numeric,
       count(*) filter (where r.avvik_ant = 0 and r.avvik_kr <> 0)::numeric,
       count(*)::numeric,
       null::numeric, null::numeric
from rate r join stasj st on st.id = r.stasjon_id
group by st.stasjon

order by del, hva, stasjon, n desc nulls last, maal;
