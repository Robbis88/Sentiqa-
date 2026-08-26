-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 8 AV 8. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 3 ressurs(er):
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

-- --- uke_rapport: forutsetninger og proberader ---
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4);

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
-- --- vaer: forutsetninger og proberader ---
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 5);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 6);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 7);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 8);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 9);

create or replace function pg_temp.nyrad_vaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.vaer (stasjon_id, dato)
  values (p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
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
-- uke_rapport  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('uke_rapport');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('uke_rapport owner_A SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A3 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 17)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 18)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 19)');
select pg_temp.skriv_avvist('uke_rapport owner_A INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 20)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 21);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 22);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 23);
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
select pg_temp.skriv_tillatt('uke_rapport manager_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 24)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 25)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 26)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 27)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 28);
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
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 29)');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 30)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 31)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 32)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34);
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
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 35)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 36)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 37)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 38)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 39);
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
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 40)');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 41)');
select pg_temp.skriv_avvist('uke_rapport owner_B INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 42)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 43);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 44);
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
select pg_temp.skriv_tillatt('uke_rapport manager_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 45)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 46)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 47)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 48);
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
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 49)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 50)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 51)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 52);
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
-- vaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('vaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('vaer owner_A SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT A2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT A3 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 53)');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 54)');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 55)');
select pg_temp.skriv_avvist('vaer owner_A INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 56)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('vaer owner_A UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 57);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 58);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 59);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('vaer owner_A DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('vaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'negativ');
select pg_temp.paastand('vaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 61)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 62)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 63)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('vaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'positiv');
select pg_temp.paastand('vaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 64)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 67)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('vaer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'negativ');
select pg_temp.paastand('vaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 68)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 70)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 71)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('vaer owner_B SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer owner_B SELECT B2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'positiv');
select pg_temp.paastand('vaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_tillatt('vaer owner_B INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 72)');
select pg_temp.skriv_tillatt('vaer owner_B INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 73)');
select pg_temp.skriv_avvist('vaer owner_B INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 74)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('vaer owner_B UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 75);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 76);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('vaer owner_B DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('vaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'negativ');
select pg_temp.paastand('vaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 77)');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 78)');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 79)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('vaer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'negativ');
select pg_temp.paastand('vaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 80)');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 81)');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 82)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 8/8: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 8/8: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
