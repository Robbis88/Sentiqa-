-- =====================================================================
-- Sentiqa 0157 - Butikksalg aggregert per stasjon og dag
--
-- HVORFOR DEN TRENGS
--
-- 25. august 2026 ble importert for Laguneparken med 8 rader og 676 kr.
-- Nabotirsdagene laa paa 37-39 000. Dagen fantes, statusen var «parset»,
-- stasjonen og datoen var riktige - og 97 % av radene manglet. Det kostet
-- 44 578 kr i rapporterte tall, og ingenting i Sentiqa kunne se det:
--
--   /dekning        ser at dagen FINNES, ikke hva den inneholder
--   importloggen    sa «parset», for parsingen gikk fint
--   dublettsjekken  regner 8 rader som en vellykket import
--
-- Rimelighetssjekken i src/lib/import/rimelighet.ts sammenligner dagen
-- mot stasjonens egen median for SAMME UKEDAG. Den trenger et tall per
-- stasjon per dag - `v_butikksalg` er per EAN, og aatte uker for fem
-- stasjoner er ~95 000 rader, langt over PostgREST sin 1000-grense.
--
-- SIKKERHET
--
-- `security_invoker = true`: viewet leser som den som spoer, saa RLS paa
-- `daglig_salg` gjelder. Uten den ville viewet lest som eier og gitt en
-- vei rundt RLS - se AGENTS.md og punkt 9 i vakthunden.
--
-- `revoke all ... from anon` ved siden av granten: Supabase-standarden
-- `alter default privileges ... grant all on tables to anon` treffer hver
-- ny view, og `anon` er rollen bak den offentlige noekkelen i hver
-- sidelast.
--
-- Bygget paa v_butikksalg og IKKE daglig_salg: drivstoff er ~68 % av
-- omsetningen, betjener seg selv paa pumpa, og hoerer ikke hjemme i en
-- vurdering av butikkens dag.
-- =====================================================================

create or replace view public.v_butikksalg_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  sum(omsetning_eks_mva)::numeric as kroner,
  count(*)::bigint                as rader
from public.v_butikksalg
group by retailer_id, stasjon_id, dato;

comment on view public.v_butikksalg_dag is
  'Butikksalg (uten ENERGI) summert per stasjon og dag. Grunnlaget for '
  'rimelighetssjekken ved import - se src/lib/import/rimelighet.ts og '
  'migrasjon 0157.';

grant select on public.v_butikksalg_dag to authenticated;
revoke all on public.v_butikksalg_dag from anon;
