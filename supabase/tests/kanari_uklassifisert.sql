-- =====================================================================
-- Kanarifuglen for dekningskontrollen.
--
-- Lager en tabell som ingen har klassifisert. `tenant_dekning.sql` SKAL
-- felle paa den. Gjor den ikke det, maaler den ingenting - og en
-- dekningssjekk som ikke maaler ser noeyaktig ut som en base uten hull.
--
-- Kjores i CI mellom to kall paa tenant_dekning.sql:
--
--   1) tenant_dekning.sql            -> skal vaere groenn
--   2) denne fila                    -> lager tabellen
--   3) tenant_dekning.sql            -> skal FEILE
--   4) kanari_uklassifisert_rydd.sql -> fjerner den
--   5) tenant_dekning.sql            -> skal vaere groenn igjen
--
-- Steg 5 er ikke pynt. Uten det ville en dekningssjekk som ALLTID
-- feiler ogsaa bestaatt steg 3.
-- =====================================================================
create table if not exists public.kanari_uklassifisert (
  id          uuid primary key default gen_random_uuid(),
  retailer_id uuid not null references public.retailers(id) on delete restrict,
  stasjon_id  uuid references public.stasjoner(id) on delete cascade,
  notat       text
);

comment on table public.kanari_uklassifisert is
  'MIDLERTIDIG. Lages og droppes av CI for aa bevise at dekningskontrollen '
  'ser en ny tabell. Finner du den i en base, har en kjoring blitt avbrutt '
  'mellom steg 2 og 4 - drop den.';
