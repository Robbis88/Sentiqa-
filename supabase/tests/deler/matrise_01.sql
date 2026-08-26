-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 1 AV 5. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 9 ressurs(er):
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

-- --- ansatt_avtale: forutsetninger og proberader ---
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de395-0000-4000-8000-00008b2de395', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b3-0000-4000-8000-00008b2de3b3', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', 80);

create or replace function pg_temp.nyrad_ansatt_avtale(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent)
  values (p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 80)
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_fravaer: forutsetninger og proberader ---
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 5, date '2026-01-01' + 5, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 6, date '2026-01-01' + 6, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 7, date '2026-01-01' + 7, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 8, date '2026-01-01' + 8, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 9, date '2026-01-01' + 9, 'Sonde');

create or replace function pg_temp.nyrad_bemanning_fravaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak)
  values (p_stasjon, 'Sonde Sondesen', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sonde')
  returning id into ny;
  return ny;
end $fn$;
-- --- ansatt_kontrakt: forutsetninger og proberader ---
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463a-0000-4000-8000-000052b0463a', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', 'utkast');
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463b-0000-4000-8000-000052b0463b', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', 'utkast');
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463c-0000-4000-8000-000052b0463c', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', 'utkast');
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b04659-0000-4000-8000-000052b04659', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', 'utkast');
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0465a-0000-4000-8000-000052b0465a', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', 'utkast');

create or replace function pg_temp.nyrad_ansatt_kontrakt(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status)
  values (p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 'utkast')
  returning id into ny;
  return ny;
end $fn$;
-- --- persondata_logg: forutsetninger og proberader ---
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d7-0000-4000-8000-0000a78b10d7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastA1', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d8-0000-4000-8000-0000a78b10d8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastA2', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d9-0000-4000-8000-0000a78b10d9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde_oppslag', 'fastA3', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f6-0000-4000-8000-0000a78b10f6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastB1', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f7-0000-4000-8000-0000a78b10f7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastB2', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
-- --- kontrolltiltak_bekreftelse: forutsetninger og proberader ---
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea45-0000-4000-8000-00009d6fea45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'fastA1', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea46-0000-4000-8000-00009d6fea46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'fastA2', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea47-0000-4000-8000-00009d6fea47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'fastA3', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea64-0000-4000-8000-00009d6fea64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'fastB1', '00000000-0000-0000-0000-00000000b000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea65-0000-4000-8000-00009d6fea65', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'fastB2', '00000000-0000-0000-0000-00000000b000');
-- --- timesalg: forutsetninger og proberader ---
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 25, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 26, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 27, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 28, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 29, '8-9', 1000, 10);

create or replace function pg_temp.nyrad_timesalg(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '8-9', 1000, 10);
end $fn$;
-- --- kassererstatistikk: forutsetninger og proberader ---
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30, 'fastA1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31, 'fastA2', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 32, 'fastA3', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33, 'fastB1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34, 'fastB2', 'Sonde Sondesen', 1000, 10);

create or replace function pg_temp.nyrad_kassererstatistikk(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 1000, 10);
end $fn$;
-- --- trafikk: forutsetninger og proberader ---
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 37, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 38, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 39, 1000, 80);
-- --- prognose_kalibrering: forutsetninger og proberader ---
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastA1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastA2', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', 'fastA3', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastB1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastB2', 1.05, 30);

-- =====================================================================
-- ansatt_avtale  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ansatt_avtale');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ansatt_avtale owner_A SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT A2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT A3 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale owner_A INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_avtale owner_A UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de395-0000-4000-8000-00008b2de395', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_avtale owner_A DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A1A1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 FLYTTER egen rad A1 -> A2', 'update public.ansatt_avtale set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A12A1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'gjenmanager_A12A2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 FLYTTER egen rad A1 -> A3', 'update public.ansatt_avtale set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ansatt_avtale owner_B SELECT B1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_B SELECT B2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale owner_B INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_avtale owner_B UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b3-0000-4000-8000-00008b2de3b3', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_avtale owner_B DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT B1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'gjenmanager_B1B1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 FLYTTER egen rad B1 -> B2', 'update public.ansatt_avtale set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

-- =====================================================================
-- bemanning_fravaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fravaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 79, date ''2026-01-01'' + 79, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 80, date ''2026-01-01'' + 80, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 81, date ''2026-01-01'' + 81, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 82, date ''2026-01-01'' + 82, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 83, date '2026-01-01' + 83, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 84, date '2026-01-01' + 84, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 85, date '2026-01-01' + 85, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 86, date ''2026-01-01'' + 86, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 87, date ''2026-01-01'' + 87, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 88, date ''2026-01-01'' + 88, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 89, date ''2026-01-01'' + 89, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 90, date '2026-01-01' + 90, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_fravaer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 91, date ''2026-01-01'' + 91, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 92, date ''2026-01-01'' + 92, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 93, date ''2026-01-01'' + 93, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 94, date ''2026-01-01'' + 94, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 95, date '2026-01-01' + 95, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 96, date '2026-01-01' + 96, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_fravaer set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 97, date ''2026-01-01'' + 97, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 98, date ''2026-01-01'' + 98, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 99, date ''2026-01-01'' + 99, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 100, date ''2026-01-01'' + 100, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_fravaer owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 101, date ''2026-01-01'' + 101, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 102, date ''2026-01-01'' + 102, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 103, date ''2026-01-01'' + 103, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 104, date '2026-01-01' + 104, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 105, date '2026-01-01' + 105, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 106, date ''2026-01-01'' + 106, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 107, date ''2026-01-01'' + 107, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 108, date ''2026-01-01'' + 108, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 109, date '2026-01-01' + 109, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_fravaer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 110, date ''2026-01-01'' + 110, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 111, date ''2026-01-01'' + 111, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 112, date ''2026-01-01'' + 112, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

-- =====================================================================
-- ansatt_kontrakt  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ansatt_kontrakt');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ansatt_kontrakt owner_A SELECT A1 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt owner_A SELECT A2 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463b-0000-4000-8000-000052b0463b'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt owner_A SELECT A3 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463c-0000-4000-8000-000052b0463c'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A INSERT A2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A INSERT A3', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_A INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A UPDATE A2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463b-0000-4000-8000-000052b0463b''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A UPDATE A3', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463c-0000-4000-8000-000052b0463c''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_A UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''');
select pg_temp.som_eier();
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463a-0000-4000-8000-000052b0463a', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', 'utkast');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A DELETE A2', 'delete from public.ansatt_kontrakt where id = ''52b0463b-0000-4000-8000-000052b0463b''');
select pg_temp.som_eier();
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463b-0000-4000-8000-000052b0463b', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', 'utkast');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_A DELETE A3', 'delete from public.ansatt_kontrakt where id = ''52b0463c-0000-4000-8000-000052b0463c''');
select pg_temp.som_eier();
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0463c-0000-4000-8000-000052b0463c', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', 'utkast');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_A DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ansatt_kontrakt manager_A1 SELECT A1 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463b-0000-4000-8000-000052b0463b'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463c-0000-4000-8000-000052b0463c'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A1 INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 INSERT A2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 INSERT A3', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A1 UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 UPDATE A2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463b-0000-4000-8000-000052b0463b''', 'ansatt_kontrakt', '52b0463b-0000-4000-8000-000052b0463b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 UPDATE A3', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 DELETE A2', 'delete from public.ansatt_kontrakt where id = ''52b0463b-0000-4000-8000-000052b0463b''', 'ansatt_kontrakt', '52b0463b-0000-4000-8000-000052b0463b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 DELETE A3', 'delete from public.ansatt_kontrakt where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A1 FLYTTER egen rad A1 -> A2', 'update public.ansatt_kontrakt set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ansatt_kontrakt manager_A12 SELECT A1 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt manager_A12 SELECT A2 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0463b-0000-4000-8000-000052b0463b'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463c-0000-4000-8000-000052b0463c'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A12 INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A12 INSERT A2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 INSERT A3', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A12 UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_A12 UPDATE A2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463b-0000-4000-8000-000052b0463b''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 UPDATE A3', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 DELETE A2', 'delete from public.ansatt_kontrakt where id = ''52b0463b-0000-4000-8000-000052b0463b''', 'ansatt_kontrakt', '52b0463b-0000-4000-8000-000052b0463b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 DELETE A3', 'delete from public.ansatt_kontrakt where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_A12 FLYTTER egen rad A1 -> A3', 'update public.ansatt_kontrakt set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ansatt_kontrakt tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463b-0000-4000-8000-000052b0463b'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463c-0000-4000-8000-000052b0463c'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'negativ');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 INSERT A2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 INSERT A3', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 UPDATE A2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463b-0000-4000-8000-000052b0463b''', 'ansatt_kontrakt', '52b0463b-0000-4000-8000-000052b0463b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 UPDATE A3', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 DELETE A2', 'delete from public.ansatt_kontrakt where id = ''52b0463b-0000-4000-8000-000052b0463b''', 'ansatt_kontrakt', '52b0463b-0000-4000-8000-000052b0463b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 DELETE A3', 'delete from public.ansatt_kontrakt where id = ''52b0463c-0000-4000-8000-000052b0463c''', 'ansatt_kontrakt', '52b0463c-0000-4000-8000-000052b0463c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_A1 DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ansatt_kontrakt owner_B SELECT B1 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt owner_B SELECT B2 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b0465a-0000-4000-8000-000052b0465a'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B INSERT B2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_B INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B UPDATE B2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0465a-0000-4000-8000-000052b0465a''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_B UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''');
select pg_temp.som_eier();
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b04659-0000-4000-8000-000052b04659', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', 'utkast');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_kontrakt owner_B DELETE B2', 'delete from public.ansatt_kontrakt where id = ''52b0465a-0000-4000-8000-000052b0465a''');
select pg_temp.som_eier();
insert into public.ansatt_kontrakt (id, stasjon_id, ansatt_nr, ansatt_navn, status) values ('52b0465a-0000-4000-8000-000052b0465a', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', 'utkast');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_kontrakt owner_B DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ansatt_kontrakt manager_B1 SELECT B1 -> ser', exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'positiv');
select pg_temp.paastand('ansatt_kontrakt manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0465a-0000-4000-8000-000052b0465a'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_B1 INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 INSERT B2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatt_kontrakt manager_B1 UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 UPDATE B2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0465a-0000-4000-8000-000052b0465a''', 'ansatt_kontrakt', '52b0465a-0000-4000-8000-000052b0465a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 DELETE B2', 'delete from public.ansatt_kontrakt where id = ''52b0465a-0000-4000-8000-000052b0465a''', 'ansatt_kontrakt', '52b0465a-0000-4000-8000-000052b0465a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.skriv_avvist('ansatt_kontrakt manager_B1 FLYTTER egen rad B1 -> B2', 'update public.ansatt_kontrakt set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ansatt_kontrakt tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b04659-0000-4000-8000-000052b04659'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0465a-0000-4000-8000-000052b0465a'), 'negativ');
select pg_temp.paastand('ansatt_kontrakt tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_kontrakt where id = '52b0463a-0000-4000-8000-000052b0463a'), 'negativ');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 INSERT B1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 INSERT B2', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 INSERT A1', 'insert into public.ansatt_kontrakt (stasjon_id, ansatt_nr, ansatt_navn, status) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', ''utkast'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 UPDATE B1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 UPDATE B2', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0465a-0000-4000-8000-000052b0465a''', 'ansatt_kontrakt', '52b0465a-0000-4000-8000-000052b0465a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 UPDATE A1', 'update public.ansatt_kontrakt set status = ''sendt'' where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 DELETE B1', 'delete from public.ansatt_kontrakt where id = ''52b04659-0000-4000-8000-000052b04659''', 'ansatt_kontrakt', '52b04659-0000-4000-8000-000052b04659', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 DELETE B2', 'delete from public.ansatt_kontrakt where id = ''52b0465a-0000-4000-8000-000052b0465a''', 'ansatt_kontrakt', '52b0465a-0000-4000-8000-000052b0465a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_kontrakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_kontrakt tablet_B1 DELETE A1', 'delete from public.ansatt_kontrakt where id = ''52b0463a-0000-4000-8000-000052b0463a''', 'ansatt_kontrakt', '52b0463a-0000-4000-8000-000052b0463a', 'id');

-- =====================================================================
-- persondata_logg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('persondata_logg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('persondata_logg owner_A SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A3 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_A INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('persondata_logg manager_A1 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A3 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('persondata_logg manager_A12 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A3 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A12 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('persondata_logg owner_B SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT B2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_B INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('persondata_logg manager_B1 SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg manager_B1 SELECT B2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');

-- =====================================================================
-- kontrolltiltak_bekreftelse  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kontrolltiltak_bekreftelse');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A3 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'')');

-- =====================================================================
-- timesalg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('timesalg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('timesalg owner_A SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 26 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A3 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 193, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 194, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 195, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_A INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 196, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 25, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 26, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 27, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_A FLYTTER egen rad -> kjede B', 'update public.timesalg set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('timesalg manager_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 26 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 197, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 198, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 199, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 200, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('timesalg manager_A12 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 26 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 201, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 202, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 203, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 204, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('timesalg tablet_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 26 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 205, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 206, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 207, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 208, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 26 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('timesalg owner_B SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT B2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 209, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 210, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_B INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 211, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 28, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 29, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_B FLYTTER egen rad -> kjede A', 'update public.timesalg set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('timesalg manager_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 212, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 213, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 214, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('timesalg tablet_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 25 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 215, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 216, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 217, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 25 and "time" = ''8-9''');

-- =====================================================================
-- kassererstatistikk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kassererstatistikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kassererstatistikk owner_A SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A3 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA3'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 218, ''owner_AA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 219, ''owner_AA2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 220, ''owner_AA3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_A INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 221, ''owner_AB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30, 'fastA1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31, 'fastA2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 32, 'fastA3', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A FLYTTER egen rad -> kjede B', 'update public.kassererstatistikk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 222, ''manager_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 223, ''manager_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 224, ''manager_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 225, ''manager_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 226, ''manager_A12A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 227, ''manager_A12A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 228, ''manager_A12A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 229, ''manager_A12B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 230, ''tablet_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 231, ''tablet_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 232, ''tablet_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 233, ''tablet_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kassererstatistikk owner_B SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT B2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastB2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 234, ''owner_BB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 235, ''owner_BB2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_B INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 236, ''owner_BA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33, 'fastB1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34, 'fastB2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B FLYTTER egen rad -> kjede A', 'update public.kassererstatistikk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 237, ''manager_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 238, ''manager_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 239, ''manager_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 240, ''tablet_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 241, ''tablet_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 242, ''tablet_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "kasserer_nr" = ''fastA1''');

-- =====================================================================
-- trafikk  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('trafikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('trafikk owner_A SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A3 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 37), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('trafikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 37), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('trafikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 37), 'negativ');
select pg_temp.paastand('trafikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('trafikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 37), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('trafikk owner_B SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT B2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 39), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('trafikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'positiv');
select pg_temp.paastand('trafikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 39), 'negativ');
select pg_temp.paastand('trafikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('trafikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 38), 'positiv');
select pg_temp.paastand('trafikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 39), 'negativ');
select pg_temp.paastand('trafikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

-- =====================================================================
-- prognose_kalibrering  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('prognose_kalibrering');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('prognose_kalibrering owner_A SELECT A1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering owner_A SELECT A2 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastA2'), 'positiv');
select pg_temp.paastand('prognose_kalibrering owner_A SELECT A3 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "type" = 'produksjonsplan' and "kategori" = 'fastA3'), 'positiv');
select pg_temp.paastand('prognose_kalibrering owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('prognose_kalibrering manager_A1 SELECT A1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastA2'), 'negativ');
select pg_temp.paastand('prognose_kalibrering manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "type" = 'produksjonsplan' and "kategori" = 'fastA3'), 'negativ');
select pg_temp.paastand('prognose_kalibrering manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('prognose_kalibrering manager_A12 SELECT A1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering manager_A12 SELECT A2 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastA2'), 'positiv');
select pg_temp.paastand('prognose_kalibrering manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "type" = 'produksjonsplan' and "kategori" = 'fastA3'), 'negativ');
select pg_temp.paastand('prognose_kalibrering manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('prognose_kalibrering tablet_A1 SELECT A1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastA2'), 'negativ');
select pg_temp.paastand('prognose_kalibrering tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "type" = 'produksjonsplan' and "kategori" = 'fastA3'), 'negativ');
select pg_temp.paastand('prognose_kalibrering tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('prognose_kalibrering owner_B SELECT B1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering owner_B SELECT B2 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastB2'), 'positiv');
select pg_temp.paastand('prognose_kalibrering owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('prognose_kalibrering manager_B1 SELECT B1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastB2'), 'negativ');
select pg_temp.paastand('prognose_kalibrering manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('prognose_kalibrering tablet_B1 SELECT B1 -> ser', exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastB1'), 'positiv');
select pg_temp.paastand('prognose_kalibrering tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "type" = 'produksjonsplan' and "kategori" = 'fastB2'), 'negativ');
select pg_temp.paastand('prognose_kalibrering tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_kalibrering where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "type" = 'produksjonsplan' and "kategori" = 'fastA1'), 'negativ');

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
    raise exception 'TENANT-MATRISEN DEL 1/5: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 1/5: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
