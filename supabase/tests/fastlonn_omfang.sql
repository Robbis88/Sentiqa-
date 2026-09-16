-- ====================================================================
-- FASTLOENN - FAKTISK OMFANG, IKKE ANTATT
--
-- KUN SELECT. Ingen DDL, ingen DML, ingen rollebytte, ingen metakommando.
-- Trygg i produksjon og kan kjoeres om igjen.
--
-- Bakgrunn: jeg skrev "fem av seks stasjoner". Det var en formulering,
-- ikke en maaling. Proben for A1-maanedene returnerte SJU stasjoner,
-- blant dem minst en som heter "Test Bones". Denne spoerringen avgjoer
-- hvilke enheter som faktisk baerer butikksjef_fastlonn, og i hvilke
-- maaneder - saa omfanget av fastlonnshullet blir talt, ikke gjettet.
-- ====================================================================

-- 1. HVILKE stasjoner har butikksjef_fastlonn, og i hvilket vindu?
--    Merk: tabellen kjenner BELOEPET, ikke personen - den har ingen
--    ansatt_nr. Det er nettopp det hullet porten handler om.
select
  s.navn                                    as stasjon,
  s.butikknummer,
  count(*)                                  as maaneder_med_fastlonn,
  min(f.ar * 100 + f.maned)                 as tidligste,
  max(f.ar * 100 + f.maned)                 as seneste,
  sum(f.grunnlonn_kr)                       as sum_grunnlonn_kr
from public.stasjoner s
join public.butikksjef_fastlonn f
  on f.stasjon_id = s.id and f.slettet_tid is null
where s.slettet_tid is null
group by s.navn, s.butikknummer
order by s.navn;

-- 2. ALLE stasjoner, ogsaa de UTEN fastlonn. Uten denne ser en stasjon
--    som mangler rad ut som en stasjon som ikke finnes.
select
  s.navn                                                     as stasjon,
  s.butikknummer,
  count(f.id)                                                as fastlonnsmaaneder,
  count(f.id) filter (where f.ar = 2026 and f.maned = 8)     as har_2026_08
from public.stasjoner s
left join public.butikksjef_fastlonn f
  on f.stasjon_id = s.id and f.slettet_tid is null
where s.slettet_tid is null
group by s.navn, s.butikknummer
order by s.navn;

-- 3. Hvem er allerede klassifisert i ansatt_avtale i dag?
--    Dette er flaten fastlonnsporten maa kunne skrive til. Staar det
--    ingen fastlonn her, er det fordi Lonnsform-lista bare viser folk
--    loennsfila kjenner - og en fastlonnet er nettopp den den ikke har.
select
  s.navn        as stasjon,
  a.ansatt_nr,
  a.navn        as navn_i_avtale,
  a.lonnsform
from public.ansatt_avtale a
join public.stasjoner s on s.id = a.stasjon_id
order by s.navn, a.ansatt_nr;

-- 4. KANDIDATENE: numre som ARBEIDET i 2026-08 men som ikke finnes i
--    stasjonens eget lonnsregister for samme maaned. Det er akkurat
--    denne lista en registreringsflate maatte tilby, og motoren regner
--    den allerede ut som `uslaatteNumre`.
select
  s.navn                          as stasjon,
  b.ansatt_nr,
  min(b.ansatt_navn)              as navn,
  count(*)                        as vakter,
  sum(b.minutter)                 as minutter
from public.basisvakt b
join public.stasjoner s on s.id = b.stasjon_id
where b.kilde_maaned = '2026-08'
  and b.betalt
  and not exists (
    select 1 from public.lonnsregister r
    where r.stasjon_id = b.stasjon_id
      and r.kilde_maaned = b.kilde_maaned
      and r.ansatt_nr = b.ansatt_nr
  )
group by s.navn, b.ansatt_nr
order by s.navn, sum(b.minutter) desc;
