-- =====================================================================
-- Sentiqa — Produksjonsplan-linjer (PROSJEKT.md §7)
-- Lagret/overstyrbar produksjonsplan per produkt per stasjon per dag.
-- AI-forslaget (foreslatt) bevares; brukeren kan justere (planlagt). RLS via
-- stasjonstilgang. Gruppering på varegruppe gjøres i app-laget.
-- =====================================================================
create table if not exists public.produksjonsplan_linjer (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete restrict,
  stasjon_id      uuid not null references public.stasjoner(id) on delete cascade,
  dato            date not null,
  varenavn        text not null,
  varegruppe_kode text,
  varegruppe_navn text,
  foreslatt       int not null default 0,
  planlagt        int not null default 0,
  oppdatert_tid   timestamptz not null default now(),
  unique (stasjon_id, dato, varenavn)
);
create index if not exists produksjonsplan_stasjon_dato_idx on public.produksjonsplan_linjer (stasjon_id, dato);

alter table public.produksjonsplan_linjer enable row level security;

drop policy if exists produksjonsplan_les on public.produksjonsplan_linjer;
create policy produksjonsplan_les on public.produksjonsplan_linjer for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists produksjonsplan_skriv on public.produksjonsplan_linjer;
create policy produksjonsplan_skriv on public.produksjonsplan_linjer for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.produksjonsplan_linjer to authenticated;
