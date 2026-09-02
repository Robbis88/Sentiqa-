-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 6 AV 10. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 12 ressurs(er):
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
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e27-0000-4000-8000-0000e8569e27', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 7');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e28-0000-4000-8000-0000e8569e28', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 8');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e29-0000-4000-8000-0000e8569e29', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 9');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d262f-0000-4000-8000-0000227d262f', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 10');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3db1-0000-4000-8000-0000228b3db1', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 11');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3db2-0000-4000-8000-0000228b3db2', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 12');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3db3-0000-4000-8000-0000228b3db3', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 13');
insert into auth.users (id, email) values ('483c79d9-0000-4000-8000-0000483c79d9', 'sonde-profil-38@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('483cee39-0000-4000-8000-0000483cee39', 'sonde-profil-39@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('483d62ae-0000-4000-8000-0000483d62ae', 'sonde-profil-40@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('484a9172-0000-4000-8000-0000484a9172', 'sonde-profil-41@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('484b05d2-0000-4000-8000-0000484b05d2', 'sonde-profil-42@kanari.local') on conflict (id) do nothing;
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23494-0000-4000-8000-000047e23494', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2a8f4-0000-4000-8000-000047e2a8f4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e31d54-0000-4000-8000-000047e31d54', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04c18-0000-4000-8000-000047f04c18', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f0c078-0000-4000-8000-000047f0c078', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d272c-0000-4000-8000-0000227d272c', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 95');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d272d-0000-4000-8000-0000227d272d', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 96');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d272e-0000-4000-8000-0000227d272e', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 97');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d272f-0000-4000-8000-0000227d272f', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 98');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2730-0000-4000-8000-0000227d2730', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 99');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe1-0000-4000-8000-00002d279fe1', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 100');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe2-0000-4000-8000-00002d279fe2', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 101');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe3-0000-4000-8000-00002d279fe3', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 102');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe4-0000-4000-8000-00002d279fe4', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 103');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe5-0000-4000-8000-00002d279fe5', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 104');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe6-0000-4000-8000-00002d279fe6', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 105');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d279fe7-0000-4000-8000-00002d279fe7', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 106');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7887-0000-4000-8000-00002edc7887', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 107');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7888-0000-4000-8000-00002edc7888', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 108');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7889-0000-4000-8000-00002edc7889', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 109');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc789f-0000-4000-8000-00002edc789f', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 110');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc78a0-0000-4000-8000-00002edc78a0', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 111');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc78a1-0000-4000-8000-00002edc78a1', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 112');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc78a2-0000-4000-8000-00002edc78a2', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 113');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc78a3-0000-4000-8000-00002edc78a3', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 114');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc78a4-0000-4000-8000-00002edc78a4', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 115');
insert into auth.users (id, email) values ('bf52bd3a-0000-4000-8000-0000bf52bd3a', 'sonde-profil-240@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795da-0000-4000-8000-0000c10795da', 'sonde-profil-241@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd3c-0000-4000-8000-0000bf52bd3c', 'sonde-profil-242@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795dc-0000-4000-8000-0000c10795dc', 'sonde-profil-243@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd3e-0000-4000-8000-0000bf52bd3e', 'sonde-profil-244@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795de-0000-4000-8000-0000c10795de', 'sonde-profil-245@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd40-0000-4000-8000-0000bf52bd40', 'sonde-profil-246@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795e0-0000-4000-8000-0000c10795e0', 'sonde-profil-247@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795e1-0000-4000-8000-0000c10795e1', 'sonde-profil-248@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd43-0000-4000-8000-0000bf52bd43', 'sonde-profil-249@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795f8-0000-4000-8000-0000c10795f8', 'sonde-profil-250@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd5a-0000-4000-8000-0000bf52bd5a', 'sonde-profil-251@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10795fa-0000-4000-8000-0000c10795fa', 'sonde-profil-252@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52bd5c-0000-4000-8000-0000bf52bd5c', 'sonde-profil-253@kanari.local') on conflict (id) do nothing;
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464531b-0000-4000-8000-0000b464531b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bbb-0000-4000-8000-0000b6192bbb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464531d-0000-4000-8000-0000b464531d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464531e-0000-4000-8000-0000b464531e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bbe-0000-4000-8000-0000b6192bbe', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645320-0000-4000-8000-0000b4645320', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645336-0000-4000-8000-0000b4645336', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bd6-0000-4000-8000-0000b6192bd6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645338-0000-4000-8000-0000b4645338', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645339-0000-4000-8000-0000b4645339', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bd9-0000-4000-8000-0000b6192bd9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bda-0000-4000-8000-0000b6192bda', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464533c-0000-4000-8000-0000b464533c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bdc-0000-4000-8000-0000b6192bdc', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bdd-0000-4000-8000-0000b6192bdd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464533f-0000-4000-8000-0000b464533f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bf4-0000-4000-8000-0000b6192bf4', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192bf5-0000-4000-8000-0000b6192bf5', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645357-0000-4000-8000-0000b4645357', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
-- --- persondata_logg: forutsetninger og proberader ---
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('33f7439e-0000-4000-8000-000033f7439e', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde_oppslag', 'nullA', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('33f7439f-0000-4000-8000-000033f7439f', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde_oppslag', 'nullB', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d7-0000-4000-8000-0000a78b10d7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastA1', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d8-0000-4000-8000-0000a78b10d8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastA2', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d9-0000-4000-8000-0000a78b10d9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde_oppslag', 'fastA3', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f6-0000-4000-8000-0000a78b10f6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastB1', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f7-0000-4000-8000-0000a78b10f7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastB2', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
-- --- personlig_kryss: forutsetninger og proberader ---
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', 'e8569e27-0000-4000-8000-0000e8569e27', date '2026-01-01' + 7);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', 'e8569e28-0000-4000-8000-0000e8569e28', date '2026-01-01' + 8);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', 'e8569e29-0000-4000-8000-0000e8569e29', date '2026-01-01' + 9);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '227d262f-0000-4000-8000-0000227d262f', date '2026-01-01' + 10);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '228b3db1-0000-4000-8000-0000228b3db1', date '2026-01-01' + 11);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '228b3db2-0000-4000-8000-0000228b3db2', date '2026-01-01' + 12);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '228b3db3-0000-4000-8000-0000228b3db3', date '2026-01-01' + 13);
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
-- --- plattform_innlegg: forutsetninger og proberader ---
insert into public.plattform_innlegg (id, tittel, innhold, publisert) values ('727ec031-0000-4000-8000-0000727ec031', 'Sondeinnlegg global', 'Sondetekst', true);
insert into public.plattform_innlegg (id, tittel, innhold, publisert) values ('ce74f8a9-0000-4000-8000-0000ce74f8a9', 'Sondeinnlegg usynlig', 'Sondetekst', false);
-- --- produksjonsplan_hode: forutsetninger og proberader ---
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 28);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 29);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 30);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 31);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 32);

create or replace function pg_temp.nyrad_produksjonsplan_hode(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- produksjonsplan_linjer: forutsetninger og proberader ---
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33, 'Sondevare fastA1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34, 'Sondevare fastA2');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 35, 'Sondevare fastA3');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 36, 'Sondevare fastB1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 37, 'Sondevare fastB2');

create or replace function pg_temp.nyrad_produksjonsplan_linjer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sondevare ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- profiler: forutsetninger og proberader ---
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483c79d9-0000-4000-8000-0000483c79d9', 'butikksjef', 'Sondeprofil fastA1');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483cee39-0000-4000-8000-0000483cee39', 'butikksjef', 'Sondeprofil fastA2');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483d62ae-0000-4000-8000-0000483d62ae', 'butikksjef', 'Sondeprofil fastA3');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('bbbb0000-0000-4000-8000-000000000000', '484a9172-0000-4000-8000-0000484a9172', 'butikksjef', 'Sondeprofil fastB1');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('bbbb0000-0000-4000-8000-000000000000', '484b05d2-0000-4000-8000-0000484b05d2', 'butikksjef', 'Sondeprofil fastB2');
-- --- prognose_kalibrering: forutsetninger og proberader ---
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastA1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastA2', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', 'fastA3', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastB1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastB2', 1.05, 30);
-- --- prognose_treff: forutsetninger og proberader ---
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f208589-0000-4000-8000-00009f208589', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 48, 'fastA1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858a-0000-4000-8000-00009f20858a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 49, 'fastA2', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858b-0000-4000-8000-00009f20858b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', date '2026-01-01' + 50, 'fastA3', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a8-0000-4000-8000-00009f2085a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 51, 'fastB1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a9-0000-4000-8000-00009f2085a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 52, 'fastB2', 100, 95);
-- --- puls_runde: forutsetninger og proberader ---
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23494-0000-4000-8000-000047e23494', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60e-0000-4000-8000-00001f2bd60e', 'aaaa0000-0000-4000-8000-000000000000', '47e2a8f4-0000-4000-8000-000047e2a8f4', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60f-0000-4000-8000-00001f2bd60f', 'aaaa0000-0000-4000-8000-000000000000', '47e31d54-0000-4000-8000-000047e31d54', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04c18-0000-4000-8000-000047f04c18', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62d-0000-4000-8000-00001f2bd62d', 'bbbb0000-0000-4000-8000-000000000000', '47f0c078-0000-4000-8000-000047f0c078', date '2026-08-01', date '2026-08-31');

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

-- =====================================================================
-- persondata_logg  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('persondata_logg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('persondata_logg owner_A SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A3 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_A INSERT med manager_A1 sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_Asomannen'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_A INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('persondata_logg manager_A1 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A1 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('persondata_logg manager_A12 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A12 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A12 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_A1 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('persondata_logg owner_B SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT B2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_B INSERT med manager_B1 sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_Bsomannen'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_B INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('persondata_logg manager_B1 SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'negativ');
select pg_temp.paastand('persondata_logg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_B1 INSERT med owner_B sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1somannen'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');
select pg_temp.paastand('persondata_logg manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_B1 INSERT med owner_B sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1somannen'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

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
select pg_temp.skriv_tillatt('personlig_kryss owner_A INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d272c-0000-4000-8000-0000227d272c'', date ''2026-01-01'' + 95)');
select pg_temp.skriv_avvist('personlig_kryss owner_A INSERT paa manager_A1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''227d272d-0000-4000-8000-0000227d272d'', date ''2026-01-01'' + 96)');
select pg_temp.skriv_tillatt('personlig_kryss owner_A UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.skriv_avvist('personlig_kryss owner_A UPDATE manager_A1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_A DELETE manager_A1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_A DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '227d272e-0000-4000-8000-0000227d272e', date '2026-01-01' + 97);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('personlig_kryss manager_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''227d272f-0000-4000-8000-0000227d272f'', date ''2026-01-01'' + 98)');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d2730-0000-4000-8000-0000227d2730'', date ''2026-01-01'' + 99)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '2d279fe1-0000-4000-8000-00002d279fe1', date '2026-01-01' + 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('personlig_kryss manager_A12 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a012'', ''2d279fe2-0000-4000-8000-00002d279fe2'', date ''2026-01-01'' + 101)');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d279fe3-0000-4000-8000-00002d279fe3'', date ''2026-01-01'' + 102)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 DELETE egen rad', 'delete from public.personlig_kryss where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '2d279fe4-0000-4000-8000-00002d279fe4', date '2026-01-01' + 103);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a101'', ''2d279fe5-0000-4000-8000-00002d279fe5'', date ''2026-01-01'' + 104)');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d279fe6-0000-4000-8000-00002d279fe6'', date ''2026-01-01'' + 105)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '2d279fe7-0000-4000-8000-00002d279fe7', date '2026-01-01' + 106);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('personlig_kryss owner_B SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'positiv');
select pg_temp.paastand('personlig_kryss owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss owner_B INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7887-0000-4000-8000-00002edc7887'', date ''2026-01-01'' + 107)');
select pg_temp.skriv_avvist('personlig_kryss owner_B INSERT paa manager_B1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc7888-0000-4000-8000-00002edc7888'', date ''2026-01-01'' + 108)');
select pg_temp.skriv_tillatt('personlig_kryss owner_B UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.skriv_avvist('personlig_kryss owner_B UPDATE manager_B1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_B DELETE manager_B1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_B DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '2edc7889-0000-4000-8000-00002edc7889', date '2026-01-01' + 109);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('personlig_kryss manager_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc789f-0000-4000-8000-00002edc789f'', date ''2026-01-01'' + 110)');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc78a0-0000-4000-8000-00002edc78a0'', date ''2026-01-01'' + 111)');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '2edc78a1-0000-4000-8000-00002edc78a1', date '2026-01-01' + 112);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b101'', ''2edc78a2-0000-4000-8000-00002edc78a2'', date ''2026-01-01'' + 113)');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc78a3-0000-4000-8000-00002edc78a3'', date ''2026-01-01'' + 114)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '2edc78a4-0000-4000-8000-00002edc78a4', date '2026-01-01' + 115);
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
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pin_forsok manager_A1 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pin_forsok manager_A12 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A12A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A12B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pin_forsok tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_A1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pin_forsok owner_B SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok owner_B SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''owner_BB1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''owner_BA1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pin_forsok manager_B1 SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_B1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pin_forsok tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_B1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
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

-- =====================================================================
-- produksjonsplan_hode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_hode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 172)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 173)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 174)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 175)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A UPDATE A2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A UPDATE A3', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 176);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 177);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 178);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_hode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('produksjonsplan_hode manager_A1 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 179)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 180)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 181)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 182)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 UPDATE A2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e3-0000-4000-8000-00003628e8e3''', 'produksjonsplan_hode', '3628e8e3-0000-4000-8000-00003628e8e3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 UPDATE A3', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 183);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''', 'produksjonsplan_hode', '3628e8e3-0000-4000-8000-00003628e8e3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 FLYTTER egen rad A1 -> A2', 'update public.produksjonsplan_hode set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_hode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('produksjonsplan_hode manager_A12 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode manager_A12 SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 184)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 185)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 186)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 187)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 UPDATE A2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 UPDATE A3', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 188);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 189);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 FLYTTER egen rad A1 -> A3', 'update public.produksjonsplan_hode set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_hode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('produksjonsplan_hode tablet_A1 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 190)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 191)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 192)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 193)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 UPDATE A2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e3-0000-4000-8000-00003628e8e3''', 'produksjonsplan_hode', '3628e8e3-0000-4000-8000-00003628e8e3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 UPDATE A3', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''', 'produksjonsplan_hode', '3628e8e3-0000-4000-8000-00003628e8e3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''', 'produksjonsplan_hode', '3628e8e4-0000-4000-8000-00003628e8e4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('produksjonsplan_hode owner_B SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_B SELECT B2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e902-0000-4000-8000-00003628e902'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 194)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 195)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 196)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B UPDATE B2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 197);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 198);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B FLYTTER egen rad -> kjede A', 'update public.produksjonsplan_hode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('produksjonsplan_hode manager_B1 SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e902-0000-4000-8000-00003628e902'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 199)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 200)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 201)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 UPDATE B2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e902-0000-4000-8000-00003628e902''', 'produksjonsplan_hode', '3628e902-0000-4000-8000-00003628e902', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 202);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''', 'produksjonsplan_hode', '3628e902-0000-4000-8000-00003628e902', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 FLYTTER egen rad B1 -> B2', 'update public.produksjonsplan_hode set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 FLYTTER egen rad -> kjede A', 'update public.produksjonsplan_hode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('produksjonsplan_hode tablet_B1 SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e902-0000-4000-8000-00003628e902'), 'negativ');
select pg_temp.paastand('produksjonsplan_hode tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'negativ');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 203)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 204)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 205)');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 UPDATE B1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 UPDATE B2', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e902-0000-4000-8000-00003628e902''', 'produksjonsplan_hode', '3628e902-0000-4000-8000-00003628e902', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 UPDATE A1', 'update public.produksjonsplan_hode set notat = ''endret av sonden'' where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 DELETE B1', 'delete from public.produksjonsplan_hode where id = ''3628e901-0000-4000-8000-00003628e901''', 'produksjonsplan_hode', '3628e901-0000-4000-8000-00003628e901', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''', 'produksjonsplan_hode', '3628e902-0000-4000-8000-00003628e902', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 DELETE A1', 'delete from public.produksjonsplan_hode where id = ''3628e8e2-0000-4000-8000-00003628e8e2''', 'produksjonsplan_hode', '3628e8e2-0000-4000-8000-00003628e8e2', 'id');

-- =====================================================================
-- produksjonsplan_linjer  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_linjer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_linjer owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0801-0000-4000-8000-0000d0ba0801'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0802-0000-4000-8000-0000d0ba0802'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 206, ''Sondevare owner_AA1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 207, ''Sondevare owner_AA2'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 208, ''Sondevare owner_AA3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 209, ''Sondevare owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A UPDATE A2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A UPDATE A3', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 210, 'Sondevare gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 211, 'Sondevare gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 212, 'Sondevare gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_linjer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('produksjonsplan_linjer manager_A1 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0801-0000-4000-8000-0000d0ba0801'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0802-0000-4000-8000-0000d0ba0802'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 213, ''Sondevare manager_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 214, ''Sondevare manager_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 215, ''Sondevare manager_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 216, ''Sondevare manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 UPDATE A2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''', 'produksjonsplan_linjer', 'd0ba0801-0000-4000-8000-0000d0ba0801', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 UPDATE A3', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 217, 'Sondevare gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''', 'produksjonsplan_linjer', 'd0ba0801-0000-4000-8000-0000d0ba0801', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 FLYTTER egen rad A1 -> A2', 'update public.produksjonsplan_linjer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_linjer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('produksjonsplan_linjer manager_A12 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer manager_A12 SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0801-0000-4000-8000-0000d0ba0801'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0802-0000-4000-8000-0000d0ba0802'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 218, ''Sondevare manager_A12A1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 219, ''Sondevare manager_A12A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 220, ''Sondevare manager_A12A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 221, ''Sondevare manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 UPDATE A2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 UPDATE A3', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 222, 'Sondevare gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 223, 'Sondevare gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 FLYTTER egen rad A1 -> A3', 'update public.produksjonsplan_linjer set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_linjer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('produksjonsplan_linjer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0801-0000-4000-8000-0000d0ba0801'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0802-0000-4000-8000-0000d0ba0802'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'negativ');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 224, ''Sondevare tablet_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 225, ''Sondevare tablet_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 226, ''Sondevare tablet_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 227, ''Sondevare tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 UPDATE A2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''', 'produksjonsplan_linjer', 'd0ba0801-0000-4000-8000-0000d0ba0801', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 UPDATE A3', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''', 'produksjonsplan_linjer', 'd0ba0801-0000-4000-8000-0000d0ba0801', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''', 'produksjonsplan_linjer', 'd0ba0802-0000-4000-8000-0000d0ba0802', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT B2 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0820-0000-4000-8000-0000d0ba0820'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 228, ''Sondevare owner_BB1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 229, ''Sondevare owner_BB2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 230, ''Sondevare owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B UPDATE B2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 231, 'Sondevare gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 232, 'Sondevare gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B FLYTTER egen rad -> kjede A', 'update public.produksjonsplan_linjer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('produksjonsplan_linjer manager_B1 SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0820-0000-4000-8000-0000d0ba0820'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 233, ''Sondevare manager_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 234, ''Sondevare manager_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 235, ''Sondevare manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 UPDATE B2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''', 'produksjonsplan_linjer', 'd0ba0820-0000-4000-8000-0000d0ba0820', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 236, 'Sondevare gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''', 'produksjonsplan_linjer', 'd0ba0820-0000-4000-8000-0000d0ba0820', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 FLYTTER egen rad B1 -> B2', 'update public.produksjonsplan_linjer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 FLYTTER egen rad -> kjede A', 'update public.produksjonsplan_linjer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('produksjonsplan_linjer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0820-0000-4000-8000-0000d0ba0820'), 'negativ');
select pg_temp.paastand('produksjonsplan_linjer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'negativ');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 237, ''Sondevare tablet_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 238, ''Sondevare tablet_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 239, ''Sondevare tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 UPDATE B2', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''', 'produksjonsplan_linjer', 'd0ba0820-0000-4000-8000-0000d0ba0820', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 DELETE B1', 'delete from public.produksjonsplan_linjer where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''', 'produksjonsplan_linjer', 'd0ba0820-0000-4000-8000-0000d0ba0820', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 DELETE A1', 'delete from public.produksjonsplan_linjer where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');

-- =====================================================================
-- profiler  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('profiler');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('profiler owner_A SELECT A -> ser', exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'positiv');
select pg_temp.paastand('profiler owner_A SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.skriv_avvist('profiler owner_A INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd3a-0000-4000-8000-0000bf52bd3a'', ''butikksjef'', ''Sondeprofil owner_AA1'')');
select pg_temp.skriv_avvist('profiler owner_A INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795da-0000-4000-8000-0000c10795da'', ''butikksjef'', ''Sondeprofil owner_AB1'')');
select pg_temp.skriv_avvist_pred('profiler owner_A UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler owner_A UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler owner_A DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler owner_A DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('profiler manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.paastand('profiler manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_A1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd3c-0000-4000-8000-0000bf52bd3c'', ''butikksjef'', ''Sondeprofil manager_A1A1'')');
select pg_temp.skriv_avvist('profiler manager_A1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795dc-0000-4000-8000-0000c10795dc'', ''butikksjef'', ''Sondeprofil manager_A1B1'')');
select pg_temp.skriv_avvist_pred('profiler manager_A1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler manager_A1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler manager_A1 DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler manager_A1 DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('profiler manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.paastand('profiler manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_A12 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd3e-0000-4000-8000-0000bf52bd3e'', ''butikksjef'', ''Sondeprofil manager_A12A1'')');
select pg_temp.skriv_avvist('profiler manager_A12 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795de-0000-4000-8000-0000c10795de'', ''butikksjef'', ''Sondeprofil manager_A12B1'')');
select pg_temp.skriv_avvist_pred('profiler manager_A12 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler manager_A12 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler manager_A12 DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler manager_A12 DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('profiler tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.paastand('profiler tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.skriv_avvist('profiler tablet_A1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd40-0000-4000-8000-0000bf52bd40'', ''butikksjef'', ''Sondeprofil tablet_A1A1'')');
select pg_temp.skriv_avvist('profiler tablet_A1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795e0-0000-4000-8000-0000c10795e0'', ''butikksjef'', ''Sondeprofil tablet_A1B1'')');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('profiler owner_B SELECT B -> ser', exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'positiv');
select pg_temp.paastand('profiler owner_B SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.skriv_avvist('profiler owner_B INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795e1-0000-4000-8000-0000c10795e1'', ''butikksjef'', ''Sondeprofil owner_BB1'')');
select pg_temp.skriv_avvist('profiler owner_B INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd43-0000-4000-8000-0000bf52bd43'', ''butikksjef'', ''Sondeprofil owner_BA1'')');
select pg_temp.skriv_avvist_pred('profiler owner_B UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler owner_B UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler owner_B DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler owner_B DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('profiler manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.paastand('profiler manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_B1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795f8-0000-4000-8000-0000c10795f8'', ''butikksjef'', ''Sondeprofil manager_B1B1'')');
select pg_temp.skriv_avvist('profiler manager_B1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd5a-0000-4000-8000-0000bf52bd5a'', ''butikksjef'', ''Sondeprofil manager_B1A1'')');
select pg_temp.skriv_avvist_pred('profiler manager_B1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler manager_B1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler manager_B1 DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler manager_B1 DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('profiler tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9172-0000-4000-8000-0000484a9172'), 'negativ');
select pg_temp.paastand('profiler tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79d9-0000-4000-8000-0000483c79d9'), 'negativ');
select pg_temp.skriv_avvist('profiler tablet_B1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10795fa-0000-4000-8000-0000c10795fa'', ''butikksjef'', ''Sondeprofil tablet_B1B1'')');
select pg_temp.skriv_avvist('profiler tablet_B1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52bd5c-0000-4000-8000-0000bf52bd5c'', ''butikksjef'', ''Sondeprofil tablet_B1A1'')');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 DELETE B', 'delete from public.profiler where "id" = ''484a9172-0000-4000-8000-0000484a9172''', 'profiler', '"id" = ''484a9172-0000-4000-8000-0000484a9172''');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 DELETE A', 'delete from public.profiler where "id" = ''483c79d9-0000-4000-8000-0000483c79d9''', 'profiler', '"id" = ''483c79d9-0000-4000-8000-0000483c79d9''');

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
select pg_temp.skriv_tillatt('puls_runde owner_A INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464531b-0000-4000-8000-0000b464531b'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_A INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bbb-0000-4000-8000-0000b6192bbb'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b464531d-0000-4000-8000-0000b464531d', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde owner_A FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_runde manager_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464531e-0000-4000-8000-0000b464531e'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bbe-0000-4000-8000-0000b6192bbe'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4645320-0000-4000-8000-0000b4645320', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_runde manager_A12 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A12 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4645336-0000-4000-8000-0000b4645336'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A12 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bd6-0000-4000-8000-0000b6192bd6'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4645338-0000-4000-8000-0000b4645338', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_runde tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4645339-0000-4000-8000-0000b4645339'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bd9-0000-4000-8000-0000b6192bd9'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_tillatt('puls_runde owner_B INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bda-0000-4000-8000-0000b6192bda'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_B INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464533c-0000-4000-8000-0000b464533c'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b6192bdc-0000-4000-8000-0000b6192bdc', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde owner_B FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_runde manager_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bdd-0000-4000-8000-0000b6192bdd'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464533f-0000-4000-8000-0000b464533f'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b6192bf4-0000-4000-8000-0000b6192bf4', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_runde tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192bf5-0000-4000-8000-0000b6192bf5'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4645357-0000-4000-8000-0000b4645357'', date ''2026-08-01'', date ''2026-08-31'')');
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
    raise exception 'TENANT-MATRISEN DEL 6/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 6/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
