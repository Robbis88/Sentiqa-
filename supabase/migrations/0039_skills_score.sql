-- =====================================================================
-- Sentiqa — Skills-score (tablet-hjem). Butikksjef registrerer treningsapp-
-- score (%) per stasjon. Tableten viser siste score m/motiverende tekst.
-- Multi-tenant: retailer_id + RLS via stasjonstilgang/rolle.
-- =====================================================================
create table if not exists public.skills_score (
  id             uuid primary key default gen_random_uuid(),
  retailer_id    uuid not null references public.retailers(id) on delete restrict,
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  prosent        numeric(5,2) not null check (prosent >= 0 and prosent <= 100),
  kommentar      text,
  registrert_av  uuid references auth.users(id) on delete set null,
  registrert_tid timestamptz not null default now()
);
create index if not exists skills_score_stasjon_idx on public.skills_score (stasjon_id, registrert_tid desc);

alter table public.skills_score enable row level security;

-- Lese: alle med stasjonstilgang (admin ser egne stasjoner, tablet sin egen).
drop policy if exists skills_les on public.skills_score;
create policy skills_les on public.skills_score for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

-- Skrive/slette: eier/butikksjef for stasjonen (tablet blokkeres på rolle).
drop policy if exists skills_skriv on public.skills_score;
create policy skills_skriv on public.skills_score for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.skills_score to authenticated;
