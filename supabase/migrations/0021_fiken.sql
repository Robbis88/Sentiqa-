-- =====================================================================
-- Sentiqa — Fiken-fakturering (PROSJEKT.md §4)
-- Lagrer Fiken-kontakt-ID per tenant (opprettes ved første faktura), så vi
-- gjenbruker kunden i Fiken i stedet for å lage dubletter.
-- =====================================================================
alter table public.retailers add column if not exists fiken_kontakt_id bigint;
