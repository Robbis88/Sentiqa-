-- =====================================================================
-- Sentiqa — Rutineskjema-system, etappe 1 (PROSJEKT.md §16.5 / §5)
-- Skjema pr vakttype (morgen/dag/kveld/natt) med konfigurerbart tidsvindu +
-- ukedager. Rutiner hører til et skjema og kan ha egne ukedager (tom = arv).
-- Tablet viser riktig skjema ut fra Oslo-klokka. RLS via stasjonstilgang.
-- =====================================================================
create table if not exists public.rutineskjemaer (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  vakttype      text not null check (vakttype in ('morgen', 'dag', 'kveld', 'natt')),
  navn          text,
  tid_start     text not null,                  -- "HH:MM" (Oslo)
  tid_slutt     text not null,                  -- "HH:MM" (kan krysse midnatt)
  ukedager      int[] not null default '{}',    -- 0=søn..6=lør; tom = alle dager
  aktiv         boolean not null default true,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists rutineskjemaer_stasjon_idx on public.rutineskjemaer (stasjon_id);

-- Rutiner hører nå til et skjema, med egne ukedager (tom = arv) og en
-- opprettet-dato (vi hopper over datoer før rutinen fantes).
alter table public.rutiner add column if not exists skjema_id uuid references public.rutineskjemaer(id) on delete cascade;
alter table public.rutiner add column if not exists ukedager int[] not null default '{}';
alter table public.rutiner add column if not exists opprettet_dato date not null default ((now() at time zone 'Europe/Oslo')::date);
alter table public.rutiner add column if not exists sortering int not null default 0;

-- «Ekstra»-utførelser holdes utenfor prosent-scoren (etappe 2).
alter table public.rutine_utforinger add column if not exists ekstra boolean not null default false;

alter table public.rutineskjemaer enable row level security;

drop policy if exists rutineskjemaer_les on public.rutineskjemaer;
create policy rutineskjemaer_les on public.rutineskjemaer for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));

drop policy if exists rutineskjemaer_skriv on public.rutineskjemaer;
create policy rutineskjemaer_skriv on public.rutineskjemaer for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.rutineskjemaer to authenticated;
