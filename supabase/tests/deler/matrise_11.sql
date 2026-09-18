-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 11 AV 11. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 6 ressurs(er):
-- egen fasitverden, egne forutsetninger, egen oppsummering, egen
-- rollback. Delene deler ingen tilstand og kan kjoeres i hvilken som
-- helst rekkefoelge. Rekkefoelgen i tallet er bare lesbarhet.
--
-- INGEN FUNN I EN DEL BETYR INGEN FUNN I DEN DELEN. Hele beviset er
-- alle delene, og hver av dem maa si "ingen funn".
--
-- ATFERDSMATRISEN. For hver varm ressurs, hver identitet og hver
-- operasjon kontrakten beskriver: naar den, eller naar den ikke?
--
-- POSITIVE KONTROLLER ER OBLIGATORISKE. En suite som bare beviser
-- "avvist" kan vaere groenn fordi alt er oedelagt. Hver identitet som
-- SKAL naa noe, proever ogsaa det.
--
-- AVVIST MAA VAERE 42501. Et forbudt insert som feiler paa en
-- unique-skranke er ogsaa "avvist", men det beviser ingenting om RLS.
-- rutine_utforinger har unique (rutine_id, dato) og ville gitt akkurat
-- den falske groennheten. `skriv_avvist` krever derfor 42501 - eller
-- null rader, som er det `using` gir paa update og delete.
begin;

-- --- Fasitverdenen ---------------------------------------------------
-- Butikknummer 0001 finnes i BEGGE kjeder, og ansatt_nr 4501 likesaa.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a000', 'owner_A@kanari.local'),
  ('00000000-0000-0000-0000-00000000a001', 'manager_A1@kanari.local'),
  ('00000000-0000-0000-0000-00000000a012', 'manager_A12@kanari.local'),
  ('00000000-0000-0000-0000-00000000a101', 'tablet_A1@kanari.local'),
  ('00000000-0000-0000-0000-00000000b000', 'owner_B@kanari.local'),
  ('00000000-0000-0000-0000-00000000b001', 'manager_B1@kanari.local'),
  ('00000000-0000-0000-0000-00000000b101', 'tablet_B1@kanari.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('aaaa0000-0000-4000-8000-000000000000', 'Kanari A'),
  ('bbbb0000-0000-4000-8000-000000000000', 'Kanari B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'retailer_admin', 'owner_A'),
  ('00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'manager_A1'),
  ('00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'manager_A12'),
  ('00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'butikkbruker_tablet', 'tablet_A1'),
  ('00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'retailer_admin', 'owner_B'),
  ('00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'manager_B1'),
  ('00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'butikkbruker_tablet', 'tablet_B1');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('a1110000-0000-4000-8000-000000000001', 'aaaa0000-0000-4000-8000-000000000000', '0001', 'Sentrum', 'sentrum'),
  ('a1110000-0000-4000-8000-000000000002', 'aaaa0000-0000-4000-8000-000000000000', '0002', 'Nord',    'pendler'),
  ('a1110000-0000-4000-8000-000000000003', 'aaaa0000-0000-4000-8000-000000000000', '0003', 'Vest',    'utfart'),
  ('b1110000-0000-4000-8000-000000000001', 'bbbb0000-0000-4000-8000-000000000000', '0001', 'Sentrum', 'sentrum'),
  ('b1110000-0000-4000-8000-000000000002', 'bbbb0000-0000-4000-8000-000000000000', '0002', 'Nord',    'pendler');

insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('00000000-0000-0000-0000-00000000a001', 'a1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000a012', 'a1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000a012', 'a1110000-0000-4000-8000-000000000002'),
  ('00000000-0000-0000-0000-00000000a101', 'a1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000b001', 'b1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000b101', 'b1110000-0000-4000-8000-000000000001');


-- --- Hjelpere --------------------------------------------------------
--
-- EN TELLER SOM VIRKER I BASEN, ikke bare i generatoren.
--
-- nyrad_* kalles flere ganger for SAMME identitet og SAMME stasjon -
-- en gang foer update, en gang foer delete. Bakes forretningsnokkelen
-- inn med en fast verdi, kolliderer det andre kallet med 23505:
--
--   duplicate key value violates unique constraint
--   "produksjonsplan_hode_stasjon_id_dato_key"
--
-- Generatorens egen teller loeser det ikke - den teller ved
-- GENERERING, og funksjonskroppen skrives en gang. Denne teller ved
-- KJORING.
--
-- EGET DATOROM. Foerste forsoek lot begge tellerne lage datoer fra
-- 2026-01-01, og da kolliderte de med hverandre i stedet for med seg
-- selv. De seedede radene bruker 2026 + generatorens teller (0-700);
-- nyrad_* bruker 2030 + denne. To tellere som teller riktig hver for
-- seg, men i samme rom, er fortsatt en kollisjon.
create temp sequence tenant_teller;

create temp table funn (
  nr serial primary key, status text not null, navn text not null, detalj text,
  gruppe text, art text
) on commit drop;

-- Gruppa er ressurs + identitet. Arten er positiv, negativ eller lesing.
-- Sammen er de det som gjor regelen under maalbar: en negativ
-- tenant-test teller ikke foer den positive i samme gruppe har lykkes.
create temp table gjeldende (gruppe text, art text) on commit drop;
insert into gjeldende values (null, null);

create or replace function pg_temp.sett_gruppe(p_gruppe text) returns void
language plpgsql security definer as $$
begin
  update pg_temp.gjeldende set gruppe = p_gruppe;
end $$;

create or replace function pg_temp.logg(p_status text, p_navn text, p_detalj text default null,
  p_art text default null)
returns void language plpgsql security definer as $$
begin
  insert into pg_temp.funn (status, navn, detalj, gruppe, art)
  values (p_status, p_navn, p_detalj,
          (select gruppe from pg_temp.gjeldende limit 1), p_art);
end $$;

create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function pg_temp.som_eier() returns void
language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean, p_art text default 'lesing')
returns void language plpgsql security definer as $$
begin
  perform pg_temp.logg(case when p_ok is true then 'ok' else 'FEIL' end, p_navn, null, p_art);
end $$;

-- SECURITY INVOKER, og det er ikke valgfritt: den dynamiske setningen
-- MAA kjore som testbrukeren. Blir denne definer, gaar skrivingen som
-- eier - forbi RLS - og hele fila blir groenn uansett hva policyen sier.
--
-- 42501 ELLER NULL RADER, INGENTING ANNET. En unique-skranke (23505)
-- eller en fremmednokkel (23503) avviser ogsaa, men beviser ingenting
-- om tenantvernet. Slike svar er FEIL her, ikke ok.
-- KONTROLLKONTEKST. Definer, saa den ser forbi RLS og svarer paa om
-- raden i det hele tatt finnes. Uten den er "0 rader" tvetydig.
create or replace function pg_temp.finnes(p_tabell text, p_id uuid, p_kol text default 'id')
returns boolean language plpgsql security definer as $$
declare n int;
begin
  execute format('select count(*) from public.%I where %I = $1', p_tabell, p_kol) into n using p_id;
  return n > 0;
end $$;

-- SAMME KONTROLLKONTEKST, MEN FOR EN SAMMENSATT NOEKKEL.
--
-- `timesalg` og `kassererstatistikk` har ingen id-kolonne; raden er
-- (retailer_id, stasjon_id, dato, time). Da finnes det ingen enkelt
-- verdi aa slaa opp paa, og "0 rader" ville vaert like tvetydig som foer
-- - bare uten en maate aa oppklare det paa.
--
-- Predikatet kommer fra generatoren og gjelder den seedede raden.
create or replace function pg_temp.finnes_pred(p_tabell text, p_pred text)
returns boolean language plpgsql security definer as $$
declare n int;
begin
  execute format('select count(*) from public.%I where %s', p_tabell, p_pred) into n;
  return n > 0;
end $$;

create or replace function pg_temp.skriv_avvist(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_id uuid default null, p_maal_kol text default 'id'
) returns void
language plpgsql as $$
begin
  -- EN KROPP, to maater aa peke paa raden. Uten delegeringen ville
  -- regelen om at 0 rader krever en bekreftet maalrad staatt to steder,
  -- og den ene kopien ville sluttet aa gjelde uten at noe sa fra.
  perform pg_temp.skriv_avvist_pred(p_navn, p_sql, p_maal_tabell,
    case when p_maal_tabell is null then null
         else format('%I = %L', p_maal_kol, p_maal_id) end);
end $$;

create or replace function pg_temp.skriv_avvist_pred(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_pred text default null
) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    if sqlstate = '42501' then
      perform pg_temp.logg('ok', p_navn, 'avvist med 42501', 'negativ');
    else
      perform pg_temp.logg('FEIL', p_navn,
        'avvist av FEIL grunn: ' || sqlstate || ' - beviser ikke tenantvern', 'negativ');
    end if;
    return;
  end;
  if n > 0 then
    perform pg_temp.logg('FEIL', p_navn, 'skrivingen gikk gjennom, ' || n || ' rad(er)', 'negativ');
    return;
  end if;

  -- NULL RADER ER IKKE ET BEVIS I SEG SELV.
  --
  -- `using` som utelukker raden gir 0 rader. Men det gjor OGSAA en feil
  -- id, en fixture som aldri ble seedet, eller en tabell som er tom.
  -- Alle tre ser identiske ut herfra, og alle tre ville vaert groenne.
  --
  -- Derfor: raden maa bevises aa finnes i kontrollkonteksten foer 0
  -- rader godtas. Da - og bare da - er det RLS som stoppet skrivingen.
  if p_maal_tabell is null then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men ingen maalrad oppgitt - kan ikke skille RLS fra feil fixture', 'negativ');
  elsif not pg_temp.finnes_pred(p_maal_tabell, p_maal_pred) then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men maalraden (' || p_maal_pred || ') finnes ikke i ' || p_maal_tabell
      || ' - testen beviser ingenting', 'negativ');
  else
    perform pg_temp.logg('ok', p_navn, '0 rader, maalrad bekreftet', 'negativ');
  end if;
end $$;

create or replace function pg_temp.skriv_tillatt(p_navn text, p_sql text) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    perform pg_temp.logg('FEIL', p_navn, 'ble blokkert: ' || sqlstate, 'positiv');
    return;
  end;
  if n = 0 then
    perform pg_temp.logg('FEIL', p_navn, 'traff 0 rader - blokkert i stillhet', 'positiv');
  else
    perform pg_temp.logg('ok', p_navn, n || ' rad', 'positiv');
  end if;
end $$;

-- --- Forutsetninger, en per forsoek ---
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('24f39fd5-0000-4000-8000-000024f39fd5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 7', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('c0d7ff8d-0000-4000-8000-0000c0d7ff8d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '24f39fd5-0000-4000-8000-000024f39fd5', 'Sonderutine 7');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('24f3a397-0000-4000-8000-000024f3a397', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 8', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('c0d8034f-0000-4000-8000-0000c0d8034f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '24f3a397-0000-4000-8000-000024f3a397', 'Sonderutine 8');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('24f3a759-0000-4000-8000-000024f3a759', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 9', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('c0d80711-0000-4000-8000-0000c0d80711', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '24f3a759-0000-4000-8000-000024f3a759', 'Sonderutine 9');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('798e71c2-0000-4000-8000-0000798e71c2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 10', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('5a36090a-0000-4000-8000-00005a36090a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '798e71c2-0000-4000-8000-0000798e71c2', 'Sonderutine 10');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('798ee622-0000-4000-8000-0000798ee622', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 11', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('5a367d6a-0000-4000-8000-00005a367d6a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '798ee622-0000-4000-8000-0000798ee622', 'Sonderutine 11');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bceb-0000-4000-8000-0000ce85bceb', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d0f8-0000-4000-8000-0000f243d0f8', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f335e6-0000-4000-8000-0000a7f335e6', 'f243d0f8-0000-4000-8000-0000f243d0f8');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('485d23f4-0000-4000-8000-0000485d23f4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd87-0000-4000-8000-0000ce85bd87', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd88-0000-4000-8000-0000ce85bd88', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd89-0000-4000-8000-0000ce85bd89', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd8a-0000-4000-8000-0000ce85bd8a', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd8b-0000-4000-8000-0000ce85bd8b', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bd8c-0000-4000-8000-0000ce85bd8c', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda2-0000-4000-8000-0000ce85bda2', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda3-0000-4000-8000-0000ce85bda3', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda4-0000-4000-8000-0000ce85bda4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda5-0000-4000-8000-0000ce85bda5', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda6-0000-4000-8000-0000ce85bda6', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda7-0000-4000-8000-0000ce85bda7', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce85bda8-0000-4000-8000-0000ce85bda8', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d52a-0000-4000-8000-0000ce93d52a', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d52b-0000-4000-8000-0000ce93d52b', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d52c-0000-4000-8000-0000ce93d52c', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d542-0000-4000-8000-0000ce93d542', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d543-0000-4000-8000-0000ce93d543', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d544-0000-4000-8000-0000ce93d544', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d545-0000-4000-8000-0000ce93d545', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d546-0000-4000-8000-0000ce93d546', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d547-0000-4000-8000-0000ce93d547', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('ce93d548-0000-4000-8000-0000ce93d548', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1d4-0000-4000-8000-0000f243d1d4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336c2-0000-4000-8000-0000a7f336c2', 'f243d1d4-0000-4000-8000-0000f243d1d4');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1d5-0000-4000-8000-0000f243d1d5', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336c3-0000-4000-8000-0000a7f336c3', 'f243d1d5-0000-4000-8000-0000f243d1d5');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1d6-0000-4000-8000-0000f243d1d6', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336c4-0000-4000-8000-0000a7f336c4', 'f243d1d6-0000-4000-8000-0000f243d1d6');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1ec-0000-4000-8000-0000f243d1ec', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336da-0000-4000-8000-0000a7f336da', 'f243d1ec-0000-4000-8000-0000f243d1ec');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1ed-0000-4000-8000-0000f243d1ed', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336db-0000-4000-8000-0000a7f336db', 'f243d1ed-0000-4000-8000-0000f243d1ed');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1ee-0000-4000-8000-0000f243d1ee', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336dc-0000-4000-8000-0000a7f336dc', 'f243d1ee-0000-4000-8000-0000f243d1ee');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1ef-0000-4000-8000-0000f243d1ef', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336dd-0000-4000-8000-0000a7f336dd', 'f243d1ef-0000-4000-8000-0000f243d1ef');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f0-0000-4000-8000-0000f243d1f0', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336de-0000-4000-8000-0000a7f336de', 'f243d1f0-0000-4000-8000-0000f243d1f0');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f1-0000-4000-8000-0000f243d1f1', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336df-0000-4000-8000-0000a7f336df', 'f243d1f1-0000-4000-8000-0000f243d1f1');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f2-0000-4000-8000-0000f243d1f2', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336e0-0000-4000-8000-0000a7f336e0', 'f243d1f2-0000-4000-8000-0000f243d1f2');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f3-0000-4000-8000-0000f243d1f3', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336e1-0000-4000-8000-0000a7f336e1', 'f243d1f3-0000-4000-8000-0000f243d1f3');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f4-0000-4000-8000-0000f243d1f4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336e2-0000-4000-8000-0000a7f336e2', 'f243d1f4-0000-4000-8000-0000f243d1f4');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('f243d1f5-0000-4000-8000-0000f243d1f5', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('a7f336e3-0000-4000-8000-0000a7f336e3', 'f243d1f5-0000-4000-8000-0000f243d1f5');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb265b-0000-4000-8000-000057eb265b', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f2d-0000-4000-8000-000058285f2d', '57eb265b-0000-4000-8000-000057eb265b');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb265c-0000-4000-8000-000057eb265c', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f2e-0000-4000-8000-000058285f2e', '57eb265c-0000-4000-8000-000057eb265c');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb265d-0000-4000-8000-000057eb265d', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f2f-0000-4000-8000-000058285f2f', '57eb265d-0000-4000-8000-000057eb265d');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb265e-0000-4000-8000-000057eb265e', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f30-0000-4000-8000-000058285f30', '57eb265e-0000-4000-8000-000057eb265e');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb265f-0000-4000-8000-000057eb265f', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f31-0000-4000-8000-000058285f31', '57eb265f-0000-4000-8000-000057eb265f');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb2660-0000-4000-8000-000057eb2660', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f32-0000-4000-8000-000058285f32', '57eb2660-0000-4000-8000-000057eb2660');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb2661-0000-4000-8000-000057eb2661', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f33-0000-4000-8000-000058285f33', '57eb2661-0000-4000-8000-000057eb2661');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb2662-0000-4000-8000-000057eb2662', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f34-0000-4000-8000-000058285f34', '57eb2662-0000-4000-8000-000057eb2662');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb2663-0000-4000-8000-000057eb2663', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f35-0000-4000-8000-000058285f35', '57eb2663-0000-4000-8000-000057eb2663');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('57eb2664-0000-4000-8000-000057eb2664', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('58285f36-0000-4000-8000-000058285f36', '57eb2664-0000-4000-8000-000057eb2664');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a40-0000-4000-8000-0000c3475a40', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a41-0000-4000-8000-0000c3475a41', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a42-0000-4000-8000-0000c3475a42', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a43-0000-4000-8000-0000c3475a43', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a44-0000-4000-8000-0000c3475a44', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a45-0000-4000-8000-0000c3475a45', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a46-0000-4000-8000-0000c3475a46', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a47-0000-4000-8000-0000c3475a47', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a48-0000-4000-8000-0000c3475a48', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a49-0000-4000-8000-0000c3475a49', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a5f-0000-4000-8000-0000c3475a5f', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a60-0000-4000-8000-0000c3475a60', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c3475a61-0000-4000-8000-0000c3475a61', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3301-0000-4000-8000-0000c4fc3301', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3302-0000-4000-8000-0000c4fc3302', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3303-0000-4000-8000-0000c4fc3303', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3304-0000-4000-8000-0000c4fc3304', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3305-0000-4000-8000-0000c4fc3305', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3306-0000-4000-8000-0000c4fc3306', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc3307-0000-4000-8000-0000c4fc3307', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc331d-0000-4000-8000-0000c4fc331d', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc331e-0000-4000-8000-0000c4fc331e', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('c4fc331f-0000-4000-8000-0000c4fc331f', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
-- --- varsler: forutsetninger og proberader ---
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('aef22628-0000-4000-8000-0000aef22628', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde', 'Sondevarsel nullA', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('aef22629-0000-4000-8000-0000aef22629', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde', 'Sondevarsel nullB', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de1-0000-4000-8000-00002c110de1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde', 'Sondevarsel fastA1', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de2-0000-4000-8000-00002c110de2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde', 'Sondevarsel fastA2', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de3-0000-4000-8000-00002c110de3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde', 'Sondevarsel fastA3', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110e00-0000-4000-8000-00002c110e00', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde', 'Sondevarsel fastB1', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110e01-0000-4000-8000-00002c110e01', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde', 'Sondevarsel fastB2', 'Sonde');

create or replace function pg_temp.nyrad_varsler(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst)
  values (p_retailer, p_stasjon, 'sonde', 'Sondevarsel ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde')
  returning id into ny;
  return ny;
end $fn$;
-- --- rutine_forventninger: forutsetninger og proberader ---
insert into public.rutine_forventninger (id, retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, rutine_tittel, forventet_start, forventet_slutt) values ('db4841c3-0000-4000-8000-0000db4841c3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'c0d7ff8d-0000-4000-8000-0000c0d7ff8d', gen_random_uuid(), date '2026-01-01' + 7, 'morgen', 'Sonderutine', '06:00', '14:00');
insert into public.rutine_forventninger (id, retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, rutine_tittel, forventet_start, forventet_slutt) values ('db4841c4-0000-4000-8000-0000db4841c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'c0d8034f-0000-4000-8000-0000c0d8034f', gen_random_uuid(), date '2026-01-01' + 8, 'morgen', 'Sonderutine', '06:00', '14:00');
insert into public.rutine_forventninger (id, retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, rutine_tittel, forventet_start, forventet_slutt) values ('db4841c5-0000-4000-8000-0000db4841c5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'c0d80711-0000-4000-8000-0000c0d80711', gen_random_uuid(), date '2026-01-01' + 9, 'morgen', 'Sonderutine', '06:00', '14:00');
insert into public.rutine_forventninger (id, retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, rutine_tittel, forventet_start, forventet_slutt) values ('db4841e2-0000-4000-8000-0000db4841e2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '5a36090a-0000-4000-8000-00005a36090a', gen_random_uuid(), date '2026-01-01' + 10, 'morgen', 'Sonderutine', '06:00', '14:00');
insert into public.rutine_forventninger (id, retailer_id, stasjon_id, rutine_id, skjema_id, dato, vakttype, rutine_tittel, forventet_start, forventet_slutt) values ('db4841e3-0000-4000-8000-0000db4841e3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '5a367d6a-0000-4000-8000-00005a367d6a', gen_random_uuid(), date '2026-01-01' + 11, 'morgen', 'Sonderutine', '06:00', '14:00');
-- --- tilbudsforesporsler: forutsetninger og proberader ---
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('bd69b5c2-0000-4000-8000-0000bd69b5c2', 'Sondekunde global', 'Sonde', 'sonde-global@example.invalid', '00000000', 1, true);
-- --- tilbud: forutsetninger og proberader ---
insert into public.tilbud (id, foresporsel_id) values ('992330a3-0000-4000-8000-0000992330a3', 'ce85bceb-0000-4000-8000-0000ce85bceb');
-- --- avtale_revisjon: forutsetninger og proberader ---
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'a7f335e6-0000-4000-8000-0000a7f335e6', 'sonde');
-- --- tilbudsforesporsel_revisjon: forutsetninger og proberader ---
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', '485d23f4-0000-4000-8000-0000485d23f4', 'sonde');

-- =====================================================================
-- varsler  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('varsler');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('varsler owner_A SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT A2 -> ser', exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT A3 -> ser', exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_AA1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel owner_AA2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel owner_AA3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler owner_A INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_AB1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('varsler owner_A UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'positiv');
select pg_temp.paastand('varsler owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('varsler manager_A1 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'negativ');
select pg_temp.paastand('varsler manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A1A1'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_A1A2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A1A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A1B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('varsler manager_A1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''', 'varsler', '2c110de2-0000-4000-8000-00002c110de2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_A1 FLYTTER egen rad A1 -> A2', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('varsler manager_A12 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler manager_A12 SELECT A2 -> ser', exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'positiv');
select pg_temp.paastand('varsler manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A12A1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_A12A2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A12 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A12A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A12 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A12B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('varsler manager_A12 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('varsler manager_A12 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('varsler manager_A12 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('varsler manager_A12 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_A12 FLYTTER egen rad A1 -> A3', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('varsler tablet_A1 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_A1A1'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_A1A2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel tablet_A1A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_A1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_A1B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('varsler tablet_A1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''', 'varsler', '2c110de2-0000-4000-8000-00002c110de2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('varsler owner_B SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler owner_B SELECT B2 -> ser', exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'positiv');
select pg_temp.paastand('varsler owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler owner_B INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_BB1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_B INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel owner_BB2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler owner_B INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_BA1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('varsler owner_B UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('varsler owner_B UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('varsler owner_B UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'positiv');
select pg_temp.paastand('varsler owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('varsler manager_B1 SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'negativ');
select pg_temp.paastand('varsler manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_B1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_B1B1'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_B1B2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_B1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_B1A1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('varsler manager_B1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('varsler manager_B1 UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''', 'varsler', '2c110e01-0000-4000-8000-00002c110e01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('varsler manager_B1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.paastand('varsler manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_B1 FLYTTER egen rad B1 -> B2', 'update public.varsler set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('varsler tablet_B1 SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'negativ');
select pg_temp.paastand('varsler tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler tablet_B1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_B1B1'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_B1B2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_B1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_B1A1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('varsler tablet_B1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('varsler tablet_B1 UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''', 'varsler', '2c110e01-0000-4000-8000-00002c110e01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('varsler tablet_B1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.paastand('varsler tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.skriv_avvist('varsler tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.varsler set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');

-- =====================================================================
-- rutine_forventninger  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_forventninger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_forventninger owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'positiv');
select pg_temp.paastand('rutine_forventninger owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c4-0000-4000-8000-0000db4841c4'), 'positiv');
select pg_temp.paastand('rutine_forventninger owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c5-0000-4000-8000-0000db4841c5'), 'positiv');
select pg_temp.paastand('rutine_forventninger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutine_forventninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'positiv');
select pg_temp.paastand('rutine_forventninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c4-0000-4000-8000-0000db4841c4'), 'negativ');
select pg_temp.paastand('rutine_forventninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c5-0000-4000-8000-0000db4841c5'), 'negativ');
select pg_temp.paastand('rutine_forventninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutine_forventninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'positiv');
select pg_temp.paastand('rutine_forventninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841c4-0000-4000-8000-0000db4841c4'), 'positiv');
select pg_temp.paastand('rutine_forventninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c5-0000-4000-8000-0000db4841c5'), 'negativ');
select pg_temp.paastand('rutine_forventninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutine_forventninger tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'negativ');
select pg_temp.paastand('rutine_forventninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c4-0000-4000-8000-0000db4841c4'), 'negativ');
select pg_temp.paastand('rutine_forventninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c5-0000-4000-8000-0000db4841c5'), 'negativ');
select pg_temp.paastand('rutine_forventninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutine_forventninger owner_B SELECT B1 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'positiv');
select pg_temp.paastand('rutine_forventninger owner_B SELECT B2 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841e3-0000-4000-8000-0000db4841e3'), 'positiv');
select pg_temp.paastand('rutine_forventninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_forventninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'positiv');
select pg_temp.paastand('rutine_forventninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e3-0000-4000-8000-0000db4841e3'), 'negativ');
select pg_temp.paastand('rutine_forventninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutine_forventninger tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e2-0000-4000-8000-0000db4841e2'), 'negativ');
select pg_temp.paastand('rutine_forventninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841e3-0000-4000-8000-0000db4841e3'), 'negativ');
select pg_temp.paastand('rutine_forventninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_forventninger where id = 'db4841c3-0000-4000-8000-0000db4841c3'), 'negativ');

-- =====================================================================
-- tilbudsforesporsler  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbudsforesporsler');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbudsforesporsler owner_A SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_A INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gowner_Ainsert'', ''Sonde'', ''sonde-gowner_Ainsert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_A UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_A DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('bd69b5c2-0000-4000-8000-0000bd69b5c2', 'Sondekunde ggjenowner_A', 'Sonde', 'sonde-ggjenowner_A@example.invalid', '00000000', 1, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbudsforesporsler manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gmanager_A1insert'', ''Sonde'', ''sonde-gmanager_A1insert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A1 UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbudsforesporsler manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A12 INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gmanager_A12insert'', ''Sonde'', ''sonde-gmanager_A12insert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A12 UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_A12 DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbudsforesporsler tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gtablet_A1insert'', ''Sonde'', ''sonde-gtablet_A1insert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_A1 UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbudsforesporsler owner_B SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_B INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gowner_Binsert'', ''Sonde'', ''sonde-gowner_Binsert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_B UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''');
select pg_temp.skriv_tillatt('tilbudsforesporsler owner_B DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('bd69b5c2-0000-4000-8000-0000bd69b5c2', 'Sondekunde ggjenowner_B', 'Sonde', 'sonde-ggjenowner_B@example.invalid', '00000000', 1, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbudsforesporsler manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gmanager_B1insert'', ''Sonde'', ''sonde-gmanager_B1insert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_B1 UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsler manager_B1 DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbudsforesporsler tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsler where id = 'bd69b5c2-0000-4000-8000-0000bd69b5c2'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsler (virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values (''Sondekunde gtablet_B1insert'', ''Sonde'', ''sonde-gtablet_B1insert@example.invalid'', ''00000000'', 1, true)');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_B1 UPDATE den globale raden', 'update public.tilbudsforesporsler set virksomhet = ''Sondekunde endret'' where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsler tablet_B1 DELETE den globale raden', 'delete from public.tilbudsforesporsler where id = ''bd69b5c2-0000-4000-8000-0000bd69b5c2''', 'tilbudsforesporsler', 'bd69b5c2-0000-4000-8000-0000bd69b5c2', 'id');

-- =====================================================================
-- tilbud  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbud');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbud owner_A SELECT den globale raden -> ser', exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'positiv');
select pg_temp.skriv_tillatt('tilbud owner_A INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce85bd87-0000-4000-8000-0000ce85bd87'')');
select pg_temp.skriv_tillatt('tilbud owner_A UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''');
select pg_temp.skriv_tillatt('tilbud owner_A DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''');
select pg_temp.som_eier();
insert into public.tilbud (id, foresporsel_id) values ('992330a3-0000-4000-8000-0000992330a3', 'ce85bd8a-0000-4000-8000-0000ce85bd8a');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbud manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'negativ');
select pg_temp.skriv_avvist('tilbud manager_A1 INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce85bd8b-0000-4000-8000-0000ce85bd8b'')');
select pg_temp.skriv_avvist('tilbud manager_A1 UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');
select pg_temp.skriv_avvist('tilbud manager_A1 DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbud manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'negativ');
select pg_temp.skriv_avvist('tilbud manager_A12 INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce85bda3-0000-4000-8000-0000ce85bda3'')');
select pg_temp.skriv_avvist('tilbud manager_A12 UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');
select pg_temp.skriv_avvist('tilbud manager_A12 DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbud tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'negativ');
select pg_temp.skriv_avvist('tilbud tablet_A1 INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce85bda6-0000-4000-8000-0000ce85bda6'')');
select pg_temp.skriv_avvist('tilbud tablet_A1 UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');
select pg_temp.skriv_avvist('tilbud tablet_A1 DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbud owner_B SELECT den globale raden -> ser', exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'positiv');
select pg_temp.skriv_tillatt('tilbud owner_B INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce93d52a-0000-4000-8000-0000ce93d52a'')');
select pg_temp.skriv_tillatt('tilbud owner_B UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''');
select pg_temp.skriv_tillatt('tilbud owner_B DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''');
select pg_temp.som_eier();
insert into public.tilbud (id, foresporsel_id) values ('992330a3-0000-4000-8000-0000992330a3', 'ce93d542-0000-4000-8000-0000ce93d542');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbud manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'negativ');
select pg_temp.skriv_avvist('tilbud manager_B1 INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce93d543-0000-4000-8000-0000ce93d543'')');
select pg_temp.skriv_avvist('tilbud manager_B1 UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');
select pg_temp.skriv_avvist('tilbud manager_B1 DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbud tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbud where id = '992330a3-0000-4000-8000-0000992330a3'), 'negativ');
select pg_temp.skriv_avvist('tilbud tablet_B1 INSERT den globale raden', 'insert into public.tilbud (foresporsel_id) values (''ce93d546-0000-4000-8000-0000ce93d546'')');
select pg_temp.skriv_avvist('tilbud tablet_B1 UPDATE den globale raden', 'update public.tilbud set status = ''sendt'' where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');
select pg_temp.skriv_avvist('tilbud tablet_B1 DELETE den globale raden', 'delete from public.tilbud where id = ''992330a3-0000-4000-8000-0000992330a3''', 'tilbud', '992330a3-0000-4000-8000-0000992330a3', 'id');

-- =====================================================================
-- avtale_revisjon  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('avtale_revisjon');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('avtale_revisjon owner_A SELECT den globale raden -> ser', exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'positiv');
select pg_temp.skriv_tillatt('avtale_revisjon owner_A INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''a7f336c2-0000-4000-8000-0000a7f336c2'', ''sonde'')');
select pg_temp.skriv_tillatt('avtale_revisjon owner_A UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.skriv_tillatt('avtale_revisjon owner_A DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.som_eier();
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'a7f336da-0000-4000-8000-0000a7f336da', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('avtale_revisjon manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''a7f336db-0000-4000-8000-0000a7f336db'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('avtale_revisjon manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''a7f336de-0000-4000-8000-0000a7f336de'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('avtale_revisjon tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''a7f336e1-0000-4000-8000-0000a7f336e1'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('avtale_revisjon owner_B SELECT den globale raden -> ser', exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'positiv');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''58285f2d-0000-4000-8000-000058285f2d'', ''sonde'')');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.som_eier();
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', '58285f30-0000-4000-8000-000058285f30', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('avtale_revisjon manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''58285f31-0000-4000-8000-000058285f31'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('avtale_revisjon tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''58285f34-0000-4000-8000-000058285f34'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

-- =====================================================================
-- tilbudsforesporsel_revisjon  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbudsforesporsel_revisjon');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbudsforesporsel_revisjon owner_A SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c3475a40-0000-4000-8000-0000c3475a40'', ''sonde'')');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', 'c3475a43-0000-4000-8000-0000c3475a43', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c3475a44-0000-4000-8000-0000c3475a44'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c3475a47-0000-4000-8000-0000c3475a47'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbudsforesporsel_revisjon tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c3475a5f-0000-4000-8000-0000c3475a5f'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbudsforesporsel_revisjon owner_B SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c4fc3301-0000-4000-8000-0000c4fc3301'', ''sonde'')');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', 'c4fc3304-0000-4000-8000-0000c4fc3304', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c4fc3305-0000-4000-8000-0000c4fc3305'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbudsforesporsel_revisjon tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''c4fc331d-0000-4000-8000-0000c4fc331d'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_B1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_B1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.som_eier();

-- =====================================================================
-- EN NEGATIV TENANT-TEST TELLER IKKE FOER DEN POSITIVE HAR LYKTES.
--
-- Fixturen er ressursens. Lykkes ingen tillatt operasjon paa en
-- ressurs, vet vi ikke om proberaden i det hele tatt er gyldig i
-- domenet - og da beviser ingen av avvisningene noe om tenantgrensen.
-- De kan like gjerne ha feilet paa en skranke, en fremmednokkel eller
-- en manglende forutsetning.
--
-- Uten denne blokka ville en suite der ALT er oedelagt sett ut som en
-- suite der alt er trygt.
-- =====================================================================
do $$
declare r record;
begin
  for r in
    select distinct f.gruppe
    from pg_temp.funn f
    where f.art = 'negativ'
      and not exists (
        select 1 from pg_temp.funn p
        where p.gruppe = f.gruppe and p.art = 'positiv' and p.status = 'ok')
    order by 1
  loop
    insert into pg_temp.funn (status, navn, detalj, gruppe, art)
    values ('FEIL', r.gruppe || ': ingen positiv kontroll lyktes',
            'Avvisningene i denne gruppa er derfor ikke gyldige tenant-bevis - fixturen kan vaere ugyldig i domenet.',
            r.gruppe, 'kontroll');
  end loop;
end $$;

select status, navn, detalj
from pg_temp.funn
order by (status = 'FEIL') desc, nr;

-- =====================================================================
-- EXIT-KODEN MAA FOELGE TABELLEN.
--
-- Paastandene er RADER, ikke unntak - det er hele grunnen til at
-- resultatet er lesbart. Men da gaar psql ut med 0 selv naar tabellen
-- er full av FEIL, og CI-jobben blir groenn.
--
-- Det skjedde 2026-08-25: elleve FEIL, groenn jobb. En roed suite som
-- rapporteres som groenn er verre enn ingen suite - det er slik man
-- laerer seg aa se bort fra roedt.
--
-- Selecten over kjorer FOERST, saa tabellen staar i loggen. Denne
-- kaster etterpaa.
-- =====================================================================
do $$
declare n int;
begin
  select count(*) into n from pg_temp.funn where status = 'FEIL';
  if n > 0 then
    raise exception 'TENANT-MATRISEN DEL 11/11: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 11/11: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
