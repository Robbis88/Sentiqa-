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
-- SVARET SKAL VAERE EN TABELL, IKKE ET TALL.
--
-- Fila brukte `raise warning` for hvert funn og `raise exception` med
-- antallet til slutt. SQL Editor viser ikke notices - saa den som
-- kjorte fikk «RLS-vakthund: 2 funn» og ingen mulighet til aa se HVILKE.
-- Og kastet den, forsvant transaksjonen og med den enhver sjanse til aa
-- lese noe som helst.
--
-- Noeyaktig samme feil som `rls_isolasjon.sql` hadde, rettet i #56.
-- Funnene samles naa i en temp-tabell, og siste setning i fila er et
-- `select` som lister dem. Feil foerst.
--
-- Grantet trengs fordi tabellen opprettes som rollen fila startes med,
-- mens innsettingen skjer inne i DO-blokka.
-- ---------------------------------------------------------------------
drop table if exists vakthund_funn;
create temp table vakthund_funn (nr int, funn text);
grant all on vakthund_funn to public;

create or replace function pg_temp.funn(p_tekst text) returns void
language plpgsql as $f$
begin
  insert into vakthund_funn (nr, funn)
    select coalesce(max(nr), 0) + 1, p_tekst from vakthund_funn;
  -- Beholdes: i psql og CI er en warning fortsatt det raskeste signalet.
  -- (Denne ene skal IKKE gaa via pg_temp.funn - det ville vaert rekursjon.)
  raise warning '%', p_tekst;
end $f$;

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
    'push_abonnementer'
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
    perform pg_temp.funn(format('PER-RAD-KALL  %s.%s (%s) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.tablename, r.policyname, r.cmd));
    feil := feil + 1;
  end loop;

  -- --- 2) "for all"-policyer paa varme tabeller ---
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public' and tablename = any(varme) and cmd = 'ALL'
    order by tablename, policyname
  loop
    perform pg_temp.funn(format('FOR ALL  %s.%s - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.tablename, r.policyname));
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
    perform pg_temp.funn(format('PROFILER SKRIVBAR  authenticated har %s - rolle/tenant kan PATCHes via PostgREST',
      r.privilege_type));
    feil := feil + 1;
  end loop;

  -- profiler maa fortsatt kunne LESES, ellers brekker innlogging (dal.ts)
  if not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated' and privilege_type = 'SELECT')
  then
    perform pg_temp.funn(format('PROFILER ULESELIG  authenticated mangler SELECT - innlogging vil brekke'));
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
    perform pg_temp.funn(format('UTEN TILSYN  %s  - har policy, men staar hverken i varme eller kalde i rls_vakthund.sql',
      r.tablename));
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
    perform pg_temp.funn(format('STAAR I LISTA, FINNES IKKE  %s  - ingen policy i public; fjern den fra rls_vakthund.sql',
      r.tablename));
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
    perform pg_temp.funn(format('PARTISJON AAPEN  %s (av %s) - %s kan leses direkte, forbi forelderens RLS; revoke all fra anon+authenticated',
      r.relname, r.forelder,
      case when r.anon_leser then 'anon' else 'authenticated' end));
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
      perform pg_temp.funn(format('KOLONNEVAKT BLIND  ansatte.pin_hash finnes ikke - maaler sjekken riktig tabell?'));
      feil := feil + 1;
    end if;

    select coalesce(array_agg(column_name::text order by column_name), array[]::text[])
      into faktisk
    from information_schema.column_privileges
    where table_schema = 'public' and table_name = 'ansatte'
      and grantee = 'authenticated' and privilege_type = 'SELECT';

    if faktisk @> array['pin_hash'] then
      perform pg_temp.funn(format('HEMMELIGHET LESBAR  authenticated har SELECT paa ansatte.pin_hash - hashene kan hentes og knekkes offline'));
      feil := feil + 1;
    end if;

    if not (faktisk <@ forventet and forventet <@ faktisk) then
      perform pg_temp.funn(format('KOLONNERETTER ENDRET  ansatte/authenticated SELECT er %s - forventet %s; ta stilling til hver nye kolonne',
        faktisk, forventet));
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
      perform pg_temp.funn(format('HEMMELIGHET SKRIVBAR  authenticated har UPDATE paa ansatte.pin_hash - en PIN kan settes direkte via PostgREST, utenom produktet'));
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
      perform pg_temp.funn(format('FUNKSJONSVAKT BLIND  public.verifiser_ansatt_pin finnes ikke - er 0112 kjort?'));
      feil := feil + 1;
    end if;

    select coalesce(array_agg(distinct grantee::text order by grantee::text), array[]::text[])
      into kallere
    from information_schema.role_routine_grants
    where specific_schema = 'public' and routine_name = 'verifiser_ansatt_pin'
      and privilege_type = 'EXECUTE'
      and grantee <> 'postgres';

    if kallere <> array['authenticated'] then
      perform pg_temp.funn(format('FUNKSJON FOR AAPEN  verifiser_ansatt_pin kan kalles av %s - forventet kun authenticated', kallere));
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
    perform pg_temp.funn(format('LAGRINGSVAKT BLIND  ingen policyer paa storage.objects - enten er ingen migrasjon kjort, eller saa er vernet borte'));
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
    perform pg_temp.funn(format('PER-RAD-KALL  storage.objects.%s (%s) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.policyname, r.cmd));
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
    perform pg_temp.funn(format('FOR ALL  storage.objects.%s - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.policyname));
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
    perform pg_temp.funn(format('UNNTAK UTEN GRUNN  storage.objects.%s  - staar i lagring_for_all_ok, men er ikke lenger `for all`; fjern den derfra',
      r.policyname));
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
    perform pg_temp.funn(format('UTEN TILSYN  storage.objects.%s  - policy uten oppfoering i `lagring` i rls_vakthund.sql',
      r.policyname));
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
    perform pg_temp.funn(format('STAAR I LISTA, FINNES IKKE  storage.objects.%s  - fjern den fra `lagring`, eller kjor migrasjonen som lager den',
      r.policyname));
    feil := feil + 1;
  end loop;

  -- Nr 0 sorterer foerst, saa «ok» staar oeverst naar det ikke er noe aa melde.
  if feil = 0 then
    insert into vakthund_funn (nr, funn)
      values (0, format('%s varme, %s kalde, %s lagringspolicyer - alle tabeller med policy er dekket',
        array_length(varme, 1), array_length(kalde, 1), array_length(lagring, 1)));
  end if;
end $$;

-- SVARET. Siste setning som gir rader, saa SQL Editor viser den.
--
-- Feil foerst: staar det «FUNN» oeverst, er det de radene som betyr noe.
-- Er alt «ok», SER man det - i stedet for aa slutte seg til det av at
-- ingenting skjedde.
select
  case when nr = 0 then 'ok' else 'FUNN' end as status,
  funn                                       as beskrivelse
from vakthund_funn
order by nr;
