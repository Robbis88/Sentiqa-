-- =====================================================================
-- Sentiqa - Regnskap: summer linjer over et periodeintervall (maaned ELLER
-- hittil i aar). Azets fyller regnskap_hittil KUN paa cluster, og hittil-tallet
-- avviker fra sum av maanedene. Vi summerer derfor maanedene selv, saa maaned og
-- aar henger sammen OG per-stasjon-hittil ikke blir null.
-- security invoker => RLS paa regnskapslinjer gjelder (admin: hele kjeden;
-- butikksjef: egne stasjoner).
-- =====================================================================
create or replace function public.regnskap_sum(p_fra date, p_til date)
returns table(
  stasjon_id uuid, seksjon text, kode text, post text,
  sortering integer, regnskap numeric, budsjett numeric
)
language sql
security invoker
set search_path = public
as $$
  select
    stasjon_id, seksjon, kode, post,
    min(sortering)::int as sortering,
    sum(regnskap)        as regnskap,
    sum(budsjett)        as budsjett
  from public.regnskapslinjer
  where periode between p_fra and p_til and slettet_tid is null
  group by stasjon_id, seksjon, kode, post
$$;

grant execute on function public.regnskap_sum(date, date) to authenticated;
