-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 8. Hele matrisen er for stor for Supabase SQL
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
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e20-0000-4000-8000-0000e8569e20', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 0');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e21-0000-4000-8000-0000e8569e21', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 1');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e22-0000-4000-8000-0000e8569e22', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 2');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8569e23-0000-4000-8000-0000e8569e23', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 3');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8571283-0000-4000-8000-0000e8571283', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 4');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8571284-0000-4000-8000-0000e8571284', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 5');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('e8571285-0000-4000-8000-0000e8571285', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 6');
insert into auth.users (id, email) values ('483c79bb-0000-4000-8000-0000483c79bb', 'sonde-profil-29@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('483cee30-0000-4000-8000-0000483cee30', 'sonde-profil-30@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('483d6290-0000-4000-8000-0000483d6290', 'sonde-profil-31@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('484a9154-0000-4000-8000-0000484a9154', 'sonde-profil-32@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('484b05b4-0000-4000-8000-0000484b05b4', 'sonde-profil-33@kanari.local') on conflict (id) do nothing;
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23476-0000-4000-8000-000047e23476', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2a8d6-0000-4000-8000-000047e2a8d6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e31d36-0000-4000-8000-000047e31d36', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04bfa-0000-4000-8000-000047f04bfa', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f0c05a-0000-4000-8000-000047f0c05a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643f87-0000-4000-8000-00004b643f87', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01688-0000-4000-8000-00002be01688', 'aaaa0000-0000-4000-8000-000000000000', '4b643f87-0000-4000-8000-00004b643f87', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b3e7-0000-4000-8000-00004b64b3e7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08ae8-0000-4000-8000-00002be08ae8', 'aaaa0000-0000-4000-8000-000000000000', '4b64b3e7-0000-4000-8000-00004b64b3e7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b652847-0000-4000-8000-00004b652847', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ff48-0000-4000-8000-00002be0ff48', 'aaaa0000-0000-4000-8000-000000000000', '4b652847-0000-4000-8000-00004b652847', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72570b-0000-4000-8000-00004b72570b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2e0c-0000-4000-8000-00002bee2e0c', 'bbbb0000-0000-4000-8000-000000000000', '4b72570b-0000-4000-8000-00004b72570b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72cb6b-0000-4000-8000-00004b72cb6b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2beea26c-0000-4000-8000-00002beea26c', 'bbbb0000-0000-4000-8000-000000000000', '4b72cb6b-0000-4000-8000-00004b72cb6b', date '2026-08-01', date '2026-08-31');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26b4-0000-4000-8000-0000227d26b4', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 59');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26ca-0000-4000-8000-0000227d26ca', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 60');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26cb-0000-4000-8000-0000227d26cb', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 61');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26cc-0000-4000-8000-0000227d26cc', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 62');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26cd-0000-4000-8000-0000227d26cd', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 63');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26ce-0000-4000-8000-0000227d26ce', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 64');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26cf-0000-4000-8000-0000227d26cf', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 65');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26d0-0000-4000-8000-0000227d26d0', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 66');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26d1-0000-4000-8000-0000227d26d1', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 67');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26d2-0000-4000-8000-0000227d26d2', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 68');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26d3-0000-4000-8000-0000227d26d3', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 69');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d26e9-0000-4000-8000-0000227d26e9', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 70');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e6b-0000-4000-8000-0000228b3e6b', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 71');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e6c-0000-4000-8000-0000228b3e6c', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 72');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e6d-0000-4000-8000-0000228b3e6d', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 73');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e6e-0000-4000-8000-0000228b3e6e', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 74');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e6f-0000-4000-8000-0000228b3e6f', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 75');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e70-0000-4000-8000-0000228b3e70', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 76');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e71-0000-4000-8000-0000228b3e71', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 77');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e72-0000-4000-8000-0000228b3e72', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 78');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3e73-0000-4000-8000-0000228b3e73', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 79');
insert into auth.users (id, email) values ('bf52b9f8-0000-4000-8000-0000bf52b9f8', 'sonde-profil-183@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c1079298-0000-4000-8000-0000c1079298', 'sonde-profil-184@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52b9fa-0000-4000-8000-0000bf52b9fa', 'sonde-profil-185@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c107929a-0000-4000-8000-0000c107929a', 'sonde-profil-186@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52b9fc-0000-4000-8000-0000bf52b9fc', 'sonde-profil-187@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c107929c-0000-4000-8000-0000c107929c', 'sonde-profil-188@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52b9fe-0000-4000-8000-0000bf52b9fe', 'sonde-profil-189@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10792b3-0000-4000-8000-0000c10792b3', 'sonde-profil-190@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10792b4-0000-4000-8000-0000c10792b4', 'sonde-profil-191@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52ba16-0000-4000-8000-0000bf52ba16', 'sonde-profil-192@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10792b6-0000-4000-8000-0000c10792b6', 'sonde-profil-193@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52ba18-0000-4000-8000-0000bf52ba18', 'sonde-profil-194@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('c10792b8-0000-4000-8000-0000c10792b8', 'sonde-profil-195@kanari.local') on conflict (id) do nothing;
insert into auth.users (id, email) values ('bf52ba1a-0000-4000-8000-0000bf52ba1a', 'sonde-profil-196@kanari.local') on conflict (id) do nothing;
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644fd9-0000-4000-8000-0000b4644fd9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192879-0000-4000-8000-0000b6192879', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644fdb-0000-4000-8000-0000b4644fdb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464527c-0000-4000-8000-0000b464527c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b1c-0000-4000-8000-0000b6192b1c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464527e-0000-4000-8000-0000b464527e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464527f-0000-4000-8000-0000b464527f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b1f-0000-4000-8000-0000b6192b1f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645281-0000-4000-8000-0000b4645281', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645282-0000-4000-8000-0000b4645282', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b22-0000-4000-8000-0000b6192b22', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b23-0000-4000-8000-0000b6192b23', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4645285-0000-4000-8000-0000b4645285', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b3a-0000-4000-8000-0000b6192b3a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b3b-0000-4000-8000-0000b6192b3b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b464529d-0000-4000-8000-0000b464529d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b3d-0000-4000-8000-0000b6192b3d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192b3e-0000-4000-8000-0000b6192b3e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b46452a0-0000-4000-8000-0000b46452a0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a62c-0000-4000-8000-00002123a62c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af4b-0000-4000-8000-00005022af4b', 'aaaa0000-0000-4000-8000-000000000000', '2123a62c-0000-4000-8000-00002123a62c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdae-0000-4000-8000-00002131bdae', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6cd-0000-4000-8000-00005030c6cd', 'aaaa0000-0000-4000-8000-000000000000', '2131bdae-0000-4000-8000-00002131bdae', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd530-0000-4000-8000-0000213fd530', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede4f-0000-4000-8000-0000503ede4f', 'aaaa0000-0000-4000-8000-000000000000', '213fd530-0000-4000-8000-0000213fd530', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ece-0000-4000-8000-000022d87ece', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787ed-0000-4000-8000-000051d787ed', 'bbbb0000-0000-4000-8000-000000000000', '22d87ece-0000-4000-8000-000022d87ece', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a630-0000-4000-8000-00002123a630', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af4f-0000-4000-8000-00005022af4f', 'aaaa0000-0000-4000-8000-000000000000', '2123a630-0000-4000-8000-00002123a630', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdc7-0000-4000-8000-00002131bdc7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6e6-0000-4000-8000-00005030c6e6', 'aaaa0000-0000-4000-8000-000000000000', '2131bdc7-0000-4000-8000-00002131bdc7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd549-0000-4000-8000-0000213fd549', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede68-0000-4000-8000-0000503ede68', 'aaaa0000-0000-4000-8000-000000000000', '213fd549-0000-4000-8000-0000213fd549', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ee7-0000-4000-8000-000022d87ee7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78806-0000-4000-8000-000051d78806', 'bbbb0000-0000-4000-8000-000000000000', '22d87ee7-0000-4000-8000-000022d87ee7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a649-0000-4000-8000-00002123a649', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af68-0000-4000-8000-00005022af68', 'aaaa0000-0000-4000-8000-000000000000', '2123a649-0000-4000-8000-00002123a649', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdcb-0000-4000-8000-00002131bdcb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6ea-0000-4000-8000-00005030c6ea', 'aaaa0000-0000-4000-8000-000000000000', '2131bdcb-0000-4000-8000-00002131bdcb', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd54d-0000-4000-8000-0000213fd54d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede6c-0000-4000-8000-0000503ede6c', 'aaaa0000-0000-4000-8000-000000000000', '213fd54d-0000-4000-8000-0000213fd54d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87eeb-0000-4000-8000-000022d87eeb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d7880a-0000-4000-8000-000051d7880a', 'bbbb0000-0000-4000-8000-000000000000', '22d87eeb-0000-4000-8000-000022d87eeb', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a64d-0000-4000-8000-00002123a64d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af6c-0000-4000-8000-00005022af6c', 'aaaa0000-0000-4000-8000-000000000000', '2123a64d-0000-4000-8000-00002123a64d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdcf-0000-4000-8000-00002131bdcf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6ee-0000-4000-8000-00005030c6ee', 'aaaa0000-0000-4000-8000-000000000000', '2131bdcf-0000-4000-8000-00002131bdcf', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd551-0000-4000-8000-0000213fd551', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede70-0000-4000-8000-0000503ede70', 'aaaa0000-0000-4000-8000-000000000000', '213fd551-0000-4000-8000-0000213fd551', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87f04-0000-4000-8000-000022d87f04', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78823-0000-4000-8000-000051d78823', 'bbbb0000-0000-4000-8000-000000000000', '22d87f04-0000-4000-8000-000022d87f04', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87f05-0000-4000-8000-000022d87f05', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78824-0000-4000-8000-000051d78824', 'bbbb0000-0000-4000-8000-000000000000', '22d87f05-0000-4000-8000-000022d87f05', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69687-0000-4000-8000-000022e69687', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59fa6-0000-4000-8000-000051e59fa6', 'bbbb0000-0000-4000-8000-000000000000', '22e69687-0000-4000-8000-000022e69687', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a668-0000-4000-8000-00002123a668', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af87-0000-4000-8000-00005022af87', 'aaaa0000-0000-4000-8000-000000000000', '2123a668-0000-4000-8000-00002123a668', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87f08-0000-4000-8000-000022d87f08', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78827-0000-4000-8000-000051d78827', 'bbbb0000-0000-4000-8000-000000000000', '22d87f08-0000-4000-8000-000022d87f08', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6968a-0000-4000-8000-000022e6968a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59fa9-0000-4000-8000-000051e59fa9', 'bbbb0000-0000-4000-8000-000000000000', '22e6968a-0000-4000-8000-000022e6968a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a66b-0000-4000-8000-00002123a66b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af8a-0000-4000-8000-00005022af8a', 'aaaa0000-0000-4000-8000-000000000000', '2123a66b-0000-4000-8000-00002123a66b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87f0b-0000-4000-8000-000022d87f0b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d7882a-0000-4000-8000-000051d7882a', 'bbbb0000-0000-4000-8000-000000000000', '22d87f0b-0000-4000-8000-000022d87f0b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6968d-0000-4000-8000-000022e6968d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59fac-0000-4000-8000-000051e59fac', 'bbbb0000-0000-4000-8000-000000000000', '22e6968d-0000-4000-8000-000022e6968d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a66e-0000-4000-8000-00002123a66e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af8d-0000-4000-8000-00005022af8d', 'aaaa0000-0000-4000-8000-000000000000', '2123a66e-0000-4000-8000-00002123a66e', date '2026-08-01', date '2026-08-31');
-- --- personlig_kryss: forutsetninger og proberader ---
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', 'e8569e20-0000-4000-8000-0000e8569e20', date '2026-01-01' + 0);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', 'e8569e21-0000-4000-8000-0000e8569e21', date '2026-01-01' + 1);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', 'e8569e22-0000-4000-8000-0000e8569e22', date '2026-01-01' + 2);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', 'e8569e23-0000-4000-8000-0000e8569e23', date '2026-01-01' + 3);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', 'e8571283-0000-4000-8000-0000e8571283', date '2026-01-01' + 4);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', 'e8571284-0000-4000-8000-0000e8571284', date '2026-01-01' + 5);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', 'e8571285-0000-4000-8000-0000e8571285', date '2026-01-01' + 6);
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
-- --- produksjonsplan_hode: forutsetninger og proberader ---
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 19);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 20);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 21);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 22);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 23);

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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 24, 'Sondevare fastA1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 25, 'Sondevare fastA2');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 26, 'Sondevare fastA3');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 27, 'Sondevare fastB1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 28, 'Sondevare fastB2');

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
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483c79bb-0000-4000-8000-0000483c79bb', 'butikksjef', 'Sondeprofil fastA1');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483cee30-0000-4000-8000-0000483cee30', 'butikksjef', 'Sondeprofil fastA2');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('aaaa0000-0000-4000-8000-000000000000', '483d6290-0000-4000-8000-0000483d6290', 'butikksjef', 'Sondeprofil fastA3');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('bbbb0000-0000-4000-8000-000000000000', '484a9154-0000-4000-8000-0000484a9154', 'butikksjef', 'Sondeprofil fastB1');
insert into public.profiler (retailer_id, id, rolle, fullt_navn) values ('bbbb0000-0000-4000-8000-000000000000', '484b05b4-0000-4000-8000-0000484b05b4', 'butikksjef', 'Sondeprofil fastB2');

create or replace function pg_temp.nyrad_profiler(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
  v_bruker uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_bruker, 'sonde-profil-' || 'rt' || nextval('tenant_teller'::regclass) || '@kanari.local') on conflict (id) do nothing;
  insert into public.profiler (retailer_id, id, rolle, fullt_navn)
  values (p_retailer, v_bruker, 'butikksjef', 'Sondeprofil ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '');
end $fn$;
-- --- prognose_kalibrering: forutsetninger og proberader ---
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastA1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastA2', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', 'fastA3', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastB1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastB2', 1.05, 30);
-- --- prognose_treff: forutsetninger og proberader ---
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f208589-0000-4000-8000-00009f208589', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 39, 'fastA1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858a-0000-4000-8000-00009f20858a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 40, 'fastA2', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858b-0000-4000-8000-00009f20858b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', date '2026-01-01' + 41, 'fastA3', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a8-0000-4000-8000-00009f2085a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 42, 'fastB1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a9-0000-4000-8000-00009f2085a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 43, 'fastB2', 100, 95);
-- --- puls_runde: forutsetninger og proberader ---
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23476-0000-4000-8000-000047e23476', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60e-0000-4000-8000-00001f2bd60e', 'aaaa0000-0000-4000-8000-000000000000', '47e2a8d6-0000-4000-8000-000047e2a8d6', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60f-0000-4000-8000-00001f2bd60f', 'aaaa0000-0000-4000-8000-000000000000', '47e31d36-0000-4000-8000-000047e31d36', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04bfa-0000-4000-8000-000047f04bfa', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62d-0000-4000-8000-00001f2bd62d', 'bbbb0000-0000-4000-8000-000000000000', '47f0c05a-0000-4000-8000-000047f0c05a', date '2026-08-01', date '2026-08-31');

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
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575b-0000-4000-8000-00003922575b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '2be01688-0000-4000-8000-00002be01688', 3, 'Sondesvar fastA1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575c-0000-4000-8000-00003922575c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '2be08ae8-0000-4000-8000-00002be08ae8', 3, 'Sondesvar fastA2');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575d-0000-4000-8000-00003922575d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '2be0ff48-0000-4000-8000-00002be0ff48', 3, 'Sondesvar fastA3');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577a-0000-4000-8000-00003922577a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '2bee2e0c-0000-4000-8000-00002bee2e0c', 3, 'Sondesvar fastB1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577b-0000-4000-8000-00003922577b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '2beea26c-0000-4000-8000-00002beea26c', 3, 'Sondesvar fastB2');

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
select pg_temp.skriv_tillatt('personlig_kryss owner_A INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d26b4-0000-4000-8000-0000227d26b4'', date ''2026-01-01'' + 59)');
select pg_temp.skriv_avvist('personlig_kryss owner_A INSERT paa manager_A1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''227d26ca-0000-4000-8000-0000227d26ca'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_tillatt('personlig_kryss owner_A UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.skriv_avvist('personlig_kryss owner_A UPDATE manager_A1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_A DELETE manager_A1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_A DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '227d26cb-0000-4000-8000-0000227d26cb', date '2026-01-01' + 61);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('personlig_kryss manager_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''227d26cc-0000-4000-8000-0000227d26cc'', date ''2026-01-01'' + 62)');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d26cd-0000-4000-8000-0000227d26cd'', date ''2026-01-01'' + 63)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '227d26ce-0000-4000-8000-0000227d26ce', date '2026-01-01' + 64);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('personlig_kryss manager_A12 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a012'', ''227d26cf-0000-4000-8000-0000227d26cf'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d26d0-0000-4000-8000-0000227d26d0'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 DELETE egen rad', 'delete from public.personlig_kryss where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '227d26d1-0000-4000-8000-0000227d26d1', date '2026-01-01' + 67);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a101'', ''227d26d2-0000-4000-8000-0000227d26d2'', date ''2026-01-01'' + 68)');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''227d26d3-0000-4000-8000-0000227d26d3'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '227d26e9-0000-4000-8000-0000227d26e9', date '2026-01-01' + 70);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('personlig_kryss owner_B SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'positiv');
select pg_temp.paastand('personlig_kryss owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss owner_B INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''228b3e6b-0000-4000-8000-0000228b3e6b'', date ''2026-01-01'' + 71)');
select pg_temp.skriv_avvist('personlig_kryss owner_B INSERT paa manager_B1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''228b3e6c-0000-4000-8000-0000228b3e6c'', date ''2026-01-01'' + 72)');
select pg_temp.skriv_tillatt('personlig_kryss owner_B UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.skriv_avvist('personlig_kryss owner_B UPDATE manager_B1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_B DELETE manager_B1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_B DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '228b3e6d-0000-4000-8000-0000228b3e6d', date '2026-01-01' + 73);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('personlig_kryss manager_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''228b3e6e-0000-4000-8000-0000228b3e6e'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''228b3e6f-0000-4000-8000-0000228b3e6f'', date ''2026-01-01'' + 75)');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '228b3e70-0000-4000-8000-0000228b3e70', date '2026-01-01' + 76);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b101'', ''228b3e71-0000-4000-8000-0000228b3e71'', date ''2026-01-01'' + 77)');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''228b3e72-0000-4000-8000-0000228b3e72'', date ''2026-01-01'' + 78)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '228b3e73-0000-4000-8000-0000228b3e73', date '2026-01-01' + 79);
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
-- produksjonsplan_hode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_hode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 115)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 116)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 117)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 118)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 119);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 120);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 121);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 122)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 123)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 124)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 125)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 126);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 127)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 128)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 129)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 130)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 131);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 132);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 133)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 134)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 135)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 136)');
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 137)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 138)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 139)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 140);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 141);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 142)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 143)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 144)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 145);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 146)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 147)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 148)');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 149, ''Sondevare owner_AA1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 150, ''Sondevare owner_AA2'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 151, ''Sondevare owner_AA3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 152, ''Sondevare owner_AB1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 153, 'Sondevare gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 154, 'Sondevare gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 155, 'Sondevare gjenowner_AA3');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 156, ''Sondevare manager_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 157, ''Sondevare manager_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 158, ''Sondevare manager_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 159, ''Sondevare manager_A1B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 160, 'Sondevare gjenmanager_A1A1');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 161, ''Sondevare manager_A12A1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 162, ''Sondevare manager_A12A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 163, ''Sondevare manager_A12A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 164, ''Sondevare manager_A12B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 165, 'Sondevare gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 166, 'Sondevare gjenmanager_A12A2');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 167, ''Sondevare tablet_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 168, ''Sondevare tablet_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 169, ''Sondevare tablet_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 170, ''Sondevare tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('produksjonsplan_linjer tablet_A1 UPDATE A1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.produksjonsplan_linjer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 FLYTTER egen rad -> kjede B', 'update public.produksjonsplan_linjer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0ba0800-0000-4000-8000-0000d0ba0800''', 'produksjonsplan_linjer', 'd0ba0800-0000-4000-8000-0000d0ba0800', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT B1 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba081f-0000-4000-8000-0000d0ba081f'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT B2 -> ser', exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0820-0000-4000-8000-0000d0ba0820'), 'positiv');
select pg_temp.paastand('produksjonsplan_linjer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.produksjonsplan_linjer where id = 'd0ba0800-0000-4000-8000-0000d0ba0800'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 171, ''Sondevare owner_BB1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 172, ''Sondevare owner_BB2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 173, ''Sondevare owner_BA1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 174, 'Sondevare gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 175, 'Sondevare gjenowner_BB2');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 176, ''Sondevare manager_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 177, ''Sondevare manager_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 178, ''Sondevare manager_B1A1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 179, 'Sondevare gjenmanager_B1B1');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 180, ''Sondevare tablet_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 181, ''Sondevare tablet_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 182, ''Sondevare tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('produksjonsplan_linjer tablet_B1 UPDATE B1', 'update public.produksjonsplan_linjer set lagd_hittil = 1 where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.produksjonsplan_linjer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 FLYTTER egen rad -> kjede A', 'update public.produksjonsplan_linjer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0ba081f-0000-4000-8000-0000d0ba081f''', 'produksjonsplan_linjer', 'd0ba081f-0000-4000-8000-0000d0ba081f', 'id');

-- =====================================================================
-- profiler  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('profiler');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('profiler owner_A SELECT A -> ser', exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'positiv');
select pg_temp.paastand('profiler owner_A SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.skriv_avvist('profiler owner_A INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52b9f8-0000-4000-8000-0000bf52b9f8'', ''butikksjef'', ''Sondeprofil owner_AA1'')');
select pg_temp.skriv_avvist('profiler owner_A INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c1079298-0000-4000-8000-0000c1079298'', ''butikksjef'', ''Sondeprofil owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('profiler owner_A UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('profiler owner_A UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('profiler owner_A DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('profiler owner_A DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('profiler manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.paastand('profiler manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_A1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52b9fa-0000-4000-8000-0000bf52b9fa'', ''butikksjef'', ''Sondeprofil manager_A1A1'')');
select pg_temp.skriv_avvist('profiler manager_A1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c107929a-0000-4000-8000-0000c107929a'', ''butikksjef'', ''Sondeprofil manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('profiler manager_A1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('profiler manager_A1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('profiler manager_A1 DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('profiler manager_A1 DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('profiler manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.paastand('profiler manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_A12 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52b9fc-0000-4000-8000-0000bf52b9fc'', ''butikksjef'', ''Sondeprofil manager_A12A1'')');
select pg_temp.skriv_avvist('profiler manager_A12 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c107929c-0000-4000-8000-0000c107929c'', ''butikksjef'', ''Sondeprofil manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('profiler manager_A12 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('profiler manager_A12 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('profiler manager_A12 DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('profiler manager_A12 DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('profiler tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.paastand('profiler tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.skriv_avvist('profiler tablet_A1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52b9fe-0000-4000-8000-0000bf52b9fe'', ''butikksjef'', ''Sondeprofil tablet_A1A1'')');
select pg_temp.skriv_avvist('profiler tablet_A1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10792b3-0000-4000-8000-0000c10792b3'', ''butikksjef'', ''Sondeprofil tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('profiler tablet_A1 DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('profiler owner_B SELECT B -> ser', exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'positiv');
select pg_temp.paastand('profiler owner_B SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.skriv_avvist('profiler owner_B INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10792b4-0000-4000-8000-0000c10792b4'', ''butikksjef'', ''Sondeprofil owner_BB1'')');
select pg_temp.skriv_avvist('profiler owner_B INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52ba16-0000-4000-8000-0000bf52ba16'', ''butikksjef'', ''Sondeprofil owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('profiler owner_B UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('profiler owner_B UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('profiler owner_B DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('profiler owner_B DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('profiler manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.paastand('profiler manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.skriv_avvist('profiler manager_B1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10792b6-0000-4000-8000-0000c10792b6'', ''butikksjef'', ''Sondeprofil manager_B1B1'')');
select pg_temp.skriv_avvist('profiler manager_B1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52ba18-0000-4000-8000-0000bf52ba18'', ''butikksjef'', ''Sondeprofil manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('profiler manager_B1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('profiler manager_B1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('profiler manager_B1 DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('profiler manager_B1 DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('profiler tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.profiler where "id" = '484a9154-0000-4000-8000-0000484a9154'), 'negativ');
select pg_temp.paastand('profiler tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.profiler where "id" = '483c79bb-0000-4000-8000-0000483c79bb'), 'negativ');
select pg_temp.skriv_avvist('profiler tablet_B1 INSERT B', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''c10792b8-0000-4000-8000-0000c10792b8'', ''butikksjef'', ''Sondeprofil tablet_B1B1'')');
select pg_temp.skriv_avvist('profiler tablet_B1 INSERT A', 'insert into public.profiler (retailer_id, id, rolle, fullt_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''bf52ba1a-0000-4000-8000-0000bf52ba1a'', ''butikksjef'', ''Sondeprofil tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 UPDATE B', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 UPDATE A', 'update public.profiler set fullt_navn = ''endret av sonden'' where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 DELETE B', 'delete from public.profiler where "id" = ''484a9154-0000-4000-8000-0000484a9154''', 'profiler', '"id" = ''484a9154-0000-4000-8000-0000484a9154''');
select pg_temp.som_eier();
select pg_temp.nyrad_profiler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('profiler tablet_B1 DELETE A', 'delete from public.profiler where "id" = ''483c79bb-0000-4000-8000-0000483c79bb''', 'profiler', '"id" = ''483c79bb-0000-4000-8000-0000483c79bb''');

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
select pg_temp.skriv_tillatt('puls_runde owner_A INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644fd9-0000-4000-8000-0000b4644fd9'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_A INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192879-0000-4000-8000-0000b6192879'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4644fdb-0000-4000-8000-0000b4644fdb', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde owner_A FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_runde manager_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464527c-0000-4000-8000-0000b464527c'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b1c-0000-4000-8000-0000b6192b1c'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b464527e-0000-4000-8000-0000b464527e', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_runde manager_A12 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A12 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464527f-0000-4000-8000-0000b464527f'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A12 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b1f-0000-4000-8000-0000b6192b1f'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4645281-0000-4000-8000-0000b4645281', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_runde tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4645282-0000-4000-8000-0000b4645282'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b22-0000-4000-8000-0000b6192b22'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_tillatt('puls_runde owner_B INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b23-0000-4000-8000-0000b6192b23'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_B INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4645285-0000-4000-8000-0000b4645285'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b6192b3a-0000-4000-8000-0000b6192b3a', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde owner_B FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_runde manager_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b3b-0000-4000-8000-0000b6192b3b'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b464529d-0000-4000-8000-0000b464529d'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b6192b3d-0000-4000-8000-0000b6192b3d', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_runde tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192b3e-0000-4000-8000-0000b6192b3e'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b46452a0-0000-4000-8000-0000b46452a0'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af4b-0000-4000-8000-00005022af4b'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6cd-0000-4000-8000-00005030c6cd'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede4f-0000-4000-8000-0000503ede4f'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787ed-0000-4000-8000-000051d787ed'', 3, ''Sondesvar owner_AB1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af4f-0000-4000-8000-00005022af4f'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6e6-0000-4000-8000-00005030c6e6'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede68-0000-4000-8000-0000503ede68'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78806-0000-4000-8000-000051d78806'', 3, ''Sondesvar manager_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af68-0000-4000-8000-00005022af68'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6ea-0000-4000-8000-00005030c6ea'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede6c-0000-4000-8000-0000503ede6c'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d7880a-0000-4000-8000-000051d7880a'', 3, ''Sondesvar manager_A12B1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af6c-0000-4000-8000-00005022af6c'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6ee-0000-4000-8000-00005030c6ee'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede70-0000-4000-8000-0000503ede70'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78823-0000-4000-8000-000051d78823'', 3, ''Sondesvar tablet_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78824-0000-4000-8000-000051d78824'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59fa6-0000-4000-8000-000051e59fa6'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af87-0000-4000-8000-00005022af87'', 3, ''Sondesvar owner_BA1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78827-0000-4000-8000-000051d78827'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59fa9-0000-4000-8000-000051e59fa9'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af8a-0000-4000-8000-00005022af8a'', 3, ''Sondesvar manager_B1A1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d7882a-0000-4000-8000-000051d7882a'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59fac-0000-4000-8000-000051e59fac'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af8d-0000-4000-8000-00005022af8d'', 3, ''Sondesvar tablet_B1A1'')');
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
    raise exception 'TENANT-MATRISEN DEL 5/8: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/8: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
