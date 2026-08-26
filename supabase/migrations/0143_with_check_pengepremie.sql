-- =====================================================================
-- 0143 - trettende forekomst av 0135-formen
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  0139
--   opplaering_periode, tilbakemelding 0140
--   uke_rapport (fri arm i et or)      0141
--   rutineskjemaer, sjekkpunkter,
--   ik_kontrollpunkter                 0142
--   pengepremie                        her
--
-- DENNE VAR VARSLET. Kontrakten sa det foer matrisen kjorte:
--
--   "FORVENTET FUNN: pengepremie_skriv er en for all-policy fra 0043
--    der with check ser stasjonen og ikke kjeden."
--
-- og matrisen svarte med fem FEIL - eier og butikksjef i begge kjeder:
--
--   FEIL | pengepremie manager_A1 FLYTTER egen rad -> kjede B | gikk gjennom
--
-- ---------------------------------------------------------------------
-- HVA SOM STOD PAA SPILL
--
-- pengepremie er kroner tildelt en ansatt, og pengepremie_bruk henger
-- under den. `0138` lukket barnetabellen - premien selv sto igjen.
-- Samme form som malene i 0142: barnet fikk oppmerksomhet, foreldren
-- ikke.
--
-- HVA SOM IKKE ENDRES: policyen forblir `for all` med upakkede kall, som
-- i 0043. Splitting og (select ...) gjelder tabeller som vokser med
-- drift; pengepremie staar med vilje i `kalde` i rls_vakthund.sql.
--
-- BEVISKRAVET, samme kontrakt som 0135 til 0142:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   leder UPDATE paa egen stasjon      1 rad          ->  1 rad
-- =====================================================================


drop policy if exists pengepremie_skriv on public.pengepremie;
create policy pengepremie_skriv on public.pengepremie for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and retailer_id = (select public.gjeldende_retailer_id())
              and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

comment on policy pengepremie_skriv on public.pengepremie is
  'with check ser BEGGE tenantkolonnene. Se 0143 - trettende forekomst av 0135-formen.';


-- Rydd etter en flytting som eventuelt alt har skjedd. Stasjonen er
-- fasiten; vaktet av seg selv - andre gang finnes ingen slike rader.
update public.pengepremie u set retailer_id = s.retailer_id
  from public.stasjoner s where s.id = u.stasjon_id and u.retailer_id <> s.retailer_id;
