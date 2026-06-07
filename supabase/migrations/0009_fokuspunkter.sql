-- =====================================================================
-- Sentiqa — Auto-fokus (PROSJEKT.md §8B)
-- AI-genererte fokuspunkter per stasjon etter månedsregnskapet:
-- 3 forbedring + 3 positivt, med konkrete tall. RLS: admin ser alt eget,
-- butikksjef sine tildelte stasjoner.
-- =====================================================================
create table if not exists public.fokuspunkter (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  periode       date not null,
  type          text not null check (type in ('forbedring', 'positivt')),
  tekst         text not null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists fokuspunkter_stasjon_periode_idx
  on public.fokuspunkter (stasjon_id, periode);

alter table public.fokuspunkter enable row level security;

drop policy if exists fokuspunkter_les on public.fokuspunkter;
create policy fokuspunkter_les on public.fokuspunkter for select to authenticated
  using (
    slettet_tid is null and (
      (public.gjeldende_rolle() = 'retailer_admin'
       and retailer_id = public.gjeldende_retailer_id())
      or public.har_stasjonstilgang(stasjon_id)
    )
  );

drop policy if exists fokuspunkter_skriv on public.fokuspunkter;
create policy fokuspunkter_skriv on public.fokuspunkter for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.fokuspunkter to authenticated;
