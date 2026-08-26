-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 2 AV 5. Hele matrisen er for stor for Supabase SQL
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d942f-0000-4000-8000-0000a86d942f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e088f-0000-4000-8000-0000a86e088f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7cef-0000-4000-8000-0000a86e7cef', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87babc8-0000-4000-8000-0000a87babc8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c2028-0000-4000-8000-0000a87c2028', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ede3-0000-4000-8000-00006544ede3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530565-0000-4000-8000-000065530565', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611ce7-0000-4000-8000-000065611ce7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c685-0000-4000-8000-000066f9c685', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ede7-0000-4000-8000-00006544ede7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530569-0000-4000-8000-000065530569', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611ceb-0000-4000-8000-000065611ceb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544edea-0000-4000-8000-00006544edea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553056c-0000-4000-8000-00006553056c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611d03-0000-4000-8000-000065611d03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6a1-0000-4000-8000-000066f9c6a1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee03-0000-4000-8000-00006544ee03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee04-0000-4000-8000-00006544ee04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530586-0000-4000-8000-000065530586', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611d08-0000-4000-8000-000065611d08', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6a6-0000-4000-8000-000066f9c6a6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee08-0000-4000-8000-00006544ee08', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553058a-0000-4000-8000-00006553058a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee0a-0000-4000-8000-00006544ee0a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655305a1-0000-4000-8000-0000655305a1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611d23-0000-4000-8000-000065611d23', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6c1-0000-4000-8000-000066f9c6c1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6c2-0000-4000-8000-000066f9c6c2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707de44-0000-4000-8000-00006707de44', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee25-0000-4000-8000-00006544ee25', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6c5-0000-4000-8000-000066f9c6c5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707de47-0000-4000-8000-00006707de47', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6c7-0000-4000-8000-000066f9c6c7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707de49-0000-4000-8000-00006707de49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee3f-0000-4000-8000-00006544ee3f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6df-0000-4000-8000-000066f9c6df', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c6e0-0000-4000-8000-000066f9c6e0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707de62-0000-4000-8000-00006707de62', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ee43-0000-4000-8000-00006544ee43', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
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
-- --- daglig_salg: forutsetninger og proberader ---
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 7, 'fastA1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 8, 'fastA2', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 9, 'fastA3', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, 'fastB1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, 'fastB2', 'Sondevare', 100);

create or replace function pg_temp.nyrad_daglig_salg(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sondevare', 100)
  returning id into ny;
  return ny;
end $fn$;
-- --- synlig_svinn: forutsetninger og proberader ---
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 12, 'fastA1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 13, 'fastA2', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 14, 'fastA3', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 15, 'fastB1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 16, 'fastB2', 'Sondevare', 1, 25);

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
-- --- stempling: forutsetninger og proberader ---
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', date '2026-01-01' + 22, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', date '2026-01-01' + 23, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', date '2026-01-01' + 24, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', date '2026-01-01' + 25, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', date '2026-01-01' + 26, clock_timestamp()::time, time '16:00', 480);

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
-- --- opplaering_periode: forutsetninger og proberader ---
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen fastA1', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen fastA2', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2c-0000-4000-8000-0000d0771b2c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen fastA3', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen fastB1', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b4a-0000-4000-8000-0000d0771b4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen fastB2', date '2026-08-01');

create or replace function pg_temp.nyrad_opplaering_periode(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato)
  values (p_retailer, p_stasjon, 'Sonde Sondesen ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', date '2026-08-01')
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
-- --- opplaering_skift: forutsetninger og proberader ---
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d942f-0000-4000-8000-0000a86d942f', date '2026-01-01' + 37);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e088f-0000-4000-8000-0000a86e088f', date '2026-01-01' + 38);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7cef-0000-4000-8000-0000a86e7cef', date '2026-01-01' + 39);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87babc8-0000-4000-8000-0000a87babc8', date '2026-01-01' + 40);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', 'a87c2028-0000-4000-8000-0000a87c2028', date '2026-01-01' + 41);

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
-- daglig_salg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('daglig_salg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('daglig_salg owner_A SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A3 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 72, ''owner_AA1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 73, ''owner_AA2'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 74, ''owner_AA3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_A INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 75, ''owner_AB1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A UPDATE A2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A UPDATE A3', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54de-0000-4000-8000-00008c5a54de''');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('daglig_salg owner_A UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 76, 'gjenowner_AA1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 77, 'gjenowner_AA2', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 78, 'gjenowner_AA3', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('daglig_salg owner_A DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.skriv_avvist('daglig_salg owner_A FLYTTER egen rad -> kjede B', 'update public.daglig_salg set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('daglig_salg manager_A1 SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'negativ');
select pg_temp.paastand('daglig_salg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'negativ');
select pg_temp.paastand('daglig_salg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 79, ''manager_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 80, ''manager_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 81, ''manager_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 82, ''manager_A1B1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 UPDATE A2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 UPDATE A3', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('daglig_salg manager_A1 DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('daglig_salg manager_A12 SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg manager_A12 SELECT A2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'positiv');
select pg_temp.paastand('daglig_salg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'negativ');
select pg_temp.paastand('daglig_salg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 83, ''manager_A12A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 84, ''manager_A12A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 85, ''manager_A12A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 86, ''manager_A12B1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 UPDATE A2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 UPDATE A3', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('daglig_salg manager_A12 DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('daglig_salg tablet_A1 SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'negativ');
select pg_temp.paastand('daglig_salg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'negativ');
select pg_temp.paastand('daglig_salg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 87, ''tablet_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 88, ''tablet_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 89, ''tablet_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 90, ''tablet_A1B1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 UPDATE A2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 UPDATE A3', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''', 'daglig_salg', '8c5a54dd-0000-4000-8000-00008c5a54dd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''', 'daglig_salg', '8c5a54de-0000-4000-8000-00008c5a54de', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('daglig_salg owner_B SELECT B1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'positiv');
select pg_temp.paastand('daglig_salg owner_B SELECT B2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54fc-0000-4000-8000-00008c5a54fc'), 'positiv');
select pg_temp.paastand('daglig_salg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'negativ');
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 91, ''owner_BB1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 92, ''owner_BB2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_B INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 93, ''owner_BA1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B UPDATE B2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('daglig_salg owner_B UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 94, 'gjenowner_BB1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 95, 'gjenowner_BB2', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('daglig_salg owner_B DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.skriv_avvist('daglig_salg owner_B FLYTTER egen rad -> kjede A', 'update public.daglig_salg set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('daglig_salg manager_B1 SELECT B1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'positiv');
select pg_temp.paastand('daglig_salg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fc-0000-4000-8000-00008c5a54fc'), 'negativ');
select pg_temp.paastand('daglig_salg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'negativ');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 96, ''manager_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 97, ''manager_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 98, ''manager_B1A1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 UPDATE B2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''', 'daglig_salg', '8c5a54fc-0000-4000-8000-00008c5a54fc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''', 'daglig_salg', '8c5a54fc-0000-4000-8000-00008c5a54fc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('daglig_salg manager_B1 DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('daglig_salg tablet_B1 SELECT B1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'positiv');
select pg_temp.paastand('daglig_salg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fc-0000-4000-8000-00008c5a54fc'), 'negativ');
select pg_temp.paastand('daglig_salg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'negativ');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 99, ''tablet_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 100, ''tablet_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 101, ''tablet_B1A1'', ''Sondevare'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 UPDATE B1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 UPDATE B2', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''', 'daglig_salg', '8c5a54fc-0000-4000-8000-00008c5a54fc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 UPDATE A1', 'update public.daglig_salg set varenavn = ''endret av sonden'' where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 DELETE B1', 'delete from public.daglig_salg where id = ''8c5a54fb-0000-4000-8000-00008c5a54fb''', 'daglig_salg', '8c5a54fb-0000-4000-8000-00008c5a54fb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''', 'daglig_salg', '8c5a54fc-0000-4000-8000-00008c5a54fc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 DELETE A1', 'delete from public.daglig_salg where id = ''8c5a54dc-0000-4000-8000-00008c5a54dc''', 'daglig_salg', '8c5a54dc-0000-4000-8000-00008c5a54dc', 'id');

-- =====================================================================
-- synlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('synlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('synlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 102, ''owner_AA1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 103, ''owner_AA2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 104, ''owner_AA3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_A INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 105, ''owner_AB1'', ''Sondevare'', 1, 25)');
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
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 106, 'gjenowner_AA1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 107, 'gjenowner_AA2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 108, 'gjenowner_AA3', 'Sondevare', 1, 25);
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
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 109, ''manager_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 110, ''manager_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 111, ''manager_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 112, ''manager_A1B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 113, ''manager_A12A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 114, ''manager_A12A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 115, ''manager_A12A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 116, ''manager_A12B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 117, ''tablet_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 118, ''tablet_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 119, ''tablet_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 120, ''tablet_A1B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 121, ''owner_BB1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 122, ''owner_BB2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_B INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 123, ''owner_BA1'', ''Sondevare'', 1, 25)');
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
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 124, 'gjenowner_BB1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 125, 'gjenowner_BB2', 'Sondevare', 1, 25);
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
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 126, ''manager_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 127, ''manager_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 128, ''manager_B1A1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 129, ''tablet_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 130, ''tablet_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 131, ''tablet_B1A1'', ''Sondevare'', 1, 25)');
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
-- stempling  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling owner_A SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A3 -> ser', exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 162, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', date ''2026-01-01'' + 163, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', date ''2026-01-01'' + 164, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_A INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 165, clock_timestamp()::time, time ''16:00'', 480)');
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
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', date '2026-01-01' + 166, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', date '2026-01-01' + 167, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', date '2026-01-01' + 168, clock_timestamp()::time, time '16:00', 480);
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
select pg_temp.skriv_tillatt('stempling manager_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 169, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 170, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 171, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 172, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 173, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 174, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 175, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 176, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 177, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 178, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 179, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 180, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_tillatt('stempling owner_B INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 181, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', date ''2026-01-01'' + 182, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_B INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 183, clock_timestamp()::time, time ''16:00'', 480)');
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
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', date '2026-01-01' + 184, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', date '2026-01-01' + 185, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 186, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 187, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 188, clock_timestamp()::time, time ''16:00'', 480)');
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
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 189, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 190, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 191, clock_timestamp()::time, time ''16:00'', 480)');
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
-- opplaering_periode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_periode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_periode owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_AA1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen owner_AA2'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen owner_AA3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode owner_A INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_AB1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_periode owner_A UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenowner_AA1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenowner_AA2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2c-0000-4000-8000-0000d0771b2c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen gjenowner_AA3', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_periode owner_A DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode owner_A FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A1A1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_A1A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen manager_A1A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A1B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_A1A1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 FLYTTER egen rad A1 -> A2', 'update public.opplaering_periode set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A12A1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_A12A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen manager_A12A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A12B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_A12A1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenmanager_A12A2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 FLYTTER egen rad A1 -> A3', 'update public.opplaering_periode set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_A1A1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen tablet_A1A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen tablet_A1A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_A1B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_periode owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode owner_B INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_BB1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_B INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen owner_BB2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode owner_B INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_BA1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_periode owner_B UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenowner_BB1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b4a-0000-4000-8000-0000d0771b4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenowner_BB2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_periode owner_B DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode owner_B FLYTTER egen rad -> kjede A', 'update public.opplaering_periode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_periode manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_B1B1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_B1B2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_B1A1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_B1B1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 FLYTTER egen rad B1 -> B2', 'update public.opplaering_periode set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 FLYTTER egen rad -> kjede A', 'update public.opplaering_periode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_B1B1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen tablet_B1B2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_B1A1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

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
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ede3-0000-4000-8000-00006544ede3'', date ''2026-01-01'' + 251)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''65530565-0000-4000-8000-000065530565'', date ''2026-01-01'' + 252)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611ce7-0000-4000-8000-000065611ce7'', date ''2026-01-01'' + 253)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c685-0000-4000-8000-000066f9c685'', date ''2026-01-01'' + 254)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ede7-0000-4000-8000-00006544ede7', date '2026-01-01' + 255);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '65530569-0000-4000-8000-000065530569', date '2026-01-01' + 256);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '65611ceb-0000-4000-8000-000065611ceb', date '2026-01-01' + 257);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544edea-0000-4000-8000-00006544edea'', date ''2026-01-01'' + 258)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''6553056c-0000-4000-8000-00006553056c'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611d03-0000-4000-8000-000065611d03'', date ''2026-01-01'' + 260)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6a1-0000-4000-8000-000066f9c6a1'', date ''2026-01-01'' + 261)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ee03-0000-4000-8000-00006544ee03', date '2026-01-01' + 262);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ee04-0000-4000-8000-00006544ee04'', date ''2026-01-01'' + 263)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''65530586-0000-4000-8000-000065530586'', date ''2026-01-01'' + 264)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611d08-0000-4000-8000-000065611d08'', date ''2026-01-01'' + 265)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6a6-0000-4000-8000-000066f9c6a6'', date ''2026-01-01'' + 266)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ee08-0000-4000-8000-00006544ee08', date '2026-01-01' + 267);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '6553058a-0000-4000-8000-00006553058a', date '2026-01-01' + 268);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ee0a-0000-4000-8000-00006544ee0a'', date ''2026-01-01'' + 269)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655305a1-0000-4000-8000-0000655305a1'', date ''2026-01-01'' + 270)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611d23-0000-4000-8000-000065611d23'', date ''2026-01-01'' + 271)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6c1-0000-4000-8000-000066f9c6c1'', date ''2026-01-01'' + 272)');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6c2-0000-4000-8000-000066f9c6c2'', date ''2026-01-01'' + 273)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707de44-0000-4000-8000-00006707de44'', date ''2026-01-01'' + 274)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ee25-0000-4000-8000-00006544ee25'', date ''2026-01-01'' + 275)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c6c5-0000-4000-8000-000066f9c6c5', date '2026-01-01' + 276);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '6707de47-0000-4000-8000-00006707de47', date '2026-01-01' + 277);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6c7-0000-4000-8000-000066f9c6c7'', date ''2026-01-01'' + 278)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707de49-0000-4000-8000-00006707de49'', date ''2026-01-01'' + 279)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ee3f-0000-4000-8000-00006544ee3f'', date ''2026-01-01'' + 280)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c6df-0000-4000-8000-000066f9c6df', date '2026-01-01' + 281);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c6e0-0000-4000-8000-000066f9c6e0'', date ''2026-01-01'' + 282)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707de62-0000-4000-8000-00006707de62'', date ''2026-01-01'' + 283)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ee43-0000-4000-8000-00006544ee43'', date ''2026-01-01'' + 284)');
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
    raise exception 'TENANT-MATRISEN DEL 2/5: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 2/5: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
