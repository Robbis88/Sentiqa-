-- =====================================================================
-- 0195 - STENGER DEN GAMLE NAVNEFUNKSJONEN
--
-- **KJOER DENNE ETTER AT KODEN ER UTE. Ikke foer.**
--
-- Det er motsatt av husregelen (migrasjon foerst, saa kode), og det er
-- med vilje: denne FJERNER noe den gamle koden bruker. Kjores den foer
-- deployen, mister /maaling og /vaar-stasjon stasjonslista si, og
-- maalekortene staar tomme - akkurat den tilstanden `0075` ga i
-- maanedsvis fordi ingen sa fra.
--
-- Rekkefoelgen er altsaa:
--
--   1. `0194`  legg til `malekort_navn()`           (trygt naar som helst)
--   2. merge   koden bytter til den nye funksjonen
--   3. `0195`  ta granten paa den gamle             (denne fila)
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE BARE DROPPE FUNKSJONEN
--
-- Fordi `funksjoner_finnes.sql` sjekker at alt migrasjonene LOVER
-- faktisk finnes, og fordi et `drop` ikke kan angres like enkelt som en
-- grant. Funksjonen blir staaende; det er tilgangen som fjernes.
--
-- Idempotent: `revoke` paa noe som alt er fjernet er en no-op.
-- =====================================================================

revoke execute on function public.malekort_stasjoner() from authenticated;

comment on function public.malekort_stasjoner() is
  'UTE AV BRUK fra 0195. Ga navnet paa hver stasjon i kjeden til enhver '
  'authenticated, og kunne joines med beregn_malekort_salg for aa omgaa '
  'malekort.anonymiser. Erstattet av malekort_navn(p_malekort), som '
  'anonymiserer per kort. Funksjonen staar igjen uten grant.';

-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- `gammel_grant` skal vaere 0 og `ny_grant` skal vaere 1.
select
  'kvittering' as hva,
  (select count(*) from information_schema.role_routine_grants
    where routine_schema = 'public' and routine_name = 'malekort_stasjoner'
      and grantee = 'authenticated')                                  as gammel_grant,
  (select count(*) from information_schema.role_routine_grants
    where routine_schema = 'public' and routine_name = 'malekort_navn'
      and grantee = 'authenticated')                                  as ny_grant;
