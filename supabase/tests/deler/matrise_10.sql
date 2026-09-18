-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 10 AV 11. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av 10 ressurs(er):
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
insert into public.merker (id, retailer_id, navn) values ('7589c162-0000-4000-8000-00007589c162', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 22');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c48aead-0000-4000-8000-00004c48aead', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-22', 'pin-merke-22');
insert into public.merker (id, retailer_id, navn) values ('758a35c2-0000-4000-8000-0000758a35c2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 23');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49230d-0000-4000-8000-00004c49230d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-23', 'pin-merke-23');
insert into public.merker (id, retailer_id, navn) values ('758aaa22-0000-4000-8000-0000758aaa22', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 24');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c49976d-0000-4000-8000-00004c49976d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-24', 'pin-merke-24');
insert into public.merker (id, retailer_id, navn) values ('7597d8e6-0000-4000-8000-00007597d8e6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 25');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c56c631-0000-4000-8000-00004c56c631', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-25', 'pin-merke-25');
insert into public.merker (id, retailer_id, navn) values ('75984d46-0000-4000-8000-000075984d46', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 26');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('4c573a91-0000-4000-8000-00004c573a91', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-26', 'pin-merke-26');
insert into auth.users (id, email) values ('17a2521d-0000-4000-8000-000017a2521d', 'sonde-42@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('17a2521d-0000-4000-8000-000017a2521d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 42');
insert into auth.users (id, email) values ('17a2c67d-0000-4000-8000-000017a2c67d', 'sonde-43@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('17a2c67d-0000-4000-8000-000017a2c67d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 43');
insert into auth.users (id, email) values ('17a33add-0000-4000-8000-000017a33add', 'sonde-44@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('17a33add-0000-4000-8000-000017a33add', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 44');
insert into auth.users (id, email) values ('17b069a1-0000-4000-8000-000017b069a1', 'sonde-45@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('17b069a1-0000-4000-8000-000017b069a1', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 45');
insert into auth.users (id, email) values ('17b0de01-0000-4000-8000-000017b0de01', 'sonde-46@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('17b0de01-0000-4000-8000-000017b0de01', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 46');
insert into public.merker (id, retailer_id, navn) values ('3bae678c-0000-4000-8000-00003bae678c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 141');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23a1-0000-4000-8000-00003ccd23a1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-141', 'pin-merke-141');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f0e-0000-4000-8000-00003bbc7f0e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 142');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b23-0000-4000-8000-00003cdb3b23', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-142', 'pin-merke-142');
insert into public.merker (id, retailer_id, navn) values ('3bca9690-0000-4000-8000-00003bca9690', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 143');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce952a5-0000-4000-8000-00003ce952a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-143', 'pin-merke-143');
insert into public.merker (id, retailer_id, navn) values ('3d63402e-0000-4000-8000-00003d63402e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 144');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc43-0000-4000-8000-00003e81fc43', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-144', 'pin-merke-144');
insert into public.merker (id, retailer_id, navn) values ('3bae6790-0000-4000-8000-00003bae6790', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 145');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23a5-0000-4000-8000-00003ccd23a5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-145', 'pin-merke-145');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f12-0000-4000-8000-00003bbc7f12', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 146');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b27-0000-4000-8000-00003cdb3b27', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-146', 'pin-merke-146');
insert into public.merker (id, retailer_id, navn) values ('3bca9694-0000-4000-8000-00003bca9694', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 147');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce952a9-0000-4000-8000-00003ce952a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-147', 'pin-merke-147');
insert into public.merker (id, retailer_id, navn) values ('3bae6793-0000-4000-8000-00003bae6793', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 148');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23a8-0000-4000-8000-00003ccd23a8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-148', 'pin-merke-148');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f15-0000-4000-8000-00003bbc7f15', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 149');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b2a-0000-4000-8000-00003cdb3b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-149', 'pin-merke-149');
insert into public.merker (id, retailer_id, navn) values ('3bca96ac-0000-4000-8000-00003bca96ac', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 150');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce952c1-0000-4000-8000-00003ce952c1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-150', 'pin-merke-150');
insert into public.merker (id, retailer_id, navn) values ('3d63404a-0000-4000-8000-00003d63404a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 151');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc5f-0000-4000-8000-00003e81fc5f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-151', 'pin-merke-151');
insert into public.merker (id, retailer_id, navn) values ('3bae67ac-0000-4000-8000-00003bae67ac', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 152');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23c1-0000-4000-8000-00003ccd23c1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-152', 'pin-merke-152');
insert into public.merker (id, retailer_id, navn) values ('3bae67ad-0000-4000-8000-00003bae67ad', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 153');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23c2-0000-4000-8000-00003ccd23c2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-153', 'pin-merke-153');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f2f-0000-4000-8000-00003bbc7f2f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 154');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b44-0000-4000-8000-00003cdb3b44', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-154', 'pin-merke-154');
insert into public.merker (id, retailer_id, navn) values ('3bca96b1-0000-4000-8000-00003bca96b1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 155');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce952c6-0000-4000-8000-00003ce952c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-155', 'pin-merke-155');
insert into public.merker (id, retailer_id, navn) values ('3d63404f-0000-4000-8000-00003d63404f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 156');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc64-0000-4000-8000-00003e81fc64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-156', 'pin-merke-156');
insert into public.merker (id, retailer_id, navn) values ('3bae67b1-0000-4000-8000-00003bae67b1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 157');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23c6-0000-4000-8000-00003ccd23c6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-157', 'pin-merke-157');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f33-0000-4000-8000-00003bbc7f33', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 158');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b48-0000-4000-8000-00003cdb3b48', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-158', 'pin-merke-158');
insert into public.merker (id, retailer_id, navn) values ('3bae67b3-0000-4000-8000-00003bae67b3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 159');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23c8-0000-4000-8000-00003ccd23c8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-159', 'pin-merke-159');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f4a-0000-4000-8000-00003bbc7f4a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 160');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3cdb3b5f-0000-4000-8000-00003cdb3b5f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-160', 'pin-merke-160');
insert into public.merker (id, retailer_id, navn) values ('3bca96cc-0000-4000-8000-00003bca96cc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 161');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ce952e1-0000-4000-8000-00003ce952e1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'merke-161', 'pin-merke-161');
insert into public.merker (id, retailer_id, navn) values ('3d63406a-0000-4000-8000-00003d63406a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 162');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc7f-0000-4000-8000-00003e81fc7f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-162', 'pin-merke-162');
insert into public.merker (id, retailer_id, navn) values ('3d63406b-0000-4000-8000-00003d63406b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 163');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc80-0000-4000-8000-00003e81fc80', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-163', 'pin-merke-163');
insert into public.merker (id, retailer_id, navn) values ('3d7157ed-0000-4000-8000-00003d7157ed', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 164');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e901402-0000-4000-8000-00003e901402', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-164', 'pin-merke-164');
insert into public.merker (id, retailer_id, navn) values ('3bae67ce-0000-4000-8000-00003bae67ce', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 165');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23e3-0000-4000-8000-00003ccd23e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-165', 'pin-merke-165');
insert into public.merker (id, retailer_id, navn) values ('3d63406e-0000-4000-8000-00003d63406e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 166');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc83-0000-4000-8000-00003e81fc83', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-166', 'pin-merke-166');
insert into public.merker (id, retailer_id, navn) values ('3d7157f0-0000-4000-8000-00003d7157f0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 167');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e901405-0000-4000-8000-00003e901405', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-167', 'pin-merke-167');
insert into public.merker (id, retailer_id, navn) values ('3d634070-0000-4000-8000-00003d634070', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 168');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc85-0000-4000-8000-00003e81fc85', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-168', 'pin-merke-168');
insert into public.merker (id, retailer_id, navn) values ('3d7157f2-0000-4000-8000-00003d7157f2', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 169');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e901407-0000-4000-8000-00003e901407', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-169', 'pin-merke-169');
insert into public.merker (id, retailer_id, navn) values ('3bae67e8-0000-4000-8000-00003bae67e8', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 170');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd23fd-0000-4000-8000-00003ccd23fd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-170', 'pin-merke-170');
insert into public.merker (id, retailer_id, navn) values ('3d634088-0000-4000-8000-00003d634088', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 171');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc9d-0000-4000-8000-00003e81fc9d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-171', 'pin-merke-171');
insert into public.merker (id, retailer_id, navn) values ('3d634089-0000-4000-8000-00003d634089', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 172');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e81fc9e-0000-4000-8000-00003e81fc9e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-172', 'pin-merke-172');
insert into public.merker (id, retailer_id, navn) values ('3d71580b-0000-4000-8000-00003d71580b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 173');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3e901420-0000-4000-8000-00003e901420', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'merke-173', 'pin-merke-173');
insert into public.merker (id, retailer_id, navn) values ('3bae67ec-0000-4000-8000-00003bae67ec', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 174');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values ('3ccd2401-0000-4000-8000-00003ccd2401', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'merke-174', 'pin-merke-174');
-- --- stotte_tilgang: forutsetninger og proberader ---
insert into public.stotte_tilgang (id, retailer_id, gitt_til, begrunnelse, til_tid) values ('c3b5da56-0000-4000-8000-0000c3b5da56', 'aaaa0000-0000-4000-8000-000000000000', '00000000-0000-0000-0000-00000000a000', 'sonde fastA1 - feilsoeking', now() + interval '1 hour');
insert into public.stotte_tilgang (id, retailer_id, gitt_til, begrunnelse, til_tid) values ('c3b5da57-0000-4000-8000-0000c3b5da57', 'aaaa0000-0000-4000-8000-000000000000', '00000000-0000-0000-0000-00000000a000', 'sonde fastA2 - feilsoeking', now() + interval '1 hour');
insert into public.stotte_tilgang (id, retailer_id, gitt_til, begrunnelse, til_tid) values ('c3b5da58-0000-4000-8000-0000c3b5da58', 'aaaa0000-0000-4000-8000-000000000000', '00000000-0000-0000-0000-00000000a000', 'sonde fastA3 - feilsoeking', now() + interval '1 hour');
insert into public.stotte_tilgang (id, retailer_id, gitt_til, begrunnelse, til_tid) values ('c3b5da75-0000-4000-8000-0000c3b5da75', 'bbbb0000-0000-4000-8000-000000000000', '00000000-0000-0000-0000-00000000b000', 'sonde fastB1 - feilsoeking', now() + interval '1 hour');
insert into public.stotte_tilgang (id, retailer_id, gitt_til, begrunnelse, til_tid) values ('c3b5da76-0000-4000-8000-0000c3b5da76', 'bbbb0000-0000-4000-8000-000000000000', '00000000-0000-0000-0000-00000000b000', 'sonde fastB2 - feilsoeking', now() + interval '1 hour');
-- --- synlig_svinn: forutsetninger og proberader ---
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 5, 'fastA1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 6, 'fastA2', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 7, 'fastA3', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 8, 'fastB1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 9, 'fastB2', 'Sondevare', 1, 25);

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
-- --- tildelte_merker: forutsetninger og proberader ---
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c162-0000-4000-8000-00007589c162', '4c48aead-0000-4000-8000-00004c48aead', date '2026-01-01' + 22);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a35c2-0000-4000-8000-0000758a35c2', '4c49230d-0000-4000-8000-00004c49230d', date '2026-01-01' + 23);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa22-0000-4000-8000-0000758aaa22', '4c49976d-0000-4000-8000-00004c49976d', date '2026-01-01' + 24);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d8e6-0000-4000-8000-00007597d8e6', '4c56c631-0000-4000-8000-00004c56c631', date '2026-01-01' + 25);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984d46-0000-4000-8000-000075984d46', '4c573a91-0000-4000-8000-00004c573a91', date '2026-01-01' + 26);

create or replace function pg_temp.nyrad_tildelte_merker(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_merke uuid := gen_random_uuid();
  v_ansatt uuid := gen_random_uuid();
begin
  insert into public.merker (id, retailer_id, navn) values (v_merke, p_retailer, 'Sondemerke ' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values (v_ansatt, p_retailer, p_stasjon, 'Sondeansatt', 'merke-' || 'rt' || nextval('tenant_teller'::regclass) || '', 'pin-merke-' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato)
  values (p_stasjon, v_merke, v_ansatt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- timesalg: forutsetninger og proberader ---
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 27, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 28, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 29, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30, '8-9', 1000, 10);
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31, '8-9', 1000, 10);

create or replace function pg_temp.nyrad_timesalg(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '8-9', 1000, 10);
end $fn$;
-- --- trafikk: forutsetninger og proberader ---
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 32, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 33, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 34, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 1000, 80);
insert into public.trafikk (stasjon_id, dato, antall_kjoretoy, dekning_pst) values ('b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 1000, 80);
-- --- uke_rapport: forutsetninger og proberader ---
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 37);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 38);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 39);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 40);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 41);

create or replace function pg_temp.nyrad_uke_rapport(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- ukebrief_utsending: forutsetninger og proberader ---
insert into public.ukebrief_utsending (id, retailer_id, stasjon_id, uke_mandag, profil_id, status) values ('4a78b95b-0000-4000-8000-00004a78b95b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 42, '17a2521d-0000-4000-8000-000017a2521d', 'sendt');
insert into public.ukebrief_utsending (id, retailer_id, stasjon_id, uke_mandag, profil_id, status) values ('4a78b95c-0000-4000-8000-00004a78b95c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 43, '17a2c67d-0000-4000-8000-000017a2c67d', 'sendt');
insert into public.ukebrief_utsending (id, retailer_id, stasjon_id, uke_mandag, profil_id, status) values ('4a78b95d-0000-4000-8000-00004a78b95d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 44, '17a33add-0000-4000-8000-000017a33add', 'sendt');
insert into public.ukebrief_utsending (id, retailer_id, stasjon_id, uke_mandag, profil_id, status) values ('4a78b97a-0000-4000-8000-00004a78b97a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 45, '17b069a1-0000-4000-8000-000017b069a1', 'sendt');
insert into public.ukebrief_utsending (id, retailer_id, stasjon_id, uke_mandag, profil_id, status) values ('4a78b97b-0000-4000-8000-00004a78b97b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 46, '17b0de01-0000-4000-8000-000017b0de01', 'sendt');
-- --- vaer: forutsetninger og proberader ---
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 47);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 48);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 49);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 50);
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 51);

create or replace function pg_temp.nyrad_vaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.vaer (stasjon_id, dato)
  values (p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- stotte_tilgang  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stotte_tilgang');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stotte_tilgang owner_A SELECT A -> ser', exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'positiv');
select pg_temp.paastand('stotte_tilgang owner_A SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stotte_tilgang manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');
select pg_temp.paastand('stotte_tilgang manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stotte_tilgang manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');
select pg_temp.paastand('stotte_tilgang manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stotte_tilgang tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');
select pg_temp.paastand('stotte_tilgang tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stotte_tilgang owner_B SELECT B -> ser', exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'positiv');
select pg_temp.paastand('stotte_tilgang owner_B SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stotte_tilgang manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');
select pg_temp.paastand('stotte_tilgang manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stotte_tilgang tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da75-0000-4000-8000-0000c3b5da75'), 'negativ');
select pg_temp.paastand('stotte_tilgang tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.stotte_tilgang where id = 'c3b5da56-0000-4000-8000-0000c3b5da56'), 'negativ');

-- =====================================================================
-- synlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('synlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('synlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 52, ''owner_AA1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 53, ''owner_AA2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 54, ''owner_AA3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_A INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 55, ''owner_AB1'', ''Sondevare'', 1, 25)');
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
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 56, 'gjenowner_AA1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 57, 'gjenowner_AA2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 58, 'gjenowner_AA3', 'Sondevare', 1, 25);
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
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 59, ''manager_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 60, ''manager_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 61, ''manager_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 62, ''manager_A1B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 63, ''manager_A12A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 64, ''manager_A12A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 65, ''manager_A12A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 66, ''manager_A12B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 67, ''tablet_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 68, ''tablet_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 69, ''tablet_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 70, ''tablet_A1B1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 71, ''owner_BB1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 72, ''owner_BB2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_B INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 73, ''owner_BA1'', ''Sondevare'', 1, 25)');
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
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 74, 'gjenowner_BB1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 75, 'gjenowner_BB2', 'Sondevare', 1, 25);
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
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 76, ''manager_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 77, ''manager_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 78, ''manager_B1A1'', ''Sondevare'', 1, 25)');
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
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 79, ''tablet_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 80, ''tablet_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 81, ''tablet_B1A1'', ''Sondevare'', 1, 25)');
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
-- tildelte_merker  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tildelte_merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tildelte_merker owner_A SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A3 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae678c-0000-4000-8000-00003bae678c'', ''3ccd23a1-0000-4000-8000-00003ccd23a1'', date ''2026-01-01'' + 141)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f0e-0000-4000-8000-00003bbc7f0e'', ''3cdb3b23-0000-4000-8000-00003cdb3b23'', date ''2026-01-01'' + 142)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9690-0000-4000-8000-00003bca9690'', ''3ce952a5-0000-4000-8000-00003ce952a5'', date ''2026-01-01'' + 143)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63402e-0000-4000-8000-00003d63402e'', ''3e81fc43-0000-4000-8000-00003e81fc43'', date ''2026-01-01'' + 144)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6790-0000-4000-8000-00003bae6790', '3ccd23a5-0000-4000-8000-00003ccd23a5', date '2026-01-01' + 145);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc7f12-0000-4000-8000-00003bbc7f12', '3cdb3b27-0000-4000-8000-00003cdb3b27', date '2026-01-01' + 146);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '3bca9694-0000-4000-8000-00003bca9694', '3ce952a9-0000-4000-8000-00003ce952a9', date '2026-01-01' + 147);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae6793-0000-4000-8000-00003bae6793'', ''3ccd23a8-0000-4000-8000-00003ccd23a8'', date ''2026-01-01'' + 148)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f15-0000-4000-8000-00003bbc7f15'', ''3cdb3b2a-0000-4000-8000-00003cdb3b2a'', date ''2026-01-01'' + 149)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96ac-0000-4000-8000-00003bca96ac'', ''3ce952c1-0000-4000-8000-00003ce952c1'', date ''2026-01-01'' + 150)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63404a-0000-4000-8000-00003d63404a'', ''3e81fc5f-0000-4000-8000-00003e81fc5f'', date ''2026-01-01'' + 151)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae67ac-0000-4000-8000-00003bae67ac', '3ccd23c1-0000-4000-8000-00003ccd23c1', date '2026-01-01' + 152);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67ad-0000-4000-8000-00003bae67ad'', ''3ccd23c2-0000-4000-8000-00003ccd23c2'', date ''2026-01-01'' + 153)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f2f-0000-4000-8000-00003bbc7f2f'', ''3cdb3b44-0000-4000-8000-00003cdb3b44'', date ''2026-01-01'' + 154)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96b1-0000-4000-8000-00003bca96b1'', ''3ce952c6-0000-4000-8000-00003ce952c6'', date ''2026-01-01'' + 155)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63404f-0000-4000-8000-00003d63404f'', ''3e81fc64-0000-4000-8000-00003e81fc64'', date ''2026-01-01'' + 156)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae67b1-0000-4000-8000-00003bae67b1', '3ccd23c6-0000-4000-8000-00003ccd23c6', date '2026-01-01' + 157);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc7f33-0000-4000-8000-00003bbc7f33', '3cdb3b48-0000-4000-8000-00003cdb3b48', date '2026-01-01' + 158);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67b3-0000-4000-8000-00003bae67b3'', ''3ccd23c8-0000-4000-8000-00003ccd23c8'', date ''2026-01-01'' + 159)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f4a-0000-4000-8000-00003bbc7f4a'', ''3cdb3b5f-0000-4000-8000-00003cdb3b5f'', date ''2026-01-01'' + 160)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96cc-0000-4000-8000-00003bca96cc'', ''3ce952e1-0000-4000-8000-00003ce952e1'', date ''2026-01-01'' + 161)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63406a-0000-4000-8000-00003d63406a'', ''3e81fc7f-0000-4000-8000-00003e81fc7f'', date ''2026-01-01'' + 162)');
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
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63406b-0000-4000-8000-00003d63406b'', ''3e81fc80-0000-4000-8000-00003e81fc80'', date ''2026-01-01'' + 163)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d7157ed-0000-4000-8000-00003d7157ed'', ''3e901402-0000-4000-8000-00003e901402'', date ''2026-01-01'' + 164)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67ce-0000-4000-8000-00003bae67ce'', ''3ccd23e3-0000-4000-8000-00003ccd23e3'', date ''2026-01-01'' + 165)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d63406e-0000-4000-8000-00003d63406e', '3e81fc83-0000-4000-8000-00003e81fc83', date '2026-01-01' + 166);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '3d7157f0-0000-4000-8000-00003d7157f0', '3e901405-0000-4000-8000-00003e901405', date '2026-01-01' + 167);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634070-0000-4000-8000-00003d634070'', ''3e81fc85-0000-4000-8000-00003e81fc85'', date ''2026-01-01'' + 168)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d7157f2-0000-4000-8000-00003d7157f2'', ''3e901407-0000-4000-8000-00003e901407'', date ''2026-01-01'' + 169)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67e8-0000-4000-8000-00003bae67e8'', ''3ccd23fd-0000-4000-8000-00003ccd23fd'', date ''2026-01-01'' + 170)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d634088-0000-4000-8000-00003d634088', '3e81fc9d-0000-4000-8000-00003e81fc9d', date '2026-01-01' + 171);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634089-0000-4000-8000-00003d634089'', ''3e81fc9e-0000-4000-8000-00003e81fc9e'', date ''2026-01-01'' + 172)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d71580b-0000-4000-8000-00003d71580b'', ''3e901420-0000-4000-8000-00003e901420'', date ''2026-01-01'' + 173)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67ec-0000-4000-8000-00003bae67ec'', ''3ccd2401-0000-4000-8000-00003ccd2401'', date ''2026-01-01'' + 174)');
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
-- timesalg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('timesalg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('timesalg owner_A SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT A3 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 175, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 176, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_A INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 177, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_A INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 178, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 27, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 28, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('timesalg owner_A DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 29, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('timesalg owner_A DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_A FLYTTER egen rad -> kjede B', 'update public.timesalg set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('timesalg manager_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 179, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 180, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 181, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 182, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('timesalg manager_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('timesalg manager_A12 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 183, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 184, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 185, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_A12 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 186, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('timesalg manager_A12 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('timesalg tablet_A1 SELECT A1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 28 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 29 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 187, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 188, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT A3', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 189, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_A1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 190, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE A3', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A2', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 28 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE A3', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 29 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('timesalg tablet_A1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('timesalg owner_B SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT B2 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 191, ''8-9'', 1000, 10)');
select pg_temp.skriv_tillatt('timesalg owner_B INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 192, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg owner_B INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 193, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('timesalg owner_B DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31, '8-9', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('timesalg owner_B DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.skriv_avvist_pred('timesalg owner_B FLYTTER egen rad -> kjede A', 'update public.timesalg set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('timesalg manager_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 194, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 195, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg manager_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 196, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('timesalg manager_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('timesalg tablet_B1 SELECT B1 -> ser', exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 30 and "time" = '8-9'), 'positiv');
select pg_temp.paastand('timesalg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 31 and "time" = '8-9'), 'negativ');
select pg_temp.paastand('timesalg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.timesalg where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 27 and "time" = '8-9'), 'negativ');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 197, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT B2', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 198, ''8-9'', 1000, 10)');
select pg_temp.skriv_avvist('timesalg tablet_B1 INSERT A1', 'insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 199, ''8-9'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE B2', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 UPDATE A1', 'update public.timesalg set antall_kunder = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B1', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 30 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE B2', 'delete from public.timesalg where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 31 and "time" = ''8-9''');
select pg_temp.som_eier();
select pg_temp.nyrad_timesalg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('timesalg tablet_B1 DELETE A1', 'delete from public.timesalg where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''', 'timesalg', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 27 and "time" = ''8-9''');

-- =====================================================================
-- trafikk  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('trafikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('trafikk owner_A SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT A3 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34), 'positiv');
select pg_temp.paastand('trafikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('trafikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'positiv');
select pg_temp.paastand('trafikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34), 'negativ');
select pg_temp.paastand('trafikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('trafikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33), 'positiv');
select pg_temp.paastand('trafikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34), 'negativ');
select pg_temp.paastand('trafikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('trafikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'positiv');
select pg_temp.paastand('trafikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34), 'negativ');
select pg_temp.paastand('trafikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('trafikk owner_B SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT B2 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'positiv');
select pg_temp.paastand('trafikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('trafikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'negativ');
select pg_temp.paastand('trafikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('trafikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35), 'positiv');
select pg_temp.paastand('trafikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36), 'negativ');
select pg_temp.paastand('trafikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.trafikk where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32), 'negativ');

-- =====================================================================
-- uke_rapport  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('uke_rapport');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('uke_rapport owner_A SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A3 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 200)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 201)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 202)');
select pg_temp.skriv_avvist('uke_rapport owner_A INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 203)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('uke_rapport owner_A UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 204);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 205);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 206);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('uke_rapport owner_A DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport owner_A FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('uke_rapport manager_A1 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 207)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 208)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 209)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 210)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('uke_rapport manager_A1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 211);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('uke_rapport manager_A1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A1 FLYTTER egen rad A1 -> A2', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A1 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('uke_rapport manager_A12 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A12 SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 212)');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 213)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 214)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 215)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 216);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 217);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('uke_rapport manager_A12 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A12 FLYTTER egen rad A1 -> A3', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_A12 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 218)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 219)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 220)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 221)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE A2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE A3', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''', 'uke_rapport', 'cf7838e7-0000-4000-8000-0000cf7838e7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''', 'uke_rapport', 'cf7838e8-0000-4000-8000-0000cf7838e8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.uke_rapport set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 FLYTTER egen rad -> kjede B', 'update public.uke_rapport set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('uke_rapport owner_B SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport owner_B SELECT B2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'positiv');
select pg_temp.paastand('uke_rapport owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 222)');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 223)');
select pg_temp.skriv_avvist('uke_rapport owner_B INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 224)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('uke_rapport owner_B UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 225);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 226);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('uke_rapport owner_B DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport owner_B FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('uke_rapport manager_B1 SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'negativ');
select pg_temp.paastand('uke_rapport manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 227)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 228)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 229)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('uke_rapport manager_B1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 230);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('uke_rapport manager_B1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_B1 FLYTTER egen rad B1 -> B2', 'update public.uke_rapport set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport manager_B1 FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('uke_rapport tablet_B1 SELECT B1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'positiv');
select pg_temp.paastand('uke_rapport tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783906-0000-4000-8000-0000cf783906'), 'negativ');
select pg_temp.paastand('uke_rapport tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 231)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 232)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 233)');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 UPDATE B1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 UPDATE B2', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 UPDATE A1', 'update public.uke_rapport set avdelinger = ''[]''::jsonb where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''', 'uke_rapport', 'cf783906-0000-4000-8000-0000cf783906', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''', 'uke_rapport', 'cf7838e6-0000-4000-8000-0000cf7838e6', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.uke_rapport set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 FLYTTER egen rad -> kjede A', 'update public.uke_rapport set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''cf783905-0000-4000-8000-0000cf783905''', 'uke_rapport', 'cf783905-0000-4000-8000-0000cf783905', 'id');

-- =====================================================================
-- ukebrief_utsending  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ukebrief_utsending');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ukebrief_utsending owner_A SELECT A1 -> ser', exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'positiv');
select pg_temp.paastand('ukebrief_utsending owner_A SELECT A2 -> ser', exists (select 1 from public.ukebrief_utsending where id = '4a78b95c-0000-4000-8000-00004a78b95c'), 'positiv');
select pg_temp.paastand('ukebrief_utsending owner_A SELECT A3 -> ser', exists (select 1 from public.ukebrief_utsending where id = '4a78b95d-0000-4000-8000-00004a78b95d'), 'positiv');
select pg_temp.paastand('ukebrief_utsending owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ukebrief_utsending manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95c-0000-4000-8000-00004a78b95c'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95d-0000-4000-8000-00004a78b95d'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ukebrief_utsending manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95c-0000-4000-8000-00004a78b95c'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95d-0000-4000-8000-00004a78b95d'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ukebrief_utsending tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');
select pg_temp.paastand('ukebrief_utsending tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95c-0000-4000-8000-00004a78b95c'), 'negativ');
select pg_temp.paastand('ukebrief_utsending tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95d-0000-4000-8000-00004a78b95d'), 'negativ');
select pg_temp.paastand('ukebrief_utsending tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ukebrief_utsending owner_B SELECT B1 -> ser', exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'positiv');
select pg_temp.paastand('ukebrief_utsending owner_B SELECT B2 -> ser', exists (select 1 from public.ukebrief_utsending where id = '4a78b97b-0000-4000-8000-00004a78b97b'), 'positiv');
select pg_temp.paastand('ukebrief_utsending owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ukebrief_utsending manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97b-0000-4000-8000-00004a78b97b'), 'negativ');
select pg_temp.paastand('ukebrief_utsending manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ukebrief_utsending tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97a-0000-4000-8000-00004a78b97a'), 'negativ');
select pg_temp.paastand('ukebrief_utsending tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b97b-0000-4000-8000-00004a78b97b'), 'negativ');
select pg_temp.paastand('ukebrief_utsending tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ukebrief_utsending where id = '4a78b95b-0000-4000-8000-00004a78b95b'), 'negativ');

-- =====================================================================
-- vaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('vaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('vaer owner_A SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT A2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT A3 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'positiv');
select pg_temp.paastand('vaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 234)');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 235)');
select pg_temp.skriv_tillatt('vaer owner_A INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 236)');
select pg_temp.skriv_avvist('vaer owner_A INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 237)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('vaer owner_A UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 238);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 239);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('vaer owner_A DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 240);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('vaer owner_A DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('vaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'negativ');
select pg_temp.paastand('vaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 241)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 242)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 243)');
select pg_temp.skriv_avvist('vaer manager_A1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 244)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('vaer manager_A1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('vaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'positiv');
select pg_temp.paastand('vaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 245)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 246)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 247)');
select pg_temp.skriv_avvist('vaer manager_A12 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 248)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('vaer manager_A12 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('vaer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'positiv');
select pg_temp.paastand('vaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d'), 'negativ');
select pg_temp.paastand('vaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e'), 'negativ');
select pg_temp.paastand('vaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'negativ');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 249)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A2', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 250)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT A3', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 251)');
select pg_temp.skriv_avvist('vaer tablet_A1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 252)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE A3', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A2', 'delete from public.vaer where id = ''a6cd0b0d-0000-4000-8000-0000a6cd0b0d''', 'vaer', 'a6cd0b0d-0000-4000-8000-0000a6cd0b0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE A3', 'delete from public.vaer where id = ''a6cd0b0e-0000-4000-8000-0000a6cd0b0e''', 'vaer', 'a6cd0b0e-0000-4000-8000-0000a6cd0b0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('vaer tablet_A1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('vaer owner_B SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer owner_B SELECT B2 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'positiv');
select pg_temp.paastand('vaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_tillatt('vaer owner_B INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 253)');
select pg_temp.skriv_tillatt('vaer owner_B INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 254)');
select pg_temp.skriv_avvist('vaer owner_B INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 255)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('vaer owner_B UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 256);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('vaer owner_B DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''');
select pg_temp.som_eier();
insert into public.vaer (id, stasjon_id, dato) values ('a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 257);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('vaer owner_B DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('vaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'negativ');
select pg_temp.paastand('vaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 258)');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_avvist('vaer manager_B1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 260)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('vaer manager_B1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('vaer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.vaer where id = 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b'), 'positiv');
select pg_temp.paastand('vaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c'), 'negativ');
select pg_temp.paastand('vaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.vaer where id = 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c'), 'negativ');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT B1', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 261)');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT B2', 'insert into public.vaer (stasjon_id, dato) values (''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 262)');
select pg_temp.skriv_avvist('vaer tablet_B1 INSERT A1', 'insert into public.vaer (stasjon_id, dato) values (''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 263)');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE B1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE B2', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 UPDATE A1', 'update public.vaer set hentet_tid = now() where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE B1', 'delete from public.vaer where id = ''a6cd0b2b-0000-4000-8000-0000a6cd0b2b''', 'vaer', 'a6cd0b2b-0000-4000-8000-0000a6cd0b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE B2', 'delete from public.vaer where id = ''a6cd0b2c-0000-4000-8000-0000a6cd0b2c''', 'vaer', 'a6cd0b2c-0000-4000-8000-0000a6cd0b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_vaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('vaer tablet_B1 DELETE A1', 'delete from public.vaer where id = ''a6cd0b0c-0000-4000-8000-0000a6cd0b0c''', 'vaer', 'a6cd0b0c-0000-4000-8000-0000a6cd0b0c', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 10/11: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 10/11: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
