-- =====================================================================
-- Sentiqa — Varsler (in-app, PROSJEKT.md §2 tverrgående, §11)
-- Et varsel kan være til en bestemt bruker (mottaker_id), en stasjon
-- (alle med tilgang) eller tenant-bredt (eier). RLS gir hver bruker kun
-- sine egne. E-post/SMS/web-push kan kobles på samme tabell senere.
-- =====================================================================
create table if not exists public.varsler (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  mottaker_id   uuid references auth.users(id) on delete cascade,    -- null = rolle/stasjon-basert
  stasjon_id    uuid references public.stasjoner(id) on delete cascade,
  type          text not null,                                       -- 'import_feil' | 'sjekkpunkt' | …
  tittel        text not null,
  tekst         text,
  lenke         text,
  lest          boolean not null default false,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists varsler_retailer_lest_idx on public.varsler (retailer_id, lest);

alter table public.varsler enable row level security;

-- Hvem ser et varsel: mottakeren selv, alle med stasjonstilgang (stasjon-varsel),
-- eller eier (tenant-bredt varsel).
drop policy if exists varsler_les on public.varsler;
create policy varsler_les on public.varsler for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = public.gjeldende_retailer_id()
    and (
      mottaker_id = auth.uid()
      or (mottaker_id is null and stasjon_id is not null and public.har_stasjonstilgang(stasjon_id))
      or (mottaker_id is null and stasjon_id is null and public.gjeldende_rolle() = 'retailer_admin')
    )
  );

-- Innlogget kan opprette varsel i egen tenant (app-laget lager dem server-side).
drop policy if exists varsler_insert on public.varsler;
create policy varsler_insert on public.varsler for insert to authenticated
  with check (retailer_id = public.gjeldende_retailer_id());

-- Markere som lest: kun rader man selv ser.
drop policy if exists varsler_update on public.varsler;
create policy varsler_update on public.varsler for update to authenticated
  using (
    retailer_id = public.gjeldende_retailer_id()
    and (
      mottaker_id = auth.uid()
      or (mottaker_id is null and stasjon_id is not null and public.har_stasjonstilgang(stasjon_id))
      or (mottaker_id is null and stasjon_id is null and public.gjeldende_rolle() = 'retailer_admin')
    )
  );

grant select, insert, update, delete on public.varsler to authenticated;
