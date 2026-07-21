-- =====================================================================
-- Sentiqa - 0078_rls_runde2.sql
-- Fortsettelse av 0077. Ren ASCII, idempotent, kjores i ett stykke.
--
-- DEL 1 - SIKKERHET: stenger privilegie-eskalering via profiler.
-- DEL 2 - YTELSE: fjerner per-rad-funksjonskall fra de tabellene som
--         faktisk vokser med drift (ansatte, oppgaver, meldinger,
--         skills, merker, sjekkpunktsvar, IK-avlesninger, opplaering).
--
-- Definisjonstabeller med noen hundre rader (vaer, merker, lenker,
-- sjekkpunkter, puls_sporsmal osv.) er BEVISST ikke rort - per-rad-kall
-- der koster ingenting, og hver policy vi rorer er en risiko.
--
-- Semantikk er uendret overalt: mine_stasjoner() (0077) returnerer
-- noyaktig samme sett som har_stasjonstilgang() slipper gjennom.
-- =====================================================================


-- =====================================================================
-- DEL 1 - SIKKERHET
-- ---------------------------------------------------------------------
-- profiler_update_selv (0001_fundament.sql:169) har
--   using (id = auth.uid()) with check (id = auth.uid())
-- uten noen begrensning paa kolonnene rolle og retailer_id. Kommentaren
-- over policyen sier at det "haandheves i app-laget/DAL" - men PostgREST
-- gaar utenom app-laget:
--   PATCH /rest/v1/profiler?id=eq.<egen uuid>  {"rolle":"retailer_admin"}
-- ville gjort en hvilken som helst innlogget bruker til admin, og
--   {"retailer_id":"<annen kjede>"} ville flyttet dem inn i en annen
-- kundes data. gjeldende_rolle() leser fra nettopp denne tabellen, saa
-- alt annet RLS folger etter.
--
-- Fiks: ta fra rollen "authenticated" retten til aa skrive til profiler
-- i det hele tatt. Verifisert at INGEN appflyt gaar via brukerklienten -
-- alle skrivinger bruker service-rollen, som ikke rammes av dette:
--   src/app/registrer/handlinger.ts:79      (admin.from('profiler').insert)
--   src/app/(beskyttet)/brukere/handlinger.ts:53   (admin)
--   src/app/(beskyttet)/plattform/handlinger.ts:68 (admin)
-- Lesing beholdes - src/lib/auth/dal.ts:28 leser med brukerklienten.
-- ---------------------------------------------------------------------
revoke insert, update, delete on public.profiler from authenticated;

-- Policyen blir virkningslos naar grantet er borte, men vi fjerner den
-- ogsaa saa ingen senere "grant all"-opprydding gjenaapner hullet uten
-- at noen ser det.
drop policy if exists profiler_update_selv on public.profiler;

comment on table public.profiler is
  'Rolle og tenant endres KUN via service-rollen (server actions). '
  'authenticated har bevisst ikke insert/update/delete - se 0078.';


-- =====================================================================
-- DEL 2 - YTELSE
-- =====================================================================

-- ---------------------------------------------------------------------
-- ansatte
-- ---------------------------------------------------------------------
drop policy if exists ansatte_les on public.ansatte;
create policy ansatte_les on public.ansatte for select to authenticated
  using (slettet_tid is null and stasjon_id in (select public.mine_stasjoner()));

drop policy if exists ansatte_skriv on public.ansatte;
drop policy if exists ansatte_ins on public.ansatte;
drop policy if exists ansatte_upd on public.ansatte;
drop policy if exists ansatte_del on public.ansatte;

create policy ansatte_ins on public.ansatte for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy ansatte_upd on public.ansatte for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy ansatte_del on public.ansatte for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));


-- ---------------------------------------------------------------------
-- oppgaver
-- ---------------------------------------------------------------------
drop policy if exists oppgaver_les on public.oppgaver;
create policy oppgaver_les on public.oppgaver for select to authenticated
  using (slettet_tid is null and stasjon_id in (select public.mine_stasjoner()));

drop policy if exists oppgaver_skriv on public.oppgaver;
drop policy if exists oppgaver_ins on public.oppgaver;
drop policy if exists oppgaver_upd on public.oppgaver;
drop policy if exists oppgaver_del on public.oppgaver;

create policy oppgaver_ins on public.oppgaver for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy oppgaver_upd on public.oppgaver for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy oppgaver_del on public.oppgaver for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));


-- ---------------------------------------------------------------------
-- tablet_meldinger (stasjon_id null = melding til hele kjeden)
-- ---------------------------------------------------------------------
drop policy if exists tablet_meldinger_les on public.tablet_meldinger;
create policy tablet_meldinger_les on public.tablet_meldinger for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );

drop policy if exists tablet_meldinger_skriv on public.tablet_meldinger;
drop policy if exists tablet_meldinger_ins on public.tablet_meldinger;
drop policy if exists tablet_meldinger_upd on public.tablet_meldinger;
drop policy if exists tablet_meldinger_del on public.tablet_meldinger;

create policy tablet_meldinger_ins on public.tablet_meldinger for insert to authenticated
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );
create policy tablet_meldinger_upd on public.tablet_meldinger for update to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  )
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );
create policy tablet_meldinger_del on public.tablet_meldinger for delete to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
    and (stasjon_id is null or stasjon_id in (select public.mine_stasjoner()))
  );


-- ---------------------------------------------------------------------
-- skills_score
-- ---------------------------------------------------------------------
drop policy if exists skills_les on public.skills_score;
create policy skills_les on public.skills_score for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists skills_skriv on public.skills_score;
drop policy if exists skills_ins on public.skills_score;
drop policy if exists skills_upd on public.skills_score;
drop policy if exists skills_del on public.skills_score;

create policy skills_ins on public.skills_score for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy skills_upd on public.skills_score for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy skills_del on public.skills_score for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));


-- ---------------------------------------------------------------------
-- tildelte_merker
-- ---------------------------------------------------------------------
drop policy if exists tildelte_les on public.tildelte_merker;
create policy tildelte_les on public.tildelte_merker for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists tildelte_skriv on public.tildelte_merker;
drop policy if exists tildelte_ins on public.tildelte_merker;
drop policy if exists tildelte_upd on public.tildelte_merker;
drop policy if exists tildelte_del on public.tildelte_merker;

create policy tildelte_ins on public.tildelte_merker for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy tildelte_upd on public.tildelte_merker for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));
create policy tildelte_del on public.tildelte_merker for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));


-- ---------------------------------------------------------------------
-- sjekkpunkt_svar (vokser per sjekkpunkt per dag)
-- ---------------------------------------------------------------------
drop policy if exists sjekkpunkt_svar_les on public.sjekkpunkt_svar;
create policy sjekkpunkt_svar_les on public.sjekkpunkt_svar for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists sjekkpunkt_svar_skriv on public.sjekkpunkt_svar;
drop policy if exists sjekkpunkt_svar_ins on public.sjekkpunkt_svar;
drop policy if exists sjekkpunkt_svar_upd on public.sjekkpunkt_svar;
drop policy if exists sjekkpunkt_svar_del on public.sjekkpunkt_svar;

create policy sjekkpunkt_svar_ins on public.sjekkpunkt_svar for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy sjekkpunkt_svar_upd on public.sjekkpunkt_svar for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));
create policy sjekkpunkt_svar_del on public.sjekkpunkt_svar for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));


-- ---------------------------------------------------------------------
-- ik_avlesninger (temperaturmaalinger, flere per dag per kontrollpunkt)
-- Skrivepolicyen var allerede "for insert" - kun innpakking trengs.
-- ---------------------------------------------------------------------
drop policy if exists ik_avlesninger_les on public.ik_avlesninger;
create policy ik_avlesninger_les on public.ik_avlesninger for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists ik_avlesninger_skriv on public.ik_avlesninger;
create policy ik_avlesninger_skriv on public.ik_avlesninger for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));


-- ---------------------------------------------------------------------
-- opplaering_skift / opplaering_utfort
-- Her laa har_stasjonstilgang() INNE i en korrelert EXISTS - altsaa ett
-- funksjonskall per periode-rad per svar-rad. Erstattes av en IN-liste
-- over periode-id-er, som evalueres en gang.
-- ---------------------------------------------------------------------
drop policy if exists opp2_skift_les on public.opplaering_skift;
create policy opp2_skift_les on public.opplaering_skift for select to authenticated
  using (periode_id in (
    select p.id from public.opplaering_periode p
    where p.stasjon_id in (select public.mine_stasjoner())));

drop policy if exists opp2_skift_skriv on public.opplaering_skift;
drop policy if exists opp2_skift_ins on public.opplaering_skift;
drop policy if exists opp2_skift_upd on public.opplaering_skift;
drop policy if exists opp2_skift_del on public.opplaering_skift;

create policy opp2_skift_ins on public.opplaering_skift for insert to authenticated
  with check ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));
create policy opp2_skift_upd on public.opplaering_skift for update to authenticated
  using ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())))
  with check ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));
create policy opp2_skift_del on public.opplaering_skift for delete to authenticated
  using ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())));

drop policy if exists opp2_utfort_les on public.opplaering_utfort;
create policy opp2_utfort_les on public.opplaering_utfort for select to authenticated
  using (periode_id in (
    select p.id from public.opplaering_periode p
    where p.stasjon_id in (select public.mine_stasjoner())));

drop policy if exists opp2_utfort_skriv on public.opplaering_utfort;
drop policy if exists opp2_utfort_ins on public.opplaering_utfort;
drop policy if exists opp2_utfort_upd on public.opplaering_utfort;
drop policy if exists opp2_utfort_del on public.opplaering_utfort;

create policy opp2_utfort_ins on public.opplaering_utfort for insert to authenticated
  with check ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));
create policy opp2_utfort_upd on public.opplaering_utfort for update to authenticated
  using ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())))
  with check ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));
create policy opp2_utfort_del on public.opplaering_utfort for delete to authenticated
  using ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())));


-- ---------------------------------------------------------------------
-- Stottende indekser for de nye IN-subqueryene.
-- ---------------------------------------------------------------------
create index if not exists opplaering_periode_stasjon_idx
  on public.opplaering_periode (stasjon_id);
create index if not exists opplaering_skift_periode_idx
  on public.opplaering_skift (periode_id);
create index if not exists opplaering_utfort_periode_idx
  on public.opplaering_utfort (periode_id);


-- =====================================================================
-- ETTER KJORING - verifiser at ingenting ble stengt for hardt:
--
--   select tablename, policyname, cmd from pg_policies
--   where schemaname = 'public'
--     and tablename in ('ansatte','oppgaver','tablet_meldinger','skills_score',
--                       'tildelte_merker','sjekkpunkt_svar','ik_avlesninger',
--                       'opplaering_skift','opplaering_utfort')
--   order by tablename, policyname;
--
-- Forventet: hver tabell har _les + _ins/_upd/_del (ik_avlesninger har
-- kun _les + _skriv, slik den alltid har hatt).
--
--
-- KREVER MANUELL VURDERING:
--
-- A) Test at brukeradministrasjon fortsatt virker etter DEL 1. Alle kjente
--    skrivinger til profiler gaar via service-rollen, men gaa gjennom
--    /brukere (opprett + endre bruker) og /plattform en gang for aa vaere
--    sikker. Skulle noe brekke, er det en app-flyt som feilaktig brukte
--    brukerklienten - da skal DEN fikses, ikke grantet gis tilbake.
--
-- B) Gjenstaaende tabeller med per-rad-kall er bevisst ikke rort. Det er
--    definisjonstabeller (noen hundre rader) der kostnaden er null.
--    Tell dem med:
--      select count(distinct tablename) from pg_policies
--      where schemaname='public' and cmd in ('SELECT','ALL')
--        and (coalesce(qual,'') like '%gjeldende_%'
--             or coalesce(qual,'') like '%har_stasjonstilgang%')
--        and coalesce(qual,'') not like '%( SELECT%';
--    Vokser en av dem til titusenvis av rader, skal den flyttes hit.
--
-- C) puls_svar / puls_runde er ikke rort - tabellene er tomme i dag.
--    Tas nar pulsfunksjonen settes i drift.
--
-- D) 0077 sine RPC-er (svinn_vindu_sum / matsalg_vindu_sum) er fortsatt
--    ikke tatt i bruk i src/app/(beskyttet)/svinn/page.tsx:63. Til det er
--    gjort regnes svinn% fortsatt paa maks 1000 rader.
-- =====================================================================
