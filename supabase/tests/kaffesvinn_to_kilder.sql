-- =====================================================================
-- St1 regner det ut selv. Stemmer det med det vi utledet?
--
-- SVINNRAPPORTEN ER PAA VAREGRUPPE, ikke avdeling. Femsifrede koder,
-- der avdelingen er de tre foerste:
--
--   13010 KAFFE             35 rader   7 mnd   5 stasjoner
--   13011 KAFFELOJALITET    33 rader   7 mnd   5 stasjoner
--   13012 TE/KAKAO/ANNET     6 rader   5 mnd   4 stasjoner
--
-- KAFFEN TELLES HVER MAANED, OVERALT. 13010 har 35 av 35 mulige rader.
-- «Har de glemt aa telle» er ikke problemet paa varm drikke.
--
-- TRE FEIL PAA RAD, ALLE AV SAMME SLAG. Jeg filtrerte paa merkelapper
-- jeg hadde gjettet:
--
--   `kode = '130'`      -> null rader. Koden er femsifret.
--   `navn ilike '%MAT%'` -> null rader. Mat heter BAKERI, POELSE,
--                          HAMBURGER, PIZZA, OPPVARMET, PAASMURT.
--   `navn ilike '%VARM%'` -> traff `12014 OPPVARMET`. Oppvarmet MAT.
--
-- Den siste er den verste. De to foerste ga null, og null ser ut som
-- «ingen svinn» - ille nok. Den tredje ga FEIL RADER MED TROVERDIGE
-- TALL: «Lone har 26 006 kr usynlig svinn paa varm drikke» var poelser
-- og hamburgere. Et tall som er galt paa en plausibel maate blir ikke
-- oppdaget av noen.
--
-- REGELEN SOM FOELGER: match paa KODEPREFIKS, aldri paa fritekstnavnet.
-- `left(kode, 3) = '130'` er avdelingen, og den er den samme noekkelen
-- `regnskapslinjer` og `daglig_salg` bruker. Navnet er til aa lese, ikke
-- til aa filtrere paa.
--
-- KUN INNEVAERENDE AAR, og samme maaneder paa begge sider av
-- sammenlikningen.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with st1 as (
  select u.stasjon_id,
         u.periode,
         sum(u.usynlig_kr)                                          as kr,
         sum(u.usynlig_kr) filter (where u.kode = '13010')          as kr_kaffe,
         sum(u.usynlig_kr) filter (where u.kode = '13011')          as kr_lojalitet,
         count(*)                                                   as rader
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and u.periode >= date_trunc('year', current_date)
    -- KODEPREFIKS, ikke navn. Avdeling 130 = varm drikke.
    and left(u.kode, 3) = '130'
  group by u.stasjon_id, u.periode
),

regnskap as (
  select r.stasjon_id,
         r.periode,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')         as oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste') as bto
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode = '130'
    and r.stasjon_id is not null
    and r.periode >= date_trunc('year', current_date)
    and r.seksjon in ('omsetning', 'bruttofortjeneste')
  group by r.stasjon_id, r.periode
  having sum(r.regnskap) filter (where r.seksjon = 'omsetning') is not null
),

kasse as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date        as periode,
         sum(v.omsetning_eks_mva)                 as oms,
         sum(v.bto_fortjeneste_kr)                as bto_med,
         sum(v.antall) filter (where v.varenavn ilike '%FYLL%') as utdelte
  from public.v_butikksalg v
  where v.avdeling_kode = '130'
    and v.dato >= date_trunc('year', current_date)
  group by v.stasjon_id, date_trunc('month', v.dato)
)

select s.navn                                          as stasjon,
       count(*)                                        as dekning,
       min(t.periode)                                  as fra,
       max(t.periode)                                  as til,
       round(sum(t.kr_kaffe))                          as st1_kaffe_kr,
       round(sum(t.kr_lojalitet))                      as st1_lojalitet_kr,
       round(sum(t.kr))                                as st1_sum_kr,
       -- Utledet over NOEYAKTIG de samme maanedene.
       round(sum(k.bto_med) - sum(k.oms) * sum(r.bto) / nullif(sum(r.oms), 0))
                                                       as utledet_kr,
       round(sum(t.kr) - (sum(k.bto_med)
             - sum(k.oms) * sum(r.bto) / nullif(sum(r.oms), 0)))
                                                       as differanse_kr,
       round(sum(k.utdelte))                           as utdelte_kopper,
       v.vanligste_paafyll,
       v.kr_per_kopp,
       -- Koppene, regnet av ST1s tall. Fasit naar den finnes.
       case when v.kr_per_kopp > 0 and sum(t.kr) > 0
            then round(sum(t.kr) / v.kr_per_kopp)
       end                                             as maa_slaas_inn
from st1 t
join regnskap r using (stasjon_id, periode)
join kasse k using (stasjon_id, periode)
join public.stasjoner s on s.id = t.stasjon_id
left join public.v_kaffe_svinn v
  on v.stasjon_id = t.stasjon_id
 and v.aar = date_trunc('year', current_date)::date
group by s.navn, v.vanligste_paafyll, v.kr_per_kopp
order by 7 desc nulls last;
