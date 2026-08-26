-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 7. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 7 ressurs(er):
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
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a685-0000-4000-8000-00002d60a685', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611ae5-0000-4000-8000-00002d611ae5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618f45-0000-4000-8000-00002d618f45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe09-0000-4000-8000-00002d6ebe09', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f3269-0000-4000-8000-00002d6f3269', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4e40-0000-4000-8000-00009e8f4e40', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc2a0-0000-4000-8000-00009e8fc2a0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e903700-0000-4000-8000-00009e903700', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d65c4-0000-4000-8000-00009e9d65c4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9dda24-0000-4000-8000-00009e9dda24', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a784-0000-4000-8000-00002d60a784', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2418e-0000-4000-8000-00007ec2418e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05910-0000-4000-8000-00007ed05910', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902ae-0000-4000-8000-0000806902ae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a10-0000-4000-8000-00007eb42a10', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24192-0000-4000-8000-00007ec24192', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05914-0000-4000-8000-00007ed05914', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a13-0000-4000-8000-00007eb42a13', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24195-0000-4000-8000-00007ec24195', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05917-0000-4000-8000-00007ed05917', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902b5-0000-4000-8000-0000806902b5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a2c-0000-4000-8000-00007eb42a2c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a2d-0000-4000-8000-00007eb42a2d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec241af-0000-4000-8000-00007ec241af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05931-0000-4000-8000-00007ed05931', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902cf-0000-4000-8000-0000806902cf', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a31-0000-4000-8000-00007eb42a31', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec241b3-0000-4000-8000-00007ec241b3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a33-0000-4000-8000-00007eb42a33', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec241b5-0000-4000-8000-00007ec241b5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05937-0000-4000-8000-00007ed05937', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902ea-0000-4000-8000-0000806902ea', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a4c-0000-4000-8000-00007eb42a4c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902ec-0000-4000-8000-0000806902ec', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771a6e-0000-4000-8000-000080771a6e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a4f-0000-4000-8000-00007eb42a4f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902ef-0000-4000-8000-0000806902ef', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771a71-0000-4000-8000-000080771a71', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806902f1-0000-4000-8000-0000806902f1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771a73-0000-4000-8000-000080771a73', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a54-0000-4000-8000-00007eb42a54', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690309-0000-4000-8000-000080690309', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069030a-0000-4000-8000-00008069030a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771a8c-0000-4000-8000-000080771a8c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42a6d-0000-4000-8000-00007eb42a6d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069030d-0000-4000-8000-00008069030d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7617-0000-4000-8000-0000335a7617', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688d99-0000-4000-8000-000033688d99', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a51b-0000-4000-8000-00003376a51b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ece-0000-4000-8000-0000350f4ece', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7630-0000-4000-8000-0000335a7630', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688db2-0000-4000-8000-000033688db2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a534-0000-4000-8000-00003376a534', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7633-0000-4000-8000-0000335a7633', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688db5-0000-4000-8000-000033688db5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a537-0000-4000-8000-00003376a537', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ed5-0000-4000-8000-0000350f4ed5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7637-0000-4000-8000-0000335a7637', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7638-0000-4000-8000-0000335a7638', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688dcf-0000-4000-8000-000033688dcf', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a551-0000-4000-8000-00003376a551', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4eef-0000-4000-8000-0000350f4eef', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7651-0000-4000-8000-0000335a7651', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688dd3-0000-4000-8000-000033688dd3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7653-0000-4000-8000-0000335a7653', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688dd5-0000-4000-8000-000033688dd5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a557-0000-4000-8000-00003376a557', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ef5-0000-4000-8000-0000350f4ef5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7657-0000-4000-8000-0000335a7657', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f0c-0000-4000-8000-0000350f4f0c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d668e-0000-4000-8000-0000351d668e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a766f-0000-4000-8000-0000335a766f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f0f-0000-4000-8000-0000350f4f0f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6691-0000-4000-8000-0000351d6691', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f11-0000-4000-8000-0000350f4f11', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6693-0000-4000-8000-0000351d6693', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7674-0000-4000-8000-0000335a7674', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f14-0000-4000-8000-0000350f4f14', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f15-0000-4000-8000-0000350f4f15', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d66ac-0000-4000-8000-0000351d66ac', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a768d-0000-4000-8000-0000335a768d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4f2d-0000-4000-8000-0000350f4f2d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
-- --- regnskap_usynlig_svinn: forutsetninger og proberader ---
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9874-0000-4000-8000-0000ca4b9874', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje fastA1', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9875-0000-4000-8000-0000ca4b9875', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje fastA2', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9876-0000-4000-8000-0000ca4b9876', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', '20010', 'Sondelinje fastA3', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9893-0000-4000-8000-0000ca4b9893', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje fastB1', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9894-0000-4000-8000-0000ca4b9894', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje fastB2', 100);

create or replace function pg_temp.nyrad_regnskap_usynlig_svinn(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr)
  values (p_retailer, p_stasjon, date '2026-08-01', '20010', 'Sondelinje ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 100)
  returning id into ny;
  return ny;
end $fn$;
-- --- regnskapslinjer: forutsetninger og proberader ---
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('576eb793-0000-4000-8000-0000576eb793', 'aaaa0000-0000-4000-8000-000000000000', null, date '2026-08-01', 'omsetning', 'Sondepost nullA', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('576eb794-0000-4000-8000-0000576eb794', 'bbbb0000-0000-4000-8000-000000000000', null, date '2026-08-01', 'omsetning', 'Sondepost nullB', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost fastA1', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost fastA2', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'omsetning', 'Sondepost fastA3', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost fastB1', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost fastB2', 1000);

create or replace function pg_temp.nyrad_regnskapslinjer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap)
  values (p_retailer, p_stasjon, date '2026-08-01', 'omsetning', 'Sondepost ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 1000)
  returning id into ny;
  return ny;
end $fn$;
-- --- rutine_utforinger: forutsetninger og proberader ---
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a685-0000-4000-8000-00002d60a685', date '2026-01-01' + 12);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611ae5-0000-4000-8000-00002d611ae5', date '2026-01-01' + 13);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '2d618f45-0000-4000-8000-00002d618f45', date '2026-01-01' + 14);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebe09-0000-4000-8000-00002d6ebe09', date '2026-01-01' + 15);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '2d6f3269-0000-4000-8000-00002d6f3269', date '2026-01-01' + 16);

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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3ca-0000-4000-8000-0000502ec3ca', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde-nullA', date '2026-01-01' + 27, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3cb-0000-4000-8000-0000502ec3cb', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde-nullB', date '2026-01-01' + 28, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-fastA1', date '2026-01-01' + 29, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-fastA2', date '2026-01-01' + 30, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-fastA3', date '2026-01-01' + 31, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-fastB1', date '2026-01-01' + 32, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-fastB2', date '2026-01-01' + 33, 'Sonde');

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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4e40-0000-4000-8000-00009e8f4e40', date '2026-01-01' + 34, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc2a0-0000-4000-8000-00009e8fc2a0', date '2026-01-01' + 35, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '9e903700-0000-4000-8000-00009e903700', date '2026-01-01' + 36, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '9e9d65c4-0000-4000-8000-00009e9d65c4', date '2026-01-01' + 37, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '9e9dda24-0000-4000-8000-00009e9dda24', date '2026-01-01' + 38, true);

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

-- =====================================================================
-- regnskap_usynlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('regnskap_usynlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA1'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA2'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AB1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9874-0000-4000-8000-0000ca4b9874', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA1', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9875-0000-4000-8000-0000ca4b9875', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA2', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9876-0000-4000-8000-0000ca4b9876', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA3', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A FLYTTER egen rad -> kjede B', 'update public.regnskap_usynlig_svinn set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT B1 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT B2 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BB1'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BB2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BA1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9893-0000-4000-8000-0000ca4b9893', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje gjenowner_BB1', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9894-0000-4000-8000-0000ca4b9894', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje gjenowner_BB2', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B FLYTTER egen rad -> kjede A', 'update public.regnskap_usynlig_svinn set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1B1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1B2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1A1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1B1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1B2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1A1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

-- =====================================================================
-- regnskapslinjer  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('regnskapslinjer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('regnskapslinjer owner_A SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT A2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT A3 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA1'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA2'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer owner_A INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AB1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapslinjer owner_A UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA1', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA2', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA3', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapslinjer owner_A DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('regnskapslinjer owner_B SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B SELECT B2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BB1'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BB2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer owner_B INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BA1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapslinjer owner_B UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_BB1', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_BB2', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapslinjer owner_B DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1B1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1B2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1A1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1B1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1B2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1A1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

-- =====================================================================
-- rutine_utforinger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_utforinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_utforinger owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''2d60a784-0000-4000-8000-00002d60a784'', date ''2026-01-01'' + 99)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec2418e-0000-4000-8000-00007ec2418e'', date ''2026-01-01'' + 100)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05910-0000-4000-8000-00007ed05910'', date ''2026-01-01'' + 101)');
select pg_temp.skriv_avvist('rutine_utforinger owner_A INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902ae-0000-4000-8000-0000806902ae'', date ''2026-01-01'' + 102)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42a10-0000-4000-8000-00007eb42a10', date '2026-01-01' + 103);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec24192-0000-4000-8000-00007ec24192', date '2026-01-01' + 104);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '7ed05914-0000-4000-8000-00007ed05914', date '2026-01-01' + 105);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a13-0000-4000-8000-00007eb42a13'', date ''2026-01-01'' + 106)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec24195-0000-4000-8000-00007ec24195'', date ''2026-01-01'' + 107)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05917-0000-4000-8000-00007ed05917'', date ''2026-01-01'' + 108)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902b5-0000-4000-8000-0000806902b5'', date ''2026-01-01'' + 109)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42a2c-0000-4000-8000-00007eb42a2c', date '2026-01-01' + 110);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a2d-0000-4000-8000-00007eb42a2d'', date ''2026-01-01'' + 111)');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec241af-0000-4000-8000-00007ec241af'', date ''2026-01-01'' + 112)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05931-0000-4000-8000-00007ed05931'', date ''2026-01-01'' + 113)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902cf-0000-4000-8000-0000806902cf'', date ''2026-01-01'' + 114)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42a31-0000-4000-8000-00007eb42a31', date '2026-01-01' + 115);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec241b3-0000-4000-8000-00007ec241b3', date '2026-01-01' + 116);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a33-0000-4000-8000-00007eb42a33'', date ''2026-01-01'' + 117)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec241b5-0000-4000-8000-00007ec241b5'', date ''2026-01-01'' + 118)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05937-0000-4000-8000-00007ed05937'', date ''2026-01-01'' + 119)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902ea-0000-4000-8000-0000806902ea'', date ''2026-01-01'' + 120)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42a4c-0000-4000-8000-00007eb42a4c', date '2026-01-01' + 121);
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
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902ec-0000-4000-8000-0000806902ec'', date ''2026-01-01'' + 122)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771a6e-0000-4000-8000-000080771a6e'', date ''2026-01-01'' + 123)');
select pg_temp.skriv_avvist('rutine_utforinger owner_B INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a4f-0000-4000-8000-00007eb42a4f'', date ''2026-01-01'' + 124)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '806902ef-0000-4000-8000-0000806902ef', date '2026-01-01' + 125);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '80771a71-0000-4000-8000-000080771a71', date '2026-01-01' + 126);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806902f1-0000-4000-8000-0000806902f1'', date ''2026-01-01'' + 127)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771a73-0000-4000-8000-000080771a73'', date ''2026-01-01'' + 128)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a54-0000-4000-8000-00007eb42a54'', date ''2026-01-01'' + 129)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '80690309-0000-4000-8000-000080690309', date '2026-01-01' + 130);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''8069030a-0000-4000-8000-00008069030a'', date ''2026-01-01'' + 131)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771a8c-0000-4000-8000-000080771a8c'', date ''2026-01-01'' + 132)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42a6d-0000-4000-8000-00007eb42a6d'', date ''2026-01-01'' + 133)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '8069030d-0000-4000-8000-00008069030d', date '2026-01-01' + 134);
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
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_AA1'', date ''2026-01-01'' + 203, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-owner_AA2'', date ''2026-01-01'' + 204, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-owner_AA3'', date ''2026-01-01'' + 205, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_A INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_AB1'', date ''2026-01-01'' + 206, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_AA1', date '2026-01-01' + 207, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_AA2', date '2026-01-01' + 208, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-gjenowner_AA3', date '2026-01-01' + 209, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1A1'', date ''2026-01-01'' + 210, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A1A2'', date ''2026-01-01'' + 211, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A1A3'', date ''2026-01-01'' + 212, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1B1'', date ''2026-01-01'' + 213, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A1A1', date '2026-01-01' + 214, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12A1'', date ''2026-01-01'' + 215, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A12A2'', date ''2026-01-01'' + 216, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A12A3'', date ''2026-01-01'' + 217, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12B1'', date ''2026-01-01'' + 218, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A12A1', date '2026-01-01' + 219, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenmanager_A12A2', date '2026-01-01' + 220, 'Sonde');
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
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1A1'', date ''2026-01-01'' + 221, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-tablet_A1A2'', date ''2026-01-01'' + 222, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-tablet_A1A3'', date ''2026-01-01'' + 223, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1B1'', date ''2026-01-01'' + 224, ''Sonde'')');
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
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_BB1'', date ''2026-01-01'' + 225, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-owner_BB2'', date ''2026-01-01'' + 226, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_B INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_BA1'', date ''2026-01-01'' + 227, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_BB1', date '2026-01-01' + 228, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_BB2', date '2026-01-01' + 229, 'Sonde');
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
select pg_temp.skriv_tillatt('signal_lukket manager_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1B1'', date ''2026-01-01'' + 230, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-manager_B1B2'', date ''2026-01-01'' + 231, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1A1'', date ''2026-01-01'' + 232, ''Sonde'')');
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
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_B1B1', date '2026-01-01' + 233, 'Sonde');
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
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1B1'', date ''2026-01-01'' + 234, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-tablet_B1B2'', date ''2026-01-01'' + 235, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1A1'', date ''2026-01-01'' + 236, ''Sonde'')');
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7617-0000-4000-8000-0000335a7617'', date ''2026-01-01'' + 237, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688d99-0000-4000-8000-000033688d99'', date ''2026-01-01'' + 238, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a51b-0000-4000-8000-00003376a51b'', date ''2026-01-01'' + 239, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ece-0000-4000-8000-0000350f4ece'', date ''2026-01-01'' + 240, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7630-0000-4000-8000-0000335a7630', date '2026-01-01' + 241, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688db2-0000-4000-8000-000033688db2', date '2026-01-01' + 242, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '3376a534-0000-4000-8000-00003376a534', date '2026-01-01' + 243, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7633-0000-4000-8000-0000335a7633'', date ''2026-01-01'' + 244, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688db5-0000-4000-8000-000033688db5'', date ''2026-01-01'' + 245, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a537-0000-4000-8000-00003376a537'', date ''2026-01-01'' + 246, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ed5-0000-4000-8000-0000350f4ed5'', date ''2026-01-01'' + 247, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7637-0000-4000-8000-0000335a7637', date '2026-01-01' + 248, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7638-0000-4000-8000-0000335a7638'', date ''2026-01-01'' + 249, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688dcf-0000-4000-8000-000033688dcf'', date ''2026-01-01'' + 250, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a551-0000-4000-8000-00003376a551'', date ''2026-01-01'' + 251, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4eef-0000-4000-8000-0000350f4eef'', date ''2026-01-01'' + 252, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7651-0000-4000-8000-0000335a7651', date '2026-01-01' + 253, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688dd3-0000-4000-8000-000033688dd3', date '2026-01-01' + 254, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7653-0000-4000-8000-0000335a7653'', date ''2026-01-01'' + 255, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688dd5-0000-4000-8000-000033688dd5'', date ''2026-01-01'' + 256, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a557-0000-4000-8000-00003376a557'', date ''2026-01-01'' + 257, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ef5-0000-4000-8000-0000350f4ef5'', date ''2026-01-01'' + 258, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7657-0000-4000-8000-0000335a7657', date '2026-01-01' + 259, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4f0c-0000-4000-8000-0000350f4f0c'', date ''2026-01-01'' + 260, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d668e-0000-4000-8000-0000351d668e'', date ''2026-01-01'' + 261, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a766f-0000-4000-8000-0000335a766f'', date ''2026-01-01'' + 262, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4f0f-0000-4000-8000-0000350f4f0f', date '2026-01-01' + 263, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '351d6691-0000-4000-8000-0000351d6691', date '2026-01-01' + 264, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4f11-0000-4000-8000-0000350f4f11'', date ''2026-01-01'' + 265, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6693-0000-4000-8000-0000351d6693'', date ''2026-01-01'' + 266, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7674-0000-4000-8000-0000335a7674'', date ''2026-01-01'' + 267, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4f14-0000-4000-8000-0000350f4f14', date '2026-01-01' + 268, true);
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
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4f15-0000-4000-8000-0000350f4f15'', date ''2026-01-01'' + 269, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d66ac-0000-4000-8000-0000351d66ac'', date ''2026-01-01'' + 270, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a768d-0000-4000-8000-0000335a768d'', date ''2026-01-01'' + 271, true)');
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
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4f2d-0000-4000-8000-0000350f4f2d', date '2026-01-01' + 272, true);
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
    raise exception 'TENANT-MATRISEN DEL 5/7: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/7: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
