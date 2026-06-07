-- =====================================================================
-- Sentiqa — Aggregeringsvisninger for salg (PROSJEKT.md §14)
-- Dashboards leser ferdige tall, aldri rådata på direkten. Disse er enkle
-- on-demand-visninger; tunge nattlige forhåndsaggregeringer kommer senere.
--
-- security_invoker = true → RLS på daglig_salg gjelder for den som spør
-- (admin ser alt eget, butikksjef kun tildelte stasjoner). Tenant-trygt.
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
  sum(bto_fortjeneste_kr)                                         as bto_fortjeneste
from public.daglig_salg
where slettet_tid is null
group by retailer_id, stasjon_id, dato;

create or replace view public.v_salg_per_varegruppe_dag
with (security_invoker = true) as
select
  retailer_id,
  dato,
  varegruppe_kode,
  varegruppe_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and varegruppe_kode is not null
group by retailer_id, dato, varegruppe_kode, varegruppe_navn;

grant select on public.v_salg_per_stasjon_dag   to authenticated;
grant select on public.v_salg_per_varegruppe_dag to authenticated;
