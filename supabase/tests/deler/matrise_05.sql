-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 7. Hele matrisen er for stor for Supabase SQL
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

-- --- Forutsetninger, en per forsoek ---
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c53b7f-0000-4000-8000-0000d0c53b7f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c53f41-0000-4000-8000-0000d0c53f41', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c54303-0000-4000-8000-0000d0c54303', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c5afe1-0000-4000-8000-0000d0c5afe1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('d0c5b3a3-0000-4000-8000-0000d0c5b3a3', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643f0c-0000-4000-8000-00004b643f0c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0160d-0000-4000-8000-00002be0160d', 'aaaa0000-0000-4000-8000-000000000000', '4b643f0c-0000-4000-8000-00004b643f0c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b36c-0000-4000-8000-00004b64b36c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08a6d-0000-4000-8000-00002be08a6d', 'aaaa0000-0000-4000-8000-000000000000', '4b64b36c-0000-4000-8000-00004b64b36c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6527cc-0000-4000-8000-00004b6527cc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0fecd-0000-4000-8000-00002be0fecd', 'aaaa0000-0000-4000-8000-000000000000', '4b6527cc-0000-4000-8000-00004b6527cc', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b725690-0000-4000-8000-00004b725690', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2d91-0000-4000-8000-00002bee2d91', 'bbbb0000-0000-4000-8000-000000000000', '4b725690-0000-4000-8000-00004b725690', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72caf0-0000-4000-8000-00004b72caf0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2beea1f1-0000-4000-8000-00002beea1f1', 'bbbb0000-0000-4000-8000-000000000000', '4b72caf0-0000-4000-8000-00004b72caf0', date '2026-08-01', date '2026-08-31');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a6c3-0000-4000-8000-00002d60a6c3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b23-0000-4000-8000-00002d611b23', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618f83-0000-4000-8000-00002d618f83', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe47-0000-4000-8000-00002d6ebe47', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f32a7-0000-4000-8000-00002d6f32a7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23479-0000-4000-8000-000047e23479', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04bfb-0000-4000-8000-000047f04bfb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2347b-0000-4000-8000-000047e2347b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23491-0000-4000-8000-000047e23491', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c13-0000-4000-8000-000047f04c13', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23493-0000-4000-8000-000047e23493', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23494-0000-4000-8000-000047e23494', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c16-0000-4000-8000-000047f04c16', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23496-0000-4000-8000-000047e23496', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23497-0000-4000-8000-000047e23497', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c19-0000-4000-8000-000047f04c19', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c1a-0000-4000-8000-000047f04c1a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2349a-0000-4000-8000-000047e2349a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c31-0000-4000-8000-000047f04c31', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c32-0000-4000-8000-000047f04c32', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b2-0000-4000-8000-000047e234b2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c34-0000-4000-8000-000047f04c34', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c35-0000-4000-8000-000047f04c35', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e234b5-0000-4000-8000-000047e234b5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643fe5-0000-4000-8000-00004b643fe5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be016e6-0000-4000-8000-00002be016e6', 'aaaa0000-0000-4000-8000-000000000000', '4b643fe5-0000-4000-8000-00004b643fe5', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b445-0000-4000-8000-00004b64b445', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08b46-0000-4000-8000-00002be08b46', 'aaaa0000-0000-4000-8000-000000000000', '4b64b445-0000-4000-8000-00004b64b445', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b6528a5-0000-4000-8000-00004b6528a5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ffa6-0000-4000-8000-00002be0ffa6', 'aaaa0000-0000-4000-8000-000000000000', '4b6528a5-0000-4000-8000-00004b6528a5', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b725769-0000-4000-8000-00004b725769', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2e6a-0000-4000-8000-00002bee2e6a', 'bbbb0000-0000-4000-8000-000000000000', '4b725769-0000-4000-8000-00004b725769', date '2026-08-01', date '2026-08-31');
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
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aa9-0000-4000-8000-000022d87aa9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783c8-0000-4000-8000-000051d783c8', 'bbbb0000-0000-4000-8000-000000000000', '22d87aa9-0000-4000-8000-000022d87aa9', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6922b-0000-4000-8000-000022e6922b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b4a-0000-4000-8000-000051e59b4a', 'bbbb0000-0000-4000-8000-000000000000', '22e6922b-0000-4000-8000-000022e6922b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a20c-0000-4000-8000-00002123a20c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab2b-0000-4000-8000-00005022ab2b', 'aaaa0000-0000-4000-8000-000000000000', '2123a20c-0000-4000-8000-00002123a20c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aac-0000-4000-8000-000022d87aac', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783cb-0000-4000-8000-000051d783cb', 'bbbb0000-0000-4000-8000-000000000000', '22d87aac-0000-4000-8000-000022d87aac', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6922e-0000-4000-8000-000022e6922e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b4d-0000-4000-8000-000051e59b4d', 'bbbb0000-0000-4000-8000-000000000000', '22e6922e-0000-4000-8000-000022e6922e', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a20f-0000-4000-8000-00002123a20f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab2e-0000-4000-8000-00005022ab2e', 'aaaa0000-0000-4000-8000-000000000000', '2123a20f-0000-4000-8000-00002123a20f', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87aaf-0000-4000-8000-000022d87aaf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d783ce-0000-4000-8000-000051d783ce', 'bbbb0000-0000-4000-8000-000000000000', '22d87aaf-0000-4000-8000-000022d87aaf', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69231-0000-4000-8000-000022e69231', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59b50-0000-4000-8000-000051e59b50', 'bbbb0000-0000-4000-8000-000000000000', '22e69231-0000-4000-8000-000022e69231', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a212-0000-4000-8000-00002123a212', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ab31-0000-4000-8000-00005022ab31', 'aaaa0000-0000-4000-8000-000000000000', '2123a212-0000-4000-8000-00002123a212', date '2026-08-01', date '2026-08-31');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42ae6-0000-4000-8000-00007eb42ae6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24268-0000-4000-8000-00007ec24268', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059ea-0000-4000-8000-00007ed059ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690388-0000-4000-8000-000080690388', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42aea-0000-4000-8000-00007eb42aea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2426c-0000-4000-8000-00007ec2426c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059ee-0000-4000-8000-00007ed059ee', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42aed-0000-4000-8000-00007eb42aed', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2426f-0000-4000-8000-00007ec2426f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059f1-0000-4000-8000-00007ed059f1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903a4-0000-4000-8000-0000806903a4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b06-0000-4000-8000-00007eb42b06', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b07-0000-4000-8000-00007eb42b07', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24289-0000-4000-8000-00007ec24289', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05a0b-0000-4000-8000-00007ed05a0b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903a9-0000-4000-8000-0000806903a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b0b-0000-4000-8000-00007eb42b0b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2428d-0000-4000-8000-00007ec2428d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b0d-0000-4000-8000-00007eb42b0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2428f-0000-4000-8000-00007ec2428f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed05a26-0000-4000-8000-00007ed05a26', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903c4-0000-4000-8000-0000806903c4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b26-0000-4000-8000-00007eb42b26', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903c6-0000-4000-8000-0000806903c6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b48-0000-4000-8000-000080771b48', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b29-0000-4000-8000-00007eb42b29', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903c9-0000-4000-8000-0000806903c9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b4b-0000-4000-8000-000080771b4b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903cb-0000-4000-8000-0000806903cb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b4d-0000-4000-8000-000080771b4d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42dce-0000-4000-8000-00007eb42dce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069066e-0000-4000-8000-00008069066e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069066f-0000-4000-8000-00008069066f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771df1-0000-4000-8000-000080771df1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42dd2-0000-4000-8000-00007eb42dd2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690672-0000-4000-8000-000080690672', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
-- --- prognose_treff: forutsetninger og proberader ---
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f208589-0000-4000-8000-00009f208589', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 0, 'fastA1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858a-0000-4000-8000-00009f20858a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 1, 'fastA2', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858b-0000-4000-8000-00009f20858b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', date '2026-01-01' + 2, 'fastA3', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a8-0000-4000-8000-00009f2085a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 3, 'fastB1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a9-0000-4000-8000-00009f2085a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 4, 'fastB2', 100, 95);
-- --- puls_runde: forutsetninger og proberader ---
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'd0c53b7f-0000-4000-8000-0000d0c53b7f', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60e-0000-4000-8000-00001f2bd60e', 'aaaa0000-0000-4000-8000-000000000000', 'd0c53f41-0000-4000-8000-0000d0c53f41', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60f-0000-4000-8000-00001f2bd60f', 'aaaa0000-0000-4000-8000-000000000000', 'd0c54303-0000-4000-8000-0000d0c54303', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'd0c5afe1-0000-4000-8000-0000d0c5afe1', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62d-0000-4000-8000-00001f2bd62d', 'bbbb0000-0000-4000-8000-000000000000', 'd0c5b3a3-0000-4000-8000-0000d0c5b3a3', date '2026-08-01', date '2026-08-31');

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
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575b-0000-4000-8000-00003922575b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '2be0160d-0000-4000-8000-00002be0160d', 3, 'Sondesvar fastA1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575c-0000-4000-8000-00003922575c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '2be08a6d-0000-4000-8000-00002be08a6d', 3, 'Sondesvar fastA2');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575d-0000-4000-8000-00003922575d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '2be0fecd-0000-4000-8000-00002be0fecd', 3, 'Sondesvar fastA3');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577a-0000-4000-8000-00003922577a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '2bee2d91-0000-4000-8000-00002bee2d91', 3, 'Sondesvar fastB1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577b-0000-4000-8000-00003922577b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '2beea1f1-0000-4000-8000-00002beea1f1', 3, 'Sondesvar fastB2');

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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a6c3-0000-4000-8000-00002d60a6c3', date '2026-01-01' + 32);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611b23-0000-4000-8000-00002d611b23', date '2026-01-01' + 33);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '2d618f83-0000-4000-8000-00002d618f83', date '2026-01-01' + 34);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebe47-0000-4000-8000-00002d6ebe47', date '2026-01-01' + 35);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '2d6f32a7-0000-4000-8000-00002d6f32a7', date '2026-01-01' + 36);

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

-- =====================================================================
-- prognose_treff  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('prognose_treff');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('prognose_treff owner_A SELECT A1 -> ser', exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'positiv');
select pg_temp.paastand('prognose_treff owner_A SELECT A2 -> ser', exists (select 1 from public.prognose_treff where id = '9f20858a-0000-4000-8000-00009f20858a'), 'positiv');
select pg_temp.paastand('prognose_treff owner_A SELECT A3 -> ser', exists (select 1 from public.prognose_treff where id = '9f20858b-0000-4000-8000-00009f20858b'), 'positiv');
select pg_temp.paastand('prognose_treff owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('prognose_treff manager_A1 SELECT A1 -> ser', exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'positiv');
select pg_temp.paastand('prognose_treff manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f20858a-0000-4000-8000-00009f20858a'), 'negativ');
select pg_temp.paastand('prognose_treff manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f20858b-0000-4000-8000-00009f20858b'), 'negativ');
select pg_temp.paastand('prognose_treff manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('prognose_treff manager_A12 SELECT A1 -> ser', exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'positiv');
select pg_temp.paastand('prognose_treff manager_A12 SELECT A2 -> ser', exists (select 1 from public.prognose_treff where id = '9f20858a-0000-4000-8000-00009f20858a'), 'positiv');
select pg_temp.paastand('prognose_treff manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f20858b-0000-4000-8000-00009f20858b'), 'negativ');
select pg_temp.paastand('prognose_treff manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('prognose_treff tablet_A1 SELECT A1 -> ser', exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'positiv');
select pg_temp.paastand('prognose_treff tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f20858a-0000-4000-8000-00009f20858a'), 'negativ');
select pg_temp.paastand('prognose_treff tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f20858b-0000-4000-8000-00009f20858b'), 'negativ');
select pg_temp.paastand('prognose_treff tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('prognose_treff owner_B SELECT B1 -> ser', exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'positiv');
select pg_temp.paastand('prognose_treff owner_B SELECT B2 -> ser', exists (select 1 from public.prognose_treff where id = '9f2085a9-0000-4000-8000-00009f2085a9'), 'positiv');
select pg_temp.paastand('prognose_treff owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('prognose_treff manager_B1 SELECT B1 -> ser', exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'positiv');
select pg_temp.paastand('prognose_treff manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a9-0000-4000-8000-00009f2085a9'), 'negativ');
select pg_temp.paastand('prognose_treff manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('prognose_treff tablet_B1 SELECT B1 -> ser', exists (select 1 from public.prognose_treff where id = '9f2085a8-0000-4000-8000-00009f2085a8'), 'positiv');
select pg_temp.paastand('prognose_treff tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f2085a9-0000-4000-8000-00009f2085a9'), 'negativ');
select pg_temp.paastand('prognose_treff tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.prognose_treff where id = '9f208589-0000-4000-8000-00009f208589'), 'negativ');

-- =====================================================================
-- puls_runde  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_runde');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_runde owner_A SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde owner_A SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde owner_A INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23479-0000-4000-8000-000047e23479'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_A INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04bfb-0000-4000-8000-000047f04bfb'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e2347b-0000-4000-8000-000047e2347b', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde owner_A FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_runde manager_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23491-0000-4000-8000-000047e23491'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c13-0000-4000-8000-000047f04c13'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23493-0000-4000-8000-000047e23493', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_runde manager_A12 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A12 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23494-0000-4000-8000-000047e23494'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A12 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c16-0000-4000-8000-000047f04c16'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23496-0000-4000-8000-000047e23496', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_runde tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e23497-0000-4000-8000-000047e23497'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c19-0000-4000-8000-000047f04c19'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_tillatt('puls_runde owner_B INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c1a-0000-4000-8000-000047f04c1a'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_B INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e2349a-0000-4000-8000-000047e2349a'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04c31-0000-4000-8000-000047f04c31', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde owner_B FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_runde manager_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c32-0000-4000-8000-000047f04c32'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b2-0000-4000-8000-000047e234b2'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04c34-0000-4000-8000-000047f04c34', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_runde tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''47f04c35-0000-4000-8000-000047f04c35'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''47e234b5-0000-4000-8000-000047e234b5'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be016e6-0000-4000-8000-00002be016e6'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b46-0000-4000-8000-00002be08b46'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffa6-0000-4000-8000-00002be0ffa6'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''2bee2e6a-0000-4000-8000-00002bee2e6a'', 3, ''Sondesvar owner_AB1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be016ea-0000-4000-8000-00002be016ea'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b5f-0000-4000-8000-00002be08b5f'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffbf-0000-4000-8000-00002be0ffbf'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''2bee2e83-0000-4000-8000-00002bee2e83'', 3, ''Sondesvar manager_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be01703-0000-4000-8000-00002be01703'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b63-0000-4000-8000-00002be08b63'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffc3-0000-4000-8000-00002be0ffc3'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''2bee2e87-0000-4000-8000-00002bee2e87'', 3, ''Sondesvar manager_A12B1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''2be01707-0000-4000-8000-00002be01707'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''2be08b67-0000-4000-8000-00002be08b67'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''2be0ffc7-0000-4000-8000-00002be0ffc7'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783c7-0000-4000-8000-000051d783c7'', 3, ''Sondesvar tablet_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783c8-0000-4000-8000-000051d783c8'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b4a-0000-4000-8000-000051e59b4a'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab2b-0000-4000-8000-00005022ab2b'', 3, ''Sondesvar owner_BA1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783cb-0000-4000-8000-000051d783cb'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b4d-0000-4000-8000-000051e59b4d'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab2e-0000-4000-8000-00005022ab2e'', 3, ''Sondesvar manager_B1A1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d783ce-0000-4000-8000-000051d783ce'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59b50-0000-4000-8000-000051e59b50'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ab31-0000-4000-8000-00005022ab31'', 3, ''Sondesvar tablet_B1A1'')');
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
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42ae6-0000-4000-8000-00007eb42ae6'', date ''2026-01-01'' + 170)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec24268-0000-4000-8000-00007ec24268'', date ''2026-01-01'' + 171)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059ea-0000-4000-8000-00007ed059ea'', date ''2026-01-01'' + 172)');
select pg_temp.skriv_avvist('rutine_utforinger owner_A INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690388-0000-4000-8000-000080690388'', date ''2026-01-01'' + 173)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42aea-0000-4000-8000-00007eb42aea', date '2026-01-01' + 174);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec2426c-0000-4000-8000-00007ec2426c', date '2026-01-01' + 175);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '7ed059ee-0000-4000-8000-00007ed059ee', date '2026-01-01' + 176);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42aed-0000-4000-8000-00007eb42aed'', date ''2026-01-01'' + 177)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec2426f-0000-4000-8000-00007ec2426f'', date ''2026-01-01'' + 178)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059f1-0000-4000-8000-00007ed059f1'', date ''2026-01-01'' + 179)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903a4-0000-4000-8000-0000806903a4'', date ''2026-01-01'' + 180)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42b06-0000-4000-8000-00007eb42b06', date '2026-01-01' + 181);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b07-0000-4000-8000-00007eb42b07'', date ''2026-01-01'' + 182)');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec24289-0000-4000-8000-00007ec24289'', date ''2026-01-01'' + 183)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05a0b-0000-4000-8000-00007ed05a0b'', date ''2026-01-01'' + 184)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903a9-0000-4000-8000-0000806903a9'', date ''2026-01-01'' + 185)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42b0b-0000-4000-8000-00007eb42b0b', date '2026-01-01' + 186);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec2428d-0000-4000-8000-00007ec2428d', date '2026-01-01' + 187);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b0d-0000-4000-8000-00007eb42b0d'', date ''2026-01-01'' + 188)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec2428f-0000-4000-8000-00007ec2428f'', date ''2026-01-01'' + 189)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed05a26-0000-4000-8000-00007ed05a26'', date ''2026-01-01'' + 190)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903c4-0000-4000-8000-0000806903c4'', date ''2026-01-01'' + 191)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42b26-0000-4000-8000-00007eb42b26', date '2026-01-01' + 192);
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
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903c6-0000-4000-8000-0000806903c6'', date ''2026-01-01'' + 193)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771b48-0000-4000-8000-000080771b48'', date ''2026-01-01'' + 194)');
select pg_temp.skriv_avvist('rutine_utforinger owner_B INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b29-0000-4000-8000-00007eb42b29'', date ''2026-01-01'' + 195)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '806903c9-0000-4000-8000-0000806903c9', date '2026-01-01' + 196);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '80771b4b-0000-4000-8000-000080771b4b', date '2026-01-01' + 197);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903cb-0000-4000-8000-0000806903cb'', date ''2026-01-01'' + 198)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771b4d-0000-4000-8000-000080771b4d'', date ''2026-01-01'' + 199)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42dce-0000-4000-8000-00007eb42dce'', date ''2026-01-01'' + 200)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '8069066e-0000-4000-8000-00008069066e', date '2026-01-01' + 201);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''8069066f-0000-4000-8000-00008069066f'', date ''2026-01-01'' + 202)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771df1-0000-4000-8000-000080771df1'', date ''2026-01-01'' + 203)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42dd2-0000-4000-8000-00007eb42dd2'', date ''2026-01-01'' + 204)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '80690672-0000-4000-8000-000080690672', date '2026-01-01' + 205);
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
