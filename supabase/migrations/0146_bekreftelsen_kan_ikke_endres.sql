-- =====================================================================
-- 0146 - et grant uten policy er en doer som venter
--
-- 0103 skrev `grant select, insert on kontrolltiltak_bekreftelse to
-- authenticated` og mente det som en BEGRENSNING. Det er det ikke.
-- Grants er additive, og Supabase' default privileges hadde allerede
-- gitt `all` paa tabellen da den ble opprettet:
--
--   alter default privileges in schema public
--     grant all on tables to anon, authenticated, service_role
--
-- 0134 tok dem fra `anon`. Ikke fra `authenticated`.
--
-- MATRISEN MOT PRODUKSJON VISTE DET, 2026-08-27:
--
--   kontrolltiltak_bekreftelse owner_A UPDATE A1 | 0 rader, maalrad bekreftet
--
-- "0 rader" betyr at setningen KJOERTE og ble stoppet av RLS. Manglet
-- rettigheten, ville den sagt `avvist med 42501` - slik profiler og
-- pin_forsok gjor, der rettigheten faktisk er tatt bort.
--
-- Jeg skrev i 0145 at radflyttingen er avvist "to ganger over - av
-- manglende policy og av manglende rettighet". Det var feil. Det er ett
-- lag, ikke to.
--
-- ---------------------------------------------------------------------
-- SAMME LAERDOM SOM I GAAR, SPEILVENDT
--
-- 0078: en POLICY UTEN GRANT er virkningsloes - `profiler_admin_alt`
-- staar i basen og ser ut som om eieren kan skrive, men grantet er
-- borte.
--
-- Her: et GRANT UTEN POLICY er en aapen doer som venter paa at noen
-- lager en. Beskyttelsen holder saa lenge det ikke finnes en
-- update-policy - og den dagen noen legger til en for et helt annet
-- formaal, ligger rettigheten der allerede.
--
-- ---------------------------------------------------------------------
-- HVORFOR DET ER TRYGT
--
-- En bekreftelse skal staa. Det er hele poenget med tabellen: den
-- dokumenterer at informasjonsplikten etter aml. par. 9-2 ER oppfylt,
-- og en dokumentasjon som lar seg redigere dokumenterer ingenting -
-- samme grunn som persondata_logg fikk i 0103.
--
-- Ingen flate skriver annet enn insert. `bekreftLest`
-- (mine-opplysninger/handlinger.ts:40) er den eneste, og den setter
-- inn. Ingen update, ingen delete, noe sted i src/.
--
-- Etter denne sier matrisen `avvist med 42501` i stedet for `0 rader`,
-- og rettighetsvakten i kontrakt.test.ts holder den lukket: klassifiserer
-- noen update eller delete for en rolle her, feiler CI paa millisekunder.
-- =====================================================================

revoke update, delete on public.kontrolltiltak_bekreftelse from authenticated;

comment on table public.kontrolltiltak_bekreftelse is
  'Dokumentasjon paa at informasjonsplikten etter aml. par. 9-2 er oppfylt. '
  'IKKE et samtykke - samtykke er sjelden gyldig i arbeidsforhold. '
  'authenticated har bevisst ikke update/delete - se 0146.';
