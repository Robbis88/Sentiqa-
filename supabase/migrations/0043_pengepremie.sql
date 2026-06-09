-- =====================================================================
-- Sentiqa - Pengepremie (manuelle tildelinger utenom konkurranser).
-- Eier/butikksjef tildeler premie til en stasjon. Saldo = sum(tildelt
-- konkurranse + manuell) - sum(bruk). utbetalt = chain->stasjon utbetalt.
-- =====================================================================
create table if not exists public.pengepremie (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  beskrivelse   text not null check (length(trim(beskrivelse)) > 0),
  belop_kr      numeric not null check (belop_kr > 0),
  dato          date not null default current_date,
  utbetalt      boolean not null default false,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now()
);
create index if not exists pengepremie_stasjon_idx on public.pengepremie (stasjon_id);

alter table public.pengepremie enable row level security;

drop policy if exists pengepremie_les on public.pengepremie;
create policy pengepremie_les on public.pengepremie for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists pengepremie_skriv on public.pengepremie;
create policy pengepremie_skriv on public.pengepremie for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.pengepremie to authenticated;
