-- =====================================================================
-- St1 regner det ut selv. Stemmer det med det vi utledet?
--
-- `regnskap_usynlig_svinn` (0049) kommer fra regnskapsfila og har St1s
-- eget tall per stasjon og kode: `usynlig_kr` (+ manko, - overskudd).
-- Vi rekonstruerte det samme av kassa minus telling uten aa vite at det
-- laa der.
--
-- TO UAVHENGIGE KILDER PAA SAMME STOERRELSE er en gave. Er de like, er
-- metoden bekreftet og vi bruker St1s tall - det er fasit. Er de ulike,
-- er St1s tall fasit likevel, og differansen er sin egen historie.
--
-- HVA VI FORTSATT TRENGER DEN UTLEDEDE TIL: St1 gir KRONER. Varselet
-- skal si KOPPER - «slaa inn 2 100 PAAFYLL CAFFE LATTE» er en handling,
-- «11 998 kr mangler» er en opplysning. Koppene krever
-- lagerjusteringen per kopp, og den finnes bare i `daglig_salg`.
--
-- KUN INNEVAERENDE AAR. Robert 2026-08-23: «vi maa kun justere paa
-- aaret, saa desember maa ikke vaere med. Neste aar kun 2027-tall.»
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with st1 as (
  select u.stasjon_id,
         sum(u.usynlig_kr)                as st1_kr,
         count(*)                         as maaneder,
         min(u.periode)                   as fra,
         max(u.periode)                   as til
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and u.periode >= date_trunc('year', current_date)
    and (u.kode = '130' or u.navn ilike '%VARM%')
  group by u.stasjon_id
),
utledet as (
  select v.stasjon_id,
         round(v.regnskap_omsetning_kr * (
           v.kassa_brutto_kr::numeric / nullif(v.kassa_omsetning_kr, 0)
           - v.regnskap_brutto_kr::numeric / nullif(v.regnskap_omsetning_kr, 0)
         ))                               as utledet_kr,
         v.maaneder                       as utledet_maaneder,
         v.vanligste_paafyll,
         v.kr_per_kopp
  from public.v_kaffe_svinn v
  where v.aar = date_trunc('year', current_date)::date
)

select s.navn                                    as stasjon,
       t.fra,
       t.til,
       t.maaneder                                as st1_maaneder,
       u.utledet_maaneder,
       round(t.st1_kr)                           as st1_kr,
       u.utledet_kr,
       round(t.st1_kr - u.utledet_kr)            as differanse_kr,
       u.vanligste_paafyll,
       u.kr_per_kopp,
       -- KOPPENE, regnet av St1s tall. Det er dette varselet skal si.
       case when u.kr_per_kopp > 0 and t.st1_kr > 0
            then round(t.st1_kr / u.kr_per_kopp)
       end                                       as maa_slaas_inn
from st1 t
full join utledet u using (stasjon_id)
join public.stasjoner s on s.id = coalesce(t.stasjon_id, u.stasjon_id)
order by t.st1_kr desc nulls last;
