-- =====================================================================
-- 0107 - de trege policyene som aldri ble sett
--
-- Dekningssjekken (rls_vakthund.sql punkt 4, 2026-08-18) viste at 47
-- tabeller hadde policyer uten aa bli sjekket av noen. Seksten av dem
-- vokser med drift og har begge monstrene som tok ned daglig_salg
-- 2026-06-16:
--
--   1) Hjelpefunksjoner kalt UTEN (select ...). De er security definer og
--      kan ikke inlines, saa de evalueres PER RAD -> statement timeout ->
--      0 rader. Ser ut som datatap, er det ikke.
--
--   2) `for all`-policyer. USING i en for all-policy gjelder OGSAA select,
--      og permissive policyer OR-es sammen - saa skrivepolicyen trekkes
--      inn i hver eneste leseplan og gjor retailer_id ikke-sargbar.
--
-- Dette er ingen regresjon. Policyene har vaert slik siden migrasjonene
-- som lagde dem (0002 til 0063); ingen hadde sett etter. 0067 og 0073
-- ryddet i de varme tabellene man visste om - dette er resten.
--
-- ENDRINGEN ER MEKANISK OG BEVARER SEMANTIKKEN:
--   public.gjeldende_rolle()        -> (select public.gjeldende_rolle())
--   public.gjeldende_retailer_id()  -> (select public.gjeldende_retailer_id())
--   auth.uid()                      -> (select auth.uid())
--   public.har_stasjonstilgang(x)   -> x in (select public.mine_stasjoner())
--
-- Det siste byttet er trygt fordi mine_stasjoner() returnerer noyaktig
-- settet har_stasjonstilgang() tester mot (verifisert mot 0001 og 0077).
-- har_stasjonstilgang tar en KOLONNE som argument og kan derfor aldri bli
-- initplan, uansett hvor mange (select ...) man pakker rundt den.
--
-- FOR ALL SPLITTES i insert/update/delete. Fire tabeller hadde KUN en for
-- all-policy - import_jobber, personlig_kryss, raa_filer og
-- regnskapsanalyser. De faar en egen select-policy her, ellers ville
-- splittingen tatt fra dem leseretten.
--
-- Alt er drop-if-exists + create, saa settet taaler aa kjores om igjen.
-- =====================================================================

-- --- ai_tool_log (0008) ---------------------------------------------
drop policy if exists ai_tool_log_les on public.ai_tool_log;
create policy ai_tool_log_les on public.ai_tool_log for select to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists ai_tool_log_skriv on public.ai_tool_log;
create policy ai_tool_log_skriv on public.ai_tool_log for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id()));

-- --- import_jobber (0002) -------------------------------------------
-- Hadde kun for all for admin. Select maa gjenopprettes eksplisitt:
-- sjef-policyen krever stasjon_id, og en importjobb uten stasjon ville
-- blitt usynlig for eieren.
drop policy if exists import_jobber_admin on public.import_jobber;
create policy import_jobber_admin_les on public.import_jobber for select to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));
create policy import_jobber_admin_ins on public.import_jobber for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy import_jobber_admin_upd on public.import_jobber for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy import_jobber_admin_del on public.import_jobber for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists import_jobber_sjef_les on public.import_jobber;
create policy import_jobber_sjef_les on public.import_jobber for select to authenticated
  using (stasjon_id is not null and stasjon_id in (select public.mine_stasjoner()));

-- --- lederstotte_rapporter (0011) ------------------------------------
drop policy if exists lederstotte_les on public.lederstotte_rapporter;
create policy lederstotte_les on public.lederstotte_rapporter for select to authenticated
  using (
    slettet_tid is null and (
      ((select public.gjeldende_rolle()) = 'retailer_admin'
       and retailer_id = (select public.gjeldende_retailer_id()))
      or stasjon_id in (select public.mine_stasjoner())
    )
  );

drop policy if exists lederstotte_skriv on public.lederstotte_rapporter;
create policy lederstotte_ins on public.lederstotte_rapporter for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy lederstotte_upd on public.lederstotte_rapporter for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy lederstotte_del on public.lederstotte_rapporter for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

-- --- opplaering_periode (0042) ---------------------------------------
drop policy if exists opp2_periode_les on public.opplaering_periode;
create policy opp2_periode_les on public.opplaering_periode for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists opp2_periode_skriv on public.opplaering_periode;
create policy opp2_periode_ins on public.opplaering_periode for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy opp2_periode_upd on public.opplaering_periode for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy opp2_periode_del on public.opplaering_periode for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- pengepremie_bruk (0041) -----------------------------------------
drop policy if exists pengepremie_bruk_les on public.pengepremie_bruk;
create policy pengepremie_bruk_les on public.pengepremie_bruk for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists pengepremie_bruk_skriv on public.pengepremie_bruk;
create policy pengepremie_bruk_ins on public.pengepremie_bruk for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy pengepremie_bruk_upd on public.pengepremie_bruk for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy pengepremie_bruk_del on public.pengepremie_bruk for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- personlig_kryss (0034) ------------------------------------------
-- Privat liste, eid av brukeren selv. Hadde kun for all.
drop policy if exists personlig_kryss_egne on public.personlig_kryss;
create policy personlig_kryss_les on public.personlig_kryss for select to authenticated
  using (user_id = (select auth.uid()));
create policy personlig_kryss_ins on public.personlig_kryss for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy personlig_kryss_upd on public.personlig_kryss for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy personlig_kryss_del on public.personlig_kryss for delete to authenticated
  using (user_id = (select auth.uid()));

-- --- produksjonsplan_hode (0052) -------------------------------------
drop policy if exists produksjonsplan_hode_les on public.produksjonsplan_hode;
create policy produksjonsplan_hode_les on public.produksjonsplan_hode for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists produksjonsplan_hode_skriv on public.produksjonsplan_hode;
create policy produksjonsplan_hode_ins on public.produksjonsplan_hode for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy produksjonsplan_hode_upd on public.produksjonsplan_hode for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy produksjonsplan_hode_del on public.produksjonsplan_hode for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

-- --- produksjonsplan_linjer (0031) -----------------------------------
drop policy if exists produksjonsplan_les on public.produksjonsplan_linjer;
create policy produksjonsplan_les on public.produksjonsplan_linjer for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists produksjonsplan_skriv on public.produksjonsplan_linjer;
create policy produksjonsplan_ins on public.produksjonsplan_linjer for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy produksjonsplan_upd on public.produksjonsplan_linjer for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy produksjonsplan_del on public.produksjonsplan_linjer for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

-- --- puls_svar (0026) ------------------------------------------------
drop policy if exists puls_les on public.puls_svar;
create policy puls_les on public.puls_svar for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists puls_insert on public.puls_svar;
create policy puls_insert on public.puls_svar for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists puls_update on public.puls_svar;
create policy puls_update on public.puls_svar for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));

-- --- raa_filer (0002) ------------------------------------------------
drop policy if exists raa_filer_admin on public.raa_filer;
create policy raa_filer_admin_les on public.raa_filer for select to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));
create policy raa_filer_admin_ins on public.raa_filer for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy raa_filer_admin_upd on public.raa_filer for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy raa_filer_admin_del on public.raa_filer for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

-- --- regnskapsanalyser (0010) ----------------------------------------
drop policy if exists regnskapsanalyser_eier on public.regnskapsanalyser;
create policy regnskapsanalyser_les on public.regnskapsanalyser for select to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));
create policy regnskapsanalyser_ins on public.regnskapsanalyser for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy regnskapsanalyser_upd on public.regnskapsanalyser for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));
create policy regnskapsanalyser_del on public.regnskapsanalyser for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

-- --- tilbakemelding (0040) -------------------------------------------
drop policy if exists tilbakemelding_les on public.tilbakemelding;
create policy tilbakemelding_les on public.tilbakemelding for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists tilbakemelding_insert on public.tilbakemelding;
create policy tilbakemelding_insert on public.tilbakemelding for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists tilbakemelding_update on public.tilbakemelding;
create policy tilbakemelding_update on public.tilbakemelding for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- trafikk (0063) --------------------------------------------------
drop policy if exists trafikk_les on public.trafikk;
create policy trafikk_les on public.trafikk for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

-- --- uke_rapport (0051) ----------------------------------------------
drop policy if exists uke_rapport_les on public.uke_rapport;
create policy uke_rapport_les on public.uke_rapport for select to authenticated
  using (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  );

drop policy if exists uke_rapport_skriv on public.uke_rapport;
create policy uke_rapport_ins on public.uke_rapport for insert to authenticated
  with check (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  );
create policy uke_rapport_upd on public.uke_rapport for update to authenticated
  using (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  )
  with check (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  );
create policy uke_rapport_del on public.uke_rapport for delete to authenticated
  using (
    ((select public.gjeldende_rolle()) = 'retailer_admin'
     and retailer_id = (select public.gjeldende_retailer_id()))
    or stasjon_id in (select public.mine_stasjoner())
  );

-- --- vaer (0015) -----------------------------------------------------
drop policy if exists vaer_les on public.vaer;
create policy vaer_les on public.vaer for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists vaer_skriv on public.vaer;
create policy vaer_ins on public.vaer for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and stasjon_id in (select public.mine_stasjoner()));
create policy vaer_upd on public.vaer for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and stasjon_id in (select public.mine_stasjoner()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and stasjon_id in (select public.mine_stasjoner()));
create policy vaer_del on public.vaer for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and stasjon_id in (select public.mine_stasjoner()));

-- --- varsler (0018) --------------------------------------------------
drop policy if exists varsler_les on public.varsler;
create policy varsler_les on public.varsler for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (
      mottaker_id = (select auth.uid())
      or (mottaker_id is null and stasjon_id is not null
          and stasjon_id in (select public.mine_stasjoner()))
      or (mottaker_id is null and stasjon_id is null
          and (select public.gjeldende_rolle()) = 'retailer_admin')
    )
  );

drop policy if exists varsler_insert on public.varsler;
create policy varsler_insert on public.varsler for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists varsler_update on public.varsler;
create policy varsler_update on public.varsler for update to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      mottaker_id = (select auth.uid())
      or (mottaker_id is null and stasjon_id is not null
          and stasjon_id in (select public.mine_stasjoner()))
      or (mottaker_id is null and stasjon_id is null
          and (select public.gjeldende_rolle()) = 'retailer_admin')
    )
  );

-- Kontroll etter kjoring: supabase/tests/rls_funn.sql skal gi null rader.
