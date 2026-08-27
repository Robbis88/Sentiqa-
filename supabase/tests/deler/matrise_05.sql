-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 9. Hele matrisen er for stor for Supabase SQL
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a140d05-0000-4000-8000-00009a140d05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a1410c7-0000-4000-8000-00009a1410c7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a141489-0000-4000-8000-00009a141489', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a148167-0000-4000-8000-00009a148167', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a148529-0000-4000-8000-00009a148529', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('159cf3cf-0000-4000-8000-0000159cf3cf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('beb6f4c3-0000-4000-8000-0000beb6f4c3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('159cf791-0000-4000-8000-0000159cf791', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('beb6f885-0000-4000-8000-0000beb6f885', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('159cfb53-0000-4000-8000-0000159cfb53', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('beb6fc47-0000-4000-8000-0000beb6fc47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('159d6831-0000-4000-8000-0000159d6831', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('beb76925-0000-4000-8000-0000beb76925', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('159d6bf3-0000-4000-8000-0000159d6bf3', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('beb76ce7-0000-4000-8000-0000beb76ce7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2653-0000-4000-8000-0000227d2653', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 25');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2654-0000-4000-8000-0000227d2654', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 26');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2655-0000-4000-8000-0000227d2655', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 27');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2656-0000-4000-8000-0000227d2656', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 28');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3dd8-0000-4000-8000-0000228b3dd8', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 29');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3dee-0000-4000-8000-0000228b3dee', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 30');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3def-0000-4000-8000-0000228b3def', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 31');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d944d-0000-4000-8000-0000a86d944d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08ad-0000-4000-8000-0000a86e08ad', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d0d-0000-4000-8000-0000a86e7d0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87babd1-0000-4000-8000-0000a87babd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d9466-0000-4000-8000-0000a86d9466', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08c6-0000-4000-8000-0000a86e08c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d26-0000-4000-8000-0000a86e7d26', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d9469-0000-4000-8000-0000a86d9469', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08c9-0000-4000-8000-0000a86e08c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d29-0000-4000-8000-0000a86e7d29', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87babed-0000-4000-8000-0000a87babed', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d946d-0000-4000-8000-0000a86d946d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d946e-0000-4000-8000-0000a86d946e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08ce-0000-4000-8000-0000a86e08ce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d43-0000-4000-8000-0000a86e7d43', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac07-0000-4000-8000-0000a87bac07', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d9487-0000-4000-8000-0000a86d9487', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08e7-0000-4000-8000-0000a86e08e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d9489-0000-4000-8000-0000a86d9489', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e08e9-0000-4000-8000-0000a86e08e9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d49-0000-4000-8000-0000a86e7d49', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac0d-0000-4000-8000-0000a87bac0d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac0e-0000-4000-8000-0000a87bac0e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c206e-0000-4000-8000-0000a87c206e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94a4-0000-4000-8000-0000a86d94a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac26-0000-4000-8000-0000a87bac26', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c2086-0000-4000-8000-0000a87c2086', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac28-0000-4000-8000-0000a87bac28', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c2088-0000-4000-8000-0000a87c2088', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94a9-0000-4000-8000-0000a86d94a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac2b-0000-4000-8000-0000a87bac2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac2c-0000-4000-8000-0000a87bac2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c208c-0000-4000-8000-0000a87c208c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94ad-0000-4000-8000-0000a86d94ad', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01869e-0000-4000-8000-00009e01869e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a42a-0000-4000-8000-00001827a42a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fafe-0000-4000-8000-00009e01fafe', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1828188a-0000-4000-8000-00001828188a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026f5e-0000-4000-8000-00009e026f5e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288cea-0000-4000-8000-000018288cea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9e22-0000-4000-8000-00009e0f9e22', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bbae-0000-4000-8000-00001835bbae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186a2-0000-4000-8000-00009e0186a2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a42e-0000-4000-8000-00001827a42e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fb02-0000-4000-8000-00009e01fb02', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1828188e-0000-4000-8000-00001828188e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026f62-0000-4000-8000-00009e026f62', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288cee-0000-4000-8000-000018288cee', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186a5-0000-4000-8000-00009e0186a5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a431-0000-4000-8000-00001827a431', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fb05-0000-4000-8000-00009e01fb05', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18281891-0000-4000-8000-000018281891', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026f65-0000-4000-8000-00009e026f65', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288cf1-0000-4000-8000-000018288cf1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9e3e-0000-4000-8000-00009e0f9e3e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bbca-0000-4000-8000-00001835bbca', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186be-0000-4000-8000-00009e0186be', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a44a-0000-4000-8000-00001827a44a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186bf-0000-4000-8000-00009e0186bf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a44b-0000-4000-8000-00001827a44b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fb1f-0000-4000-8000-00009e01fb1f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('182818ab-0000-4000-8000-0000182818ab', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026f7f-0000-4000-8000-00009e026f7f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288d0b-0000-4000-8000-000018288d0b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9e43-0000-4000-8000-00009e0f9e43', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bbcf-0000-4000-8000-00001835bbcf', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186c3-0000-4000-8000-00009e0186c3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a44f-0000-4000-8000-00001827a44f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fb23-0000-4000-8000-00009e01fb23', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('182818af-0000-4000-8000-0000182818af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0186c5-0000-4000-8000-00009e0186c5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a451-0000-4000-8000-00001827a451', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fb25-0000-4000-8000-00009e01fb25', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('182818b1-0000-4000-8000-0000182818b1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b620d-0000-4000-8000-0000224b620d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f601-0000-4000-8000-0000ece8f601', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bab-0000-4000-8000-000023e40bab', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819f9f-0000-4000-8000-0000ee819f9f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bac-0000-4000-8000-000023e40bac', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fa0-0000-4000-8000-0000ee819fa0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f2232e-0000-4000-8000-000023f2232e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb722-0000-4000-8000-0000ee8fb722', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f330f-0000-4000-8000-0000222f330f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc703-0000-4000-8000-0000ecccc703', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40baf-0000-4000-8000-000023e40baf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fa3-0000-4000-8000-0000ee819fa3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22331-0000-4000-8000-000023f22331', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb725-0000-4000-8000-0000ee8fb725', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bb1-0000-4000-8000-000023e40bb1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fa5-0000-4000-8000-0000ee819fa5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22333-0000-4000-8000-000023f22333', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb727-0000-4000-8000-0000ee8fb727', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3314-0000-4000-8000-0000222f3314', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc708-0000-4000-8000-0000ecccc708', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bc9-0000-4000-8000-000023e40bc9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fbd-0000-4000-8000-0000ee819fbd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bca-0000-4000-8000-000023e40bca', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fbe-0000-4000-8000-0000ee819fbe', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f2234c-0000-4000-8000-000023f2234c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb740-0000-4000-8000-0000ee8fb740', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f332d-0000-4000-8000-0000222f332d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc721-0000-4000-8000-0000ecccc721', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3a9-0000-4000-8000-00002d27a3a9', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 207');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3aa-0000-4000-8000-00002d27a3aa', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 208');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3ab-0000-4000-8000-00002d27a3ab', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 209');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c1-0000-4000-8000-00002d27a3c1', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 210');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c2-0000-4000-8000-00002d27a3c2', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 211');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c3-0000-4000-8000-00002d27a3c3', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 212');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c4-0000-4000-8000-00002d27a3c4', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 213');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c5-0000-4000-8000-00002d27a3c5', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 214');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c6-0000-4000-8000-00002d27a3c6', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 215');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c7-0000-4000-8000-00002d27a3c7', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 216');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c8-0000-4000-8000-00002d27a3c8', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 217');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a3c9-0000-4000-8000-00002d27a3c9', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 218');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c69-0000-4000-8000-00002edc7c69', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 219');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c7f-0000-4000-8000-00002edc7c7f', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 220');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c80-0000-4000-8000-00002edc7c80', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 221');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c81-0000-4000-8000-00002edc7c81', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 222');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c82-0000-4000-8000-00002edc7c82', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 223');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c83-0000-4000-8000-00002edc7c83', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 224');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c84-0000-4000-8000-00002edc7c84', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 225');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c85-0000-4000-8000-00002edc7c85', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 226');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7c86-0000-4000-8000-00002edc7c86', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 227');
-- --- opplaering_skift: forutsetninger og proberader ---
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '9a140d05-0000-4000-8000-00009a140d05', date '2026-01-01' + 0);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '9a1410c7-0000-4000-8000-00009a1410c7', date '2026-01-01' + 1);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '9a141489-0000-4000-8000-00009a141489', date '2026-01-01' + 2);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '9a148167-0000-4000-8000-00009a148167', date '2026-01-01' + 3);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '9a148529-0000-4000-8000-00009a148529', date '2026-01-01' + 4);

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
-- --- opplaering_utfort: forutsetninger og proberader ---
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'beb6f4c3-0000-4000-8000-0000beb6f4c3', '159cf3cf-0000-4000-8000-0000159cf3cf');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'beb6f885-0000-4000-8000-0000beb6f885', '159cf791-0000-4000-8000-0000159cf791');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', 'beb6fc47-0000-4000-8000-0000beb6fc47', '159cfb53-0000-4000-8000-0000159cfb53');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'beb76925-0000-4000-8000-0000beb76925', '159d6831-0000-4000-8000-0000159d6831');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', 'beb76ce7-0000-4000-8000-0000beb76ce7', '159d6bf3-0000-4000-8000-0000159d6bf3');

create or replace function pg_temp.nyrad_opplaering_utfort(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_oppgave uuid := gen_random_uuid();
  v_periode uuid := gen_random_uuid();
begin
  insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values (v_oppgave, p_retailer, 'Sondeoppgave', 'Kasse');
  insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values (v_periode, p_retailer, p_stasjon, 'Sonde Sondesen', current_date);
  insert into public.opplaering_utfort (periode_id, oppgave_id)
  values (v_periode, v_oppgave)
  returning id into ny;
  return ny;
end $fn$;
-- --- pengepremie: forutsetninger og proberader ---
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie fastA1', 100, date '2026-01-01' + 10);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie fastA2', 100, date '2026-01-01' + 11);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie fastA3', 100, date '2026-01-01' + 12);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie fastB1', 100, date '2026-01-01' + 13);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie fastB2', 100, date '2026-01-01' + 14);

create or replace function pg_temp.nyrad_pengepremie(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato)
  values (p_retailer, p_stasjon, 'Sondepremie ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 100, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- pengepremie_bruk: forutsetninger og proberader ---
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991c-0000-4000-8000-0000caae991c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie fastA1', 500);
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991d-0000-4000-8000-0000caae991d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie fastA2', 500);
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991e-0000-4000-8000-0000caae991e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie fastA3', 500);
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae993b-0000-4000-8000-0000caae993b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie fastB1', 500);
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae993c-0000-4000-8000-0000caae993c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie fastB2', 500);

create or replace function pg_temp.nyrad_pengepremie_bruk(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr)
  values (p_retailer, p_stasjon, 'Sondepremie ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 500)
  returning id into ny;
  return ny;
end $fn$;
-- --- persondata_logg: forutsetninger og proberader ---
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d7-0000-4000-8000-0000a78b10d7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastA1', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d8-0000-4000-8000-0000a78b10d8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastA2', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d9-0000-4000-8000-0000a78b10d9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde_oppslag', 'fastA3', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f6-0000-4000-8000-0000a78b10f6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastB1', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f7-0000-4000-8000-0000a78b10f7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastB2', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
-- --- personlig_kryss: forutsetninger og proberader ---
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '227d2653-0000-4000-8000-0000227d2653', date '2026-01-01' + 25);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '227d2654-0000-4000-8000-0000227d2654', date '2026-01-01' + 26);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '227d2655-0000-4000-8000-0000227d2655', date '2026-01-01' + 27);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '227d2656-0000-4000-8000-0000227d2656', date '2026-01-01' + 28);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '228b3dd8-0000-4000-8000-0000228b3dd8', date '2026-01-01' + 29);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '228b3dee-0000-4000-8000-0000228b3dee', date '2026-01-01' + 30);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '228b3def-0000-4000-8000-0000228b3def', date '2026-01-01' + 31);
-- --- personlig_punkt: forutsetninger og proberader ---
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('ede83c80-0000-4000-8000-0000ede83c80', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt brukerowner_A');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('f8320b37-0000-4000-8000-0000f8320b37', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt brukermanager_A1');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('0e0f5bdb-0000-4000-8000-00000e0f5bdb', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt brukermanager_A12');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('9d416494-0000-4000-8000-00009d416494', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt brukertablet_A1');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('ede83c81-0000-4000-8000-0000ede83c81', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt brukerowner_B');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('f8320b56-0000-4000-8000-0000f8320b56', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt brukermanager_B1');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('9d4164b3-0000-4000-8000-00009d4164b3', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt brukertablet_B1');
-- --- pin_forsok: forutsetninger og proberader ---
insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values ('aaaa0000-0000-4000-8000-000000000000', 'fastA1', 'vakt', false);
insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values ('aaaa0000-0000-4000-8000-000000000000', 'fastA2', 'vakt', false);
insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values ('aaaa0000-0000-4000-8000-000000000000', 'fastA3', 'vakt', false);
insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values ('bbbb0000-0000-4000-8000-000000000000', 'fastB1', 'vakt', false);
insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values ('bbbb0000-0000-4000-8000-000000000000', 'fastB2', 'vakt', false);

create or replace function pg_temp.nyrad_pin_forsok(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok)
  values (p_retailer, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'vakt', false);
end $fn$;
-- --- plattform_innlegg: forutsetninger og proberader ---
insert into public.plattform_innlegg (id, tittel, innhold, publisert) values ('727ec031-0000-4000-8000-0000727ec031', 'Sondeinnlegg global', 'Sondetekst', true);
insert into public.plattform_innlegg (id, tittel, innhold, publisert) values ('ce74f8a9-0000-4000-8000-0000ce74f8a9', 'Sondeinnlegg usynlig', 'Sondetekst', false);

-- =====================================================================
-- opplaering_skift  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_skift');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_skift owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d944d-0000-4000-8000-0000a86d944d'', date ''2026-01-01'' + 46)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e08ad-0000-4000-8000-0000a86e08ad'', date ''2026-01-01'' + 47)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d0d-0000-4000-8000-0000a86e7d0d'', date ''2026-01-01'' + 48)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87babd1-0000-4000-8000-0000a87babd1'', date ''2026-01-01'' + 49)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d9466-0000-4000-8000-0000a86d9466', date '2026-01-01' + 50);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e08c6-0000-4000-8000-0000a86e08c6', date '2026-01-01' + 51);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7d26-0000-4000-8000-0000a86e7d26', date '2026-01-01' + 52);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d9469-0000-4000-8000-0000a86d9469'', date ''2026-01-01'' + 53)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e08c9-0000-4000-8000-0000a86e08c9'', date ''2026-01-01'' + 54)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d29-0000-4000-8000-0000a86e7d29'', date ''2026-01-01'' + 55)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87babed-0000-4000-8000-0000a87babed'', date ''2026-01-01'' + 56)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d946d-0000-4000-8000-0000a86d946d', date '2026-01-01' + 57);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d946e-0000-4000-8000-0000a86d946e'', date ''2026-01-01'' + 58)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e08ce-0000-4000-8000-0000a86e08ce'', date ''2026-01-01'' + 59)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d43-0000-4000-8000-0000a86e7d43'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac07-0000-4000-8000-0000a87bac07'', date ''2026-01-01'' + 61)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d9487-0000-4000-8000-0000a86d9487', date '2026-01-01' + 62);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e08e7-0000-4000-8000-0000a86e08e7', date '2026-01-01' + 63);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d9489-0000-4000-8000-0000a86d9489'', date ''2026-01-01'' + 64)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e08e9-0000-4000-8000-0000a86e08e9'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d49-0000-4000-8000-0000a86e7d49'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac0d-0000-4000-8000-0000a87bac0d'', date ''2026-01-01'' + 67)');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac0e-0000-4000-8000-0000a87bac0e'', date ''2026-01-01'' + 68)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c206e-0000-4000-8000-0000a87c206e'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94a4-0000-4000-8000-0000a86d94a4'', date ''2026-01-01'' + 70)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87bac26-0000-4000-8000-0000a87bac26', date '2026-01-01' + 71);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', 'a87c2086-0000-4000-8000-0000a87c2086', date '2026-01-01' + 72);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac28-0000-4000-8000-0000a87bac28'', date ''2026-01-01'' + 73)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c2088-0000-4000-8000-0000a87c2088'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94a9-0000-4000-8000-0000a86d94a9'', date ''2026-01-01'' + 75)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87bac2b-0000-4000-8000-0000a87bac2b', date '2026-01-01' + 76);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac2c-0000-4000-8000-0000a87bac2c'', date ''2026-01-01'' + 77)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''a87c208c-0000-4000-8000-0000a87c208c'', date ''2026-01-01'' + 78)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94ad-0000-4000-8000-0000a86d94ad'', date ''2026-01-01'' + 79)');
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

-- =====================================================================
-- opplaering_utfort  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_utfort');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_utfort owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1827a42a-0000-4000-8000-00001827a42a'', ''9e01869e-0000-4000-8000-00009e01869e'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1828188a-0000-4000-8000-00001828188a'', ''9e01fafe-0000-4000-8000-00009e01fafe'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''18288cea-0000-4000-8000-000018288cea'', ''9e026f5e-0000-4000-8000-00009e026f5e'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_A INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1835bbae-0000-4000-8000-00001835bbae'', ''9e0f9e22-0000-4000-8000-00009e0f9e22'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_utfort owner_A UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a42e-0000-4000-8000-00001827a42e', '9e0186a2-0000-4000-8000-00009e0186a2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', '1828188e-0000-4000-8000-00001828188e', '9e01fb02-0000-4000-8000-00009e01fb02');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', '18288cee-0000-4000-8000-000018288cee', '9e026f62-0000-4000-8000-00009e026f62');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_utfort owner_A DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1827a431-0000-4000-8000-00001827a431'', ''9e0186a5-0000-4000-8000-00009e0186a5'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''18281891-0000-4000-8000-000018281891'', ''9e01fb05-0000-4000-8000-00009e01fb05'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''18288cf1-0000-4000-8000-000018288cf1'', ''9e026f65-0000-4000-8000-00009e026f65'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1835bbca-0000-4000-8000-00001835bbca'', ''9e0f9e3e-0000-4000-8000-00009e0f9e3e'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a44a-0000-4000-8000-00001827a44a', '9e0186be-0000-4000-8000-00009e0186be');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1827a44b-0000-4000-8000-00001827a44b'', ''9e0186bf-0000-4000-8000-00009e0186bf'')');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''182818ab-0000-4000-8000-0000182818ab'', ''9e01fb1f-0000-4000-8000-00009e01fb1f'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''18288d0b-0000-4000-8000-000018288d0b'', ''9e026f7f-0000-4000-8000-00009e026f7f'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1835bbcf-0000-4000-8000-00001835bbcf'', ''9e0f9e43-0000-4000-8000-00009e0f9e43'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a44f-0000-4000-8000-00001827a44f', '9e0186c3-0000-4000-8000-00009e0186c3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', '182818af-0000-4000-8000-0000182818af', '9e01fb23-0000-4000-8000-00009e01fb23');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''1827a451-0000-4000-8000-00001827a451'', ''9e0186c5-0000-4000-8000-00009e0186c5'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''182818b1-0000-4000-8000-0000182818b1'', ''9e01fb25-0000-4000-8000-00009e01fb25'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f601-0000-4000-8000-0000ece8f601'', ''224b620d-0000-4000-8000-0000224b620d'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819f9f-0000-4000-8000-0000ee819f9f'', ''23e40bab-0000-4000-8000-000023e40bab'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_utfort owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fa0-0000-4000-8000-0000ee819fa0'', ''23e40bac-0000-4000-8000-000023e40bac'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb722-0000-4000-8000-0000ee8fb722'', ''23f2232e-0000-4000-8000-000023f2232e'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_B INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc703-0000-4000-8000-0000ecccc703'', ''222f330f-0000-4000-8000-0000222f330f'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee819fa3-0000-4000-8000-0000ee819fa3', '23e40baf-0000-4000-8000-000023e40baf');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', 'ee8fb725-0000-4000-8000-0000ee8fb725', '23f22331-0000-4000-8000-000023f22331');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fa5-0000-4000-8000-0000ee819fa5'', ''23e40bb1-0000-4000-8000-000023e40bb1'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb727-0000-4000-8000-0000ee8fb727'', ''23f22333-0000-4000-8000-000023f22333'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc708-0000-4000-8000-0000ecccc708'', ''222f3314-0000-4000-8000-0000222f3314'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee819fbd-0000-4000-8000-0000ee819fbd', '23e40bc9-0000-4000-8000-000023e40bc9');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fbe-0000-4000-8000-0000ee819fbe'', ''23e40bca-0000-4000-8000-000023e40bca'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb740-0000-4000-8000-0000ee8fb740'', ''23f2234c-0000-4000-8000-000023f2234c'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc721-0000-4000-8000-0000ecccc721'', ''222f332d-0000-4000-8000-0000222f332d'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

-- =====================================================================
-- pengepremie  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('pengepremie');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('pengepremie owner_A SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT A2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT A3 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AA1'', 100, date ''2026-01-01'' + 114)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_AA2'', 100, date ''2026-01-01'' + 115)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie owner_AA3'', 100, date ''2026-01-01'' + 116)');
select pg_temp.skriv_avvist('pengepremie owner_A INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AB1'', 100, date ''2026-01-01'' + 117)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie owner_A UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_AA1', 100, date '2026-01-01' + 118);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_AA2', 100, date '2026-01-01' + 119);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie gjenowner_AA3', 100, date '2026-01-01' + 120);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie owner_A DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie owner_A FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pengepremie manager_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'negativ');
select pg_temp.paastand('pengepremie manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1A1'', 100, date ''2026-01-01'' + 121)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A1A2'', 100, date ''2026-01-01'' + 122)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A1A3'', 100, date ''2026-01-01'' + 123)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1B1'', 100, date ''2026-01-01'' + 124)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie manager_A1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie manager_A1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A1A1', 100, date '2026-01-01' + 125);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A1 FLYTTER egen rad A1 -> A2', 'update public.pengepremie set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A1 FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pengepremie manager_A12 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie manager_A12 SELECT A2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'positiv');
select pg_temp.paastand('pengepremie manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12A1'', 100, date ''2026-01-01'' + 126)');
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A12A2'', 100, date ''2026-01-01'' + 127)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A12A3'', 100, date ''2026-01-01'' + 128)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12B1'', 100, date ''2026-01-01'' + 129)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A12A1', 100, date '2026-01-01' + 130);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenmanager_A12A2', 100, date '2026-01-01' + 131);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A12 FLYTTER egen rad A1 -> A3', 'update public.pengepremie set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A12 FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pengepremie tablet_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'negativ');
select pg_temp.paastand('pengepremie tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1A1'', 100, date ''2026-01-01'' + 132)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_A1A2'', 100, date ''2026-01-01'' + 133)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie tablet_A1A3'', 100, date ''2026-01-01'' + 134)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1B1'', 100, date ''2026-01-01'' + 135)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pengepremie owner_B SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie owner_B SELECT B2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'positiv');
select pg_temp.paastand('pengepremie owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BB1'', 100, date ''2026-01-01'' + 136)');
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_BB2'', 100, date ''2026-01-01'' + 137)');
select pg_temp.skriv_avvist('pengepremie owner_B INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BA1'', 100, date ''2026-01-01'' + 138)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie owner_B UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_BB1', 100, date '2026-01-01' + 139);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_BB2', 100, date '2026-01-01' + 140);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie owner_B DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie owner_B FLYTTER egen rad -> kjede A', 'update public.pengepremie set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pengepremie manager_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'negativ');
select pg_temp.paastand('pengepremie manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1B1'', 100, date ''2026-01-01'' + 141)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_B1B2'', 100, date ''2026-01-01'' + 142)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1A1'', 100, date ''2026-01-01'' + 143)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie manager_B1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie manager_B1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_B1B1', 100, date '2026-01-01' + 144);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_B1 FLYTTER egen rad B1 -> B2', 'update public.pengepremie set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_B1 FLYTTER egen rad -> kjede A', 'update public.pengepremie set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pengepremie tablet_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'negativ');
select pg_temp.paastand('pengepremie tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1B1'', 100, date ''2026-01-01'' + 145)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_B1B2'', 100, date ''2026-01-01'' + 146)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1A1'', 100, date ''2026-01-01'' + 147)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

-- =====================================================================
-- pengepremie_bruk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('pengepremie_bruk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('pengepremie_bruk owner_A SELECT A1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'positiv');
select pg_temp.paastand('pengepremie_bruk owner_A SELECT A2 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991d-0000-4000-8000-0000caae991d'), 'positiv');
select pg_temp.paastand('pengepremie_bruk owner_A SELECT A3 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991e-0000-4000-8000-0000caae991e'), 'positiv');
select pg_temp.paastand('pengepremie_bruk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AA1'', 500)');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A INSERT A2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_AA2'', 500)');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A INSERT A3', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie owner_AA3'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk owner_A INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AB1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A UPDATE A2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991d-0000-4000-8000-0000caae991d''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A UPDATE A3', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991e-0000-4000-8000-0000caae991e''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie_bruk owner_A UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991c-0000-4000-8000-0000caae991c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_AA1', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A DELETE A2', 'delete from public.pengepremie_bruk where id = ''caae991d-0000-4000-8000-0000caae991d''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991d-0000-4000-8000-0000caae991d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_AA2', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_A DELETE A3', 'delete from public.pengepremie_bruk where id = ''caae991e-0000-4000-8000-0000caae991e''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991e-0000-4000-8000-0000caae991e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie gjenowner_AA3', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie_bruk owner_A DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk owner_A FLYTTER egen rad -> kjede B', 'update public.pengepremie_bruk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pengepremie_bruk manager_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'positiv');
select pg_temp.paastand('pengepremie_bruk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991d-0000-4000-8000-0000caae991d'), 'negativ');
select pg_temp.paastand('pengepremie_bruk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991e-0000-4000-8000-0000caae991e'), 'negativ');
select pg_temp.paastand('pengepremie_bruk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A1 INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1A1'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 INSERT A2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A1A2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 INSERT A3', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A1A3'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1B1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A1 UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 UPDATE A2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991d-0000-4000-8000-0000caae991d''', 'pengepremie_bruk', 'caae991d-0000-4000-8000-0000caae991d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 UPDATE A3', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A1 DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991c-0000-4000-8000-0000caae991c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A1A1', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 DELETE A2', 'delete from public.pengepremie_bruk where id = ''caae991d-0000-4000-8000-0000caae991d''', 'pengepremie_bruk', 'caae991d-0000-4000-8000-0000caae991d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 DELETE A3', 'delete from public.pengepremie_bruk where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 FLYTTER egen rad A1 -> A2', 'update public.pengepremie_bruk set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A1 FLYTTER egen rad -> kjede B', 'update public.pengepremie_bruk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pengepremie_bruk manager_A12 SELECT A1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'positiv');
select pg_temp.paastand('pengepremie_bruk manager_A12 SELECT A2 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991d-0000-4000-8000-0000caae991d'), 'positiv');
select pg_temp.paastand('pengepremie_bruk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991e-0000-4000-8000-0000caae991e'), 'negativ');
select pg_temp.paastand('pengepremie_bruk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12A1'', 500)');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 INSERT A2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A12A2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 INSERT A3', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A12A3'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12B1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 UPDATE A2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991d-0000-4000-8000-0000caae991d''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 UPDATE A3', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991c-0000-4000-8000-0000caae991c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A12A1', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_A12 DELETE A2', 'delete from public.pengepremie_bruk where id = ''caae991d-0000-4000-8000-0000caae991d''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae991d-0000-4000-8000-0000caae991d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenmanager_A12A2', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 DELETE A3', 'delete from public.pengepremie_bruk where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 FLYTTER egen rad A1 -> A3', 'update public.pengepremie_bruk set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_A12 FLYTTER egen rad -> kjede B', 'update public.pengepremie_bruk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pengepremie_bruk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'positiv');
select pg_temp.paastand('pengepremie_bruk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991d-0000-4000-8000-0000caae991d'), 'negativ');
select pg_temp.paastand('pengepremie_bruk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991e-0000-4000-8000-0000caae991e'), 'negativ');
select pg_temp.paastand('pengepremie_bruk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'negativ');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1A1'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 INSERT A2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_A1A2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 INSERT A3', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie tablet_A1A3'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1B1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 UPDATE A2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991d-0000-4000-8000-0000caae991d''', 'pengepremie_bruk', 'caae991d-0000-4000-8000-0000caae991d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 UPDATE A3', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 DELETE A2', 'delete from public.pengepremie_bruk where id = ''caae991d-0000-4000-8000-0000caae991d''', 'pengepremie_bruk', 'caae991d-0000-4000-8000-0000caae991d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 DELETE A3', 'delete from public.pengepremie_bruk where id = ''caae991e-0000-4000-8000-0000caae991e''', 'pengepremie_bruk', 'caae991e-0000-4000-8000-0000caae991e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_A1 DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pengepremie_bruk owner_B SELECT B1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'positiv');
select pg_temp.paastand('pengepremie_bruk owner_B SELECT B2 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae993c-0000-4000-8000-0000caae993c'), 'positiv');
select pg_temp.paastand('pengepremie_bruk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BB1'', 500)');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B INSERT B2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_BB2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk owner_B INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BA1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B UPDATE B2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993c-0000-4000-8000-0000caae993c''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie_bruk owner_B UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae993b-0000-4000-8000-0000caae993b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_BB1', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie_bruk owner_B DELETE B2', 'delete from public.pengepremie_bruk where id = ''caae993c-0000-4000-8000-0000caae993c''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae993c-0000-4000-8000-0000caae993c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_BB2', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie_bruk owner_B DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk owner_B FLYTTER egen rad -> kjede A', 'update public.pengepremie_bruk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pengepremie_bruk manager_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'positiv');
select pg_temp.paastand('pengepremie_bruk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993c-0000-4000-8000-0000caae993c'), 'negativ');
select pg_temp.paastand('pengepremie_bruk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_B1 INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1B1'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 INSERT B2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_B1B2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1A1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_B1 UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 UPDATE B2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993c-0000-4000-8000-0000caae993c''', 'pengepremie_bruk', 'caae993c-0000-4000-8000-0000caae993c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie_bruk manager_B1 DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''');
select pg_temp.som_eier();
insert into public.pengepremie_bruk (id, retailer_id, stasjon_id, beskrivelse, belop_kr) values ('caae993b-0000-4000-8000-0000caae993b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_B1B1', 500);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 DELETE B2', 'delete from public.pengepremie_bruk where id = ''caae993c-0000-4000-8000-0000caae993c''', 'pengepremie_bruk', 'caae993c-0000-4000-8000-0000caae993c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 FLYTTER egen rad B1 -> B2', 'update public.pengepremie_bruk set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.skriv_avvist('pengepremie_bruk manager_B1 FLYTTER egen rad -> kjede A', 'update public.pengepremie_bruk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pengepremie_bruk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie_bruk where id = 'caae993b-0000-4000-8000-0000caae993b'), 'positiv');
select pg_temp.paastand('pengepremie_bruk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae993c-0000-4000-8000-0000caae993c'), 'negativ');
select pg_temp.paastand('pengepremie_bruk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie_bruk where id = 'caae991c-0000-4000-8000-0000caae991c'), 'negativ');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 INSERT B1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1B1'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 INSERT B2', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_B1B2'', 500)');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 INSERT A1', 'insert into public.pengepremie_bruk (retailer_id, stasjon_id, beskrivelse, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1A1'', 500)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 UPDATE B1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 UPDATE B2', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae993c-0000-4000-8000-0000caae993c''', 'pengepremie_bruk', 'caae993c-0000-4000-8000-0000caae993c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 UPDATE A1', 'update public.pengepremie_bruk set belop_kr = 750 where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 DELETE B1', 'delete from public.pengepremie_bruk where id = ''caae993b-0000-4000-8000-0000caae993b''', 'pengepremie_bruk', 'caae993b-0000-4000-8000-0000caae993b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 DELETE B2', 'delete from public.pengepremie_bruk where id = ''caae993c-0000-4000-8000-0000caae993c''', 'pengepremie_bruk', 'caae993c-0000-4000-8000-0000caae993c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie_bruk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie_bruk tablet_B1 DELETE A1', 'delete from public.pengepremie_bruk where id = ''caae991c-0000-4000-8000-0000caae991c''', 'pengepremie_bruk', 'caae991c-0000-4000-8000-0000caae991c', 'id');

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
-- personlig_kryss  (brukerscope paa user_id, warm)
-- =====================================================================
select pg_temp.sett_gruppe('personlig_kryss');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('personlig_kryss owner_A SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'positiv');
select pg_temp.paastand('personlig_kryss owner_A SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_A SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_A SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_A SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_A SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_A SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss owner_A INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a3a9-0000-4000-8000-00002d27a3a9'', date ''2026-01-01'' + 207)');
select pg_temp.skriv_avvist('personlig_kryss owner_A INSERT paa manager_A1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''2d27a3aa-0000-4000-8000-00002d27a3aa'', date ''2026-01-01'' + 208)');
select pg_temp.skriv_tillatt('personlig_kryss owner_A UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.skriv_avvist('personlig_kryss owner_A UPDATE manager_A1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_A DELETE manager_A1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_A DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '2d27a3ab-0000-4000-8000-00002d27a3ab', date '2026-01-01' + 209);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('personlig_kryss manager_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''2d27a3c1-0000-4000-8000-00002d27a3c1'', date ''2026-01-01'' + 210)');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a3c2-0000-4000-8000-00002d27a3c2'', date ''2026-01-01'' + 211)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '2d27a3c3-0000-4000-8000-00002d27a3c3', date '2026-01-01' + 212);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('personlig_kryss manager_A12 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a012'', ''2d27a3c4-0000-4000-8000-00002d27a3c4'', date ''2026-01-01'' + 213)');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a3c5-0000-4000-8000-00002d27a3c5'', date ''2026-01-01'' + 214)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 DELETE egen rad', 'delete from public.personlig_kryss where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '2d27a3c6-0000-4000-8000-00002d27a3c6', date '2026-01-01' + 215);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a101'', ''2d27a3c7-0000-4000-8000-00002d27a3c7'', date ''2026-01-01'' + 216)');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a3c8-0000-4000-8000-00002d27a3c8'', date ''2026-01-01'' + 217)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '2d27a3c9-0000-4000-8000-00002d27a3c9', date '2026-01-01' + 218);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('personlig_kryss owner_B SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'positiv');
select pg_temp.paastand('personlig_kryss owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss owner_B INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7c69-0000-4000-8000-00002edc7c69'', date ''2026-01-01'' + 219)');
select pg_temp.skriv_avvist('personlig_kryss owner_B INSERT paa manager_B1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc7c7f-0000-4000-8000-00002edc7c7f'', date ''2026-01-01'' + 220)');
select pg_temp.skriv_tillatt('personlig_kryss owner_B UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.skriv_avvist('personlig_kryss owner_B UPDATE manager_B1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_B DELETE manager_B1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_B DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '2edc7c80-0000-4000-8000-00002edc7c80', date '2026-01-01' + 221);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('personlig_kryss manager_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc7c81-0000-4000-8000-00002edc7c81'', date ''2026-01-01'' + 222)');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7c82-0000-4000-8000-00002edc7c82'', date ''2026-01-01'' + 223)');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '2edc7c83-0000-4000-8000-00002edc7c83', date '2026-01-01' + 224);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b101'', ''2edc7c84-0000-4000-8000-00002edc7c84'', date ''2026-01-01'' + 225)');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7c85-0000-4000-8000-00002edc7c85'', date ''2026-01-01'' + 226)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '2edc7c86-0000-4000-8000-00002edc7c86', date '2026-01-01' + 227);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');

-- =====================================================================
-- personlig_punkt  (brukerscope paa user_id, warm)
-- =====================================================================
select pg_temp.sett_gruppe('personlig_punkt');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('personlig_punkt owner_A SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'positiv');
select pg_temp.paastand('personlig_punkt owner_A SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_A SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_A SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_A SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_A SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_A SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt owner_A INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a000'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insowner_A'')');
select pg_temp.skriv_avvist('personlig_punkt owner_A INSERT paa manager_A1 sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a001'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insfowner_A'')');
select pg_temp.skriv_tillatt('personlig_punkt owner_A UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c80-0000-4000-8000-0000ede83c80''');
select pg_temp.skriv_avvist('personlig_punkt owner_A UPDATE manager_A1 sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''f8320b37-0000-4000-8000-0000f8320b37''', 'personlig_punkt', 'f8320b37-0000-4000-8000-0000f8320b37', 'id');
select pg_temp.skriv_avvist('personlig_punkt owner_A DELETE manager_A1 sin rad', 'delete from public.personlig_punkt where id = ''f8320b37-0000-4000-8000-0000f8320b37''', 'personlig_punkt', 'f8320b37-0000-4000-8000-0000f8320b37', 'id');
select pg_temp.skriv_tillatt('personlig_punkt owner_A DELETE egen rad', 'delete from public.personlig_punkt where id = ''ede83c80-0000-4000-8000-0000ede83c80''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('ede83c80-0000-4000-8000-0000ede83c80', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt gjenowner_A');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('personlig_punkt manager_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'positiv');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt manager_A1 INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a001'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insmanager_A1'')');
select pg_temp.skriv_avvist('personlig_punkt manager_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a000'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insfmanager_A1'')');
select pg_temp.skriv_tillatt('personlig_punkt manager_A1 UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''f8320b37-0000-4000-8000-0000f8320b37''');
select pg_temp.skriv_avvist('personlig_punkt manager_A1 UPDATE owner_A sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_avvist('personlig_punkt manager_A1 DELETE owner_A sin rad', 'delete from public.personlig_punkt where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_tillatt('personlig_punkt manager_A1 DELETE egen rad', 'delete from public.personlig_punkt where id = ''f8320b37-0000-4000-8000-0000f8320b37''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('f8320b37-0000-4000-8000-0000f8320b37', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt gjenmanager_A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('personlig_punkt manager_A12 SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'positiv');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt manager_A12 INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a012'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insmanager_A12'')');
select pg_temp.skriv_avvist('personlig_punkt manager_A12 INSERT paa owner_A sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a000'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insfmanager_A12'')');
select pg_temp.skriv_tillatt('personlig_punkt manager_A12 UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''0e0f5bdb-0000-4000-8000-00000e0f5bdb''');
select pg_temp.skriv_avvist('personlig_punkt manager_A12 UPDATE owner_A sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_avvist('personlig_punkt manager_A12 DELETE owner_A sin rad', 'delete from public.personlig_punkt where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_tillatt('personlig_punkt manager_A12 DELETE egen rad', 'delete from public.personlig_punkt where id = ''0e0f5bdb-0000-4000-8000-00000e0f5bdb''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('0e0f5bdb-0000-4000-8000-00000e0f5bdb', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt gjenmanager_A12');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'positiv');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt tablet_A1 INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a101'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt instablet_A1'')');
select pg_temp.skriv_avvist('personlig_punkt tablet_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000a000'', ''aaaa0000-0000-4000-8000-000000000000'', ''Sondepunkt insftablet_A1'')');
select pg_temp.skriv_tillatt('personlig_punkt tablet_A1 UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''9d416494-0000-4000-8000-00009d416494''');
select pg_temp.skriv_avvist('personlig_punkt tablet_A1 UPDATE owner_A sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_avvist('personlig_punkt tablet_A1 DELETE owner_A sin rad', 'delete from public.personlig_punkt where id = ''ede83c80-0000-4000-8000-0000ede83c80''', 'personlig_punkt', 'ede83c80-0000-4000-8000-0000ede83c80', 'id');
select pg_temp.skriv_tillatt('personlig_punkt tablet_A1 DELETE egen rad', 'delete from public.personlig_punkt where id = ''9d416494-0000-4000-8000-00009d416494''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('9d416494-0000-4000-8000-00009d416494', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt gjentablet_A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('personlig_punkt owner_B SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'positiv');
select pg_temp.paastand('personlig_punkt owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.paastand('personlig_punkt owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt owner_B INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b000'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt insowner_B'')');
select pg_temp.skriv_avvist('personlig_punkt owner_B INSERT paa manager_B1 sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b001'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt insfowner_B'')');
select pg_temp.skriv_tillatt('personlig_punkt owner_B UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c81-0000-4000-8000-0000ede83c81''');
select pg_temp.skriv_avvist('personlig_punkt owner_B UPDATE manager_B1 sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''f8320b56-0000-4000-8000-0000f8320b56''', 'personlig_punkt', 'f8320b56-0000-4000-8000-0000f8320b56', 'id');
select pg_temp.skriv_avvist('personlig_punkt owner_B DELETE manager_B1 sin rad', 'delete from public.personlig_punkt where id = ''f8320b56-0000-4000-8000-0000f8320b56''', 'personlig_punkt', 'f8320b56-0000-4000-8000-0000f8320b56', 'id');
select pg_temp.skriv_tillatt('personlig_punkt owner_B DELETE egen rad', 'delete from public.personlig_punkt where id = ''ede83c81-0000-4000-8000-0000ede83c81''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('ede83c81-0000-4000-8000-0000ede83c81', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt gjenowner_B');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('personlig_punkt manager_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'positiv');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt manager_B1 INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b001'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt insmanager_B1'')');
select pg_temp.skriv_avvist('personlig_punkt manager_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b000'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt insfmanager_B1'')');
select pg_temp.skriv_tillatt('personlig_punkt manager_B1 UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''f8320b56-0000-4000-8000-0000f8320b56''');
select pg_temp.skriv_avvist('personlig_punkt manager_B1 UPDATE owner_B sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c81-0000-4000-8000-0000ede83c81''', 'personlig_punkt', 'ede83c81-0000-4000-8000-0000ede83c81', 'id');
select pg_temp.skriv_avvist('personlig_punkt manager_B1 DELETE owner_B sin rad', 'delete from public.personlig_punkt where id = ''ede83c81-0000-4000-8000-0000ede83c81''', 'personlig_punkt', 'ede83c81-0000-4000-8000-0000ede83c81', 'id');
select pg_temp.skriv_tillatt('personlig_punkt manager_B1 DELETE egen rad', 'delete from public.personlig_punkt where id = ''f8320b56-0000-4000-8000-0000f8320b56''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('f8320b56-0000-4000-8000-0000f8320b56', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt gjenmanager_B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_punkt where id = '9d4164b3-0000-4000-8000-00009d4164b3'), 'positiv');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c80-0000-4000-8000-0000ede83c80'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b37-0000-4000-8000-0000f8320b37'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '0e0f5bdb-0000-4000-8000-00000e0f5bdb'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = '9d416494-0000-4000-8000-00009d416494'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'ede83c81-0000-4000-8000-0000ede83c81'), 'negativ');
select pg_temp.paastand('personlig_punkt tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_punkt where id = 'f8320b56-0000-4000-8000-0000f8320b56'), 'negativ');
select pg_temp.skriv_tillatt('personlig_punkt tablet_B1 INSERT paa seg selv', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b101'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt instablet_B1'')');
select pg_temp.skriv_avvist('personlig_punkt tablet_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_punkt (user_id, retailer_id, tittel) values (''00000000-0000-0000-0000-00000000b000'', ''bbbb0000-0000-4000-8000-000000000000'', ''Sondepunkt insftablet_B1'')');
select pg_temp.skriv_tillatt('personlig_punkt tablet_B1 UPDATE egen rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''9d4164b3-0000-4000-8000-00009d4164b3''');
select pg_temp.skriv_avvist('personlig_punkt tablet_B1 UPDATE owner_B sin rad', 'update public.personlig_punkt set tittel = ''endret av sonden'' where id = ''ede83c81-0000-4000-8000-0000ede83c81''', 'personlig_punkt', 'ede83c81-0000-4000-8000-0000ede83c81', 'id');
select pg_temp.skriv_avvist('personlig_punkt tablet_B1 DELETE owner_B sin rad', 'delete from public.personlig_punkt where id = ''ede83c81-0000-4000-8000-0000ede83c81''', 'personlig_punkt', 'ede83c81-0000-4000-8000-0000ede83c81', 'id');
select pg_temp.skriv_tillatt('personlig_punkt tablet_B1 DELETE egen rad', 'delete from public.personlig_punkt where id = ''9d4164b3-0000-4000-8000-00009d4164b3''');
select pg_temp.som_eier();
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('9d4164b3-0000-4000-8000-00009d4164b3', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt gjentablet_B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');

-- =====================================================================
-- pin_forsok  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('pin_forsok');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('pin_forsok owner_A SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok owner_A SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok owner_A INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''owner_AA1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok owner_A INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''owner_AB1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pin_forsok manager_A1 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A1B1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pin_forsok manager_A12 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A12A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A12B1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pin_forsok tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_A1B1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pin_forsok owner_B SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok owner_B SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''owner_BB1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''owner_BA1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pin_forsok manager_B1 SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_B1A1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pin_forsok tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_B1A1'', ''vakt'', false)');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pin_forsok('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

-- =====================================================================
-- plattform_innlegg  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('plattform_innlegg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('plattform_innlegg owner_A SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg owner_A SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg owner_A INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gowner_Ainsert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg owner_A UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg owner_A DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('plattform_innlegg manager_A1 SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg manager_A1 SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg manager_A1 INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gmanager_A1insert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg manager_A1 UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg manager_A1 DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('plattform_innlegg manager_A12 SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg manager_A12 SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg manager_A12 INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gmanager_A12insert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg manager_A12 UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg manager_A12 DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('plattform_innlegg tablet_A1 SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg tablet_A1 SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg tablet_A1 INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gtablet_A1insert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg tablet_A1 UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg tablet_A1 DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('plattform_innlegg owner_B SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg owner_B SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg owner_B INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gowner_Binsert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg owner_B UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg owner_B DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('plattform_innlegg manager_B1 SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg manager_B1 SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg manager_B1 INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gmanager_B1insert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg manager_B1 UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg manager_B1 DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('plattform_innlegg tablet_B1 SELECT den globale raden -> ser', exists (select 1 from public.plattform_innlegg where id = '727ec031-0000-4000-8000-0000727ec031'), 'positiv');
select pg_temp.paastand('plattform_innlegg tablet_B1 SELECT den skjulte raden -> ser ikke', not exists (select 1 from public.plattform_innlegg where id = 'ce74f8a9-0000-4000-8000-0000ce74f8a9'), 'negativ');
select pg_temp.skriv_avvist('plattform_innlegg tablet_B1 INSERT den globale raden', 'insert into public.plattform_innlegg (tittel, innhold, publisert) values (''Sondeinnlegg gtablet_B1insert'', ''Sondetekst'', true)');
select pg_temp.skriv_avvist('plattform_innlegg tablet_B1 UPDATE den globale raden', 'update public.plattform_innlegg set tittel = ''endret av sonden'' where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');
select pg_temp.skriv_avvist('plattform_innlegg tablet_B1 DELETE den globale raden', 'delete from public.plattform_innlegg where id = ''727ec031-0000-4000-8000-0000727ec031''', 'plattform_innlegg', '727ec031-0000-4000-8000-0000727ec031', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 5/9: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/9: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
