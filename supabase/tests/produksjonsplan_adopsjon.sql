-- =====================================================================
-- Finnes det en FOER og en ETTER?
--
-- REN LESING. Ingen tabeller, views, funksjoner, policyer eller data
-- roeres. Trygg i produksjon.
--
-- ---------------------------------------------------------------------
-- HVA SPOERSMAALET ER
--
-- Robert, 2026-08-24: «svinn kan bare brukes til kontroll og sjekke om
-- det faktisk gaar ned etter de har brukt produksjonsplan.»
--
-- Det er en maaling PAA systemet, ikke en inngang TIL det - motoren
-- selv rører ikke svinn, og en vakt i
-- `src/lib/produksjonsplan.grense.test.ts` holder den derfra.
--
-- Men en foer/etter-maaling krever at det FINNES et foer og et etter.
-- Har ingen stasjon publisert en plan, eller publiserte alle fra samme
-- dag, er det ingenting aa sammenligne. Denne sonden svarer paa det, og
-- ikke noe mer.
--
-- ---------------------------------------------------------------------
-- TRE TING SOM MAA STEMME FOER KONTROLLEN KAN BYGGES
--
--   1  ADOPSJON. Naar begynte hver stasjon aa publisere planer, og
--      hvor jevnt gjoer de det? En stasjon som publiserte tre dager i
--      mars og aldri siden har ikke «tatt planen i bruk».
--
--   2  SVINN I DE RIKTIGE VAREGRUPPENE. Planen daekker bakevarer og
--      varmmat. Maales totalsvinnet, drukner virkningen i tobakk og
--      kiosk - og en endring der har ingenting med planen aa gjoere.
--
--   3  SAMMENLIGNBAR REGISTRERING. Foeringsdagene varierer fra 34 % til
--      93 % mellom stasjonene (kasserer- og svinnsonden, 2026-08-24).
--      Faller foeringen samtidig som planen tas i bruk, ser svinnet ut
--      til aa gaa ned uten at noe er kastet mindre. Det er den mest
--      sannsynlige maaten denne maalingen kan lyve paa.
--
-- Kolonnene er de samme i hver gren:
-- del, hva, stasjon, maal, verdi, n, a, b, c.
-- =====================================================================

with

stasj as (
  select id, butikknummer || ' ' || navn as stasjon
  from public.stasjoner
  where slettet_tid is null
),

vindu as (
  select (current_date - interval '18 months')::date as fra,
         current_date                                as til
),

-- Publiserte planer. `publisert_tid` er signalet: en plan som er lagd
-- men aldri publisert har ingen naadd.
publisert as (
  select h.stasjon_id,
         h.dato,
         date_trunc('month', h.dato)::date as maned
  from public.produksjonsplan_hode h, vindu v
  where h.publisert_tid is not null
    and h.dato between v.fra and v.til
),

-- Linjer uten hode teller ogsaa: en plan kan vaere brukt paa gulvet
-- uten at noen trykket publiser. `lagd_hittil > 0` betyr at noen
-- faktisk krysset av for at det ble laget.
brukt as (
  select l.stasjon_id,
         l.dato,
         date_trunc('month', l.dato)::date as maned,
         sum(case when l.lagd_hittil > 0 then 1 else 0 end) as linjer_lagd,
         count(*)                                          as linjer
  from public.produksjonsplan_linjer l, vindu v
  where l.dato between v.fra and v.til
  group by l.stasjon_id, l.dato, date_trunc('month', l.dato)::date
),

-- Svinn i de varegruppene planen daekker. 1201 BAKEVARER og 1216
-- VARMMAT er de to fixturen og produksjonsplanen bruker; koden leser
-- prefiks 12 for aa fange soesken uten aa gjette paa hele kodeverket.
svinn as (
  select s.stasjon_id,
         date_trunc('month', s.dato)::date as maned,
         sum(s.nettopris_total) filter (
           where vg.gruppe_kode like '12%')            as plan_kr,
         sum(s.nettopris_total)                        as alt_kr,
         count(distinct s.dato)                        as foeringsdager
  from public.synlig_svinn s
  cross join vindu v
  left join public.v_vare_gruppe vg on vg.ean = s.ean
  where s.slettet_tid is null
    and s.dato between v.fra and v.til
  group by s.stasjon_id, date_trunc('month', s.dato)::date
)

-- =====================================================================
-- 1  ADOPSJON - naar, og hvor jevnt
-- =====================================================================
select 1 as del, 'PUBLISERT' as hva, st.stasjon as stasjon,
       'dager med publisert plan' as maal,
       min(p.dato)::text || ' -> ' || max(p.dato)::text as verdi,
       count(*)::numeric                     as n,
       count(distinct p.maned)::numeric      as a,
       null::numeric as b, null::numeric as c
from publisert p join stasj st on st.id = p.stasjon_id
group by st.stasjon

union all
select 1, 'PUBLISERT PER MAANED', st.stasjon,
       p.maned::text,
       null::text,
       count(*)::numeric,
       null::numeric, null::numeric, null::numeric
from publisert p join stasj st on st.id = p.stasjon_id
group by st.stasjon, p.maned

-- INGEN PUBLISERING ER OGSAA ET SVAR, og det er det svaret som avgjoer
-- om kontrollen kan bygges i det hele tatt. Uten denne grenen ser en
-- stasjon som aldri har publisert ut som en stasjon som ikke finnes.
union all
select 1, 'INGEN PUBLISERING', st.stasjon,
       'stasjonen har aldri publisert en plan i vinduet',
       null::text,
       0::numeric, null::numeric, null::numeric, null::numeric
from stasj st
where not exists (select 1 from publisert p where p.stasjon_id = st.id)

union all
select 2, 'LINJER LAGD', st.stasjon,
       'dager der noen krysset av for at det ble laget',
       null::text,
       count(*) filter (where b.linjer_lagd > 0)::numeric,
       count(*)::numeric,
       sum(b.linjer_lagd)::numeric,
       sum(b.linjer)::numeric
from brukt b join stasj st on st.id = b.stasjon_id
group by st.stasjon

-- =====================================================================
-- 3  SVINNET SOM SKAL KONTROLLERES
-- =====================================================================
union all
select 3, 'SVINN PER MAANED', st.stasjon,
       s.maned::text,
       null::text,
       s.plan_kr::numeric,
       s.alt_kr::numeric,
       s.foeringsdager::numeric,
       (select count(*) from publisert p
        where p.stasjon_id = s.stasjon_id and p.maned = s.maned)::numeric
from svinn s join stasj st on st.id = s.stasjon_id

-- ANDELEN SOM I DET HELE TATT LAR SEG KOBLE. Er den lav, maaler
-- «plan_kr» noe annet enn det planen daekker - varmmat paa
-- produksjonskode faller utenfor akkurat der det betyr mest.
union all
select 3, 'KOBLINGSGRAD', st.stasjon,
       'andel av svinnkronene som har varegruppe',
       null::text,
       sum(s.plan_kr)::numeric,
       sum(s.alt_kr)::numeric,
       null::numeric, null::numeric
from svinn s join stasj st on st.id = s.stasjon_id
group by st.stasjon

order by del, hva, stasjon, maal, n desc nulls last;
