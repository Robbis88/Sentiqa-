-- =====================================================================
-- 0140 - syvende og aattende forekomst av samme feil
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  0139
--   opplaering_periode, tilbakemelding her
--
-- DETEKTOREN PEKTE, MATRISEN BEKREFTET. De to sto i utskriften fra
-- supabase/tests/kandidater_with_check.sql 2026-08-26 som KANDIDAT, og
-- ble ikke roert da - de var ikke bekreftet. Klassifiseringen i pulje 5
-- ga atferdsmatrisen dem, og den svarte med ti FEIL-rader:
--
--   FEIL | opplaering_periode owner_A FLYTTER egen rad -> kjede B  | gikk gjennom
--   FEIL | tilbakemelding manager_A1 FLYTTER egen rad -> kjede B   | gikk gjennom
--
-- Fem identiteter hver, og begge veier mellom kjedene. `using` gjor
-- jobben sin; feilen ligger kun i `with check`, som ser stasjonen men
-- ikke kjeden. Endres bare retailer_id, staar stasjon_id uroert og
-- innenfor mine_stasjoner() - og raden flyttes til en annen kjede.
--
-- ---------------------------------------------------------------------
-- HVA SOM STOD PAA SPILL
--
-- opplaering_periode er roten i opplaeringstreet: bade opplaering_skift
-- og opplaering_utfort henter tenantnokkelen sin gjennom periode_id. En
-- periode som flyttes tar skiftene og hakene med seg - de har ingen egen
-- retailer_id aa motsi den med.
--
-- tilbakemelding er meldinger om uhell, nestenuhell og krenkelse. De er
-- persondata i praksis, og de skal aldri kunne havne i en annen kjede.
--
-- ---------------------------------------------------------------------
-- BEVISKRAVET, samme kontrakt som 0135, 0138 og 0139:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   owner/manager UPDATE egen stasjon  1 rad          ->  1 rad
--
-- Ingenting annet endres: samme rolle, samme stasjonsledd, samme
-- lesetilgang. Kun tenant-bindingen paa den nye radtilstanden kommer til.
-- =====================================================================


drop policy if exists opp2_periode_upd on public.opplaering_periode;
create policy opp2_periode_upd on public.opplaering_periode for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy opp2_periode_upd on public.opplaering_periode is
  'with check ser BEGGE tenantkolonnene. Se 0140 - syvende forekomst av 0135-formen.';


drop policy if exists tilbakemelding_update on public.tilbakemelding;
create policy tilbakemelding_update on public.tilbakemelding for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy tilbakemelding_update on public.tilbakemelding is
  'with check ser BEGGE tenantkolonnene. Se 0140 - aattende forekomst.';
