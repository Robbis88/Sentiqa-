-- =====================================================================
-- Sentiqa — Puls / ansatt-trivsel (PROSJEKT.md engasjement)
-- Rask daglig stemningssjekk fra ansatte (humør 1–5 + valgfri kommentar).
-- Ansatte registrerer; eier/butikksjef ser aggregat + anonyme kommentarer
-- (tablet kan IKKE lese andres svar → ærlig tilbakemelding). RLS via stasjon.
-- =====================================================================
create table if not exists public.puls_svar (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ansatt_id     uuid references public.ansatte(id) on delete set null,
  dato          date not null,
  humor         int not null check (humor between 1 and 5),
  kommentar     text,
  opprettet_tid timestamptz not null default now()
);
create index if not exists puls_svar_stasjon_dato_idx on public.puls_svar (stasjon_id, dato);
-- Ett svar per ansatt per dag (kan oppdateres).
create unique index if not exists puls_svar_ansatt_dag on public.puls_svar (ansatt_id, dato) where ansatt_id is not null;

alter table public.puls_svar enable row level security;

-- Kun leder ser svarene (aggregat/kommentarer) — tablet kan ikke lese.
drop policy if exists puls_les on public.puls_svar;
create policy puls_les on public.puls_svar for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

-- Alle med stasjonstilgang kan gi puls (også tablet).
drop policy if exists puls_insert on public.puls_svar;
create policy puls_insert on public.puls_svar for insert to authenticated
  with check (public.har_stasjonstilgang(stasjon_id));
drop policy if exists puls_update on public.puls_svar;
create policy puls_update on public.puls_svar for update to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update on public.puls_svar to authenticated;
