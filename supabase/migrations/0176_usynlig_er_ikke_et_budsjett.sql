-- =====================================================================
-- `usynlig_budsjett_kr` ER IKKE ET BUDSJETT
--
-- `0172` opprettet kolonnen med denne kommentaren:
--
--     «USYNLIG SVINN har sitt EGET budsjett, og bare den nyeste
--      filvarianten oppgir det.»
--
-- Det er feil. Robert bekreftet 2026-09-06:
--
--     «det er det historiske usynlige svinnet som er i
--      regnskapsrapporten fra i fjor, du faar bare vite hvor mye du maa
--      forbedre deg paa for aa treffe brutto de setter i BP»
--
-- Tallet i delingsfilas «Usynlig svinn»-kolonne er altsaa FJORAARETS
-- faktiske usynlige svinn, hentet fra regnskapsrapporten. **St1 setter
-- ingen grense for usynlig svinn i det hele tatt.**
--
-- ---------------------------------------------------------------------
-- GRENSEN FINNES, MEN DEN STAAR I BP-EN
--
-- Det St1 setter er en BRUTTOFORTJENESTE. Da foelger svinnbudsjettet av
-- identiteten, og trenger ikke sin egen kolonne:
--
--     teoretisk brutto - faktisk brutto = synlig + usynlig svinn
--     TILLATT SVINN    = teoretisk brutto - brutto budsjettert i BP
--
-- Begge tallene ligger alt i `v_bp_status_avdeling` (`0116`), og
-- `/svinn` leser dem derfra. Kast og usynlig deler grensen: de spiser av
-- samme brutto, og en krone tapt i manko koster like mye som en krone
-- kastet.
--
-- ---------------------------------------------------------------------
-- HVORFOR KOLONNEN BLIR STAAENDE
--
-- Dataene er ekte og verdt aa ha - fjoraarets usynlige svinn per stasjon
-- er et sammenligningsgrunnlag. Det er NAVNET som lyver, og navnet er
-- det eneste noen leser naar de skal avgjoere hva tallet betyr.
--
-- Aa doepe om kolonnen ville roert importen i samme slengen. Kommentaren
-- retter det som faktisk kan misforstaas, og ingen kodevei leser
-- kolonnen lenger.
--
-- **En antakelse skrevet ned i en kolonnekommentar er ikke mindre farlig
-- enn en i koden - den er farligere, fordi den ser ut som dokumentasjon.**
-- Det samme skjedde i `0174`: «importen skriver som service_role» sto i
-- to filer og var sant i ingen.
--
-- Idempotent: `comment on` er alltid en erstatning.
-- =====================================================================

comment on column public.kastbudsjett.usynlig_budsjett_kr is
  'FEIL NAVN, RIKTIG TALL. Dette er FJORAARETS faktiske usynlige svinn, '
  'slik det staar i regnskapsrapporten - IKKE et budsjett eller et krav. '
  'St1 setter ingen grense for usynlig svinn; de setter en brutto i BP-en, '
  'og tillatt svinn er teoretisk brutto minus den (se v_bp_status_avdeling). '
  'Ingen kodevei leser kolonnen. Bekreftet av Robert 2026-09-06.';

comment on table public.kastbudsjett is
  'St1s kastbudsjett per stasjon, aar og vareomraade, fra delingsfila. '
  'kast_pst_av_salg er KOST DELT PAA OMSETNING - en annen broek enn '
  'svinnprosenten paa /svinn, som er kost mot kost. De skal ikke '
  'sammenlignes. MERK at usynlig_budsjett_kr tross navnet ikke er et '
  'budsjett - se kolonnekommentaren.';

-- Kvittering: kommentaren skal vaere byttet.
select left(col_description(
         'public.kastbudsjett'::regclass,
         (select attnum from pg_attribute
           where attrelid = 'public.kastbudsjett'::regclass
             and attname = 'usynlig_budsjett_kr')), 40) as ny_kommentar;
