-- =====================================================================
-- Sentiqa - «Send til tablet»: en oppgave med vis_paa_tablet vises som et
-- avhukbart kort i «Meldinger fra butikksjef» pa tablet-forsiden. Valgfritt
-- bilde. RLS uendret (oppgaver-tabellens egne policyer).
-- =====================================================================
alter table public.oppgaver
  add column if not exists vis_paa_tablet boolean not null default false,
  add column if not exists bilde_url      text;

create index if not exists oppgaver_tablet_idx on public.oppgaver (stasjon_id) where vis_paa_tablet;

-- Tablet-brukeren (butikkbruker) far kvittere «utfort» pa en vis_paa_tablet-melding
-- uten full skrivetilgang til oppgaver. Security definer + sjekk i WHERE.
create or replace function public.kvitter_tablet_melding(p_oppgave uuid, p_fullfort boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.oppgaver set
    status = case when p_fullfort then 'fullfort' else 'apen' end,
    fullfort_av = case when p_fullfort then auth.uid() else null end,
    fullfort_tid = case when p_fullfort then now() else null end
  where id = p_oppgave and vis_paa_tablet and public.har_stasjonstilgang(stasjon_id);
end $$;
grant execute on function public.kvitter_tablet_melding(uuid, boolean) to authenticated;
