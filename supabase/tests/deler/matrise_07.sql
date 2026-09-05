-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 7 AV 10. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 11 ressurs(er):
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
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c53b7a-0000-4000-8000-0000d0c53b7a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c53f3c-0000-4000-8000-0000d0c53f3c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c542fe-0000-4000-8000-0000d0c542fe', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c5afdc-0000-4000-8000-0000d0c5afdc', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c5b39e-0000-4000-8000-0000d0c5b39e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
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
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23492-0000-4000-8000-000047e23492', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c14-0000-4000-8000-000047f04c14', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23494-0000-4000-8000-000047e23494', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23495-0000-4000-8000-000047e23495', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c17-0000-4000-8000-000047f04c17', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23497-0000-4000-8000-000047e23497', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23498-0000-4000-8000-000047e23498', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c1a-0000-4000-8000-000047f04c1a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2349a-0000-4000-8000-000047e2349a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b0-0000-4000-8000-000047e234b0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c32-0000-4000-8000-000047f04c32', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c33-0000-4000-8000-000047f04c33', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b3-0000-4000-8000-000047e234b3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c35-0000-4000-8000-000047f04c35', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c36-0000-4000-8000-000047f04c36', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b6-0000-4000-8000-000047e234b6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c38-0000-4000-8000-000047f04c38', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c39-0000-4000-8000-000047f04c39', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b9-0000-4000-8000-000047e234b9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643fe9-0000-4000-8000-00004b643fe9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be016ea-0000-4000-8000-00002be016ea', 'aaaa0000-0000-4000-8000-000000000000', '4b643fe9-0000-4000-8000-00004b643fe9', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b45e-0000-4000-8000-00004b64b45e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08b5f-0000-4000-8000-00002be08b5f', 'aaaa0000-0000-4000-8000-000000000000', '4b64b45e-0000-4000-8000-00004b64b45e', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6528be-0000-4000-8000-00004b6528be', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ffbf-0000-4000-8000-00002be0ffbf', 'aaaa0000-0000-4000-8000-000000000000', '4b6528be-0000-4000-8000-00004b6528be', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b725782-0000-4000-8000-00004b725782', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2e83-0000-4000-8000-00002bee2e83', 'bbbb0000-0000-4000-8000-000000000000', '4b725782-0000-4000-8000-00004b725782', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b644002-0000-4000-8000-00004b644002', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01703-0000-4000-8000-00002be01703', 'aaaa0000-0000-4000-8000-000000000000', '4b644002-0000-4000-8000-00004b644002', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b462-0000-4000-8000-00004b64b462', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08b63-0000-4000-8000-00002be08b63', 'aaaa0000-0000-4000-8000-000000000000', '4b64b462-0000-4000-8000-00004b64b462', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6528c2-0000-4000-8000-00004b6528c2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ffc3-0000-4000-8000-00002be0ffc3', 'aaaa0000-0000-4000-8000-000000000000', '4b6528c2-0000-4000-8000-00004b6528c2', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b725786-0000-4000-8000-00004b725786', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2e87-0000-4000-8000-00002bee2e87', 'bbbb0000-0000-4000-8000-000000000000', '4b725786-0000-4000-8000-00004b725786', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b644006-0000-4000-8000-00004b644006', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01707-0000-4000-8000-00002be01707', 'aaaa0000-0000-4000-8000-000000000000', '4b644006-0000-4000-8000-00004b644006', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b466-0000-4000-8000-00004b64b466', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08b67-0000-4000-8000-00002be08b67', 'aaaa0000-0000-4000-8000-000000000000', '4b64b466-0000-4000-8000-00004b64b466', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6528c6-0000-4000-8000-00004b6528c6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ffc7-0000-4000-8000-00002be0ffc7', 'aaaa0000-0000-4000-8000-000000000000', '4b6528c6-0000-4000-8000-00004b6528c6', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aa8-0000-4000-8000-000022d87aa8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783c7-0000-4000-8000-000051d783c7', 'bbbb0000-0000-4000-8000-000000000000', '22d87aa8-0000-4000-8000-000022d87aa8', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a20a-0000-4000-8000-00002123a20a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab29-0000-4000-8000-00005022ab29', 'aaaa0000-0000-4000-8000-000000000000', '2123a20a-0000-4000-8000-00002123a20a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131b98c-0000-4000-8000-00002131b98c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c2ab-0000-4000-8000-00005030c2ab', 'aaaa0000-0000-4000-8000-000000000000', '2131b98c-0000-4000-8000-00002131b98c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd10e-0000-4000-8000-0000213fd10e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503eda2d-0000-4000-8000-0000503eda2d', 'aaaa0000-0000-4000-8000-000000000000', '213fd10e-0000-4000-8000-0000213fd10e', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aac-0000-4000-8000-000022d87aac', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783cb-0000-4000-8000-000051d783cb', 'bbbb0000-0000-4000-8000-000000000000', '22d87aac-0000-4000-8000-000022d87aac', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aad-0000-4000-8000-000022d87aad', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783cc-0000-4000-8000-000051d783cc', 'bbbb0000-0000-4000-8000-000000000000', '22d87aad-0000-4000-8000-000022d87aad', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6922f-0000-4000-8000-000022e6922f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b4e-0000-4000-8000-000051e59b4e', 'bbbb0000-0000-4000-8000-000000000000', '22e6922f-0000-4000-8000-000022e6922f', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a210-0000-4000-8000-00002123a210', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab2f-0000-4000-8000-00005022ab2f', 'aaaa0000-0000-4000-8000-000000000000', '2123a210-0000-4000-8000-00002123a210', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ab0-0000-4000-8000-000022d87ab0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783cf-0000-4000-8000-000051d783cf', 'bbbb0000-0000-4000-8000-000000000000', '22d87ab0-0000-4000-8000-000022d87ab0', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69232-0000-4000-8000-000022e69232', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b51-0000-4000-8000-000051e59b51', 'bbbb0000-0000-4000-8000-000000000000', '22e69232-0000-4000-8000-000022e69232', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a228-0000-4000-8000-00002123a228', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab47-0000-4000-8000-00005022ab47', 'aaaa0000-0000-4000-8000-000000000000', '2123a228-0000-4000-8000-00002123a228', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ac8-0000-4000-8000-000022d87ac8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783e7-0000-4000-8000-000051d783e7', 'bbbb0000-0000-4000-8000-000000000000', '22d87ac8-0000-4000-8000-000022d87ac8', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6924a-0000-4000-8000-000022e6924a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b69-0000-4000-8000-000051e59b69', 'bbbb0000-0000-4000-8000-000000000000', '22e6924a-0000-4000-8000-000022e6924a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a22b-0000-4000-8000-00002123a22b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab4a-0000-4000-8000-00005022ab4a', 'aaaa0000-0000-4000-8000-000000000000', '2123a22b-0000-4000-8000-00002123a22b', date '2026-08-01', date '2026-08-31');
-- --- puls_runde: forutsetninger og proberader ---
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'd0c53b7a-0000-4000-8000-0000d0c53b7a', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60e-0000-4000-8000-00001f2bd60e', 'aaaa0000-0000-4000-8000-000000000000', 'd0c53f3c-0000-4000-8000-0000d0c53f3c', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60f-0000-4000-8000-00001f2bd60f', 'aaaa0000-0000-4000-8000-000000000000', 'd0c542fe-0000-4000-8000-0000d0c542fe', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'd0c5afdc-0000-4000-8000-0000d0c5afdc', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62d-0000-4000-8000-00001f2bd62d', 'bbbb0000-0000-4000-8000-000000000000', 'd0c5b39e-0000-4000-8000-0000d0c5b39e', date '2026-08-01', date '2026-08-31');

create or replace function pg_temp.nyrad_puls_runde(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_sporsmal uuid := gen_random_uuid();
begin
  insert into public.puls_sporsmal (id, retailer_id, tekst) values (v_sporsmal, p_retailer, 'Sondesporsmaal');
  insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato)
  values (p_retailer, v_sporsmal, date '2026-08-01', date '2026-08-31')
  returning id into ny;
  return ny;
end $fn$;
-- --- puls_sporsmal: forutsetninger og proberader ---
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal fastA1');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0d-0000-4000-8000-00006a0e2c0d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal fastA2');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0e-0000-4000-8000-00006a0e2c0e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal fastA3');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal fastB1');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c2c-0000-4000-8000-00006a0e2c2c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal fastB2');

create or replace function pg_temp.nyrad_puls_sporsmal(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.puls_sporsmal (retailer_id, tekst)
  values (p_retailer, 'Sondesporsmaal ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- puls_svar: forutsetninger og proberader ---
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575b-0000-4000-8000-00003922575b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '2be01608-0000-4000-8000-00002be01608', 3, 'Sondesvar fastA1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575c-0000-4000-8000-00003922575c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '2be08a68-0000-4000-8000-00002be08a68', 3, 'Sondesvar fastA2');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575d-0000-4000-8000-00003922575d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '2be0fec8-0000-4000-8000-00002be0fec8', 3, 'Sondesvar fastA3');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577a-0000-4000-8000-00003922577a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '2bee2d8c-0000-4000-8000-00002bee2d8c', 3, 'Sondesvar fastB1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577b-0000-4000-8000-00003922577b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '2beea1ec-0000-4000-8000-00002beea1ec', 3, 'Sondesvar fastB2');
-- --- push_abonnementer: forutsetninger og proberader ---
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('834a4d61-0000-4000-8000-0000834a4d61', '00000000-0000-0000-0000-00000000a000', 'https://sonde.local/push/brukerowner_A', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('d73c42b6-0000-4000-8000-0000d73c42b6', '00000000-0000-0000-0000-00000000a001', 'https://sonde.local/push/brukermanager_A1', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('104c143c-0000-4000-8000-0000104c143c', '00000000-0000-0000-0000-00000000a012', 'https://sonde.local/push/brukermanager_A12', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('6262c135-0000-4000-8000-00006262c135', '00000000-0000-0000-0000-00000000a101', 'https://sonde.local/push/brukertablet_A1', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('834a4d62-0000-4000-8000-0000834a4d62', '00000000-0000-0000-0000-00000000b000', 'https://sonde.local/push/brukerowner_B', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('d73c42d5-0000-4000-8000-0000d73c42d5', '00000000-0000-0000-0000-00000000b001', 'https://sonde.local/push/brukermanager_B1', 'sonde-p256dh', 'sonde-auth');
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('6262c154-0000-4000-8000-00006262c154', '00000000-0000-0000-0000-00000000b101', 'https://sonde.local/push/brukertablet_B1', 'sonde-p256dh', 'sonde-auth');
-- --- raa_filer: forutsetninger og proberader ---
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed7d-0000-4000-8000-0000f22aed7d', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-fastA1.csv', 'sonde/fastA1.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed7e-0000-4000-8000-0000f22aed7e', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-fastA2.csv', 'sonde/fastA2.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed7f-0000-4000-8000-0000f22aed7f', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-fastA3.csv', 'sonde/fastA3.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed9c-0000-4000-8000-0000f22aed9c', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-fastB1.csv', 'sonde/fastB1.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed9d-0000-4000-8000-0000f22aed9d', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-fastB2.csv', 'sonde/fastB2.csv', 'epost');

create or replace function pg_temp.nyrad_raa_filer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal)
  values (p_retailer, 'sonde-' || p_merke || '-' || nextval('tenant_teller'::regclass) || '.csv', 'sonde/' || p_merke || '-' || nextval('tenant_teller'::regclass) || '.csv', 'epost')
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
-- --- regnskapsanalyser: forutsetninger og proberader ---
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('13698085-0000-4000-8000-000013698085', 'aaaa0000-0000-4000-8000-000000000000', date '2026-01-01' + 32, '{}'::jsonb);
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('13698086-0000-4000-8000-000013698086', 'aaaa0000-0000-4000-8000-000000000000', date '2026-01-01' + 33, '{}'::jsonb);
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('13698087-0000-4000-8000-000013698087', 'aaaa0000-0000-4000-8000-000000000000', date '2026-01-01' + 34, '{}'::jsonb);
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('136980a4-0000-4000-8000-0000136980a4', 'bbbb0000-0000-4000-8000-000000000000', date '2026-01-01' + 35, '{}'::jsonb);
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('136980a5-0000-4000-8000-0000136980a5', 'bbbb0000-0000-4000-8000-000000000000', date '2026-01-01' + 36, '{}'::jsonb);

create or replace function pg_temp.nyrad_regnskapsanalyser(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.regnskapsanalyser (retailer_id, periode, rapport)
  values (p_retailer, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '{}'::jsonb)
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
-- --- retailer_kodeerklaering: forutsetninger og proberader ---
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
-- --- retailer_koderegel: forutsetninger og proberader ---
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5b-0000-4000-8000-0000c922ed5b', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA1');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5c-0000-4000-8000-0000c922ed5c', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA2');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5d-0000-4000-8000-0000c922ed5d', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA3');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7a-0000-4000-8000-0000c922ed7a', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastB1');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7b-0000-4000-8000-0000c922ed7b', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastB2');

create or replace function pg_temp.nyrad_retailer_koderegel(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode)
  values (p_retailer, 'drivstoff', 'avdeling', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- retailers: forutsetninger og proberader ---
-- Proberaden er en rad fasitverdenen alt har skrevet. Ingen seeding.

-- =====================================================================
-- puls_runde  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_runde');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_runde owner_A SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde owner_A SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde owner_A INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23492-0000-4000-8000-000047e23492'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_A INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c14-0000-4000-8000-000047f04c14'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('puls_runde owner_A UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('puls_runde owner_A DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23494-0000-4000-8000-000047e23494', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde owner_A FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_runde manager_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23495-0000-4000-8000-000047e23495'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c17-0000-4000-8000-000047f04c17'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('puls_runde manager_A1 UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('puls_runde manager_A1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23497-0000-4000-8000-000047e23497', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_runde manager_A12 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A12 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23498-0000-4000-8000-000047e23498'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A12 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c1a-0000-4000-8000-000047f04c1a'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('puls_runde manager_A12 UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('puls_runde manager_A12 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''');
select pg_temp.som_eier();
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e2349a-0000-4000-8000-000047e2349a', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_runde tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b0-0000-4000-8000-000047e234b0'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c32-0000-4000-8000-000047f04c32'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_runde tablet_A1 UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_runde tablet_A1 UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_runde tablet_A1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_runde tablet_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('puls_runde owner_B SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde owner_B SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde owner_B INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c33-0000-4000-8000-000047f04c33'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_B INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b3-0000-4000-8000-000047e234b3'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('puls_runde owner_B UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('puls_runde owner_B DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''');
select pg_temp.som_eier();
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04c35-0000-4000-8000-000047f04c35', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde owner_B FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_runde manager_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c36-0000-4000-8000-000047f04c36'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b6-0000-4000-8000-000047e234b6'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('puls_runde manager_B1 UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('puls_runde manager_B1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''');
select pg_temp.som_eier();
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04c38-0000-4000-8000-000047f04c38', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_runde tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c39-0000-4000-8000-000047f04c39'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b9-0000-4000-8000-000047e234b9'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_runde tablet_B1 UPDATE B', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_runde tablet_B1 UPDATE A', 'update public.puls_runde set notat = ''endret av sonden'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_runde tablet_B1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_runde tablet_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

-- =====================================================================
-- puls_sporsmal  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_sporsmal');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_sporsmal owner_A SELECT A -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'positiv');
select pg_temp.paastand('puls_sporsmal owner_A SELECT B -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'negativ');
select pg_temp.skriv_tillatt('puls_sporsmal owner_A INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal owner_AA1'')');
select pg_temp.skriv_avvist('puls_sporsmal owner_A INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('puls_sporsmal owner_A UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_sporsmal owner_A UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('puls_sporsmal owner_A DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_sporsmal owner_A DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.skriv_avvist('puls_sporsmal owner_A FLYTTER egen rad -> kjede B', 'update public.puls_sporsmal set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_sporsmal manager_A1 SELECT A -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'positiv');
select pg_temp.paastand('puls_sporsmal manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'negativ');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A1 INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_A1A1'')');
select pg_temp.skriv_avvist('puls_sporsmal manager_A1 INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A1 UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_sporsmal manager_A1 UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A1 DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_sporsmal manager_A1 DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.skriv_avvist('puls_sporsmal manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_sporsmal set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_sporsmal manager_A12 SELECT A -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'positiv');
select pg_temp.paastand('puls_sporsmal manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'negativ');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A12 INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_A12A1'')');
select pg_temp.skriv_avvist('puls_sporsmal manager_A12 INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A12 UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_sporsmal manager_A12 UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('puls_sporsmal manager_A12 DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''');
select pg_temp.som_eier();
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_sporsmal manager_A12 DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.skriv_avvist('puls_sporsmal manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_sporsmal set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_sporsmal tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'positiv');
select pg_temp.paastand('puls_sporsmal tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'negativ');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_A1 DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('puls_sporsmal owner_B SELECT B -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'positiv');
select pg_temp.paastand('puls_sporsmal owner_B SELECT A -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'negativ');
select pg_temp.skriv_tillatt('puls_sporsmal owner_B INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal owner_BB1'')');
select pg_temp.skriv_avvist('puls_sporsmal owner_B INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('puls_sporsmal owner_B UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_sporsmal owner_B UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('puls_sporsmal owner_B DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''');
select pg_temp.som_eier();
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_sporsmal owner_B DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.skriv_avvist('puls_sporsmal owner_B FLYTTER egen rad -> kjede A', 'update public.puls_sporsmal set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_sporsmal manager_B1 SELECT B -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'positiv');
select pg_temp.paastand('puls_sporsmal manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'negativ');
select pg_temp.skriv_tillatt('puls_sporsmal manager_B1 INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_B1B1'')');
select pg_temp.skriv_avvist('puls_sporsmal manager_B1 INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('puls_sporsmal manager_B1 UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_sporsmal manager_B1 UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('puls_sporsmal manager_B1 DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''');
select pg_temp.som_eier();
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_sporsmal manager_B1 DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.skriv_avvist('puls_sporsmal manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_sporsmal set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_sporsmal tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_sporsmal where id = '6a0e2c2b-0000-4000-8000-00006a0e2c2b'), 'positiv');
select pg_temp.paastand('puls_sporsmal tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_sporsmal where id = '6a0e2c0c-0000-4000-8000-00006a0e2c0c'), 'negativ');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 INSERT B', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondesporsmaal tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 INSERT A', 'insert into public.puls_sporsmal (retailer_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondesporsmaal tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 UPDATE B', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 UPDATE A', 'update public.puls_sporsmal set kategori = ''Endret av sonden'' where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 DELETE B', 'delete from public.puls_sporsmal where id = ''6a0e2c2b-0000-4000-8000-00006a0e2c2b''', 'puls_sporsmal', '6a0e2c2b-0000-4000-8000-00006a0e2c2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_sporsmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('puls_sporsmal tablet_B1 DELETE A', 'delete from public.puls_sporsmal where id = ''6a0e2c0c-0000-4000-8000-00006a0e2c0c''', 'puls_sporsmal', '6a0e2c0c-0000-4000-8000-00006a0e2c0c', 'id');

-- =====================================================================
-- puls_svar  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_svar owner_A SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A2 -> ser', exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A3 -> ser', exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be016ea-0000-4000-8000-00002be016ea'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b5f-0000-4000-8000-00002be08b5f'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffbf-0000-4000-8000-00002be0ffbf'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''2bee2e83-0000-4000-8000-00002bee2e83'', 3, ''Sondesvar owner_AB1'')');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.skriv_avvist('puls_svar owner_A UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_svar manager_A1 SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'negativ');
select pg_temp.paastand('puls_svar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be01703-0000-4000-8000-00002be01703'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b63-0000-4000-8000-00002be08b63'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffc3-0000-4000-8000-00002be0ffc3'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''2bee2e87-0000-4000-8000-00002bee2e87'', 3, ''Sondesvar manager_A1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_svar manager_A12 SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar manager_A12 SELECT A2 -> ser', exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'positiv');
select pg_temp.paastand('puls_svar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be01707-0000-4000-8000-00002be01707'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b67-0000-4000-8000-00002be08b67'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffc7-0000-4000-8000-00002be0ffc7'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783c7-0000-4000-8000-000051d783c7'', 3, ''Sondesvar manager_A12B1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.skriv_avvist('puls_svar manager_A12 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_svar tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'negativ');
select pg_temp.paastand('puls_svar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab29-0000-4000-8000-00005022ab29'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c2ab-0000-4000-8000-00005030c2ab'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503eda2d-0000-4000-8000-0000503eda2d'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783cb-0000-4000-8000-000051d783cb'', 3, ''Sondesvar tablet_A1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575c-0000-4000-8000-00003922575c''', 'puls_svar', '3922575c-0000-4000-8000-00003922575c', 'id');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE A3', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575d-0000-4000-8000-00003922575d''', 'puls_svar', '3922575d-0000-4000-8000-00003922575d', 'id');
select pg_temp.skriv_avvist('puls_svar tablet_A1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('puls_svar owner_B SELECT B1 -> ser', exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'positiv');
select pg_temp.paastand('puls_svar owner_B SELECT B2 -> ser', exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'positiv');
select pg_temp.paastand('puls_svar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783cc-0000-4000-8000-000051d783cc'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b4e-0000-4000-8000-000051e59b4e'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab2f-0000-4000-8000-00005022ab2f'', 3, ''Sondesvar owner_BA1'')');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.skriv_avvist('puls_svar owner_B UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'positiv');
select pg_temp.paastand('puls_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'negativ');
select pg_temp.paastand('puls_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783cf-0000-4000-8000-000051d783cf'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b51-0000-4000-8000-000051e59b51'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab47-0000-4000-8000-00005022ab47'', 3, ''Sondesvar manager_B1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.skriv_avvist('puls_svar manager_B1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_svar tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.paastand('puls_svar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577b-0000-4000-8000-00003922577b'), 'negativ');
select pg_temp.paastand('puls_svar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'negativ');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783e7-0000-4000-8000-000051d783e7'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b69-0000-4000-8000-000051e59b69'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab4a-0000-4000-8000-00005022ab4a'', 3, ''Sondesvar tablet_B1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE B1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577a-0000-4000-8000-00003922577a''', 'puls_svar', '3922577a-0000-4000-8000-00003922577a', 'id');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE B2', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922577b-0000-4000-8000-00003922577b''', 'puls_svar', '3922577b-0000-4000-8000-00003922577b', 'id');
select pg_temp.skriv_avvist('puls_svar tablet_B1 UPDATE A1', 'update public.puls_svar set kommentar = ''endret av sonden'' where id = ''3922575b-0000-4000-8000-00003922575b''', 'puls_svar', '3922575b-0000-4000-8000-00003922575b', 'id');

-- =====================================================================
-- push_abonnementer  (brukerscope paa user_id, warm)
-- =====================================================================
select pg_temp.sett_gruppe('push_abonnementer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('push_abonnementer owner_A SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'positiv');
select pg_temp.paastand('push_abonnementer owner_A SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_A SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_A SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_A SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_A SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_A SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer owner_A INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a000'', ''https://sonde.local/push/insowner_A'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer owner_A INSERT paa manager_A1 sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a001'', ''https://sonde.local/push/insfowner_A'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer owner_A UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d61-0000-4000-8000-0000834a4d61''');
select pg_temp.skriv_avvist('push_abonnementer owner_A UPDATE manager_A1 sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''d73c42b6-0000-4000-8000-0000d73c42b6''', 'push_abonnementer', 'd73c42b6-0000-4000-8000-0000d73c42b6', 'id');
select pg_temp.skriv_avvist('push_abonnementer owner_A DELETE manager_A1 sin rad', 'delete from public.push_abonnementer where id = ''d73c42b6-0000-4000-8000-0000d73c42b6''', 'push_abonnementer', 'd73c42b6-0000-4000-8000-0000d73c42b6', 'id');
select pg_temp.skriv_tillatt('push_abonnementer owner_A DELETE egen rad', 'delete from public.push_abonnementer where id = ''834a4d61-0000-4000-8000-0000834a4d61''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('834a4d61-0000-4000-8000-0000834a4d61', '00000000-0000-0000-0000-00000000a000', 'https://sonde.local/push/gjenowner_A', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('push_abonnementer manager_A1 SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'positiv');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer manager_A1 INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a001'', ''https://sonde.local/push/insmanager_A1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer manager_A1 INSERT paa owner_A sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a000'', ''https://sonde.local/push/insfmanager_A1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer manager_A1 UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''d73c42b6-0000-4000-8000-0000d73c42b6''');
select pg_temp.skriv_avvist('push_abonnementer manager_A1 UPDATE owner_A sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_avvist('push_abonnementer manager_A1 DELETE owner_A sin rad', 'delete from public.push_abonnementer where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_tillatt('push_abonnementer manager_A1 DELETE egen rad', 'delete from public.push_abonnementer where id = ''d73c42b6-0000-4000-8000-0000d73c42b6''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('d73c42b6-0000-4000-8000-0000d73c42b6', '00000000-0000-0000-0000-00000000a001', 'https://sonde.local/push/gjenmanager_A1', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('push_abonnementer manager_A12 SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'positiv');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer manager_A12 INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a012'', ''https://sonde.local/push/insmanager_A12'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer manager_A12 INSERT paa owner_A sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a000'', ''https://sonde.local/push/insfmanager_A12'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer manager_A12 UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''104c143c-0000-4000-8000-0000104c143c''');
select pg_temp.skriv_avvist('push_abonnementer manager_A12 UPDATE owner_A sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_avvist('push_abonnementer manager_A12 DELETE owner_A sin rad', 'delete from public.push_abonnementer where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_tillatt('push_abonnementer manager_A12 DELETE egen rad', 'delete from public.push_abonnementer where id = ''104c143c-0000-4000-8000-0000104c143c''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('104c143c-0000-4000-8000-0000104c143c', '00000000-0000-0000-0000-00000000a012', 'https://sonde.local/push/gjenmanager_A12', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'positiv');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer tablet_A1 INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a101'', ''https://sonde.local/push/instablet_A1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer tablet_A1 INSERT paa owner_A sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000a000'', ''https://sonde.local/push/insftablet_A1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer tablet_A1 UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''6262c135-0000-4000-8000-00006262c135''');
select pg_temp.skriv_avvist('push_abonnementer tablet_A1 UPDATE owner_A sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_avvist('push_abonnementer tablet_A1 DELETE owner_A sin rad', 'delete from public.push_abonnementer where id = ''834a4d61-0000-4000-8000-0000834a4d61''', 'push_abonnementer', '834a4d61-0000-4000-8000-0000834a4d61', 'id');
select pg_temp.skriv_tillatt('push_abonnementer tablet_A1 DELETE egen rad', 'delete from public.push_abonnementer where id = ''6262c135-0000-4000-8000-00006262c135''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('6262c135-0000-4000-8000-00006262c135', '00000000-0000-0000-0000-00000000a101', 'https://sonde.local/push/gjentablet_A1', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('push_abonnementer owner_B SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'positiv');
select pg_temp.paastand('push_abonnementer owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.paastand('push_abonnementer owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer owner_B INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b000'', ''https://sonde.local/push/insowner_B'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer owner_B INSERT paa manager_B1 sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b001'', ''https://sonde.local/push/insfowner_B'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer owner_B UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d62-0000-4000-8000-0000834a4d62''');
select pg_temp.skriv_avvist('push_abonnementer owner_B UPDATE manager_B1 sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''d73c42d5-0000-4000-8000-0000d73c42d5''', 'push_abonnementer', 'd73c42d5-0000-4000-8000-0000d73c42d5', 'id');
select pg_temp.skriv_avvist('push_abonnementer owner_B DELETE manager_B1 sin rad', 'delete from public.push_abonnementer where id = ''d73c42d5-0000-4000-8000-0000d73c42d5''', 'push_abonnementer', 'd73c42d5-0000-4000-8000-0000d73c42d5', 'id');
select pg_temp.skriv_tillatt('push_abonnementer owner_B DELETE egen rad', 'delete from public.push_abonnementer where id = ''834a4d62-0000-4000-8000-0000834a4d62''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('834a4d62-0000-4000-8000-0000834a4d62', '00000000-0000-0000-0000-00000000b000', 'https://sonde.local/push/gjenowner_B', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('push_abonnementer manager_B1 SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'positiv');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer manager_B1 INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b001'', ''https://sonde.local/push/insmanager_B1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer manager_B1 INSERT paa owner_B sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b000'', ''https://sonde.local/push/insfmanager_B1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer manager_B1 UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''d73c42d5-0000-4000-8000-0000d73c42d5''');
select pg_temp.skriv_avvist('push_abonnementer manager_B1 UPDATE owner_B sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d62-0000-4000-8000-0000834a4d62''', 'push_abonnementer', '834a4d62-0000-4000-8000-0000834a4d62', 'id');
select pg_temp.skriv_avvist('push_abonnementer manager_B1 DELETE owner_B sin rad', 'delete from public.push_abonnementer where id = ''834a4d62-0000-4000-8000-0000834a4d62''', 'push_abonnementer', '834a4d62-0000-4000-8000-0000834a4d62', 'id');
select pg_temp.skriv_tillatt('push_abonnementer manager_B1 DELETE egen rad', 'delete from public.push_abonnementer where id = ''d73c42d5-0000-4000-8000-0000d73c42d5''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('d73c42d5-0000-4000-8000-0000d73c42d5', '00000000-0000-0000-0000-00000000b001', 'https://sonde.local/push/gjenmanager_B1', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.push_abonnementer where id = '6262c154-0000-4000-8000-00006262c154'), 'positiv');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d61-0000-4000-8000-0000834a4d61'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42b6-0000-4000-8000-0000d73c42b6'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '104c143c-0000-4000-8000-0000104c143c'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '6262c135-0000-4000-8000-00006262c135'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = '834a4d62-0000-4000-8000-0000834a4d62'), 'negativ');
select pg_temp.paastand('push_abonnementer tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.push_abonnementer where id = 'd73c42d5-0000-4000-8000-0000d73c42d5'), 'negativ');
select pg_temp.skriv_tillatt('push_abonnementer tablet_B1 INSERT paa seg selv', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b101'', ''https://sonde.local/push/instablet_B1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_avvist('push_abonnementer tablet_B1 INSERT paa owner_B sin liste', 'insert into public.push_abonnementer (user_id, endpoint, p256dh, auth) values (''00000000-0000-0000-0000-00000000b000'', ''https://sonde.local/push/insftablet_B1'', ''sonde-p256dh'', ''sonde-auth'')');
select pg_temp.skriv_tillatt('push_abonnementer tablet_B1 UPDATE egen rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''6262c154-0000-4000-8000-00006262c154''');
select pg_temp.skriv_avvist('push_abonnementer tablet_B1 UPDATE owner_B sin rad', 'update public.push_abonnementer set p256dh = ''endret'' where id = ''834a4d62-0000-4000-8000-0000834a4d62''', 'push_abonnementer', '834a4d62-0000-4000-8000-0000834a4d62', 'id');
select pg_temp.skriv_avvist('push_abonnementer tablet_B1 DELETE owner_B sin rad', 'delete from public.push_abonnementer where id = ''834a4d62-0000-4000-8000-0000834a4d62''', 'push_abonnementer', '834a4d62-0000-4000-8000-0000834a4d62', 'id');
select pg_temp.skriv_tillatt('push_abonnementer tablet_B1 DELETE egen rad', 'delete from public.push_abonnementer where id = ''6262c154-0000-4000-8000-00006262c154''');
select pg_temp.som_eier();
insert into public.push_abonnementer (id, user_id, endpoint, p256dh, auth) values ('6262c154-0000-4000-8000-00006262c154', '00000000-0000-0000-0000-00000000b101', 'https://sonde.local/push/gjentablet_B1', 'sonde-p256dh', 'sonde-auth');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');

-- =====================================================================
-- raa_filer  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('raa_filer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('raa_filer owner_A SELECT A -> ser', exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'positiv');
select pg_temp.paastand('raa_filer owner_A SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.skriv_tillatt('raa_filer owner_A INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-owner_AA1.csv'', ''sonde/owner_AA1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer owner_A INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-owner_AB1.csv'', ''sonde/owner_AB1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('raa_filer owner_A UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('raa_filer owner_A UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('raa_filer owner_A DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''');
select pg_temp.som_eier();
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed7d-0000-4000-8000-0000f22aed7d', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-gjenowner_AA1.csv', 'sonde/gjenowner_AA1.csv', 'epost');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('raa_filer owner_A DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.skriv_avvist('raa_filer owner_A FLYTTER egen rad -> kjede B', 'update public.raa_filer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('raa_filer manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.paastand('raa_filer manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.skriv_avvist('raa_filer manager_A1 INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-manager_A1A1.csv'', ''sonde/manager_A1A1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer manager_A1 INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-manager_A1B1.csv'', ''sonde/manager_A1B1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('raa_filer manager_A1 UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('raa_filer manager_A1 UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('raa_filer manager_A1 DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('raa_filer manager_A1 DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('raa_filer manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.paastand('raa_filer manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.skriv_avvist('raa_filer manager_A12 INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-manager_A12A1.csv'', ''sonde/manager_A12A1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer manager_A12 INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-manager_A12B1.csv'', ''sonde/manager_A12B1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('raa_filer manager_A12 UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('raa_filer manager_A12 UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('raa_filer manager_A12 DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('raa_filer manager_A12 DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('raa_filer tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.paastand('raa_filer tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.skriv_avvist('raa_filer tablet_A1 INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-tablet_A1A1.csv'', ''sonde/tablet_A1A1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer tablet_A1 INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-tablet_A1B1.csv'', ''sonde/tablet_A1B1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('raa_filer tablet_A1 UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('raa_filer tablet_A1 UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('raa_filer tablet_A1 DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('raa_filer tablet_A1 DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('raa_filer owner_B SELECT B -> ser', exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'positiv');
select pg_temp.paastand('raa_filer owner_B SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.skriv_tillatt('raa_filer owner_B INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-owner_BB1.csv'', ''sonde/owner_BB1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer owner_B INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-owner_BA1.csv'', ''sonde/owner_BA1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('raa_filer owner_B UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('raa_filer owner_B UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('raa_filer owner_B DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''');
select pg_temp.som_eier();
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('f22aed9c-0000-4000-8000-0000f22aed9c', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-gjenowner_BB1.csv', 'sonde/gjenowner_BB1.csv', 'epost');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('raa_filer owner_B DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.skriv_avvist('raa_filer owner_B FLYTTER egen rad -> kjede A', 'update public.raa_filer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('raa_filer manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.paastand('raa_filer manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.skriv_avvist('raa_filer manager_B1 INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-manager_B1B1.csv'', ''sonde/manager_B1B1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer manager_B1 INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-manager_B1A1.csv'', ''sonde/manager_B1A1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('raa_filer manager_B1 UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('raa_filer manager_B1 UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('raa_filer manager_B1 DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('raa_filer manager_B1 DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('raa_filer tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed9c-0000-4000-8000-0000f22aed9c'), 'negativ');
select pg_temp.paastand('raa_filer tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.raa_filer where id = 'f22aed7d-0000-4000-8000-0000f22aed7d'), 'negativ');
select pg_temp.skriv_avvist('raa_filer tablet_B1 INSERT B', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''bbbb0000-0000-4000-8000-000000000000'', ''sonde-tablet_B1B1.csv'', ''sonde/tablet_B1B1.csv'', ''epost'')');
select pg_temp.skriv_avvist('raa_filer tablet_B1 INSERT A', 'insert into public.raa_filer (retailer_id, filnavn, storage_sti, mottakskanal) values (''aaaa0000-0000-4000-8000-000000000000'', ''sonde-tablet_B1A1.csv'', ''sonde/tablet_B1A1.csv'', ''epost'')');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('raa_filer tablet_B1 UPDATE B', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('raa_filer tablet_B1 UPDATE A', 'update public.raa_filer set filnavn = ''endret.csv'' where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('raa_filer tablet_B1 DELETE B', 'delete from public.raa_filer where id = ''f22aed9c-0000-4000-8000-0000f22aed9c''', 'raa_filer', 'f22aed9c-0000-4000-8000-0000f22aed9c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_raa_filer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('raa_filer tablet_B1 DELETE A', 'delete from public.raa_filer where id = ''f22aed7d-0000-4000-8000-0000f22aed7d''', 'raa_filer', 'f22aed7d-0000-4000-8000-0000f22aed7d', 'id');

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
-- regnskapsanalyser  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('regnskapsanalyser');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('regnskapsanalyser owner_A SELECT A -> ser', exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'positiv');
select pg_temp.paastand('regnskapsanalyser owner_A SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_A INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 181, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser owner_A INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 182, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_A UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapsanalyser owner_A UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_A DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''');
select pg_temp.som_eier();
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('13698085-0000-4000-8000-000013698085', 'aaaa0000-0000-4000-8000-000000000000', date '2026-01-01' + 183, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapsanalyser owner_A DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.skriv_avvist('regnskapsanalyser owner_A FLYTTER egen rad -> kjede B', 'update public.regnskapsanalyser set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('regnskapsanalyser manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.paastand('regnskapsanalyser manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 184, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 185, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A1 DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('regnskapsanalyser manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.paastand('regnskapsanalyser manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 186, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 187, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapsanalyser manager_A12 DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('regnskapsanalyser tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.paastand('regnskapsanalyser tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 188, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 189, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_A1 DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('regnskapsanalyser owner_B SELECT B -> ser', exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'positiv');
select pg_temp.paastand('regnskapsanalyser owner_B SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_B INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 190, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser owner_B INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 191, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_B UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapsanalyser owner_B UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapsanalyser owner_B DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''');
select pg_temp.som_eier();
insert into public.regnskapsanalyser (id, retailer_id, periode, rapport) values ('136980a4-0000-4000-8000-0000136980a4', 'bbbb0000-0000-4000-8000-000000000000', date '2026-01-01' + 192, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapsanalyser owner_B DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.skriv_avvist('regnskapsanalyser owner_B FLYTTER egen rad -> kjede A', 'update public.regnskapsanalyser set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('regnskapsanalyser manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.paastand('regnskapsanalyser manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 193, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 194, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapsanalyser manager_B1 DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('regnskapsanalyser tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '136980a4-0000-4000-8000-0000136980a4'), 'negativ');
select pg_temp.paastand('regnskapsanalyser tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.regnskapsanalyser where id = '13698085-0000-4000-8000-000013698085'), 'negativ');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 INSERT B', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 195, ''{}''::jsonb)');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 INSERT A', 'insert into public.regnskapsanalyser (retailer_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', date ''2026-01-01'' + 196, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 UPDATE B', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 UPDATE A', 'update public.regnskapsanalyser set rapport = ''{"endret": true}''::jsonb where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 DELETE B', 'delete from public.regnskapsanalyser where id = ''136980a4-0000-4000-8000-0000136980a4''', 'regnskapsanalyser', '136980a4-0000-4000-8000-0000136980a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapsanalyser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapsanalyser tablet_B1 DELETE A', 'delete from public.regnskapsanalyser where id = ''13698085-0000-4000-8000-000013698085''', 'regnskapsanalyser', '13698085-0000-4000-8000-000013698085', 'id');

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
-- retailer_kodeerklaering  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailer_kodeerklaering');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailer_kodeerklaering owner_A SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_kodeerklaering owner_A INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.som_eier();
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A FLYTTER egen rad -> kjede B', 'update public.retailer_kodeerklaering set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailer_kodeerklaering manager_A1 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailer_kodeerklaering manager_A12 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A12 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A12 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailer_kodeerklaering tablet_A1 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_A1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_A1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailer_kodeerklaering owner_B SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_kodeerklaering owner_B INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.som_eier();
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B FLYTTER egen rad -> kjede A', 'update public.retailer_kodeerklaering set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailer_kodeerklaering manager_B1 SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_B1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_B1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailer_kodeerklaering tablet_B1 SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_B1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_B1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

-- =====================================================================
-- retailer_koderegel  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailer_koderegel');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailer_koderegel owner_A SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('retailer_koderegel owner_A INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_koderegel owner_A UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''');
select pg_temp.som_eier();
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5b-0000-4000-8000-0000c922ed5b', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_koderegel owner_A DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.skriv_avvist('retailer_koderegel owner_A FLYTTER egen rad -> kjede B', 'update public.retailer_koderegel set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailer_koderegel manager_A1 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailer_koderegel manager_A12 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailer_koderegel tablet_A1 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailer_koderegel owner_B SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('retailer_koderegel owner_B INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_koderegel owner_B UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''');
select pg_temp.som_eier();
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7a-0000-4000-8000-0000c922ed7a', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_koderegel owner_B DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.skriv_avvist('retailer_koderegel owner_B FLYTTER egen rad -> kjede A', 'update public.retailer_koderegel set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailer_koderegel manager_B1 SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailer_koderegel tablet_B1 SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

-- =====================================================================
-- retailers  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailers');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailers owner_A SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers owner_A INSERT A', 'insert into public.retailers (navn) values (''Sondekjede owner_AA1'')');
select pg_temp.skriv_avvist('retailers owner_A INSERT B', 'insert into public.retailers (navn) values (''Sondekjede owner_AB1'')');
select pg_temp.skriv_tillatt('retailers owner_A UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''');
select pg_temp.skriv_avvist('retailers owner_A UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_A DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_A DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailers manager_A1 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_A1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_A1A1'')');
select pg_temp.skriv_avvist('retailers manager_A1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_A1B1'')');
select pg_temp.skriv_avvist('retailers manager_A1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailers manager_A12 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_A12 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_A12A1'')');
select pg_temp.skriv_avvist('retailers manager_A12 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_A12B1'')');
select pg_temp.skriv_avvist('retailers manager_A12 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailers tablet_A1 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers tablet_A1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede tablet_A1A1'')');
select pg_temp.skriv_avvist('retailers tablet_A1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede tablet_A1B1'')');
select pg_temp.skriv_avvist('retailers tablet_A1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailers owner_B SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers owner_B INSERT B', 'insert into public.retailers (navn) values (''Sondekjede owner_BB1'')');
select pg_temp.skriv_avvist('retailers owner_B INSERT A', 'insert into public.retailers (navn) values (''Sondekjede owner_BA1'')');
select pg_temp.skriv_tillatt('retailers owner_B UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''');
select pg_temp.skriv_avvist('retailers owner_B UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_B DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_B DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailers manager_B1 SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_B1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_B1B1'')');
select pg_temp.skriv_avvist('retailers manager_B1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_B1A1'')');
select pg_temp.skriv_avvist('retailers manager_B1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailers tablet_B1 SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers tablet_B1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede tablet_B1B1'')');
select pg_temp.skriv_avvist('retailers tablet_B1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede tablet_B1A1'')');
select pg_temp.skriv_avvist('retailers tablet_B1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 7/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 7/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
