-- =====================================================================
-- Sentiqa — Oppgaver (PROSJEKT.md §8A handling, §16.5)
-- Enkle oppgaver per stasjon. Opprettes av eier/butikksjef (også via AI-en),
-- fullføres med avkryssing. RLS via stasjonstilgang.
-- =====================================================================
create table if not exists public.oppgaver (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  tittel        text not null,
  beskrivelse   text,
  status        text not null default 'apen' check (status in ('apen', 'fullfort')),
  frist         date,
  opprettet_av  uuid references auth.users(id) on delete set null,
  fullfort_av   uuid references auth.users(id) on delete set null,
  fullfort_tid  timestamptz,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists oppgaver_stasjon_status_idx on public.oppgaver (stasjon_id, status);

alter table public.oppgaver enable row level security;

drop policy if exists oppgaver_les on public.oppgaver;
create policy oppgaver_les on public.oppgaver for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));

drop policy if exists oppgaver_skriv on public.oppgaver;
create policy oppgaver_skriv on public.oppgaver for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.oppgaver to authenticated;
