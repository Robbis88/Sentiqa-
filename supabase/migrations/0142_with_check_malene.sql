-- =====================================================================
-- 0142 - tiende, ellevte og tolvte forekomst av 0135-formen
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  0139
--   opplaering_periode, tilbakemelding 0140
--   uke_rapport (ny form: fri arm)     0141
--   rutineskjemaer, sjekkpunkter,
--   ik_kontrollpunkter                 her
--
-- Alle tre er MALENE bak utforelser som alt var bevist:
--
--   sjekkpunkter        -> sjekkpunkt_svar     (bevist i pulje 5)
--   ik_kontrollpunkter  -> ik_avlesninger      (bevist i pulje 5)
--   rutineskjemaer      -> rutiner             (bevist i pulje 6)
--
-- SVARET VAR BEVIST OG MALEN VAR IKKE. Det er noyaktig den halvparten
-- som ser tryggest ut: barnetabellen vokser med drift, staar i `varme`,
-- og fikk oppmerksomhet i 0077/0078. Malen har faa rader, staar i
-- `kalde`, og har hatt samme for all-policy siden 0014/0023/0032.
--
-- Matrisen ga 15 FEIL i den kjoringen som klassifiserte dem - tre
-- tabeller ganger fem identiteter, begge veier mellom kjedene:
--
--   FEIL | sjekkpunkter manager_A1 FLYTTER egen rad -> kjede B | gikk gjennom
--
-- `using` gjor jobben sin. Feilen ligger kun i `with check`, som ser
-- stasjonen og ikke kjeden: endres bare retailer_id, staar stasjon_id
-- uroert og innenfor har_stasjonstilgang().
--
-- ---------------------------------------------------------------------
-- HVA SOM STOD PAA SPILL
--
-- ik_kontrollpunkter er temperaturkravene i IK-mat-dokumentasjonen -
-- hvilken kjoel som skal ligge under hvor mange grader. Flyttes et
-- kontrollpunkt ut av kjeden, tar det avlesningene med seg: de har
-- ingen egen retailer_id aa motsi den med, bare kontrollpunkt_id.
-- Samme form paa sjekkpunkt_svar og paa rutinene under et skjema.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- Policyene forblir `for all` med upakkede kall, slik de har vaert
-- siden 0014/0023/0032. Reglene om splitting og (select ...) gjelder
-- tabeller som VOKSER med drift; disse tre er oppsett med faa rader og
-- staar med vilje i `kalde` i rls_vakthund.sql. Denne migrasjonen har
-- ett aerend, og skal kunne leses som ett aerend.
--
-- BEVISKRAVET, samme kontrakt som 0135 til 0141:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   leder UPDATE paa egen stasjon      1 rad          ->  1 rad
-- =====================================================================


drop policy if exists rutineskjemaer_skriv on public.rutineskjemaer;
create policy rutineskjemaer_skriv on public.rutineskjemaer for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and retailer_id = (select public.gjeldende_retailer_id())
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

comment on policy rutineskjemaer_skriv on public.rutineskjemaer is
  'with check ser BEGGE tenantkolonnene. Se 0142 - tiende forekomst av 0135-formen.';


drop policy if exists sjekkpunkter_skriv on public.sjekkpunkter;
create policy sjekkpunkter_skriv on public.sjekkpunkter for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and retailer_id = (select public.gjeldende_retailer_id())
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

comment on policy sjekkpunkter_skriv on public.sjekkpunkter is
  'with check ser BEGGE tenantkolonnene. Se 0142 - ellevte forekomst.';


drop policy if exists ik_punkter_skriv on public.ik_kontrollpunkter;
create policy ik_punkter_skriv on public.ik_kontrollpunkter for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and retailer_id = (select public.gjeldende_retailer_id())
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

comment on policy ik_punkter_skriv on public.ik_kontrollpunkter is
  'with check ser BEGGE tenantkolonnene. Se 0142 - tolvte forekomst.';


-- ---------------------------------------------------------------------
-- OG RYDD ETTER EN FLYTTING SOM EVENTUELT ALT HAR SKJEDD.
--
-- Samme form som 0141: stasjonen er fasiten, siden stasjoner.retailer_id
-- er den eneste kilden hullet ikke kunne skrive til. Vaktet av seg selv
-- - andre gang finnes ingen rader der de to er ulike.
-- ---------------------------------------------------------------------
update public.rutineskjemaer u set retailer_id = s.retailer_id
  from public.stasjoner s where s.id = u.stasjon_id and u.retailer_id <> s.retailer_id;

update public.sjekkpunkter u set retailer_id = s.retailer_id
  from public.stasjoner s where s.id = u.stasjon_id and u.retailer_id <> s.retailer_id;

update public.ik_kontrollpunkter u set retailer_id = s.retailer_id
  from public.stasjoner s where s.id = u.stasjon_id and u.retailer_id <> s.retailer_id;
