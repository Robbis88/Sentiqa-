-- =====================================================================
-- 0137 - bemanningstaket er lederdata
--
-- `bemanning_stasjon_les` hadde ikke rollepredikat, saa nettbrettets
-- delte konto leste `maks_bemanning` paa egen stasjon.
--
-- KARTLAGT FOER DET BLE ENDRET. Tabellen leses fra /bemanning, som er
-- lederflaten - `bemanning/page.tsx:333`. Ingen rute nettbrettet kan
-- aapne bruker den. Produktkontrakten sier "tablet: ingen lederdata",
-- og et bemanningstak er lederdata: det er rammen butikksjefen
-- planlegger innenfor, ikke noe medarbeideren skal forholde seg til.
--
-- Klassifisert i kontrakten foerst, som `avvik_fra_intensjon`, og
-- strammet her - i den rekkefoelgen med vilje. Kontrakten beskrev
-- dagens sannhet; naa flyttes sannheten.
--
-- MINSTE ENDRING: ett predikat paa en policy. Skrivepolicyene hadde
-- rollepredikat fra `0087` og er uroert.
--
-- Funksjonskallet er pakket i `(select ...)` saa det blir initplan.
-- =====================================================================
drop policy if exists bemanning_stasjon_les on public.bemanning_stasjon;
create policy bemanning_stasjon_les on public.bemanning_stasjon
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy bemanning_stasjon_les on public.bemanning_stasjon is
  'Bemanningstaket er lederdata. Nettbrettet leste det foer 0137 uten at '
  'noen nettbrettrute brukte tabellen.';

-- ---------------------------------------------------------------------
-- BEVISET SOM SKAL FORELIGGE ETTERPAA:
--
--   tablet SELECT egen stasjon        -> ser ikke
--   manager_A1 SELECT A1              -> ser
--   manager_A12 SELECT A1 og A2       -> ser, A3 -> ser ikke
--   owner_A SELECT A1, A2, A3         -> ser
--   manager/owner INSERT/UPDATE/DELETE -> uendret, 1 rad
--
-- De fire siste er poenget. En innstramming som ogsaa tar lederens
-- tilgang ser identisk ut fra nettbrettets side.
-- ---------------------------------------------------------------------
