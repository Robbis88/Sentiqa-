-- =====================================================================
-- Sentiqa — Anvisninger + Lenker (PROSJEKT.md §16.5, tablet)
-- Anvisninger = prosedyre-/oppskrift-bibliotek de ansatte slår opp i.
-- Lenker = hurtiglenker til eksterne verktøy. Begge tenant-brede; alle ser,
-- eier/butikksjef redigerer. RLS via tenant.
-- =====================================================================
create table if not exists public.anvisninger (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  kategori      text not null default 'Generelt',
  tittel        text not null,
  innhold       text not null,
  sortering     int not null default 0,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists anvisninger_retailer_idx on public.anvisninger (retailer_id);

create table if not exists public.lenker (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  tittel        text not null,
  url           text not null,
  ikon          text not null default '🔗',
  sortering     int not null default 0,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists lenker_retailer_idx on public.lenker (retailer_id);

alter table public.anvisninger enable row level security;
alter table public.lenker      enable row level security;

drop policy if exists anvisninger_les on public.anvisninger;
create policy anvisninger_les on public.anvisninger for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists anvisninger_skriv on public.anvisninger;
create policy anvisninger_skriv on public.anvisninger for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists lenker_les on public.lenker;
create policy lenker_les on public.lenker for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists lenker_skriv on public.lenker;
create policy lenker_skriv on public.lenker for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.anvisninger to authenticated;
grant select, insert, update, delete on public.lenker to authenticated;
