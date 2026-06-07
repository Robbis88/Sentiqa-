-- =====================================================================
-- Sentiqa — E-post-inntak (PROSJEKT.md §6)
-- Per-tenant innboks-adresse + avsender-allowlist. En webhook tar imot
-- videresendte e-poster (vedlegg → kø). retailers oppdateres av eier (RLS finnes).
-- =====================================================================
alter table public.retailers add column if not exists inntak_epost text;
alter table public.retailers add column if not exists avsender_allowlist text[] not null default '{}';

-- Unik innboks-adresse per tenant.
create unique index if not exists retailers_inntak_epost_unik
  on public.retailers (lower(inntak_epost)) where inntak_epost is not null;

-- Sett en standard innboks-adresse fra slug for eksisterende tenants.
update public.retailers
  set inntak_epost = slug || '@inn.sentiqa.ai'
  where inntak_epost is null and slug is not null;
