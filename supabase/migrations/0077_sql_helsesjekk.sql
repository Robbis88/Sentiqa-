-- =====================================================================
-- Sentiqa - 0077_sql_helsesjekk.sql
-- Samleopprydning etter SQL-helsesjekk. Ren ASCII, idempotent, kan kjores
-- i ett stykke i Supabase SQL Editor og kan kjores flere ganger.
--
-- Hva den fikser:
--  1) "for all"-skrivepolicyene (_skriv / _admin_skriv) gjaldt ogsa SELECT
--     (permissive policyer OR-es), med upakkede gjeldende_rolle() /
--     gjeldende_retailer_id() -> per-rad-kall. Det gjorde 0067-fiksen
--     virkningslos paa lesesiden. Splittes i insert/update/delete og pakkes
--     i (select ...) etter monsteret fra 0067.
--  2) rutiner / rutine_utforinger brukte har_stasjonstilgang(stasjon_id) per
--     rad (kolonne-argument -> aldri initplan). Erstattes av en initplan-bar
--     IN-subquery, pluss indekser paa oppslagene appen faktisk gjor.
--  3) 0073 (malekort) reintroduserte upakkede kall og "for all"-policyer.
--  4) 0076 stengte tablet-kontoen ute fra a REGISTRERE IK-mat-avvik.
--     Innsetting apnes igjen for stasjonstilgang; endring/sletting forblir
--     begrenset til retailer_admin/butikksjef slik 0076 ville.
--  5) Nye aggregerende RPC-er for svinnvinduet, saa app-laget slipper a
--     summere raa transaksjonsrader mot PostgREST sin 1000-rad-grense.
--
-- Semantikk er bevisst uendret: hver policy slipper inn noyaktig de samme
-- radene som for. Kun evalueringsmaaten og kommandoinndelingen endres.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1a) daglig_salg - skrivepolicyen ut av SELECT-planen
-- ---------------------------------------------------------------------
drop policy if exists daglig_salg_admin_skriv on public.daglig_salg;
drop policy if exists daglig_salg_admin_ins on public.daglig_salg;
drop policy if exists daglig_salg_admin_upd on public.daglig_salg;
drop policy if exists daglig_salg_admin_del on public.daglig_salg;

create policy daglig_salg_admin_ins on public.daglig_salg for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy daglig_salg_admin_upd on public.daglig_salg for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy daglig_salg_admin_del on public.daglig_salg for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));


-- ---------------------------------------------------------------------
-- 1b) timesalg, kassererstatistikk, synlig_svinn (samme monster som 0005)
-- ---------------------------------------------------------------------
do $do$
declare t text;
begin
  foreach t in array array['timesalg', 'kassererstatistikk', 'synlig_svinn'] loop
    execute format('drop policy if exists %I on public.%I', t || '_skriv', t);
    execute format('drop policy if exists %I on public.%I', t || '_ins', t);
    execute format('drop policy if exists %I on public.%I', t || '_upd', t);
    execute format('drop policy if exists %I on public.%I', t || '_del', t);

    execute format($f$
      create policy %I on public.%I for insert to authenticated
      with check ((select public.gjeldende_rolle()) = 'retailer_admin'
                  and retailer_id = (select public.gjeldende_retailer_id()))$f$,
      t || '_ins', t);

    execute format($f$
      create policy %I on public.%I for update to authenticated
      using ((select public.gjeldende_rolle()) = 'retailer_admin'
             and retailer_id = (select public.gjeldende_retailer_id()))
      with check ((select public.gjeldende_rolle()) = 'retailer_admin'
                  and retailer_id = (select public.gjeldende_retailer_id()))$f$,
      t || '_upd', t);

    execute format($f$
      create policy %I on public.%I for delete to authenticated
      using ((select public.gjeldende_rolle()) = 'retailer_admin'
             and retailer_id = (select public.gjeldende_retailer_id()))$f$,
      t || '_del', t);
  end loop;
end $do$;


-- ---------------------------------------------------------------------
-- 1c) regnskapslinjer
-- ---------------------------------------------------------------------
drop policy if exists regnskapslinjer_skriv on public.regnskapslinjer;
drop policy if exists regnskapslinjer_ins on public.regnskapslinjer;
drop policy if exists regnskapslinjer_upd on public.regnskapslinjer;
drop policy if exists regnskapslinjer_del on public.regnskapslinjer;

create policy regnskapslinjer_ins on public.regnskapslinjer for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy regnskapslinjer_upd on public.regnskapslinjer for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy regnskapslinjer_del on public.regnskapslinjer for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));


-- ---------------------------------------------------------------------
-- 1d) regnskap_usynlig_svinn
-- ---------------------------------------------------------------------
drop policy if exists usynlig_svinn_skriv on public.regnskap_usynlig_svinn;
drop policy if exists usynlig_svinn_ins on public.regnskap_usynlig_svinn;
drop policy if exists usynlig_svinn_upd on public.regnskap_usynlig_svinn;
drop policy if exists usynlig_svinn_del on public.regnskap_usynlig_svinn;

create policy usynlig_svinn_ins on public.regnskap_usynlig_svinn for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy usynlig_svinn_upd on public.regnskap_usynlig_svinn for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy usynlig_svinn_del on public.regnskap_usynlig_svinn for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));


-- ---------------------------------------------------------------------
-- 2a) Initplan-bar erstatning for har_stasjonstilgang(kolonne)
-- Returnerer settet av stasjoner brukeren har tilgang til. Brukt som
-- "stasjon_id in (select public.mine_stasjoner())" evalueres den EN gang
-- per sporring (hashed subplan), ikke per rad.
-- Semantikken er identisk med har_stasjonstilgang() i 0001_fundament.sql:
--   retailer_admin      -> egne, ikke-slettede stasjoner
--   butikksjef / tablet -> tildelte stasjoner i butikksjef_stasjoner
--   plattform_redaktor  -> ingen
-- ---------------------------------------------------------------------
create or replace function public.mine_stasjoner()
returns setof uuid
language sql stable security definer set search_path = public
as $$
  select s.id
  from public.stasjoner s
  where (select public.gjeldende_rolle()) = 'retailer_admin'
    and s.retailer_id = (select public.gjeldende_retailer_id())
    and s.slettet_tid is null
  union
  select bs.stasjon_id
  from public.butikksjef_stasjoner bs
  where (select public.gjeldende_rolle()) in ('butikksjef', 'butikkbruker_tablet')
    and bs.profil_id = (select auth.uid())
$$;

grant execute on function public.mine_stasjoner() to authenticated;


-- ---------------------------------------------------------------------
-- 2b) rutiner + rutine_utforinger - vekk fra per-rad-funksjonskall
-- rutine_utforinger har ingen retailer_id, saa det finnes ikke noe billig
-- ledende predikat; IN-subqueryen er derfor det som faktisk avgjor planen.
-- ---------------------------------------------------------------------
drop policy if exists rutiner_les on public.rutiner;
create policy rutiner_les on public.rutiner for select to authenticated
  using (slettet_tid is null and stasjon_id in (select public.mine_stasjoner()));

drop policy if exists rutiner_skriv on public.rutiner;
drop policy if exists rutiner_ins on public.rutiner;
drop policy if exists rutiner_upd on public.rutiner;
drop policy if exists rutiner_del on public.rutiner;

create policy rutiner_ins on public.rutiner for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy rutiner_upd on public.rutiner for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy rutiner_del on public.rutiner for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

drop policy if exists rutine_utforinger_les on public.rutine_utforinger;
create policy rutine_utforinger_les on public.rutine_utforinger for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists rutine_utforinger_skriv on public.rutine_utforinger;
drop policy if exists rutine_utforinger_ins on public.rutine_utforinger;
drop policy if exists rutine_utforinger_upd on public.rutine_utforinger;
drop policy if exists rutine_utforinger_del on public.rutine_utforinger;

create policy rutine_utforinger_ins on public.rutine_utforinger for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));

create policy rutine_utforinger_upd on public.rutine_utforinger for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));

create policy rutine_utforinger_del on public.rutine_utforinger for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

-- Indekser for spoerringene appen faktisk gjor:
--   butikksjef-dashbord.tsx: count paa .eq('dato', idag)  -> dato ledende
--   rutiner/page.tsx:        .in('dato', datoer)          -> dato ledende
--   rutinestat.ts:           .eq('stasjon_id', ...)       -> stasjon ledende
-- Uten disse blir alt seq scan over hele tabellen paa tvers av tenanter.
create index if not exists rutine_utforinger_dato_idx
  on public.rutine_utforinger (dato);
create index if not exists rutine_utforinger_stasjon_dato_idx
  on public.rutine_utforinger (stasjon_id, dato);


-- ---------------------------------------------------------------------
-- 3) malekort / malekort_scope (0073 kom etter 0067, men brukte gammelt
--    monster). Tabellene er sma, men "for all" gjelder ogsa SELECT og
--    skygger for lesepolicyen, saa de ryddes med samme snitt.
-- ---------------------------------------------------------------------
drop policy if exists malekort_admin on public.malekort;
drop policy if exists malekort_ins on public.malekort;
drop policy if exists malekort_upd on public.malekort;
drop policy if exists malekort_del on public.malekort;

create policy malekort_ins on public.malekort for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy malekort_upd on public.malekort for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy malekort_del on public.malekort for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

-- Merk: admin leser malekort via malekort_les. Den filtrerer slettet_tid,
-- slik den gjorde for alle andre roller ogsa for denne migrasjonen.
drop policy if exists malekort_les on public.malekort;
create policy malekort_les on public.malekort for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()) and slettet_tid is null);

drop policy if exists malekort_scope_admin on public.malekort_scope;
drop policy if exists malekort_scope_ins on public.malekort_scope;
drop policy if exists malekort_scope_upd on public.malekort_scope;
drop policy if exists malekort_scope_del on public.malekort_scope;

create policy malekort_scope_ins on public.malekort_scope for insert to authenticated
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy malekort_scope_upd on public.malekort_scope for update to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()))
  with check ((select public.gjeldende_rolle()) = 'retailer_admin'
              and retailer_id = (select public.gjeldende_retailer_id()));

create policy malekort_scope_del on public.malekort_scope for delete to authenticated
  using ((select public.gjeldende_rolle()) = 'retailer_admin'
         and retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists malekort_scope_les on public.malekort_scope;
create policy malekort_scope_les on public.malekort_scope for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()));


-- ---------------------------------------------------------------------
-- 4) avvik: 0076 stengte butikkbruker_tablet ute fra WITH CHECK, slik at
-- IK-mat-avvik fra tableten ble avvist av RLS. Vi splitter policyen:
-- innsetting krever stasjonstilgang (tablet skal kunne REGISTRERE avvik),
-- mens endring og sletting fortsatt krever retailer_admin/butikksjef -
-- som var hele poenget med 0076.
-- ---------------------------------------------------------------------
drop policy if exists avvik_skriv on public.avvik;
drop policy if exists avvik_ins on public.avvik;
drop policy if exists avvik_upd on public.avvik;
drop policy if exists avvik_del on public.avvik;

create policy avvik_ins on public.avvik for insert to authenticated
  with check (public.har_stasjonstilgang(stasjon_id));

create policy avvik_upd on public.avvik for update to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id)
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy avvik_del on public.avvik for delete to authenticated
  using (public.har_stasjonstilgang(stasjon_id)
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));


-- ---------------------------------------------------------------------
-- 5) Aggregering i databasen for svinnvinduet.
-- /svinn hentet raa transaksjonsrader for et 30-dagersvindu og summerte i
-- JS. PostgREST kapper stille paa 1000 rader, saa svinn% ble regnet paa en
-- vilkaarlig delmengde og stasjoner fikk gronn status feilaktig.
-- security invoker => RLS paa synlig_svinn / daglig_salg gjelder som for.
-- ---------------------------------------------------------------------
create or replace function public.svinn_vindu_sum(p_fra date, p_til date)
returns table(stasjon_id uuid, svinn_kr numeric)
language sql
security invoker
set search_path = public
as $$
  select stasjon_id, coalesce(sum(nettopris_total), 0)
  from public.synlig_svinn
  where dato between p_fra and p_til
    and slettet_tid is null
  group by stasjon_id
$$;

grant execute on function public.svinn_vindu_sum(date, date) to authenticated;

create or replace function public.matsalg_vindu_sum(p_fra date, p_til date)
returns table(stasjon_id uuid, mat_omsetning numeric)
language sql
security invoker
set search_path = public
as $$
  select stasjon_id, coalesce(sum(mat_omsetning), 0)
  from public.v_salg_per_stasjon_dag
  where dato between p_fra and p_til
  group by stasjon_id
$$;

grant execute on function public.matsalg_vindu_sum(date, date) to authenticated;


-- =====================================================================
-- KREVER MANUELL VURDERING:
--
-- A) src/app/(beskyttet)/svinn/page.tsx:63-64 maa faktisk BYTTE til de nye
--    RPC-ene, ellers er 1000-rad-trunkeringen fortsatt der:
--      supabase.rpc('svinn_vindu_sum',   { p_fra: start, p_til: slutt })
--      supabase.rpc('matsalg_vindu_sum', { p_fra: start, p_til: slutt })
--    Merk at svinn_vindu_sum filtrerer slettet_tid is null, mens dagens
--    sporring paa linje 63 ikke gjor det. Tallene vil derfor endre seg litt
--    (til det riktige) om det finnes soft-slettede svinnrader - verifiser
--    mot faktiske data for utrulling. Linje 51-56 (dagens raa rader, brukt
--    til topp-varer) er fortsatt upaginert og maa enten pagineres etter
--    hentAlt-monsteret i src/lib/backtest.ts:40 eller deles i aggregat +
--    egen topp-10-sporring med .limit().
--
-- B) src/app/(beskyttet)/ikmat/handlinger.ts:86 sjekker ikke error fra
--    insert mot avvik og returnerer ubetinget { ok: true }. Policyfiksen
--    over apner flyten igjen, men feilsvelgingen bestaar og vil skjule
--    neste feil paa samme maate. Destrukturer { error } og returner
--    { feil: ... }. Kan ikke fikses i SQL.
--
-- C) src/app/(beskyttet)/ikmat/handlinger.ts:85 beregner lopenr med count()
--    uten laas eller unikhets-constraint. To samtidige avvik paa samme
--    stasjon kan faa samme lopenr. Fiks krever enten en sekvens per stasjon
--    eller en unique-indeks (retailer_id, stasjon_id, lopenr) - sistnevnte
--    kan feile paa eksisterende data (dagens default er 0 for alle rader),
--    saa den maa ryddes manuelt for den kan legges paa.
--
-- D) rutine_utforinger mangler retailer_id. Med kolonnen (backfilt fra
--    rutiner) kunne policyen filtrere paa tenant forst, slik 0067-monsteret
--    forutsetter, og tabellen kunne faa (retailer_id, dato)-indeks. Det er
--    en datamigrering (add column + backfill + not null + trigger/patch i
--    src/app/(beskyttet)/rutiner/handlinger.ts), ikke tatt med her.
--
-- E) v_varehierarki og v_varer (0073:79-96) gjor "select distinct" over hele
--    daglig_salg uten retailer-/datoavgrensning. Selv med ryddede policyer
--    er det full skann av en ~400k-rads partisjonert tabell ved hvert sok i
--    scope-velgeren. Riktig fiks er en materialisert varekatalog-tabell
--    (eller minst en dato-avgrensning + stottende indeks) - krever
--    designbeslutning og indeksbygg paa full tabell.
--
-- F) De gamle _skriv-policyene manglet "slettet_tid is null", og fordi de
--    var "for all" ga de retailer_admin lesetilgang til soft-slettede rader
--    i daglig_salg, timesalg, kassererstatistikk, synlig_svinn og
--    regnskapslinjer. Etter denne migrasjonen leser admin kun via _les, som
--    filtrerer slettet_tid. Det er den tiltenkte oppforselen, men det kan
--    endre tall i admin-visninger som (utilsiktet) inkluderte slettede
--    rader. Verifiser mot data for utrulling.
--
-- G) Kontroller etter kjoring at ingen tabell star igjen med en policy som
--    kaller hjelpefunksjonene upakket:
--      select schemaname, tablename, policyname, cmd, qual, with_check
--      from pg_policies
--      where schemaname = 'public'
--        and (qual like '%gjeldende_%' or with_check like '%gjeldende_%')
--        and qual not like '%( SELECT%';
--    Denne migrasjonen dekker de store/varme tabellene, ikke alle 76.
-- =====================================================================