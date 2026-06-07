-- =====================================================================
-- Sentiqa — Eier-regnskapsanalyse (PROSJEKT.md §8C)
-- Strukturert AI-rapport for eieren per periode (sammendrag, per-stasjon
-- status, røde flagg, muligheter, tiltak). Lagres som jsonb. Kun eier (§8C).
-- =====================================================================
create table if not exists public.regnskapsanalyser (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  periode       date not null,
  analyse       jsonb not null,
  modell        text,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists regnskapsanalyser_retailer_periode_idx
  on public.regnskapsanalyser (retailer_id, periode);

alter table public.regnskapsanalyser enable row level security;

-- Kun eier (regnskapsanalyse er eier-nivå, §8C).
drop policy if exists regnskapsanalyser_eier on public.regnskapsanalyser;
create policy regnskapsanalyser_eier on public.regnskapsanalyser for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.regnskapsanalyser to authenticated;
