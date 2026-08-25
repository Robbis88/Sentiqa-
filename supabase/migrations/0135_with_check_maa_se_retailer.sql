-- =====================================================================
-- 0135 - `with check` maa se retailer_id, ikke bare stasjon_id
--
-- FUNNET AV DEN GENERERTE ATFERDSMATRISEN, 2026-08-25, kjoring
-- 32872102217. Ti FEIL-rader paa to tabeller:
--
--   FEIL | avvik owner_A      FLYTTER egen rad -> kjede B | gikk gjennom
--   FEIL | avvik manager_A1   FLYTTER egen rad -> kjede B | gikk gjennom
--   FEIL | avvik manager_A12  FLYTTER egen rad -> kjede B | gikk gjennom
--   FEIL | avvik manager_B1   FLYTTER egen rad -> kjede A | gikk gjennom
--   FEIL | avvik owner_B      FLYTTER egen rad -> kjede A | avvist av FEIL grunn: 23505
--   FEIL | stempling_hendelse ... samme, fem identiteter
--
-- AARSAKEN. Begge policyene har en `with check` som validerer at
-- stasjon_id er en stasjon brukeren har tilgang til - men ikke at
-- retailer_id fortsatt er brukerens egen:
--
--   with check (stasjon_id in (select public.mine_stasjoner())
--               and (select public.gjeldende_rolle()) in (...))
--
-- `using` slipper raden inn fordi den ER brukerens. `with check` ser
-- paa den nye raden, men bare paa stasjonen. Endres KUN retailer_id,
-- staar stasjon_id uroert og fortsatt innenfor mine_stasjoner() - og
-- begge klausulene er fornoeyd.
--
-- Foelgen: en autorisert rad kan flyttes til en annen retailer saa
-- lenge stasjon_id fortsatt er en stasjon brukeren har tilgang til.
-- Det er en ekte cross-retailer write-lekkasje.
--
-- MALEKORT HADDE DET IKKE. `malekort_upd` navngir retailer_id i sin
-- `with check`, og den var groenn i samme kjoring. Kontrasten er
-- beviset paa at diagnosen stemmer.
--
-- DEN HAANDSKREVNE KANARIFUGLEN FANGET DET IKKE. Den testet aa flytte
-- stasjon_id, ikke retailer_id. Generatoren gjor begge fordi
-- kontrakten sier at tabellene er `retailer_and_station` - og en
-- ressurs med to tenantkolonner maa proeves paa begge.
--
-- MINSTE MULIGE ENDRING, med vilje: ett predikat lagt til i `with
-- check` paa to policyer. `using` er uroert - den slapp aldri inn en
-- fremmed rad. Ingen andre tabeller er rort foer disse to er groenne.
--
-- Funksjonskallet er pakket i `(select ...)` saa det blir initplan.
-- Begge tabellene er VARME.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) avvik
-- ---------------------------------------------------------------------
drop policy if exists avvik_upd on public.avvik;
create policy avvik_upd on public.avvik for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy avvik_upd on public.avvik is
  'with check ser BEGGE tenantkolonnene. Uten retailer_id-predikatet kunne '
  'en rad flyttes til en annen kjede mens stasjon_id sto uroert - se 0135.';


-- ---------------------------------------------------------------------
-- 2) stempling_hendelse
-- ---------------------------------------------------------------------
drop policy if exists stempling_hendelse_upd on public.stempling_hendelse;
create policy stempling_hendelse_upd on public.stempling_hendelse
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy stempling_hendelse_upd on public.stempling_hendelse is
  'with check ser BEGGE tenantkolonnene. Se 0135.';


-- ---------------------------------------------------------------------
-- ETTER DENNE:
--
--   1. supabase/tests/rls_vakthund.sql          - policyene er endret
--   2. supabase/tests/rls_kanarifugl_generert.sql - FLYTTER-testene skal
--      gaa fra FEIL til ok, og de positive egen-stasjons-oppdateringene
--      skal fortsatt vaere ok
--
-- Punkt 2 er det som skiller en retting fra en innstramming som ogsaa
-- tok noe den ikke skulle.
--
-- IKKE GENERALISERT. De andre tabellene med samme moenster staar
-- uroert til disse to er groenne. Naar de er det, er neste steg aa
-- klassifisere resten - og da finner matrisen dem selv.
-- ---------------------------------------------------------------------
