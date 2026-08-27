-- =====================================================================
-- 0144 - importkoeen er ikke nettbrettets
--
-- `import_jobber_sjef_les` (0002) har ikke rollepredikat:
--
--   using (stasjon_id is not null
--          and stasjon_id in (select public.mine_stasjoner()))
--
-- `mine_stasjoner()` dekker BADE butikksjef og butikkbruker_tablet, saa
-- den delte kontoen i butikken leser importjobbene for sin stasjon -
-- filnavn, status, feilmelding og antall rader fra kjedens rapporter.
--
-- POLICYEN SIER DET SELV, i 0002 linje 105:
--
--   "import_jobber: admin ser/skriver alt eget; butikksjef LESER jobber
--    for tildelte stasjoner."
--
-- Rollen sto i kommentaren og ikke i predikatet. Samme form som 0137.
--
-- KARTLAGT FOER DET BLE ENDRET. `/import` er den eneste flaten som
-- leser tabellen, og den er laast til retailer_admin
-- (`import/page.tsx:125`). Ingen rute nettbrettet kan aapne bruker
-- import_jobber. Butikksjefens lesing beholdes - 0002 ville det slik -
-- og bare nettbrettet mister den.
--
-- FUNNET AV ATFERDSMATRISEN, i den kjoringen som klassifiserte
-- import_jobber som den siste av 80 tabeller:
--
--   FEIL | import_jobber tablet_A1 SELECT A1 -> ser ikke |
--   FEIL | import_jobber tablet_B1 SELECT B1 -> ser ikke |
--
-- Ikke en tenantlekkasje: nettbrettet saa bare sin egen stasjon. Men
-- det er lederdata, og "tablet: ingen lederdata" er produktkontrakten.
--
-- MINSTE ENDRING: ett predikat. Admin-policyene fra 0107 er uroert, og
-- funksjonskallene er pakket i (select ...) saa de blir initplan.
-- =====================================================================
drop policy if exists import_jobber_sjef_les on public.import_jobber;
create policy import_jobber_sjef_les on public.import_jobber
  for select to authenticated
  using (stasjon_id is not null
         and stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'butikksjef');

comment on policy import_jobber_sjef_les on public.import_jobber is
  'Rollen sto i kommentaren i 0002, ikke i predikatet - saa nettbrettet '
  'leste importkoeen til 0144. Se 0137 for samme form.';
