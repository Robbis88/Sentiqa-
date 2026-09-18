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
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cb48-0000-4000-8000-00003a90cb48', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532507-0000-4000-8000-00001e532507', '3a90cb48-0000-4000-8000-00003a90cb48');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('4c84d033-0000-4000-8000-00004c84d033', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
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
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc24-0000-4000-8000-00003a90cc24', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325e3-0000-4000-8000-00001e5325e3', '3a90cc24-0000-4000-8000-00003a90cc24');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc25-0000-4000-8000-00003a90cc25', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325e4-0000-4000-8000-00001e5325e4', '3a90cc25-0000-4000-8000-00003a90cc25');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc26-0000-4000-8000-00003a90cc26', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325e5-0000-4000-8000-00001e5325e5', '3a90cc26-0000-4000-8000-00003a90cc26');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc3c-0000-4000-8000-00003a90cc3c', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325fb-0000-4000-8000-00001e5325fb', '3a90cc3c-0000-4000-8000-00003a90cc3c');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc3d-0000-4000-8000-00003a90cc3d', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325fc-0000-4000-8000-00001e5325fc', '3a90cc3d-0000-4000-8000-00003a90cc3d');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc3e-0000-4000-8000-00003a90cc3e', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325fd-0000-4000-8000-00001e5325fd', '3a90cc3e-0000-4000-8000-00003a90cc3e');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc3f-0000-4000-8000-00003a90cc3f', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325fe-0000-4000-8000-00001e5325fe', '3a90cc3f-0000-4000-8000-00003a90cc3f');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc40-0000-4000-8000-00003a90cc40', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e5325ff-0000-4000-8000-00001e5325ff', '3a90cc40-0000-4000-8000-00003a90cc40');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc41-0000-4000-8000-00003a90cc41', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532600-0000-4000-8000-00001e532600', '3a90cc41-0000-4000-8000-00003a90cc41');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc42-0000-4000-8000-00003a90cc42', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532601-0000-4000-8000-00001e532601', '3a90cc42-0000-4000-8000-00003a90cc42');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc43-0000-4000-8000-00003a90cc43', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532602-0000-4000-8000-00001e532602', '3a90cc43-0000-4000-8000-00003a90cc43');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc44-0000-4000-8000-00003a90cc44', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532603-0000-4000-8000-00001e532603', '3a90cc44-0000-4000-8000-00003a90cc44');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('3a90cc45-0000-4000-8000-00003a90cc45', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('1e532604-0000-4000-8000-00001e532604', '3a90cc45-0000-4000-8000-00003a90cc45');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d760b-0000-4000-8000-0000193d760b', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc6542c-0000-4000-8000-0000adc6542c', '193d760b-0000-4000-8000-0000193d760b');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d760c-0000-4000-8000-0000193d760c', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc6542d-0000-4000-8000-0000adc6542d', '193d760c-0000-4000-8000-0000193d760c');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d760d-0000-4000-8000-0000193d760d', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc6542e-0000-4000-8000-0000adc6542e', '193d760d-0000-4000-8000-0000193d760d');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d760e-0000-4000-8000-0000193d760e', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc6542f-0000-4000-8000-0000adc6542f', '193d760e-0000-4000-8000-0000193d760e');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d760f-0000-4000-8000-0000193d760f', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65430-0000-4000-8000-0000adc65430', '193d760f-0000-4000-8000-0000193d760f');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d7610-0000-4000-8000-0000193d7610', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65431-0000-4000-8000-0000adc65431', '193d7610-0000-4000-8000-0000193d7610');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d7611-0000-4000-8000-0000193d7611', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65432-0000-4000-8000-0000adc65432', '193d7611-0000-4000-8000-0000193d7611');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d7612-0000-4000-8000-0000193d7612', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65433-0000-4000-8000-0000adc65433', '193d7612-0000-4000-8000-0000193d7612');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d7613-0000-4000-8000-0000193d7613', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65434-0000-4000-8000-0000adc65434', '193d7613-0000-4000-8000-0000193d7613');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('193d7614-0000-4000-8000-0000193d7614', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbud (id, foresporsel_id) values ('adc65435-0000-4000-8000-0000adc65435', '193d7614-0000-4000-8000-0000193d7614');
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e1-0000-4000-8000-0000441535e1', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e2-0000-4000-8000-0000441535e2', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e3-0000-4000-8000-0000441535e3', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e4-0000-4000-8000-0000441535e4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e5-0000-4000-8000-0000441535e5', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e6-0000-4000-8000-0000441535e6', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e7-0000-4000-8000-0000441535e7', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e8-0000-4000-8000-0000441535e8', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535e9-0000-4000-8000-0000441535e9', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('441535ea-0000-4000-8000-0000441535ea', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('44153600-0000-4000-8000-000044153600', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('44153601-0000-4000-8000-000044153601', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('44153602-0000-4000-8000-000044153602', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea2-0000-4000-8000-000045ca0ea2', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea3-0000-4000-8000-000045ca0ea3', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea4-0000-4000-8000-000045ca0ea4', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea5-0000-4000-8000-000045ca0ea5', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea6-0000-4000-8000-000045ca0ea6', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea7-0000-4000-8000-000045ca0ea7', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ea8-0000-4000-8000-000045ca0ea8', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ebe-0000-4000-8000-000045ca0ebe', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ebf-0000-4000-8000-000045ca0ebf', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
insert into public.tilbudsforesporsler (id, virksomhet, kontaktperson, epost, telefon, antall_stasjoner, samtykke) values ('45ca0ec0-0000-4000-8000-000045ca0ec0', 'Sondekunde', 'Sonde', 'sonde@example.invalid', '00000000', 1, true);
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
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', '1e532507-0000-4000-8000-00001e532507', 'sonde');
-- --- tilbudsforesporsel_revisjon: forutsetninger og proberader ---
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', '4c84d033-0000-4000-8000-00004c84d033', 'sonde');

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
select pg_temp.skriv_tillatt('avtale_revisjon owner_A INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''1e5325e3-0000-4000-8000-00001e5325e3'', ''sonde'')');
select pg_temp.skriv_tillatt('avtale_revisjon owner_A UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.skriv_tillatt('avtale_revisjon owner_A DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.som_eier();
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', '1e5325fb-0000-4000-8000-00001e5325fb', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('avtale_revisjon manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''1e5325fc-0000-4000-8000-00001e5325fc'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_A1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('avtale_revisjon manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''1e5325ff-0000-4000-8000-00001e5325ff'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_A12 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('avtale_revisjon tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''1e532602-0000-4000-8000-00001e532602'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon tablet_A1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('avtale_revisjon owner_B SELECT den globale raden -> ser', exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'positiv');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''adc6542c-0000-4000-8000-0000adc6542c'', ''sonde'')');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.skriv_tillatt('avtale_revisjon owner_B DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''');
select pg_temp.som_eier();
insert into public.avtale_revisjon (id, tilbud_id, handling) values ('ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'adc6542f-0000-4000-8000-0000adc6542f', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('avtale_revisjon manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''adc65430-0000-4000-8000-0000adc65430'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon manager_B1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('avtale_revisjon tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.avtale_revisjon where id = 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d'), 'negativ');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 INSERT den globale raden', 'insert into public.avtale_revisjon (tilbud_id, handling) values (''adc65433-0000-4000-8000-0000adc65433'', ''sonde'')');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 UPDATE den globale raden', 'update public.avtale_revisjon set endringer = ''{}''::jsonb where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');
select pg_temp.skriv_avvist('avtale_revisjon tablet_B1 DELETE den globale raden', 'delete from public.avtale_revisjon where id = ''ffdf0b5d-0000-4000-8000-0000ffdf0b5d''', 'avtale_revisjon', 'ffdf0b5d-0000-4000-8000-0000ffdf0b5d', 'id');

-- =====================================================================
-- tilbudsforesporsel_revisjon  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbudsforesporsel_revisjon');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbudsforesporsel_revisjon owner_A SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''441535e1-0000-4000-8000-0000441535e1'', ''sonde'')');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_A DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', '441535e4-0000-4000-8000-0000441535e4', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''441535e5-0000-4000-8000-0000441535e5'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_A12 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''441535e8-0000-4000-8000-0000441535e8'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_A12 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbudsforesporsel_revisjon tablet_A1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''44153600-0000-4000-8000-000044153600'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_A1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbudsforesporsel_revisjon owner_B SELECT den globale raden -> ser', exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'positiv');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''45ca0ea2-0000-4000-8000-000045ca0ea2'', ''sonde'')');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.skriv_tillatt('tilbudsforesporsel_revisjon owner_B DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''');
select pg_temp.som_eier();
insert into public.tilbudsforesporsel_revisjon (id, foresporsel_id, handling) values ('ac332947-0000-4000-8000-0000ac332947', '45ca0ea5-0000-4000-8000-000045ca0ea5', 'sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbudsforesporsel_revisjon manager_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''45ca0ea6-0000-4000-8000-000045ca0ea6'', ''sonde'')');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 UPDATE den globale raden', 'update public.tilbudsforesporsel_revisjon set endringer = ''{}''::jsonb where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon manager_B1 DELETE den globale raden', 'delete from public.tilbudsforesporsel_revisjon where id = ''ac332947-0000-4000-8000-0000ac332947''', 'tilbudsforesporsel_revisjon', 'ac332947-0000-4000-8000-0000ac332947', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbudsforesporsel_revisjon tablet_B1 SELECT den globale raden -> ser ikke', not exists (select 1 from public.tilbudsforesporsel_revisjon where id = 'ac332947-0000-4000-8000-0000ac332947'), 'negativ');
select pg_temp.skriv_avvist('tilbudsforesporsel_revisjon tablet_B1 INSERT den globale raden', 'insert into public.tilbudsforesporsel_revisjon (foresporsel_id, handling) values (''45ca0ebe-0000-4000-8000-000045ca0ebe'', ''sonde'')');
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
