-- =====================================================================
-- 0136 - produksjonsplanen: minste noedvendige capability for nettbrettet
--
-- KARTLAGT FRA SERVERHANDLINGENE, ikke antatt.
--
-- Nettbrettgrenen i produksjonsplan/page.tsx (linje 61-98) gjor tre ting:
-- leser `produksjonsplan_hode` (notat, publisert_tid), leser linjene, og
-- rendrer <TabletPlan>. TabletPlan importerer NOEYAKTIG EN handling:
--
--   tablet-plan.tsx:3   import { loggLagd } from './handlinger'
--
--   handling   tabell                   op       kolonner
--   loggLagd   produksjonsplan_linjer   update   lagd_hittil, oppdatert_tid
--
-- De tre andre handlingene hoerer til lederflaten (PlanTabell):
--
--   setLinje   produksjonsplan_linjer   upsert   plangrunnlaget
--   setNotat   produksjonsplan_hode     upsert   notat
--   publiser   produksjonsplan_hode     upsert   publisert_tid
--
-- INGEN FLATE SLETTER. `grep "\.delete(" ` paa begge tabellene gir null
-- treff i hele src/. Sletting er en capability ingen bruker - og en
-- ubrukt capability paa en delt konto i et butikklokale er bare risiko.
--
-- Foer denne hadde ingen av de aatte policyene et rollepredikat.
-- Nettbrettkontoen kunne slette en publisert produksjonsplan.
--
-- ---------------------------------------------------------------------
-- HVA SOM STRAMMES
--
--   hode    insert  update  delete   -> retailer_admin, butikksjef
--   hode    select                   -> uendret, nettbrettet leser planen
--   linjer  insert  delete           -> retailer_admin, butikksjef
--   linjer  update                   -> UENDRET. loggLagd trenger den.
--   linjer  select                   -> uendret
--
-- ---------------------------------------------------------------------
-- DET SOM IKKE LOESES HER, og som ikke skal gjemmes bort:
--
-- Nettbrettet trenger UPDATE paa linjene for `lagd_hittil`. RLS er
-- radnivaa, ikke kolonnenivaa - saa raden slipper ogsaa en endring av
-- `planlagt`. Et kolonnegrant ville truffet HELE `authenticated`, altsaa
-- ogsaa butikksjefen som skal kunne sette `planlagt` via setLinje. Samme
-- felle som `skills_score.kommentar`.
--
-- Skal det lukkes, er det en trigger eller en egen skrivevei - og det er
-- en produktbeslutning, ikke en innstramming man tar i forbifarten.
-- Rapportert, ikke gjettet.
--
-- ---------------------------------------------------------------------
-- RETAILER_ID I `with check`, samme klasse som 0135.
--
-- Begge tabellene er `retailer_and_station`, men `with check` saa bare
-- paa stasjonen. Det er noeyaktig lekkasjen 0135 rettet paa avvik og
-- stempling_hendelse. Siden policyene uansett skrives om her, tas den
-- med - ikke som en ny beslutning, men som den samme.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) produksjonsplan_hode - nettbrettet leser, lederen administrerer
-- ---------------------------------------------------------------------
drop policy if exists produksjonsplan_hode_ins on public.produksjonsplan_hode;
create policy produksjonsplan_hode_ins on public.produksjonsplan_hode for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists produksjonsplan_hode_upd on public.produksjonsplan_hode;
create policy produksjonsplan_hode_upd on public.produksjonsplan_hode for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists produksjonsplan_hode_del on public.produksjonsplan_hode;
create policy produksjonsplan_hode_del on public.produksjonsplan_hode for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy produksjonsplan_hode_upd on public.produksjonsplan_hode is
  'setNotat og publiser er lederhandlinger. Nettbrettet leser planen, det '
  'administrerer den ikke. Se 0136.';


-- ---------------------------------------------------------------------
-- 2) produksjonsplan_linjer - nettbrettet foerer 'lagd hittil'
--
-- UPDATE staar aapen med vilje: det er den ene operative handlingen
-- nettbrettet faktisk har. INSERT og DELETE er lederens.
-- ---------------------------------------------------------------------
drop policy if exists produksjonsplan_ins on public.produksjonsplan_linjer;
create policy produksjonsplan_ins on public.produksjonsplan_linjer for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists produksjonsplan_upd on public.produksjonsplan_linjer;
create policy produksjonsplan_upd on public.produksjonsplan_linjer for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists produksjonsplan_del on public.produksjonsplan_linjer;
create policy produksjonsplan_del on public.produksjonsplan_linjer for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy produksjonsplan_upd on public.produksjonsplan_linjer is
  'AAPEN FOR NETTBRETTET MED VILJE - loggLagd skriver lagd_hittil herfra. '
  'RLS er radnivaa, saa raden slipper ogsaa en endring av planlagt. '
  'Kolonnegrant duger ikke: det ville truffet butikksjefen ogsaa. Se 0136.';


-- ---------------------------------------------------------------------
-- ETTER DENNE: kjor rls_vakthund.sql, og deretter
-- rls_kanarifugl_generert.sql naar de to tabellene er klassifisert.
--
-- BEVISET SOM SKAL FORELIGGE:
--
--   tablet leser publisert plan paa egen stasjon        ok
--   tablet UPDATE lagd_hittil paa egen stasjon          ok
--   tablet DELETE hode                                  42501
--   tablet DELETE linjer                                42501
--   tablet INSERT hode / linjer                         42501
--   tablet naar ikke annen stasjon                      42501 / 0 rader
--   butikksjef setLinje / setNotat / publiser           ok
--   eier det samme                                      ok
--
-- Den nest siste linja er den som skiller en innstramming fra en
-- innstramming som ogsaa tok noe den ikke skulle.
-- ---------------------------------------------------------------------
