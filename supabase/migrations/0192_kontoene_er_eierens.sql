-- =====================================================================
-- 0192 - KONTOENE ER EIERENS, OGSAA I RLS
--
-- `src/lib/regnskap-tilgang.ts` har siden den ble skrevet sagt at
-- butikksjefen ser kostnadene hen selv kan paavirke, og at royalty,
-- franchiseavgift, husleie, finans, avskrivninger og selve
-- RESULTAT-linja er eierens. Regelen haandheves tre steder i appen:
-- /regnskap, AI-konteksten og auto-fokus.
--
-- Men den har aldri vaert haandhevet i RLS. `regnskapslinjer_les`
-- (0067) gir butikksjefen HVER rad for stasjonene sine, og appfilteret
-- er en visningsregel. **En visningsregel er ikke en grense.** Den
-- samme innloggede brukeren kan lese royaltylinja rett over PostgREST
-- med sin egen sesjon - `.from('regnskapslinjer').select('*')` i en
-- konsoll er nok.
--
-- Det er noeyaktig samme form som `malekort.vis_tablet` foer `0134`: et
-- flagg som bodde i spoerringen i staden for i policyen. AGENTS.md sier
-- det rett ut - «et flagg i en kolonne er ikke en grense foer RLS leser
-- det».
--
-- ---------------------------------------------------------------------
-- HVORFOR SVARTELISTE PAA SEKSJON OG HVITLISTE PAA KODE
--
-- Predikatet lar hver seksjon UNNTATT `driftskostnader` og `resultat`
-- vaere i fred, og hvitlister kodene inne i `driftskostnader`.
--
-- Det er ikke slurv - det er en avveining mellom to maater aa ta feil:
--
--   En hvitliste over SEKSJONER ville faatt en ny seksjon til aa
--   forsvinne i stillhet for butikksjefen. En side som blir tom uten
--   feilmelding er den dyreste formen dette huset har - `0065` og
--   fail-closed-`v_butikksalg` er begge den historien.
--
--   En hvitliste over KODER inne i `driftskostnader` er derimot trygg,
--   fordi der er kontoplanen lukket og kjent (`KONTO_NAVN` i
--   `src/lib/parsere/regnskap.ts`). Det er ogsaa der de foelsomme
--   kontoene faktisk ligger.
--
-- Visningsfilteret i appen er fortsatt en HVITLISTE og feiler dermed
-- lukket. De to lagene feiler hver sin vei med vilje: visningen viser
-- aldri for mye, tilgangen tar aldri bort for mye.
--
-- ---------------------------------------------------------------------
-- LOENNSKOSTEN
--
-- `hentLonnskost` leser HELE `driftskostnader` for stasjonen og
-- filtrerer i TypeScript. De ni kontoene den bygger paa - 501, 502,
-- 503, 505, 508, 509, 540, 541, 590 - staar alle i hvitlista under, og
-- overlever derfor. `supabase/tests/regnskap_butikksjef_probe.sql`
-- beviser det mot ekte data foer denne kjores, og
-- `src/lib/regnskap/kodegrense.test.ts` binder lista her til
-- `BUTIKKSJEF_KOSTNAD_KODER` saa de to ikke kan skille lag.
--
-- Kjor sonden FOERST. Viser den at en av de ni ligger i en annen
-- seksjon enn `driftskostnader`, skal ikke denne kjores.
--
-- Idempotent: `drop policy if exists` + `create policy`.
-- =====================================================================

drop policy if exists regnskapslinjer_les on public.regnskapslinjer;
create policy regnskapslinjer_les on public.regnskapslinjer for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or (
        stasjon_id is not null
        -- `har_stasjonstilgang(stasjon_id)` kan aldri bli initplan - den
        -- tar en kolonne som argument. Underspoerringen her er den samme
        -- som 0067 brukte, og evalueres én gang.
        and stasjon_id in (
          select bs.stasjon_id from public.butikksjef_stasjoner bs
          where bs.profil_id = (select auth.uid())
        )
        -- KONTOENE ER EIERENS.
        and seksjon <> 'resultat'
        and (
          seksjon <> 'driftskostnader'
          or kode in (
            -- Personalkostnad (BUTIKKSJEF_PERSONAL_KODER)
            '501', '502', '503', '505', '508', '509', '540', '541', '590',
            -- Paavirkbare driftskostnader (BUTIKKSJEF_DRIFT_KODER)
            '627', '628', '629', '632', '633', '634', '636', '638', '746'
          )
        )
      )
    )
  );

comment on policy regnskapslinjer_les on public.regnskapslinjer is
  'Butikksjefen ser sine stasjoner, men ikke RESULTAT-linja og ikke de '
  'driftskostnadene hen ikke kan paavirke - royalty, franchiseavgift, '
  'husleie, finans, avskrivninger. Regelen sto i regnskap-tilgang.ts fra '
  'starten, men bare som visningsfilter; over PostgREST var hver rad '
  'lesbar. Kodelista speiler BUTIKKSJEF_KOSTNAD_KODER og er bundet til '
  'den av kodegrense.test.ts.';

-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som en rad.
-- `kodene` skal vaere 18. Er den noe annet, har innlimingen mistet noe.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'regnskapslinjer'
      and policyname = 'regnskapslinjer_les')                    as policy_finnes,
  (select count(*) from regexp_matches(
     (select qual from pg_policies
       where schemaname = 'public' and tablename = 'regnskapslinjer'
         and policyname = 'regnskapslinjer_les'),
     '''[0-9]{3}''::text', 'g'))                                 as kodene,
  (select (qual ~ 'resultat')::int from pg_policies
    where schemaname = 'public' and tablename = 'regnskapslinjer'
      and policyname = 'regnskapslinjer_les')                    as resultat_stengt;
