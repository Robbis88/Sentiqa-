-- =====================================================================
-- 0145 - en bekreftelse tilhoerer den som bekreftet
--
-- `kontrolltiltak_ins` fra 0103 sjekket BARE retailer_id:
--
--   with check (retailer_id = (select gjeldende_retailer_id()))
--
-- Ingen stasjon, ingen rolle, ingen binding til den innloggede. Enhver
-- i kjeden kunne skrive en aml. par. 9-2-bekreftelse for en hvilken som
-- helst stasjon, med en hvilken som helst bruker_id eller ansatt_id.
--
-- FOR ET DOKUMENT SOM SKAL BEVISE AT INFORMASJONSPLIKTEN ER OPPFYLT ER
-- DET FOR LITE. Raden sa at NOEN bekreftet - ikke at den som bekreftet
-- var den det gjaldt. En bekreftelse ingen kan etterproeve hvem som ga,
-- dokumenterer ikke plikten; den ser bare ut som om den gjor det.
--
-- Matrisen viste det som `manager_A1 INSERT A2 | 1 rad`: en butikksjef
-- med bare A1 skrev en bekreftelse for A2 og A3.
--
-- ---------------------------------------------------------------------
-- HVA POLICYEN KREVER NAA
--
--   retailer_id   egen kjede                        (som foer)
--   bruker_id     NULL eller den innloggede         (nytt)
--   stasjon_id    NULL eller en stasjon jeg naar    (nytt)
--   ansatt_id     NULL eller en ansatt paa en slik  (nytt)
--
-- MOENSTERET FINNES ALLEREDE I SAMME FIL: `persondata_logg_ins` skrev
-- `bruker_id = (select auth.uid())` fra dag en. De to tabellene ble
-- laget i samme migrasjon, og bare den ene fikk bindingen.
--
-- ---------------------------------------------------------------------
-- HVORFOR bruker_id FAAR VAERE NULL
--
-- Tabellen har TO identiteter, og det er med vilje (0103):
--
--   bruker_id   den innloggede - butikksjefen bekrefter som seg selv
--   ansatt_id   den paa vakt - nettbrettet bekrefter som PERSONEN,
--               ikke som enheten
--
-- Den delte tablet-kontoen bekrefter paa vegne av hver enkelt ansatt,
-- og skriver derfor `bruker_id = null`. Krevde policyen
-- `bruker_id = auth.uid()` ubetinget, ville den unike indeksen
-- `(bruker_id, versjon)` gjort at BARE DEN FOERSTE ansatte paa et
-- nettbrett fikk bekrefte - resten hadde kollidert med 23505.
--
-- `null or = auth.uid()` er derfor det som faktisk stenger hullet:
-- du kan la den staa tom, men du kan ikke sette en annens.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- LESINGEN ER UROERT. Revisjonsinnsynet er som foer: din egen rad, og
-- ledere paa sine stasjoner. To ting foelger av det, og begge er
-- rapportert som egne funn - ikke rettet her:
--
--   * En leders EGEN bekreftelse faar `stasjon_id = null` fra
--     serverhandlingen, og er dermed usynlig for alle andre enn henne
--     selv. Arbeidsgiver kan ikke dokumentere at LEDERNE er informert.
--   * Nettbrettet kan ikke lese sin egen bekreftelse: den delte kontoen
--     bekrefter som ansatt_id, mens egen-grenen matcher paa bruker_id.
--
-- INGEN UPDATE- ELLER DELETE-POLICY, og `grant select, insert` alene.
-- En bekreftelse skal staa. Radflytting til en annen bruker er dermed
-- avvist to ganger over - av manglende policy og av manglende rettighet
-- - og matrisen paastaar det naa eksplisitt i stedet for aa anta det.
--
-- ---------------------------------------------------------------------
-- BEVISKRAVET
--
--   INSERT som seg selv, egen stasjon    1 rad
--   INSERT med en annens bruker_id       avvist med 42501
--   INSERT paa en stasjon jeg ikke naar  avvist med 42501
--   INSERT i en annen kjede              avvist med 42501
--   FLYTTER raden til en annen bruker    avvist med 42501
--
-- Serverhandlingen `bekreftLest` er uroert og fortsetter aa virke:
-- lederen skriver (bruker_id = auth.uid(), stasjon_id null), og
-- nettbrettet skriver (bruker_id null, ansatt_id = den paa vakt,
-- stasjon_id = ansattens stasjon).
-- =====================================================================


drop policy if exists kontrolltiltak_ins on public.kontrolltiltak_bekreftelse;
create policy kontrolltiltak_ins on public.kontrolltiltak_bekreftelse
  for insert to authenticated
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    -- Du kan la den staa tom, men ikke sette en annens.
    and (bruker_id is null or bruker_id = (select auth.uid()))
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
    and (
      ansatt_id is null
      or ansatt_id in (
        select a.id from public.ansatte a
        where a.stasjon_id in (select public.mine_stasjoner())
      )
    )
  );

comment on policy kontrolltiltak_ins on public.kontrolltiltak_bekreftelse is
  'Raden tilhoerer den som bekreftet. Se 0145 - bindingen sto i '
  'persondata_logg fra 0103, men ikke her.';


-- ---------------------------------------------------------------------
-- RYDD ETTER EN BEKREFTELSE SOM ALT ER SKREVET FEIL STED.
--
-- Ikke en flytting som i 0141: her finnes det ingen fasit aa rette
-- MOT - en bekreftelse skrevet av feil person kan ikke gjoeres om til
-- riktig person. Derfor bare et varsel med tallet, saa det staar i
-- kjoereloggen om det noen gang var mer enn null.
--
-- Kriteriet er stasjonen: en rad hvis stasjon hoerer til en annen kjede
-- enn radens egen retailer_id kan ingen ha skrevet i god tro.
-- ---------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
  from public.kontrolltiltak_bekreftelse k
  join public.stasjoner s on s.id = k.stasjon_id
  where s.retailer_id <> k.retailer_id;

  if n > 0 then
    raise warning '0145: % bekreftelse(r) har stasjon i en annen kjede enn retailer_id. Se paa dem for haand.', n;
  else
    raise notice '0145: ingen bekreftelser med stasjon i feil kjede.';
  end if;
end $$;
