-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 2 AV 8. Hele matrisen er for stor for Supabase SQL
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
insert into auth.users (id, email) values ('57fa7205-0000-4000-8000-000057fa7205', 'sonde-25@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7205-0000-4000-8000-000057fa7205', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 25');
insert into auth.users (id, email) values ('57fae665-0000-4000-8000-000057fae665', 'sonde-26@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae665-0000-4000-8000-000057fae665', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 26');
insert into auth.users (id, email) values ('57fb5ac5-0000-4000-8000-000057fb5ac5', 'sonde-27@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5ac5-0000-4000-8000-000057fb5ac5', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 27');
insert into auth.users (id, email) values ('58088989-0000-4000-8000-000058088989', 'sonde-28@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('58088989-0000-4000-8000-000058088989', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 28');
insert into auth.users (id, email) values ('5808fde9-0000-4000-8000-00005808fde9', 'sonde-29@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('5808fde9-0000-4000-8000-00005808fde9', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 29');
insert into auth.users (id, email) values ('a753ced1-0000-4000-8000-0000a753ced1', 'sonde-256@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ced1-0000-4000-8000-0000a753ced1', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 256');
insert into auth.users (id, email) values ('a761e653-0000-4000-8000-0000a761e653', 'sonde-257@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e653-0000-4000-8000-0000a761e653', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 257');
insert into auth.users (id, email) values ('a76ffdd5-0000-4000-8000-0000a76ffdd5', 'sonde-258@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffdd5-0000-4000-8000-0000a76ffdd5', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 258');
insert into auth.users (id, email) values ('a908a773-0000-4000-8000-0000a908a773', 'sonde-259@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a773-0000-4000-8000-0000a908a773', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 259');
insert into auth.users (id, email) values ('a753ceea-0000-4000-8000-0000a753ceea', 'sonde-260@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ceea-0000-4000-8000-0000a753ceea', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 260');
insert into auth.users (id, email) values ('a761e66c-0000-4000-8000-0000a761e66c', 'sonde-261@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e66c-0000-4000-8000-0000a761e66c', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 261');
insert into auth.users (id, email) values ('a76ffdee-0000-4000-8000-0000a76ffdee', 'sonde-262@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffdee-0000-4000-8000-0000a76ffdee', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 262');
insert into auth.users (id, email) values ('a908a78c-0000-4000-8000-0000a908a78c', 'sonde-263@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a78c-0000-4000-8000-0000a908a78c', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 263');
insert into auth.users (id, email) values ('a753ceee-0000-4000-8000-0000a753ceee', 'sonde-264@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ceee-0000-4000-8000-0000a753ceee', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 264');
insert into auth.users (id, email) values ('a761e670-0000-4000-8000-0000a761e670', 'sonde-265@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e670-0000-4000-8000-0000a761e670', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 265');
insert into auth.users (id, email) values ('a76ffdf2-0000-4000-8000-0000a76ffdf2', 'sonde-266@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffdf2-0000-4000-8000-0000a76ffdf2', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 266');
insert into auth.users (id, email) values ('a908a790-0000-4000-8000-0000a908a790', 'sonde-267@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a790-0000-4000-8000-0000a908a790', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 267');
insert into auth.users (id, email) values ('a753cef2-0000-4000-8000-0000a753cef2', 'sonde-268@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753cef2-0000-4000-8000-0000a753cef2', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 268');
insert into auth.users (id, email) values ('a761e674-0000-4000-8000-0000a761e674', 'sonde-269@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e674-0000-4000-8000-0000a761e674', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 269');
insert into auth.users (id, email) values ('a76ffe0b-0000-4000-8000-0000a76ffe0b', 'sonde-270@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffe0b-0000-4000-8000-0000a76ffe0b', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 270');
insert into auth.users (id, email) values ('a908a7a9-0000-4000-8000-0000a908a7a9', 'sonde-271@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a7a9-0000-4000-8000-0000a908a7a9', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 271');
insert into auth.users (id, email) values ('a908a7aa-0000-4000-8000-0000a908a7aa', 'sonde-272@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a7aa-0000-4000-8000-0000a908a7aa', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 272');
insert into auth.users (id, email) values ('a916bf2c-0000-4000-8000-0000a916bf2c', 'sonde-273@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916bf2c-0000-4000-8000-0000a916bf2c', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 273');
insert into auth.users (id, email) values ('a753cf0d-0000-4000-8000-0000a753cf0d', 'sonde-274@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753cf0d-0000-4000-8000-0000a753cf0d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 274');
insert into auth.users (id, email) values ('a908a7ad-0000-4000-8000-0000a908a7ad', 'sonde-275@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a7ad-0000-4000-8000-0000a908a7ad', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 275');
insert into auth.users (id, email) values ('a916bf2f-0000-4000-8000-0000a916bf2f', 'sonde-276@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916bf2f-0000-4000-8000-0000a916bf2f', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 276');
insert into auth.users (id, email) values ('a753cf10-0000-4000-8000-0000a753cf10', 'sonde-277@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753cf10-0000-4000-8000-0000a753cf10', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 277');
insert into auth.users (id, email) values ('a908a7b0-0000-4000-8000-0000a908a7b0', 'sonde-278@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a7b0-0000-4000-8000-0000a908a7b0', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 278');
insert into auth.users (id, email) values ('a916bf32-0000-4000-8000-0000a916bf32', 'sonde-279@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916bf32-0000-4000-8000-0000a916bf32', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 279');
insert into auth.users (id, email) values ('a753cf28-0000-4000-8000-0000a753cf28', 'sonde-280@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753cf28-0000-4000-8000-0000a753cf28', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 280');
-- --- bemanning_fravaer: forutsetninger og proberader ---
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 0, date '2026-01-01' + 0, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 1, date '2026-01-01' + 1, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 2, date '2026-01-01' + 2, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 3, date '2026-01-01' + 3, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 4, date '2026-01-01' + 4, 'Sonde');

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
-- --- bemanning_krav: forutsetninger og proberader ---
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde fastA1');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde fastA2');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a6-0000-4000-8000-00005dec22a6', 'a1110000-0000-4000-8000-000000000003', 2, 8, 10, 2, 'Sonde fastA3');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde fastB1');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c4-0000-4000-8000-00005dec22c4', 'b1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde fastB2');

create or replace function pg_temp.nyrad_bemanning_krav(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse)
  values (p_stasjon, 2, 8, 10, 2, 'Sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_maned: forutsetninger og proberader ---
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
-- --- bemanning_stasjon: forutsetninger og proberader ---
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
-- --- bemanning_vindu: forutsetninger og proberader ---
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 20, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 21, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 22, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 23, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 24, 6, 22, 1);

create or replace function pg_temp.nyrad_bemanning_vindu(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning)
  values (p_stasjon, 1, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 6, 22, 1)
  returning id into ny;
  return ny;
end $fn$;
-- --- butikksjef_stasjoner: forutsetninger og proberader ---
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', '57fa7205-0000-4000-8000-000057fa7205');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', '57fae665-0000-4000-8000-000057fae665');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', '57fb5ac5-0000-4000-8000-000057fb5ac5');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', '58088989-0000-4000-8000-000058088989');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', '5808fde9-0000-4000-8000-00005808fde9');

create or replace function pg_temp.nyrad_butikksjef_stasjoner(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
  v_profil uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_profil, 'sonde-' || 'rt' || nextval('tenant_teller'::regclass) || '@kanari.local') on conflict (id) do nothing;
  insert into public.profiler (id, retailer_id, rolle, fullt_navn) values (v_profil, p_retailer, 'butikksjef', 'Sondesjef ' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.butikksjef_stasjoner (stasjon_id, profil_id)
  values (p_stasjon, v_profil);
end $fn$;
-- --- daglig_salg: forutsetninger og proberader ---
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30, 'fastA1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31, 'fastA2', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 32, 'fastA3', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33, 'fastB1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34, 'fastB2', 'Sondevare', 100);

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
-- --- fokuspunkter: forutsetninger og proberader ---
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 'forbedring', 'Sondepunkt fastA1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 'forbedring', 'Sondepunkt fastA2');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 37, 'forbedring', 'Sondepunkt fastA3');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 38, 'forbedring', 'Sondepunkt fastB1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 39, 'forbedring', 'Sondepunkt fastB2');

create or replace function pg_temp.nyrad_fokuspunkter(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'forbedring', 'Sondepunkt ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- bemanning_fravaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fravaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 40, date ''2026-01-01'' + 40, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 41, date ''2026-01-01'' + 41, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 42, date ''2026-01-01'' + 42, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 43, date ''2026-01-01'' + 43, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 44, date '2026-01-01' + 44, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 45, date '2026-01-01' + 45, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 46, date '2026-01-01' + 46, 'Sonde');
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
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 47, date ''2026-01-01'' + 47, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 48, date ''2026-01-01'' + 48, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 49, date ''2026-01-01'' + 49, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 50, date ''2026-01-01'' + 50, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 51, date '2026-01-01' + 51, 'Sonde');
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
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 52, date ''2026-01-01'' + 52, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 53, date ''2026-01-01'' + 53, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 54, date ''2026-01-01'' + 54, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 55, date ''2026-01-01'' + 55, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 56, date '2026-01-01' + 56, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 57, date '2026-01-01' + 57, 'Sonde');
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
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 58, date ''2026-01-01'' + 58, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 59, date ''2026-01-01'' + 59, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 60, date ''2026-01-01'' + 60, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 61, date ''2026-01-01'' + 61, ''Sonde'')');
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
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 62, date ''2026-01-01'' + 62, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 63, date ''2026-01-01'' + 63, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 64, date ''2026-01-01'' + 64, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 65, date '2026-01-01' + 65, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 66, date '2026-01-01' + 66, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 67, date ''2026-01-01'' + 67, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 68, date ''2026-01-01'' + 68, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 69, date ''2026-01-01'' + 69, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 70, date '2026-01-01' + 70, 'Sonde');
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
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 71, date ''2026-01-01'' + 71, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 72, date ''2026-01-01'' + 72, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 73, date ''2026-01-01'' + 73, ''Sonde'')');
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
-- bemanning_krav  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_krav');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_krav owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_AA1'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde owner_AA2'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde owner_AA3'')');
select pg_temp.skriv_avvist('bemanning_krav owner_A INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_krav owner_A UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a6-0000-4000-8000-00005dec22a6', 'a1110000-0000-4000-8000-000000000003', 2, 8, 10, 2, 'Sonde gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_krav owner_A DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A1A1'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_A1A2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde manager_A1A3'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_krav set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A12A1'')');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_A12A2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde manager_A12A3'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_krav set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_A1A1'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde tablet_A1A2'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde tablet_A1A3'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_krav owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav owner_B INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_BB1'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_B INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde owner_BB2'')');
select pg_temp.skriv_avvist('bemanning_krav owner_B INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_krav owner_B UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c4-0000-4000-8000-00005dec22c4', 'b1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_krav owner_B DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_krav manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_B1B1'')');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_B1B2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_krav set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_B1B1'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde tablet_B1B2'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

-- =====================================================================
-- bemanning_maned  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_maned');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_maned owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_maned owner_A INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''');
select pg_temp.skriv_avvist('bemanning_maned owner_A UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_maned owner_A DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_maned owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_maned owner_B INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''');
select pg_temp.skriv_tillatt('bemanning_maned owner_B UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''');
select pg_temp.skriv_avvist('bemanning_maned owner_B UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_tillatt('bemanning_maned owner_B DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_maned owner_B DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_maned manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

-- =====================================================================
-- bemanning_stasjon  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_stasjon');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_stasjon owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('bemanning_stasjon owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('bemanning_stasjon owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003'), 'positiv');
select pg_temp.paastand('bemanning_stasjon owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A INSERT A2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A INSERT A3', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_stasjon owner_A INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A UPDATE A2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A UPDATE A3', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.skriv_avvist('bemanning_stasjon owner_A UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A DELETE A2', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_A DELETE A3', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_stasjon owner_A DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_stasjon manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('bemanning_stasjon manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('bemanning_stasjon manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('bemanning_stasjon manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A1 INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 INSERT A2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 INSERT A3', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A1 UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 UPDATE A2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 UPDATE A3', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A1 DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 DELETE A2', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 DELETE A3', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_stasjon set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_stasjon manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('bemanning_stasjon manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('bemanning_stasjon manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('bemanning_stasjon manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 INSERT A2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 INSERT A3', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 UPDATE A2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 UPDATE A3', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_A12 DELETE A2', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 DELETE A3', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_stasjon set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_stasjon tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('bemanning_stasjon tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('bemanning_stasjon tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('bemanning_stasjon tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 INSERT A2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 INSERT A3', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 UPDATE A2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 UPDATE A3', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 DELETE A2', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 DELETE A3', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000003''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000003', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_A1 DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_stasjon owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('bemanning_stasjon owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('bemanning_stasjon owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B INSERT B2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_stasjon owner_B INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B UPDATE B2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.skriv_avvist('bemanning_stasjon owner_B UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_stasjon owner_B DELETE B2', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_stasjon owner_B DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_stasjon manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('bemanning_stasjon manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('bemanning_stasjon manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_B1 INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 INSERT B2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_B1 UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 UPDATE B2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_tillatt('bemanning_stasjon manager_B1 DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 DELETE B2', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_stasjon set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_stasjon tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('bemanning_stasjon tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('bemanning_stasjon tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 INSERT B1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 INSERT B2', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 INSERT A1', 'insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 7)');
select pg_temp.som_eier();
delete from public.bemanning_stasjon where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 UPDATE B1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 UPDATE B2', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''b1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 UPDATE A1', 'update public.bemanning_stasjon set maks_bemanning = 9 where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 DELETE B1', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000001', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 DELETE B2', 'delete from public.bemanning_stasjon where stasjon_id = ''b1110000-0000-4000-8000-000000000002''', 'bemanning_stasjon', 'b1110000-0000-4000-8000-000000000002', 'stasjon_id');
select pg_temp.skriv_avvist('bemanning_stasjon tablet_B1 DELETE A1', 'delete from public.bemanning_stasjon where stasjon_id = ''a1110000-0000-4000-8000-000000000001''', 'bemanning_stasjon', 'a1110000-0000-4000-8000-000000000001', 'stasjon_id');

-- =====================================================================
-- bemanning_vindu  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_vindu');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_vindu owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 222, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 223, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 224, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_A INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 225, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_vindu owner_A UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 226, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 227, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 228, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_vindu owner_A DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 229, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 230, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 231, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 232, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 233, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_vindu set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 234, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 235, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 236, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 237, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 238, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 239, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_vindu set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 240, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 241, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 242, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 243, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_vindu owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 244, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 245, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_B INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 246, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 247, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 248, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 249, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 250, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 251, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 252, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_vindu set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 253, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 254, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 255, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

-- =====================================================================
-- butikksjef_stasjoner  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('butikksjef_stasjoner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae665-0000-4000-8000-000057fae665' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A3 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac5-0000-4000-8000-000057fb5ac5' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ced1-0000-4000-8000-0000a753ced1'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e653-0000-4000-8000-0000a761e653'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffdd5-0000-4000-8000-0000a76ffdd5'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_A INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a773-0000-4000-8000-0000a908a773'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', '57fa7205-0000-4000-8000-000057fa7205');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', '57fae665-0000-4000-8000-000057fae665');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', '57fb5ac5-0000-4000-8000-000057fb5ac5');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae665-0000-4000-8000-000057fae665' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac5-0000-4000-8000-000057fb5ac5' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ceea-0000-4000-8000-0000a753ceea'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e66c-0000-4000-8000-0000a761e66c'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffdee-0000-4000-8000-0000a76ffdee'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a78c-0000-4000-8000-0000a908a78c'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae665-0000-4000-8000-000057fae665' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac5-0000-4000-8000-000057fb5ac5' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ceee-0000-4000-8000-0000a753ceee'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e670-0000-4000-8000-0000a761e670'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffdf2-0000-4000-8000-0000a76ffdf2'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a790-0000-4000-8000-0000a908a790'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae665-0000-4000-8000-000057fae665' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac5-0000-4000-8000-000057fb5ac5' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753cef2-0000-4000-8000-0000a753cef2'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e674-0000-4000-8000-0000a761e674'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffe0b-0000-4000-8000-0000a76ffe0b'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a7a9-0000-4000-8000-0000a908a7a9'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae665-0000-4000-8000-000057fae665'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac5-0000-4000-8000-000057fb5ac5'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde9-0000-4000-8000-00005808fde9' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a7aa-0000-4000-8000-0000a908a7aa'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916bf2c-0000-4000-8000-0000a916bf2c'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_B INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753cf0d-0000-4000-8000-0000a753cf0d'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', '58088989-0000-4000-8000-000058088989');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', '5808fde9-0000-4000-8000-00005808fde9');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde9-0000-4000-8000-00005808fde9' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a7ad-0000-4000-8000-0000a908a7ad'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916bf2f-0000-4000-8000-0000a916bf2f'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753cf10-0000-4000-8000-0000a753cf10'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088989-0000-4000-8000-000058088989' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde9-0000-4000-8000-00005808fde9' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7205-0000-4000-8000-000057fa7205' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a7b0-0000-4000-8000-0000a908a7b0'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916bf32-0000-4000-8000-0000a916bf32'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753cf28-0000-4000-8000-0000a753cf28'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088989-0000-4000-8000-000058088989'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde9-0000-4000-8000-00005808fde9'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7205-0000-4000-8000-000057fa7205'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

-- =====================================================================
-- daglig_salg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('daglig_salg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('daglig_salg owner_A SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A3 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 281, ''owner_AA1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 282, ''owner_AA2'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 283, ''owner_AA3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_A INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 284, ''owner_AB1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 285, 'gjenowner_AA1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 286, 'gjenowner_AA2', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 287, 'gjenowner_AA3', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 288, ''manager_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 289, ''manager_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 290, ''manager_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 291, ''manager_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 292, ''manager_A12A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 293, ''manager_A12A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 294, ''manager_A12A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 295, ''manager_A12B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 296, ''tablet_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 297, ''tablet_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 298, ''tablet_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 299, ''tablet_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 300, ''owner_BB1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 301, ''owner_BB2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_B INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 302, ''owner_BA1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 303, 'gjenowner_BB1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 304, 'gjenowner_BB2', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 305, ''manager_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 306, ''manager_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 307, ''manager_B1A1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 308, ''tablet_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 309, ''tablet_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 310, ''tablet_B1A1'', ''Sondevare'', 100)');
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
-- fokuspunkter  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('fokuspunkter');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('fokuspunkter owner_A SELECT A1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT A2 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f4-0000-4000-8000-0000384b12f4'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT A3 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f5-0000-4000-8000-0000384b12f5'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'negativ');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 311, ''forbedring'', ''Sondepunkt owner_AA1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 312, ''forbedring'', ''Sondepunkt owner_AA2'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 313, ''forbedring'', ''Sondepunkt owner_AA3'')');
select pg_temp.skriv_avvist('fokuspunkter owner_A INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 314, ''forbedring'', ''Sondepunkt owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A UPDATE A2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f4-0000-4000-8000-0000384b12f4''');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A UPDATE A3', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f5-0000-4000-8000-0000384b12f5''');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('fokuspunkter owner_A UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 315, 'forbedring', 'Sondepunkt gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 316, 'forbedring', 'Sondepunkt gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 317, 'forbedring', 'Sondepunkt gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('fokuspunkter owner_A DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.skriv_avvist('fokuspunkter owner_A FLYTTER egen rad -> kjede B', 'update public.fokuspunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('fokuspunkter manager_A1 SELECT A1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'positiv');
select pg_temp.paastand('fokuspunkter manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f4-0000-4000-8000-0000384b12f4'), 'negativ');
select pg_temp.paastand('fokuspunkter manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f5-0000-4000-8000-0000384b12f5'), 'negativ');
select pg_temp.paastand('fokuspunkter manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'negativ');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 318, ''forbedring'', ''Sondepunkt manager_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 319, ''forbedring'', ''Sondepunkt manager_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 320, ''forbedring'', ''Sondepunkt manager_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 321, ''forbedring'', ''Sondepunkt manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 UPDATE A2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 UPDATE A3', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('fokuspunkter manager_A12 SELECT A1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'positiv');
select pg_temp.paastand('fokuspunkter manager_A12 SELECT A2 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f4-0000-4000-8000-0000384b12f4'), 'positiv');
select pg_temp.paastand('fokuspunkter manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f5-0000-4000-8000-0000384b12f5'), 'negativ');
select pg_temp.paastand('fokuspunkter manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'negativ');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 322, ''forbedring'', ''Sondepunkt manager_A12A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 323, ''forbedring'', ''Sondepunkt manager_A12A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 324, ''forbedring'', ''Sondepunkt manager_A12A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 325, ''forbedring'', ''Sondepunkt manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 UPDATE A2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 UPDATE A3', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('fokuspunkter tablet_A1 SELECT A1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'positiv');
select pg_temp.paastand('fokuspunkter tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f4-0000-4000-8000-0000384b12f4'), 'negativ');
select pg_temp.paastand('fokuspunkter tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f5-0000-4000-8000-0000384b12f5'), 'negativ');
select pg_temp.paastand('fokuspunkter tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'negativ');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 326, ''forbedring'', ''Sondepunkt tablet_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 327, ''forbedring'', ''Sondepunkt tablet_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 328, ''forbedring'', ''Sondepunkt tablet_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 329, ''forbedring'', ''Sondepunkt tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 UPDATE A2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 UPDATE A3', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''', 'fokuspunkter', '384b12f4-0000-4000-8000-0000384b12f4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''', 'fokuspunkter', '384b12f5-0000-4000-8000-0000384b12f5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('fokuspunkter owner_B SELECT B1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_B SELECT B2 -> ser', exists (select 1 from public.fokuspunkter where id = '384b1313-0000-4000-8000-0000384b1313'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'negativ');
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 330, ''forbedring'', ''Sondepunkt owner_BB1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 331, ''forbedring'', ''Sondepunkt owner_BB2'')');
select pg_temp.skriv_avvist('fokuspunkter owner_B INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 332, ''forbedring'', ''Sondepunkt owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B UPDATE B2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1313-0000-4000-8000-0000384b1313''');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('fokuspunkter owner_B UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 333, 'forbedring', 'Sondepunkt gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B DELETE B2', 'delete from public.fokuspunkter where id = ''384b1313-0000-4000-8000-0000384b1313''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 334, 'forbedring', 'Sondepunkt gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('fokuspunkter owner_B DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.skriv_avvist('fokuspunkter owner_B FLYTTER egen rad -> kjede A', 'update public.fokuspunkter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('fokuspunkter manager_B1 SELECT B1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'positiv');
select pg_temp.paastand('fokuspunkter manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1313-0000-4000-8000-0000384b1313'), 'negativ');
select pg_temp.paastand('fokuspunkter manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'negativ');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 335, ''forbedring'', ''Sondepunkt manager_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 336, ''forbedring'', ''Sondepunkt manager_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 337, ''forbedring'', ''Sondepunkt manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 UPDATE B2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1313-0000-4000-8000-0000384b1313''', 'fokuspunkter', '384b1313-0000-4000-8000-0000384b1313', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 DELETE B2', 'delete from public.fokuspunkter where id = ''384b1313-0000-4000-8000-0000384b1313''', 'fokuspunkter', '384b1313-0000-4000-8000-0000384b1313', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('fokuspunkter tablet_B1 SELECT B1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'positiv');
select pg_temp.paastand('fokuspunkter tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1313-0000-4000-8000-0000384b1313'), 'negativ');
select pg_temp.paastand('fokuspunkter tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'negativ');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 338, ''forbedring'', ''Sondepunkt tablet_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 339, ''forbedring'', ''Sondepunkt tablet_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 340, ''forbedring'', ''Sondepunkt tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 UPDATE B1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 UPDATE B2', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b1313-0000-4000-8000-0000384b1313''', 'fokuspunkter', '384b1313-0000-4000-8000-0000384b1313', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 UPDATE A1', 'update public.fokuspunkter set tekst = ''endret av sonden'' where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 DELETE B1', 'delete from public.fokuspunkter where id = ''384b1312-0000-4000-8000-0000384b1312''', 'fokuspunkter', '384b1312-0000-4000-8000-0000384b1312', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 DELETE B2', 'delete from public.fokuspunkter where id = ''384b1313-0000-4000-8000-0000384b1313''', 'fokuspunkter', '384b1313-0000-4000-8000-0000384b1313', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 DELETE A1', 'delete from public.fokuspunkter where id = ''384b12f3-0000-4000-8000-0000384b12f3''', 'fokuspunkter', '384b12f3-0000-4000-8000-0000384b12f3', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 2/8: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 2/8: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
