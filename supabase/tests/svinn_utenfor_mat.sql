-- =====================================================================
-- Hva er de 43 278 kronene paa Lone i mai 2026?
--
-- REN LESING. Ingen tabeller, views, funksjoner, policyer eller data
-- roeres. Trygg i produksjon.
--
-- ---------------------------------------------------------------------
-- FUNNET SOM UTLOESTE DENNE
--
-- `produksjonsplan_adopsjon.sql` (2026-08-25) viste at Lone i mai 2026
-- hadde 26 693 kr svinn i matgruppene (12xx) og 69 971 kr totalt. De
-- 43 278 kronene utenfor mat er 5-10 ganger et vanlig maanedstall der -
-- ellers ligger differansen paa 800 til 8 000.
--
-- Det er én maaned, én stasjon. Spoersmaalet er hva det ER, ikke hvem
-- som gjorde det.
--
-- ---------------------------------------------------------------------
-- HVA SVARET SKAL SKILLE MELLOM
--
--   én dag, én vare      en engangsavskriving - frysebrudd,
--                        tilbakekalling, en vare som gikk ut paa dato
--                        i bulk. Ett tall, én forklaring.
--
--   én dag, mange varer  en opprydning som ble foert samlet. Kronene er
--                        ekte, men de tilhoerer flere dager.
--
--   mange dager          et moenster, ikke en hendelse. Da er det
--                        driften som har endret seg.
--
--   uten varegruppe      varmmat paa produksjonskode, ingredienser,
--                        bulk. Da er «utenfor mat» en koblingsfeil og
--                        ikke et funn i det hele tatt.
--
-- ---------------------------------------------------------------------
-- OPERATOERNUMMERET ER MED FOR AA SE OM DET ER ÉN FOERING
--
-- Ikke for aa peke ut noen. Ligger alle kronene paa ett operatoernummer
-- og én dato, er det én registrering - og da er spoersmaalet hva som
-- ble ryddet, ikke hvem som ryddet. Det finnes ingen rangering her, og
-- det skal ikke lages en. Se `kasserer_fordeling.sql` for hvorfor:
-- svingningen inni én person er stoerre enn spennet mellom personer.
--
-- Kolonnene er de samme i hver gren:
-- del, hva, nokkel, verdi, n, kr, antall, linjer, dager.
-- =====================================================================

with

mal as (
  -- Endre disse to for aa se paa en annen stasjon eller maaned.
  select '4177'::text                as butikknummer,
         date '2026-05-01'           as maned
),

stasj as (
  select s.id, s.butikknummer, s.butikknummer || ' ' || s.navn as stasjon
  from public.stasjoner s
  where s.slettet_tid is null
),

-- Alt svinn paa maalstasjonen, med varegruppe der den finnes.
rader as (
  select s.stasjon_id,
         s.dato,
         date_trunc('month', s.dato)::date as maned,
         s.ean,
         s.varenavn,
         s.varenummer,
         s.operatornr,
         s.arsakskode,
         s.transaksjonstype,
         s.antall,
         s.nettopris_total as kr,
         vg.gruppe_kode,
         vg.gruppe_navn,
         case
           when vg.gruppe_kode is null       then 'uten varegruppe'
           when vg.gruppe_kode like '12%'    then 'mat (12xx)'
           else 'utenfor mat'
         end as sone
  from public.synlig_svinn s
  join stasj st on st.id = s.stasjon_id
  join mal m on m.butikknummer = st.butikknummer
  left join public.v_vare_gruppe vg on vg.ean = s.ean
  where s.slettet_tid is null
    and s.dato is not null
),

maaneden as (
  select r.* from rader r, mal m where r.maned = m.maned
)

-- =====================================================================
-- 1  HVOR LIGGER KRONENE
-- =====================================================================
select 1 as del, 'SONE' as hva, r.sone as nokkel,
       null::text as verdi,
       null::numeric as n,
       sum(r.kr)::numeric as kr,
       sum(r.antall)::numeric as antall,
       count(*)::numeric as linjer,
       count(distinct r.dato)::numeric as dager
from maaneden r
group by r.sone

-- =====================================================================
-- 2  ÉN DAG ELLER MANGE? Dette avgjoer alt det andre.
-- =====================================================================
union all
select 2, 'PER DAG UTENFOR MAT', r.dato::text,
       null::text, null::numeric,
       sum(r.kr)::numeric, sum(r.antall)::numeric,
       count(*)::numeric, count(distinct r.ean)::numeric
from maaneden r
where r.sone <> 'mat (12xx)'
group by r.dato

-- =====================================================================
-- 3  HVILKE VAREGRUPPER
-- =====================================================================
union all
select 3, 'VAREGRUPPE UTENFOR MAT',
       coalesce(r.gruppe_kode, '(ingen)') || ' ' || coalesce(r.gruppe_navn, ''),
       null::text, null::numeric,
       sum(r.kr)::numeric, sum(r.antall)::numeric,
       count(*)::numeric, count(distinct r.dato)::numeric
from maaneden r
where r.sone <> 'mat (12xx)'
group by r.gruppe_kode, r.gruppe_navn

-- =====================================================================
-- 4  HVILKE VARER - de tjue stoerste
-- =====================================================================
union all
select 4, 'VARE', x.ean || ' ' || coalesce(x.varenavn, ''),
       coalesce(x.gruppe_navn, '(ingen varegruppe)'),
       x.rn::numeric,
       x.kr, x.antall, x.linjer, x.dager
from (
  select r.ean, min(r.varenavn) as varenavn, min(r.gruppe_navn) as gruppe_navn,
         sum(r.kr) as kr, sum(r.antall) as antall,
         count(*)::numeric as linjer, count(distinct r.dato)::numeric as dager,
         row_number() over (order by sum(r.kr) desc nulls last) as rn
  from maaneden r
  where r.sone <> 'mat (12xx)'
  group by r.ean
) x
where x.rn <= 20

-- =====================================================================
-- 5  AARSAK OG TYPE - staar det noe i selve raden?
-- =====================================================================
union all
select 5, 'AARSAKSKODE',
       coalesce(nullif(btrim(r.arsakskode), ''), '(tom)'),
       coalesce(nullif(btrim(r.transaksjonstype), ''), '(tom)'),
       null::numeric,
       sum(r.kr)::numeric, sum(r.antall)::numeric,
       count(*)::numeric, count(distinct r.dato)::numeric
from maaneden r
where r.sone <> 'mat (12xx)'
group by nullif(btrim(r.arsakskode), ''), nullif(btrim(r.transaksjonstype), '')

-- ÉN FOERING ELLER MANGE. Ligger alt paa ett nummer og én dato, er det
-- én registrering - og da er spoersmaalet hva som ble ryddet.
union all
select 5, 'OPERATOER',
       coalesce(nullif(btrim(r.operatornr), ''), '(tom)'),
       null::text, null::numeric,
       sum(r.kr)::numeric, sum(r.antall)::numeric,
       count(*)::numeric, count(distinct r.dato)::numeric
from maaneden r
where r.sone <> 'mat (12xx)'
group by nullif(btrim(r.operatornr), '')

-- =====================================================================
-- 6  ER MAI SAERLIG? Samme stasjon, alle maaneder.
-- =====================================================================
union all
select 6, 'SAMME STASJON, ALLE MAANEDER', r.maned::text,
       null::text, null::numeric,
       sum(r.kr) filter (where r.sone <> 'mat (12xx)')::numeric,
       sum(r.kr) filter (where r.sone = 'utenfor mat')::numeric,
       sum(r.kr) filter (where r.sone = 'uten varegruppe')::numeric,
       count(distinct r.dato)::numeric
from rader r
group by r.maned

-- =====================================================================
-- 7  ER LONE SAERLIG? Alle stasjoner, samme maaned.
-- =====================================================================
union all
select 7, 'ALLE STASJONER, SAMME MAANED', st.stasjon,
       null::text, null::numeric,
       sum(s.nettopris_total) filter (
         where vg.gruppe_kode is null or vg.gruppe_kode not like '12%')::numeric,
       sum(s.nettopris_total)::numeric,
       count(*)::numeric,
       count(distinct s.dato)::numeric
from public.synlig_svinn s
join stasj st on st.id = s.stasjon_id
cross join mal m
left join public.v_vare_gruppe vg on vg.ean = s.ean
where s.slettet_tid is null
  and date_trunc('month', s.dato)::date = m.maned
group by st.stasjon

order by del, hva, n nulls last, kr desc nulls last, nokkel;
