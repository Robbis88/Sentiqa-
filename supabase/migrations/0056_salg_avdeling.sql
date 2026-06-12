-- =====================================================================
-- Sentiqa - Salg per AVDELING (Mat, Kald drikke, Varm drikke …) per stasjon/dag,
-- og varegruppe per STASJON. Begge med stasjon_id, så /salg kan bryte ned både
-- kjedevis og per butikk. Aggregering skjer i databasen (ingen 1000-rad-grense
-- som JS-aggregering av daglig_salg ville fått). security_invoker → RLS på
-- daglig_salg gjelder (tenant-trygt, butikksjef ser kun egne stasjoner).
-- =====================================================================

create or replace view public.v_salg_per_avdeling_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  avdeling_kode,
  avdeling_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and avdeling_kode is not null
group by retailer_id, stasjon_id, dato, avdeling_kode, avdeling_navn;

create or replace view public.v_salg_per_varegruppe_stasjon_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  varegruppe_kode,
  varegruppe_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and varegruppe_kode is not null
group by retailer_id, stasjon_id, dato, varegruppe_kode, varegruppe_navn;

grant select on public.v_salg_per_avdeling_dag          to authenticated;
grant select on public.v_salg_per_varegruppe_stasjon_dag to authenticated;
