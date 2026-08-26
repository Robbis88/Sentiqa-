-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 6 AV 7. Hele matrisen er for stor for Supabase SQL
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
insert into public.merker (id, retailer_id, navn) values ('7589c186-0000-4000-8000-00007589c186', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 37');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48aed1-0000-4000-8000-00004c48aed1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-37', 'pin-merke-37');
insert into public.merker (id, retailer_id, navn) values ('758a35e6-0000-4000-8000-0000758a35e6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 38');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c492331-0000-4000-8000-00004c492331', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-38', 'pin-merke-38');
insert into public.merker (id, retailer_id, navn) values ('758aaa46-0000-4000-8000-0000758aaa46', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 39');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c499791-0000-4000-8000-00004c499791', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-39', 'pin-merke-39');
insert into public.merker (id, retailer_id, navn) values ('7597d91f-0000-4000-8000-00007597d91f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 40');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c66a-0000-4000-8000-00004c56c66a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-40', 'pin-merke-40');
insert into public.merker (id, retailer_id, navn) values ('75984d7f-0000-4000-8000-000075984d7f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 41');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573aca-0000-4000-8000-00004c573aca', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-41', 'pin-merke-41');
insert into public.merker (id, retailer_id, navn) values ('3bae6b6f-0000-4000-8000-00003bae6b6f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 254');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2784-0000-4000-8000-00003ccd2784', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-254', 'pin-merke-254');
insert into public.merker (id, retailer_id, navn) values ('3bbc82f1-0000-4000-8000-00003bbc82f1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 255');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f06-0000-4000-8000-00003cdb3f06', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-255', 'pin-merke-255');
insert into public.merker (id, retailer_id, navn) values ('3bca9a73-0000-4000-8000-00003bca9a73', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 256');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce95688-0000-4000-8000-00003ce95688', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-256', 'pin-merke-256');
insert into public.merker (id, retailer_id, navn) values ('3d634411-0000-4000-8000-00003d634411', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 257');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820026-0000-4000-8000-00003e820026', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-257', 'pin-merke-257');
insert into public.merker (id, retailer_id, navn) values ('3bae6b73-0000-4000-8000-00003bae6b73', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 258');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2788-0000-4000-8000-00003ccd2788', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-258', 'pin-merke-258');
insert into public.merker (id, retailer_id, navn) values ('3bbc82f5-0000-4000-8000-00003bbc82f5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 259');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f0a-0000-4000-8000-00003cdb3f0a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-259', 'pin-merke-259');
insert into public.merker (id, retailer_id, navn) values ('3bca9a8c-0000-4000-8000-00003bca9a8c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 260');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce956a1-0000-4000-8000-00003ce956a1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-260', 'pin-merke-260');
insert into public.merker (id, retailer_id, navn) values ('3bae6b8b-0000-4000-8000-00003bae6b8b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 261');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27a0-0000-4000-8000-00003ccd27a0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-261', 'pin-merke-261');
insert into public.merker (id, retailer_id, navn) values ('3bbc830d-0000-4000-8000-00003bbc830d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 262');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f22-0000-4000-8000-00003cdb3f22', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-262', 'pin-merke-262');
insert into public.merker (id, retailer_id, navn) values ('3bca9a8f-0000-4000-8000-00003bca9a8f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 263');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce956a4-0000-4000-8000-00003ce956a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-263', 'pin-merke-263');
insert into public.merker (id, retailer_id, navn) values ('3d63442d-0000-4000-8000-00003d63442d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 264');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820042-0000-4000-8000-00003e820042', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-264', 'pin-merke-264');
insert into public.merker (id, retailer_id, navn) values ('3bae6b8f-0000-4000-8000-00003bae6b8f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 265');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27a4-0000-4000-8000-00003ccd27a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-265', 'pin-merke-265');
insert into public.merker (id, retailer_id, navn) values ('3bae6b90-0000-4000-8000-00003bae6b90', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 266');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27a5-0000-4000-8000-00003ccd27a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-266', 'pin-merke-266');
insert into public.merker (id, retailer_id, navn) values ('3bbc8312-0000-4000-8000-00003bbc8312', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 267');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f27-0000-4000-8000-00003cdb3f27', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-267', 'pin-merke-267');
insert into public.merker (id, retailer_id, navn) values ('3bca9a94-0000-4000-8000-00003bca9a94', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 268');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce956a9-0000-4000-8000-00003ce956a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-268', 'pin-merke-268');
insert into public.merker (id, retailer_id, navn) values ('3d634432-0000-4000-8000-00003d634432', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 269');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820047-0000-4000-8000-00003e820047', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-269', 'pin-merke-269');
insert into public.merker (id, retailer_id, navn) values ('3bae6ba9-0000-4000-8000-00003bae6ba9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 270');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27be-0000-4000-8000-00003ccd27be', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-270', 'pin-merke-270');
insert into public.merker (id, retailer_id, navn) values ('3bbc832b-0000-4000-8000-00003bbc832b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 271');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f40-0000-4000-8000-00003cdb3f40', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-271', 'pin-merke-271');
insert into public.merker (id, retailer_id, navn) values ('3bae6bab-0000-4000-8000-00003bae6bab', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 272');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27c0-0000-4000-8000-00003ccd27c0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-272', 'pin-merke-272');
insert into public.merker (id, retailer_id, navn) values ('3bbc832d-0000-4000-8000-00003bbc832d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 273');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3f42-0000-4000-8000-00003cdb3f42', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-273', 'pin-merke-273');
insert into public.merker (id, retailer_id, navn) values ('3bca9aaf-0000-4000-8000-00003bca9aaf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 274');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce956c4-0000-4000-8000-00003ce956c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-274', 'pin-merke-274');
insert into public.merker (id, retailer_id, navn) values ('3d63444d-0000-4000-8000-00003d63444d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 275');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820062-0000-4000-8000-00003e820062', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-275', 'pin-merke-275');
insert into public.merker (id, retailer_id, navn) values ('3d63444e-0000-4000-8000-00003d63444e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 276');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820063-0000-4000-8000-00003e820063', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-276', 'pin-merke-276');
insert into public.merker (id, retailer_id, navn) values ('3d715bd0-0000-4000-8000-00003d715bd0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 277');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017e5-0000-4000-8000-00003e9017e5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-277', 'pin-merke-277');
insert into public.merker (id, retailer_id, navn) values ('3bae6bb1-0000-4000-8000-00003bae6bb1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 278');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27c6-0000-4000-8000-00003ccd27c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-278', 'pin-merke-278');
insert into public.merker (id, retailer_id, navn) values ('3d634451-0000-4000-8000-00003d634451', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 279');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820066-0000-4000-8000-00003e820066', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-279', 'pin-merke-279');
insert into public.merker (id, retailer_id, navn) values ('3d715be8-0000-4000-8000-00003d715be8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 280');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017fd-0000-4000-8000-00003e9017fd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-280', 'pin-merke-280');
insert into public.merker (id, retailer_id, navn) values ('3d634468-0000-4000-8000-00003d634468', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 281');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e82007d-0000-4000-8000-00003e82007d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-281', 'pin-merke-281');
insert into public.merker (id, retailer_id, navn) values ('3d715bea-0000-4000-8000-00003d715bea', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 282');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e9017ff-0000-4000-8000-00003e9017ff', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-282', 'pin-merke-282');
insert into public.merker (id, retailer_id, navn) values ('3bae6bcb-0000-4000-8000-00003bae6bcb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 283');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27e0-0000-4000-8000-00003ccd27e0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-283', 'pin-merke-283');
insert into public.merker (id, retailer_id, navn) values ('3d63446b-0000-4000-8000-00003d63446b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 284');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820080-0000-4000-8000-00003e820080', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-284', 'pin-merke-284');
insert into public.merker (id, retailer_id, navn) values ('3d63446c-0000-4000-8000-00003d63446c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 285');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e820081-0000-4000-8000-00003e820081', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-285', 'pin-merke-285');
insert into public.merker (id, retailer_id, navn) values ('3d715bee-0000-4000-8000-00003d715bee', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 286');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e901803-0000-4000-8000-00003e901803', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-286', 'pin-merke-286');
insert into public.merker (id, retailer_id, navn) values ('3bae6bcf-0000-4000-8000-00003bae6bcf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 287');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd27e4-0000-4000-8000-00003ccd27e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-287', 'pin-merke-287');
-- --- sjekkpunkter: forutsetninger og proberader ---
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922545-0000-4000-8000-000028922545', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? fastA1');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922546-0000-4000-8000-000028922546', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Er kjoelen sjekket? fastA2');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922547-0000-4000-8000-000028922547', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Er kjoelen sjekket? fastA3');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922564-0000-4000-8000-000028922564', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? fastB1');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922565-0000-4000-8000-000028922565', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Er kjoelen sjekket? fastB2');

create or replace function pg_temp.nyrad_sjekkpunkter(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal)
  values (p_retailer, p_stasjon, 'Er kjoelen sjekket? ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- skills_score: forutsetninger og proberader ---
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49c9-0000-4000-8000-0000420e49c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 88);
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49ca-0000-4000-8000-0000420e49ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 88);
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49cb-0000-4000-8000-0000420e49cb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 88);
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49e8-0000-4000-8000-0000420e49e8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 88);
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49e9-0000-4000-8000-0000420e49e9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 88);

create or replace function pg_temp.nyrad_skills_score(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.skills_score (retailer_id, stasjon_id, prosent)
  values (p_retailer, p_stasjon, 88)
  returning id into ny;
  return ny;
end $fn$;
-- --- stempling: forutsetninger og proberader ---
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', date '2026-01-01' + 10, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', date '2026-01-01' + 11, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', date '2026-01-01' + 12, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', date '2026-01-01' + 13, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', date '2026-01-01' + 14, clock_timestamp()::time, time '16:00', 480);

create or replace function pg_temp.nyrad_stempling(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter)
  values (p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, clock_timestamp()::time, time '16:00', 480)
  returning id into ny;
  return ny;
end $fn$;
-- --- stempling_hendelse: forutsetninger og proberader ---
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e262-0000-4000-8000-0000fd47e262', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e263-0000-4000-8000-0000fd47e263', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e264-0000-4000-8000-0000fd47e264', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e281-0000-4000-8000-0000fd47e281', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e282-0000-4000-8000-0000fd47e282', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');

create or replace function pg_temp.nyrad_stempling_hendelse(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde)
  values (p_retailer, p_stasjon, '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet')
  returning id into ny;
  return ny;
end $fn$;
-- --- synlig_svinn: forutsetninger og proberader ---
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 20, 'fastA1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 21, 'fastA2', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 22, 'fastA3', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 23, 'fastB1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 24, 'fastB2', 'Sondevare', 1, 25);

create or replace function pg_temp.nyrad_synlig_svinn(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sondevare', 1, 25)
  returning id into ny;
  return ny;
end $fn$;
-- --- tablet_meldinger: forutsetninger og proberader ---
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('80f0b8e1-0000-4000-8000-000080f0b8e1', 'aaaa0000-0000-4000-8000-000000000000', null, 'Sondemelding nullA');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('80f0b8e2-0000-4000-8000-000080f0b8e2', 'bbbb0000-0000-4000-8000-000000000000', null, 'Sondemelding nullB');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding fastA1');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding fastA2');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadc-0000-4000-8000-0000d7d6fadc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding fastA3');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding fastB1');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fafa-0000-4000-8000-0000d7d6fafa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding fastB2');

create or replace function pg_temp.nyrad_tablet_meldinger(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst)
  values (p_retailer, p_stasjon, 'Sondemelding ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c186-0000-4000-8000-00007589c186', '4c48aed1-0000-4000-8000-00004c48aed1', date '2026-01-01' + 37);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a35e6-0000-4000-8000-0000758a35e6', '4c492331-0000-4000-8000-00004c492331', date '2026-01-01' + 38);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa46-0000-4000-8000-0000758aaa46', '4c499791-0000-4000-8000-00004c499791', date '2026-01-01' + 39);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d91f-0000-4000-8000-00007597d91f', '4c56c66a-0000-4000-8000-00004c56c66a', date '2026-01-01' + 40);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984d7f-0000-4000-8000-000075984d7f', '4c573aca-0000-4000-8000-00004c573aca', date '2026-01-01' + 41);

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

-- =====================================================================
-- sjekkpunkter  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('sjekkpunkter');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('sjekkpunkter owner_A SELECT A1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'positiv');
select pg_temp.paastand('sjekkpunkter owner_A SELECT A2 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922546-0000-4000-8000-000028922546'), 'positiv');
select pg_temp.paastand('sjekkpunkter owner_A SELECT A3 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922547-0000-4000-8000-000028922547'), 'positiv');
select pg_temp.paastand('sjekkpunkter owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? owner_AA1'')');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A INSERT A2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? owner_AA2'')');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A INSERT A3', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Er kjoelen sjekket? owner_AA3'')');
select pg_temp.skriv_avvist('sjekkpunkter owner_A INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A UPDATE A2', 'update public.sjekkpunkter set kritisk = true where id = ''28922546-0000-4000-8000-000028922546''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A UPDATE A3', 'update public.sjekkpunkter set kritisk = true where id = ''28922547-0000-4000-8000-000028922547''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkter owner_A UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922545-0000-4000-8000-000028922545', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A DELETE A2', 'delete from public.sjekkpunkter where id = ''28922546-0000-4000-8000-000028922546''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922546-0000-4000-8000-000028922546', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Er kjoelen sjekket? gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_A DELETE A3', 'delete from public.sjekkpunkter where id = ''28922547-0000-4000-8000-000028922547''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922547-0000-4000-8000-000028922547', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Er kjoelen sjekket? gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkter owner_A DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.skriv_avvist('sjekkpunkter owner_A FLYTTER egen rad -> kjede B', 'update public.sjekkpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('sjekkpunkter manager_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'positiv');
select pg_temp.paastand('sjekkpunkter manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922546-0000-4000-8000-000028922546'), 'negativ');
select pg_temp.paastand('sjekkpunkter manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922547-0000-4000-8000-000028922547'), 'negativ');
select pg_temp.paastand('sjekkpunkter manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A1 INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_A1A1'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 INSERT A2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? manager_A1A2'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 INSERT A3', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Er kjoelen sjekket? manager_A1A3'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A1 UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 UPDATE A2', 'update public.sjekkpunkter set kritisk = true where id = ''28922546-0000-4000-8000-000028922546''', 'sjekkpunkter', '28922546-0000-4000-8000-000028922546', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 UPDATE A3', 'update public.sjekkpunkter set kritisk = true where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A1 DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922545-0000-4000-8000-000028922545', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 DELETE A2', 'delete from public.sjekkpunkter where id = ''28922546-0000-4000-8000-000028922546''', 'sjekkpunkter', '28922546-0000-4000-8000-000028922546', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 DELETE A3', 'delete from public.sjekkpunkter where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 FLYTTER egen rad A1 -> A2', 'update public.sjekkpunkter set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_A1 FLYTTER egen rad -> kjede B', 'update public.sjekkpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('sjekkpunkter manager_A12 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'positiv');
select pg_temp.paastand('sjekkpunkter manager_A12 SELECT A2 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922546-0000-4000-8000-000028922546'), 'positiv');
select pg_temp.paastand('sjekkpunkter manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922547-0000-4000-8000-000028922547'), 'negativ');
select pg_temp.paastand('sjekkpunkter manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_A12A1'')');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 INSERT A2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? manager_A12A2'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 INSERT A3', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Er kjoelen sjekket? manager_A12A3'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 UPDATE A2', 'update public.sjekkpunkter set kritisk = true where id = ''28922546-0000-4000-8000-000028922546''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 UPDATE A3', 'update public.sjekkpunkter set kritisk = true where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922545-0000-4000-8000-000028922545', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkter manager_A12 DELETE A2', 'delete from public.sjekkpunkter where id = ''28922546-0000-4000-8000-000028922546''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922546-0000-4000-8000-000028922546', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Er kjoelen sjekket? gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 DELETE A3', 'delete from public.sjekkpunkter where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 FLYTTER egen rad A1 -> A3', 'update public.sjekkpunkter set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_A12 FLYTTER egen rad -> kjede B', 'update public.sjekkpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('sjekkpunkter tablet_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'positiv');
select pg_temp.paastand('sjekkpunkter tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922546-0000-4000-8000-000028922546'), 'negativ');
select pg_temp.paastand('sjekkpunkter tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922547-0000-4000-8000-000028922547'), 'negativ');
select pg_temp.paastand('sjekkpunkter tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'negativ');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? tablet_A1A1'')');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 INSERT A2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? tablet_A1A2'')');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 INSERT A3', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Er kjoelen sjekket? tablet_A1A3'')');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 UPDATE A2', 'update public.sjekkpunkter set kritisk = true where id = ''28922546-0000-4000-8000-000028922546''', 'sjekkpunkter', '28922546-0000-4000-8000-000028922546', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 UPDATE A3', 'update public.sjekkpunkter set kritisk = true where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 DELETE A2', 'delete from public.sjekkpunkter where id = ''28922546-0000-4000-8000-000028922546''', 'sjekkpunkter', '28922546-0000-4000-8000-000028922546', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 DELETE A3', 'delete from public.sjekkpunkter where id = ''28922547-0000-4000-8000-000028922547''', 'sjekkpunkter', '28922547-0000-4000-8000-000028922547', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_A1 DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('sjekkpunkter owner_B SELECT B1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'positiv');
select pg_temp.paastand('sjekkpunkter owner_B SELECT B2 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922565-0000-4000-8000-000028922565'), 'positiv');
select pg_temp.paastand('sjekkpunkter owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? owner_BB1'')');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B INSERT B2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? owner_BB2'')');
select pg_temp.skriv_avvist('sjekkpunkter owner_B INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B UPDATE B2', 'update public.sjekkpunkter set kritisk = true where id = ''28922565-0000-4000-8000-000028922565''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkter owner_B UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922564-0000-4000-8000-000028922564', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkter owner_B DELETE B2', 'delete from public.sjekkpunkter where id = ''28922565-0000-4000-8000-000028922565''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922565-0000-4000-8000-000028922565', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Er kjoelen sjekket? gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkter owner_B DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.skriv_avvist('sjekkpunkter owner_B FLYTTER egen rad -> kjede A', 'update public.sjekkpunkter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkter manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'positiv');
select pg_temp.paastand('sjekkpunkter manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922565-0000-4000-8000-000028922565'), 'negativ');
select pg_temp.paastand('sjekkpunkter manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkter manager_B1 INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_B1B1'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 INSERT B2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? manager_B1B2'')');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkter manager_B1 UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 UPDATE B2', 'update public.sjekkpunkter set kritisk = true where id = ''28922565-0000-4000-8000-000028922565''', 'sjekkpunkter', '28922565-0000-4000-8000-000028922565', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkter manager_B1 DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''');
select pg_temp.som_eier();
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('28922564-0000-4000-8000-000028922564', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Er kjoelen sjekket? gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 DELETE B2', 'delete from public.sjekkpunkter where id = ''28922565-0000-4000-8000-000028922565''', 'sjekkpunkter', '28922565-0000-4000-8000-000028922565', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 FLYTTER egen rad B1 -> B2', 'update public.sjekkpunkter set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.skriv_avvist('sjekkpunkter manager_B1 FLYTTER egen rad -> kjede A', 'update public.sjekkpunkter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('sjekkpunkter tablet_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkter where id = '28922564-0000-4000-8000-000028922564'), 'positiv');
select pg_temp.paastand('sjekkpunkter tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922565-0000-4000-8000-000028922565'), 'negativ');
select pg_temp.paastand('sjekkpunkter tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkter where id = '28922545-0000-4000-8000-000028922545'), 'negativ');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 INSERT B1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? tablet_B1B1'')');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 INSERT B2', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Er kjoelen sjekket? tablet_B1B2'')');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 INSERT A1', 'insert into public.sjekkpunkter (retailer_id, stasjon_id, sporsmaal) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Er kjoelen sjekket? tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 UPDATE B1', 'update public.sjekkpunkter set kritisk = true where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 UPDATE B2', 'update public.sjekkpunkter set kritisk = true where id = ''28922565-0000-4000-8000-000028922565''', 'sjekkpunkter', '28922565-0000-4000-8000-000028922565', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 UPDATE A1', 'update public.sjekkpunkter set kritisk = true where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 DELETE B1', 'delete from public.sjekkpunkter where id = ''28922564-0000-4000-8000-000028922564''', 'sjekkpunkter', '28922564-0000-4000-8000-000028922564', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 DELETE B2', 'delete from public.sjekkpunkter where id = ''28922565-0000-4000-8000-000028922565''', 'sjekkpunkter', '28922565-0000-4000-8000-000028922565', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkter tablet_B1 DELETE A1', 'delete from public.sjekkpunkter where id = ''28922545-0000-4000-8000-000028922545''', 'sjekkpunkter', '28922545-0000-4000-8000-000028922545', 'id');

-- =====================================================================
-- skills_score  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('skills_score');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('skills_score owner_A SELECT A1 -> ser', exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'positiv');
select pg_temp.paastand('skills_score owner_A SELECT A2 -> ser', exists (select 1 from public.skills_score where id = '420e49ca-0000-4000-8000-0000420e49ca'), 'positiv');
select pg_temp.paastand('skills_score owner_A SELECT A3 -> ser', exists (select 1 from public.skills_score where id = '420e49cb-0000-4000-8000-0000420e49cb'), 'positiv');
select pg_temp.paastand('skills_score owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'negativ');
select pg_temp.skriv_tillatt('skills_score owner_A INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_tillatt('skills_score owner_A INSERT A2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_tillatt('skills_score owner_A INSERT A3', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', 88)');
select pg_temp.skriv_avvist('skills_score owner_A INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A UPDATE A2', 'update public.skills_score set prosent = 91 where id = ''420e49ca-0000-4000-8000-0000420e49ca''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A UPDATE A3', 'update public.skills_score set prosent = 91 where id = ''420e49cb-0000-4000-8000-0000420e49cb''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('skills_score owner_A UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49c9-0000-4000-8000-0000420e49c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A DELETE A2', 'delete from public.skills_score where id = ''420e49ca-0000-4000-8000-0000420e49ca''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49ca-0000-4000-8000-0000420e49ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('skills_score owner_A DELETE A3', 'delete from public.skills_score where id = ''420e49cb-0000-4000-8000-0000420e49cb''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49cb-0000-4000-8000-0000420e49cb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('skills_score owner_A DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.skriv_avvist('skills_score owner_A FLYTTER egen rad -> kjede B', 'update public.skills_score set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('skills_score manager_A1 SELECT A1 -> ser', exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'positiv');
select pg_temp.paastand('skills_score manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49ca-0000-4000-8000-0000420e49ca'), 'negativ');
select pg_temp.paastand('skills_score manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49cb-0000-4000-8000-0000420e49cb'), 'negativ');
select pg_temp.paastand('skills_score manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'negativ');
select pg_temp.skriv_tillatt('skills_score manager_A1 INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_avvist('skills_score manager_A1 INSERT A2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score manager_A1 INSERT A3', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', 88)');
select pg_temp.skriv_avvist('skills_score manager_A1 INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('skills_score manager_A1 UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 UPDATE A2', 'update public.skills_score set prosent = 91 where id = ''420e49ca-0000-4000-8000-0000420e49ca''', 'skills_score', '420e49ca-0000-4000-8000-0000420e49ca', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 UPDATE A3', 'update public.skills_score set prosent = 91 where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('skills_score manager_A1 DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49c9-0000-4000-8000-0000420e49c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 DELETE A2', 'delete from public.skills_score where id = ''420e49ca-0000-4000-8000-0000420e49ca''', 'skills_score', '420e49ca-0000-4000-8000-0000420e49ca', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 DELETE A3', 'delete from public.skills_score where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('skills_score manager_A1 DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.skriv_avvist('skills_score manager_A1 FLYTTER egen rad A1 -> A2', 'update public.skills_score set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.skriv_avvist('skills_score manager_A1 FLYTTER egen rad -> kjede B', 'update public.skills_score set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('skills_score manager_A12 SELECT A1 -> ser', exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'positiv');
select pg_temp.paastand('skills_score manager_A12 SELECT A2 -> ser', exists (select 1 from public.skills_score where id = '420e49ca-0000-4000-8000-0000420e49ca'), 'positiv');
select pg_temp.paastand('skills_score manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49cb-0000-4000-8000-0000420e49cb'), 'negativ');
select pg_temp.paastand('skills_score manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'negativ');
select pg_temp.skriv_tillatt('skills_score manager_A12 INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_tillatt('skills_score manager_A12 INSERT A2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score manager_A12 INSERT A3', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', 88)');
select pg_temp.skriv_avvist('skills_score manager_A12 INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('skills_score manager_A12 UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('skills_score manager_A12 UPDATE A2', 'update public.skills_score set prosent = 91 where id = ''420e49ca-0000-4000-8000-0000420e49ca''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('skills_score manager_A12 UPDATE A3', 'update public.skills_score set prosent = 91 where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('skills_score manager_A12 UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('skills_score manager_A12 DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49c9-0000-4000-8000-0000420e49c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('skills_score manager_A12 DELETE A2', 'delete from public.skills_score where id = ''420e49ca-0000-4000-8000-0000420e49ca''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49ca-0000-4000-8000-0000420e49ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('skills_score manager_A12 DELETE A3', 'delete from public.skills_score where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('skills_score manager_A12 DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.skriv_avvist('skills_score manager_A12 FLYTTER egen rad A1 -> A3', 'update public.skills_score set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.skriv_avvist('skills_score manager_A12 FLYTTER egen rad -> kjede B', 'update public.skills_score set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('skills_score tablet_A1 SELECT A1 -> ser', exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'positiv');
select pg_temp.paastand('skills_score tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49ca-0000-4000-8000-0000420e49ca'), 'negativ');
select pg_temp.paastand('skills_score tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49cb-0000-4000-8000-0000420e49cb'), 'negativ');
select pg_temp.paastand('skills_score tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'negativ');
select pg_temp.skriv_avvist('skills_score tablet_A1 INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_avvist('skills_score tablet_A1 INSERT A2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score tablet_A1 INSERT A3', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', 88)');
select pg_temp.skriv_avvist('skills_score tablet_A1 INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 UPDATE A2', 'update public.skills_score set prosent = 91 where id = ''420e49ca-0000-4000-8000-0000420e49ca''', 'skills_score', '420e49ca-0000-4000-8000-0000420e49ca', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 UPDATE A3', 'update public.skills_score set prosent = 91 where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 DELETE A2', 'delete from public.skills_score where id = ''420e49ca-0000-4000-8000-0000420e49ca''', 'skills_score', '420e49ca-0000-4000-8000-0000420e49ca', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 DELETE A3', 'delete from public.skills_score where id = ''420e49cb-0000-4000-8000-0000420e49cb''', 'skills_score', '420e49cb-0000-4000-8000-0000420e49cb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('skills_score tablet_A1 DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('skills_score owner_B SELECT B1 -> ser', exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'positiv');
select pg_temp.paastand('skills_score owner_B SELECT B2 -> ser', exists (select 1 from public.skills_score where id = '420e49e9-0000-4000-8000-0000420e49e9'), 'positiv');
select pg_temp.paastand('skills_score owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'negativ');
select pg_temp.skriv_tillatt('skills_score owner_B INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_tillatt('skills_score owner_B INSERT B2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score owner_B INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('skills_score owner_B UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('skills_score owner_B UPDATE B2', 'update public.skills_score set prosent = 91 where id = ''420e49e9-0000-4000-8000-0000420e49e9''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('skills_score owner_B UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('skills_score owner_B DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49e8-0000-4000-8000-0000420e49e8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('skills_score owner_B DELETE B2', 'delete from public.skills_score where id = ''420e49e9-0000-4000-8000-0000420e49e9''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49e9-0000-4000-8000-0000420e49e9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('skills_score owner_B DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.skriv_avvist('skills_score owner_B FLYTTER egen rad -> kjede A', 'update public.skills_score set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('skills_score manager_B1 SELECT B1 -> ser', exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'positiv');
select pg_temp.paastand('skills_score manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e9-0000-4000-8000-0000420e49e9'), 'negativ');
select pg_temp.paastand('skills_score manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'negativ');
select pg_temp.skriv_tillatt('skills_score manager_B1 INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_avvist('skills_score manager_B1 INSERT B2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score manager_B1 INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('skills_score manager_B1 UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('skills_score manager_B1 UPDATE B2', 'update public.skills_score set prosent = 91 where id = ''420e49e9-0000-4000-8000-0000420e49e9''', 'skills_score', '420e49e9-0000-4000-8000-0000420e49e9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('skills_score manager_B1 UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('skills_score manager_B1 DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''');
select pg_temp.som_eier();
insert into public.skills_score (id, retailer_id, stasjon_id, prosent) values ('420e49e8-0000-4000-8000-0000420e49e8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 88);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('skills_score manager_B1 DELETE B2', 'delete from public.skills_score where id = ''420e49e9-0000-4000-8000-0000420e49e9''', 'skills_score', '420e49e9-0000-4000-8000-0000420e49e9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('skills_score manager_B1 DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.skriv_avvist('skills_score manager_B1 FLYTTER egen rad B1 -> B2', 'update public.skills_score set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.skriv_avvist('skills_score manager_B1 FLYTTER egen rad -> kjede A', 'update public.skills_score set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('skills_score tablet_B1 SELECT B1 -> ser', exists (select 1 from public.skills_score where id = '420e49e8-0000-4000-8000-0000420e49e8'), 'positiv');
select pg_temp.paastand('skills_score tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49e9-0000-4000-8000-0000420e49e9'), 'negativ');
select pg_temp.paastand('skills_score tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.skills_score where id = '420e49c9-0000-4000-8000-0000420e49c9'), 'negativ');
select pg_temp.skriv_avvist('skills_score tablet_B1 INSERT B1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.skriv_avvist('skills_score tablet_B1 INSERT B2', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', 88)');
select pg_temp.skriv_avvist('skills_score tablet_B1 INSERT A1', 'insert into public.skills_score (retailer_id, stasjon_id, prosent) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 UPDATE B1', 'update public.skills_score set prosent = 91 where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 UPDATE B2', 'update public.skills_score set prosent = 91 where id = ''420e49e9-0000-4000-8000-0000420e49e9''', 'skills_score', '420e49e9-0000-4000-8000-0000420e49e9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 UPDATE A1', 'update public.skills_score set prosent = 91 where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 DELETE B1', 'delete from public.skills_score where id = ''420e49e8-0000-4000-8000-0000420e49e8''', 'skills_score', '420e49e8-0000-4000-8000-0000420e49e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 DELETE B2', 'delete from public.skills_score where id = ''420e49e9-0000-4000-8000-0000420e49e9''', 'skills_score', '420e49e9-0000-4000-8000-0000420e49e9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_skills_score('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('skills_score tablet_B1 DELETE A1', 'delete from public.skills_score where id = ''420e49c9-0000-4000-8000-0000420e49c9''', 'skills_score', '420e49c9-0000-4000-8000-0000420e49c9', 'id');

-- =====================================================================
-- stempling  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling owner_A SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A3 -> ser', exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 110, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', date ''2026-01-01'' + 111, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', date ''2026-01-01'' + 112, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_A INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 113, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling owner_A UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', date '2026-01-01' + 114, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', date '2026-01-01' + 115, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', date '2026-01-01' + 116, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling owner_A DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stempling manager_A1 SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'negativ');
select pg_temp.paastand('stempling manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 117, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 118, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 119, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 120, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stempling manager_A1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.skriv_avvist('stempling manager_A1 FLYTTER egen rad A1 -> A2', 'update public.stempling set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stempling manager_A12 SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling manager_A12 SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 121, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 122, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 123, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 124, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling manager_A12 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling manager_A12 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.skriv_avvist('stempling manager_A12 FLYTTER egen rad A1 -> A3', 'update public.stempling set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stempling tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 125, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 126, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 127, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 128, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stempling owner_B SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling owner_B SELECT B2 -> ser', exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'positiv');
select pg_temp.paastand('stempling owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 129, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', date ''2026-01-01'' + 130, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_B INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 131, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', date '2026-01-01' + 132, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', date '2026-01-01' + 133, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 134, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 135, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 136, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stempling manager_B1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.skriv_avvist('stempling manager_B1 FLYTTER egen rad B1 -> B2', 'update public.stempling set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stempling tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.paastand('stempling tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 137, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 138, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 139, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

-- =====================================================================
-- stempling_hendelse  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling_hendelse');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling_hendelse owner_A SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT A2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT A3 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse owner_A INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling_hendelse owner_A UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse owner_A FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''', 'stempling_hendelse', 'fd47e263-0000-4000-8000-0000fd47e263', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 FLYTTER egen rad A1 -> A2', 'update public.stempling_hendelse set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 FLYTTER egen rad A1 -> A3', 'update public.stempling_hendelse set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse tablet_A1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''', 'stempling_hendelse', 'fd47e263-0000-4000-8000-0000fd47e263', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stempling_hendelse owner_B SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_B SELECT B2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse owner_B INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling_hendelse owner_B UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse owner_B FLYTTER egen rad -> kjede A', 'update public.stempling_hendelse set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_B1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stempling_hendelse manager_B1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''', 'stempling_hendelse', 'fd47e282-0000-4000-8000-0000fd47e282', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 FLYTTER egen rad B1 -> B2', 'update public.stempling_hendelse set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 FLYTTER egen rad -> kjede A', 'update public.stempling_hendelse set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse tablet_B1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''', 'stempling_hendelse', 'fd47e282-0000-4000-8000-0000fd47e282', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

-- =====================================================================
-- synlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('synlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('synlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 165, ''owner_AA1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 166, ''owner_AA2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 167, ''owner_AA3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_A INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 168, ''owner_AB1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('synlig_svinn owner_A UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 169, 'gjenowner_AA1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 170, 'gjenowner_AA2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 171, 'gjenowner_AA3', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('synlig_svinn owner_A DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.skriv_avvist('synlig_svinn owner_A FLYTTER egen rad -> kjede B', 'update public.synlig_svinn set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 172, ''manager_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 173, ''manager_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 174, ''manager_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 175, ''manager_A1B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 176, ''manager_A12A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 177, ''manager_A12A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 178, ''manager_A12A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 179, ''manager_A12B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 180, ''tablet_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 181, ''tablet_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 182, ''tablet_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 183, ''tablet_A1B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('synlig_svinn owner_B SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_B SELECT B2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 184, ''owner_BB1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 185, ''owner_BB2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_B INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 186, ''owner_BA1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('synlig_svinn owner_B UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 187, 'gjenowner_BB1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 188, 'gjenowner_BB2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('synlig_svinn owner_B DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.skriv_avvist('synlig_svinn owner_B FLYTTER egen rad -> kjede A', 'update public.synlig_svinn set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('synlig_svinn manager_B1 SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 189, ''manager_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 190, ''manager_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 191, ''manager_B1A1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 192, ''tablet_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 193, ''tablet_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 194, ''tablet_B1A1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

-- =====================================================================
-- tablet_meldinger  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tablet_meldinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tablet_meldinger owner_A SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT A2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT A3 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AA1'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_AA2'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding owner_AA3'')');
select pg_temp.skriv_avvist('tablet_meldinger owner_A INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tablet_meldinger owner_A UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadc-0000-4000-8000-0000d7d6fadc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tablet_meldinger owner_A DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1A1'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A1A2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A1A3'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger manager_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tablet_meldinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12A1'')');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A12A2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A12A3'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger manager_A12 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tablet_meldinger set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1A1'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_A1A2'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding tablet_A1A3'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger tablet_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tablet_meldinger owner_B SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B SELECT B2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BB1'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_BB2'')');
select pg_temp.skriv_avvist('tablet_meldinger owner_B INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tablet_meldinger owner_B UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fafa-0000-4000-8000-0000d7d6fafa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tablet_meldinger owner_B DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1B1'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_B1B2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger manager_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tablet_meldinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1B1'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_B1B2'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger tablet_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');

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
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b6f-0000-4000-8000-00003bae6b6f'', ''3ccd2784-0000-4000-8000-00003ccd2784'', date ''2026-01-01'' + 254)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc82f1-0000-4000-8000-00003bbc82f1'', ''3cdb3f06-0000-4000-8000-00003cdb3f06'', date ''2026-01-01'' + 255)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a73-0000-4000-8000-00003bca9a73'', ''3ce95688-0000-4000-8000-00003ce95688'', date ''2026-01-01'' + 256)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634411-0000-4000-8000-00003d634411'', ''3e820026-0000-4000-8000-00003e820026'', date ''2026-01-01'' + 257)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6b73-0000-4000-8000-00003bae6b73', '3ccd2788-0000-4000-8000-00003ccd2788', date '2026-01-01' + 258);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc82f5-0000-4000-8000-00003bbc82f5', '3cdb3f0a-0000-4000-8000-00003cdb3f0a', date '2026-01-01' + 259);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '3bca9a8c-0000-4000-8000-00003bca9a8c', '3ce956a1-0000-4000-8000-00003ce956a1', date '2026-01-01' + 260);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b8b-0000-4000-8000-00003bae6b8b'', ''3ccd27a0-0000-4000-8000-00003ccd27a0'', date ''2026-01-01'' + 261)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc830d-0000-4000-8000-00003bbc830d'', ''3cdb3f22-0000-4000-8000-00003cdb3f22'', date ''2026-01-01'' + 262)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a8f-0000-4000-8000-00003bca9a8f'', ''3ce956a4-0000-4000-8000-00003ce956a4'', date ''2026-01-01'' + 263)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63442d-0000-4000-8000-00003d63442d'', ''3e820042-0000-4000-8000-00003e820042'', date ''2026-01-01'' + 264)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6b8f-0000-4000-8000-00003bae6b8f', '3ccd27a4-0000-4000-8000-00003ccd27a4', date '2026-01-01' + 265);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6b90-0000-4000-8000-00003bae6b90'', ''3ccd27a5-0000-4000-8000-00003ccd27a5'', date ''2026-01-01'' + 266)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc8312-0000-4000-8000-00003bbc8312'', ''3cdb3f27-0000-4000-8000-00003cdb3f27'', date ''2026-01-01'' + 267)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9a94-0000-4000-8000-00003bca9a94'', ''3ce956a9-0000-4000-8000-00003ce956a9'', date ''2026-01-01'' + 268)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634432-0000-4000-8000-00003d634432'', ''3e820047-0000-4000-8000-00003e820047'', date ''2026-01-01'' + 269)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6ba9-0000-4000-8000-00003bae6ba9', '3ccd27be-0000-4000-8000-00003ccd27be', date '2026-01-01' + 270);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc832b-0000-4000-8000-00003bbc832b', '3cdb3f40-0000-4000-8000-00003cdb3f40', date '2026-01-01' + 271);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6bab-0000-4000-8000-00003bae6bab'', ''3ccd27c0-0000-4000-8000-00003ccd27c0'', date ''2026-01-01'' + 272)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc832d-0000-4000-8000-00003bbc832d'', ''3cdb3f42-0000-4000-8000-00003cdb3f42'', date ''2026-01-01'' + 273)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9aaf-0000-4000-8000-00003bca9aaf'', ''3ce956c4-0000-4000-8000-00003ce956c4'', date ''2026-01-01'' + 274)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63444d-0000-4000-8000-00003d63444d'', ''3e820062-0000-4000-8000-00003e820062'', date ''2026-01-01'' + 275)');
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
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63444e-0000-4000-8000-00003d63444e'', ''3e820063-0000-4000-8000-00003e820063'', date ''2026-01-01'' + 276)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715bd0-0000-4000-8000-00003d715bd0'', ''3e9017e5-0000-4000-8000-00003e9017e5'', date ''2026-01-01'' + 277)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6bb1-0000-4000-8000-00003bae6bb1'', ''3ccd27c6-0000-4000-8000-00003ccd27c6'', date ''2026-01-01'' + 278)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d634451-0000-4000-8000-00003d634451', '3e820066-0000-4000-8000-00003e820066', date '2026-01-01' + 279);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '3d715be8-0000-4000-8000-00003d715be8', '3e9017fd-0000-4000-8000-00003e9017fd', date '2026-01-01' + 280);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634468-0000-4000-8000-00003d634468'', ''3e82007d-0000-4000-8000-00003e82007d'', date ''2026-01-01'' + 281)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715bea-0000-4000-8000-00003d715bea'', ''3e9017ff-0000-4000-8000-00003e9017ff'', date ''2026-01-01'' + 282)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6bcb-0000-4000-8000-00003bae6bcb'', ''3ccd27e0-0000-4000-8000-00003ccd27e0'', date ''2026-01-01'' + 283)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d63446b-0000-4000-8000-00003d63446b', '3e820080-0000-4000-8000-00003e820080', date '2026-01-01' + 284);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63446c-0000-4000-8000-00003d63446c'', ''3e820081-0000-4000-8000-00003e820081'', date ''2026-01-01'' + 285)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d715bee-0000-4000-8000-00003d715bee'', ''3e901803-0000-4000-8000-00003e901803'', date ''2026-01-01'' + 286)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6bcf-0000-4000-8000-00003bae6bcf'', ''3ccd27e4-0000-4000-8000-00003ccd27e4'', date ''2026-01-01'' + 287)');
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
    raise exception 'TENANT-MATRISEN DEL 6/7: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 6/7: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
