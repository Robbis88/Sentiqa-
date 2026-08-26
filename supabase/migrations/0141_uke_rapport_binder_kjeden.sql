-- =====================================================================
-- 0141 - niende forekomst, men en NY FORM av den
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  0139
--   opplaering_periode, tilbakemelding 0140
--   uke_rapport                        her
--
-- DE AATTE FOERSTE MANGLET `retailer_id` I `with check`. Denne NEVNER
-- den - og lekker likevel. Bindingen staar i feil arm av et `or`:
--
--   with check (
--     ((select gjeldende_rolle()) = 'retailer_admin'
--      and retailer_id = (select gjeldende_retailer_id()))   <- bundet
--     or stasjon_id in (select mine_stasjoner())             <- fri
--   )
--
-- Den andre armen alene godtar hva som helst i retailer_id, saa lenge
-- stasjonen er min. AA NEVNE KOLONNEN ER IKKE AA BINDE DEN. Derfor sto
-- uke_rapport ikke i kandidater_with_check.sql: detektoren leter etter
-- FRAVAER av retailer_id, og her er den til stede.
--
-- ---------------------------------------------------------------------
-- HVORDAN DEN BLE FUNNET, og hvorfor det tok til pulje 10
--
-- Atferdsmatrisen svarte med 14 FEIL - som alle er ETT funn som brer
-- seg. Foerst flyttingen:
--
--   FEIL | uke_rapport owner_A FLYTTER egen rad -> kjede B | gikk gjennom
--
-- Raden beholder stasjon A1 og bytter retailer_id til B. Da er den
-- plutselig kjede B sin i lesepolicyen - `retailer_admin` i B ser hele
-- sin egen kjede - og resten foelger av det:
--
--   FEIL | uke_rapport owner_B SELECT A1 -> ser ikke | (den saa den)
--   FEIL | uke_rapport owner_B DELETE A1            | gikk gjennom
--   FEIL | uke_rapport manager_B1 UPDATE A1         | maalraden finnes ikke
--
-- Den siste er ikke en egen feil; den er ekkoet av slettingen over.
--
-- ---------------------------------------------------------------------
-- HVA SOM STOD PAA SPILL
--
-- Ukerapporten er stasjonens tall: omsetning, brutto, avdelingsmiks og
-- et AI-sammendrag, mot samme uke i fjor. En rad som flyttes tar hele
-- uka med seg ut av kjeden - og den som mistet den ser bare at
-- dashbordet er tomt.
--
-- ---------------------------------------------------------------------
-- BEVISKRAVET, samme kontrakt som 0135 til 0140:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   owner/manager/tablet paa egen st.  1 rad          ->  1 rad
--
-- Ingenting annet endres. `using` roeres ikke: en rad hvis stasjon er
-- min, er per definisjon min kjedes - naar den ikke lenger kan flyttes.
-- =====================================================================


drop policy if exists uke_rapport_ins on public.uke_rapport;
create policy uke_rapport_ins on public.uke_rapport for insert to authenticated
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select public.mine_stasjoner())
    )
  );

comment on policy uke_rapport_ins on public.uke_rapport is
  'Kjeden bindes UTENFOR or-et. Se 0141 - nevnt er ikke bundet.';


drop policy if exists uke_rapport_upd on public.uke_rapport;
create policy uke_rapport_upd on public.uke_rapport for update to authenticated
  using (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  )
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select public.mine_stasjoner())
    )
  );

comment on policy uke_rapport_upd on public.uke_rapport is
  'Kjeden bindes UTENFOR or-et. Se 0141 - niende forekomst, ny form.';


-- ---------------------------------------------------------------------
-- OG RYDD ETTER EN EVENTUELL FLYTTING SOM ALT HAR SKJEDD.
--
-- Policyen stenger doeren; den setter ikke tilbake det som gikk ut.
-- Stasjonen er fasiten - `stasjoner.retailer_id` er den eneste kilden
-- som ikke kunne skrives gjennom hullet.
--
-- Vaktet av seg selv: andre gang er det ingen rader igjen der de to er
-- ulike, og setningen blir en no-op.
-- ---------------------------------------------------------------------
update public.uke_rapport u
   set retailer_id = s.retailer_id
  from public.stasjoner s
 where s.id = u.stasjon_id
   and u.retailer_id <> s.retailer_id;
