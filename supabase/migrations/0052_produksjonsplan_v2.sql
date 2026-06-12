-- =====================================================================
-- Sentiqa - Produksjonsplan v2: redigering (ekskluder, startAntall, manuelt
-- kampanje-flagg), tablet-fremdrift (lagd_hittil), og plan-hode (notat +
-- publisering pr stasjon/dag). RLS via stasjonstilgang (som linjene).
-- =====================================================================
alter table public.produksjonsplan_linjer
  add column if not exists ekskludert       boolean not null default false,
  add column if not exists start_antall      int not null default 0,
  add column if not exists lagd_hittil       int not null default 0,
  add column if not exists kampanje_manuell  boolean not null default false;

create table if not exists public.produksjonsplan_hode (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  dato          date not null,
  notat         text,
  publisert_tid timestamptz,
  oppdatert_tid timestamptz not null default now(),
  unique (stasjon_id, dato)
);
create index if not exists produksjonsplan_hode_idx on public.produksjonsplan_hode (stasjon_id, dato);

alter table public.produksjonsplan_hode enable row level security;

drop policy if exists produksjonsplan_hode_les on public.produksjonsplan_hode;
create policy produksjonsplan_hode_les on public.produksjonsplan_hode for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists produksjonsplan_hode_skriv on public.produksjonsplan_hode;
create policy produksjonsplan_hode_skriv on public.produksjonsplan_hode for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.produksjonsplan_hode to authenticated;
