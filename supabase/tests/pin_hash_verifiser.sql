-- =====================================================================
-- Verifiser pin_hash-porten MOT DEN FAKTISKE DATABASEN
-- =====================================================================
--
-- Lim inn i Supabase SQL Editor og kjor. Returnerer en TABELL.
--
-- HVORFOR EN TABELL OG IKKE `raise warning`: SQL Editor viser ikke
-- warnings. Det er samme grunn til at `rls_funn.sql` finnes ved siden av
-- `rls_vakthund.sql` - vakthunden feller CI, den lesbare utgaven er den
-- man faktisk ser noe i. Denne er den lesbare utgaven av
-- `pin_hash_lukket.sql`.
--
-- TRYGG I PRODUKSJON. Rettighetssjekkene leser bare katalogen.
-- Oppfoerselssjekkene lager sin egen syntetiske kjede i en indre blokk
-- som RULLES TILBAKE - ingen ekte ansatt roeres, ingen laases ute.
-- Funnene overlever rullingen fordi de ligger i variabler, ikke i rader.
-- =====================================================================

create temp table if not exists pin_sjekk (
  nr int, sjekk text, forventet text, faktisk text, dom text
);
truncate pin_sjekk;

do $$
declare
  RETAILER constant uuid := 'dddddddd-0000-4000-8000-000000000001';
  NABO     constant uuid := 'dddddddd-0000-4000-8000-000000000002';
  TABLET   constant uuid := '00000000-0000-4000-8000-0000000000f1';
  ANSATT   constant uuid := 'dddddddd-2222-4000-8000-000000000001';
  kolonner text;
  kallere  text;
  r        record;
  i        int;
  -- Oppfoerselen samles i variabler, saa den overlever rullingen.
  v_ok        text := 'kjorte ikke';
  v_feilpin   text := 'kjorte ikke';
  v_ukjent    text := 'kjorte ikke';
  v_tenant    text := 'kjorte ikke';
  v_sperret   text := 'kjorte ikke';
  v_vent      text := 'kjorte ikke';
  v_gammel    text := 'kjorte ikke';
  v_fersk     text := 'kjorte ikke';
  v_logget    text := 'kjorte ikke';
  v_blokkert  text := 'kjorte ikke';
  v_direkte   text := 'kjorte ikke';
begin

  -- --- 1) HEMMELIGHETEN ----------------------------------------------
  insert into pin_sjekk values (1, 'authenticated SELECT paa pin_hash', 'nei',
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'SELECT')
         then 'JA' else 'nei' end,
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'SELECT')
         -- Fram til steg 3 staar det midlertidige grantet som reddet
         -- produksjonen. Det er ventet HER, og bare her.
         then 'MIDLERTIDIG - fjernes i steg 3' else 'OK' end);

  insert into pin_sjekk values (2, 'anon SELECT paa pin_hash', 'nei',
    case when has_column_privilege('anon', 'public.ansatte', 'pin_hash', 'SELECT')
         then 'JA' else 'nei' end,
    case when has_column_privilege('anon', 'public.ansatte', 'pin_hash', 'SELECT')
         then 'FUNN' else 'OK' end);

  insert into pin_sjekk values (3, 'authenticated UPDATE paa pin_hash', 'nei',
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'UPDATE')
         then 'JA' else 'nei' end,
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'UPDATE')
         then 'FUNN' else 'OK' end);

  insert into pin_sjekk values (4, 'authenticated INSERT paa pin_hash (trengs)', 'ja',
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'INSERT')
         then 'ja' else 'NEI' end,
    case when has_column_privilege('authenticated', 'public.ansatte', 'pin_hash', 'INSERT')
         then 'OK' else 'FUNN - nye ansatte kan ikke opprettes' end);

  -- --- 2) KOLONNEGRANTS ----------------------------------------------
  select coalesce(string_agg(column_name::text, ', ' order by column_name), '(ingen)')
    into kolonner
  from information_schema.column_privileges
  where table_schema = 'public' and table_name = 'ansatte'
    and grantee = 'authenticated' and privilege_type = 'SELECT';

  insert into pin_sjekk values (5, 'SELECT-kolonner paa ansatte',
    'aktiv, ansatt_nr, id, navn, opprettet_av, opprettet_tid, retailer_id, slettet_tid, stasjon_id',
    kolonner,
    case when kolonner like '%pin_hash%' then 'MIDLERTIDIG - hemmeligheten er med'
         else 'OK' end);

  select coalesce(string_agg(column_name::text, ', ' order by column_name), '(ingen)')
    into kolonner
  from information_schema.column_privileges
  where table_schema = 'public' and table_name = 'ansatte'
    and grantee = 'authenticated' and privilege_type = 'UPDATE';

  insert into pin_sjekk values (6, 'UPDATE-kolonner paa ansatte',
    'aktiv, ansatt_nr, navn, slettet_tid, stasjon_id', kolonner,
    case when kolonner like '%pin_hash%' then 'FUNN - hemmeligheten er skrivbar'
         else 'OK' end);

  -- --- 3) FUNKSJONEN --------------------------------------------------
  select coalesce(string_agg(distinct grantee::text, ', ' order by grantee::text), '(ingen)')
    into kallere
  from information_schema.role_routine_grants
  where specific_schema = 'public' and routine_name = 'verifiser_ansatt_pin'
    and privilege_type = 'EXECUTE' and grantee <> 'postgres';

  insert into pin_sjekk values (7, 'Hvem kan EXECUTE verifiser_ansatt_pin', 'authenticated',
    kallere, case when kallere = 'authenticated' then 'OK' else 'FUNN' end);

  insert into pin_sjekk values (8, 'anon kan kalle funksjonen', 'nei',
    case when has_function_privilege('anon', 'public.verifiser_ansatt_pin(text,text,text)', 'EXECUTE')
         then 'JA' else 'nei' end,
    case when has_function_privilege('anon', 'public.verifiser_ansatt_pin(text,text,text)', 'EXECUTE')
         then 'FUNN' else 'OK' end);

  -- --- 4) SIKKERHETSLOGGEN -------------------------------------------
  insert into pin_sjekk values (9, 'pin_forsok finnes', 'ja',
    case when to_regclass('public.pin_forsok') is null then 'NEI' else 'ja' end,
    case when to_regclass('public.pin_forsok') is null then 'FUNN' else 'OK' end);

  insert into pin_sjekk values (10, 'authenticated kan skrive i pin_forsok', 'nei',
    case when has_table_privilege('authenticated', 'public.pin_forsok', 'INSERT')
           or has_table_privilege('authenticated', 'public.pin_forsok', 'UPDATE')
           or has_table_privilege('authenticated', 'public.pin_forsok', 'DELETE')
         then 'JA' else 'nei' end,
    case when has_table_privilege('authenticated', 'public.pin_forsok', 'INSERT')
           or has_table_privilege('authenticated', 'public.pin_forsok', 'UPDATE')
           or has_table_privilege('authenticated', 'public.pin_forsok', 'DELETE')
         then 'FUNN - pausen kan omgaas' else 'OK' end);

  -- --- 5) OPPFOERSELEN, i en blokk som rulles tilbake -----------------
  begin
    insert into auth.users (id, email) values (TABLET, 'pin-verifiser@test.local')
      on conflict (id) do nothing;
    insert into public.retailers (id, navn) values
      (RETAILER, 'Verifiser-kjeden'), (NABO, 'Verifiser-nabo');
    insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
      (TABLET, RETAILER, 'butikkbruker_tablet', 'Nettbrett');
    insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
      ('dddddddd-1111-4000-8000-000000000001', RETAILER, '0001', 'V-butikk', 'pendler'),
      ('dddddddd-1111-4000-8000-000000000002', NABO,     '0001', 'V-nabo',   'pendler');
    insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
      (TABLET, 'dddddddd-1111-4000-8000-000000000001');
    insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash, ansatt_nr) values
      (ANSATT, RETAILER, 'dddddddd-1111-4000-8000-000000000001', 'Pia', 'HASH-RIKTIG', '5001'),
      ('dddddddd-2222-4000-8000-000000000002', NABO,
       'dddddddd-1111-4000-8000-000000000002', 'Nils', 'HASH-NABO', '5001');

    perform set_config('request.jwt.claims', json_build_object('sub', TABLET)::text, true);

    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-RIKTIG', 'vakt');
    v_ok := r.status;
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-FEIL', 'vakt');
    v_feilpin := r.status;
    select * into r from public.verifiser_ansatt_pin('999999', 'HASH-RIKTIG', 'vakt');
    v_ukjent := r.status;
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-NABO', 'vakt');
    v_tenant := r.status;

    -- Terskelen: telleren staar paa to, fire til gir fem.
    for i in 1..4 loop
      perform public.verifiser_ansatt_pin('5001', 'HASH-FEIL', 'vakt');
    end loop;
    select * into r from public.verifiser_ansatt_pin('5001', 'HASH-RIKTIG', 'vakt');
    v_sperret := r.status;
    v_vent := r.vent_sekunder::text;

    -- Cooldownen utloeper. To numre, like mange feil, ulik alder.
    insert into public.pin_forsok
      (retailer_id, ansatt_nr, bruker_id, kilde, ok, blokkert, opprettet_tid)
    select RETAILER, '5009', TABLET, 'vakt', false, false,
           clock_timestamp() - interval '20 minutes' from generate_series(1, 5);
    insert into public.pin_forsok
      (retailer_id, ansatt_nr, bruker_id, kilde, ok, blokkert, opprettet_tid)
    select RETAILER, '5010', TABLET, 'vakt', false, false,
           clock_timestamp() from generate_series(1, 5);

    select * into r from public.verifiser_ansatt_pin('5009', 'HASH-FEIL', 'vakt');
    v_gammel := r.status;
    select * into r from public.verifiser_ansatt_pin('5010', 'HASH-FEIL', 'vakt');
    v_fersk := r.status;

    select count(*)::text into v_logget
    from public.pin_forsok where retailer_id = RETAILER and not ok and not blokkert;
    select count(*)::text into v_blokkert
    from public.pin_forsok where retailer_id = RETAILER and blokkert;

    -- Og det direkte forsoeket, slik PostgREST ville gjort det.
    begin
      set local role authenticated;
      perform pin_hash from public.ansatte limit 1;
      v_direkte := 'LESTE HASHEN';
    exception
      when insufficient_privilege then v_direkte := 'nektet';
    end;
    reset role;

    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  insert into pin_sjekk values (11, 'riktig nummer + riktig PIN', 'ok', v_ok,
    case when v_ok = 'ok' then 'OK' else 'FUNN' end);
  insert into pin_sjekk values (12, 'feil PIN', 'avvist', v_feilpin,
    case when v_feilpin = 'avvist' then 'OK' else 'FUNN' end);
  insert into pin_sjekk values (13, 'ukjent nummer (samme svar som feil PIN)', 'avvist', v_ukjent,
    case when v_ukjent = v_feilpin then 'OK' else 'FUNN - svarene skiller seg' end);
  insert into pin_sjekk values (14, 'ansatt i annen kjede', 'avvist/sperret', v_tenant,
    case when v_tenant <> 'ok' then 'OK' else 'FUNN - TENANTBRUDD' end);
  insert into pin_sjekk values (15, 'sjette forsoek innenfor vinduet', 'sperret', v_sperret,
    case when v_sperret = 'sperret' then 'OK' else 'FUNN - rate limit fyrer ikke' end);
  insert into pin_sjekk values (16, 'ventetid (sekunder, maks 900)', '1-900', v_vent,
    case when v_vent ~ '^\d+$' and v_vent::int between 1 and 900 then 'OK' else 'FUNN' end);
  insert into pin_sjekk values (17, 'fem feil, 20 min gamle', 'avvist', v_gammel,
    case when v_gammel = 'avvist' then 'OK' else 'FUNN - cooldown slipper ikke' end);
  insert into pin_sjekk values (18, 'fem feil, ferske (kontrast)', 'sperret', v_fersk,
    case when v_fersk = 'sperret' then 'OK' else 'FUNN - vinduet maaler ingenting' end);
  insert into pin_sjekk values (19, 'feilede forsoek logget', '>= 6', v_logget,
    case when v_logget ~ '^\d+$' and v_logget::int >= 6 then 'OK' else 'FUNN' end);
  insert into pin_sjekk values (20, 'blokkerte forsoek logget', '>= 2', v_blokkert,
    case when v_blokkert ~ '^\d+$' and v_blokkert::int >= 2 then 'OK' else 'FUNN' end);
  insert into pin_sjekk values (21, 'direkte SELECT av pin_hash som authenticated', 'nektet', v_direkte,
    case when v_direkte = 'nektet' then 'OK'
         -- Fram til steg 3 er dette ventet: det midlertidige grantet staar.
         else 'MIDLERTIDIG - fjernes i steg 3' end);
end $$;

select nr, sjekk, forventet, faktisk, dom
from pin_sjekk
order by case dom when 'FUNN' then 1 when 'MIDLERTIDIG - fjernes i steg 3' then 2 else 3 end, nr;
