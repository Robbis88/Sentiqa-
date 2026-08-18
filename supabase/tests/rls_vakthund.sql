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
    -- Oppsett for bemanningsplanleggeren (0081). Faa rader, men de
    -- joines mot timesalg per time - en upakket policy her trekker
    -- per-rad-kall inn i hver eneste planberegning.
    'bemanning_vindu', 'bemanning_krav', 'bemanning_fast_vakt',
    'bemanning_budsjett', 'bemanning_aar', 'bemanning_maned',
    'bemanning_stasjon',
    -- Stemplinger (0088). Vokser med drift: ~130 rader per stasjon per
    -- maaned, og leses per time mot timesalg naar plan males mot faktisk.
    'stempling',
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
    'personlig_kryss', 'puls_svar', 'varsler',
    'import_jobber', 'raa_filer', 'fakturaer', 'ai_tool_log',
    'opplaering_periode', 'opplaring_fullfort', 'pengepremie_bruk',
    'tilbakemelding', 'regnskapsanalyser', 'lederstotte_rapporter'
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
    -- Eldre opplaeringstabeller (annen skrivemaate enn opplaering_*).
    'opplaring_personer', 'opplaring_punkter'
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
    raise warning 'PER-RAD-KALL  %.% (%) - pakk i (select ...) eller bruk mine_stasjoner()',
      r.tablename, r.policyname, r.cmd;
    feil := feil + 1;
  end loop;

  -- --- 2) "for all"-policyer paa varme tabeller ---
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public' and tablename = any(varme) and cmd = 'ALL'
    order by tablename, policyname
  loop
    raise warning 'FOR ALL  %.% - USING gjelder ogsaa SELECT; splitt i insert/update/delete',
      r.tablename, r.policyname;
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
    raise warning 'PROFILER SKRIVBAR  authenticated har % - rolle/tenant kan PATCHes via PostgREST',
      r.privilege_type;
    feil := feil + 1;
  end loop;

  -- profiler maa fortsatt kunne LESES, ellers brekker innlogging (dal.ts)
  if not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'profiler'
      and grantee = 'authenticated' and privilege_type = 'SELECT')
  then
    raise warning 'PROFILER ULESELIG  authenticated mangler SELECT - innlogging vil brekke';
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
    raise warning 'UTEN TILSYN  %  - har policy, men staar hverken i varme eller kalde i rls_vakthund.sql',
      r.tablename;
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
    raise warning 'STAAR I LISTA, FINNES IKKE  %  - ingen policy i public; fjern den fra rls_vakthund.sql',
      r.tablename;
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
    raise warning 'PARTISJON AAPEN  % (av %) - % kan leses direkte, forbi forelderens RLS; revoke all fra anon+authenticated',
      r.relname, r.forelder,
      case when r.anon_leser then 'anon' else 'authenticated' end;
    feil := feil + 1;
  end loop;

  if feil > 0 then
    raise exception 'RLS-vakthund: % funn. Se advarslene over.', feil;
  end if;

  raise notice '--- RLS-vakthund: ingen funn. % varme, % kalde, alle tabeller med policy er dekket ---',
    array_length(varme, 1), array_length(kalde, 1);
end $$;
