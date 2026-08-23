-- =====================================================================
-- St1 regner det ut selv. Stemmer det med det vi utledet?
--
-- `regnskap_usynlig_svinn` (0049) kommer fra regnskapsfila og har St1s
-- eget tall per stasjon og kode: `usynlig_kr` (+ manko, - overskudd).
-- Vi rekonstruerte det samme av kassa minus telling uten aa vite at det
-- laa der.
--
-- FOERSTE UTGAVE SAMMENLIKNET ULIKE VINDUER, og svaret var derfor
-- verdiloest. St1s tall finnes bare for NOEN maaneder per stasjon:
--
--   Lone 7 maaneder, Bones 6, Dale 3, Laguneparken 2, Varden 1
--
-- Mot sju maaneder utledet. Vardens ene maaned mot vaare sju sier
-- ingenting - og differansen saa ut som en uenighet mellom kildene naar
-- den i hovedsak var ulik dekning.
--
-- Denne versjonen joiner paa (stasjon, periode), saa bare maaneder som
-- finnes i BEGGE kildene telles. `dekning` sier hvor mange maaneder som
-- faktisk ble sammenliknet, saa et tynt grunnlag ikke ser tykt ut.
--
-- HVORFOR DEKNINGEN ER TYNN er sitt eget spoersmaal. `lagreUsynligSvinn`
-- i import/kjerne.ts sletter per (retailer, periode) og setter inn paa
-- nytt, og kallet staar i en `try { } catch { }` med kommentaren «fila
-- har kanskje ikke per-stasjon-ark». Mangler arket i en maaneds fil,
-- finnes ikke raden - og det ser identisk ut med at St1 ikke fant noe.
-- Del 2 under viser dekningen maaned for maaned.
--
-- KUN INNEVAERENDE AAR. Robert 2026-08-23: «vi maa kun justere paa
-- aaret, saa desember maa ikke vaere med. Neste aar kun 2027-tall.»
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DEL 1: samme maaneder paa begge sider
-- ---------------------------------------------------------------------
with st1 as (
  select u.stasjon_id,
         u.periode,
         sum(u.usynlig_kr) as kr
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and u.periode >= date_trunc('year', current_date)
    and (u.kode = '130' or u.navn ilike '%VARM%')
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
       round(sum(t.kr))                                as st1_kr,
       -- Utledet over NOEYAKTIG de samme maanedene.
       round(sum(k.bto_med) - sum(k.oms) * sum(r.bto) / nullif(sum(r.oms), 0))
                                                       as utledet_kr,
       round(sum(t.kr) - (sum(k.bto_med)
             - sum(k.oms) * sum(r.bto) / nullif(sum(r.oms), 0)))
                                                       as differanse_kr,
       round(sum(k.utdelte))                           as utdelte_kopper,
       v.vanligste_paafyll,
       v.kr_per_kopp,
       -- Koppene, regnet av ST1s tall. Det er fasit naar den finnes.
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
order by 5 desc nulls last;
