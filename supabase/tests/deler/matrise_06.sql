-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 6 AV 8. Hele matrisen er for stor for Supabase SQL
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
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8597c34c-0000-4000-8000-00008597c34c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8597c70e-0000-4000-8000-00008597c70e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8597cad0-0000-4000-8000-00008597cad0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('859837ae-0000-4000-8000-0000859837ae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('85983b70-0000-4000-8000-000085983b70', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4e1f-0000-4000-8000-00009e8f4e1f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc27f-0000-4000-8000-00009e8fc27f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9036df-0000-4000-8000-00009e9036df', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d65a3-0000-4000-8000-00009e9d65a3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9dda03-0000-4000-8000-00009e9dda03', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a6e2-0000-4000-8000-00002d60a6e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b42-0000-4000-8000-00002d611b42', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fa2-0000-4000-8000-00002d618fa2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe66-0000-4000-8000-00002d6ebe66', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a6e6-0000-4000-8000-00002d60a6e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b46-0000-4000-8000-00002d611b46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fa6-0000-4000-8000-00002d618fa6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a6e9-0000-4000-8000-00002d60a6e9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b5e-0000-4000-8000-00002d611b5e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fbe-0000-4000-8000-00002d618fbe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe82-0000-4000-8000-00002d6ebe82', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a702-0000-4000-8000-00002d60a702', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a703-0000-4000-8000-00002d60a703', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b63-0000-4000-8000-00002d611b63', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fc3-0000-4000-8000-00002d618fc3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe87-0000-4000-8000-00002d6ebe87', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a707-0000-4000-8000-00002d60a707', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b67-0000-4000-8000-00002d611b67', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a71e-0000-4000-8000-00002d60a71e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b7e-0000-4000-8000-00002d611b7e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fde-0000-4000-8000-00002d618fde', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebea2-0000-4000-8000-00002d6ebea2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a722-0000-4000-8000-00002d60a722', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebea4-0000-4000-8000-00002d6ebea4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f3304-0000-4000-8000-00002d6f3304', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a725-0000-4000-8000-00002d60a725', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebea7-0000-4000-8000-00002d6ebea7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f3307-0000-4000-8000-00002d6f3307', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebebe-0000-4000-8000-00002d6ebebe', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f331e-0000-4000-8000-00002d6f331e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a73f-0000-4000-8000-00002d60a73f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebec1-0000-4000-8000-00002d6ebec1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebec2-0000-4000-8000-00002d6ebec2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f3322-0000-4000-8000-00002d6f3322', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a743-0000-4000-8000-00002d60a743', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebec5-0000-4000-8000-00002d6ebec5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a72ea-0000-4000-8000-0000335a72ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a6c-0000-4000-8000-000033688a6c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a1ee-0000-4000-8000-00003376a1ee', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4b8c-0000-4000-8000-0000350f4b8c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a72ee-0000-4000-8000-0000335a72ee', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a70-0000-4000-8000-000033688a70', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a1f2-0000-4000-8000-00003376a1f2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a72f1-0000-4000-8000-0000335a72f1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a73-0000-4000-8000-000033688a73', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a1f5-0000-4000-8000-00003376a1f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ba8-0000-4000-8000-0000350f4ba8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a730a-0000-4000-8000-0000335a730a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a730b-0000-4000-8000-0000335a730b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a8d-0000-4000-8000-000033688a8d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a20f-0000-4000-8000-00003376a20f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4bad-0000-4000-8000-0000350f4bad', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a730f-0000-4000-8000-0000335a730f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a91-0000-4000-8000-000033688a91', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7311-0000-4000-8000-0000335a7311', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688a93-0000-4000-8000-000033688a93', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a4b5-0000-4000-8000-00003376a4b5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e53-0000-4000-8000-0000350f4e53', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75b5-0000-4000-8000-0000335a75b5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e55-0000-4000-8000-0000350f4e55', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65d7-0000-4000-8000-0000351d65d7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75b8-0000-4000-8000-0000335a75b8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e58-0000-4000-8000-0000350f4e58', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65da-0000-4000-8000-0000351d65da', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e5a-0000-4000-8000-0000350f4e5a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65dc-0000-4000-8000-0000351d65dc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75d2-0000-4000-8000-0000335a75d2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e72-0000-4000-8000-0000350f4e72', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e73-0000-4000-8000-0000350f4e73', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d65f5-0000-4000-8000-0000351d65f5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a75d6-0000-4000-8000-0000335a75d6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4e76-0000-4000-8000-0000350f4e76', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
-- --- rutine_utforinger: forutsetninger og proberader ---
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '8597c34c-0000-4000-8000-00008597c34c', date '2026-01-01' + 0);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '8597c70e-0000-4000-8000-00008597c70e', date '2026-01-01' + 1);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '8597cad0-0000-4000-8000-00008597cad0', date '2026-01-01' + 2);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '859837ae-0000-4000-8000-0000859837ae', date '2026-01-01' + 3);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '85983b70-0000-4000-8000-000085983b70', date '2026-01-01' + 4);

create or replace function pg_temp.nyrad_rutine_utforinger(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_rutine uuid := gen_random_uuid();
begin
  insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values (v_rutine, p_retailer, p_stasjon, 'Sonderutine');
  insert into public.rutine_utforinger (stasjon_id, rutine_id, dato)
  values (p_stasjon, v_rutine, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
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
-- --- rutineskjemaer: forutsetninger og proberader ---
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema fastA1', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema fastA2', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a579-0000-4000-8000-000027b1a579', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema fastA3', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema fastB1', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a597-0000-4000-8000-000027b1a597', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema fastB2', '06:00', '14:00');

create or replace function pg_temp.nyrad_rutineskjemaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt)
  values (p_retailer, p_stasjon, 'morgen', 'Sondeskjema ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', '06:00', '14:00')
  returning id into ny;
  return ny;
end $fn$;
-- --- signal_lukket: forutsetninger og proberader ---
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3ca-0000-4000-8000-0000502ec3ca', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde-nullA', date '2026-01-01' + 15, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3cb-0000-4000-8000-0000502ec3cb', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde-nullB', date '2026-01-01' + 16, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-fastA1', date '2026-01-01' + 17, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-fastA2', date '2026-01-01' + 18, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-fastA3', date '2026-01-01' + 19, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-fastB1', date '2026-01-01' + 20, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-fastB2', date '2026-01-01' + 21, 'Sonde');

create or replace function pg_temp.nyrad_signal_lukket(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat)
  values (p_retailer, p_stasjon, 'sonde-' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sonde')
  returning id into ny;
  return ny;
end $fn$;
-- --- sjekkpunkt_svar: forutsetninger og proberader ---
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4e1f-0000-4000-8000-00009e8f4e1f', date '2026-01-01' + 22, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc27f-0000-4000-8000-00009e8fc27f', date '2026-01-01' + 23, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '9e9036df-0000-4000-8000-00009e9036df', date '2026-01-01' + 24, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '9e9d65a3-0000-4000-8000-00009e9d65a3', date '2026-01-01' + 25, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '9e9dda03-0000-4000-8000-00009e9dda03', date '2026-01-01' + 26, true);

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
-- --- stasjoner: forutsetninger og proberader ---
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6337-0000-4000-8000-0000b7fb6337', 'aaaa0000-0000-4000-8000-000000000000', '0037', 'Sondestasjon fastA1', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6338-0000-4000-8000-0000b7fb6338', 'aaaa0000-0000-4000-8000-000000000000', '0038', 'Sondestasjon fastA2', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6339-0000-4000-8000-0000b7fb6339', 'aaaa0000-0000-4000-8000-000000000000', '0039', 'Sondestasjon fastA3', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6356-0000-4000-8000-0000b7fb6356', 'bbbb0000-0000-4000-8000-000000000000', '0040', 'Sondestasjon fastB1', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6357-0000-4000-8000-0000b7fb6357', 'bbbb0000-0000-4000-8000-000000000000', '0041', 'Sondestasjon fastB2', 'sentrum');

create or replace function pg_temp.nyrad_stasjoner(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype)
  values (p_retailer, lpad((9000 + nextval('tenant_teller'::regclass) % 1000)::text, 4, '0'), 'Sondestasjon ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'sentrum')
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- rutine_utforinger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_utforinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_utforinger owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a6e2-0000-4000-8000-00002d60a6e2'', date ''2026-01-01'' + 42)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''2d611b42-0000-4000-8000-00002d611b42'', date ''2026-01-01'' + 43)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''2d618fa2-0000-4000-8000-00002d618fa2'', date ''2026-01-01'' + 44)');
select pg_temp.skriv_avvist('rutine_utforinger owner_A INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebe66-0000-4000-8000-00002d6ebe66'', date ''2026-01-01'' + 45)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_utforinger owner_A UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a6e6-0000-4000-8000-00002d60a6e6', date '2026-01-01' + 46);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611b46-0000-4000-8000-00002d611b46', date '2026-01-01' + 47);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '2d618fa6-0000-4000-8000-00002d618fa6', date '2026-01-01' + 48);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_utforinger owner_A DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a6e9-0000-4000-8000-00002d60a6e9'', date ''2026-01-01'' + 49)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''2d611b5e-0000-4000-8000-00002d611b5e'', date ''2026-01-01'' + 50)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''2d618fbe-0000-4000-8000-00002d618fbe'', date ''2026-01-01'' + 51)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebe82-0000-4000-8000-00002d6ebe82'', date ''2026-01-01'' + 52)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a702-0000-4000-8000-00002d60a702', date '2026-01-01' + 53);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a703-0000-4000-8000-00002d60a703'', date ''2026-01-01'' + 54)');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''2d611b63-0000-4000-8000-00002d611b63'', date ''2026-01-01'' + 55)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''2d618fc3-0000-4000-8000-00002d618fc3'', date ''2026-01-01'' + 56)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebe87-0000-4000-8000-00002d6ebe87'', date ''2026-01-01'' + 57)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a707-0000-4000-8000-00002d60a707', date '2026-01-01' + 58);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611b67-0000-4000-8000-00002d611b67', date '2026-01-01' + 59);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a71e-0000-4000-8000-00002d60a71e'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''2d611b7e-0000-4000-8000-00002d611b7e'', date ''2026-01-01'' + 61)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''2d618fde-0000-4000-8000-00002d618fde'', date ''2026-01-01'' + 62)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebea2-0000-4000-8000-00002d6ebea2'', date ''2026-01-01'' + 63)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a722-0000-4000-8000-00002d60a722', date '2026-01-01' + 64);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutine_utforinger owner_B SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_B SELECT B2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebea4-0000-4000-8000-00002d6ebea4'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''2d6f3304-0000-4000-8000-00002d6f3304'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_avvist('rutine_utforinger owner_B INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a725-0000-4000-8000-00002d60a725'', date ''2026-01-01'' + 67)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebea7-0000-4000-8000-00002d6ebea7', date '2026-01-01' + 68);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '2d6f3307-0000-4000-8000-00002d6f3307', date '2026-01-01' + 69);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebebe-0000-4000-8000-00002d6ebebe'', date ''2026-01-01'' + 70)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''2d6f331e-0000-4000-8000-00002d6f331e'', date ''2026-01-01'' + 71)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a73f-0000-4000-8000-00002d60a73f'', date ''2026-01-01'' + 72)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebec1-0000-4000-8000-00002d6ebec1', date '2026-01-01' + 73);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_utforinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''2d6ebec2-0000-4000-8000-00002d6ebec2'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''2d6f3322-0000-4000-8000-00002d6f3322'', date ''2026-01-01'' + 75)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a743-0000-4000-8000-00002d60a743'', date ''2026-01-01'' + 76)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebec5-0000-4000-8000-00002d6ebec5', date '2026-01-01' + 77);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_utforinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

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
-- rutineskjemaer  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutineskjemaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutineskjemaer owner_A SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT A2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT A3 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_AA1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema owner_AA2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema owner_AA3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer owner_A INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_AB1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutineskjemaer owner_A UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenowner_AA1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenowner_AA2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a579-0000-4000-8000-000027b1a579', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema gjenowner_AA3', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutineskjemaer owner_A DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer owner_A FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A1A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_A1A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema manager_A1A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A1B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_A1A1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutineskjemaer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A12A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_A12A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema manager_A12A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A12B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_A12A1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenmanager_A12A2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutineskjemaer set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_A1A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema tablet_A1A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema tablet_A1A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_A1B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutineskjemaer owner_B SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_B SELECT B2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_BB1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema owner_BB2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer owner_B INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_BA1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutineskjemaer owner_B UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenowner_BB1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a597-0000-4000-8000-000027b1a597', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenowner_BB2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutineskjemaer owner_B DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer owner_B FLYTTER egen rad -> kjede A', 'update public.rutineskjemaer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_B1B1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_B1B2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_B1A1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_B1B1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutineskjemaer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 FLYTTER egen rad -> kjede A', 'update public.rutineskjemaer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_B1B1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema tablet_B1B2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_B1A1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

-- =====================================================================
-- signal_lukket  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('signal_lukket');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('signal_lukket owner_A SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A3 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_AA1'', date ''2026-01-01'' + 146, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-owner_AA2'', date ''2026-01-01'' + 147, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-owner_AA3'', date ''2026-01-01'' + 148, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_A INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_AB1'', date ''2026-01-01'' + 149, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('signal_lukket owner_A UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_AA1', date '2026-01-01' + 150, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_AA2', date '2026-01-01' + 151, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-gjenowner_AA3', date '2026-01-01' + 152, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('signal_lukket owner_A DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('signal_lukket manager_A1 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1A1'', date ''2026-01-01'' + 153, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A1A2'', date ''2026-01-01'' + 154, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A1A3'', date ''2026-01-01'' + 155, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1B1'', date ''2026-01-01'' + 156, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A1A1', date '2026-01-01' + 157, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket manager_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_A1 FLYTTER egen rad A1 -> A2', 'update public.signal_lukket set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('signal_lukket manager_A12 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 SELECT A2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12A1'', date ''2026-01-01'' + 158, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A12A2'', date ''2026-01-01'' + 159, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A12A3'', date ''2026-01-01'' + 160, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12B1'', date ''2026-01-01'' + 161, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A12A1', date '2026-01-01' + 162, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenmanager_A12A2', date '2026-01-01' + 163, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket manager_A12 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_A12 FLYTTER egen rad A1 -> A3', 'update public.signal_lukket set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1A1'', date ''2026-01-01'' + 164, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-tablet_A1A2'', date ''2026-01-01'' + 165, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-tablet_A1A3'', date ''2026-01-01'' + 166, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1B1'', date ''2026-01-01'' + 167, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket tablet_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('signal_lukket owner_B SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B SELECT B2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_BB1'', date ''2026-01-01'' + 168, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-owner_BB2'', date ''2026-01-01'' + 169, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_B INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_BA1'', date ''2026-01-01'' + 170, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('signal_lukket owner_B UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_BB1', date '2026-01-01' + 171, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_BB2', date '2026-01-01' + 172, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('signal_lukket owner_B DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('signal_lukket manager_B1 SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'negativ');
select pg_temp.paastand('signal_lukket manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1B1'', date ''2026-01-01'' + 173, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-manager_B1B2'', date ''2026-01-01'' + 174, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1A1'', date ''2026-01-01'' + 175, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_B1B1', date '2026-01-01' + 176, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket manager_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_B1 FLYTTER egen rad B1 -> B2', 'update public.signal_lukket set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('signal_lukket tablet_B1 SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1B1'', date ''2026-01-01'' + 177, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-tablet_B1B2'', date ''2026-01-01'' + 178, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1A1'', date ''2026-01-01'' + 179, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket tablet_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');

-- =====================================================================
-- sjekkpunkt_svar  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('sjekkpunkt_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A3 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a72ea-0000-4000-8000-0000335a72ea'', date ''2026-01-01'' + 180, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688a6c-0000-4000-8000-000033688a6c'', date ''2026-01-01'' + 181, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a1ee-0000-4000-8000-00003376a1ee'', date ''2026-01-01'' + 182, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4b8c-0000-4000-8000-0000350f4b8c'', date ''2026-01-01'' + 183, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a72ee-0000-4000-8000-0000335a72ee', date '2026-01-01' + 184, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688a70-0000-4000-8000-000033688a70', date '2026-01-01' + 185, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '3376a1f2-0000-4000-8000-00003376a1f2', date '2026-01-01' + 186, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a72f1-0000-4000-8000-0000335a72f1'', date ''2026-01-01'' + 187, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688a73-0000-4000-8000-000033688a73'', date ''2026-01-01'' + 188, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a1f5-0000-4000-8000-00003376a1f5'', date ''2026-01-01'' + 189, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ba8-0000-4000-8000-0000350f4ba8'', date ''2026-01-01'' + 190, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a730a-0000-4000-8000-0000335a730a', date '2026-01-01' + 191, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a730b-0000-4000-8000-0000335a730b'', date ''2026-01-01'' + 192, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688a8d-0000-4000-8000-000033688a8d'', date ''2026-01-01'' + 193, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a20f-0000-4000-8000-00003376a20f'', date ''2026-01-01'' + 194, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4bad-0000-4000-8000-0000350f4bad'', date ''2026-01-01'' + 195, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a730f-0000-4000-8000-0000335a730f', date '2026-01-01' + 196, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688a91-0000-4000-8000-000033688a91', date '2026-01-01' + 197, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7311-0000-4000-8000-0000335a7311'', date ''2026-01-01'' + 198, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688a93-0000-4000-8000-000033688a93'', date ''2026-01-01'' + 199, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a4b5-0000-4000-8000-00003376a4b5'', date ''2026-01-01'' + 200, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e53-0000-4000-8000-0000350f4e53'', date ''2026-01-01'' + 201, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a75b5-0000-4000-8000-0000335a75b5', date '2026-01-01' + 202, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e55-0000-4000-8000-0000350f4e55'', date ''2026-01-01'' + 203, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d65d7-0000-4000-8000-0000351d65d7'', date ''2026-01-01'' + 204, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75b8-0000-4000-8000-0000335a75b8'', date ''2026-01-01'' + 205, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e58-0000-4000-8000-0000350f4e58', date '2026-01-01' + 206, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '351d65da-0000-4000-8000-0000351d65da', date '2026-01-01' + 207, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e5a-0000-4000-8000-0000350f4e5a'', date ''2026-01-01'' + 208, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d65dc-0000-4000-8000-0000351d65dc'', date ''2026-01-01'' + 209, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75d2-0000-4000-8000-0000335a75d2'', date ''2026-01-01'' + 210, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e72-0000-4000-8000-0000350f4e72', date '2026-01-01' + 211, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4e73-0000-4000-8000-0000350f4e73'', date ''2026-01-01'' + 212, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d65f5-0000-4000-8000-0000351d65f5'', date ''2026-01-01'' + 213, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a75d6-0000-4000-8000-0000335a75d6'', date ''2026-01-01'' + 214, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4e76-0000-4000-8000-0000350f4e76', date '2026-01-01' + 215, true);
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
-- stasjoner  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stasjoner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stasjoner owner_A SELECT A -> ser', exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'positiv');
select pg_temp.paastand('stasjoner owner_A SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_tillatt('stasjoner owner_A INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0284'', ''Sondestasjon owner_AA1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner owner_A INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0285'', ''Sondestasjon owner_AB1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjoner owner_A UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stasjoner owner_A UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjoner owner_A DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''');
select pg_temp.som_eier();
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6337-0000-4000-8000-0000b7fb6337', 'aaaa0000-0000-4000-8000-000000000000', '0286', 'Sondestasjon gjenowner_AA1', 'sentrum');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stasjoner owner_A DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.skriv_avvist('stasjoner owner_A FLYTTER egen rad -> kjede B', 'update public.stasjoner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stasjoner manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.paastand('stasjoner manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_avvist('stasjoner manager_A1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0287'', ''Sondestasjon manager_A1A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_A1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0288'', ''Sondestasjon manager_A1B1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjoner manager_A1 UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjoner manager_A1 UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjoner manager_A1 DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjoner manager_A1 DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stasjoner manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.paastand('stasjoner manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_avvist('stasjoner manager_A12 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0289'', ''Sondestasjon manager_A12A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_A12 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0290'', ''Sondestasjon manager_A12B1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjoner manager_A12 UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjoner manager_A12 UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjoner manager_A12 DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjoner manager_A12 DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stasjoner tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.paastand('stasjoner tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_avvist('stasjoner tablet_A1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0291'', ''Sondestasjon tablet_A1A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner tablet_A1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0292'', ''Sondestasjon tablet_A1B1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjoner tablet_A1 UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjoner tablet_A1 UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjoner tablet_A1 DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjoner tablet_A1 DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stasjoner owner_B SELECT B -> ser', exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'positiv');
select pg_temp.paastand('stasjoner owner_B SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.skriv_tillatt('stasjoner owner_B INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0293'', ''Sondestasjon owner_BB1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner owner_B INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0294'', ''Sondestasjon owner_BA1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjoner owner_B UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stasjoner owner_B UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjoner owner_B DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''');
select pg_temp.som_eier();
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6356-0000-4000-8000-0000b7fb6356', 'bbbb0000-0000-4000-8000-000000000000', '0295', 'Sondestasjon gjenowner_BB1', 'sentrum');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stasjoner owner_B DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.skriv_avvist('stasjoner owner_B FLYTTER egen rad -> kjede A', 'update public.stasjoner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stasjoner manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.paastand('stasjoner manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.skriv_avvist('stasjoner manager_B1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0296'', ''Sondestasjon manager_B1B1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_B1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0297'', ''Sondestasjon manager_B1A1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjoner manager_B1 UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjoner manager_B1 UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjoner manager_B1 DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjoner manager_B1 DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stasjoner tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.paastand('stasjoner tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.skriv_avvist('stasjoner tablet_B1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0298'', ''Sondestasjon tablet_B1B1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner tablet_B1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0299'', ''Sondestasjon tablet_B1A1'', ''sentrum'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjoner tablet_B1 UPDATE B', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjoner tablet_B1 UPDATE A', 'update public.stasjoner set navn = ''endret av sonden'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjoner tablet_B1 DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjoner tablet_B1 DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 6/8: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 6/8: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
