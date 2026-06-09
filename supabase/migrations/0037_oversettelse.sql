-- =====================================================================
-- Sentiqa — Oversettelses-cache (PROSJEKT.md §16.5, tablet flerspråk)
-- Innholds-adressert cache (sha256 av kildetekst). Endres en rutine, endres
-- hashen → ny oversettelse (auto-invalidering). Skrives/leses kun av
-- service-role (app-laget), RLS låser ute alt annet.
-- =====================================================================
create table if not exists public.oversettelse_cache (
  id            uuid primary key default gen_random_uuid(),
  sprak         text not null,
  kilde_hash    text not null,
  oversatt      text not null,
  opprettet_tid timestamptz not null default now(),
  unique (sprak, kilde_hash)
);
create index if not exists oversettelse_cache_idx on public.oversettelse_cache (sprak, kilde_hash);

alter table public.oversettelse_cache enable row level security;
-- Ingen policy for authenticated → kun service-role (omgår RLS) når app-laget cacher.
grant select, insert, update on public.oversettelse_cache to service_role;
