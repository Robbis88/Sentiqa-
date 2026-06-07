-- =====================================================================
-- Sentiqa — Drift: sjekkpunkt-tablet (PROSJEKT.md §11)
-- Tidsstyrte ja/nei-sjekkpunkter på tablet. Daglig gjentakelse, rent ja/nei.
-- Eier/butikksjef ser svarene. Separat fra rutineskjema. RLS via stasjonstilgang.
-- =====================================================================
create table if not exists public.sjekkpunkter (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  sporsmaal     text not null,
  klokkeslett   text,                              -- "HH:MM"
  kritisk       boolean not null default false,    -- «Nei» her er verdt et varsel
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists sjekkpunkter_stasjon_idx on public.sjekkpunkter (stasjon_id);

create table if not exists public.sjekkpunkt_svar (
  id            uuid primary key default gen_random_uuid(),
  sjekkpunkt_id uuid not null references public.sjekkpunkter(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  dato          date not null,
  svar          boolean not null,                  -- true = ja
  svart_av      uuid references auth.users(id) on delete set null,
  svart_tid     timestamptz not null default now(),
  unique (sjekkpunkt_id, dato)
);

alter table public.sjekkpunkter     enable row level security;
alter table public.sjekkpunkt_svar  enable row level security;

drop policy if exists sjekkpunkter_les on public.sjekkpunkter;
create policy sjekkpunkter_les on public.sjekkpunkter for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));

drop policy if exists sjekkpunkter_skriv on public.sjekkpunkter;
create policy sjekkpunkter_skriv on public.sjekkpunkter for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists sjekkpunkt_svar_les on public.sjekkpunkt_svar;
create policy sjekkpunkt_svar_les on public.sjekkpunkt_svar for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists sjekkpunkt_svar_skriv on public.sjekkpunkt_svar;
create policy sjekkpunkt_svar_skriv on public.sjekkpunkt_svar for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.sjekkpunkter, public.sjekkpunkt_svar to authenticated;
