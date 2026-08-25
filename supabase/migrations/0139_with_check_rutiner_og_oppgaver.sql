-- =====================================================================
-- 0139 - femte og sjette forekomst av samme feil
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  her
--
-- Bekreftet av atferdsmatrisen 2026-08-26, ti FEIL-rader:
--
--   FEIL | rutiner owner_A FLYTTER egen rad -> kjede B  | skrivingen gikk gjennom
--   FEIL | oppgaver manager_A1 FLYTTER egen rad -> kjede B | samme
--
-- Fem identiteter hver. `using` gjor jobben sin; feilen ligger kun i
-- `with check`, som mangler tenant-bindingen paa den nye radtilstanden.
--
-- ---------------------------------------------------------------------
-- SEKS FOREKOMSTER ER NOK TIL AA SOEKE MEKANISK.
--
-- `supabase/tests/kandidater_with_check.sql` finner naa formen i
-- katalogen. Foerste kjoering ga seks policyer:
--
--   KANDIDAT          oppgaver, rutiner, opplaering_periode, tilbakemelding
--   TRYGG VIA GRANT   ansatte, puls_svar
--
-- De to siste har samme policytekst, men `authenticated` kan ikke skrive
-- `retailer_id` paa dem - kolonnegjerdet stopper flyttingen. `ansatte`
-- var ikke et saertilfelle; `puls_svar` har det samme.
--
-- DETEKTOREN ER EN TIDLIG ALARM, IKKE EN FASIT. Den sier hvor
-- atferdsmatrisen boer se. De to nye kandidatene - opplaering_periode og
-- tilbakemelding - er IKKE roert her, fordi de ikke er bekreftet ennaa.
--
-- ---------------------------------------------------------------------
-- BEVISKRAVET, samme kontrakt som 0135 og 0138:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   owner/manager UPDATE egen stasjon  1 rad          ->  1 rad
-- =====================================================================


drop policy if exists rutiner_upd on public.rutiner;
create policy rutiner_upd on public.rutiner for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy rutiner_upd on public.rutiner is
  'with check ser BEGGE tenantkolonnene. Se 0139 - femte forekomst av 0135-formen.';


drop policy if exists oppgaver_upd on public.oppgaver;
create policy oppgaver_upd on public.oppgaver for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy oppgaver_upd on public.oppgaver is
  'with check ser BEGGE tenantkolonnene. Se 0139 - sjette forekomst.';
