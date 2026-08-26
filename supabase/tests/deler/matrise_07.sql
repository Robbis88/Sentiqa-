-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 7 AV 7. Hele matrisen er for stor for Supabase SQL
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
insert into public.merker (id, retailer_id, navn) values ('5ea158d3-0000-4000-8000-00005ea158d3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 5');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('12fa1628-0000-4000-8000-000012fa1628', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-5', 'pin-merke-5');
insert into public.merker (id, retailer_id, navn) values ('5ea15c95-0000-4000-8000-00005ea15c95', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 6');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('12fa19ea-0000-4000-8000-000012fa19ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-6', 'pin-merke-6');
insert into public.merker (id, retailer_id, navn) values ('5ea16057-0000-4000-8000-00005ea16057', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 7');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('12fa1dac-0000-4000-8000-000012fa1dac', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-7', 'pin-merke-7');
insert into public.merker (id, retailer_id, navn) values ('5ea1cd35-0000-4000-8000-00005ea1cd35', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 8');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('12fa8a8a-0000-4000-8000-000012fa8a8a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-8', 'pin-merke-8');
insert into public.merker (id, retailer_id, navn) values ('5ea1d0f7-0000-4000-8000-00005ea1d0f7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 9');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('12fa8e4c-0000-4000-8000-000012fa8e4c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-9', 'pin-merke-9');
insert into public.merker (id, retailer_id, navn) values ('7589c1c4-0000-4000-8000-00007589c1c4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 57');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af0f-0000-4000-8000-00004c48af0f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-57', 'pin-merke-57');
insert into public.merker (id, retailer_id, navn) values ('758a3624-0000-4000-8000-0000758a3624', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 58');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49236f-0000-4000-8000-00004c49236f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-58', 'pin-merke-58');
insert into public.merker (id, retailer_id, navn) values ('758aaa84-0000-4000-8000-0000758aaa84', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 59');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4997cf-0000-4000-8000-00004c4997cf', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-59', 'pin-merke-59');
insert into public.merker (id, retailer_id, navn) values ('7597d95d-0000-4000-8000-00007597d95d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 60');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6a8-0000-4000-8000-00004c56c6a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-60', 'pin-merke-60');
insert into public.merker (id, retailer_id, navn) values ('7589c1dd-0000-4000-8000-00007589c1dd', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 61');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af28-0000-4000-8000-00004c48af28', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-61', 'pin-merke-61');
insert into public.merker (id, retailer_id, navn) values ('758a363d-0000-4000-8000-0000758a363d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 62');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c492388-0000-4000-8000-00004c492388', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-62', 'pin-merke-62');
insert into public.merker (id, retailer_id, navn) values ('758aaa9d-0000-4000-8000-0000758aaa9d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 63');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4997e8-0000-4000-8000-00004c4997e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-63', 'pin-merke-63');
insert into public.merker (id, retailer_id, navn) values ('7589c1e0-0000-4000-8000-00007589c1e0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 64');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af2b-0000-4000-8000-00004c48af2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-64', 'pin-merke-64');
insert into public.merker (id, retailer_id, navn) values ('758a3640-0000-4000-8000-0000758a3640', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 65');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49238b-0000-4000-8000-00004c49238b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-65', 'pin-merke-65');
insert into public.merker (id, retailer_id, navn) values ('758aaaa0-0000-4000-8000-0000758aaaa0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 66');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4997eb-0000-4000-8000-00004c4997eb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-66', 'pin-merke-66');
insert into public.merker (id, retailer_id, navn) values ('7597d964-0000-4000-8000-00007597d964', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 67');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6af-0000-4000-8000-00004c56c6af', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-67', 'pin-merke-67');
insert into public.merker (id, retailer_id, navn) values ('7589c1e4-0000-4000-8000-00007589c1e4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 68');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af2f-0000-4000-8000-00004c48af2f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-68', 'pin-merke-68');
insert into public.merker (id, retailer_id, navn) values ('7589c1e5-0000-4000-8000-00007589c1e5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 69');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af30-0000-4000-8000-00004c48af30', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-69', 'pin-merke-69');
insert into public.merker (id, retailer_id, navn) values ('758a365a-0000-4000-8000-0000758a365a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 70');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4923a5-0000-4000-8000-00004c4923a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-70', 'pin-merke-70');
insert into public.merker (id, retailer_id, navn) values ('758aaaba-0000-4000-8000-0000758aaaba', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 71');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c499805-0000-4000-8000-00004c499805', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-71', 'pin-merke-71');
insert into public.merker (id, retailer_id, navn) values ('7597d97e-0000-4000-8000-00007597d97e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 72');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6c9-0000-4000-8000-00004c56c6c9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-72', 'pin-merke-72');
insert into public.merker (id, retailer_id, navn) values ('7589c1fe-0000-4000-8000-00007589c1fe', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 73');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af49-0000-4000-8000-00004c48af49', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-73', 'pin-merke-73');
insert into public.merker (id, retailer_id, navn) values ('758a365e-0000-4000-8000-0000758a365e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 74');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4923a9-0000-4000-8000-00004c4923a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-74', 'pin-merke-74');
insert into public.merker (id, retailer_id, navn) values ('7589c200-0000-4000-8000-00007589c200', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 75');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af4b-0000-4000-8000-00004c48af4b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-75', 'pin-merke-75');
insert into public.merker (id, retailer_id, navn) values ('758a3660-0000-4000-8000-0000758a3660', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 76');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c4923ab-0000-4000-8000-00004c4923ab', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-76', 'pin-merke-76');
insert into public.merker (id, retailer_id, navn) values ('758aaac0-0000-4000-8000-0000758aaac0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 77');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49980b-0000-4000-8000-00004c49980b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-77', 'pin-merke-77');
insert into public.merker (id, retailer_id, navn) values ('7597d984-0000-4000-8000-00007597d984', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 78');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6cf-0000-4000-8000-00004c56c6cf', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-78', 'pin-merke-78');
insert into public.merker (id, retailer_id, navn) values ('7597d985-0000-4000-8000-00007597d985', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 79');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6d0-0000-4000-8000-00004c56c6d0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-79', 'pin-merke-79');
insert into public.merker (id, retailer_id, navn) values ('75984dfa-0000-4000-8000-000075984dfa', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 80');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573b45-0000-4000-8000-00004c573b45', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-80', 'pin-merke-80');
insert into public.merker (id, retailer_id, navn) values ('7589c21b-0000-4000-8000-00007589c21b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 81');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af66-0000-4000-8000-00004c48af66', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-81', 'pin-merke-81');
insert into public.merker (id, retailer_id, navn) values ('7597d99d-0000-4000-8000-00007597d99d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 82');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6e8-0000-4000-8000-00004c56c6e8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-82', 'pin-merke-82');
insert into public.merker (id, retailer_id, navn) values ('75984dfd-0000-4000-8000-000075984dfd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 83');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573b48-0000-4000-8000-00004c573b48', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-83', 'pin-merke-83');
insert into public.merker (id, retailer_id, navn) values ('7597d99f-0000-4000-8000-00007597d99f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 84');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6ea-0000-4000-8000-00004c56c6ea', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-84', 'pin-merke-84');
insert into public.merker (id, retailer_id, navn) values ('75984dff-0000-4000-8000-000075984dff', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 85');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573b4a-0000-4000-8000-00004c573b4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-85', 'pin-merke-85');
insert into public.merker (id, retailer_id, navn) values ('7589c220-0000-4000-8000-00007589c220', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 86');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af6b-0000-4000-8000-00004c48af6b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-86', 'pin-merke-86');
insert into public.merker (id, retailer_id, navn) values ('7597d9a2-0000-4000-8000-00007597d9a2', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 87');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6ed-0000-4000-8000-00004c56c6ed', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-87', 'pin-merke-87');
insert into public.merker (id, retailer_id, navn) values ('7597d9a3-0000-4000-8000-00007597d9a3', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 88');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c6ee-0000-4000-8000-00004c56c6ee', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-88', 'pin-merke-88');
insert into public.merker (id, retailer_id, navn) values ('75984e03-0000-4000-8000-000075984e03', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 89');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573b4e-0000-4000-8000-00004c573b4e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-89', 'pin-merke-89');
insert into public.merker (id, retailer_id, navn) values ('7589c239-0000-4000-8000-00007589c239', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 90');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48af84-0000-4000-8000-00004c48af84', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-90', 'pin-merke-90');
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
-- --- tildelte_merker: forutsetninger og proberader ---
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '5ea158d3-0000-4000-8000-00005ea158d3', '12fa1628-0000-4000-8000-000012fa1628', date '2026-01-01' + 5);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '5ea15c95-0000-4000-8000-00005ea15c95', '12fa19ea-0000-4000-8000-000012fa19ea', date '2026-01-01' + 6);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '5ea16057-0000-4000-8000-00005ea16057', '12fa1dac-0000-4000-8000-000012fa1dac', date '2026-01-01' + 7);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '5ea1cd35-0000-4000-8000-00005ea1cd35', '12fa8a8a-0000-4000-8000-000012fa8a8a', date '2026-01-01' + 8);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '5ea1d0f7-0000-4000-8000-00005ea1d0f7', '12fa8e4c-0000-4000-8000-000012fa8e4c', date '2026-01-01' + 9);

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
-- --- timesalg: forutsetninger og proberader ---
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 12, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 13, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 14, '8-9', 1000, 10);

create or replace function pg_temp.nyrad_timesalg(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '8-9', 1000, 10);
end $fn$;
-- --- trafikk: forutsetninger og proberader ---
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 15, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 16, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 17, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 18, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 19, 1000, 80);
-- --- uke_rapport: forutsetninger og proberader ---
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 20);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 21);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 22);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 23);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 24);

create or replace function pg_temp.nyrad_uke_rapport(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
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
-- tildelte_merker  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tildelte_merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tildelte_merker owner_A SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A3 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1c4-0000-4000-8000-00007589c1c4'', ''4c48af0f-0000-4000-8000-00004c48af0f'', date ''2026-01-01'' + 57)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a3624-0000-4000-8000-0000758a3624'', ''4c49236f-0000-4000-8000-00004c49236f'', date ''2026-01-01'' + 58)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaa84-0000-4000-8000-0000758aaa84'', ''4c4997cf-0000-4000-8000-00004c4997cf'', date ''2026-01-01'' + 59)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d95d-0000-4000-8000-00007597d95d'', ''4c56c6a8-0000-4000-8000-00004c56c6a8'', date ''2026-01-01'' + 60)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1dd-0000-4000-8000-00007589c1dd', '4c48af28-0000-4000-8000-00004c48af28', date '2026-01-01' + 61);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a363d-0000-4000-8000-0000758a363d', '4c492388-0000-4000-8000-00004c492388', date '2026-01-01' + 62);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa9d-0000-4000-8000-0000758aaa9d', '4c4997e8-0000-4000-8000-00004c4997e8', date '2026-01-01' + 63);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1e0-0000-4000-8000-00007589c1e0'', ''4c48af2b-0000-4000-8000-00004c48af2b'', date ''2026-01-01'' + 64)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a3640-0000-4000-8000-0000758a3640'', ''4c49238b-0000-4000-8000-00004c49238b'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaaa0-0000-4000-8000-0000758aaaa0'', ''4c4997eb-0000-4000-8000-00004c4997eb'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d964-0000-4000-8000-00007597d964'', ''4c56c6af-0000-4000-8000-00004c56c6af'', date ''2026-01-01'' + 67)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1e4-0000-4000-8000-00007589c1e4', '4c48af2f-0000-4000-8000-00004c48af2f', date '2026-01-01' + 68);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1e5-0000-4000-8000-00007589c1e5'', ''4c48af30-0000-4000-8000-00004c48af30'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a365a-0000-4000-8000-0000758a365a'', ''4c4923a5-0000-4000-8000-00004c4923a5'', date ''2026-01-01'' + 70)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaaba-0000-4000-8000-0000758aaaba'', ''4c499805-0000-4000-8000-00004c499805'', date ''2026-01-01'' + 71)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d97e-0000-4000-8000-00007597d97e'', ''4c56c6c9-0000-4000-8000-00004c56c6c9'', date ''2026-01-01'' + 72)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1fe-0000-4000-8000-00007589c1fe', '4c48af49-0000-4000-8000-00004c48af49', date '2026-01-01' + 73);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a365e-0000-4000-8000-0000758a365e', '4c4923a9-0000-4000-8000-00004c4923a9', date '2026-01-01' + 74);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c200-0000-4000-8000-00007589c200'', ''4c48af4b-0000-4000-8000-00004c48af4b'', date ''2026-01-01'' + 75)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a3660-0000-4000-8000-0000758a3660'', ''4c4923ab-0000-4000-8000-00004c4923ab'', date ''2026-01-01'' + 76)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaac0-0000-4000-8000-0000758aaac0'', ''4c49980b-0000-4000-8000-00004c49980b'', date ''2026-01-01'' + 77)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d984-0000-4000-8000-00007597d984'', ''4c56c6cf-0000-4000-8000-00004c56c6cf'', date ''2026-01-01'' + 78)');
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
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d985-0000-4000-8000-00007597d985'', ''4c56c6d0-0000-4000-8000-00004c56c6d0'', date ''2026-01-01'' + 79)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984dfa-0000-4000-8000-000075984dfa'', ''4c573b45-0000-4000-8000-00004c573b45'', date ''2026-01-01'' + 80)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c21b-0000-4000-8000-00007589c21b'', ''4c48af66-0000-4000-8000-00004c48af66'', date ''2026-01-01'' + 81)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d99d-0000-4000-8000-00007597d99d', '4c56c6e8-0000-4000-8000-00004c56c6e8', date '2026-01-01' + 82);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984dfd-0000-4000-8000-000075984dfd', '4c573b48-0000-4000-8000-00004c573b48', date '2026-01-01' + 83);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d99f-0000-4000-8000-00007597d99f'', ''4c56c6ea-0000-4000-8000-00004c56c6ea'', date ''2026-01-01'' + 84)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984dff-0000-4000-8000-000075984dff'', ''4c573b4a-0000-4000-8000-00004c573b4a'', date ''2026-01-01'' + 85)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c220-0000-4000-8000-00007589c220'', ''4c48af6b-0000-4000-8000-00004c48af6b'', date ''2026-01-01'' + 86)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d9a2-0000-4000-8000-00007597d9a2', '4c56c6ed-0000-4000-8000-00004c56c6ed', date '2026-01-01' + 87);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d9a3-0000-4000-8000-00007597d9a3'', ''4c56c6ee-0000-4000-8000-00004c56c6ee'', date ''2026-01-01'' + 88)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984e03-0000-4000-8000-000075984e03'', ''4c573b4e-0000-4000-8000-00004c573b4e'', date ''2026-01-01'' + 89)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c239-0000-4000-8000-00007589c239'', ''4c48af84-0000-4000-8000-00004c48af84'', date ''2026-01-01'' + 90)');
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
-- timesalg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('timesalg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('timesalg owner_A SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A3 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 91, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 92, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 93, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_A INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 94, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 12, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_A FLYTTER egen rad -> kjede B', 'update public.timesalg set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('timesalg manager_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 95, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 96, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 97, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 98, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('timesalg manager_A12 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 99, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 100, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 101, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 102, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('timesalg tablet_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 103, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 104, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 105, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 106, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('timesalg owner_B SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT B2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 107, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 108, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_B INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 109, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 13, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 14, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_B FLYTTER egen rad -> kjede A', 'update public.timesalg set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('timesalg manager_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 110, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 111, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 112, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('timesalg tablet_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 113, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 114, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 115, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "time" = ''8-9''');

-- =====================================================================
-- trafikk  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('trafikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('trafikk owner_A SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 16), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A3 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 17), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('trafikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'positiv');
select pg_temp.paastand('trafikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 16), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 17), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('trafikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 16), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 17), 'negativ');
select pg_temp.paastand('trafikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('trafikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'positiv');
select pg_temp.paastand('trafikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 16), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 17), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('trafikk owner_B SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT B2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 19), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('trafikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'positiv');
select pg_temp.paastand('trafikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 19), 'negativ');
select pg_temp.paastand('trafikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('trafikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 18), 'positiv');
select pg_temp.paastand('trafikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 19), 'negativ');
select pg_temp.paastand('trafikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 15), 'negativ');

-- =====================================================================
-- uke_rapport  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('uke_rapport');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('uke_rapport owner_A SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A3 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 116)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 117)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 118)');
select pg_temp.skriv_avvist('uke_rapport owner_A INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 119)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('uke_rapport owner_A UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 120);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 121);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 122);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('uke_rapport owner_A DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport owner_A FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('uke_rapport manager_A1 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 123)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 124)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 125)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 126)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 127);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A1 FLYTTER egen rad A1 -> A2', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A1 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('uke_rapport manager_A12 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A12 SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 128)');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 129)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 130)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 131)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 132);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 133);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A12 FLYTTER egen rad A1 -> A3', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A12 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 134)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 135)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 136)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 137)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 138);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('uke_rapport owner_B SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport owner_B SELECT B2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'positiv');
select pg_temp.paastand('uke_rapport owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 139)');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 140)');
select pg_temp.skriv_avvist('uke_rapport owner_B INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 141)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('uke_rapport owner_B UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 142);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 143);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('uke_rapport owner_B DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport owner_B FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('uke_rapport manager_B1 SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'negativ');
select pg_temp.paastand('uke_rapport manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 144)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 145)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 146)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 147);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_B1 FLYTTER egen rad B1 -> B2', 'update public.uke_rapport set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_B1 FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('uke_rapport tablet_B1 SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 148)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 149)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 150)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 151);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.uke_rapport set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

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
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_A1A2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A1A3'', ''Sonde'')');
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
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A12A3'', ''Sonde'')');
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
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_A1A2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel tablet_A1A3'', ''Sonde'')');
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
select pg_temp.skriv_tillatt('varsler manager_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_B1B2'', ''Sonde'')');
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
select pg_temp.skriv_tillatt('varsler tablet_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_B1B2'', ''Sonde'')');
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
    raise exception 'TENANT-MATRISEN DEL 7/7: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 7/7: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
