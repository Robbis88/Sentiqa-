-- =====================================================================
-- Sentiqa — Opplæring nyansatte (PROSJEKT.md §16.5)
-- Læreplan (punkter per område, delt i kjeden) + personer under opplæring +
-- fullført-sporing med signering. RLS via stasjonstilgang; læreplanen er
-- tenant-bred. Signering gjøres av leder (eier/butikksjef).
-- =====================================================================
create table if not exists public.opplaring_punkter (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  omrade        text not null,
  tekst         text not null,
  sortering     int not null default 0,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists opplaring_punkter_retailer_idx on public.opplaring_punkter (retailer_id);

create table if not exists public.opplaring_personer (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  navn          text not null,
  startdato     date,
  aktiv         boolean not null default true,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists opplaring_personer_stasjon_idx on public.opplaring_personer (stasjon_id);

create table if not exists public.opplaring_fullfort (
  id             uuid primary key default gen_random_uuid(),
  person_id      uuid not null references public.opplaring_personer(id) on delete cascade,
  punkt_id       uuid not null references public.opplaring_punkter(id) on delete cascade,
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  signert_av     uuid references auth.users(id) on delete set null,
  fullfort_dato  date not null,
  opprettet_tid  timestamptz not null default now(),
  unique (person_id, punkt_id)
);

alter table public.opplaring_punkter  enable row level security;
alter table public.opplaring_personer enable row level security;
alter table public.opplaring_fullfort enable row level security;

drop policy if exists opplaring_punkter_les on public.opplaring_punkter;
create policy opplaring_punkter_les on public.opplaring_punkter for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists opplaring_punkter_skriv on public.opplaring_punkter;
create policy opplaring_punkter_skriv on public.opplaring_punkter for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists opplaring_personer_les on public.opplaring_personer;
create policy opplaring_personer_les on public.opplaring_personer for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));
drop policy if exists opplaring_personer_skriv on public.opplaring_personer;
create policy opplaring_personer_skriv on public.opplaring_personer for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists opplaring_fullfort_les on public.opplaring_fullfort;
create policy opplaring_fullfort_les on public.opplaring_fullfort for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));
drop policy if exists opplaring_fullfort_skriv on public.opplaring_fullfort;
create policy opplaring_fullfort_skriv on public.opplaring_fullfort for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.opplaring_punkter to authenticated;
grant select, insert, update, delete on public.opplaring_personer to authenticated;
grant select, insert, update, delete on public.opplaring_fullfort to authenticated;
