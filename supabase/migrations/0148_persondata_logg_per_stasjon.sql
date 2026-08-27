-- =====================================================================
-- 0148 - butikksjefen ser sine stasjoners logg, ikke kjedens
--
-- PRODUKTBESLUTNING, tatt 2026-08-27:
--
--   tablet           ingen SELECT
--   butikksjef       bare stasjonene hun faktisk administrerer
--   retailer_admin   hele egen retailer
--   ingen            en annen retailer
--
-- `persondata_logg_les` fra 0103 hadde bare det ytterste leddet:
--
--   retailer_id = min kjede and rolle in ('retailer_admin','butikksjef')
--
-- En butikksjef med EN tildelt stasjon leste dermed hele kjedens
-- tilgangslogg: hvem som hadde sett loenn, foedselsdato og sykefravaer
-- paa stasjoner hun ikke har noe med.
--
-- LOGGEN ER SELV PERSONDATA. Den sier "denne lederen slo opp denne
-- navngitte ansatte, paa denne datoen". En tilgangslogg som er bredere
-- enn tilgangen den logger, lager et nytt innsyn i stedet for aa
-- dokumentere det som fantes.
--
-- ---------------------------------------------------------------------
-- SCOPET UTLEDES IKKE - DET STAAR I RADEN
--
-- persondata_logg har en `stasjon_id` fra 0103. Butikksjefens gren er
-- derfor et direkte oppslag, ikke en gjetning:
--
--   stasjon_id in (select public.mine_stasjoner())
--
-- Ingen kobling paa ansatt_nr, og ingen paa navn. Se
-- [[sentiqa-tre-identiteter]]: samme ansatt ligger under ansatt_nr,
-- ansatte.id og fritekst navn, og en logg som utledet stasjon fra navnet
-- ville tatt feil den dagen to heter det samme.
--
-- RADER UTEN STASJON ER EIERENS. En logglinje uten stasjon kan ikke
-- tilskrives noen butikksjefs ansvarsomraade, og da skal den ikke vaere
-- synlig for noen av dem. Den faller til retailer_admin, som ser hele
-- kjeden uansett. Det er samme betydning som null_stasjon: kun_eier har
-- paa regnskapslinjer, import_jobber og varsler.
--
-- Kolonnen er `on delete set null`, saa en slettet stasjon gjor raden
-- eierens. Det feiler LUKKET, og det er riktig vei.
--
-- ---------------------------------------------------------------------
-- KJEDEN BINDES UTENFOR OR-ET
--
-- Se 0141: `uke_rapport` NEVNTE retailer_id, men bare i den ene armen av
-- et or, og raden kunne flyttes ut av kjeden med stasjonen i behold.
-- Her staar `retailer_id = min kjede` som ytterste konjunkt, saa ingen
-- av grenene kan naa en annen kjede. Punkt 11 i rls_vakthund.sql feller
-- den formen naa, men predikatet skal vaere riktig av seg selv.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- Skrivingen er uroert: `persondata_logg_ins` har hatt
-- `bruker_id = (select auth.uid())` siden 0103 - det var den som viste
-- hva kontrolltiltak_bekreftelse manglet. Ingen update- eller
-- delete-policy: en logg som lar seg redigere av den som er logget,
-- dokumenterer ingenting.
--
-- BEVISKRAVET
--
--   manager_A1 ser A1                      ser
--   manager_A1 ser A2, A3                  ser ikke
--   manager_A12 ser A1, A2                 ser
--   manager_A12 ser A3                     ser ikke
--   owner_A ser A1, A2, A3                 ser
--   ingen A-bruker ser B1                  ser ikke
--   tablet ser ingenting                   ser ikke
--   rader uten stasjon                     bare eieren
-- =====================================================================


drop policy if exists persondata_logg_les on public.persondata_logg;
create policy persondata_logg_les on public.persondata_logg
  for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or (
        (select public.gjeldende_rolle()) = 'butikksjef'
        and stasjon_id in (select public.mine_stasjoner())
      )
    )
  );

comment on policy persondata_logg_les on public.persondata_logg is
  'Butikksjefen ser sine stasjoner, eieren ser kjeden, nettbrettet '
  'ingenting. Se 0148 - loggen er selv persondata, og var bredere enn '
  'tilgangen den logger.';
