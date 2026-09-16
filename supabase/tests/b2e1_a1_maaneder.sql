-- ====================================================================
-- B2e.1 - HVA hentA1Maaneder FAKTISK SVARER I PRODUKSJON
--
-- KUN SELECT. Ingen DDL, ingen DML, ingen rollebytte, ingen metakommando.
-- Trygg i produksjon og kan kjoeres om igjen.
--
-- Den speiler `src/lib/lonnskost/a1-maaneder.ts` setning for setning:
--
--   en maaned finnes for stasjonen dersom stasjonen har en EGEN rad i
--   basisvakt ELLER i lonnsregister i den maaneden.
--
-- KRYSSREGISTER TELLER IKKE. Derfor staar `stasjon_id` paa BEGGE armene.
-- Faller det filteret bort paa registerarmen, blir svaret her et annet
-- enn kodens - og det er nettopp den feilen injeksjonen
-- "kryssregister gjoer en maaned lokal" ble roed paa.
-- ====================================================================

-- 1. Svaret, per stasjon. Sortert nyeste foerst, som i koden.
select
  s.navn                             as stasjon,
  m.kilde_maaned                     as maaned,
  m.fra_basisvakt,
  m.fra_register
from public.stasjoner s
join (
  select stasjon_id, kilde_maaned,
         max(case when k = 'basisvakt' then 1 else 0 end)    as fra_basisvakt,
         max(case when k = 'lonnsregister' then 1 else 0 end) as fra_register
  from (
    select stasjon_id, kilde_maaned, 'basisvakt' as k
      from public.basisvakt
    union all
    select stasjon_id, kilde_maaned, 'lonnsregister' as k
      from public.lonnsregister
  ) r
  group by stasjon_id, kilde_maaned
) m on m.stasjon_id = s.id
order by s.navn, m.kilde_maaned desc;

-- 2. Trenger noen av kallene mer enn EN side? PostgREST kutter ved 1000
--    rader uten aa si fra, og `hentAlle` sider derfor. Er et av tallene
--    under over 1000, gjoer produksjonskjoeringen flere rundturer enn
--    maalingen min viste - og da er kalltellingen i rapporten for lav.
select
  s.navn                                                  as stasjon,
  count(*) filter (where b.id is not null)                as basisvaktrader_totalt,
  count(*) filter (where b.kilde_maaned = '2026-08')      as basisvaktrader_2026_08
from public.stasjoner s
left join public.basisvakt b on b.stasjon_id = s.id
group by s.navn
order by s.navn;

-- 3. Registerrader per stasjon og maaned, samme sporsmaal.
select
  s.navn        as stasjon,
  r.kilde_maaned as maaned,
  count(*)       as registerrader
from public.lonnsregister r
join public.stasjoner s on s.id = r.stasjon_id
group by s.navn, r.kilde_maaned
order by s.navn, r.kilde_maaned desc;
