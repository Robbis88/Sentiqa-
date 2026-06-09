-- =====================================================================
-- Sentiqa — Tablet-meldinger (PROSJEKT.md §16.5, tablet)
-- Eier/butikksjef sender korte beskjeder som vises på stasjons-tableten.
-- stasjon_id null = hele kjeden. RLS via tenant + stasjonstilgang.
-- =====================================================================
create table if not exists public.tablet_meldinger (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid references public.stasjoner(id) on delete cascade,  -- null = alle stasjoner
  tekst         text not null,
  viktig        boolean not null default false,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists tablet_meldinger_retailer_idx on public.tablet_meldinger (retailer_id);

alter table public.tablet_meldinger enable row level security;

-- Leses av alle i tenant for sin stasjon (eller kjede-brede).
drop policy if exists tablet_meldinger_les on public.tablet_meldinger;
create policy tablet_meldinger_les on public.tablet_meldinger for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = public.gjeldende_retailer_id()
    and (stasjon_id is null or public.har_stasjonstilgang(stasjon_id))
  );

drop policy if exists tablet_meldinger_skriv on public.tablet_meldinger;
create policy tablet_meldinger_skriv on public.tablet_meldinger for all to authenticated
  using (
    retailer_id = public.gjeldende_retailer_id()
    and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or public.har_stasjonstilgang(stasjon_id))
  )
  with check (
    retailer_id = public.gjeldende_retailer_id()
    and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or public.har_stasjonstilgang(stasjon_id))
  );

grant select, insert, update, delete on public.tablet_meldinger to authenticated;
