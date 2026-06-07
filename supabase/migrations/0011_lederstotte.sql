-- =====================================================================
-- Sentiqa — Lederstøtte-rapport (PROSJEKT.md §8D)
-- Utviklingsorientert coaching-rapport per stasjon (grønn/gul/blå, aldri
-- rød/«dårlig»). Butikksjef ser egen. Lagres som jsonb per stasjon/periode.
-- =====================================================================
create table if not exists public.lederstotte_rapporter (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  periode       date not null,
  rapport       jsonb not null,
  modell        text,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists lederstotte_stasjon_periode_idx
  on public.lederstotte_rapporter (stasjon_id, periode);

alter table public.lederstotte_rapporter enable row level security;

drop policy if exists lederstotte_les on public.lederstotte_rapporter;
create policy lederstotte_les on public.lederstotte_rapporter for select to authenticated
  using (
    slettet_tid is null and (
      (public.gjeldende_rolle() = 'retailer_admin'
       and retailer_id = public.gjeldende_retailer_id())
      or public.har_stasjonstilgang(stasjon_id)
    )
  );

drop policy if exists lederstotte_skriv on public.lederstotte_rapporter;
create policy lederstotte_skriv on public.lederstotte_rapporter for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.lederstotte_rapporter to authenticated;
