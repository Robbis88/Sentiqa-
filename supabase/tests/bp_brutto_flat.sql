-- =====================================================================
-- Er bruttobudsjettet fjoraarets margin, eller et rundt tall?
--
-- /businessplan sier det til brukeren, ordrett (`bp-rad.tsx`):
-- «Bruttobudsjettet er fjoraarets oppnaadde margin, saa et positivt tall
-- betyr at ...». Hele tolkningen av `brutto_mot_bp_pp` hviler paa det.
--
-- FOR VARM DRIKKE PAA BONES HOLDER DET IKKE. Budsjettet er 20,0 % i alle
-- tolv maanedene i 2026 - et rundt tall satt én gang, ikke en maalt
-- historikk. Desember 2025 sto til 48,2 %, altsaa et helt annet regime.
--
-- Denne teller hvor mange ULIKE budsjettmarginer hver avdeling har over
-- aaret. Er svaret 1 for de fleste, er setningen paa skjermen feil - og
-- da maaler `brutto_mot_bp_pp` avstanden til et tall ingen har utledet
-- av noe.
--
-- Varierer den derimot fra maaned til maaned, er setningen sann, og
-- varm drikke er unntaket som skal forklares for seg.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with pr_maaned as (
  select r.stasjon_id,
         r.kode,
         min(r.post)                                                    as post,
         r.periode,
         coalesce(
           sum(r.budsjett) filter (where r.seksjon = 'omsetning'),
           sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')
         )                                                              as bud_oms,
         coalesce(
           sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste'),
           sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste')
         )                                                              as bud_bto
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode is not null
    and r.stasjon_id is not null
    and r.periode >= date '2026-01-01'
    and r.periode <  date '2027-01-01'
    and r.seksjon in ('omsetning', 'bruttofortjeneste',
                      'bp_omsetning', 'bp_bruttofortjeneste')
  group by r.stasjon_id, r.kode, r.periode
),
marginer as (
  select stasjon_id, kode, post,
         round(100 * bud_bto / bud_oms, 1) as bud_pst
  from pr_maaned
  where bud_oms > 0
)
select s.navn                              as stasjon,
       m.post,
       count(*)                            as maaneder,
       count(distinct m.bud_pst)           as ulike_marginer,
       min(m.bud_pst)                      as lavest,
       max(m.bud_pst)                      as hoyest
from marginer m
join public.stasjoner s on s.id = m.stasjon_id
group by s.navn, m.post
order by count(distinct m.bud_pst), s.navn, m.post;
