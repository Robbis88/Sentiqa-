-- =====================================================================
-- 0197  stotte_oppslag.id: bigint identity -> uuid
-- =====================================================================
-- 0196 ga loggen `id bigint generated always as identity`. Det var et
-- valg uten grunn: hver eneste andre tabell i denne basen har en
-- uuid-primaernoekkel, og generatoren for tenant-atferdsmatrisen antar
-- det. Den seeder en uuid for `id` og setter den i proberaden - se
-- `idKol()` og `seedId()` i src/lib/tenant/generer.ts.
--
-- Resultatet var en CI-feil som ikke handlet om sikkerhet i det hele
-- tatt:
--
--   ERROR: invalid input syntax for type bigint: "43f6149a-0000-..."
--
-- Det er noeyaktig formen AGENTS.md advarer mot under
-- "Generatorantakelser skal testes direkte": en formfeil, ikke en
-- autorisasjonsfeil. En autorisasjonsfeil gir 42501 og roper. En
-- formfeil later som den er noe annet, og koster en CI-runde per symptom.
--
-- ---------------------------------------------------------------------
-- HVORFOR EN NY FIL, OG IKKE EN RETTELSE I 0196
--
-- 0196 er kjoert mot produksjon. En migrasjon som er kjoert skal ikke
-- endres: da sier fila en ting og basen en annen, og `if not exists`
-- soerger for at forskjellen aldri retter seg selv. To sannheter om samme
-- tabell er verre enn en stygg kolonnetype.
--
-- ---------------------------------------------------------------------
-- VAKTET PAA information_schema, ikke paa `if exists`
--
-- `drop column if exists` + `add column if not exists` ville vaert
-- re-kjoerbart i ordets forstand og likevel farlig: andre gang ville den
-- SLETTET kolonnen med data i. Denne fyrer bare naar kolonnen fremdeles
-- er bigint. Er den alt uuid, skjer ingenting. Samme moenster som
-- 0026/0038.
--
-- Tabellen er tom naar dette kjoeres: ingenting skriver til den foer
-- porten er deployet. Konverteringen taper derfor ingen rader - men
-- vakten staar der uansett, fordi "den er tom naa" ikke er en egenskap
-- ved migrasjonen.
-- =====================================================================

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stotte_oppslag'
      and column_name = 'id'
      and data_type = 'bigint'
  ) then
    alter table public.stotte_oppslag drop column id;
    alter table public.stotte_oppslag
      add column id uuid primary key default gen_random_uuid();
  end if;
end $$;
