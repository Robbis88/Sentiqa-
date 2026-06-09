-- =====================================================================
-- Sentiqa — Opplæring v2 (4 tabeller). Master-oppgaveliste (delt) + periode
-- per nyansatt + skift-kalender + kvitt-bok. Multi-tenant (retailer_id + RLS).
-- UI bygges som eget steg; tabellene legges her.
-- =====================================================================
create table if not exists public.opplaering_oppgave (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  tittel        text not null check (length(trim(tittel)) > 0),
  beskrivelse   text,
  kategori      text not null default 'Generelt',
  rekkefolge    int not null default 0,
  estimert_min  int,
  aktiv         boolean not null default true,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists opplaering_oppgave_kategori_idx on public.opplaering_oppgave (retailer_id, kategori);

create table if not exists public.opplaering_periode (
  id             uuid primary key default gen_random_uuid(),
  retailer_id    uuid not null references public.retailers(id) on delete restrict,
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  ansatt_navn    text not null,
  start_dato     date not null,
  forventet_slutt date,
  fullfort_tid   timestamptz,
  notater        text,
  opprettet_av   uuid references auth.users(id) on delete set null,
  opprettet_tid  timestamptz not null default now()
);
create index if not exists opplaering_periode_stasjon_idx on public.opplaering_periode (stasjon_id);

create table if not exists public.opplaering_skift (
  id                  uuid primary key default gen_random_uuid(),
  periode_id          uuid not null references public.opplaering_periode(id) on delete cascade,
  dato                date not null,
  ansvarlig_bruker_id uuid references auth.users(id) on delete set null,
  notater             text,
  opprettet_tid       timestamptz not null default now(),
  unique (periode_id, dato)
);
create index if not exists opplaering_skift_periode_idx on public.opplaering_skift (periode_id);

create table if not exists public.opplaering_utfort (
  id            uuid primary key default gen_random_uuid(),
  periode_id    uuid not null references public.opplaering_periode(id) on delete cascade,
  oppgave_id    uuid not null references public.opplaering_oppgave(id) on delete cascade,
  utfort_tid    timestamptz not null default now(),
  bekreftet_av  uuid references auth.users(id) on delete set null,
  notater       text,
  unique (periode_id, oppgave_id)
);
create index if not exists opplaering_utfort_periode_idx on public.opplaering_utfort (periode_id);

alter table public.opplaering_oppgave enable row level security;
alter table public.opplaering_periode enable row level security;
alter table public.opplaering_skift   enable row level security;
alter table public.opplaering_utfort  enable row level security;

drop policy if exists opp2_oppgave_les on public.opplaering_oppgave;
create policy opp2_oppgave_les on public.opplaering_oppgave for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists opp2_oppgave_skriv on public.opplaering_oppgave;
create policy opp2_oppgave_skriv on public.opplaering_oppgave for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists opp2_periode_les on public.opplaering_periode;
create policy opp2_periode_les on public.opplaering_periode for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));
drop policy if exists opp2_periode_skriv on public.opplaering_periode;
create policy opp2_periode_skriv on public.opplaering_periode for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

-- Skift + utført følger periodens stasjonstilgang.
drop policy if exists opp2_skift_les on public.opplaering_skift;
create policy opp2_skift_les on public.opplaering_skift for select to authenticated
  using (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id)));
drop policy if exists opp2_skift_skriv on public.opplaering_skift;
create policy opp2_skift_skriv on public.opplaering_skift for all to authenticated
  using (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')))
  with check (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')));

drop policy if exists opp2_utfort_les on public.opplaering_utfort;
create policy opp2_utfort_les on public.opplaering_utfort for select to authenticated
  using (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id)));
drop policy if exists opp2_utfort_skriv on public.opplaering_utfort;
create policy opp2_utfort_skriv on public.opplaering_utfort for all to authenticated
  using (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')))
  with check (exists (select 1 from public.opplaering_periode p where p.id = periode_id and public.har_stasjonstilgang(p.stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')));

grant select, insert, update, delete on public.opplaering_oppgave to authenticated;
grant select, insert, update, delete on public.opplaering_periode to authenticated;
grant select, insert, update, delete on public.opplaering_skift to authenticated;
grant select, insert, update, delete on public.opplaering_utfort to authenticated;
