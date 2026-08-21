-- =====================================================================
-- Sentiqa - beviser at pin_hash er lukket, og at verifiseringen virker
-- =====================================================================
--
-- Kjores i CI etter migrasjonene. Kaster exception ved funn.
--
-- HVORFOR DETTE ER EN SQL-TEST OG IKKE EN NETTLESERTEST: de tre
-- approllene - butikkbruker_tablet, butikksjef, retailer_admin - er
-- SAMME Postgres-rolle, `authenticated`. Rollene skilles av RLS og av
-- `gjeldende_rolle()`, ikke av rettigheter. Ett kolonneprivilegium
-- gjelder derfor alle tre, og aa maale det per approlle i en nettleser
-- ville vaert aa maale det samme tre ganger og tro man maalte tre ting.
--
-- ALT LIGGER I EN `do`-BLOKK MED VILJE. `supabase db query --file`
-- sender fila som EN prepared statement, og flere setninger gir
-- «cannot insert multiple commands into a prepared statement». Derfor er
-- det heller ingen `begin`/`rollback` her: testdataene ryddes ved at en
-- indre blokk kaster en sentinel-exception, som ruller tilbake
-- underslaget sitt. PL/pgSQL-variabler overlever den rullingen -
-- det er slik funnene naar ut.
-- =====================================================================
do $$
declare
  feil     int := 0;
  r        record;
  n        int;
  i        int;
  h        text;
  RETAILER constant uuid := 'dddddddd-0000-4000-8000-000000000001';
  NABO     constant uuid := 'dddddddd-0000-4000-8000-000000000002';
  TABLET   constant uuid := '00000000-0000-4000-8000-0000000000f1';
  ANSATT   constant uuid := 'dddddddd-2222-4000-8000-000000000001';
begin

  -- -------------------------------------------------------------------
  -- KANARIFUGL FOERST. Maaler vi paa noe som ikke finnes, er alle
  -- svarene under trivielt gronne.
  -- -------------------------------------------------------------------
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ansatte'
      and column_name = 'pin_hash')
  then
    raise exception 'BLIND TEST: ansatte.pin_hash finnes ikke - er 0025 kjort?';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'verifiser_ansatt_pin')
  then
    raise exception 'BLIND TEST: verifiser_ansatt_pin finnes ikke - er 0112 kjort?';
  end if;

  -- -------------------------------------------------------------------
  -- DEL 1: rettighetene
  -- -------------------------------------------------------------------

  -- 1a) Hemmeligheten er ikke lesbar. Dekker tablet, butikksjef OG eier.
  if has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'SELECT') then
    raise warning 'authenticated har SELECT paa ansatte.pin_hash';
    feil := feil + 1;
  end if;
  if has_column_privilege('anon', 'public.ansatte', 'pin_hash', 'SELECT') then
    raise warning 'anon har SELECT paa ansatte.pin_hash';
    feil := feil + 1;
  end if;

  -- 1b) Hemmeligheten kan ikke SKRIVES over direkte.
  if has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'UPDATE') then
    raise warning 'authenticated har UPDATE paa ansatte.pin_hash - en PIN kan settes utenom produktet';
    feil := feil + 1;
  end if;

  -- 1c) ... men den kan settes ved OPPRETTELSE. Uten dette virker ikke
  --     `leggTilAnsatt`, og kolonnen er `not null`.
  if not has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'INSERT') then
    raise warning 'authenticated mangler INSERT paa ansatte.pin_hash - nye ansatte kan ikke opprettes';
    feil := feil + 1;
  end if;

  -- 1d) Kolonnene produktet faktisk trenger, er fortsatt lesbare og
  --     skrivbare. Uten denne kunne man «bestaa» ved aa stenge alt.
  if not (has_column_privilege('authenticated', 'public.ansatte', 'navn', 'SELECT')
      and has_column_privilege('authenticated', 'public.ansatte', 'ansatt_nr', 'SELECT')
      and has_column_privilege('authenticated', 'public.ansatte', 'stasjon_id', 'SELECT')) then
    raise warning 'authenticated mangler SELECT paa kolonner produktet bruker';
    feil := feil + 1;
  end if;
  if not (has_column_privilege('authenticated', 'public.ansatte', 'ansatt_nr', 'UPDATE')
      and has_column_privilege('authenticated', 'public.ansatte', 'aktiv', 'UPDATE')) then
    raise warning 'authenticated mangler UPDATE paa ansatt_nr/aktiv - settAnsattnummer og deaktivering brekker';
    feil := feil + 1;
  end if;

  -- 1e) Funksjonen kan ikke kalles av alle. Supabase deler ut EXECUTE
  --     paa nye funksjoner til anon/authenticated/service_role gjennom
  --     default privileges - NAVNGITT, ikke gjennom PUBLIC. En revoke
  --     fra PUBLIC alene roerer dem ikke.
  if has_function_privilege('anon', 'public.verifiser_ansatt_pin(text,text,text)', 'EXECUTE') then
    raise warning 'anon kan kalle verifiser_ansatt_pin';
    feil := feil + 1;
  end if;
  if not has_function_privilege('authenticated', 'public.verifiser_ansatt_pin(text,text,text)', 'EXECUTE') then
    raise warning 'authenticated kan IKKE kalle verifiser_ansatt_pin - innlogging vil brekke';
    feil := feil + 1;
  end if;

  -- 1f) Ingen kan skrive i sikkerhetsloggen selv. Kunne en klient sette
  --     inn rader her, kunne den skrive seg ut av sin egen pause.
  if has_table_privilege('authenticated', 'public.pin_forsok', 'INSERT')
     or has_table_privilege('authenticated', 'public.pin_forsok', 'UPDATE')
     or has_table_privilege('authenticated', 'public.pin_forsok', 'DELETE') then
    raise warning 'authenticated kan skrive i pin_forsok - pausen kan omgaas';
    feil := feil + 1;
  end if;

  -- -------------------------------------------------------------------
  -- DEL 2: oppfoerselen. Egen blokk, saa testdataene rulles tilbake.
  -- -------------------------------------------------------------------
  begin
    insert into auth.users (id, email) values
      (TABLET, 'pin-tablet@test.local')
    on conflict (id) do nothing;

    insert into public.retailers (id, navn) values
      (RETAILER, 'PIN-kjeden'), (NABO, 'Nabokjeden');

    insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
      (TABLET, RETAILER, 'butikkbruker_tablet', 'Nettbrett');

    insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
      ('dddddddd-1111-4000-8000-000000000001', RETAILER, '0001', 'PIN-butikken', 'pendler'),
      ('dddddddd-1111-4000-8000-000000000002', NABO,     '0001', 'Nabobutikken', 'pendler');

    insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
      (TABLET, 'dddddddd-1111-4000-8000-000000000001');

    -- Hashen er vilkaarlig her: funksjonen sammenligner strenger, den
    -- regner ikke ut noe. Det er nettopp derfor PIN-en aldri naar basen.
    insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash, ansatt_nr) values
      (ANSATT, RETAILER, 'dddddddd-1111-4000-8000-000000000001', 'Pia PIN', 'HASH-RIKTIG', '5001'),
      ('dddddddd-2222-4000-8000-000000000002', NABO, 'dddddddd-1111-4000-8000-000000000002',
       'Nils Nabo', 'HASH-NABO', '5001');

    -- Utgi seg for nettbrettet, slik en ekte foresporsel ser ut.
    perform set_config('request.jwt.claims', json_build_object('sub', TABLET)::text, true);

    -- 2a) Riktig nummer + riktig hash.
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-RIKTIG', 'vakt');
    if r.status <> 'ok' or r.ansatt_id <> ANSATT then
      raise warning 'riktig nummer + riktig PIN ga % (%)', r.status, r.ansatt_id;
      feil := feil + 1;
    end if;

    -- 2b) Feil hash.
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-FEIL', 'vakt');
    if r.status <> 'avvist' or r.ansatt_id is not null then
      raise warning 'feil PIN ga % (%)', r.status, r.ansatt_id;
      feil := feil + 1;
    end if;

    -- 2c) Ukjent nummer skal gi NOEYAKTIG samme svar som feil PIN. To
    --     ulike svar ville latt hvem som helst kartlegge hvilke numre
    --     som finnes.
    select * into r from public.verifiser_ansatt_pin('999999', 'HASH-RIKTIG', 'vakt');
    if r.status <> 'avvist' or r.ansatt_id is not null then
      raise warning 'ukjent nummer ga % - skiller seg fra feil PIN', r.status;
      feil := feil + 1;
    end if;

    -- 2d) TENANT. Nabokjedens ansatt har samme nummer og en hash vi
    --     kjenner. Funksjonen er security definer og gaar forbi RLS, saa
    --     gjerdet maa staa inne i den - dette er beviset paa at det gjor det.
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-NABO', 'vakt');
    if r.status = 'ok' then
      raise warning 'TENANTBRUDD: verifiserte en ansatt i en annen kjede';
      feil := feil + 1;
    end if;

    -- 2e) RATE LIMITING. Telleren staar paa to (2b og 2d gjaldt 5001).
    for i in 1..4 loop
      perform public.verifiser_ansatt_pin('5001', 'HASH-FEIL', 'vakt');
    end loop;

    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-RIKTIG', 'vakt');
    if r.status <> 'sperret' then
      raise warning 'RATE LIMIT VIRKER IKKE: forsoek nr 6 ga % - orakelet staar aapent', r.status;
      feil := feil + 1;
    end if;
    if r.vent_sekunder <= 0 or r.vent_sekunder > 900 then
      raise warning 'ventetid utenfor vinduet: % sekunder', r.vent_sekunder;
      feil := feil + 1;
    end if;

    -- 2f) Pausen gjelder SELV MED RIKTIG PIN. Ellers ville den ikke
    --     bremset gjetting, bare de mislykkede forsoekene.
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-RIKTIG', 'vakt');
    if r.status <> 'sperret' then
      raise warning 'pausen kan omgaas med riktig PIN: %', r.status;
      feil := feil + 1;
    end if;

    -- 2g) REVISJON. Hvert forsoek skal staa der, ogsaa de blokkerte.
    select count(*) into n from public.pin_forsok where retailer_id = RETAILER;
    if n < 9 then
      raise warning 'revisjonssporet mangler rader: % funnet', n;
      feil := feil + 1;
    end if;

    select count(*) into n from public.pin_forsok where retailer_id = RETAILER and ok;
    if n <> 1 then
      raise warning 'antall vellykkede forsoek i sporet er % - ventet 1', n;
      feil := feil + 1;
    end if;

    select count(*) into n from public.pin_forsok where retailer_id = RETAILER and blokkert;
    if n < 2 then
      raise warning 'blokkerte forsoek er ikke logget: %', n;
      feil := feil + 1;
    end if;

    -- 2h) INGEN HEMMELIGHETER I SPORET. Den viktigste av alle: en
    --     sikkerhetslogg som lagrer det den skal beskytte, er verre enn
    --     ingen logg.
    select count(*) into n from public.pin_forsok
    where retailer_id = RETAILER and coalesce(ansatt_nr, '') like '%HASH%';
    if n > 0 then
      raise warning 'HASH I LOGGEN: % rader baerer noe som ligner en hemmelighet', n;
      feil := feil + 1;
    end if;

    -- 2i) Og det direkte forsoeket: kan `authenticated` i det hele tatt
    --     lese kolonnen? Alt over gaar gjennom funksjonen; dette gaar
    --     rett paa tabellen, slik PostgREST ville gjort det.
    begin
      set local role authenticated;
      select pin_hash into h from public.ansatte limit 1;
      raise warning 'HULLET ER AAPENT: authenticated leste pin_hash direkte';
      feil := feil + 1;
    exception
      when insufficient_privilege then
        null;  -- forventet
    end;
    reset role;

    -- Sentinel: ruller tilbake alt testdataet over. Feilene er allerede
    -- talt opp i `feil`, og den variabelen overlever rullingen.
    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  if feil > 0 then
    raise exception 'pin_hash: % funn. Se advarslene over.', feil;
  end if;
  raise notice '--- pin_hash: rettigheter, verifisering, rate limiting, tenant og revisjon i orden ---';
end $$;
