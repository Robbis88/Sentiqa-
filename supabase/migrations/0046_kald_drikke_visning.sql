-- =====================================================================
-- Sentiqa - Kald drikke (avd. 140) i salgsvisningen, for vekst-engasjement
-- pa tableten (Mat = 120, Kald drikke = 140). Ny kolonne legges bakerst sa
-- "create or replace view" godtas.
-- =====================================================================
create or replace view public.v_salg_per_stasjon_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  sum(omsetning_eks_mva)                                          as omsetning,
  sum(antall)                                                     as antall,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '120')     as mat_omsetning,
  sum(bto_fortjeneste_kr)                                         as bto_fortjeneste,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '140')     as kald_drikke_omsetning
from public.daglig_salg
where slettet_tid is null
group by retailer_id, stasjon_id, dato;

grant select on public.v_salg_per_stasjon_dag to authenticated;
