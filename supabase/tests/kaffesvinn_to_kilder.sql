-- =====================================================================
-- Kaffejusteringen: gaar 130xx i null?
--
-- REGELEN, fra Robert 2026-08-23:
--
--   «Kaffelojalitet er der vi nedjusteres. Hvis kaffelojalitet er
--    -2000 kr og kaffe/te er 2000, saa er det rett justert. Er kaffe/te
--    1000 kr, mangler det justering paa 1000 kr.»
--
-- Kaffen forsvinner fysisk fra lageret og gir MANKO paa `13010 KAFFE`.
-- Slaas utdelingen inn, gir den et tilsvarende OVERSKUDD paa
-- `13011 KAFFELOJALITET`. Balanserer de, er alt registrert. Det som
-- staar igjen, er justeringen som mangler.
--
-- DETTE ER EKSAKT, ikke et anslag. St1 har regnet det ut i
-- `regnskap_usynlig_svinn` (0049), + manko / - overskudd. Ingen
-- antakelse om kaffepris, varemiks eller hvor mange kopper som gaar med.
-- Utledningen «kassa minus telling» svarte paa det samme, men med tre
-- mellomregninger som alle kunne baere en feil.
--
-- HELE KJEDEN, 2026:  481 994 - 325 161 - 8 405 = +148 428 kr ujustert.
--
-- MATCH PAA KODEPREFIKS, ALDRI PAA NAVNET. Svinnrapporten er paa
-- VAREGRUPPE - femsifrede koder der avdelingen er de tre foerste.
-- `navn ilike (prosent)VARM(prosent)` traff `12014 OPPVARMET`, altsaa
-- oppvarmet MAT, og ga et troverdig tall for feil avdeling.
--
-- KUN INNEVAERENDE AAR. Robert: «vi maa kun justere paa aaret. Neste aar
-- kun 2027-tall.»
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with svinn as (
  select u.stasjon_id,
         count(distinct u.periode)                                  as maaneder,
         min(u.periode)                                             as fra,
         max(u.periode)                                             as til,
         sum(u.usynlig_kr) filter (where u.kode = '13010')          as kaffe_kr,
         sum(u.usynlig_kr) filter (where u.kode = '13011')          as lojalitet_kr,
         sum(u.usynlig_kr) filter (
           where u.kode not in ('13010', '13011'))                  as annet_kr,
         sum(u.usynlig_kr)                                          as rest_kr
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and u.periode >= date_trunc('year', current_date)
    and left(u.kode, 3) = '130'
  group by u.stasjon_id
),

-- Den mest utdelte varen og hva lageret justeres med per kopp. Bare til
-- aa gjoere kroner om til et antall - varselet skal si «slaa inn 2 100
-- PAAFYLL CAFFE LATTE», ikke «11 998 kr mangler».
vanligste as (
  select distinct on (v.stasjon_id)
         v.stasjon_id,
         v.varenavn,
         round(-sum(v.bto_fortjeneste_kr) / sum(v.antall), 2)  as kr_per_kopp,
         sum(v.antall)                                         as antall
  from public.v_butikksalg v
  where v.avdeling_kode = '130'
    and v.varenavn ilike '%FYLL%'
    and v.dato >= date_trunc('year', current_date)
  group by v.stasjon_id, v.varenavn
  having sum(v.antall) > 0 and -sum(v.bto_fortjeneste_kr) > 0
  order by v.stasjon_id, sum(v.antall) desc
)

select s.navn                                    as stasjon,
       v.maaneder,
       v.fra,
       v.til,
       round(v.kaffe_kr)                         as kaffe_kr,
       round(v.lojalitet_kr)                     as lojalitet_kr,
       round(v.annet_kr)                         as annet_kr,
       -- DOMMEN. Positiv = justering som mangler.
       round(v.rest_kr)                          as mangler_kr,
       -- Hvor stor del av utdelingen som ikke er slaatt inn.
       case when v.lojalitet_kr < 0
            then round(100 * v.rest_kr / -v.lojalitet_kr)
       end                                       as andel_ujustert_pst,
       p.varenavn                                as vanligste_paafyll,
       p.kr_per_kopp,
       case when p.kr_per_kopp > 0 and v.rest_kr > 0
            then round(v.rest_kr / p.kr_per_kopp)
       end                                       as maa_slaas_inn
from svinn v
join public.stasjoner s on s.id = v.stasjon_id
left join vanligste p using (stasjon_id)
order by v.rest_kr desc nulls last;
