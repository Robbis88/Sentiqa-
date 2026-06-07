-- =====================================================================
-- Sentiqa — AI-konkurranser (PROSJEKT.md §9, §11)
-- Samtalestyrte konkurranser mellom stasjoner. Måling gjenbruker daglig_salg
-- (AI gjetter aldri). Premie kobles til pengepremier senere. RLS: hele tenant
-- ser konkurransen (relativ plassering er lov §8); kun eier oppretter/kårer.
-- =====================================================================
create table if not exists public.konkurranser (
  id                uuid primary key default gen_random_uuid(),
  retailer_id       uuid not null references public.retailers(id) on delete restrict,
  navn              text not null,
  kpi               text not null,                 -- fritekst, f.eks. "omsetning pølse"
  varegruppe_kode   text,                           -- hvilken varegruppe måles (null = all omsetning)
  maaltype          text not null default 'omsetning' check (maaltype in ('omsetning', 'antall')),
  stasjon_ids       uuid[] not null default '{}',   -- tomt = alle stasjoner i tenant
  periode_start     date not null,
  periode_slutt     date not null,
  premie_kr         numeric,
  status            text not null default 'aktiv' check (status in ('aktiv', 'avsluttet')),
  vinner_stasjon_id uuid references public.stasjoner(id) on delete set null,
  opprettet_av      uuid references auth.users(id) on delete set null,
  opprettet_tid     timestamptz not null default now(),
  slettet_tid       timestamptz
);
create index if not exists konkurranser_retailer_idx on public.konkurranser (retailer_id, status);

alter table public.konkurranser enable row level security;

-- Hele tenant ser konkurransen (relativ plassering, §8). Eksakte tall vises
-- kun til eier i app-laget.
drop policy if exists konkurranser_les on public.konkurranser;
create policy konkurranser_les on public.konkurranser for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());

drop policy if exists konkurranser_skriv on public.konkurranser;
create policy konkurranser_skriv on public.konkurranser for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.konkurranser to authenticated;
