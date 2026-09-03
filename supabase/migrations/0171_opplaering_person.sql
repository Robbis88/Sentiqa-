-- =====================================================================
-- OPPLAERINGEN FAAR EN PERSON, OG EN MEDALJE
--
-- `opplaering_periode.ansatt_navn` er FRITEKST. Det holdt saa lenge
-- sjekklista bare skulle dukke opp paa stasjonen: nettbrettet spurte
-- «er det et skift i dag her?», ikke «hvem er du?».
--
-- Men det er nettopp derfor tre ting ikke gikk an:
--
--   1. Lista vises for ALLE som bruker nettbrettet den dagen. Systemet
--      vet ikke hvem den nyansatte er.
--   2. Medaljen kan ikke deles ut. `tildelte_merker.ansatt_id` peker paa
--      en ekte ansatt; et navn er ikke en ansatt.
--   3. «Bestaatt opplaering» kan ikke lagres paa personen.
--
-- AA KOBLE PAA NAVN VILLE VAERT FEIL. Samme ansatt finnes under
-- `ansatt_nr`, `ansatte.id` og fritekst-navn, og en stille navnekobling
-- treffer feil person. Derfor en ekte fremmednoekkel, valgt fra lista.
--
-- `ansatt_navn` blir staaende. Den er historikken: slettes den ansatte,
-- skal det fortsatt gaa an aa se hvem perioden gjaldt. Nye perioder
-- fyller begge.
--
-- ---------------------------------------------------------------------
-- HVILKEN MEDALJE?
--
-- `merker` er kjedens egne. Systemet kan ikke gjette hvilken av dem som
-- betyr «ferdig opplaert», saa kjeden peker den ut selv med
-- `tildeles_ved = 'opplaering_fullfort'`.
--
-- Den PARTIELLE unike indeksen tillater noeyaktig én slik per kjede.
-- Uten den kunne to merker baere samme betydning, og da maatte koden
-- velge - og et valg mellom to like gyldige rader er et tilfeldig valg.
--
-- Idempotent: `add column if not exists` / `create ... if not exists`.
-- =====================================================================

alter table public.opplaering_periode
  add column if not exists ansatt_id uuid references public.ansatte(id) on delete set null;

comment on column public.opplaering_periode.ansatt_id is
  'Den ansatte perioden gjelder. Null for perioder opprettet foer 0171 - '
  'de faller tilbake paa den gamle oppfoerselen: synlig for hele stasjonen.';

create index if not exists opplaering_periode_ansatt_idx
  on public.opplaering_periode (ansatt_id) where ansatt_id is not null;

-- ---------------------------------------------------------------------
-- MEDALJEN
-- ---------------------------------------------------------------------
alter table public.merker
  add column if not exists tildeles_ved text
    check (tildeles_ved is null or tildeles_ved in ('opplaering_fullfort'));

comment on column public.merker.tildeles_ved is
  'Naar merket deles ut automatisk. Null = deles ut for haand, som foer.';

-- Noeyaktig ett merke per kjede kan baere hver automatikk.
create unique index if not exists merker_tildeles_ved_unik
  on public.merker (retailer_id, tildeles_ved)
  where tildeles_ved is not null and slettet_tid is null;

-- ---------------------------------------------------------------------
-- RETTIGHETER
--
-- Ingen nye tabeller, saa ingen nye grants eller policyer. Kolonnene
-- arver tabellenes RLS. `revoke ... from anon` staar allerede paa begge.
-- ---------------------------------------------------------------------
