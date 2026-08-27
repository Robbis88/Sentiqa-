-- =====================================================================
-- 0147 - en bekreftelse uten stasjon er kjedens
--
-- PRODUKTBESLUTNING, tatt 2026-08-27: en rad i
-- kontrolltiltak_bekreftelse med `stasjon_id = null` er en legitim
-- retailer-/lederbekreftelse. Null betyr EGEN RETAILER, aldri global.
--
-- Den formen oppstaar hver gang en leder bekrefter: `bekreftLest`
-- (mine-opplysninger/handlinger.ts) slaar bare opp stasjon naar det
-- finnes en aktiv vakt, altsaa paa nettbrettet. Butikksjefen og eieren
-- logger inn som seg selv, og raden deres faar ingen stasjon.
--
-- ---------------------------------------------------------------------
-- BLINDSONEN SOM FULGTE AV DET
--
-- `kontrolltiltak_les` fra 0103 har to grener:
--
--   bruker_id = auth.uid()                        din egen rad
--   stasjon_id in mine_stasjoner() and leder      lederens revisjon
--
-- For en rad UTEN stasjon er den andre grenen alltid usann. Da saa
-- INGEN ANDRE enn personen selv raden - heller ikke eieren.
--
-- ARBEIDSGIVER KUNNE DERMED IKKE DOKUMENTERE AT LEDERNE VAR INFORMERT.
-- Plikten etter aml. par. 9-2 er arbeidsgivers, og en dokumentasjon
-- bare den ansatte selv kan se, dokumenterer ingenting utad. At
-- butikksjefene er de eneste det gjaldt, gjorde det ikke mindre galt -
-- det er nettopp lederne som ellers har innsynet.
--
-- ---------------------------------------------------------------------
-- HVA SOM ENDRES
--
-- En tredje gren i LESINGEN, og bare der:
--
--   stasjon_id is null and retailer_id = min kjede and retailer_admin
--
-- Eieren ser kjedens stasjonslose bekreftelser. Butikksjefen gjor det
-- ikke: hennes revisjonsinnsyn er stasjonene hun administrerer, og en
-- annen leders personlige bekreftelse er ikke en av dem.
--
-- Samme betydning som `null_stasjon: kun_eier` har paa regnskapslinjer,
-- import_jobber og varsler - null er kjedens, og kjeden er eierens.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ENDRES
--
-- SKRIVINGEN ER UROERT. 0145 staar: bruker_id er null eller den
-- innloggede, stasjon_id og ansatt_id innenfor mine_stasjoner(). Ingen
-- kan skrive en bekreftelse i en annens navn, og en stasjonslos rad er
-- fortsatt bundet til egen retailer - aldri global.
--
-- Ingen ny skriverett, ingen ny rolle, ingen ny tabell.
--
-- BEVISKRAVET
--
--   owner_A ser kjedens null-stasjonsrad            ser
--   owner_A ser IKKE den andre kjedens null-rad     ser ikke
--   manager/tablet ser IKKE kjedens null-rad        ser ikke
--   alt fra 0145 staar uendret
-- =====================================================================


drop policy if exists kontrolltiltak_les on public.kontrolltiltak_bekreftelse;
create policy kontrolltiltak_les on public.kontrolltiltak_bekreftelse
  for select to authenticated
  using (
    -- Din egen. Uten den kan ikke den ansatte selv se hva hun har
    -- faatt vite, og det er halve poenget med par. 9-2.
    bruker_id = (select auth.uid())
    -- Lederens revisjon paa stasjonene hun administrerer.
    or (stasjon_id in (select public.mine_stasjoner())
        and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    -- Kjedens egne, stasjonslose bekreftelser: eierens revisjon.
    or (stasjon_id is null
        and retailer_id = (select public.gjeldende_retailer_id())
        and (select public.gjeldende_rolle()) = 'retailer_admin')
  );

comment on policy kontrolltiltak_les on public.kontrolltiltak_bekreftelse is
  'Tre grener: din egen, lederens stasjoner, og kjedens stasjonslose '
  'rader for eieren. Se 0147 - uten den siste kunne arbeidsgiver ikke '
  'dokumentere at LEDERNE var informert.';
