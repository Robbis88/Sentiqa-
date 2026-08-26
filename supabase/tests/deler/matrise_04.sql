-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 4 AV 6. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 8 ressurs(er):
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a140d0a-0000-4000-8000-00009a140d0a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a1410cc-0000-4000-8000-00009a1410cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14148e-0000-4000-8000-00009a14148e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14816c-0000-4000-8000-00009a14816c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14852e-0000-4000-8000-00009a14852e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643f07-0000-4000-8000-00004b643f07', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01608-0000-4000-8000-00002be01608', 'aaaa0000-0000-4000-8000-000000000000', '4b643f07-0000-4000-8000-00004b643f07', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b367-0000-4000-8000-00004b64b367', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08a68-0000-4000-8000-00002be08a68', 'aaaa0000-0000-4000-8000-000000000000', '4b64b367-0000-4000-8000-00004b64b367', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6527c7-0000-4000-8000-00004b6527c7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0fec8-0000-4000-8000-00002be0fec8', 'aaaa0000-0000-4000-8000-000000000000', '4b6527c7-0000-4000-8000-00004b6527c7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72568b-0000-4000-8000-00004b72568b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2d8c-0000-4000-8000-00002bee2d8c', 'bbbb0000-0000-4000-8000-000000000000', '4b72568b-0000-4000-8000-00004b72568b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72caeb-0000-4000-8000-00004b72caeb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2beea1ec-0000-4000-8000-00002beea1ec', 'bbbb0000-0000-4000-8000-000000000000', '4b72caeb-0000-4000-8000-00004b72caeb', date '2026-08-01', date '2026-08-31');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4e22-0000-4000-8000-00009e8f4e22', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc282-0000-4000-8000-00009e8fc282', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9036e2-0000-4000-8000-00009e9036e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d65a6-0000-4000-8000-00009e9d65a6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9dda06-0000-4000-8000-00009e9dda06', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.merker (id, retailer_id, navn) values ('7589c17f-0000-4000-8000-00007589c17f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 30');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48aeca-0000-4000-8000-00004c48aeca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-30', 'pin-merke-30');
insert into public.merker (id, retailer_id, navn) values ('758a35df-0000-4000-8000-0000758a35df', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 31');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49232a-0000-4000-8000-00004c49232a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-31', 'pin-merke-31');
insert into public.merker (id, retailer_id, navn) values ('758aaa3f-0000-4000-8000-0000758aaa3f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 32');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49978a-0000-4000-8000-00004c49978a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-32', 'pin-merke-32');
insert into public.merker (id, retailer_id, navn) values ('7597d903-0000-4000-8000-00007597d903', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 33');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c64e-0000-4000-8000-00004c56c64e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-33', 'pin-merke-33');
insert into public.merker (id, retailer_id, navn) values ('75984d63-0000-4000-8000-000075984d63', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 34');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573aae-0000-4000-8000-00004c573aae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-34', 'pin-merke-34');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e48c-0000-4000-8000-00001a99e48c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a58ec-0000-4000-8000-00001a9a58ec', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acd4c-0000-4000-8000-00001a9acd4c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fc10-0000-4000-8000-00001aa7fc10', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87070-0000-4000-8000-00001aa87070', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d948a-0000-4000-8000-0000a86d948a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08ea-0000-4000-8000-0000a86e08ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d4a-0000-4000-8000-0000a86e7d4a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac0e-0000-4000-8000-0000a87bac0e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d948e-0000-4000-8000-0000a86d948e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0903-0000-4000-8000-0000a86e0903', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d63-0000-4000-8000-0000a86e7d63', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94a6-0000-4000-8000-0000a86d94a6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0906-0000-4000-8000-0000a86e0906', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d66-0000-4000-8000-0000a86e7d66', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac2a-0000-4000-8000-0000a87bac2a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94aa-0000-4000-8000-0000a86d94aa', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94ab-0000-4000-8000-0000a86d94ab', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e090b-0000-4000-8000-0000a86e090b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d6b-0000-4000-8000-0000a86e7d6b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac44-0000-4000-8000-0000a87bac44', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94c4-0000-4000-8000-0000a86d94c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0924-0000-4000-8000-0000a86e0924', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94c6-0000-4000-8000-0000a86d94c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0926-0000-4000-8000-0000a86e0926', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d86-0000-4000-8000-0000a86e7d86', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac4a-0000-4000-8000-0000a87bac4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac4b-0000-4000-8000-0000a87bac4b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c20ab-0000-4000-8000-0000a87c20ab', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94cc-0000-4000-8000-0000a86d94cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac63-0000-4000-8000-0000a87bac63', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c20c3-0000-4000-8000-0000a87c20c3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac65-0000-4000-8000-0000a87bac65', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c20c5-0000-4000-8000-0000a87c20c5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94e6-0000-4000-8000-0000a86d94e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac68-0000-4000-8000-0000a87bac68', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac69-0000-4000-8000-0000a87bac69', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c20c9-0000-4000-8000-0000a87c20c9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94ea-0000-4000-8000-0000a86d94ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b644008-0000-4000-8000-00004b644008', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01709-0000-4000-8000-00002be01709', 'aaaa0000-0000-4000-8000-000000000000', '4b644008-0000-4000-8000-00004b644008', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131b98a-0000-4000-8000-00002131b98a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c2a9-0000-4000-8000-00005030c2a9', 'aaaa0000-0000-4000-8000-000000000000', '2131b98a-0000-4000-8000-00002131b98a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd10c-0000-4000-8000-0000213fd10c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503eda2b-0000-4000-8000-0000503eda2b', 'aaaa0000-0000-4000-8000-000000000000', '213fd10c-0000-4000-8000-0000213fd10c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aaa-0000-4000-8000-000022d87aaa', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783c9-0000-4000-8000-000051d783c9', 'bbbb0000-0000-4000-8000-000000000000', '22d87aaa-0000-4000-8000-000022d87aaa', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a20c-0000-4000-8000-00002123a20c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab2b-0000-4000-8000-00005022ab2b', 'aaaa0000-0000-4000-8000-000000000000', '2123a20c-0000-4000-8000-00002123a20c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131b98e-0000-4000-8000-00002131b98e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c2ad-0000-4000-8000-00005030c2ad', 'aaaa0000-0000-4000-8000-000000000000', '2131b98e-0000-4000-8000-00002131b98e', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd110-0000-4000-8000-0000213fd110', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503eda2f-0000-4000-8000-0000503eda2f', 'aaaa0000-0000-4000-8000-000000000000', '213fd110-0000-4000-8000-0000213fd110', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aae-0000-4000-8000-000022d87aae', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783cd-0000-4000-8000-000051d783cd', 'bbbb0000-0000-4000-8000-000000000000', '22d87aae-0000-4000-8000-000022d87aae', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a210-0000-4000-8000-00002123a210', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab2f-0000-4000-8000-00005022ab2f', 'aaaa0000-0000-4000-8000-000000000000', '2123a210-0000-4000-8000-00002123a210', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131b992-0000-4000-8000-00002131b992', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c2b1-0000-4000-8000-00005030c2b1', 'aaaa0000-0000-4000-8000-000000000000', '2131b992-0000-4000-8000-00002131b992', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd114-0000-4000-8000-0000213fd114', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503eda33-0000-4000-8000-0000503eda33', 'aaaa0000-0000-4000-8000-000000000000', '213fd114-0000-4000-8000-0000213fd114', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ac7-0000-4000-8000-000022d87ac7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783e6-0000-4000-8000-000051d783e6', 'bbbb0000-0000-4000-8000-000000000000', '22d87ac7-0000-4000-8000-000022d87ac7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a229-0000-4000-8000-00002123a229', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab48-0000-4000-8000-00005022ab48', 'aaaa0000-0000-4000-8000-000000000000', '2123a229-0000-4000-8000-00002123a229', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131b9ab-0000-4000-8000-00002131b9ab', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c2ca-0000-4000-8000-00005030c2ca', 'aaaa0000-0000-4000-8000-000000000000', '2131b9ab-0000-4000-8000-00002131b9ab', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd12d-0000-4000-8000-0000213fd12d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503eda4c-0000-4000-8000-0000503eda4c', 'aaaa0000-0000-4000-8000-000000000000', '213fd12d-0000-4000-8000-0000213fd12d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87acb-0000-4000-8000-000022d87acb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783ea-0000-4000-8000-000051d783ea', 'bbbb0000-0000-4000-8000-000000000000', '22d87acb-0000-4000-8000-000022d87acb', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87acc-0000-4000-8000-000022d87acc', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783eb-0000-4000-8000-000051d783eb', 'bbbb0000-0000-4000-8000-000000000000', '22d87acc-0000-4000-8000-000022d87acc', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6924e-0000-4000-8000-000022e6924e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b6d-0000-4000-8000-000051e59b6d', 'bbbb0000-0000-4000-8000-000000000000', '22e6924e-0000-4000-8000-000022e6924e', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a22f-0000-4000-8000-00002123a22f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab4e-0000-4000-8000-00005022ab4e', 'aaaa0000-0000-4000-8000-000000000000', '2123a22f-0000-4000-8000-00002123a22f', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87acf-0000-4000-8000-000022d87acf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783ee-0000-4000-8000-000051d783ee', 'bbbb0000-0000-4000-8000-000000000000', '22d87acf-0000-4000-8000-000022d87acf', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69251-0000-4000-8000-000022e69251', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b70-0000-4000-8000-000051e59b70', 'bbbb0000-0000-4000-8000-000000000000', '22e69251-0000-4000-8000-000022e69251', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a247-0000-4000-8000-00002123a247', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab66-0000-4000-8000-00005022ab66', 'aaaa0000-0000-4000-8000-000000000000', '2123a247-0000-4000-8000-00002123a247', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ae7-0000-4000-8000-000022d87ae7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78406-0000-4000-8000-000051d78406', 'bbbb0000-0000-4000-8000-000000000000', '22d87ae7-0000-4000-8000-000022d87ae7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69269-0000-4000-8000-000022e69269', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b88-0000-4000-8000-000051e59b88', 'bbbb0000-0000-4000-8000-000000000000', '22e69269-0000-4000-8000-000022e69269', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a24a-0000-4000-8000-00002123a24a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab69-0000-4000-8000-00005022ab69', 'aaaa0000-0000-4000-8000-000000000000', '2123a24a-0000-4000-8000-00002123a24a', date '2026-08-01', date '2026-08-31');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a730b-0000-4000-8000-0000335a730b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a8d-0000-4000-8000-000033688a8d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a20f-0000-4000-8000-00003376a20f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4bad-0000-4000-8000-0000350f4bad', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a730f-0000-4000-8000-0000335a730f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a91-0000-4000-8000-000033688a91', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a213-0000-4000-8000-00003376a213', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7312-0000-4000-8000-0000335a7312', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688d34-0000-4000-8000-000033688d34', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a4b6-0000-4000-8000-00003376a4b6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e54-0000-4000-8000-0000350f4e54', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75b6-0000-4000-8000-0000335a75b6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75b7-0000-4000-8000-0000335a75b7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688d39-0000-4000-8000-000033688d39', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a4bb-0000-4000-8000-00003376a4bb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e59-0000-4000-8000-0000350f4e59', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75bb-0000-4000-8000-0000335a75bb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688d3d-0000-4000-8000-000033688d3d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75d2-0000-4000-8000-0000335a75d2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688d54-0000-4000-8000-000033688d54', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a4d6-0000-4000-8000-00003376a4d6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e74-0000-4000-8000-0000350f4e74', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75d6-0000-4000-8000-0000335a75d6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e76-0000-4000-8000-0000350f4e76', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65f8-0000-4000-8000-0000351d65f8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75d9-0000-4000-8000-0000335a75d9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e79-0000-4000-8000-0000350f4e79', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65fb-0000-4000-8000-0000351d65fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e90-0000-4000-8000-0000350f4e90', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6612-0000-4000-8000-0000351d6612', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75f3-0000-4000-8000-0000335a75f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e93-0000-4000-8000-0000350f4e93', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e94-0000-4000-8000-0000350f4e94', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6616-0000-4000-8000-0000351d6616', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75f7-0000-4000-8000-0000335a75f7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e97-0000-4000-8000-0000350f4e97', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.merker (id, retailer_id, navn) values ('3bae6b16-0000-4000-8000-00003bae6b16', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 228');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd272b-0000-4000-8000-00003ccd272b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-228', 'pin-merke-228');
insert into public.merker (id, retailer_id, navn) values ('3bbc8298-0000-4000-8000-00003bbc8298', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 229');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ead-0000-4000-8000-00003cdb3ead', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-229', 'pin-merke-229');
insert into public.merker (id, retailer_id, navn) values ('3bca9a2f-0000-4000-8000-00003bca9a2f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 230');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce95644-0000-4000-8000-00003ce95644', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-230', 'pin-merke-230');
insert into public.merker (id, retailer_id, navn) values ('3d6343cd-0000-4000-8000-00003d6343cd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 231');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81ffe2-0000-4000-8000-00003e81ffe2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-231', 'pin-merke-231');
insert into public.merker (id, retailer_id, navn) values ('3bae6b2f-0000-4000-8000-00003bae6b2f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 232');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2744-0000-4000-8000-00003ccd2744', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-232', 'pin-merke-232');
insert into public.merker (id, retailer_id, navn) values ('3bbc82b1-0000-4000-8000-00003bbc82b1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 233');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ec6-0000-4000-8000-00003cdb3ec6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-233', 'pin-merke-233');
insert into public.merker (id, retailer_id, navn) values ('3bca9a33-0000-4000-8000-00003bca9a33', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 234');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce95648-0000-4000-8000-00003ce95648', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-234', 'pin-merke-234');
insert into public.merker (id, retailer_id, navn) values ('3bae6b32-0000-4000-8000-00003bae6b32', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 235');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2747-0000-4000-8000-00003ccd2747', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-235', 'pin-merke-235');
insert into public.merker (id, retailer_id, navn) values ('3bbc82b4-0000-4000-8000-00003bbc82b4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 236');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ec9-0000-4000-8000-00003cdb3ec9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-236', 'pin-merke-236');
insert into public.merker (id, retailer_id, navn) values ('3bca9a36-0000-4000-8000-00003bca9a36', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 237');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce9564b-0000-4000-8000-00003ce9564b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-237', 'pin-merke-237');
insert into public.merker (id, retailer_id, navn) values ('3d6343d4-0000-4000-8000-00003d6343d4', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 238');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81ffe9-0000-4000-8000-00003e81ffe9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-238', 'pin-merke-238');
insert into public.merker (id, retailer_id, navn) values ('3bae6b36-0000-4000-8000-00003bae6b36', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 239');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd274b-0000-4000-8000-00003ccd274b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-239', 'pin-merke-239');
insert into public.merker (id, retailer_id, navn) values ('3bae6b4c-0000-4000-8000-00003bae6b4c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 240');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2761-0000-4000-8000-00003ccd2761', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-240', 'pin-merke-240');
insert into public.merker (id, retailer_id, navn) values ('3bbc82ce-0000-4000-8000-00003bbc82ce', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 241');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ee3-0000-4000-8000-00003cdb3ee3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-241', 'pin-merke-241');
insert into public.merker (id, retailer_id, navn) values ('3bca9a50-0000-4000-8000-00003bca9a50', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 242');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce95665-0000-4000-8000-00003ce95665', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-242', 'pin-merke-242');
insert into public.merker (id, retailer_id, navn) values ('3d6343ee-0000-4000-8000-00003d6343ee', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 243');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820003-0000-4000-8000-00003e820003', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-243', 'pin-merke-243');
insert into public.merker (id, retailer_id, navn) values ('3bae6b50-0000-4000-8000-00003bae6b50', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 244');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2765-0000-4000-8000-00003ccd2765', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-244', 'pin-merke-244');
insert into public.merker (id, retailer_id, navn) values ('3bbc82d2-0000-4000-8000-00003bbc82d2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 245');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ee7-0000-4000-8000-00003cdb3ee7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-245', 'pin-merke-245');
insert into public.merker (id, retailer_id, navn) values ('3bae6b52-0000-4000-8000-00003bae6b52', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 246');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2767-0000-4000-8000-00003ccd2767', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-246', 'pin-merke-246');
insert into public.merker (id, retailer_id, navn) values ('3bbc82d4-0000-4000-8000-00003bbc82d4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 247');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3ee9-0000-4000-8000-00003cdb3ee9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-247', 'pin-merke-247');
insert into public.merker (id, retailer_id, navn) values ('3bca9a56-0000-4000-8000-00003bca9a56', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 248');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce9566b-0000-4000-8000-00003ce9566b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-248', 'pin-merke-248');
insert into public.merker (id, retailer_id, navn) values ('3d6343f4-0000-4000-8000-00003d6343f4', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 249');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820009-0000-4000-8000-00003e820009', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-249', 'pin-merke-249');
insert into public.merker (id, retailer_id, navn) values ('3d63440a-0000-4000-8000-00003d63440a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 250');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e82001f-0000-4000-8000-00003e82001f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-250', 'pin-merke-250');
insert into public.merker (id, retailer_id, navn) values ('3d715b8c-0000-4000-8000-00003d715b8c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 251');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017a1-0000-4000-8000-00003e9017a1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-251', 'pin-merke-251');
insert into public.merker (id, retailer_id, navn) values ('3bae6b6d-0000-4000-8000-00003bae6b6d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 252');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2782-0000-4000-8000-00003ccd2782', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-252', 'pin-merke-252');
insert into public.merker (id, retailer_id, navn) values ('3d63440d-0000-4000-8000-00003d63440d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 253');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820022-0000-4000-8000-00003e820022', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-253', 'pin-merke-253');
insert into public.merker (id, retailer_id, navn) values ('3d715b8f-0000-4000-8000-00003d715b8f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 254');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017a4-0000-4000-8000-00003e9017a4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-254', 'pin-merke-254');
insert into public.merker (id, retailer_id, navn) values ('3d63440f-0000-4000-8000-00003d63440f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 255');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820024-0000-4000-8000-00003e820024', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-255', 'pin-merke-255');
insert into public.merker (id, retailer_id, navn) values ('3d715b91-0000-4000-8000-00003d715b91', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 256');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017a6-0000-4000-8000-00003e9017a6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-256', 'pin-merke-256');
insert into public.merker (id, retailer_id, navn) values ('3bae6b72-0000-4000-8000-00003bae6b72', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 257');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2787-0000-4000-8000-00003ccd2787', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-257', 'pin-merke-257');
insert into public.merker (id, retailer_id, navn) values ('3d634412-0000-4000-8000-00003d634412', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 258');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820027-0000-4000-8000-00003e820027', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-258', 'pin-merke-258');
insert into public.merker (id, retailer_id, navn) values ('3d634413-0000-4000-8000-00003d634413', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 259');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820028-0000-4000-8000-00003e820028', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-259', 'pin-merke-259');
insert into public.merker (id, retailer_id, navn) values ('3d715baa-0000-4000-8000-00003d715baa', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 260');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017bf-0000-4000-8000-00003e9017bf', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-260', 'pin-merke-260');
insert into public.merker (id, retailer_id, navn) values ('3bae6b8b-0000-4000-8000-00003bae6b8b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 261');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27a0-0000-4000-8000-00003ccd27a0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-261', 'pin-merke-261');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a984-0000-4000-8000-000038a2a984', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c106-0000-4000-8000-000038b0c106', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed888-0000-4000-8000-000038bed888', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578226-0000-4000-8000-00003a578226', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a988-0000-4000-8000-000038a2a988', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c10a-0000-4000-8000-000038b0c10a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed88c-0000-4000-8000-000038bed88c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a57822a-0000-4000-8000-00003a57822a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9a1-0000-4000-8000-000038a2a9a1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c123-0000-4000-8000-000038b0c123', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8a5-0000-4000-8000-000038bed8a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578243-0000-4000-8000-00003a578243', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9a5-0000-4000-8000-000038a2a9a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c127-0000-4000-8000-000038b0c127', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8a9-0000-4000-8000-000038bed8a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578247-0000-4000-8000-00003a578247', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578248-0000-4000-8000-00003a578248', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6599ca-0000-4000-8000-00003a6599ca', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c0-0000-4000-8000-000038a2a9c0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578260-0000-4000-8000-00003a578260', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6599e2-0000-4000-8000-00003a6599e2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c3-0000-4000-8000-000038a2a9c3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578263-0000-4000-8000-00003a578263', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6599e5-0000-4000-8000-00003a6599e5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c6-0000-4000-8000-000038a2a9c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
-- --- tilbakemelding: forutsetninger og proberader ---
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc56-0000-4000-8000-0000bcf4dc56', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding fastA1');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc57-0000-4000-8000-0000bcf4dc57', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding fastA2');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc58-0000-4000-8000-0000bcf4dc58', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding fastA3');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc75-0000-4000-8000-0000bcf4dc75', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding fastB1');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc76-0000-4000-8000-0000bcf4dc76', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding fastB2');

create or replace function pg_temp.nyrad_tilbakemelding(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.tilbakemelding (retailer_id, stasjon_id, tekst)
  values (p_retailer, p_stasjon, 'Sondemelding ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- opplaering_skift: forutsetninger og proberader ---
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '9a140d0a-0000-4000-8000-00009a140d0a', date '2026-01-01' + 5);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '9a1410cc-0000-4000-8000-00009a1410cc', date '2026-01-01' + 6);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '9a14148e-0000-4000-8000-00009a14148e', date '2026-01-01' + 7);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '9a14816c-0000-4000-8000-00009a14816c', date '2026-01-01' + 8);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '9a14852e-0000-4000-8000-00009a14852e', date '2026-01-01' + 9);

create or replace function pg_temp.nyrad_opplaering_skift(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_periode uuid := gen_random_uuid();
begin
  insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values (v_periode, p_retailer, p_stasjon, 'Sonde Sondesen', date '2026-08-01');
  insert into public.opplaering_skift (periode_id, dato)
  values (v_periode, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- puls_svar: forutsetninger og proberader ---
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575b-0000-4000-8000-00003922575b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '2be01608-0000-4000-8000-00002be01608', 3, 'Sondesvar fastA1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575c-0000-4000-8000-00003922575c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '2be08a68-0000-4000-8000-00002be08a68', 3, 'Sondesvar fastA2');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575d-0000-4000-8000-00003922575d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '2be0fec8-0000-4000-8000-00002be0fec8', 3, 'Sondesvar fastA3');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577a-0000-4000-8000-00003922577a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '2bee2d8c-0000-4000-8000-00002bee2d8c', 3, 'Sondesvar fastB1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577b-0000-4000-8000-00003922577b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '2beea1ec-0000-4000-8000-00002beea1ec', 3, 'Sondesvar fastB2');

create or replace function pg_temp.nyrad_puls_svar(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_sporsmal uuid := gen_random_uuid();
  v_runde uuid := gen_random_uuid();
begin
  insert into public.puls_sporsmal (id, retailer_id, tekst) values (v_sporsmal, p_retailer, 'Sondesporsmaal');
  insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values (v_runde, p_retailer, v_sporsmal, date '2026-08-01', date '2026-08-31');
  insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar)
  values (p_retailer, p_stasjon, v_runde, 3, 'Sondesvar ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- rutiner: forutsetninger og proberader ---
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine fastA1');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine fastA2');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62219-0000-4000-8000-000023d62219', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine fastA3');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine fastB1');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62237-0000-4000-8000-000023d62237', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine fastB2');

create or replace function pg_temp.nyrad_rutiner(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.rutiner (retailer_id, stasjon_id, tittel)
  values (p_retailer, p_stasjon, 'Sonderutine ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- oppgaver: forutsetninger og proberader ---
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave fastA1');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave fastA2');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7b0-0000-4000-8000-000021faa7b0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeoppgave fastA3');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave fastB1');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ce-0000-4000-8000-000021faa7ce', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeoppgave fastB2');

create or replace function pg_temp.nyrad_oppgaver(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.oppgaver (retailer_id, stasjon_id, tittel)
  values (p_retailer, p_stasjon, 'Sondeoppgave ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- sjekkpunkt_svar: forutsetninger og proberader ---
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4e22-0000-4000-8000-00009e8f4e22', date '2026-01-01' + 25, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc282-0000-4000-8000-00009e8fc282', date '2026-01-01' + 26, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '9e9036e2-0000-4000-8000-00009e9036e2', date '2026-01-01' + 27, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '9e9d65a6-0000-4000-8000-00009e9d65a6', date '2026-01-01' + 28, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '9e9dda06-0000-4000-8000-00009e9dda06', date '2026-01-01' + 29, true);

create or replace function pg_temp.nyrad_sjekkpunkt_svar(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_sjekkpunkt uuid := gen_random_uuid();
begin
  insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values (v_sjekkpunkt, p_retailer, p_stasjon, 'Sondesporsmaal');
  insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar)
  values (p_stasjon, v_sjekkpunkt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, true)
  returning id into ny;
  return ny;
end $fn$;
-- --- tildelte_merker: forutsetninger og proberader ---
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c17f-0000-4000-8000-00007589c17f', '4c48aeca-0000-4000-8000-00004c48aeca', date '2026-01-01' + 30);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a35df-0000-4000-8000-0000758a35df', '4c49232a-0000-4000-8000-00004c49232a', date '2026-01-01' + 31);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa3f-0000-4000-8000-0000758aaa3f', '4c49978a-0000-4000-8000-00004c49978a', date '2026-01-01' + 32);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d903-0000-4000-8000-00007597d903', '4c56c64e-0000-4000-8000-00004c56c64e', date '2026-01-01' + 33);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984d63-0000-4000-8000-000075984d63', '4c573aae-0000-4000-8000-00004c573aae', date '2026-01-01' + 34);

create or replace function pg_temp.nyrad_tildelte_merker(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_merke uuid := gen_random_uuid();
  v_ansatt uuid := gen_random_uuid();
begin
  insert into public.merker (id, retailer_id, navn) values (v_merke, p_retailer, 'Sondemerke ' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (v_ansatt, p_retailer, p_stasjon, 'Sondeansatt', 'merke-' || 'rt' || nextval('tenant_teller'::regclass) || '', 'pin-merke-' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato)
  values (p_stasjon, v_merke, v_ansatt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- ik_avlesninger: forutsetninger og proberader ---
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '1a99e48c-0000-4000-8000-00001a99e48c', date '2026-01-01' + 35, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '1a9a58ec-0000-4000-8000-00001a9a58ec', date '2026-01-01' + 36, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '1a9acd4c-0000-4000-8000-00001a9acd4c', date '2026-01-01' + 37, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '1aa7fc10-0000-4000-8000-00001aa7fc10', date '2026-01-01' + 38, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '1aa87070-0000-4000-8000-00001aa87070', date '2026-01-01' + 39, 4.0, true);

-- =====================================================================
-- tilbakemelding  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbakemelding');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbakemelding owner_A SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT A2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT A3 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AA1'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_AA2'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding owner_AA3'')');
select pg_temp.skriv_avvist('tilbakemelding owner_A INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tilbakemelding owner_A UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding owner_A FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_A1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1A1'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A1A2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A1A3'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tilbakemelding manager_A1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''', 'tilbakemelding', 'bcf4dc57-0000-4000-8000-0000bcf4dc57', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tilbakemelding set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12A1'')');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A12A2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A12A3'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tilbakemelding set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding tablet_A1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1A1'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_A1A2'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding tablet_A1A3'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''', 'tilbakemelding', 'bcf4dc57-0000-4000-8000-0000bcf4dc57', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbakemelding owner_B SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_B SELECT B2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding owner_B INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BB1'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_B INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_BB2'')');
select pg_temp.skriv_avvist('tilbakemelding owner_B INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tilbakemelding owner_B UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tilbakemelding owner_B UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tilbakemelding owner_B UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding owner_B FLYTTER egen rad -> kjede A', 'update public.tilbakemelding set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbakemelding manager_B1 SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_B1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1B1'')');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_B1B2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tilbakemelding manager_B1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''', 'tilbakemelding', 'bcf4dc76-0000-4000-8000-0000bcf4dc76', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tilbakemelding set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 FLYTTER egen rad -> kjede A', 'update public.tilbakemelding set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding tablet_B1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1B1'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_B1B2'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''', 'tilbakemelding', 'bcf4dc76-0000-4000-8000-0000bcf4dc76', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

-- =====================================================================
-- opplaering_skift  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_skift');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_skift owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d948a-0000-4000-8000-0000a86d948a'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e08ea-0000-4000-8000-0000a86e08ea'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d4a-0000-4000-8000-0000a86e7d4a'', date ''2026-01-01'' + 67)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac0e-0000-4000-8000-0000a87bac0e'', date ''2026-01-01'' + 68)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_skift owner_A UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d948e-0000-4000-8000-0000a86d948e', date '2026-01-01' + 69);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e0903-0000-4000-8000-0000a86e0903', date '2026-01-01' + 70);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7d63-0000-4000-8000-0000a86e7d63', date '2026-01-01' + 71);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_skift owner_A DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94a6-0000-4000-8000-0000a86d94a6'', date ''2026-01-01'' + 72)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e0906-0000-4000-8000-0000a86e0906'', date ''2026-01-01'' + 73)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d66-0000-4000-8000-0000a86e7d66'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac2a-0000-4000-8000-0000a87bac2a'', date ''2026-01-01'' + 75)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d94aa-0000-4000-8000-0000a86d94aa', date '2026-01-01' + 76);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94ab-0000-4000-8000-0000a86d94ab'', date ''2026-01-01'' + 77)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e090b-0000-4000-8000-0000a86e090b'', date ''2026-01-01'' + 78)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d6b-0000-4000-8000-0000a86e7d6b'', date ''2026-01-01'' + 79)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac44-0000-4000-8000-0000a87bac44'', date ''2026-01-01'' + 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d94c4-0000-4000-8000-0000a86d94c4', date '2026-01-01' + 81);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e0924-0000-4000-8000-0000a86e0924', date '2026-01-01' + 82);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94c6-0000-4000-8000-0000a86d94c6'', date ''2026-01-01'' + 83)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e0926-0000-4000-8000-0000a86e0926'', date ''2026-01-01'' + 84)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d86-0000-4000-8000-0000a86e7d86'', date ''2026-01-01'' + 85)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac4a-0000-4000-8000-0000a87bac4a'', date ''2026-01-01'' + 86)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_skift owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac4b-0000-4000-8000-0000a87bac4b'', date ''2026-01-01'' + 87)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c20ab-0000-4000-8000-0000a87c20ab'', date ''2026-01-01'' + 88)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94cc-0000-4000-8000-0000a86d94cc'', date ''2026-01-01'' + 89)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87bac63-0000-4000-8000-0000a87bac63', date '2026-01-01' + 90);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', 'a87c20c3-0000-4000-8000-0000a87c20c3', date '2026-01-01' + 91);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac65-0000-4000-8000-0000a87bac65'', date ''2026-01-01'' + 92)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c20c5-0000-4000-8000-0000a87c20c5'', date ''2026-01-01'' + 93)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94e6-0000-4000-8000-0000a86d94e6'', date ''2026-01-01'' + 94)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87bac68-0000-4000-8000-0000a87bac68', date '2026-01-01' + 95);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac69-0000-4000-8000-0000a87bac69'', date ''2026-01-01'' + 96)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c20c9-0000-4000-8000-0000a87c20c9'', date ''2026-01-01'' + 97)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94ea-0000-4000-8000-0000a86d94ea'', date ''2026-01-01'' + 98)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

-- =====================================================================
-- puls_svar  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_svar owner_A SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A2 -> ser', exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A3 -> ser', exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be01709-0000-4000-8000-00002be01709'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c2a9-0000-4000-8000-00005030c2a9'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503eda2b-0000-4000-8000-0000503eda2b'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783c9-0000-4000-8000-000051d783c9'', 3, ''Sondesvar owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_svar manager_A1 SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'negativ');
select pg_temp.paastand('puls_svar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab2b-0000-4000-8000-00005022ab2b'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c2ad-0000-4000-8000-00005030c2ad'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503eda2f-0000-4000-8000-0000503eda2f'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783cd-0000-4000-8000-000051d783cd'', 3, ''Sondesvar manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_svar manager_A12 SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar manager_A12 SELECT A2 -> ser', exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'positiv');
select pg_temp.paastand('puls_svar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab2f-0000-4000-8000-00005022ab2f'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c2b1-0000-4000-8000-00005030c2b1'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503eda33-0000-4000-8000-0000503eda33'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783e6-0000-4000-8000-000051d783e6'', 3, ''Sondesvar manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_svar tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab48-0000-4000-8000-00005022ab48'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c2ca-0000-4000-8000-00005030c2ca'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503eda4c-0000-4000-8000-0000503eda4c'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783ea-0000-4000-8000-000051d783ea'', 3, ''Sondesvar tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('puls_svar owner_B SELECT B1 -> ser', exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'positiv');
select pg_temp.paastand('puls_svar owner_B SELECT B2 -> ser', exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'positiv');
select pg_temp.paastand('puls_svar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783eb-0000-4000-8000-000051d783eb'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b6d-0000-4000-8000-000051e59b6d'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab4e-0000-4000-8000-00005022ab4e'', 3, ''Sondesvar owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'positiv');
select pg_temp.paastand('puls_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'negativ');
select pg_temp.paastand('puls_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783ee-0000-4000-8000-000051d783ee'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b70-0000-4000-8000-000051e59b70'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab66-0000-4000-8000-00005022ab66'', 3, ''Sondesvar manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_svar tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.paastand('puls_svar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'negativ');
select pg_temp.paastand('puls_svar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78406-0000-4000-8000-000051d78406'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b88-0000-4000-8000-000051e59b88'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab69-0000-4000-8000-00005022ab69'', 3, ''Sondesvar tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

-- =====================================================================
-- rutiner  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutiner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutiner owner_A SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT A2 -> ser', exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT A3 -> ser', exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_AA1'')');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine owner_AA2'')');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine owner_AA3'')');
select pg_temp.skriv_avvist('rutiner owner_A INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutiner owner_A UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62219-0000-4000-8000-000023d62219', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutiner owner_A DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner owner_A FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutiner manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'negativ');
select pg_temp.paastand('rutiner manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_A1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A1A1'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_A1A2'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine manager_A1A3'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutiner manager_A1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutiner manager_A1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutiner set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_A1 FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutiner manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'positiv');
select pg_temp.paastand('rutiner manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_A12 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A12A1'')');
select pg_temp.skriv_tillatt('rutiner manager_A12 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_A12A2'')');
select pg_temp.skriv_avvist('rutiner manager_A12 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine manager_A12A3'')');
select pg_temp.skriv_avvist('rutiner manager_A12 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutiner set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_A12 FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutiner tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'negativ');
select pg_temp.paastand('rutiner tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_A1A1'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine tablet_A1A2'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine tablet_A1A3'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutiner owner_B SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner owner_B SELECT B2 -> ser', exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'positiv');
select pg_temp.paastand('rutiner owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_tillatt('rutiner owner_B INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_BB1'')');
select pg_temp.skriv_tillatt('rutiner owner_B INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine owner_BB2'')');
select pg_temp.skriv_avvist('rutiner owner_B INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutiner owner_B UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62237-0000-4000-8000-000023d62237', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutiner owner_B DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner owner_B FLYTTER egen rad -> kjede A', 'update public.rutiner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutiner manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'negativ');
select pg_temp.paastand('rutiner manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_B1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_B1B1'')');
select pg_temp.skriv_avvist('rutiner manager_B1 INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_B1B2'')');
select pg_temp.skriv_avvist('rutiner manager_B1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutiner manager_B1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutiner manager_B1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutiner set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_B1 FLYTTER egen rad -> kjede A', 'update public.rutiner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutiner tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'negativ');
select pg_temp.paastand('rutiner tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_B1B1'')');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine tablet_B1B2'')');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

-- =====================================================================
-- oppgaver  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('oppgaver');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('oppgaver owner_A SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT A2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT A3 -> ser', exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_AA1'')');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave owner_AA2'')');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave owner_AA3'')');
select pg_temp.skriv_avvist('oppgaver owner_A INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('oppgaver owner_A UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7b0-0000-4000-8000-000021faa7b0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeoppgave gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('oppgaver owner_A DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver owner_A FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('oppgaver manager_A1 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'negativ');
select pg_temp.paastand('oppgaver manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_A1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A1A1'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_A1A2'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave manager_A1A3'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('oppgaver manager_A1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('oppgaver manager_A1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A1 FLYTTER egen rad A1 -> A2', 'update public.oppgaver set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A1 FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('oppgaver manager_A12 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver manager_A12 SELECT A2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'positiv');
select pg_temp.paastand('oppgaver manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_A12 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A12A1'')');
select pg_temp.skriv_tillatt('oppgaver manager_A12 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_A12A2'')');
select pg_temp.skriv_avvist('oppgaver manager_A12 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave manager_A12A3'')');
select pg_temp.skriv_avvist('oppgaver manager_A12 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A12 FLYTTER egen rad A1 -> A3', 'update public.oppgaver set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A12 FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('oppgaver tablet_A1 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'negativ');
select pg_temp.paastand('oppgaver tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_A1A1'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave tablet_A1A2'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave tablet_A1A3'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('oppgaver owner_B SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver owner_B SELECT B2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'positiv');
select pg_temp.paastand('oppgaver owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver owner_B INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_BB1'')');
select pg_temp.skriv_tillatt('oppgaver owner_B INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave owner_BB2'')');
select pg_temp.skriv_avvist('oppgaver owner_B INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('oppgaver owner_B UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ce-0000-4000-8000-000021faa7ce', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('oppgaver owner_B DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver owner_B FLYTTER egen rad -> kjede A', 'update public.oppgaver set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('oppgaver manager_B1 SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'negativ');
select pg_temp.paastand('oppgaver manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_B1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_B1B1'')');
select pg_temp.skriv_avvist('oppgaver manager_B1 INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_B1B2'')');
select pg_temp.skriv_avvist('oppgaver manager_B1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('oppgaver manager_B1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('oppgaver manager_B1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_B1 FLYTTER egen rad B1 -> B2', 'update public.oppgaver set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_B1 FLYTTER egen rad -> kjede A', 'update public.oppgaver set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('oppgaver tablet_B1 SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'negativ');
select pg_temp.paastand('oppgaver tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_B1B1'')');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave tablet_B1B2'')');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

-- =====================================================================
-- sjekkpunkt_svar  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('sjekkpunkt_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A3 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a730b-0000-4000-8000-0000335a730b'', date ''2026-01-01'' + 192, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688a8d-0000-4000-8000-000033688a8d'', date ''2026-01-01'' + 193, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a20f-0000-4000-8000-00003376a20f'', date ''2026-01-01'' + 194, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4bad-0000-4000-8000-0000350f4bad'', date ''2026-01-01'' + 195, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a730f-0000-4000-8000-0000335a730f', date '2026-01-01' + 196, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688a91-0000-4000-8000-000033688a91', date '2026-01-01' + 197, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '3376a213-0000-4000-8000-00003376a213', date '2026-01-01' + 198, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7312-0000-4000-8000-0000335a7312'', date ''2026-01-01'' + 199, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688d34-0000-4000-8000-000033688d34'', date ''2026-01-01'' + 200, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a4b6-0000-4000-8000-00003376a4b6'', date ''2026-01-01'' + 201, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e54-0000-4000-8000-0000350f4e54'', date ''2026-01-01'' + 202, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a75b6-0000-4000-8000-0000335a75b6', date '2026-01-01' + 203, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 FLYTTER egen rad A1 -> A2', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75b7-0000-4000-8000-0000335a75b7'', date ''2026-01-01'' + 204, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688d39-0000-4000-8000-000033688d39'', date ''2026-01-01'' + 205, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a4bb-0000-4000-8000-00003376a4bb'', date ''2026-01-01'' + 206, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e59-0000-4000-8000-0000350f4e59'', date ''2026-01-01'' + 207, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a75bb-0000-4000-8000-0000335a75bb', date '2026-01-01' + 208, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688d3d-0000-4000-8000-000033688d3d', date '2026-01-01' + 209, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 FLYTTER egen rad A1 -> A3', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75d2-0000-4000-8000-0000335a75d2'', date ''2026-01-01'' + 210, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688d54-0000-4000-8000-000033688d54'', date ''2026-01-01'' + 211, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a4d6-0000-4000-8000-00003376a4d6'', date ''2026-01-01'' + 212, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e74-0000-4000-8000-0000350f4e74'', date ''2026-01-01'' + 213, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a75d6-0000-4000-8000-0000335a75d6', date '2026-01-01' + 214, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT B2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e76-0000-4000-8000-0000350f4e76'', date ''2026-01-01'' + 215, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d65f8-0000-4000-8000-0000351d65f8'', date ''2026-01-01'' + 216, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75d9-0000-4000-8000-0000335a75d9'', date ''2026-01-01'' + 217, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e79-0000-4000-8000-0000350f4e79', date '2026-01-01' + 218, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '351d65fb-0000-4000-8000-0000351d65fb', date '2026-01-01' + 219, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e90-0000-4000-8000-0000350f4e90'', date ''2026-01-01'' + 220, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6612-0000-4000-8000-0000351d6612'', date ''2026-01-01'' + 221, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75f3-0000-4000-8000-0000335a75f3'', date ''2026-01-01'' + 222, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e93-0000-4000-8000-0000350f4e93', date '2026-01-01' + 223, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 FLYTTER egen rad B1 -> B2', 'update public.sjekkpunkt_svar set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e94-0000-4000-8000-0000350f4e94'', date ''2026-01-01'' + 224, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6616-0000-4000-8000-0000351d6616'', date ''2026-01-01'' + 225, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75f7-0000-4000-8000-0000335a75f7'', date ''2026-01-01'' + 226, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e97-0000-4000-8000-0000350f4e97', date '2026-01-01' + 227, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.sjekkpunkt_svar set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

-- =====================================================================
-- tildelte_merker  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tildelte_merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tildelte_merker owner_A SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A3 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b16-0000-4000-8000-00003bae6b16'', ''3ccd272b-0000-4000-8000-00003ccd272b'', date ''2026-01-01'' + 228)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc8298-0000-4000-8000-00003bbc8298'', ''3cdb3ead-0000-4000-8000-00003cdb3ead'', date ''2026-01-01'' + 229)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a2f-0000-4000-8000-00003bca9a2f'', ''3ce95644-0000-4000-8000-00003ce95644'', date ''2026-01-01'' + 230)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d6343cd-0000-4000-8000-00003d6343cd'', ''3e81ffe2-0000-4000-8000-00003e81ffe2'', date ''2026-01-01'' + 231)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tildelte_merker owner_A UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6b2f-0000-4000-8000-00003bae6b2f', '3ccd2744-0000-4000-8000-00003ccd2744', date '2026-01-01' + 232);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc82b1-0000-4000-8000-00003bbc82b1', '3cdb3ec6-0000-4000-8000-00003cdb3ec6', date '2026-01-01' + 233);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '3bca9a33-0000-4000-8000-00003bca9a33', '3ce95648-0000-4000-8000-00003ce95648', date '2026-01-01' + 234);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tildelte_merker owner_A DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b32-0000-4000-8000-00003bae6b32'', ''3ccd2747-0000-4000-8000-00003ccd2747'', date ''2026-01-01'' + 235)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc82b4-0000-4000-8000-00003bbc82b4'', ''3cdb3ec9-0000-4000-8000-00003cdb3ec9'', date ''2026-01-01'' + 236)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a36-0000-4000-8000-00003bca9a36'', ''3ce9564b-0000-4000-8000-00003ce9564b'', date ''2026-01-01'' + 237)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d6343d4-0000-4000-8000-00003d6343d4'', ''3e81ffe9-0000-4000-8000-00003e81ffe9'', date ''2026-01-01'' + 238)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6b36-0000-4000-8000-00003bae6b36', '3ccd274b-0000-4000-8000-00003ccd274b', date '2026-01-01' + 239);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tildelte_merker set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b4c-0000-4000-8000-00003bae6b4c'', ''3ccd2761-0000-4000-8000-00003ccd2761'', date ''2026-01-01'' + 240)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc82ce-0000-4000-8000-00003bbc82ce'', ''3cdb3ee3-0000-4000-8000-00003cdb3ee3'', date ''2026-01-01'' + 241)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a50-0000-4000-8000-00003bca9a50'', ''3ce95665-0000-4000-8000-00003ce95665'', date ''2026-01-01'' + 242)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d6343ee-0000-4000-8000-00003d6343ee'', ''3e820003-0000-4000-8000-00003e820003'', date ''2026-01-01'' + 243)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6b50-0000-4000-8000-00003bae6b50', '3ccd2765-0000-4000-8000-00003ccd2765', date '2026-01-01' + 244);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc82d2-0000-4000-8000-00003bbc82d2', '3cdb3ee7-0000-4000-8000-00003cdb3ee7', date '2026-01-01' + 245);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tildelte_merker set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b52-0000-4000-8000-00003bae6b52'', ''3ccd2767-0000-4000-8000-00003ccd2767'', date ''2026-01-01'' + 246)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc82d4-0000-4000-8000-00003bbc82d4'', ''3cdb3ee9-0000-4000-8000-00003cdb3ee9'', date ''2026-01-01'' + 247)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a56-0000-4000-8000-00003bca9a56'', ''3ce9566b-0000-4000-8000-00003ce9566b'', date ''2026-01-01'' + 248)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d6343f4-0000-4000-8000-00003d6343f4'', ''3e820009-0000-4000-8000-00003e820009'', date ''2026-01-01'' + 249)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tildelte_merker owner_B SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_B SELECT B2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63440a-0000-4000-8000-00003d63440a'', ''3e82001f-0000-4000-8000-00003e82001f'', date ''2026-01-01'' + 250)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715b8c-0000-4000-8000-00003d715b8c'', ''3e9017a1-0000-4000-8000-00003e9017a1'', date ''2026-01-01'' + 251)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b6d-0000-4000-8000-00003bae6b6d'', ''3ccd2782-0000-4000-8000-00003ccd2782'', date ''2026-01-01'' + 252)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d63440d-0000-4000-8000-00003d63440d', '3e820022-0000-4000-8000-00003e820022', date '2026-01-01' + 253);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '3d715b8f-0000-4000-8000-00003d715b8f', '3e9017a4-0000-4000-8000-00003e9017a4', date '2026-01-01' + 254);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63440f-0000-4000-8000-00003d63440f'', ''3e820024-0000-4000-8000-00003e820024'', date ''2026-01-01'' + 255)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715b91-0000-4000-8000-00003d715b91'', ''3e9017a6-0000-4000-8000-00003e9017a6'', date ''2026-01-01'' + 256)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b72-0000-4000-8000-00003bae6b72'', ''3ccd2787-0000-4000-8000-00003ccd2787'', date ''2026-01-01'' + 257)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d634412-0000-4000-8000-00003d634412', '3e820027-0000-4000-8000-00003e820027', date '2026-01-01' + 258);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tildelte_merker set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634413-0000-4000-8000-00003d634413'', ''3e820028-0000-4000-8000-00003e820028'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715baa-0000-4000-8000-00003d715baa'', ''3e9017bf-0000-4000-8000-00003e9017bf'', date ''2026-01-01'' + 260)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b8b-0000-4000-8000-00003bae6b8b'', ''3ccd27a0-0000-4000-8000-00003ccd27a0'', date ''2026-01-01'' + 261)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

-- =====================================================================
-- ik_avlesninger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ik_avlesninger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ik_avlesninger owner_A SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A3 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a984-0000-4000-8000-000038a2a984'', date ''2026-01-01'' + 262, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c106-0000-4000-8000-000038b0c106'', date ''2026-01-01'' + 263, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed888-0000-4000-8000-000038bed888'', date ''2026-01-01'' + 264, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578226-0000-4000-8000-00003a578226'', date ''2026-01-01'' + 265, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a988-0000-4000-8000-000038a2a988'', date ''2026-01-01'' + 266, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c10a-0000-4000-8000-000038b0c10a'', date ''2026-01-01'' + 267, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed88c-0000-4000-8000-000038bed88c'', date ''2026-01-01'' + 268, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a57822a-0000-4000-8000-00003a57822a'', date ''2026-01-01'' + 269, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9a1-0000-4000-8000-000038a2a9a1'', date ''2026-01-01'' + 270, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c123-0000-4000-8000-000038b0c123'', date ''2026-01-01'' + 271, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8a5-0000-4000-8000-000038bed8a5'', date ''2026-01-01'' + 272, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578243-0000-4000-8000-00003a578243'', date ''2026-01-01'' + 273, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9a5-0000-4000-8000-000038a2a9a5'', date ''2026-01-01'' + 274, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c127-0000-4000-8000-000038b0c127'', date ''2026-01-01'' + 275, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8a9-0000-4000-8000-000038bed8a9'', date ''2026-01-01'' + 276, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578247-0000-4000-8000-00003a578247'', date ''2026-01-01'' + 277, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578248-0000-4000-8000-00003a578248'', date ''2026-01-01'' + 278, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6599ca-0000-4000-8000-00003a6599ca'', date ''2026-01-01'' + 279, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c0-0000-4000-8000-000038a2a9c0'', date ''2026-01-01'' + 280, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578260-0000-4000-8000-00003a578260'', date ''2026-01-01'' + 281, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6599e2-0000-4000-8000-00003a6599e2'', date ''2026-01-01'' + 282, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c3-0000-4000-8000-000038a2a9c3'', date ''2026-01-01'' + 283, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578263-0000-4000-8000-00003a578263'', date ''2026-01-01'' + 284, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6599e5-0000-4000-8000-00003a6599e5'', date ''2026-01-01'' + 285, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c6-0000-4000-8000-000038a2a9c6'', date ''2026-01-01'' + 286, 4.0, true)');

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
    raise exception 'TENANT-MATRISEN DEL 4/6: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 4/6: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
