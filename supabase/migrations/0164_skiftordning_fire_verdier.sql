-- =====================================================================
-- Sentiqa 0164 - fire uketimetall, ikke to
--
-- ENERGISTASJONSOVERENSKOMSTEN § 2.7.1.1
--
--   37,5   ordinaer
--   36,5   2-dagskift som verken gaar loerdag aften eller i
--          helligdagsdoegnet
--   35,5   der loven har 38 t/uke
--   33,5   der loven har 36 t/uke
--
-- `0096` kjente bare 37,5 og 35,5. En ansatt paa en av de to andre
-- ordningene kunne derfor ikke registreres i det hele tatt - og hadde
-- skranken sluppet verdien gjennom, ville vedkommende faatt BAADE feil
-- sammenligningssats i tariffkontrollen OG feil ukegrense for overtid.
-- Omregningen er `grunnloenn x 37,5 / uketimetall`, saa forskjellen mellom
-- 35,5 og 33,5 er over ti kroner timen paa laveste trinn.
--
-- DET GAMLE NAVNET BLIR STAAENDE. `to_skift` er 35,5-ordningen. Aa doepe
-- den om til `skift_35_5` ville betydd aa skrive om eksisterende rader for
-- aa vinne et penere navn, og en datamigrering som ikke retter noe er en
-- risiko uten gevinst.
--
-- Skranken maa DROPPES foer den legges til paa nytt - `add constraint`
-- er ikke `or replace`, og `0096` legger den bare til hvis den mangler.
-- Begge setningene taaler aa kjoeres om igjen.
-- =====================================================================

alter table public.ansatt_avtale
  drop constraint if exists ansatt_avtale_skift_sjekk;

alter table public.ansatt_avtale
  add constraint ansatt_avtale_skift_sjekk
  check (skiftordning is null or skiftordning in (
    'ordinaer', 'skift_36_5', 'to_skift', 'skift_33_5'));

comment on column public.ansatt_avtale.skiftordning is
  'Uketimetall etter Energistasjonsoverenskomsten 2.7.1.1: ordinaer = '
  '37,5, skift_36_5 = 36,5, to_skift = 35,5, skift_33_5 = 33,5. '
  '`to_skift` er det gamle navnet paa 35,5-ordningen - se migrasjon 0164.';
