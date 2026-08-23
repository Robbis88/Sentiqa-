-- =====================================================================
-- Hva heter radene egentlig i St1s svinnrapport?
--
-- FUNNET SOM UTLOESTE DENNE: arket leses hver eneste maaned - 10 til 30
-- rader per stasjon - men `kode = '130'` finnes ALDRI. Likevel ga
-- sammenlikningen treff, og den filtrerte paa
-- `kode = '130' or navn ilike '%VARM%'`.
--
-- Altsaa: radene er der, men koden stemmer ikke. Enten er `kode` null,
-- eller saa bruker svinnrapporten en annen kodenoekkel enn
-- `regnskapslinjer`. Vi har filtrert paa noe som ikke finnes, og faatt
-- null tilbake uten at noe sa fra - null rader ser ut som «ingen svinn».
--
-- DEL 1 lister hva som faktisk staar der. Ingen antakelser.
--
-- DEL 2 er regelen Robert oppga 2026-08-23: «de har alltid litt svinn
-- paa kaffe hver mnd, ellers har de glemt aa telle. Mat, tobakk, varm
-- drikke og bilvask telles hver mnd.»
--
-- Det er en langt bedre maaling enn aa utlede svinn av kassa minus
-- telling: den krever ingen antakelse om kaffepris eller varemiks. Er
-- raden borte, er tellingen ikke gjort. Det er et faktum, ikke et
-- anslag.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DEL 1: hvilke koder og navn finnes, og hvor ofte
-- ---------------------------------------------------------------------
select coalesce(u.kode, '(ingen kode)')   as kode,
       u.navn,
       count(*)                           as rader,
       count(distinct u.periode)          as maaneder,
       count(distinct u.stasjon_id)       as stasjoner,
       round(sum(u.usynlig_kr))           as sum_kr
from public.regnskap_usynlig_svinn u
where u.slettet_tid is null
  and u.periode >= date_trunc('year', current_date)
group by coalesce(u.kode, '(ingen kode)'), u.navn
order by count(*) desc, u.navn;


-- ---------------------------------------------------------------------
-- DEL 2: har de talt? Fire kategorier skal telles hver maaned.
--
-- Kjor denne SEPARAT, etter at del 1 har vist hva navnene er. Traff
-- moenstrene under feil, ser en talt maaned ut som en glemt.
-- ---------------------------------------------------------------------
with maaneder as (
  select distinct r.stasjon_id, r.periode
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.stasjon_id is not null
    and r.periode >= date_trunc('year', current_date)
    -- Bare maaneder som faktisk er avlagt.
    and exists (
      select 1 from public.regnskapslinjer x
      where x.stasjon_id = r.stasjon_id and x.periode = r.periode
        and x.seksjon = 'omsetning' and x.regnskap is not null
    )
),
talt as (
  select u.stasjon_id,
         u.periode,
         count(*) filter (where u.navn ilike '%VARM%')                  as varm_drikke,
         count(*) filter (where u.navn ilike '%MAT%')                   as mat,
         count(*) filter (where u.navn ilike '%TOBAKK%')                as tobakk,
         count(*) filter (where u.navn ilike '%VASK%')                  as bilvask
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.periode >= date_trunc('year', current_date)
  group by u.stasjon_id, u.periode
)

select s.navn                                        as stasjon,
       m.periode,
       coalesce(t.varm_drikke, 0)                    as varm_drikke,
       coalesce(t.mat, 0)                            as mat,
       coalesce(t.tobakk, 0)                         as tobakk,
       coalesce(t.bilvask, 0)                        as bilvask,
       -- «Alltid litt svinn hver maaned, ellers har de glemt aa telle.»
       nullif(concat_ws(', ',
         case when coalesce(t.varm_drikke, 0) = 0 then 'varm drikke' end,
         case when coalesce(t.mat, 0) = 0 then 'mat' end,
         case when coalesce(t.tobakk, 0) = 0 then 'tobakk' end,
         case when coalesce(t.bilvask, 0) = 0 then 'bilvask' end
       ), '')                                        as ikke_talt
from maaneder m
join public.stasjoner s on s.id = m.stasjon_id
left join talt t using (stasjon_id, periode)
order by s.navn, m.periode;
