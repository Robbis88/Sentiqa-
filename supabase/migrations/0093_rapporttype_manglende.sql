-- ---------------------------------------------------------------------
-- 0093: rapporttyper som koden bruker, men enum-en ikke har
-- ---------------------------------------------------------------------
-- Opplasting av timesalg feilet med
--   invalid input value for enum rapporttype: "st1_salesperhour_inneute"
--
-- To verdier koden har brukt lenge finnes ikke i typen:
--
--   st1_salesperhour_inneute  0603-rapporten med inne-/utekunder. Enum-en
--                             har bare 'st1_salesperhour' (den gamle 0758).
--   salgsgrid_varetrans       synlig svinn. Enum-en har 'salesgrid_varetrans'
--                             - engelsk stavemaate, aldri brukt av koden.
--
-- Hvorfor det ikke ble oppdaget: koeveien (Storage + nattjobb) setter
-- rapporttype med en UPDATE hvis feil aldri sjekkes, saa jobben gikk
-- videre og dataene landet - med rapporttype 'ukjent' i basen.
-- Nettleserveien setter den i INSERT, og der kastet det. Samme fil, to
-- veier, ett virket.
--
-- De gamle verdiene beholdes. Eksisterende rader kan referere dem, og en
-- enum-verdi kan ikke fjernes uten aa skrive om typen.
alter type public.rapporttype add value if not exists 'st1_salesperhour_inneute';
alter type public.rapporttype add value if not exists 'salgsgrid_varetrans';

-- Rydd opp i jobber som fikk 'ukjent' fordi UPDATE-en feilet i stillhet.
-- Vaktet: bare rader som faktisk er parset og har en fil som ser ut som
-- en 0603-rapport. Kjores dette om igjen, treffer where-en ingenting.
update public.import_jobber j
   set rapporttype = 'st1_salesperhour_inneute'
  from public.raa_filer r
 where r.id = j.raa_fil_id
   and j.rapporttype = 'ukjent'
   and j.status = 'parset'
   and r.filnavn ilike '%timesalgsrapport%';
