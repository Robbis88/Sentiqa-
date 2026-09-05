-- =====================================================================
-- KASTBUDSJETTET ER LEDERDATA, IKKE NETTBRETTDATA
--
-- `0172` skrev policyen som `stasjon_id in (mine_stasjoner())` alene.
-- Det slipper OGSAA nettbrettkontoen inn: den er bundet til en stasjon,
-- saa `mine_stasjoner()` svarer for den.
--
-- Tenantmatrisen fanget det med en gang - kontrakten sa `tablet: none`,
-- basen sa noe annet:
--
--     FEIL | kastbudsjett tablet_A1 SELECT A1 -> ser ikke
--     FEIL | kastbudsjett tablet_B1 SELECT B1 -> ser ikke
--
-- Kommentaren i `0172` sa hva jeg mente: «BUTIKKSJEFEN SKAL SE SITT EGET
-- KRAV». Men **RLS avgjoer hva som ER mulig, ikke hva kommentaren mener**,
-- og det gjelder ogsaa naar den som skrev kommentaren var meg.
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE BARE RETTE KONTRAKTEN
--
-- Fordi budsjettet ikke hoerer hjemme paa nettbrettet. Det er en delt
-- konto i butikken, og kastbudsjettet er et krav St1 stiller til
-- driveren - «hvor mye har vi lov til aa kaste i aar». Det styres av
-- butikksjefen, som ogsaa er den som kan gjoere noe med det.
--
-- Aa endre kontrakten i stedet ville vaert aa la implementasjonen
-- bestemme hva som er riktig. Da er matrisen ikke lenger en fasit, bare
-- et referat.
--
-- Idempotent: `drop policy if exists` foer `create policy`.
-- =====================================================================

drop policy if exists kastbudsjett_les on public.kastbudsjett;
create policy kastbudsjett_les on public.kastbudsjett
  for select to authenticated
  using (
    stasjon_id in (select public.mine_stasjoner())
    -- Pakket i `(select ...)` saa den evalueres én gang som initplan.
    -- `gjeldende_rolle()` er security definer og kan ikke inlines; uten
    -- pakkingen kjoeres den per rad.
    and (select public.gjeldende_rolle())::text in ('retailer_admin', 'butikksjef')
  );
