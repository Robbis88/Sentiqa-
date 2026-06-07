-- =====================================================================
-- Sentiqa — Abonnement (PROSJEKT.md §4)
-- Fakturadetaljer per tenant. Pris beregnes fra antall stasjoner i app-laget.
-- org_nr (fundament) = nøkkel for EHF/PEPPOL-fakturering.
-- =====================================================================
alter table public.retailers add column if not exists faktura_epost text;
alter table public.retailers add column if not exists aarlig_forskudd boolean not null default false;
alter table public.retailers add column if not exists premium_avtalevokter boolean not null default false;
