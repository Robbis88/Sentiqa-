-- =====================================================================
-- Hvilke maaneder finnes St1s usynlige svinn for i det hele tatt?
--
-- `regnskap_usynlig_svinn` hadde 1 til 7 maaneder per stasjon i 2026:
-- Lone 7, Bones 6, Dale 3, Laguneparken 2, Varden 1. Det er ikke et
-- moenster som ser ut som drift.
--
-- MISTANKEN LIGGER I IMPORTEN, ikke hos St1. `lagreUsynligSvinn` i
-- `src/lib/import/kjerne.ts` kalles slik:
--
--   try {
--     const us = await parseUsynligSvinn(buffer)
--     await lagreUsynligSvinn(...)
--   } catch { /* fila har kanskje ikke per-stasjon-ark */ }
--
-- Mangler arket i én maaneds fil - eller feiler parseren paa den -
-- finnes ikke raden. Og en manglende rad ser noeyaktig ut som «St1 fant
-- ikke noe svinn den maaneden». Det er den samme sykdommen som
-- skrivevakten er bygget mot: en stille feil som likner en vellykket
-- kjoering.
--
-- DENNE SPOERRINGEN SKILLER DE TO. `regnskapslinjer` finnes for hver
-- maaned som er importert i det hele tatt. Har en maaned regnskapslinjer
-- men ingen svinnrad, ble arket ikke lest - da er hullet vaart.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with maaneder as (
  -- Alle maaneder vi faktisk har importert regnskap for.
  select distinct r.stasjon_id, r.periode
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.stasjon_id is not null
    and r.periode >= date_trunc('year', current_date)
),
svinn as (
  select u.stasjon_id,
         u.periode,
         count(*)                                        as rader,
         count(*) filter (where u.kode = '130')          as varm_drikke_rader,
         sum(u.usynlig_kr)                               as sum_kr
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
  group by u.stasjon_id, u.periode
)

select s.navn                            as stasjon,
       m.periode,
       coalesce(v.rader, 0)              as svinnrader,
       coalesce(v.varm_drikke_rader, 0)  as varm_drikke,
       round(v.sum_kr)                   as sum_kr_alle_koder,
       case when v.rader is null
            then 'ARKET BLE IKKE LEST'
            when coalesce(v.varm_drikke_rader, 0) = 0
            then 'lest, men ingen 130-rad'
            else 'ok'
       end                               as status
from maaneder m
join public.stasjoner s on s.id = m.stasjon_id
left join svinn v using (stasjon_id, periode)
order by s.navn, m.periode;
