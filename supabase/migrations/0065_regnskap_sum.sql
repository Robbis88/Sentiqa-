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

-- Tilsvarende for usynlig svinn: summer hittil i aar per stasjon+varegruppe, saa
-- en enkelt minus-maaned som netter ut over aaret ikke flagges. Prosent regnes
-- pa nytt (sum kr / sum salg) i app-laget.
create or replace function public.svinn_sum(p_fra date, p_til date)
returns table(stasjon_id uuid, navn text, salg numeric, usynlig_kr numeric, kast numeric)
language sql
security invoker
set search_path = public
as $$
  select stasjon_id, navn, sum(salg), sum(usynlig_kr), sum(kast)
  from public.regnskap_usynlig_svinn
  where periode between p_fra and p_til and slettet_tid is null
  group by stasjon_id, navn
$$;

grant execute on function public.svinn_sum(date, date) to authenticated;
