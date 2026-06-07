-- =====================================================================
-- Sentiqa — Drift: rutiner (PROSJEKT.md §11, §16.5)
-- Butikksjef/eier lager rutiner per stasjon; tablet/butikksjef krysser av
-- daglig. RLS via stasjonstilgang (admin alt eget, butikksjef/tablet tildelte).
-- Forenklet v1: ingen vakt/tidsvindu ennå — rutinen gjelder daglig.
-- =====================================================================
create table if not exists public.rutiner (
  id             uuid primary key default gen_random_uuid(),
  retailer_id    uuid not null references public.retailers(id) on delete restrict,
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  tittel         text not null,
  beskrivelse    text,
  paakrevd_bilde boolean not null default false,
  opprettet_av   uuid references auth.users(id) on delete set null,
  opprettet_tid  timestamptz not null default now(),
  slettet_tid    timestamptz
);
create index if not exists rutiner_stasjon_idx on public.rutiner (stasjon_id);

create table if not exists public.rutine_utforinger (
  id          uuid primary key default gen_random_uuid(),
  rutine_id   uuid not null references public.rutiner(id) on delete cascade,
  stasjon_id  uuid not null references public.stasjoner(id) on delete cascade,
  dato        date not null,
  utfort_av   uuid references auth.users(id) on delete set null,
  utfort_tid  timestamptz not null default now(),
  unique (rutine_id, dato)
);

alter table public.rutiner            enable row level security;
alter table public.rutine_utforinger  enable row level security;

-- rutiner: alle med stasjonstilgang leser; admin + butikksjef skriver for sine.
drop policy if exists rutiner_les on public.rutiner;
create policy rutiner_les on public.rutiner for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));

drop policy if exists rutiner_skriv on public.rutiner;
create policy rutiner_skriv on public.rutiner for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

-- utføringer: alle med stasjonstilgang leser og krysser av (også tablet).
drop policy if exists rutine_utforinger_les on public.rutine_utforinger;
create policy rutine_utforinger_les on public.rutine_utforinger for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists rutine_utforinger_skriv on public.rutine_utforinger;
create policy rutine_utforinger_skriv on public.rutine_utforinger for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.rutiner, public.rutine_utforinger to authenticated;
