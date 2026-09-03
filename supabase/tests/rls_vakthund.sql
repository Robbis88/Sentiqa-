-- =====================================================================
-- Sentiqa - RLS-vakthund
-- Kjor denne etter HVER nye migrasjon som rorer policyer. Den tar ikke
-- stilling til om isolasjonen er riktig (det gjor rls_isolasjon.sql) -
-- den fanger de tre monstrene som allerede har gitt produksjonsfeil:
--
--  1) Hjelpefunksjoner kalt UTEN (select ...) -> evalueres per rad ->
--     statement timeout -> 0 rader returnert. Slo ut daglig_salg 2026-06-16,
--     og ble gjeninnfort av 0073 og 0076 etter at 0067 hadde fikset det.
--
--  2) "for all"-policyer paa store tabeller. USING i en FOR ALL-policy
--     gjelder OGSAA select, og permissive policyer OR-es sammen - saa en
--     upakket skrivepolicy trekkes inn i hver eneste leseplan og gjor
--     retailer_id ikke-sargbar. Det gjorde 0067 halvveis virkningslos.
--
--  3) Skrivetilgang til profiler for "authenticated". Rolle og tenant
--     ligger der; kan de PATCHes via PostgREST, er hele RLS-modellen ute
--     av spill (se 0078).
--
-- Kjores mot en base der alle migrasjoner er kjort. Leser kun katalogen -
-- ingen testdata, ingen opprydding, trygt i produksjon.
-- =====================================================================

-- ---------------------------------------------------------------------
-- ÉN SETNING. IKKE DEL DEN OPP.
--
-- CI kjorer denne fila med `supabase db query --local --file`, som
-- sender innholdet som ÉN prepared statement. To setninger gir
-- «cannot insert multiple commands into a prepared statement» og en
-- roed jobb som ikke handler om RLS i det hele tatt.
--
-- Jeg proevde aa gjore den om til temp-tabell + avsluttende `select`,
-- slik `rls_isolasjon.sql` ble i #56. Den fila er MANUELL og staar ikke
-- i CI - derfor gikk det bra der. Denne staar i CI, og forsoket kostet
-- to ting: en roed jobb, og naerved en vakt som alltid ville vaert
-- groenn, fordi `raise exception` var det ENESTE som fikk CI til aa
-- feile paa funn.
--
-- Trenger du funnene lesbare: de ligger i feilmeldingen, ikke i
-- warnings. SQL Editor viser meldingen.
-- ---------------------------------------------------------------------
do $$
declare
  -- Tabeller som vokser med drift. Nye transaksjonstabeller SKAL inn her.
  varme text[] := array[
    'daglig_salg', 'timesalg', 'kassererstatistikk', 'synlig_svinn',
    'regnskapslinjer', 'regnskap_usynlig_svinn', 'rutine_utforinger',
    'sjekkpunkt_svar', 'ik_avlesninger', 'ansatte', 'oppgaver',
    'tablet_meldinger', 'skills_score', 'tildelte_merker',
    'opplaering_skift', 'opplaering_utfort', 'avvik', 'malekort',
    'malekort_scope', 'rutiner',
    -- Innloggingsforsoek for vakt og stempling (0112). Vokser med hver
    -- eneste innsjekk, og leses av ledere i revisjonsoyemed.
    'pin_forsok',
    -- BP-en som eget dokument (0155). Faa rader per aar, men de leses av
    -- hver analysevisning og vokser med hver aargang og hver stasjon.
    'bp_aar', 'bp_linje',
    -- Ukebriefens utsendingslogg (0169). En rad per stasjon per uke per
    -- mottaker, saa den vokser med drift like sikkert som salget.
    'ukebrief_utsending',
    -- Semantisk kodemapping (0152). FAA RADER, MEN VARME: `v_butikksalg`
    -- joiner dem i HVER eneste salgsspoerring. En upakket funksjon i en
    -- policy her trekker per-rad-kall inn i alt som summerer kroner.
    'retailer_kodeerklaering', 'retailer_koderegel',
    -- Oppsett for bemanningsplanleggeren (0081). Faa rader, men de
    -- joines mot timesalg per time - en upakket policy her trekker
    -- per-rad-kall inn i hver eneste planberegning.
    'bemanning_vindu', 'bemanning_krav', 'bemanning_fast_vakt',
    'bemanning_budsjett', 'bemanning_aar', 'bemanning_maned',
    'bemanning_stasjon',
    -- Stemplinger (0088). Vokser med drift: ~130 rader per stasjon per
    -- maaned, og leses per time mot timesalg naar plan males mot faktisk.
    'stempling',
    -- Raa inn/ut-hendelser (0110). Varm fra dag en: to rader per ansatt
    -- per dag, og de leses hver gang en vakt avledes.
    'stempling_hendelse',
    -- Ansatte og fravaer (0089). Faa rader, men leses i hver planberegning.
    'ansatt_avtale', 'bemanning_fravaer',
    -- Leses paa hver forside for aa filtrere feeden (0083).
    'signal_lukket',
    -- Arbeidsavtaler (0098). Vokser med drift - en rad per generering,
    -- og signerte rader slettes aldri.
    'ansatt_kontrakt',
    -- Tilgangsloggen (0103). Vokser raskest av alle: en rad per oppslag
    -- paa persondata, og den kan aldri slettes.
    'persondata_logg',
    -- Soskentabellen fra samme migrasjon (0103), som ble glemt her.
    -- Den vokser saktere - en rad per ansatt per tekstversjon - men den
    -- leses paa HVER visning av /mine-opplysninger, og den ruta naas fra
    -- nettbrettet. En upakket policy her ville truffet hver ansatt som
    -- apnet sida, ikke bare en leder som saa paa en rapport.
    'kontrolltiltak_bekreftelse',

    -- --- Lagt inn av dekningssjekken (punkt 4) 2026-08-18. -----------
    -- Disse hadde policyer uten aa bli sjekket av noen. Alle vokser med
    -- drift; flere av dem leses i sider paa tusen rader.
    'produksjonsplan_hode', 'produksjonsplan_linjer',
    'prognose_treff', 'prognose_kalibrering',
    'vaer', 'trafikk', 'uke_rapport',
    'personlig_kryss', 'personlig_punkt', 'puls_svar', 'varsler',
    'import_jobber', 'raa_filer', 'ai_tool_log',
    'opplaering_periode', 'pengepremie_bruk',
    'tilbakemelding', 'regnskapsanalyser', 'lederstotte_rapporter'
    -- Her stod exchange_rates en kort stund. Ukjent opphav, ingen
    -- migrasjon lagde den, og den ble lagt i VARME med vilje - en tabell
    -- vi ikke kjenner skal sjekkes, ikke ignoreres. Den viste seg aa
    -- vaere tom og ubrukt, klikket inn i Supabase-dashbordet (policynavn
    -- med mellomrom), og er droppet i 0109.
  ];

  -- Tabeller som med vilje IKKE sjekkes: oppsett og oppslagsdata.
  -- Faa rader, endres sjelden, og joines ikke mot noe som vokser. Et
  -- per-rad-kall her koster ikke noe maalbart.
  --
  -- Lista finnes for at punkt 4 skal kunne kreve at HVER tabell med
  -- policy staar et sted. Da kan ingen ny tabell falle mellom stolene -
  -- den tvinger fram en beslutning, slik monstre.ts gjor for ruter.
  kalde text[] := array[
    -- Tenant og tilgang. profiler har sin egen sjekk i punkt 3.
    'retailers', 'stasjoner', 'profiler', 'butikksjef_stasjoner',
    -- Innhold kunden redigerer. En rad per element, lest som en liste.
    'anvisninger', 'kunnskap', 'merker', 'lenker', 'kampanjer',
    'konkurranser', 'plattform_innlegg', 'fokuspunkter', 'pengepremie',
    -- Oppsett bak funksjonene. Endres naar noe settes opp, ikke i drift.
    'kontraktmal', 'opplaering_oppgave', 'puls_sporsmal', 'puls_runde',
    'sjekkpunkter', 'rutineskjemaer', 'ik_kontrollpunkter',
    'kalender_kilder', 'arrangementer', 'kategori_vaerprofil',
    'push_abonnementer',
    -- Driftsregler for produksjonsplanen (0149). Skrives naar en stasjon
    -- setter start- eller marginprosent, ikke per transaksjon.
    'stasjon_produksjon_innstilling'
    -- Her stod opplaring_personer, opplaring_punkter og opplaring_fullfort
    -- (varme). Ingen av dem finnes i basen - de er erstattet av
    -- opplaering_*-tabellene og ble aldri opprettet. Sjekk 4b fanget det:
    -- en tabell i lista uten policy gir falsk trygghet om dekning.
  ];

  -- LAGRING. `storage.objects` er én tabell for alle bucketene, saa
  -- varme/kalde-modellen passer ikke: her er det POLICYEN som er
  -- enheten, ikke tabellen. Lista er fasit over hvem som skal ha en.
  --
  -- Tabellen vokser med drift - én rad per opplastet fil - saa de samme
  -- tre reglene gjelder som paa daglig_salg.
  lagring text[] := array[
    -- `fakturaer_storage_eier` staar med vilje IKKE her: 0106 droppet
    -- baade policyen og boetta. Lista skal speile basen, ikke historikken.
    'anvisninger_storage_les',
    'anvisninger_storage_skriv',
    'kontrakt_signert_ins',
    'kontrakt_signert_les',
    'kontraktmal_storage_les',
    'raa_filer_storage_admin',
    'rutinebilder_storage'
  ];

  -- `for all` PAA LAGRING SOM ER BESTEMT, IKKE GLEMT.
  --
  -- 0080 splittet de fleste storage-policyene og skrev ned hvorfor tre
  -- ble staaende. Uten denne lista ville vakthunden lyst roedt paa dem
  -- hver eneste kjoering - og en vakt som alltid er roed laerer folk aa
  -- ignorere roedt. Det er den samme grunnen `kalde` finnes.
  --
  -- Ingen av de tre har per-rad-kall: predikatene er pakket i (select ...)
  -- eller gaar via mine_stasjoner(). Det som staar igjen er at USING
  -- gjelder ogsaa SELECT - en klarhetskostnad, ikke et hull, siden hver
  -- policy sjekker bucket_id.
  --
  --   rutinebilder_storage  0080 punkt A: om en nettbrettbruker skal
  --                         kunne slette bildebevis for IK-mat er en
  --                         DRIFTSBESLUTNING, ikke en teknisk feil.
  --                         Tas naar noen bestemmer seg, ikke her.
  --   raa_filer_storage_admin
  --                         Kun retailer_admin, og eieren skal kunne
  --                         bade lese, laste opp og rydde. Splitting
  --                         ville gitt fire identiske policyer.
  --
  -- Legger du en ny bucket, skal den IKKE inn her uten en grunn skrevet
  -- ned paa samme maate.
  lagring_for_all_ok text[] := array[
    'raa_filer_storage_admin',
    'rutinebilder_storage'
  ];
  r record;
  feil int := 0;
  -- Funnene samles her og legges i selve feilmeldingen til slutt.
  funnliste text[] := array[]::text[];
begin

  -- --- 1) Upakkede hjelpefunksjonskall paa varme tabeller ---
  for r in
    select tablename, policyname, cmd
    from pg_policies
    where schemaname = 'public'
      and tablename = any(varme)
      -- Vurder USING og WITH CHECK hver for seg: en policy kan ha wrappet
      -- den ene og rå den andre, og da er den fortsatt per-rad på skriv.
      and (
        (coalesce(qual, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(qual, '') !~ '\( SELECT')
        or
        (coalesce(with_check, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(with_check, '') !~ '\( SELECT')
      )
    order by tablename, policyname
  loop
    funnliste := funnliste || format('PER-RAD-KALL  %s.%s (%s) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.tablename, r.policyname, r.cmd);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- --- 2) "for all"-policyer paa varme tabeller ---
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public' and tablename = any(varme) and cmd = 'ALL'
    order by tablename, policyname
  loop
    funnliste := funnliste || format('FOR ALL  %s.%s - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.tablename, r.policyname);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- --- 3) Skrivetilgang til profiler ---
  for r in
    select privilege_type
    from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  loop
    funnliste := funnliste || format('PROFILER SKRIVBAR  authenticated har %s - rolle/tenant kan PATCHes via PostgREST',
      r.privilege_type);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- profiler maa fortsatt kunne LESES, ellers brekker innlogging (dal.ts)
  if not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated' and privilege_type = 'SELECT')
  then
    funnliste := funnliste || format('PROFILER ULESELIG  authenticated mangler SELECT - innlogging vil brekke');
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end if;

  -- --- 4) Dekning: har noen tabell falt utenfor vakthunden? ---
  --
  -- Lagt til 2026-08-18, etter at kontrolltiltak_bekreftelse hadde ligget
  -- med policyer og uten tilsyn siden 0103. Sostertabellen fra samme
  -- migrasjon kom inn i varme; denne ble glemt, og ingen ting sa fra.
  --
  -- De tre sjekkene over kan bare finne feil paa tabeller noen har husket
  -- aa fore opp. Denne sjekker listene selv: hver tabell med policy skal
  -- staa i varme eller i kalde. Da er utelatelse ikke lenger mulig - en
  -- ny tabell TVINGER en beslutning om den vokser med drift eller ikke.
  for r in
    select distinct tablename
    from pg_policies
    where schemaname = 'public'
      and tablename <> all(varme)
      and tablename <> all(kalde)
    order by tablename
  loop
    funnliste := funnliste || format('UTEN TILSYN  %s  - har policy, men staar hverken i varme eller kalde i rls_vakthund.sql',
      r.tablename);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- Motsatt vei: en tabell som er fjernet fra basen, men staar igjen i
  -- listene, gir falsk trygghet om dekning. Billig aa fange her.
  for r in
    select t as tablename
    from unnest(varme || kalde) as t
    where not exists (
      select 1 from pg_policies p
      where p.schemaname = 'public' and p.tablename = t)
    order by t
  loop
    funnliste := funnliste || format('STAAR I LISTA, FINNES IKKE  %s  - ingen policy i public; fjern den fra rls_vakthund.sql',
      r.tablename);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- --- 5) Partisjoner uten eget vern ---
  --
  -- Lagt til 2026-08-18, etter at alle 49 partisjonene av daglig_salg
  -- viste seg lesbare for anon. Forelderen hadde RLS og riktige
  -- policyer; partisjonene arvet aldri vernet, og rettighetene kom av
  -- seg selv fra Supabase' default privileges.
  --
  -- De fire sjekkene over var blinde for det: en tabell UTEN RLS har
  -- ingen rader i pg_policies, og saa derfor ut som en tabell uten
  -- problemer. Sjekkene lette etter trege policyer og forutsatte at det
  -- fantes policyer aa vurdere.
  --
  -- Treg RLS feiler LUKKET - null rader. Manglende RLS feiler AAPENT.
  -- Vakthunden var bygget for den mildeste av de to feilene.
  for r in
    select c.relname, par.relname as forelder,
           has_table_privilege('anon', c.oid, 'SELECT') as anon_leser
    from pg_class c
    join pg_inherits i on i.inhrelid = c.oid
    join pg_class par on par.oid = i.inhparent
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relispartition
      and (has_table_privilege('anon', c.oid, 'SELECT')
           or has_table_privilege('authenticated', c.oid, 'SELECT'))
    order by c.relname
  loop
    funnliste := funnliste || format('PARTISJON AAPEN  %s (av %s) - %s kan leses direkte, forbi forelderens RLS; revoke all fra anon+authenticated',
      r.relname, r.forelder,
      case when r.anon_leser then 'anon' else 'authenticated' end);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- --- 6) Hemmelige kolonner: pin_hash ---
  --
  -- Lagt til 2026-08-21, etter at `pin_hash` viste seg lesbar for
  -- klientrollen. RLS gjorde jobben sin - `ansatte_les` (0078) gir
  -- nettbrettet radene paa egen stasjon. Men RLS avgjor RADER. Grants
  -- avgjor KOLONNER, og `grant select on public.ansatte` (0025) var paa
  -- TABELLNIVAA. Radgjerdet var riktig og kolonnegjerdet fantes ikke.
  --
  -- De fem sjekkene over var blinde for hele kategorien: de leser
  -- policyer og tabellrettigheter, aldri kolonnerettigheter.
  --
  -- DENNE MAALER DEN EKSAKTE MENGDEN, ikke bare fravaeret av pin_hash.
  -- Det er med vilje: da feller den BEGGE veier noen kan aapne hullet -
  -- `grant select (pin_hash)` og `grant select on ansatte` gir samme
  -- utslag, og en ny kolonne tvinger en beslutning i stedet for aa bli
  -- lesbar av seg selv slik `ansatt_nr` ble i 0110.
  declare
    forventet text[] := array[
      'id', 'retailer_id', 'stasjon_id', 'navn', 'ansatt_nr',
      'aktiv', 'opprettet_av', 'opprettet_tid', 'slettet_tid'
    ];
    faktisk text[];
  begin
    -- KANARIFUGL. Finnes hverken tabellen eller kolonnen, maaler
    -- sjekken ingenting - og en sjekk som ikke finner det den skal
    -- vurdere skal rope, ikke tie. Det er noyaktig feilen sjekk 4 ble
    -- laget for.
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'ansatte'
        and column_name = 'pin_hash')
    then
      funnliste := funnliste || format('KOLONNEVAKT BLIND  ansatte.pin_hash finnes ikke - maaler sjekken riktig tabell?');
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    select coalesce(array_agg(column_name::text order by column_name), array[]::text[])
      into faktisk
    from information_schema.column_privileges
    where table_schema = 'public' and table_name = 'ansatte'
      and grantee = 'authenticated' and privilege_type = 'SELECT';

    if faktisk @> array['pin_hash'] then
      funnliste := funnliste || format('HEMMELIGHET LESBAR  authenticated har SELECT paa ansatte.pin_hash - hashene kan hentes og knekkes offline');
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    if not (faktisk <@ forventet and forventet <@ faktisk) then
      funnliste := funnliste || format('KOLONNERETTER ENDRET  ansatte/authenticated SELECT er %s - forventet %s; ta stilling til hver nye kolonne',
        faktisk, forventet);
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    -- Skrivetilgangen paa hemmeligheten. UPDATE ble fjernet i 0112 fordi
    -- ingen kode bruker den; INSERT staar, fordi lederen som oppretter en
    -- ansatt skal sette den foerste PIN-en.
    if exists (
      select 1 from information_schema.column_privileges
      where table_schema = 'public' and table_name = 'ansatte'
        and grantee = 'authenticated' and column_name = 'pin_hash'
        and privilege_type = 'UPDATE')
    then
      funnliste := funnliste || format('HEMMELIGHET SKRIVBAR  authenticated har UPDATE paa ansatte.pin_hash - en PIN kan settes direkte via PostgREST, utenom produktet');
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;
  end;

  -- --- 7) Sikkerhetsfunksjonen: hvem kan kalle den ---
  --
  -- `verifiser_ansatt_pin` er security definer og ser hashen. Blir
  -- EXECUTE bredere enn `authenticated`, er den et orakel for flere enn
  -- de innloggede - og `revoke from public` er lett aa glemme, fordi en
  -- funksjon arver EXECUTE til PUBLIC av seg selv.
  declare
    kallere text[];
  begin
    -- KANARIFUGL: funksjonen maa finnes for at sjekken skal bety noe.
    if not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'verifiser_ansatt_pin')
    then
      funnliste := funnliste || format('FUNKSJONSVAKT BLIND  public.verifiser_ansatt_pin finnes ikke - er 0112 kjort?');
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    select coalesce(array_agg(distinct grantee::text order by grantee::text), array[]::text[])
      into kallere
    from information_schema.role_routine_grants
    where specific_schema = 'public' and routine_name = 'verifiser_ansatt_pin'
      and privilege_type = 'EXECUTE'
      and grantee <> 'postgres';

    if kallere <> array['authenticated'] then
      funnliste := funnliste || format('FUNKSJON FOR AAPEN  verifiser_ansatt_pin kan kalles av %s - forventet kun authenticated', kallere);
    raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;
  end;

  -- --- 8) storage.objects ---
  --
  -- Lagt til 2026-08-24. HVER ENESTE SJEKK OVER ER SCOPET TIL
  -- `schemaname = 'public'` - ogsaa dekningssjekken i punkt 4, den som
  -- skulle gjoere utelatelse umulig. `storage.objects` ligger i skjemaet
  -- `storage`, og har derfor aldri blitt sett paa av noen av dem.
  --
  -- Det er den samme feilen som punkt 4 og 5 ble skrevet for: en flate
  -- som faller utenfor ser noeyaktig ut som en flate uten problemer.
  -- Vakthunden meldte «alle tabeller med policy er dekket», og det var
  -- sant - for public.
  --
  -- Da denne ble skrevet laa det tre `for all`-policyer der, og én av
  -- dem med upakkede hjelpefunksjonskall. Filene vokser med drift.

  -- KANARIFUGL FOERST. Finnes det ingen policyer, er de tre sjekkene
  -- under tomme loekker - og en tom loekke er groenn. Da maaler
  -- vakthunden ingenting og ser ut som om alt er i orden.
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects') then
    funnliste := funnliste || format('LAGRINGSVAKT BLIND  ingen policyer paa storage.objects - enten er ingen migrasjon kjort, eller saa er vernet borte');
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end if;

  -- a) Upakkede hjelpefunksjonskall. Samme regel som punkt 1.
  for r in
    select policyname, cmd
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (
        (coalesce(qual, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(qual, '') !~ '\( SELECT')
        or
        (coalesce(with_check, '') ~ '(gjeldende_rolle|gjeldende_retailer_id|har_stasjonstilgang|auth\.uid)'
         and coalesce(with_check, '') !~ '\( SELECT')
      )
    order by policyname
  loop
    funnliste := funnliste || format('PER-RAD-KALL  storage.objects.%s (%s) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.policyname, r.cmd);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- b) `for all`. Samme regel som punkt 2: USING gjelder ogsaa SELECT,
  --    og permissive policyer OR-es sammen paa tvers av bucketer.
  --    De tre i `lagring_for_all_ok` er bestemt, ikke glemt.
  for r in
    select policyname
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd = 'ALL'
      and policyname <> all(lagring_for_all_ok)
    order by policyname
  loop
    funnliste := funnliste || format('FOR ALL  storage.objects.%s - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.policyname);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- e) UNNTAKET SKAL IKKE OVERLEVE GRUNNEN SIN. Blir en av de tre
  --    splittet senere, staar den igjen som et unntak som dekker over
  --    noe som ikke lenger finnes - og neste `for all` paa samme navn
  --    ville sluppet gjennom i stillhet.
  for r in
    select t as policyname
    from unnest(lagring_for_all_ok) as t
    where not exists (
      select 1 from pg_policies p
      where p.schemaname = 'storage' and p.tablename = 'objects'
        and p.policyname = t and p.cmd = 'ALL')
    order by t
  loop
    funnliste := funnliste || format('UNNTAK UTEN GRUNN  storage.objects.%s  - staar i lagring_for_all_ok, men er ikke lenger `for all`; fjern den derfra',
      r.policyname);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- c) Dekning. En ny bucket uten en beslutning her er nettopp det
  --    punkt 4 finnes for aa hindre.
  for r in
    select policyname
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname <> all(lagring)
    order by policyname
  loop
    funnliste := funnliste || format('UTEN TILSYN  storage.objects.%s  - policy uten oppfoering i `lagring` i rls_vakthund.sql',
      r.policyname);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- d) Motsatt vei: staar i lista, finnes ikke.
  for r in
    select t as policyname
    from unnest(lagring) as t
    where not exists (
      select 1 from pg_policies p
      where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = t)
    order by t
  loop
    funnliste := funnliste || format('STAAR I LISTA, FINNES IKKE  storage.objects.%s  - fjern den fra `lagring`, eller kjor migrasjonen som lager den',
      r.policyname);
    raise warning '%', funnliste[array_length(funnliste, 1)];
    feil := feil + 1;
  end loop;

  -- --- 9) Views: invoker paa, anon av ---
  --
  -- Lagt til 2026-08-24, etter at view_invoker_sonde.sql viste at alle
  -- 21 views i public hadde SELECT for `anon`. Ingen skrev det - det kom
  -- fra Supabase-standarden
  --     alter default privileges in schema public
  --       grant all on tables to anon, authenticated, service_role
  -- altsaa den samme mekanismen som ga partisjonene rettigheter i 0105.
  --
  -- DE ATTE SJEKKENE OVER ER BLINDE FOR VIEWS. De leser pg_policies, og
  -- en view har ingen policyer. En view er likevel en leseflate med
  -- eget grant - og med `security_invoker` AV leser den som eieren,
  -- forbi RLS, forbi retailer_id, forbi stasjonstildeling.
  --
  -- `create or replace view` UTEN `with (security_invoker = true)`
  -- nullstiller flagget i stillhet. Diffen ser ufarlig ut.
  declare
    antall_views int;
  begin
    select count(*) into antall_views
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('v', 'm');

    -- KANARIFUGL. Finner sjekken ingen views, maaler den ingenting - og
    -- de to loekkene under ville da vaert stille uansett hvor galt det
    -- sto til. Det er den samme feilen som punkt 4 og 5 ble laget for:
    -- en flate som faller utenfor ser ut som en flate uten problemer.
    if antall_views = 0 then
      funnliste := funnliste || 'VIEWVAKT BLIND  ingen views funnet i public - maaler sjekken riktig skjema?';
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    -- a) Uten security_invoker leser viewet som EIEREN.
    for r in
      select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('v', 'm')
        and coalesce(
              (select option_value from pg_options_to_table(c.reloptions)
               where option_name = 'security_invoker'), 'off') not in ('on', 'true')
      order by c.relname
    loop
      funnliste := funnliste || format('DEFINER-VIEW  public.%s  - mangler `with (security_invoker = true)` og leser forbi RLS. En `create or replace view` uten klausulen nullstiller flagget i stillhet.',
        r.relname);
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end loop;

    -- b) anon er rollen bak den offentlige noekkelen i hver sidelast.
    --    Ingen forretningsview skal vaere lesbar for den.
    for r in
      select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('v', 'm')
        and has_table_privilege('anon', c.oid, 'select')
      order by c.relname
    loop
      funnliste := funnliste || format('ANON KAN LESE  public.%s  - `revoke all on public.%s from anon` (se 0130). Grantet kommer av seg selv fra default privileges.',
        r.relname, r.relname);
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end loop;
  end;

  -- --- 10) Tabeller: anon av ---
  --
  -- Lagt til 2026-08-25, etter at postgrest_sonde.mjs sonderte 103
  -- ressurser som anon over ekte HTTPS og fant:
  --
  --     sperret 26  |  tomt 77  |  LEKKASJE 0
  --
  -- Ingen lekkasje - men 77 tabeller svarte `200 []`. Granten fantes,
  -- RLS returnerte ingenting. Ett lag.
  --
  -- PUNKT 9 ER BLINDT FOR TABELLER, av samme grunn som de aatte foer
  -- den er blinde for views: den spor `relkind in ('v','m')`. En tabell
  -- med anon-grant falt mellom punkt 9 og resten.
  --
  -- 0134 tok grantene. Denne vakten er det som gjor det til noe annet
  -- enn en opprydding: default privileges gir grantet paa nytt til hver
  -- NY tabell, og til hver ny partisjon (0105).
  declare
    antall_tabeller int;
  begin
    select count(*) into antall_tabeller
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p');

    -- KANARIFUGL. Samme grunn som i punkt 9: en sjekk som ikke finner
    -- noen tabeller ser noyaktig ut som en base uten problemer.
    if antall_tabeller = 0 then
      funnliste := funnliste || 'TABELLVAKT BLIND  ingen tabeller funnet i public - maaler sjekken riktig skjema?';
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;

    for r in
      select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relkind in ('r', 'p')
        and has_table_privilege('anon', c.oid, 'select')
      order by c.relname
    loop
      funnliste := funnliste || format('ANON KAN LESE  public.%s  - `revoke all on public.%s from anon` (se 0134). Grantet kommer av seg selv fra default privileges, ogsaa til nye partisjoner.',
        r.relname, r.relname);
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end loop;
  end;

  -- --- 11) with check: kjeden maa bindes i HVER arm av et or ---
  --
  -- Lagt til 2026-08-26, etter 0141.
  --
  -- De aatte forekomstene foer den manglet `retailer_id` i `with check`.
  -- `uke_rapport` NEVNTE den - bindingen sto bare i feil arm:
  --
  --   with check (
  --     (rolle = 'retailer_admin' and retailer_id = min kjede)  -- bundet
  --     or stasjon_id in (mine_stasjoner())                     -- fri
  --   )
  --
  -- Andre arm godtar hva som helst i retailer_id saa lenge stasjonen er
  -- min, og raden kan flyttes til en annen kjede med stasjonen i behold.
  -- AA NEVNE KOLONNEN ER IKKE AA BINDE DEN - og derfor sto uke_rapport
  -- aldri i kandidater_with_check.sql, som leter etter FRAVAER.
  --
  -- Regelen: har uttrykket mer enn en arm paa oeverste niva, maa HVER
  -- arm nevne retailer_id. Ellers finnes det en vei gjennom som ikke
  -- binder kjeden.
  --
  -- KUN `with check`. I `using` er en fri stasjonsarm riktig: en rad hvis
  -- stasjon er min, er per definisjon min kjedes - naar den ikke lenger
  -- kan flyttes.
  --
  -- Teksten kommer fra pg_get_expr, altsaa fra katalogen og ikke fra
  -- migrasjonsfila. Splittingen teller parenteser og bryr seg ikke om
  -- strengliteraler; en policy med « OR » inne i en literal ville lurt
  -- den, og det finnes ingen slik i dag.
  declare
    t             text;
    d             int;
    i             int;
    c             text;
    arm           text;
    fri           boolean;
    antall_armer  int;
    balansert     boolean;
    sett          int := 0;
  begin
    for r in
      -- KANARIFUGLEN GAAR GJENNOM SAMME KODE SOM ALT ANNET.
      -- Den er uke_rapport slik den sto foer 0141, normalisert slik
      -- pg_get_expr ville skrevet den. Slutter splitteren aa se en fri
      -- arm, faller den her - ikke i stillhet et halvt aar senere.
      select p.tablename, p.policyname, p.with_check, false as er_kanari
      from pg_policies p
      where p.schemaname = 'public'
        and p.with_check is not null
        and exists (
          select 1 from information_schema.columns col
          where col.table_schema = 'public'
            and col.table_name = p.tablename
            and col.column_name = 'retailer_id')
      union all
      select '(kanarifugl)', 'fri_arm_skal_ses',
             '(((( SELECT gjeldende_rolle()) = ''retailer_admin''::text) AND'
             || ' (retailer_id = ( SELECT gjeldende_retailer_id()))) OR'
             || ' (stasjon_id IN ( SELECT mine_stasjoner())))',
             true
      order by 1, 2
    loop
      sett := sett + 1;
      t := btrim(r.with_check);

      -- Skrell ytre parenteser, men bare naar den foerste lukkes helt til slutt.
      loop
        exit when left(t, 1) <> '(' or right(t, 1) <> ')';
        d := 0;
        balansert := true;
        for i in 1..length(t) loop
          c := substr(t, i, 1);
          if c = '(' then
            d := d + 1;
          elsif c = ')' then
            d := d - 1;
            if d = 0 and i < length(t) then
              balansert := false;
              exit;
            end if;
          end if;
        end loop;
        exit when not balansert;
        t := btrim(substr(t, 2, length(t) - 2));
      end loop;

      -- Del paa OR i dybde 0.
      d := 0;
      arm := '';
      fri := false;
      antall_armer := 1;
      i := 1;
      while i <= length(t) loop
        c := substr(t, i, 1);
        if c = '(' then
          d := d + 1;
        elsif c = ')' then
          d := d - 1;
        end if;
        if d = 0 and upper(substr(t, i, 4)) = ' OR ' then
          antall_armer := antall_armer + 1;
          if position('retailer_id' in arm) = 0 then fri := true; end if;
          arm := '';
          i := i + 4;
          continue;
        end if;
        arm := arm || c;
        i := i + 1;
      end loop;
      if position('retailer_id' in arm) = 0 then fri := true; end if;

      if r.er_kanari then
        if not (antall_armer > 1 and fri) then
          funnliste := funnliste || 'ARMVAKT BLIND  kanarifuglen ble ikke sett - splitteren i punkt 11 maaler ikke lenger noe';
          raise warning '%', funnliste[array_length(funnliste, 1)];
          feil := feil + 1;
        end if;
      elsif antall_armer > 1 and fri then
        funnliste := funnliste || format('FRI ARM I WITH CHECK  public.%s / %s - en av %s armene nevner ikke retailer_id, saa raden kan flyttes til en annen kjede med stasjonen i behold (se 0141)',
          r.tablename, r.policyname, antall_armer);
        raise warning '%', funnliste[array_length(funnliste, 1)];
        feil := feil + 1;
      end if;
    end loop;

    -- Kanarifuglen alene teller ogsaa: ser sjekken bare den, leser den
    -- ingen ekte policyer, og da maaler den ingenting.
    if sett < 2 then
      funnliste := funnliste || 'ARMVAKT BLIND  ingen policy med with check paa en tabell med retailer_id - maaler sjekken riktig skjema?';
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;
  end;

  -- --- 12) Myk sletting maa faktisk kunne gjennomfoeres ---
  --
  -- Funnet 2026-08-29, gjennom et skjermbilde: "Kunne ikke slette
  -- malekort [42501]: new row violates row-level security policy".
  --
  -- En SELECT-policy som krever `slettet_tid IS NULL` blokkerer sin egen
  -- soft delete. Setter en UPDATE `slettet_tid`, faller den nye raden ut
  -- av policyen - og Postgres nekter en oppdatering som gjoer raden
  -- usynlig for den som skriver. Bevist ved eksperiment: samme UPDATE
  -- gikk gjennom straks en midlertidig policy lot eieren se slettede
  -- rader.
  --
  -- Ingen har kunnet slette et malekort siden 0073. Feilen sier
  -- "tilgang", saa den ser ut som en rettighetssak - og rollen var
  -- riktig hele tiden.
  --
  -- HVORFOR MATRISEN IKKE FANGET DET: den tester `update` med
  -- `oppdaterbart`-feltet, som setter et VANLIG felt. Den har aldri
  -- forsokt aa sette `slettet_tid`. Vakten maalte at eieren kan skrive,
  -- ikke at eieren kan slette.
  --
  -- REGELEN: `slettet_tid` er ikke et sikkerhetsvilkaar. En slettet rad i
  -- din egen kjede er din egen rad i en annen tilstand, ikke andres data.
  -- RLS haandhever TENANT; spoerringene haandhever LIVSSYKLUS - og
  -- 62 av 80 lesninger gjorde det allerede da regelen ble skrevet.
  --
  -- Salgstabellene staar UTENFOR med vilje: de myk-slettes bare av
  -- importen, som kjoerer som service_role og omgaar RLS. Der virker
  -- slettingen alt, og aa eksponere slettede salgsrader er en tallrisiko.
  declare
    myk_slettbare text[] := array[
      'malekort', 'ansatte', 'rutiner', 'rutineskjemaer', 'oppgaver',
      'sjekkpunkter', 'konkurranser', 'merker', 'lenker', 'kunnskap',
      'anvisninger', 'arrangementer', 'kalender_kilder', 'ik_kontrollpunkter',
      'puls_runde', 'puls_sporsmal', 'opplaering_oppgave', 'plattform_innlegg',
      'tablet_meldinger', 'personlig_punkt'
    ];
    t text;
    sett int := 0;
  begin
    foreach t in array myk_slettbare loop
      -- Finnes tabellen i det hele tatt? En som er dopt om ville ellers
      -- passert i stillhet.
      if not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                     where n.nspname = 'public' and c.relname = t) then
        funnliste := funnliste || format(
          'MYK SLETT UKJENT  %s staar i lista, men finnes ikke - dopt om eller fjernet?', t);
        raise warning '%', funnliste[array_length(funnliste, 1)];
        feil := feil + 1;
        continue;
      end if;

      sett := sett + 1;

      if exists (
        select 1 from pg_policy pol
        join pg_class c on c.oid = pol.polrelid
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = t
          and pol.polcmd::text in ('r', '*')
          and pg_get_expr(pol.polqual, pol.polrelid) like '%slettet_tid IS NULL%'
      ) then
        funnliste := funnliste || format(
          'MYK SLETT BLOKKERT  %s: SELECT-policyen krever slettet_tid IS NULL, '
          || 'saa en UPDATE som SETTER den avvises med 42501. Sletteknappen er doed. '
          || 'Filtrer i spoerringen i stedet.', t);
        raise warning '%', funnliste[array_length(funnliste, 1)];
        feil := feil + 1;
      end if;
    end loop;

    -- KANARIFUGL. Ser loekka ingen tabeller, melder den heller ingen
    -- funn - og en vakt som slutter aa se ser noeyaktig ut som en vakt
    -- som ikke finner noe.
    if sett = 0 then
      funnliste := funnliste || 'MYK SLETT BLIND  ingen av de myk-slettbare tabellene ble sett';
      raise warning '%', funnliste[array_length(funnliste, 1)];
      feil := feil + 1;
    end if;
  end;

  -- FUNNENE HOERER HJEMME I FEILMELDINGEN.
  --
  -- Foer sto det bare «RLS-vakthund: 2 funn. Se advarslene over» - og
  -- SQL Editor viser ikke warnings, saa det fantes ingen advarsler aa se.
  -- Man fikk vite AT noe var galt, og ingenting mer.
  --
  -- Meldingen vises alltid. Derfor staar hele lista i den.
  if feil > 0 then
    raise exception '%',
      format('RLS-vakthund: %s funn%s%s', feil, chr(10) || chr(10),
             array_to_string(funnliste, chr(10)));
  end if;

  raise notice '--- RLS-vakthund: ingen funn. % varme, % kalde, % lagringspolicyer, % views, % tabeller uten anon-grant, alle tabeller med policy er dekket ---',
    array_length(varme, 1), array_length(kalde, 1), array_length(lagring, 1),
    (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('v', 'm')),
    (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p'));
end $$;
