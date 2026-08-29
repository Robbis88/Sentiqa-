-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 8 AV 10. Hele matrisen er for stor for Supabase SQL
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
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('b288c078-0000-4000-8000-0000b288c078', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('b288c43a-0000-4000-8000-0000b288c43a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('b288c7fc-0000-4000-8000-0000b288c7fc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d657f-0000-4000-8000-00009e9d657f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9dd9df-0000-4000-8000-00009e9dd9df', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4ebe-0000-4000-8000-00009e8f4ebe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc31e-0000-4000-8000-00009e8fc31e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e90377e-0000-4000-8000-00009e90377e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d6642-0000-4000-8000-00009e9d6642', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4ed7-0000-4000-8000-00009e8f4ed7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc337-0000-4000-8000-00009e8fc337', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e903797-0000-4000-8000-00009e903797', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4eda-0000-4000-8000-00009e8f4eda', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc33a-0000-4000-8000-00009e8fc33a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e90379a-0000-4000-8000-00009e90379a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d665e-0000-4000-8000-00009e9d665e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4ede-0000-4000-8000-00009e8f4ede', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4edf-0000-4000-8000-00009e8f4edf', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc33f-0000-4000-8000-00009e8fc33f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9037b4-0000-4000-8000-00009e9037b4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d6678-0000-4000-8000-00009e9d6678', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4ef8-0000-4000-8000-00009e8f4ef8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc358-0000-4000-8000-00009e8fc358', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4efa-0000-4000-8000-00009e8f4efa', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc35a-0000-4000-8000-00009e8fc35a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9037ba-0000-4000-8000-00009e9037ba', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d667e-0000-4000-8000-00009e9d667e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4efe-0000-4000-8000-00009e8f4efe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d6680-0000-4000-8000-00009e9d6680', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6212-0000-4000-8000-0000351d6212', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a71f3-0000-4000-8000-0000335a71f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4a93-0000-4000-8000-0000350f4a93', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6215-0000-4000-8000-0000351d6215', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4a95-0000-4000-8000-0000350f4a95', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6217-0000-4000-8000-0000351d6217', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a71f8-0000-4000-8000-0000335a71f8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4a98-0000-4000-8000-0000350f4a98', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4a99-0000-4000-8000-0000350f4a99', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d621b-0000-4000-8000-0000351d621b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7211-0000-4000-8000-0000335a7211', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ab1-0000-4000-8000-0000350f4ab1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
-- --- signal_lukket: forutsetninger og proberader ---
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3ca-0000-4000-8000-0000502ec3ca', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde-nullA', date '2026-01-01' + 0, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3cb-0000-4000-8000-0000502ec3cb', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde-nullB', date '2026-01-01' + 1, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-fastA1', date '2026-01-01' + 2, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-fastA2', date '2026-01-01' + 3, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-fastA3', date '2026-01-01' + 4, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-fastB1', date '2026-01-01' + 5, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-fastB2', date '2026-01-01' + 6, 'Sonde');

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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', 'b288c078-0000-4000-8000-0000b288c078', date '2026-01-01' + 7, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', 'b288c43a-0000-4000-8000-0000b288c43a', date '2026-01-01' + 8, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', 'b288c7fc-0000-4000-8000-0000b288c7fc', date '2026-01-01' + 9, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '9e9d657f-0000-4000-8000-00009e9d657f', date '2026-01-01' + 10, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '9e9dd9df-0000-4000-8000-00009e9dd9df', date '2026-01-01' + 11, true);

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
-- --- stasjon_produksjon_innstilling: forutsetninger og proberader ---
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce44-0000-4000-8000-0000409fce44', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'fastA1');
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce45-0000-4000-8000-0000409fce45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'fastA2');
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce46-0000-4000-8000-0000409fce46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'fastA3');
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce63-0000-4000-8000-0000409fce63', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'fastB1');
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce64-0000-4000-8000-0000409fce64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'fastB2');

create or replace function pg_temp.nyrad_stasjon_produksjon_innstilling(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode)
  values (p_retailer, p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- stasjoner: forutsetninger og proberader ---
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6337-0000-4000-8000-0000b7fb6337', 'aaaa0000-0000-4000-8000-000000000000', '0027', 'Sondestasjon fastA1', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6338-0000-4000-8000-0000b7fb6338', 'aaaa0000-0000-4000-8000-000000000000', '0028', 'Sondestasjon fastA2', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6339-0000-4000-8000-0000b7fb6339', 'aaaa0000-0000-4000-8000-000000000000', '0029', 'Sondestasjon fastA3', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6356-0000-4000-8000-0000b7fb6356', 'bbbb0000-0000-4000-8000-000000000000', '0030', 'Sondestasjon fastB1', 'sentrum');
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6357-0000-4000-8000-0000b7fb6357', 'bbbb0000-0000-4000-8000-000000000000', '0031', 'Sondestasjon fastB2', 'sentrum');

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
-- --- stempling: forutsetninger og proberader ---
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', date '2026-01-01' + 32, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', date '2026-01-01' + 33, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', date '2026-01-01' + 34, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', date '2026-01-01' + 35, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', date '2026-01-01' + 36, clock_timestamp()::time, time '16:00', 480);

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

-- =====================================================================
-- signal_lukket  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('signal_lukket');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('signal_lukket owner_A SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A3 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_AA1'', date ''2026-01-01'' + 42, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-owner_AA2'', date ''2026-01-01'' + 43, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-owner_AA3'', date ''2026-01-01'' + 44, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_A INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_AB1'', date ''2026-01-01'' + 45, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_AA1', date '2026-01-01' + 46, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_AA2', date '2026-01-01' + 47, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-gjenowner_AA3', date '2026-01-01' + 48, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1A1'', date ''2026-01-01'' + 49, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A1A2'', date ''2026-01-01'' + 50, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A1A3'', date ''2026-01-01'' + 51, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1B1'', date ''2026-01-01'' + 52, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A1A1', date '2026-01-01' + 53, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12A1'', date ''2026-01-01'' + 54, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A12A2'', date ''2026-01-01'' + 55, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A12A3'', date ''2026-01-01'' + 56, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12B1'', date ''2026-01-01'' + 57, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A12A1', date '2026-01-01' + 58, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenmanager_A12A2', date '2026-01-01' + 59, 'Sonde');
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
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1A1'', date ''2026-01-01'' + 60, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-tablet_A1A2'', date ''2026-01-01'' + 61, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-tablet_A1A3'', date ''2026-01-01'' + 62, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1B1'', date ''2026-01-01'' + 63, ''Sonde'')');
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
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_BB1'', date ''2026-01-01'' + 64, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-owner_BB2'', date ''2026-01-01'' + 65, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_B INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_BA1'', date ''2026-01-01'' + 66, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_BB1', date '2026-01-01' + 67, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_BB2', date '2026-01-01' + 68, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1B1'', date ''2026-01-01'' + 69, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-manager_B1B2'', date ''2026-01-01'' + 70, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1A1'', date ''2026-01-01'' + 71, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_B1B1', date '2026-01-01' + 72, 'Sonde');
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
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1B1'', date ''2026-01-01'' + 73, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-tablet_B1B2'', date ''2026-01-01'' + 74, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1A1'', date ''2026-01-01'' + 75, ''Sonde'')');
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''9e8f4ebe-0000-4000-8000-00009e8f4ebe'', date ''2026-01-01'' + 76, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''9e8fc31e-0000-4000-8000-00009e8fc31e'', date ''2026-01-01'' + 77, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''9e90377e-0000-4000-8000-00009e90377e'', date ''2026-01-01'' + 78, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''9e9d6642-0000-4000-8000-00009e9d6642'', date ''2026-01-01'' + 79, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4ed7-0000-4000-8000-00009e8f4ed7', date '2026-01-01' + 80, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc337-0000-4000-8000-00009e8fc337', date '2026-01-01' + 81, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '9e903797-0000-4000-8000-00009e903797', date '2026-01-01' + 82, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''9e8f4eda-0000-4000-8000-00009e8f4eda'', date ''2026-01-01'' + 83, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''9e8fc33a-0000-4000-8000-00009e8fc33a'', date ''2026-01-01'' + 84, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''9e90379a-0000-4000-8000-00009e90379a'', date ''2026-01-01'' + 85, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''9e9d665e-0000-4000-8000-00009e9d665e'', date ''2026-01-01'' + 86, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4ede-0000-4000-8000-00009e8f4ede', date '2026-01-01' + 87, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''9e8f4edf-0000-4000-8000-00009e8f4edf'', date ''2026-01-01'' + 88, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''9e8fc33f-0000-4000-8000-00009e8fc33f'', date ''2026-01-01'' + 89, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''9e9037b4-0000-4000-8000-00009e9037b4'', date ''2026-01-01'' + 90, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''9e9d6678-0000-4000-8000-00009e9d6678'', date ''2026-01-01'' + 91, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4ef8-0000-4000-8000-00009e8f4ef8', date '2026-01-01' + 92, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc358-0000-4000-8000-00009e8fc358', date '2026-01-01' + 93, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''9e8f4efa-0000-4000-8000-00009e8f4efa'', date ''2026-01-01'' + 94, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''9e8fc35a-0000-4000-8000-00009e8fc35a'', date ''2026-01-01'' + 95, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''9e9037ba-0000-4000-8000-00009e9037ba'', date ''2026-01-01'' + 96, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''9e9d667e-0000-4000-8000-00009e9d667e'', date ''2026-01-01'' + 97, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4efe-0000-4000-8000-00009e8f4efe', date '2026-01-01' + 98, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''9e9d6680-0000-4000-8000-00009e9d6680'', date ''2026-01-01'' + 99, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6212-0000-4000-8000-0000351d6212'', date ''2026-01-01'' + 100, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a71f3-0000-4000-8000-0000335a71f3'', date ''2026-01-01'' + 101, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4a93-0000-4000-8000-0000350f4a93', date '2026-01-01' + 102, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '351d6215-0000-4000-8000-0000351d6215', date '2026-01-01' + 103, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4a95-0000-4000-8000-0000350f4a95'', date ''2026-01-01'' + 104, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6217-0000-4000-8000-0000351d6217'', date ''2026-01-01'' + 105, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a71f8-0000-4000-8000-0000335a71f8'', date ''2026-01-01'' + 106, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4a98-0000-4000-8000-0000350f4a98', date '2026-01-01' + 107, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4a99-0000-4000-8000-0000350f4a99'', date ''2026-01-01'' + 108, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d621b-0000-4000-8000-0000351d621b'', date ''2026-01-01'' + 109, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7211-0000-4000-8000-0000335a7211'', date ''2026-01-01'' + 110, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4ab1-0000-4000-8000-0000350f4ab1', date '2026-01-01' + 111, true);
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
-- stasjon_produksjon_innstilling  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stasjon_produksjon_innstilling');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stasjon_produksjon_innstilling owner_A SELECT A1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling owner_A SELECT A2 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce45-0000-4000-8000-0000409fce45'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling owner_A SELECT A3 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce46-0000-4000-8000-0000409fce46'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'negativ');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'')');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A INSERT A2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'')');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A INSERT A3', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_A INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A UPDATE A2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce45-0000-4000-8000-0000409fce45''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A UPDATE A3', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce46-0000-4000-8000-0000409fce46''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_A UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce44-0000-4000-8000-0000409fce44', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A DELETE A2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce45-0000-4000-8000-0000409fce45''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce45-0000-4000-8000-0000409fce45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_A DELETE A3', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce46-0000-4000-8000-0000409fce46''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce46-0000-4000-8000-0000409fce46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_A DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_A FLYTTER egen rad -> kjede B', 'update public.stasjon_produksjon_innstilling set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A1 SELECT A1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce45-0000-4000-8000-0000409fce45'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce46-0000-4000-8000-0000409fce46'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'negativ');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A1 INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 INSERT A2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 INSERT A3', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A1 UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 UPDATE A2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce45-0000-4000-8000-0000409fce45''', 'stasjon_produksjon_innstilling', '409fce45-0000-4000-8000-0000409fce45', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 UPDATE A3', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A1 DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce44-0000-4000-8000-0000409fce44', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 DELETE A2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce45-0000-4000-8000-0000409fce45''', 'stasjon_produksjon_innstilling', '409fce45-0000-4000-8000-0000409fce45', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 DELETE A3', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 FLYTTER egen rad A1 -> A2', 'update public.stasjon_produksjon_innstilling set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A1 FLYTTER egen rad -> kjede B', 'update public.stasjon_produksjon_innstilling set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A12 SELECT A1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A12 SELECT A2 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce45-0000-4000-8000-0000409fce45'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce46-0000-4000-8000-0000409fce46'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'negativ');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'')');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 INSERT A2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 INSERT A3', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 UPDATE A2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce45-0000-4000-8000-0000409fce45''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 UPDATE A3', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce44-0000-4000-8000-0000409fce44', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_A12 DELETE A2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce45-0000-4000-8000-0000409fce45''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce45-0000-4000-8000-0000409fce45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 DELETE A3', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 FLYTTER egen rad A1 -> A3', 'update public.stasjon_produksjon_innstilling set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_A12 FLYTTER egen rad -> kjede B', 'update public.stasjon_produksjon_innstilling set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_A1 SELECT A1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce45-0000-4000-8000-0000409fce45'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce46-0000-4000-8000-0000409fce46'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'negativ');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 INSERT A2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 INSERT A3', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 UPDATE A2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce45-0000-4000-8000-0000409fce45''', 'stasjon_produksjon_innstilling', '409fce45-0000-4000-8000-0000409fce45', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 UPDATE A3', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 DELETE A2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce45-0000-4000-8000-0000409fce45''', 'stasjon_produksjon_innstilling', '409fce45-0000-4000-8000-0000409fce45', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 DELETE A3', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce46-0000-4000-8000-0000409fce46''', 'stasjon_produksjon_innstilling', '409fce46-0000-4000-8000-0000409fce46', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_A1 DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stasjon_produksjon_innstilling owner_B SELECT B1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling owner_B SELECT B2 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce64-0000-4000-8000-0000409fce64'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'negativ');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'')');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B INSERT B2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_B INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B UPDATE B2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce64-0000-4000-8000-0000409fce64''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_B UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce63-0000-4000-8000-0000409fce63', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling owner_B DELETE B2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce64-0000-4000-8000-0000409fce64''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce64-0000-4000-8000-0000409fce64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_B DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling owner_B FLYTTER egen rad -> kjede A', 'update public.stasjon_produksjon_innstilling set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stasjon_produksjon_innstilling manager_B1 SELECT B1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce64-0000-4000-8000-0000409fce64'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'negativ');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_B1 INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 INSERT B2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_B1 UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 UPDATE B2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce64-0000-4000-8000-0000409fce64''', 'stasjon_produksjon_innstilling', '409fce64-0000-4000-8000-0000409fce64', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stasjon_produksjon_innstilling manager_B1 DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''');
select pg_temp.som_eier();
insert into public.stasjon_produksjon_innstilling (id, retailer_id, stasjon_id, varegruppe_kode) values ('409fce63-0000-4000-8000-0000409fce63', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 DELETE B2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce64-0000-4000-8000-0000409fce64''', 'stasjon_produksjon_innstilling', '409fce64-0000-4000-8000-0000409fce64', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 FLYTTER egen rad B1 -> B2', 'update public.stasjon_produksjon_innstilling set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling manager_B1 FLYTTER egen rad -> kjede A', 'update public.stasjon_produksjon_innstilling set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_B1 SELECT B1 -> ser', exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce63-0000-4000-8000-0000409fce63'), 'positiv');
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce64-0000-4000-8000-0000409fce64'), 'negativ');
select pg_temp.paastand('stasjon_produksjon_innstilling tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stasjon_produksjon_innstilling where id = '409fce44-0000-4000-8000-0000409fce44'), 'negativ');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 INSERT B1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 INSERT B2', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'')');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 INSERT A1', 'insert into public.stasjon_produksjon_innstilling (retailer_id, stasjon_id, varegruppe_kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 UPDATE B1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 UPDATE B2', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce64-0000-4000-8000-0000409fce64''', 'stasjon_produksjon_innstilling', '409fce64-0000-4000-8000-0000409fce64', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 UPDATE A1', 'update public.stasjon_produksjon_innstilling set start_prosent = 42 where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 DELETE B1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce63-0000-4000-8000-0000409fce63''', 'stasjon_produksjon_innstilling', '409fce63-0000-4000-8000-0000409fce63', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 DELETE B2', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce64-0000-4000-8000-0000409fce64''', 'stasjon_produksjon_innstilling', '409fce64-0000-4000-8000-0000409fce64', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjon_produksjon_innstilling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stasjon_produksjon_innstilling tablet_B1 DELETE A1', 'delete from public.stasjon_produksjon_innstilling where id = ''409fce44-0000-4000-8000-0000409fce44''', 'stasjon_produksjon_innstilling', '409fce44-0000-4000-8000-0000409fce44', 'id');

-- =====================================================================
-- stasjoner  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stasjoner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stasjoner owner_A SELECT A -> ser', exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'positiv');
select pg_temp.paastand('stasjoner owner_A SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_tillatt('stasjoner owner_A INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0214'', ''Sondestasjon owner_AA1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner owner_A INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0215'', ''Sondestasjon owner_AB1'', ''sentrum'')');
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
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6337-0000-4000-8000-0000b7fb6337', 'aaaa0000-0000-4000-8000-000000000000', '0216', 'Sondestasjon gjenowner_AA1', 'sentrum');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stasjoner owner_A DELETE B', 'delete from public.stasjoner where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');
select pg_temp.skriv_avvist('stasjoner owner_A FLYTTER egen rad -> kjede B', 'update public.stasjoner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stasjoner manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.paastand('stasjoner manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.skriv_avvist('stasjoner manager_A1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0217'', ''Sondestasjon manager_A1A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_A1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0218'', ''Sondestasjon manager_A1B1'', ''sentrum'')');
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
select pg_temp.skriv_avvist('stasjoner manager_A12 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0219'', ''Sondestasjon manager_A12A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_A12 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0220'', ''Sondestasjon manager_A12B1'', ''sentrum'')');
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
select pg_temp.skriv_avvist('stasjoner tablet_A1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0221'', ''Sondestasjon tablet_A1A1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner tablet_A1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0222'', ''Sondestasjon tablet_A1B1'', ''sentrum'')');
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
select pg_temp.skriv_tillatt('stasjoner owner_B INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0223'', ''Sondestasjon owner_BB1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner owner_B INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0224'', ''Sondestasjon owner_BA1'', ''sentrum'')');
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
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values ('b7fb6356-0000-4000-8000-0000b7fb6356', 'bbbb0000-0000-4000-8000-000000000000', '0225', 'Sondestasjon gjenowner_BB1', 'sentrum');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stasjoner owner_B DELETE A', 'delete from public.stasjoner where id = ''b7fb6337-0000-4000-8000-0000b7fb6337''', 'stasjoner', 'b7fb6337-0000-4000-8000-0000b7fb6337', 'id');
select pg_temp.skriv_avvist('stasjoner owner_B FLYTTER egen rad -> kjede A', 'update public.stasjoner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''b7fb6356-0000-4000-8000-0000b7fb6356''', 'stasjoner', 'b7fb6356-0000-4000-8000-0000b7fb6356', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stasjoner manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6356-0000-4000-8000-0000b7fb6356'), 'negativ');
select pg_temp.paastand('stasjoner manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.stasjoner where id = 'b7fb6337-0000-4000-8000-0000b7fb6337'), 'negativ');
select pg_temp.skriv_avvist('stasjoner manager_B1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0226'', ''Sondestasjon manager_B1B1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner manager_B1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0227'', ''Sondestasjon manager_B1A1'', ''sentrum'')');
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
select pg_temp.skriv_avvist('stasjoner tablet_B1 INSERT B', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''bbbb0000-0000-4000-8000-000000000000'', ''0228'', ''Sondestasjon tablet_B1B1'', ''sentrum'')');
select pg_temp.skriv_avvist('stasjoner tablet_B1 INSERT A', 'insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype) values (''aaaa0000-0000-4000-8000-000000000000'', ''0229'', ''Sondestasjon tablet_B1A1'', ''sentrum'')');
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

-- =====================================================================
-- stempling  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling owner_A SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A3 -> ser', exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 230, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', date ''2026-01-01'' + 231, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', date ''2026-01-01'' + 232, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_A INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 233, clock_timestamp()::time, time ''16:00'', 480)');
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
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', date '2026-01-01' + 234, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', date '2026-01-01' + 235, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', date '2026-01-01' + 236, clock_timestamp()::time, time '16:00', 480);
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
select pg_temp.skriv_tillatt('stempling manager_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 237, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 238, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 239, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 240, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 241, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 242, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 243, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 244, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 245, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 246, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 247, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 248, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_tillatt('stempling owner_B INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 249, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', date ''2026-01-01'' + 250, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_B INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 251, clock_timestamp()::time, time ''16:00'', 480)');
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
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', date '2026-01-01' + 252, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', date '2026-01-01' + 253, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 254, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 255, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 256, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 257, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 258, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 259, clock_timestamp()::time, time ''16:00'', 480)');
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
    raise exception 'TENANT-MATRISEN DEL 8/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 8/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
