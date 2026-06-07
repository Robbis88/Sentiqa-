-- =====================================================================
-- Sentiqa — Vær (PROSJEKT.md §7, §18 – yr.no/Open-Meteo)
-- Koordinater per stasjon + daglig vær (temp maks/min, nedbør). Hentes fra
-- Open-Meteo (gratis, ingen nøkkel). Grunnlag for vær-sensitivitet og
-- produksjonsplan. RLS via stasjonstilgang.
-- =====================================================================
alter table public.stasjoner add column if not exists breddegrad numeric;
alter table public.stasjoner add column if not exists lengdegrad numeric;

create table if not exists public.vaer (
  id          uuid primary key default gen_random_uuid(),
  stasjon_id  uuid not null references public.stasjoner(id) on delete cascade,
  dato        date not null,
  temp_maks   numeric,
  temp_min    numeric,
  nedbor_mm   numeric,
  hentet_tid  timestamptz not null default now(),
  unique (stasjon_id, dato)
);
create index if not exists vaer_stasjon_dato_idx on public.vaer (stasjon_id, dato);

alter table public.vaer enable row level security;

drop policy if exists vaer_les on public.vaer;
create policy vaer_les on public.vaer for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists vaer_skriv on public.vaer;
create policy vaer_skriv on public.vaer for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and public.har_stasjonstilgang(stasjon_id))
  with check (public.gjeldende_rolle() = 'retailer_admin' and public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.vaer to authenticated;
