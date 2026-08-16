-- ---------------------------------------------------------------------
-- 0094: rett opp jobbene som fikk 'ukjent'
-- ---------------------------------------------------------------------
-- MAA kjores ETTER 0093, i en egen kjoring. Postgres nekter aa bruke en
-- enum-verdi i samme transaksjon som den ble lagt til (55P04), og
-- SQL-editoren kjorer hvert skript som en transaksjon.
--
-- Koeveien satte rapporttype med en UPDATE hvis feil aldri ble sjekket.
-- Manglet verdien i enum-en, feilet oppdateringen i stillhet og jobben
-- ble staaende som 'ukjent' - selv om dataene landet riktig. Radene
-- finnes fortsatt, og de gjor importlista uleselig.
--
-- Vaktet paa tre ting samtidig: bare parsede jobber, bare de som staar
-- som 'ukjent', og bare filer som ser ut som det de skal vaere. Kjores
-- dette om igjen, treffer where-en ingenting.
update public.import_jobber j
   set rapporttype = 'st1_salesperhour_inneute'
  from public.raa_filer r
 where r.id = j.raa_fil_id
   and j.rapporttype = 'ukjent'
   and j.status = 'parset'
   and r.filnavn ilike '%timesalgsrapport%';

update public.import_jobber j
   set rapporttype = 'salgsgrid_varetrans'
  from public.raa_filer r
 where r.id = j.raa_fil_id
   and j.rapporttype = 'ukjent'
   and j.status = 'parset'
   and (r.filnavn ilike '%varetrans%' or r.filnavn ilike '%breakage%');
