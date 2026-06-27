-- =====================================================================
-- Sentiqa — Målekort fase 3: stasjonsliste for leaderboardet.
-- Butikksjef ser via RLS bare SINE stasjoner, men leaderboardet trenger navn
-- på alle stasjonene i clusteret. SECURITY DEFINER + retailer-filter gir kun
-- navn/butikknummer (ikke forretningsdata) — aldri en annen kjedes stasjoner.
-- =====================================================================
create or replace function public.malekort_stasjoner()
returns table(id uuid, navn text, butikknummer text)
language sql stable security definer set search_path = public as $$
  select id, navn, butikknummer
  from public.stasjoner
  where slettet_tid is null and retailer_id = public.gjeldende_retailer_id()
  order by butikknummer
$$;
grant execute on function public.malekort_stasjoner() to authenticated;
