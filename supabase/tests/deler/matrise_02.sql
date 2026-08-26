-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 2 AV 7. Hele matrisen er for stor for Supabase SQL
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
insert into auth.users (id, email) values ('57fa7200-0000-4000-8000-000057fa7200', 'sonde-20@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7200-0000-4000-8000-000057fa7200', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 20');
insert into auth.users (id, email) values ('57fae660-0000-4000-8000-000057fae660', 'sonde-21@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae660-0000-4000-8000-000057fae660', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 21');
insert into auth.users (id, email) values ('57fb5ac0-0000-4000-8000-000057fb5ac0', 'sonde-22@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5ac0-0000-4000-8000-000057fb5ac0', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 22');
insert into auth.users (id, email) values ('58088984-0000-4000-8000-000058088984', 'sonde-23@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('58088984-0000-4000-8000-000058088984', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 23');
insert into auth.users (id, email) values ('5808fde4-0000-4000-8000-00005808fde4', 'sonde-24@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('5808fde4-0000-4000-8000-00005808fde4', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 24');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e487-0000-4000-8000-00001a99e487', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a58e7-0000-4000-8000-00001a9a58e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acd47-0000-4000-8000-00001a9acd47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fc0b-0000-4000-8000-00001aa7fc0b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa8706b-0000-4000-8000-00001aa8706b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into auth.users (id, email) values ('a753ce70-0000-4000-8000-0000a753ce70', 'sonde-222@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ce70-0000-4000-8000-0000a753ce70', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 222');
insert into auth.users (id, email) values ('a761e5f2-0000-4000-8000-0000a761e5f2', 'sonde-223@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e5f2-0000-4000-8000-0000a761e5f2', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 223');
insert into auth.users (id, email) values ('a76ffd74-0000-4000-8000-0000a76ffd74', 'sonde-224@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffd74-0000-4000-8000-0000a76ffd74', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 224');
insert into auth.users (id, email) values ('a908a712-0000-4000-8000-0000a908a712', 'sonde-225@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a712-0000-4000-8000-0000a908a712', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 225');
insert into auth.users (id, email) values ('a753ce74-0000-4000-8000-0000a753ce74', 'sonde-226@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ce74-0000-4000-8000-0000a753ce74', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 226');
insert into auth.users (id, email) values ('a761e5f6-0000-4000-8000-0000a761e5f6', 'sonde-227@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e5f6-0000-4000-8000-0000a761e5f6', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 227');
insert into auth.users (id, email) values ('a76ffd78-0000-4000-8000-0000a76ffd78', 'sonde-228@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffd78-0000-4000-8000-0000a76ffd78', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 228');
insert into auth.users (id, email) values ('a908a716-0000-4000-8000-0000a908a716', 'sonde-229@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a716-0000-4000-8000-0000a908a716', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 229');
insert into auth.users (id, email) values ('a753ce8d-0000-4000-8000-0000a753ce8d', 'sonde-230@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ce8d-0000-4000-8000-0000a753ce8d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 230');
insert into auth.users (id, email) values ('a761e60f-0000-4000-8000-0000a761e60f', 'sonde-231@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e60f-0000-4000-8000-0000a761e60f', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 231');
insert into auth.users (id, email) values ('a76ffd91-0000-4000-8000-0000a76ffd91', 'sonde-232@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffd91-0000-4000-8000-0000a76ffd91', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 232');
insert into auth.users (id, email) values ('a908a72f-0000-4000-8000-0000a908a72f', 'sonde-233@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a72f-0000-4000-8000-0000a908a72f', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 233');
insert into auth.users (id, email) values ('a753ce91-0000-4000-8000-0000a753ce91', 'sonde-234@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ce91-0000-4000-8000-0000a753ce91', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 234');
insert into auth.users (id, email) values ('a761e613-0000-4000-8000-0000a761e613', 'sonde-235@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a761e613-0000-4000-8000-0000a761e613', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 235');
insert into auth.users (id, email) values ('a76ffd95-0000-4000-8000-0000a76ffd95', 'sonde-236@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a76ffd95-0000-4000-8000-0000a76ffd95', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 236');
insert into auth.users (id, email) values ('a908a733-0000-4000-8000-0000a908a733', 'sonde-237@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a733-0000-4000-8000-0000a908a733', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 237');
insert into auth.users (id, email) values ('a908a734-0000-4000-8000-0000a908a734', 'sonde-238@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a734-0000-4000-8000-0000a908a734', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 238');
insert into auth.users (id, email) values ('a916beb6-0000-4000-8000-0000a916beb6', 'sonde-239@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916beb6-0000-4000-8000-0000a916beb6', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 239');
insert into auth.users (id, email) values ('a753ceac-0000-4000-8000-0000a753ceac', 'sonde-240@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ceac-0000-4000-8000-0000a753ceac', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 240');
insert into auth.users (id, email) values ('a908a74c-0000-4000-8000-0000a908a74c', 'sonde-241@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a74c-0000-4000-8000-0000a908a74c', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 241');
insert into auth.users (id, email) values ('a916bece-0000-4000-8000-0000a916bece', 'sonde-242@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916bece-0000-4000-8000-0000a916bece', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 242');
insert into auth.users (id, email) values ('a753ceaf-0000-4000-8000-0000a753ceaf', 'sonde-243@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ceaf-0000-4000-8000-0000a753ceaf', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 243');
insert into auth.users (id, email) values ('a908a74f-0000-4000-8000-0000a908a74f', 'sonde-244@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a908a74f-0000-4000-8000-0000a908a74f', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 244');
insert into auth.users (id, email) values ('a916bed1-0000-4000-8000-0000a916bed1', 'sonde-245@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a916bed1-0000-4000-8000-0000a916bed1', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 245');
insert into auth.users (id, email) values ('a753ceb2-0000-4000-8000-0000a753ceb2', 'sonde-246@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('a753ceb2-0000-4000-8000-0000a753ceb2', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 246');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9a8-0000-4000-8000-000038a2a9a8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c12a-0000-4000-8000-000038b0c12a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8ac-0000-4000-8000-000038bed8ac', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a57825f-0000-4000-8000-00003a57825f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c1-0000-4000-8000-000038a2a9c1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c143-0000-4000-8000-000038b0c143', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8c5-0000-4000-8000-000038bed8c5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578263-0000-4000-8000-00003a578263', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c5-0000-4000-8000-000038a2a9c5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c147-0000-4000-8000-000038b0c147', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8c9-0000-4000-8000-000038bed8c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578267-0000-4000-8000-00003a578267', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9c9-0000-4000-8000-000038a2a9c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0c160-0000-4000-8000-000038b0c160', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed8e2-0000-4000-8000-000038bed8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578280-0000-4000-8000-00003a578280', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578281-0000-4000-8000-00003a578281', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659a03-0000-4000-8000-00003a659a03', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9e4-0000-4000-8000-000038a2a9e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578284-0000-4000-8000-00003a578284', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659a06-0000-4000-8000-00003a659a06', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a9e7-0000-4000-8000-000038a2a9e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578287-0000-4000-8000-00003a578287', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659ca9-0000-4000-8000-00003a659ca9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2ac8a-0000-4000-8000-000038a2ac8a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 15, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 16, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 17, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 18, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 19, 6, 22, 1);

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
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', '57fa7200-0000-4000-8000-000057fa7200');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', '57fae660-0000-4000-8000-000057fae660');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', '57fb5ac0-0000-4000-8000-000057fb5ac0');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', '58088984-0000-4000-8000-000058088984');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', '5808fde4-0000-4000-8000-00005808fde4');

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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 25, 'fastA1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 26, 'fastA2', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 27, 'fastA3', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 28, 'fastB1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 29, 'fastB2', 'Sondevare', 100);

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
-- --- ik_avlesninger: forutsetninger og proberader ---
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '1a99e487-0000-4000-8000-00001a99e487', date '2026-01-01' + 30, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '1a9a58e7-0000-4000-8000-00001a9a58e7', date '2026-01-01' + 31, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '1a9acd47-0000-4000-8000-00001a9acd47', date '2026-01-01' + 32, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '1aa7fc0b-0000-4000-8000-00001aa7fc0b', date '2026-01-01' + 33, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '1aa8706b-0000-4000-8000-00001aa8706b', date '2026-01-01' + 34, 4.0, true);
-- --- ik_kontrollpunkter: forutsetninger og proberader ---
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondekjoel fastA1');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d30-0000-4000-8000-0000a4cd5d30', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondekjoel fastA2');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d31-0000-4000-8000-0000a4cd5d31', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondekjoel fastA3');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondekjoel fastB1');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondekjoel fastB2');

create or replace function pg_temp.nyrad_ik_kontrollpunkter(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn)
  values (p_retailer, p_stasjon, 'Sondekjoel ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;

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
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 188, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 189, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 190, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_A INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 191, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 192, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 193, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 194, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 195, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 196, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 197, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 198, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 199, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 200, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 201, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 202, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 203, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 204, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 205, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 206, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 207, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 208, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 209, 6, 22, 1)');
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
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 210, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 211, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_B INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 212, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 213, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 214, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 215, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 216, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 217, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 218, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 219, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 220, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 221, 6, 22, 1)');
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
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae660-0000-4000-8000-000057fae660' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A3 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac0-0000-4000-8000-000057fb5ac0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ce70-0000-4000-8000-0000a753ce70'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e5f2-0000-4000-8000-0000a761e5f2'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffd74-0000-4000-8000-0000a76ffd74'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_A INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a712-0000-4000-8000-0000a908a712'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', '57fa7200-0000-4000-8000-000057fa7200');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', '57fae660-0000-4000-8000-000057fae660');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', '57fb5ac0-0000-4000-8000-000057fb5ac0');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae660-0000-4000-8000-000057fae660' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac0-0000-4000-8000-000057fb5ac0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ce74-0000-4000-8000-0000a753ce74'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e5f6-0000-4000-8000-0000a761e5f6'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffd78-0000-4000-8000-0000a76ffd78'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a716-0000-4000-8000-0000a908a716'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae660-0000-4000-8000-000057fae660' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac0-0000-4000-8000-000057fb5ac0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ce8d-0000-4000-8000-0000a753ce8d'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e60f-0000-4000-8000-0000a761e60f'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffd91-0000-4000-8000-0000a76ffd91'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a72f-0000-4000-8000-0000a908a72f'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fae660-0000-4000-8000-000057fae660' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fb5ac0-0000-4000-8000-000057fb5ac0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ce91-0000-4000-8000-0000a753ce91'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''a761e613-0000-4000-8000-0000a761e613'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''a76ffd95-0000-4000-8000-0000a76ffd95'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a733-0000-4000-8000-0000a908a733'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''57fae660-0000-4000-8000-000057fae660'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''57fb5ac0-0000-4000-8000-000057fb5ac0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde4-0000-4000-8000-00005808fde4' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a734-0000-4000-8000-0000a908a734'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916beb6-0000-4000-8000-0000a916beb6'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_B INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ceac-0000-4000-8000-0000a753ceac'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', '58088984-0000-4000-8000-000058088984');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', '5808fde4-0000-4000-8000-00005808fde4');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde4-0000-4000-8000-00005808fde4' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a74c-0000-4000-8000-0000a908a74c'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916bece-0000-4000-8000-0000a916bece'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ceaf-0000-4000-8000-0000a753ceaf'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '58088984-0000-4000-8000-000058088984' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '5808fde4-0000-4000-8000-00005808fde4' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = '57fa7200-0000-4000-8000-000057fa7200' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''a908a74f-0000-4000-8000-0000a908a74f'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''a916bed1-0000-4000-8000-0000a916bed1'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''a753ceb2-0000-4000-8000-0000a753ceb2'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''58088984-0000-4000-8000-000058088984'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''5808fde4-0000-4000-8000-00005808fde4'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''57fa7200-0000-4000-8000-000057fa7200'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

-- =====================================================================
-- daglig_salg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('daglig_salg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('daglig_salg owner_A SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A3 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 247, ''owner_AA1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 248, ''owner_AA2'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 249, ''owner_AA3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_A INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 250, ''owner_AB1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 251, 'gjenowner_AA1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 252, 'gjenowner_AA2', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 253, 'gjenowner_AA3', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 254, ''manager_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 255, ''manager_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 256, ''manager_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 257, ''manager_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 258, ''manager_A12A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 259, ''manager_A12A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 260, ''manager_A12A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 261, ''manager_A12B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 262, ''tablet_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 263, ''tablet_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 264, ''tablet_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 265, ''tablet_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 266, ''owner_BB1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 267, ''owner_BB2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_B INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 268, ''owner_BA1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 269, 'gjenowner_BB1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 270, 'gjenowner_BB2', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 271, ''manager_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 272, ''manager_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 273, ''manager_B1A1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 274, ''tablet_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 275, ''tablet_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 276, ''tablet_B1A1'', ''Sondevare'', 100)');
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
-- ik_avlesninger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ik_avlesninger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ik_avlesninger owner_A SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A3 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9a8-0000-4000-8000-000038a2a9a8'', date ''2026-01-01'' + 277, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c12a-0000-4000-8000-000038b0c12a'', date ''2026-01-01'' + 278, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8ac-0000-4000-8000-000038bed8ac'', date ''2026-01-01'' + 279, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a57825f-0000-4000-8000-00003a57825f'', date ''2026-01-01'' + 280, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c1-0000-4000-8000-000038a2a9c1'', date ''2026-01-01'' + 281, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c143-0000-4000-8000-000038b0c143'', date ''2026-01-01'' + 282, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8c5-0000-4000-8000-000038bed8c5'', date ''2026-01-01'' + 283, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578263-0000-4000-8000-00003a578263'', date ''2026-01-01'' + 284, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c5-0000-4000-8000-000038a2a9c5'', date ''2026-01-01'' + 285, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c147-0000-4000-8000-000038b0c147'', date ''2026-01-01'' + 286, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8c9-0000-4000-8000-000038bed8c9'', date ''2026-01-01'' + 287, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578267-0000-4000-8000-00003a578267'', date ''2026-01-01'' + 288, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9c9-0000-4000-8000-000038a2a9c9'', date ''2026-01-01'' + 289, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0c160-0000-4000-8000-000038b0c160'', date ''2026-01-01'' + 290, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed8e2-0000-4000-8000-000038bed8e2'', date ''2026-01-01'' + 291, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578280-0000-4000-8000-00003a578280'', date ''2026-01-01'' + 292, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578281-0000-4000-8000-00003a578281'', date ''2026-01-01'' + 293, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659a03-0000-4000-8000-00003a659a03'', date ''2026-01-01'' + 294, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9e4-0000-4000-8000-000038a2a9e4'', date ''2026-01-01'' + 295, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578284-0000-4000-8000-00003a578284'', date ''2026-01-01'' + 296, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659a06-0000-4000-8000-00003a659a06'', date ''2026-01-01'' + 297, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a9e7-0000-4000-8000-000038a2a9e7'', date ''2026-01-01'' + 298, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578287-0000-4000-8000-00003a578287'', date ''2026-01-01'' + 299, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659ca9-0000-4000-8000-00003a659ca9'', date ''2026-01-01'' + 300, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2ac8a-0000-4000-8000-000038a2ac8a'', date ''2026-01-01'' + 301, 4.0, true)');

-- =====================================================================
-- ik_kontrollpunkter  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ik_kontrollpunkter');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ik_kontrollpunkter owner_A SELECT A1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter owner_A SELECT A2 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d30-0000-4000-8000-0000a4cd5d30'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter owner_A SELECT A3 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d31-0000-4000-8000-0000a4cd5d31'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'negativ');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel owner_AA1'')');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A INSERT A2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondekjoel owner_AA2'')');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A INSERT A3', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondekjoel owner_AA3'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_A INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A UPDATE A2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A UPDATE A3', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_A UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondekjoel gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A DELETE A2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d30-0000-4000-8000-0000a4cd5d30', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondekjoel gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_A DELETE A3', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d31-0000-4000-8000-0000a4cd5d31', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondekjoel gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_A DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_A FLYTTER egen rad -> kjede B', 'update public.ik_kontrollpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_kontrollpunkter manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d30-0000-4000-8000-0000a4cd5d30'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d31-0000-4000-8000-0000a4cd5d31'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'negativ');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A1 INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_A1A1'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 INSERT A2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondekjoel manager_A1A2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 INSERT A3', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondekjoel manager_A1A3'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A1 UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 UPDATE A2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''', 'ik_kontrollpunkter', 'a4cd5d30-0000-4000-8000-0000a4cd5d30', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 UPDATE A3', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A1 DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondekjoel gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 DELETE A2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''', 'ik_kontrollpunkter', 'a4cd5d30-0000-4000-8000-0000a4cd5d30', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 DELETE A3', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 FLYTTER egen rad A1 -> A2', 'update public.ik_kontrollpunkter set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A1 FLYTTER egen rad -> kjede B', 'update public.ik_kontrollpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_kontrollpunkter manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d30-0000-4000-8000-0000a4cd5d30'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d31-0000-4000-8000-0000a4cd5d31'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'negativ');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_A12A1'')');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 INSERT A2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondekjoel manager_A12A2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 INSERT A3', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondekjoel manager_A12A3'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 UPDATE A2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 UPDATE A3', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondekjoel gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_A12 DELETE A2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d30-0000-4000-8000-0000a4cd5d30', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondekjoel gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 DELETE A3', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 FLYTTER egen rad A1 -> A3', 'update public.ik_kontrollpunkter set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_A12 FLYTTER egen rad -> kjede B', 'update public.ik_kontrollpunkter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_kontrollpunkter tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d30-0000-4000-8000-0000a4cd5d30'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d31-0000-4000-8000-0000a4cd5d31'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'negativ');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel tablet_A1A1'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 INSERT A2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondekjoel tablet_A1A2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 INSERT A3', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondekjoel tablet_A1A3'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 UPDATE A2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''', 'ik_kontrollpunkter', 'a4cd5d30-0000-4000-8000-0000a4cd5d30', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 UPDATE A3', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 DELETE A2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d30-0000-4000-8000-0000a4cd5d30''', 'ik_kontrollpunkter', 'a4cd5d30-0000-4000-8000-0000a4cd5d30', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 DELETE A3', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d31-0000-4000-8000-0000a4cd5d31''', 'ik_kontrollpunkter', 'a4cd5d31-0000-4000-8000-0000a4cd5d31', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_A1 DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_kontrollpunkter owner_B SELECT B1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter owner_B SELECT B2 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'negativ');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel owner_BB1'')');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B INSERT B2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondekjoel owner_BB2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_B INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B UPDATE B2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_B UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondekjoel gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ik_kontrollpunkter owner_B DELETE B2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondekjoel gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_B DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter owner_B FLYTTER egen rad -> kjede A', 'update public.ik_kontrollpunkter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_kontrollpunkter manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'negativ');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_B1 INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_B1B1'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 INSERT B2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondekjoel manager_B1B2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_B1 UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 UPDATE B2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''', 'ik_kontrollpunkter', 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ik_kontrollpunkter manager_B1 DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''');
select pg_temp.som_eier();
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondekjoel gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 DELETE B2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''', 'ik_kontrollpunkter', 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 FLYTTER egen rad B1 -> B2', 'update public.ik_kontrollpunkter set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.skriv_avvist('ik_kontrollpunkter manager_B1 FLYTTER egen rad -> kjede A', 'update public.ik_kontrollpunkter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_kontrollpunkter tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e'), 'positiv');
select pg_temp.paastand('ik_kontrollpunkter tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f'), 'negativ');
select pg_temp.paastand('ik_kontrollpunkter tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_kontrollpunkter where id = 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f'), 'negativ');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 INSERT B1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondekjoel tablet_B1B1'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 INSERT B2', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondekjoel tablet_B1B2'')');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 INSERT A1', 'insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondekjoel tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 UPDATE B1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 UPDATE B2', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''', 'ik_kontrollpunkter', 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 UPDATE A1', 'update public.ik_kontrollpunkter set sortering = 1 where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 DELETE B1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4e-0000-4000-8000-0000a4cd5d4e''', 'ik_kontrollpunkter', 'a4cd5d4e-0000-4000-8000-0000a4cd5d4e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 DELETE B2', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d4f-0000-4000-8000-0000a4cd5d4f''', 'ik_kontrollpunkter', 'a4cd5d4f-0000-4000-8000-0000a4cd5d4f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ik_kontrollpunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ik_kontrollpunkter tablet_B1 DELETE A1', 'delete from public.ik_kontrollpunkter where id = ''a4cd5d2f-0000-4000-8000-0000a4cd5d2f''', 'ik_kontrollpunkter', 'a4cd5d2f-0000-4000-8000-0000a4cd5d2f', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 2/7: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 2/7: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
