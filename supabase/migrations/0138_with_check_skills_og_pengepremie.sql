-- =====================================================================
-- 0138 - samme feil som 0135, paa to tabeller til
--
-- FUNNET AV ATFERDSMATRISEN i det oeyeblikket tabellene ble
-- klassifisert. Ti FEIL-rader, alle av samme form:
--
--   FEIL | skills_score owner_A FLYTTER egen rad -> kjede B     | skrivingen gikk gjennom, 1 rad(er)
--   FEIL | pengepremie_bruk manager_A1 FLYTTER egen rad -> kjede B | samme
--
--   skills_score      5 identiteter
--   pengepremie_bruk  5 identiteter
--
-- REN 0135-FORM, tegn for tegn. `using` gjor jobben sin - den slipper
-- bare inn rader paa egne stasjoner, og bare for ledere. Ingen av de ti
-- handler om at feil rad ble naadd; alle er FLYTTER EGEN RAD.
--
-- Feilen ligger kun i `with check`, som mangler tenant-bindingen paa
-- den NYE radtilstanden. Endres bare retailer_id, staar stasjon_id
-- uroert og fortsatt innenfor mine_stasjoner() - og begge klausulene er
-- fornoeyd mens raden flyttes til den andre kjeden.
--
-- ---------------------------------------------------------------------
-- ANSATTE HADDE SAMME POLICYTEKST OG FEILET LIKEVEL IKKE.
--
-- Den ga `avvist med 42501`, men ikke paa grunn av policyen. `0112`
-- skrev, for aa lukke pin_hash:
--
--   revoke update on public.ansatte from authenticated;
--   grant  update (navn, stasjon_id, ansatt_nr, aktiv, slettet_tid)
--          on public.ansatte to authenticated;
--
-- `retailer_id` staar ikke paa lista. Kolonnegjerdet lukket
-- kryss-retailer-flyttingen som en bivirkning, fra en helt annen
-- migrasjon skrevet av en helt annen grunn.
--
-- LAERDOMMEN, og den er stoerre enn denne migrasjonen:
--
--   Tenant-sikkerhet er den effektive summen av RLS + grants +
--   RPC/view-grenser. Policytekst alene beskriver ikke den faktiske
--   capabilityen.
--
-- To tabeller med IDENTISK RLS kan ha ulik angrepsflate. Det er derfor
-- atferdsmatrisen er verdt mer enn en ren policy-gjennomlesing - og
-- derfor `ansatte` ikke roeres her.
--
-- ---------------------------------------------------------------------
-- SAA SMALT SOM MULIG: ett predikat, to policyer, kun `with check`.
-- `using` er uroert. SELECT, INSERT og DELETE er uroert. Nettbrettets
-- kolonnetilgang er et eget capability-spoersmaal og hoerer ikke hjemme
-- i en lekkasjeretting.
-- =====================================================================


drop policy if exists skills_upd on public.skills_score;
create policy skills_upd on public.skills_score for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy skills_upd on public.skills_score is
  'with check ser BEGGE tenantkolonnene. Se 0138, som er 0135 paa to tabeller til.';


drop policy if exists pengepremie_bruk_upd on public.pengepremie_bruk;
create policy pengepremie_bruk_upd on public.pengepremie_bruk for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy pengepremie_bruk_upd on public.pengepremie_bruk is
  'with check ser BEGGE tenantkolonnene. Se 0138.';


-- ---------------------------------------------------------------------
-- BEVISKRAVET, samme kontrakt som 0135:
--
--   FLYTTER egen rad -> annen kjede    1 rad skrevet  ->  avvist med 42501
--   owner/manager UPDATE egen stasjon  1 rad          ->  1 rad
--
-- Begge maa holde. Den foerste alene beviser at lekkasjen er lukket;
-- den andre at legitim drift ikke ble oedelagt.
-- ---------------------------------------------------------------------
