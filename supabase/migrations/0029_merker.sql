-- =====================================================================
-- Sentiqa — Merker / badges (PROSJEKT.md engasjement/gamification)
-- Anerkjennelses-merker til ansatte. Ledere definerer merker (tenant-bredt)
-- og tildeler dem. Merkeveggen er synlig for alle med stasjonstilgang (motiverer).
-- =====================================================================
create table if not exists public.merker (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  navn          text not null,
  beskrivelse   text,
  emoji         text not null default '⭐',
  sortering     int not null default 0,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists merker_retailer_idx on public.merker (retailer_id);

create table if not exists public.tildelte_merker (
  id            uuid primary key default gen_random_uuid(),
  merke_id      uuid not null references public.merker(id) on delete cascade,
  ansatt_id     uuid not null references public.ansatte(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  tildelt_av    uuid references auth.users(id) on delete set null,
  tildelt_dato  date not null,
  opprettet_tid timestamptz not null default now(),
  unique (merke_id, ansatt_id)
);
create index if not exists tildelte_merker_ansatt_idx on public.tildelte_merker (ansatt_id);

alter table public.merker          enable row level security;
alter table public.tildelte_merker enable row level security;

drop policy if exists merker_les on public.merker;
create policy merker_les on public.merker for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists merker_skriv on public.merker;
create policy merker_skriv on public.merker for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists tildelte_les on public.tildelte_merker;
create policy tildelte_les on public.tildelte_merker for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));
drop policy if exists tildelte_skriv on public.tildelte_merker;
create policy tildelte_skriv on public.tildelte_merker for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.merker to authenticated;
grant select, insert, update, delete on public.tildelte_merker to authenticated;
