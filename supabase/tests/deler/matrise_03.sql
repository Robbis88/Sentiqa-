-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 4. Hele matrisen er for stor for Supabase SQL
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
insert into public.merker (id, retailer_id, navn) values ('5ea158ce-0000-4000-8000-00005ea158ce', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 0');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('12fa1623-0000-4000-8000-000012fa1623', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-0');
insert into public.merker (id, retailer_id, navn) values ('5ea15c90-0000-4000-8000-00005ea15c90', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 1');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('12fa19e5-0000-4000-8000-000012fa19e5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-1');
insert into public.merker (id, retailer_id, navn) values ('5ea16052-0000-4000-8000-00005ea16052', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 2');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('12fa1da7-0000-4000-8000-000012fa1da7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-2');
insert into public.merker (id, retailer_id, navn) values ('5ea1cd30-0000-4000-8000-00005ea1cd30', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 3');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('12fa8a85-0000-4000-8000-000012fa8a85', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-3');
insert into public.merker (id, retailer_id, navn) values ('5ea1d0f2-0000-4000-8000-00005ea1d0f2', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 4');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('12fa8e47-0000-4000-8000-000012fa8e47', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-4');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcb4cb-0000-4000-8000-000084fcb4cb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcb88d-0000-4000-8000-000084fcb88d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcbc4f-0000-4000-8000-000084fcbc4f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fd292d-0000-4000-8000-000084fd292d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fd2cef-0000-4000-8000-000084fd2cef', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.merker (id, retailer_id, navn) values ('7589c1a0-0000-4000-8000-00007589c1a0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 42');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48aeeb-0000-4000-8000-00004c48aeeb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-42');
insert into public.merker (id, retailer_id, navn) values ('758a3600-0000-4000-8000-0000758a3600', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 43');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c49234b-0000-4000-8000-00004c49234b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-43');
insert into public.merker (id, retailer_id, navn) values ('758aaa60-0000-4000-8000-0000758aaa60', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 44');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4997ab-0000-4000-8000-00004c4997ab', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-44');
insert into public.merker (id, retailer_id, navn) values ('7597d924-0000-4000-8000-00007597d924', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 45');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c66f-0000-4000-8000-00004c56c66f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-45');
insert into public.merker (id, retailer_id, navn) values ('7589c1a4-0000-4000-8000-00007589c1a4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 46');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48aeef-0000-4000-8000-00004c48aeef', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-46');
insert into public.merker (id, retailer_id, navn) values ('758a3604-0000-4000-8000-0000758a3604', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 47');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c49234f-0000-4000-8000-00004c49234f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-47');
insert into public.merker (id, retailer_id, navn) values ('758aaa64-0000-4000-8000-0000758aaa64', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 48');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4997af-0000-4000-8000-00004c4997af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-48');
insert into public.merker (id, retailer_id, navn) values ('7589c1a7-0000-4000-8000-00007589c1a7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 49');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48aef2-0000-4000-8000-00004c48aef2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-49');
insert into public.merker (id, retailer_id, navn) values ('758a361c-0000-4000-8000-0000758a361c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 50');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c492367-0000-4000-8000-00004c492367', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-50');
insert into public.merker (id, retailer_id, navn) values ('758aaa7c-0000-4000-8000-0000758aaa7c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 51');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4997c7-0000-4000-8000-00004c4997c7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-51');
insert into public.merker (id, retailer_id, navn) values ('7597d940-0000-4000-8000-00007597d940', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 52');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c68b-0000-4000-8000-00004c56c68b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-52');
insert into public.merker (id, retailer_id, navn) values ('7589c1c0-0000-4000-8000-00007589c1c0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 53');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af0b-0000-4000-8000-00004c48af0b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-53');
insert into public.merker (id, retailer_id, navn) values ('7589c1c1-0000-4000-8000-00007589c1c1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 54');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af0c-0000-4000-8000-00004c48af0c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-54');
insert into public.merker (id, retailer_id, navn) values ('758a3621-0000-4000-8000-0000758a3621', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 55');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c49236c-0000-4000-8000-00004c49236c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-55');
insert into public.merker (id, retailer_id, navn) values ('758aaa81-0000-4000-8000-0000758aaa81', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 56');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4997cc-0000-4000-8000-00004c4997cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-56');
insert into public.merker (id, retailer_id, navn) values ('7597d945-0000-4000-8000-00007597d945', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 57');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c690-0000-4000-8000-00004c56c690', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-57');
insert into public.merker (id, retailer_id, navn) values ('7589c1c5-0000-4000-8000-00007589c1c5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 58');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af10-0000-4000-8000-00004c48af10', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-58');
insert into public.merker (id, retailer_id, navn) values ('758a3625-0000-4000-8000-0000758a3625', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 59');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c492370-0000-4000-8000-00004c492370', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-59');
insert into public.merker (id, retailer_id, navn) values ('7589c1dc-0000-4000-8000-00007589c1dc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 60');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af27-0000-4000-8000-00004c48af27', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-60');
insert into public.merker (id, retailer_id, navn) values ('758a363c-0000-4000-8000-0000758a363c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 61');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c492387-0000-4000-8000-00004c492387', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-61');
insert into public.merker (id, retailer_id, navn) values ('758aaa9c-0000-4000-8000-0000758aaa9c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 62');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4997e7-0000-4000-8000-00004c4997e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-62');
insert into public.merker (id, retailer_id, navn) values ('7597d960-0000-4000-8000-00007597d960', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 63');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6ab-0000-4000-8000-00004c56c6ab', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-63');
insert into public.merker (id, retailer_id, navn) values ('7597d961-0000-4000-8000-00007597d961', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 64');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6ac-0000-4000-8000-00004c56c6ac', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-64');
insert into public.merker (id, retailer_id, navn) values ('75984dc1-0000-4000-8000-000075984dc1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 65');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c573b0c-0000-4000-8000-00004c573b0c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-65');
insert into public.merker (id, retailer_id, navn) values ('7589c1e2-0000-4000-8000-00007589c1e2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 66');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af2d-0000-4000-8000-00004c48af2d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-66');
insert into public.merker (id, retailer_id, navn) values ('7597d964-0000-4000-8000-00007597d964', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 67');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6af-0000-4000-8000-00004c56c6af', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-67');
insert into public.merker (id, retailer_id, navn) values ('75984dc4-0000-4000-8000-000075984dc4', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 68');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c573b0f-0000-4000-8000-00004c573b0f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-68');
insert into public.merker (id, retailer_id, navn) values ('7597d966-0000-4000-8000-00007597d966', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 69');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6b1-0000-4000-8000-00004c56c6b1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-69');
insert into public.merker (id, retailer_id, navn) values ('75984ddb-0000-4000-8000-000075984ddb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 70');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c573b26-0000-4000-8000-00004c573b26', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-70');
insert into public.merker (id, retailer_id, navn) values ('7589c1fc-0000-4000-8000-00007589c1fc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 71');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af47-0000-4000-8000-00004c48af47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-71');
insert into public.merker (id, retailer_id, navn) values ('7597d97e-0000-4000-8000-00007597d97e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 72');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6c9-0000-4000-8000-00004c56c6c9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-72');
insert into public.merker (id, retailer_id, navn) values ('7597d97f-0000-4000-8000-00007597d97f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 73');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c6ca-0000-4000-8000-00004c56c6ca', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-73');
insert into public.merker (id, retailer_id, navn) values ('75984ddf-0000-4000-8000-000075984ddf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 74');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c573b2a-0000-4000-8000-00004c573b2a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-74');
insert into public.merker (id, retailer_id, navn) values ('7589c200-0000-4000-8000-00007589c200', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 75');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48af4b-0000-4000-8000-00004c48af4b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-75');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e509-0000-4000-8000-00001a99e509', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a5969-0000-4000-8000-00001a9a5969', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acdc9-0000-4000-8000-00001a9acdc9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fc8d-0000-4000-8000-00001aa7fc8d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e522-0000-4000-8000-00001a99e522', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a5982-0000-4000-8000-00001a9a5982', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acde2-0000-4000-8000-00001a9acde2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fca6-0000-4000-8000-00001aa7fca6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e526-0000-4000-8000-00001a99e526', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a5986-0000-4000-8000-00001a9a5986', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acde6-0000-4000-8000-00001a9acde6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcaa-0000-4000-8000-00001aa7fcaa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e52a-0000-4000-8000-00001a99e52a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a598a-0000-4000-8000-00001a9a598a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acdff-0000-4000-8000-00001a9acdff', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc3-0000-4000-8000-00001aa7fcc3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc4-0000-4000-8000-00001aa7fcc4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87124-0000-4000-8000-00001aa87124', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e545-0000-4000-8000-00001a99e545', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc7-0000-4000-8000-00001aa7fcc7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87127-0000-4000-8000-00001aa87127', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e548-0000-4000-8000-00001a99e548', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcca-0000-4000-8000-00001aa7fcca', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa8712a-0000-4000-8000-00001aa8712a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a507-0000-4000-8000-000038a2a507', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
-- --- tildelte_merker: forutsetninger og proberader ---
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '5ea158ce-0000-4000-8000-00005ea158ce', '12fa1623-0000-4000-8000-000012fa1623', date '2026-01-01' + 0);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '5ea15c90-0000-4000-8000-00005ea15c90', '12fa19e5-0000-4000-8000-000012fa19e5', date '2026-01-01' + 1);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '5ea16052-0000-4000-8000-00005ea16052', '12fa1da7-0000-4000-8000-000012fa1da7', date '2026-01-01' + 2);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '5ea1cd30-0000-4000-8000-00005ea1cd30', '12fa8a85-0000-4000-8000-000012fa8a85', date '2026-01-01' + 3);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '5ea1d0f2-0000-4000-8000-00005ea1d0f2', '12fa8e47-0000-4000-8000-000012fa8e47', date '2026-01-01' + 4);

create or replace function pg_temp.nyrad_tildelte_merker(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_merke uuid := gen_random_uuid();
  v_ansatt uuid := gen_random_uuid();
begin
  insert into public.merker (id, retailer_id, navn) values (v_merke, p_retailer, 'Sondemerke ' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values (v_ansatt, p_retailer, p_stasjon, 'Sondeansatt', 'pin-merke-' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato)
  values (p_stasjon, v_merke, v_ansatt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- ik_avlesninger: forutsetninger og proberader ---
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '84fcb4cb-0000-4000-8000-000084fcb4cb', date '2026-01-01' + 5, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '84fcb88d-0000-4000-8000-000084fcb88d', date '2026-01-01' + 6, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '84fcbc4f-0000-4000-8000-000084fcbc4f', date '2026-01-01' + 7, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '84fd292d-0000-4000-8000-000084fd292d', date '2026-01-01' + 8, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '84fd2cef-0000-4000-8000-000084fd2cef', date '2026-01-01' + 9, 4.0, true);

create or replace function pg_temp.nyrad_ik_avlesninger(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_kontrollpunkt uuid := gen_random_uuid();
begin
  insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values (v_kontrollpunkt, p_retailer, p_stasjon, 'Sondepunkt');
  insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor)
  values (p_stasjon, v_kontrollpunkt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 4.0, true)
  returning id into ny;
  return ny;
end $fn$;
-- --- ansatte: forutsetninger og proberader ---
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3e-0000-4000-8000-000019538d3e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'fastA1', 'pin fastA1');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3f-0000-4000-8000-000019538d3f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', 'fastA2', 'pin fastA2');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d40-0000-4000-8000-000019538d40', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', 'fastA3', 'pin fastA3');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d5d-0000-4000-8000-000019538d5d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'fastB1', 'pin fastB1');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d5e-0000-4000-8000-000019538d5e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', 'fastB2', 'pin fastB2');

create or replace function pg_temp.nyrad_ansatte(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash)
  values (p_retailer, p_stasjon, 'Sonde Sondesen', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'pin ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
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
-- --- bemanning_stasjon: forutsetninger og proberader ---
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
-- --- tablet_meldinger: forutsetninger og proberader ---
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('80f0b8e1-0000-4000-8000-000080f0b8e1', 'aaaa0000-0000-4000-8000-000000000000', null, 'Sondemelding nullA');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('80f0b8e2-0000-4000-8000-000080f0b8e2', 'bbbb0000-0000-4000-8000-000000000000', null, 'Sondemelding nullB');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding fastA1');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding fastA2');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadc-0000-4000-8000-0000d7d6fadc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding fastA3');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding fastB1');
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fafa-0000-4000-8000-0000d7d6fafa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding fastB2');

create or replace function pg_temp.nyrad_tablet_meldinger(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst)
  values (p_retailer, p_stasjon, 'Sondemelding ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- produksjonsplan_hode: forutsetninger og proberader ---
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 37);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 38);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 39);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 40);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 41);

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

-- =====================================================================
-- tildelte_merker  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tildelte_merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tildelte_merker owner_A SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A3 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1a0-0000-4000-8000-00007589c1a0'', ''4c48aeeb-0000-4000-8000-00004c48aeeb'', date ''2026-01-01'' + 42)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a3600-0000-4000-8000-0000758a3600'', ''4c49234b-0000-4000-8000-00004c49234b'', date ''2026-01-01'' + 43)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaa60-0000-4000-8000-0000758aaa60'', ''4c4997ab-0000-4000-8000-00004c4997ab'', date ''2026-01-01'' + 44)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d924-0000-4000-8000-00007597d924'', ''4c56c66f-0000-4000-8000-00004c56c66f'', date ''2026-01-01'' + 45)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tildelte_merker owner_A UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1a4-0000-4000-8000-00007589c1a4', '4c48aeef-0000-4000-8000-00004c48aeef', date '2026-01-01' + 46);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a3604-0000-4000-8000-0000758a3604', '4c49234f-0000-4000-8000-00004c49234f', date '2026-01-01' + 47);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa64-0000-4000-8000-0000758aaa64', '4c4997af-0000-4000-8000-00004c4997af', date '2026-01-01' + 48);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tildelte_merker owner_A DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1a7-0000-4000-8000-00007589c1a7'', ''4c48aef2-0000-4000-8000-00004c48aef2'', date ''2026-01-01'' + 49)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a361c-0000-4000-8000-0000758a361c'', ''4c492367-0000-4000-8000-00004c492367'', date ''2026-01-01'' + 50)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaa7c-0000-4000-8000-0000758aaa7c'', ''4c4997c7-0000-4000-8000-00004c4997c7'', date ''2026-01-01'' + 51)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d940-0000-4000-8000-00007597d940'', ''4c56c68b-0000-4000-8000-00004c56c68b'', date ''2026-01-01'' + 52)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1c0-0000-4000-8000-00007589c1c0', '4c48af0b-0000-4000-8000-00004c48af0b', date '2026-01-01' + 53);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tildelte_merker set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1c1-0000-4000-8000-00007589c1c1'', ''4c48af0c-0000-4000-8000-00004c48af0c'', date ''2026-01-01'' + 54)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a3621-0000-4000-8000-0000758a3621'', ''4c49236c-0000-4000-8000-00004c49236c'', date ''2026-01-01'' + 55)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaa81-0000-4000-8000-0000758aaa81'', ''4c4997cc-0000-4000-8000-00004c4997cc'', date ''2026-01-01'' + 56)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d945-0000-4000-8000-00007597d945'', ''4c56c690-0000-4000-8000-00004c56c690'', date ''2026-01-01'' + 57)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c1c5-0000-4000-8000-00007589c1c5', '4c48af10-0000-4000-8000-00004c48af10', date '2026-01-01' + 58);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a3625-0000-4000-8000-0000758a3625', '4c492370-0000-4000-8000-00004c492370', date '2026-01-01' + 59);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tildelte_merker set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1dc-0000-4000-8000-00007589c1dc'', ''4c48af27-0000-4000-8000-00004c48af27'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''758a363c-0000-4000-8000-0000758a363c'', ''4c492387-0000-4000-8000-00004c492387'', date ''2026-01-01'' + 61)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''758aaa9c-0000-4000-8000-0000758aaa9c'', ''4c4997e7-0000-4000-8000-00004c4997e7'', date ''2026-01-01'' + 62)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d960-0000-4000-8000-00007597d960'', ''4c56c6ab-0000-4000-8000-00004c56c6ab'', date ''2026-01-01'' + 63)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE A3', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''', 'tildelte_merker', '2addacad-0000-4000-8000-00002addacad', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''', 'tildelte_merker', '2addacae-0000-4000-8000-00002addacae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tildelte_merker owner_B SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_B SELECT B2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d961-0000-4000-8000-00007597d961'', ''4c56c6ac-0000-4000-8000-00004c56c6ac'', date ''2026-01-01'' + 64)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984dc1-0000-4000-8000-000075984dc1'', ''4c573b0c-0000-4000-8000-00004c573b0c'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1e2-0000-4000-8000-00007589c1e2'', ''4c48af2d-0000-4000-8000-00004c48af2d'', date ''2026-01-01'' + 66)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d964-0000-4000-8000-00007597d964', '4c56c6af-0000-4000-8000-00004c56c6af', date '2026-01-01' + 67);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984dc4-0000-4000-8000-000075984dc4', '4c573b0f-0000-4000-8000-00004c573b0f', date '2026-01-01' + 68);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d966-0000-4000-8000-00007597d966'', ''4c56c6b1-0000-4000-8000-00004c56c6b1'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984ddb-0000-4000-8000-000075984ddb'', ''4c573b26-0000-4000-8000-00004c573b26'', date ''2026-01-01'' + 70)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c1fc-0000-4000-8000-00007589c1fc'', ''4c48af47-0000-4000-8000-00004c48af47'', date ''2026-01-01'' + 71)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d97e-0000-4000-8000-00007597d97e', '4c56c6c9-0000-4000-8000-00004c56c6c9', date '2026-01-01' + 72);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tildelte_merker set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''7597d97f-0000-4000-8000-00007597d97f'', ''4c56c6ca-0000-4000-8000-00004c56c6ca'', date ''2026-01-01'' + 73)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''75984ddf-0000-4000-8000-000075984ddf'', ''4c573b2a-0000-4000-8000-00004c573b2a'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''7589c200-0000-4000-8000-00007589c200'', ''4c48af4b-0000-4000-8000-00004c48af4b'', date ''2026-01-01'' + 75)');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE B1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE B2', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 UPDATE A1', 'update public.tildelte_merker set tildelt_dato = date ''2029-01-01'' where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE B1', 'delete from public.tildelte_merker where id = ''2addaccb-0000-4000-8000-00002addaccb''', 'tildelte_merker', '2addaccb-0000-4000-8000-00002addaccb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''', 'tildelte_merker', '2addaccc-0000-4000-8000-00002addaccc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

-- =====================================================================
-- ik_avlesninger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ik_avlesninger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ik_avlesninger owner_A SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A3 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e509-0000-4000-8000-00001a99e509'', date ''2026-01-01'' + 76, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a5969-0000-4000-8000-00001a9a5969'', date ''2026-01-01'' + 77, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acdc9-0000-4000-8000-00001a9acdc9'', date ''2026-01-01'' + 78, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fc8d-0000-4000-8000-00001aa7fc8d'', date ''2026-01-01'' + 79, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e522-0000-4000-8000-00001a99e522'', date ''2026-01-01'' + 80, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a5982-0000-4000-8000-00001a9a5982'', date ''2026-01-01'' + 81, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acde2-0000-4000-8000-00001a9acde2'', date ''2026-01-01'' + 82, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fca6-0000-4000-8000-00001aa7fca6'', date ''2026-01-01'' + 83, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e526-0000-4000-8000-00001a99e526'', date ''2026-01-01'' + 84, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a5986-0000-4000-8000-00001a9a5986'', date ''2026-01-01'' + 85, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acde6-0000-4000-8000-00001a9acde6'', date ''2026-01-01'' + 86, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcaa-0000-4000-8000-00001aa7fcaa'', date ''2026-01-01'' + 87, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e52a-0000-4000-8000-00001a99e52a'', date ''2026-01-01'' + 88, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a598a-0000-4000-8000-00001a9a598a'', date ''2026-01-01'' + 89, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acdff-0000-4000-8000-00001a9acdff'', date ''2026-01-01'' + 90, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc3-0000-4000-8000-00001aa7fcc3'', date ''2026-01-01'' + 91, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc4-0000-4000-8000-00001aa7fcc4'', date ''2026-01-01'' + 92, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''1aa87124-0000-4000-8000-00001aa87124'', date ''2026-01-01'' + 93, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e545-0000-4000-8000-00001a99e545'', date ''2026-01-01'' + 94, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc7-0000-4000-8000-00001aa7fcc7'', date ''2026-01-01'' + 95, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''1aa87127-0000-4000-8000-00001aa87127'', date ''2026-01-01'' + 96, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e548-0000-4000-8000-00001a99e548'', date ''2026-01-01'' + 97, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcca-0000-4000-8000-00001aa7fcca'', date ''2026-01-01'' + 98, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''1aa8712a-0000-4000-8000-00001aa8712a'', date ''2026-01-01'' + 99, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a507-0000-4000-8000-000038a2a507'', date ''2026-01-01'' + 100, 4.0, true)');

-- =====================================================================
-- ansatte  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ansatte');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ansatte owner_A SELECT A1 -> ser', exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'positiv');
select pg_temp.paastand('ansatte owner_A SELECT A2 -> ser', exists (select 1 from public.ansatte where id = '19538d3f-0000-4000-8000-000019538d3f'), 'positiv');
select pg_temp.paastand('ansatte owner_A SELECT A3 -> ser', exists (select 1 from public.ansatte where id = '19538d40-0000-4000-8000-000019538d40'), 'positiv');
select pg_temp.paastand('ansatte owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'negativ');
select pg_temp.skriv_tillatt('ansatte owner_A INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''owner_AA1'', ''pin owner_AA1'')');
select pg_temp.skriv_tillatt('ansatte owner_A INSERT A2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''owner_AA2'', ''pin owner_AA2'')');
select pg_temp.skriv_tillatt('ansatte owner_A INSERT A3', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', ''owner_AA3'', ''pin owner_AA3'')');
select pg_temp.skriv_avvist('ansatte owner_A INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''owner_AB1'', ''pin owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A UPDATE A2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3f-0000-4000-8000-000019538d3f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A UPDATE A3', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d40-0000-4000-8000-000019538d40''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatte owner_A UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3e-0000-4000-8000-000019538d3e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'gjenowner_AA1', 'pin gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A DELETE A2', 'delete from public.ansatte where id = ''19538d3f-0000-4000-8000-000019538d3f''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3f-0000-4000-8000-000019538d3f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', 'gjenowner_AA2', 'pin gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatte owner_A DELETE A3', 'delete from public.ansatte where id = ''19538d40-0000-4000-8000-000019538d40''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d40-0000-4000-8000-000019538d40', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', 'gjenowner_AA3', 'pin gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatte owner_A DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.skriv_avvist('ansatte owner_A FLYTTER egen rad -> kjede B', 'update public.ansatte set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ansatte manager_A1 SELECT A1 -> ser', exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'positiv');
select pg_temp.paastand('ansatte manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d3f-0000-4000-8000-000019538d3f'), 'negativ');
select pg_temp.paastand('ansatte manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d40-0000-4000-8000-000019538d40'), 'negativ');
select pg_temp.paastand('ansatte manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'negativ');
select pg_temp.skriv_tillatt('ansatte manager_A1 INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_A1A1'', ''pin manager_A1A1'')');
select pg_temp.skriv_avvist('ansatte manager_A1 INSERT A2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''manager_A1A2'', ''pin manager_A1A2'')');
select pg_temp.skriv_avvist('ansatte manager_A1 INSERT A3', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', ''manager_A1A3'', ''pin manager_A1A3'')');
select pg_temp.skriv_avvist('ansatte manager_A1 INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_A1B1'', ''pin manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatte manager_A1 UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 UPDATE A2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3f-0000-4000-8000-000019538d3f''', 'ansatte', '19538d3f-0000-4000-8000-000019538d3f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 UPDATE A3', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatte manager_A1 DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3e-0000-4000-8000-000019538d3e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'gjenmanager_A1A1', 'pin gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 DELETE A2', 'delete from public.ansatte where id = ''19538d3f-0000-4000-8000-000019538d3f''', 'ansatte', '19538d3f-0000-4000-8000-000019538d3f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 DELETE A3', 'delete from public.ansatte where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatte manager_A1 DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.skriv_avvist('ansatte manager_A1 FLYTTER egen rad A1 -> A2', 'update public.ansatte set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.skriv_avvist('ansatte manager_A1 FLYTTER egen rad -> kjede B', 'update public.ansatte set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ansatte manager_A12 SELECT A1 -> ser', exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'positiv');
select pg_temp.paastand('ansatte manager_A12 SELECT A2 -> ser', exists (select 1 from public.ansatte where id = '19538d3f-0000-4000-8000-000019538d3f'), 'positiv');
select pg_temp.paastand('ansatte manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d40-0000-4000-8000-000019538d40'), 'negativ');
select pg_temp.paastand('ansatte manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'negativ');
select pg_temp.skriv_tillatt('ansatte manager_A12 INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_A12A1'', ''pin manager_A12A1'')');
select pg_temp.skriv_tillatt('ansatte manager_A12 INSERT A2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''manager_A12A2'', ''pin manager_A12A2'')');
select pg_temp.skriv_avvist('ansatte manager_A12 INSERT A3', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', ''manager_A12A3'', ''pin manager_A12A3'')');
select pg_temp.skriv_avvist('ansatte manager_A12 INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_A12B1'', ''pin manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatte manager_A12 UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatte manager_A12 UPDATE A2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3f-0000-4000-8000-000019538d3f''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatte manager_A12 UPDATE A3', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatte manager_A12 UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatte manager_A12 DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3e-0000-4000-8000-000019538d3e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'gjenmanager_A12A1', 'pin gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatte manager_A12 DELETE A2', 'delete from public.ansatte where id = ''19538d3f-0000-4000-8000-000019538d3f''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d3f-0000-4000-8000-000019538d3f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', 'gjenmanager_A12A2', 'pin gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatte manager_A12 DELETE A3', 'delete from public.ansatte where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatte manager_A12 DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.skriv_avvist('ansatte manager_A12 FLYTTER egen rad A1 -> A3', 'update public.ansatte set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.skriv_avvist('ansatte manager_A12 FLYTTER egen rad -> kjede B', 'update public.ansatte set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ansatte tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'positiv');
select pg_temp.paastand('ansatte tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d3f-0000-4000-8000-000019538d3f'), 'negativ');
select pg_temp.paastand('ansatte tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d40-0000-4000-8000-000019538d40'), 'negativ');
select pg_temp.paastand('ansatte tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'negativ');
select pg_temp.skriv_avvist('ansatte tablet_A1 INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''tablet_A1A1'', ''pin tablet_A1A1'')');
select pg_temp.skriv_avvist('ansatte tablet_A1 INSERT A2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''tablet_A1A2'', ''pin tablet_A1A2'')');
select pg_temp.skriv_avvist('ansatte tablet_A1 INSERT A3', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', ''tablet_A1A3'', ''pin tablet_A1A3'')');
select pg_temp.skriv_avvist('ansatte tablet_A1 INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''tablet_A1B1'', ''pin tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 UPDATE A2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3f-0000-4000-8000-000019538d3f''', 'ansatte', '19538d3f-0000-4000-8000-000019538d3f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 UPDATE A3', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 DELETE A2', 'delete from public.ansatte where id = ''19538d3f-0000-4000-8000-000019538d3f''', 'ansatte', '19538d3f-0000-4000-8000-000019538d3f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 DELETE A3', 'delete from public.ansatte where id = ''19538d40-0000-4000-8000-000019538d40''', 'ansatte', '19538d40-0000-4000-8000-000019538d40', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatte tablet_A1 DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ansatte owner_B SELECT B1 -> ser', exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'positiv');
select pg_temp.paastand('ansatte owner_B SELECT B2 -> ser', exists (select 1 from public.ansatte where id = '19538d5e-0000-4000-8000-000019538d5e'), 'positiv');
select pg_temp.paastand('ansatte owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'negativ');
select pg_temp.skriv_tillatt('ansatte owner_B INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''owner_BB1'', ''pin owner_BB1'')');
select pg_temp.skriv_tillatt('ansatte owner_B INSERT B2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''owner_BB2'', ''pin owner_BB2'')');
select pg_temp.skriv_avvist('ansatte owner_B INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''owner_BA1'', ''pin owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatte owner_B UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatte owner_B UPDATE B2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5e-0000-4000-8000-000019538d5e''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatte owner_B UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatte owner_B DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d5d-0000-4000-8000-000019538d5d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'gjenowner_BB1', 'pin gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatte owner_B DELETE B2', 'delete from public.ansatte where id = ''19538d5e-0000-4000-8000-000019538d5e''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d5e-0000-4000-8000-000019538d5e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', 'gjenowner_BB2', 'pin gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatte owner_B DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.skriv_avvist('ansatte owner_B FLYTTER egen rad -> kjede A', 'update public.ansatte set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ansatte manager_B1 SELECT B1 -> ser', exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'positiv');
select pg_temp.paastand('ansatte manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5e-0000-4000-8000-000019538d5e'), 'negativ');
select pg_temp.paastand('ansatte manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'negativ');
select pg_temp.skriv_tillatt('ansatte manager_B1 INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_B1B1'', ''pin manager_B1B1'')');
select pg_temp.skriv_avvist('ansatte manager_B1 INSERT B2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''manager_B1B2'', ''pin manager_B1B2'')');
select pg_temp.skriv_avvist('ansatte manager_B1 INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''manager_B1A1'', ''pin manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatte manager_B1 UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatte manager_B1 UPDATE B2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5e-0000-4000-8000-000019538d5e''', 'ansatte', '19538d5e-0000-4000-8000-000019538d5e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatte manager_B1 UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatte manager_B1 DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''');
select pg_temp.som_eier();
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('19538d5d-0000-4000-8000-000019538d5d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', 'gjenmanager_B1B1', 'pin gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatte manager_B1 DELETE B2', 'delete from public.ansatte where id = ''19538d5e-0000-4000-8000-000019538d5e''', 'ansatte', '19538d5e-0000-4000-8000-000019538d5e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatte manager_B1 DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.skriv_avvist('ansatte manager_B1 FLYTTER egen rad B1 -> B2', 'update public.ansatte set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.skriv_avvist('ansatte manager_B1 FLYTTER egen rad -> kjede A', 'update public.ansatte set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ansatte tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ansatte where id = '19538d5d-0000-4000-8000-000019538d5d'), 'positiv');
select pg_temp.paastand('ansatte tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d5e-0000-4000-8000-000019538d5e'), 'negativ');
select pg_temp.paastand('ansatte tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatte where id = '19538d3e-0000-4000-8000-000019538d3e'), 'negativ');
select pg_temp.skriv_avvist('ansatte tablet_B1 INSERT B1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''tablet_B1B1'', ''pin tablet_B1B1'')');
select pg_temp.skriv_avvist('ansatte tablet_B1 INSERT B2', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', ''tablet_B1B2'', ''pin tablet_B1B2'')');
select pg_temp.skriv_avvist('ansatte tablet_B1 INSERT A1', 'insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', ''tablet_B1A1'', ''pin tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 UPDATE B1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 UPDATE B2', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d5e-0000-4000-8000-000019538d5e''', 'ansatte', '19538d5e-0000-4000-8000-000019538d5e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 UPDATE A1', 'update public.ansatte set navn = ''Endret av sonden'' where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 DELETE B1', 'delete from public.ansatte where id = ''19538d5d-0000-4000-8000-000019538d5d''', 'ansatte', '19538d5d-0000-4000-8000-000019538d5d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 DELETE B2', 'delete from public.ansatte where id = ''19538d5e-0000-4000-8000-000019538d5e''', 'ansatte', '19538d5e-0000-4000-8000-000019538d5e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatte('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatte tablet_B1 DELETE A1', 'delete from public.ansatte where id = ''19538d3e-0000-4000-8000-000019538d3e''', 'ansatte', '19538d3e-0000-4000-8000-000019538d3e', 'id');

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
-- tablet_meldinger  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tablet_meldinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tablet_meldinger owner_A SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT A2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT A3 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AA1'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_AA2'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding owner_AA3'')');
select pg_temp.skriv_avvist('tablet_meldinger owner_A INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tablet_meldinger owner_A UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_A DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadc-0000-4000-8000-0000d7d6fadc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tablet_meldinger owner_A DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1A1'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A1A2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A1A3'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger manager_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tablet_meldinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12A1'')');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A12A2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A12A3'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fada-0000-4000-8000-0000d7d6fada', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tablet_meldinger manager_A12 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fadb-0000-4000-8000-0000d7d6fadb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger manager_A12 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tablet_meldinger set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadb-0000-4000-8000-0000d7d6fadb'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fadc-0000-4000-8000-0000d7d6fadc'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1A1'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_A1A2'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT A3', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding tablet_A1A3'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE A3', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A2', 'delete from public.tablet_meldinger where id = ''d7d6fadb-0000-4000-8000-0000d7d6fadb''', 'tablet_meldinger', 'd7d6fadb-0000-4000-8000-0000d7d6fadb', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE A3', 'delete from public.tablet_meldinger where id = ''d7d6fadc-0000-4000-8000-0000d7d6fadc''', 'tablet_meldinger', 'd7d6fadc-0000-4000-8000-0000d7d6fadc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_A1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.paastand('tablet_meldinger tablet_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tablet_meldinger owner_B SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B SELECT B2 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BB1'')');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_BB2'')');
select pg_temp.skriv_avvist('tablet_meldinger owner_B INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tablet_meldinger owner_B UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tablet_meldinger owner_B DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6fafa-0000-4000-8000-0000d7d6fafa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tablet_meldinger owner_B DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'negativ');
select pg_temp.paastand('tablet_meldinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1B1'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_B1B2'')');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tablet_meldinger manager_B1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''');
select pg_temp.som_eier();
insert into public.tablet_meldinger (id, retailer_id, stasjon_id, tekst) values ('d7d6faf9-0000-4000-8000-0000d7d6faf9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger manager_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tablet_meldinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tablet_meldinger where id = 'd7d6faf9-0000-4000-8000-0000d7d6faf9'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fafa-0000-4000-8000-0000d7d6fafa'), 'negativ');
select pg_temp.paastand('tablet_meldinger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tablet_meldinger where id = 'd7d6fada-0000-4000-8000-0000d7d6fada'), 'negativ');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT B1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1B1'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT B2', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_B1B2'')');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 INSERT A1', 'insert into public.tablet_meldinger (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE B1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE B2', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 UPDATE A1', 'update public.tablet_meldinger set viktig = true where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE B1', 'delete from public.tablet_meldinger where id = ''d7d6faf9-0000-4000-8000-0000d7d6faf9''', 'tablet_meldinger', 'd7d6faf9-0000-4000-8000-0000d7d6faf9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE B2', 'delete from public.tablet_meldinger where id = ''d7d6fafa-0000-4000-8000-0000d7d6fafa''', 'tablet_meldinger', 'd7d6fafa-0000-4000-8000-0000d7d6fafa', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tablet_meldinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tablet_meldinger tablet_B1 DELETE A1', 'delete from public.tablet_meldinger where id = ''d7d6fada-0000-4000-8000-0000d7d6fada''', 'tablet_meldinger', 'd7d6fada-0000-4000-8000-0000d7d6fada', 'id');
select pg_temp.paastand('tablet_meldinger tablet_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.tablet_meldinger where id = '80f0b8e2-0000-4000-8000-000080f0b8e2'), 'positiv');
select pg_temp.paastand('tablet_meldinger tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.tablet_meldinger where id = '80f0b8e1-0000-4000-8000-000080f0b8e1'), 'negativ');

-- =====================================================================
-- produksjonsplan_hode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_hode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 296)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 297)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 298)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 299)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 300);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 301);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 302);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 303)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 304)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 305)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 306)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 307);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 308)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 309)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 310)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 311)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 312);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 313);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 314)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 315)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 316)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 317)');
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 318)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 319)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 320)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 321);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 322);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 323)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 324)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 325)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 326);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 327)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 328)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 329)');
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
    raise exception 'TENANT-MATRISEN DEL 3/4: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 3/4: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
