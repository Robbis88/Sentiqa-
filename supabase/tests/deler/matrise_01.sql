-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 1 AV 6. Hele matrisen er for stor for Supabase SQL
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
insert into public.malekort (id, retailer_id, navn) values ('f3bfea3d-0000-4000-8000-0000f3bfea3d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA1');
insert into public.malekort (id, retailer_id, navn) values ('f3c05eb2-0000-4000-8000-0000f3c05eb2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA2');
insert into public.malekort (id, retailer_id, navn) values ('f3c0d312-0000-4000-8000-0000f3c0d312', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA3');
insert into public.malekort (id, retailer_id, navn) values ('f3ce01d6-0000-4000-8000-0000f3ce01d6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB1');
insert into public.malekort (id, retailer_id, navn) values ('f3ce7636-0000-4000-8000-0000f3ce7636', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB2');
insert into public.malekort (id, retailer_id, navn) values ('843d5cfc-0000-4000-8000-0000843d5cfc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_AA1');
insert into public.malekort (id, retailer_id, navn) values ('85f2359c-0000-4000-8000-000085f2359c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_AB1');
insert into public.malekort (id, retailer_id, navn) values ('843d5cfe-0000-4000-8000-0000843d5cfe', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_AA1');
insert into public.malekort (id, retailer_id, navn) values ('843d5cff-0000-4000-8000-0000843d5cff', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A1A1');
insert into public.malekort (id, retailer_id, navn) values ('85f2359f-0000-4000-8000-000085f2359f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A1B1');
insert into public.malekort (id, retailer_id, navn) values ('843d5d01-0000-4000-8000-0000843d5d01', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A12A1');
insert into public.malekort (id, retailer_id, navn) values ('85f235b6-0000-4000-8000-000085f235b6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A12B1');
insert into public.malekort (id, retailer_id, navn) values ('843d5d18-0000-4000-8000-0000843d5d18', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1A1');
insert into public.malekort (id, retailer_id, navn) values ('85f235b8-0000-4000-8000-000085f235b8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1B1');
insert into public.malekort (id, retailer_id, navn) values ('85f235b9-0000-4000-8000-000085f235b9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_BB1');
insert into public.malekort (id, retailer_id, navn) values ('843d5d1b-0000-4000-8000-0000843d5d1b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_BA1');
insert into public.malekort (id, retailer_id, navn) values ('85f235bb-0000-4000-8000-000085f235bb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_BB1');
insert into public.malekort (id, retailer_id, navn) values ('85f235bc-0000-4000-8000-000085f235bc', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_B1B1');
insert into public.malekort (id, retailer_id, navn) values ('843d5d1e-0000-4000-8000-0000843d5d1e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_B1A1');
insert into public.malekort (id, retailer_id, navn) values ('85f235be-0000-4000-8000-000085f235be', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1B1');
insert into public.malekort (id, retailer_id, navn) values ('843d5d20-0000-4000-8000-0000843d5d20', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1A1');
-- --- varsler: forutsetninger og proberader ---
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('aef22628-0000-4000-8000-0000aef22628', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde', 'Sondevarsel nullA', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('aef22629-0000-4000-8000-0000aef22629', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde', 'Sondevarsel nullB', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de1-0000-4000-8000-00002c110de1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde', 'Sondevarsel fastA1', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de2-0000-4000-8000-00002c110de2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde', 'Sondevarsel fastA2', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110de3-0000-4000-8000-00002c110de3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde', 'Sondevarsel fastA3', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110e00-0000-4000-8000-00002c110e00', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde', 'Sondevarsel fastB1', 'Sonde');
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst) values ('2c110e01-0000-4000-8000-00002c110e01', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde', 'Sondevarsel fastB2', 'Sonde');

create or replace function pg_temp.nyrad_varsler(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst)
  values (p_retailer, p_stasjon, 'sonde', 'Sondevarsel ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde')
  returning id into ny;
  return ny;
end $fn$;
-- --- signal_lukket: forutsetninger og proberader ---
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3ca-0000-4000-8000-0000502ec3ca', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde-nullA', date '2026-01-01' + 7, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('502ec3cb-0000-4000-8000-0000502ec3cb', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde-nullB', date '2026-01-01' + 8, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-fastA1', date '2026-01-01' + 9, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-fastA2', date '2026-01-01' + 10, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-fastA3', date '2026-01-01' + 11, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-fastB1', date '2026-01-01' + 12, 'Sonde');
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-fastB2', date '2026-01-01' + 13, 'Sonde');

create or replace function pg_temp.nyrad_signal_lukket(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat)
  values (p_retailer, p_stasjon, 'sonde-' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sonde')
  returning id into ny;
  return ny;
end $fn$;
-- --- uke_rapport: forutsetninger og proberader ---
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 14);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 15);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 16);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 17);
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 18);

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
-- --- malekort_scope: forutsetninger og proberader ---
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', 'f3bfea3d-0000-4000-8000-0000f3bfea3d', 'avdeling', 'fastA1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bd-0000-4000-8000-00005d5db7bd', 'aaaa0000-0000-4000-8000-000000000000', 'f3c05eb2-0000-4000-8000-0000f3c05eb2', 'avdeling', 'fastA2');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7be-0000-4000-8000-00005d5db7be', 'aaaa0000-0000-4000-8000-000000000000', 'f3c0d312-0000-4000-8000-0000f3c0d312', 'avdeling', 'fastA3');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce01d6-0000-4000-8000-0000f3ce01d6', 'avdeling', 'fastB1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7dc-0000-4000-8000-00005d5db7dc', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce7636-0000-4000-8000-0000f3ce7636', 'avdeling', 'fastB2');

create or replace function pg_temp.nyrad_malekort_scope(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_malekort uuid := gen_random_uuid();
begin
  insert into public.malekort (id, retailer_id, navn) values (v_malekort, p_retailer, 'Sondekort ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '');
  insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode)
  values (p_retailer, v_malekort, 'avdeling', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- prognose_treff: forutsetninger og proberader ---
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f208589-0000-4000-8000-00009f208589', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 24, 'fastA1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858a-0000-4000-8000-00009f20858a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 25, 'fastA2', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858b-0000-4000-8000-00009f20858b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', date '2026-01-01' + 26, 'fastA3', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a8-0000-4000-8000-00009f2085a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 27, 'fastB1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a9-0000-4000-8000-00009f2085a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 28, 'fastB2', 100, 95);
-- --- bemanning_vindu: forutsetninger og proberader ---
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 29, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 30, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 31, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 32, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 33, 6, 22, 1);

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
-- --- bemanning_fast_vakt: forutsetninger og proberader ---
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde fastA1', 3, date '2026-01-01' + 39, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde fastA2', 3, date '2026-01-01' + 40, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde fastA3', 3, date '2026-01-01' + 41, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde fastB1', 3, date '2026-01-01' + 42, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde fastB2', 3, date '2026-01-01' + 43, 7, 15);

create or replace function pg_temp.nyrad_bemanning_fast_vakt(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time)
  values (p_stasjon, 'Sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 3, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 7, 15)
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_budsjett: forutsetninger og proberader ---
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);

-- =====================================================================
-- varsler  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('varsler');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('varsler owner_A SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT A2 -> ser', exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT A3 -> ser', exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'positiv');
select pg_temp.paastand('varsler owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_AA1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel owner_AA2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_A INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel owner_AA3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler owner_A INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_AB1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('varsler owner_A UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('varsler owner_A UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'positiv');
select pg_temp.paastand('varsler owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('varsler manager_A1 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'negativ');
select pg_temp.paastand('varsler manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A1A1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_A1A2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A1A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A1B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('varsler manager_A1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''', 'varsler', '2c110de2-0000-4000-8000-00002c110de2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('varsler manager_A1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_A1 FLYTTER egen rad A1 -> A2', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('varsler manager_A12 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler manager_A12 SELECT A2 -> ser', exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'positiv');
select pg_temp.paastand('varsler manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A12A1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_A12A2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_A12 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel manager_A12A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_A12 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_A12B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('varsler manager_A12 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('varsler manager_A12 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('varsler manager_A12 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('varsler manager_A12 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_A12 FLYTTER egen rad A1 -> A3', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('varsler tablet_A1 SELECT A1 -> ser', exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'positiv');
select pg_temp.paastand('varsler tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de2-0000-4000-8000-00002c110de2'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de3-0000-4000-8000-00002c110de3'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'negativ');
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_A1A1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_A1A2'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler tablet_A1 INSERT A3', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde'', ''Sondevarsel tablet_A1A3'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_A1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_A1B1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('varsler tablet_A1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE A2', 'update public.varsler set lest = true where id = ''2c110de2-0000-4000-8000-00002c110de2''', 'varsler', '2c110de2-0000-4000-8000-00002c110de2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE A3', 'update public.varsler set lest = true where id = ''2c110de3-0000-4000-8000-00002c110de3''', 'varsler', '2c110de3-0000-4000-8000-00002c110de3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('varsler tablet_A1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');
select pg_temp.paastand('varsler tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.paastand('varsler tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.skriv_avvist('varsler tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.varsler set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('varsler owner_B SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler owner_B SELECT B2 -> ser', exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'positiv');
select pg_temp.paastand('varsler owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler owner_B INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_BB1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler owner_B INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel owner_BB2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler owner_B INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel owner_BA1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('varsler owner_B UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('varsler owner_B UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('varsler owner_B UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'positiv');
select pg_temp.paastand('varsler owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('varsler manager_B1 SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'negativ');
select pg_temp.paastand('varsler manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler manager_B1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_B1B1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler manager_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel manager_B1B2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler manager_B1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel manager_B1A1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('varsler manager_B1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('varsler manager_B1 UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''', 'varsler', '2c110e01-0000-4000-8000-00002c110e01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('varsler manager_B1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.paastand('varsler manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.skriv_avvist('varsler manager_B1 FLYTTER egen rad B1 -> B2', 'update public.varsler set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('varsler tablet_B1 SELECT B1 -> ser', exists (select 1 from public.varsler where id = '2c110e00-0000-4000-8000-00002c110e00'), 'positiv');
select pg_temp.paastand('varsler tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110e01-0000-4000-8000-00002c110e01'), 'negativ');
select pg_temp.paastand('varsler tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.varsler where id = '2c110de1-0000-4000-8000-00002c110de1'), 'negativ');
select pg_temp.skriv_tillatt('varsler tablet_B1 INSERT B1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_B1B1'', ''Sonde'')');
select pg_temp.skriv_tillatt('varsler tablet_B1 INSERT B2', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde'', ''Sondevarsel tablet_B1B2'', ''Sonde'')');
select pg_temp.skriv_avvist('varsler tablet_B1 INSERT A1', 'insert into public.varsler (retailer_id, stasjon_id, type, tittel, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde'', ''Sondevarsel tablet_B1A1'', ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('varsler tablet_B1 UPDATE B1', 'update public.varsler set lest = true where id = ''2c110e00-0000-4000-8000-00002c110e00''');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('varsler tablet_B1 UPDATE B2', 'update public.varsler set lest = true where id = ''2c110e01-0000-4000-8000-00002c110e01''', 'varsler', '2c110e01-0000-4000-8000-00002c110e01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_varsler('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('varsler tablet_B1 UPDATE A1', 'update public.varsler set lest = true where id = ''2c110de1-0000-4000-8000-00002c110de1''', 'varsler', '2c110de1-0000-4000-8000-00002c110de1', 'id');
select pg_temp.paastand('varsler tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.varsler where id = 'aef22629-0000-4000-8000-0000aef22629'), 'negativ');
select pg_temp.paastand('varsler tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.varsler where id = 'aef22628-0000-4000-8000-0000aef22628'), 'negativ');
select pg_temp.skriv_avvist('varsler tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.varsler set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''2c110e00-0000-4000-8000-00002c110e00''', 'varsler', '2c110e00-0000-4000-8000-00002c110e00', 'id');

-- =====================================================================
-- signal_lukket  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('signal_lukket');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('signal_lukket owner_A SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT A3 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_AA1'', date ''2026-01-01'' + 74, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-owner_AA2'', date ''2026-01-01'' + 75, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_A INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-owner_AA3'', date ''2026-01-01'' + 76, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_A INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_AB1'', date ''2026-01-01'' + 77, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('signal_lukket owner_A UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_AA1', date '2026-01-01' + 78, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_AA2', date '2026-01-01' + 79, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('signal_lukket owner_A DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac05-0000-4000-8000-000089bcac05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde-gjenowner_AA3', date '2026-01-01' + 80, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('signal_lukket owner_A DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('signal_lukket manager_A1 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1A1'', date ''2026-01-01'' + 81, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A1A2'', date ''2026-01-01'' + 82, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A1A3'', date ''2026-01-01'' + 83, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A1B1'', date ''2026-01-01'' + 84, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('signal_lukket manager_A1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A1A1', date '2026-01-01' + 85, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('signal_lukket manager_A1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket manager_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_A1 FLYTTER egen rad A1 -> A2', 'update public.signal_lukket set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('signal_lukket manager_A12 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 SELECT A2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12A1'', date ''2026-01-01'' + 86, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-manager_A12A2'', date ''2026-01-01'' + 87, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-manager_A12A3'', date ''2026-01-01'' + 88, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_A12 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_A12B1'', date ''2026-01-01'' + 89, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac03-0000-4000-8000-000089bcac03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_A12A1', date '2026-01-01' + 90, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('signal_lukket manager_A12 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac04-0000-4000-8000-000089bcac04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde-gjenmanager_A12A2', date '2026-01-01' + 91, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('signal_lukket manager_A12 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket manager_A12 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_A12 FLYTTER egen rad A1 -> A3', 'update public.signal_lukket set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac04-0000-4000-8000-000089bcac04'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac05-0000-4000-8000-000089bcac05'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1A1'', date ''2026-01-01'' + 92, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde-tablet_A1A2'', date ''2026-01-01'' + 93, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT A3', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde-tablet_A1A3'', date ''2026-01-01'' + 94, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_A1B1'', date ''2026-01-01'' + 95, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE A3', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A2', 'delete from public.signal_lukket where id = ''89bcac04-0000-4000-8000-000089bcac04''', 'signal_lukket', '89bcac04-0000-4000-8000-000089bcac04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE A3', 'delete from public.signal_lukket where id = ''89bcac05-0000-4000-8000-000089bcac05''', 'signal_lukket', '89bcac05-0000-4000-8000-000089bcac05', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('signal_lukket tablet_A1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.paastand('signal_lukket tablet_A1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('signal_lukket owner_B SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B SELECT B2 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-owner_BB1'', date ''2026-01-01'' + 96, ''Sonde'')');
select pg_temp.skriv_tillatt('signal_lukket owner_B INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-owner_BB2'', date ''2026-01-01'' + 97, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket owner_B INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-owner_BA1'', date ''2026-01-01'' + 98, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('signal_lukket owner_B UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenowner_BB1', date '2026-01-01' + 99, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('signal_lukket owner_B DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac23-0000-4000-8000-000089bcac23', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde-gjenowner_BB2', date '2026-01-01' + 100, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('signal_lukket owner_B DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('signal_lukket manager_B1 SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'negativ');
select pg_temp.paastand('signal_lukket manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1B1'', date ''2026-01-01'' + 101, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-manager_B1B2'', date ''2026-01-01'' + 102, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket manager_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-manager_B1A1'', date ''2026-01-01'' + 103, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('signal_lukket manager_B1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''');
select pg_temp.som_eier();
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat) values ('89bcac22-0000-4000-8000-000089bcac22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde-gjenmanager_B1B1', date '2026-01-01' + 104, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('signal_lukket manager_B1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket manager_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket manager_B1 FLYTTER egen rad B1 -> B2', 'update public.signal_lukket set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('signal_lukket tablet_B1 SELECT B1 -> ser', exists (select 1 from public.signal_lukket where id = '89bcac22-0000-4000-8000-000089bcac22'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac23-0000-4000-8000-000089bcac23'), 'negativ');
select pg_temp.paastand('signal_lukket tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.signal_lukket where id = '89bcac03-0000-4000-8000-000089bcac03'), 'negativ');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1B1'', date ''2026-01-01'' + 105, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT B2', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde-tablet_B1B2'', date ''2026-01-01'' + 106, ''Sonde'')');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 INSERT A1', 'insert into public.signal_lukket (retailer_id, stasjon_id, signal_id, gjelder_til, notat) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde-tablet_B1A1'', date ''2026-01-01'' + 107, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE B1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE B2', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 UPDATE A1', 'update public.signal_lukket set notat = ''endret av sonden'' where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE B1', 'delete from public.signal_lukket where id = ''89bcac22-0000-4000-8000-000089bcac22''', 'signal_lukket', '89bcac22-0000-4000-8000-000089bcac22', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE B2', 'delete from public.signal_lukket where id = ''89bcac23-0000-4000-8000-000089bcac23''', 'signal_lukket', '89bcac23-0000-4000-8000-000089bcac23', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_signal_lukket('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('signal_lukket tablet_B1 DELETE A1', 'delete from public.signal_lukket where id = ''89bcac03-0000-4000-8000-000089bcac03''', 'signal_lukket', '89bcac03-0000-4000-8000-000089bcac03', 'id');
select pg_temp.paastand('signal_lukket tablet_B1 ser kjedens null-stasjonsrad', exists (select 1 from public.signal_lukket where id = '502ec3cb-0000-4000-8000-0000502ec3cb'), 'positiv');
select pg_temp.paastand('signal_lukket tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.signal_lukket where id = '502ec3ca-0000-4000-8000-0000502ec3ca'), 'negativ');

-- =====================================================================
-- uke_rapport  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('uke_rapport');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('uke_rapport owner_A SELECT A1 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e6-0000-4000-8000-0000cf7838e6'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A2 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e7-0000-4000-8000-0000cf7838e7'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT A3 -> ser', exists (select 1 from public.uke_rapport where id = 'cf7838e8-0000-4000-8000-0000cf7838e8'), 'positiv');
select pg_temp.paastand('uke_rapport owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.uke_rapport where id = 'cf783905-0000-4000-8000-0000cf783905'), 'negativ');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 108)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 109)');
select pg_temp.skriv_tillatt('uke_rapport owner_A INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 110)');
select pg_temp.skriv_avvist('uke_rapport owner_A INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 111)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 112);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 113);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('uke_rapport owner_A DELETE A3', 'delete from public.uke_rapport where id = ''cf7838e8-0000-4000-8000-0000cf7838e8''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e8-0000-4000-8000-0000cf7838e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 114);
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
select pg_temp.skriv_tillatt('uke_rapport manager_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 115)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 116)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 117)');
select pg_temp.skriv_avvist('uke_rapport manager_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 118)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 119);
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
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 120)');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 121)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 122)');
select pg_temp.skriv_avvist('uke_rapport manager_A12 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 123)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 124);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('uke_rapport manager_A12 DELETE A2', 'delete from public.uke_rapport where id = ''cf7838e7-0000-4000-8000-0000cf7838e7''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e7-0000-4000-8000-0000cf7838e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 125);
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
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 126)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 127)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT A3', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 128)');
select pg_temp.skriv_avvist('uke_rapport tablet_A1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 129)');
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
select pg_temp.skriv_tillatt('uke_rapport tablet_A1 DELETE A1', 'delete from public.uke_rapport where id = ''cf7838e6-0000-4000-8000-0000cf7838e6''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf7838e6-0000-4000-8000-0000cf7838e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 130);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
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
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 131)');
select pg_temp.skriv_tillatt('uke_rapport owner_B INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 132)');
select pg_temp.skriv_avvist('uke_rapport owner_B INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 133)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 134);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_uke_rapport('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('uke_rapport owner_B DELETE B2', 'delete from public.uke_rapport where id = ''cf783906-0000-4000-8000-0000cf783906''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783906-0000-4000-8000-0000cf783906', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 135);
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
select pg_temp.skriv_tillatt('uke_rapport manager_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 136)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 137)');
select pg_temp.skriv_avvist('uke_rapport manager_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 138)');
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
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 139);
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
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 INSERT B1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 140)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT B2', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 141)');
select pg_temp.skriv_avvist('uke_rapport tablet_B1 INSERT A1', 'insert into public.uke_rapport (retailer_id, stasjon_id, uke_mandag) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 142)');
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
select pg_temp.skriv_tillatt('uke_rapport tablet_B1 DELETE B1', 'delete from public.uke_rapport where id = ''cf783905-0000-4000-8000-0000cf783905''');
select pg_temp.som_eier();
insert into public.uke_rapport (id, retailer_id, stasjon_id, uke_mandag) values ('cf783905-0000-4000-8000-0000cf783905', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 143);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
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
-- malekort_scope  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('malekort_scope');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('malekort_scope owner_A SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope owner_A SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_tillatt('malekort_scope owner_A INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5cfc-0000-4000-8000-0000843d5cfc'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('malekort_scope owner_A INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2359c-0000-4000-8000-000085f2359c'', ''avdeling'', ''owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('malekort_scope owner_A UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort_scope owner_A UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('malekort_scope owner_A DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''');
select pg_temp.som_eier();
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', '843d5cfe-0000-4000-8000-0000843d5cfe', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort_scope owner_A DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_A FLYTTER egen rad -> kjede B', 'update public.malekort_scope set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('malekort_scope manager_A1 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5cff-0000-4000-8000-0000843d5cff'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2359f-0000-4000-8000-000085f2359f'', ''avdeling'', ''manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort_scope manager_A1 UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort_scope manager_A1 UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort_scope manager_A1 DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort_scope manager_A1 DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('malekort_scope manager_A12 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5d01-0000-4000-8000-0000843d5d01'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f235b6-0000-4000-8000-000085f235b6'', ''avdeling'', ''manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort_scope manager_A12 UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort_scope manager_A12 UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort_scope manager_A12 DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort_scope manager_A12 DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('malekort_scope tablet_A1 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5d18-0000-4000-8000-0000843d5d18'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f235b8-0000-4000-8000-000085f235b8'', ''avdeling'', ''tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('malekort_scope owner_B SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope owner_B SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_tillatt('malekort_scope owner_B INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f235b9-0000-4000-8000-000085f235b9'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('malekort_scope owner_B INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5d1b-0000-4000-8000-0000843d5d1b'', ''avdeling'', ''owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('malekort_scope owner_B UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort_scope owner_B UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('malekort_scope owner_B DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''');
select pg_temp.som_eier();
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', '85f235bb-0000-4000-8000-000085f235bb', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort_scope owner_B DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_B FLYTTER egen rad -> kjede A', 'update public.malekort_scope set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('malekort_scope manager_B1 SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f235bc-0000-4000-8000-000085f235bc'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5d1e-0000-4000-8000-0000843d5d1e'', ''avdeling'', ''manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort_scope manager_B1 UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort_scope manager_B1 UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort_scope manager_B1 DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort_scope manager_B1 DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('malekort_scope tablet_B1 SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f235be-0000-4000-8000-000085f235be'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5d20-0000-4000-8000-0000843d5d20'', ''avdeling'', ''tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 UPDATE B', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 UPDATE A', 'update public.malekort_scope set kode = ''endret'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

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
-- bemanning_vindu  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_vindu');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_vindu owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 160, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 161, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 162, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_A INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 163, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 164, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 165, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 166, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 167, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 168, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 169, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 170, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 171, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 172, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 173, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 174, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 175, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 176, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 177, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 178, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 179, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 180, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 181, 6, 22, 1)');
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
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 182, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 183, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_B INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 184, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 185, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 186, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 187, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 188, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 189, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 190, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 191, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 192, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 193, 6, 22, 1)');
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
-- bemanning_fast_vakt  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fast_vakt');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_AA1'', 3, date ''2026-01-01'' + 228, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde owner_AA2'', 3, date ''2026-01-01'' + 229, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde owner_AA3'', 3, date ''2026-01-01'' + 230, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_AB1'', 3, date ''2026-01-01'' + 231, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_AA1', 3, date '2026-01-01' + 232, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_AA2', 3, date '2026-01-01' + 233, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde gjenowner_AA3', 3, date '2026-01-01' + 234, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1A1'', 3, date ''2026-01-01'' + 235, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A1A2'', 3, date ''2026-01-01'' + 236, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A1A3'', 3, date ''2026-01-01'' + 237, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1B1'', 3, date ''2026-01-01'' + 238, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A1A1', 3, date '2026-01-01' + 239, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_fast_vakt set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12A1'', 3, date ''2026-01-01'' + 240, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A12A2'', 3, date ''2026-01-01'' + 241, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A12A3'', 3, date ''2026-01-01'' + 242, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12B1'', 3, date ''2026-01-01'' + 243, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A12A1', 3, date '2026-01-01' + 244, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenmanager_A12A2', 3, date '2026-01-01' + 245, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_fast_vakt set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1A1'', 3, date ''2026-01-01'' + 246, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde tablet_A1A2'', 3, date ''2026-01-01'' + 247, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde tablet_A1A3'', 3, date ''2026-01-01'' + 248, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1B1'', 3, date ''2026-01-01'' + 249, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_BB1'', 3, date ''2026-01-01'' + 250, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde owner_BB2'', 3, date ''2026-01-01'' + 251, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_BA1'', 3, date ''2026-01-01'' + 252, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_BB1', 3, date '2026-01-01' + 253, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_BB2', 3, date '2026-01-01' + 254, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1B1'', 3, date ''2026-01-01'' + 255, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde manager_B1B2'', 3, date ''2026-01-01'' + 256, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1A1'', 3, date ''2026-01-01'' + 257, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_B1B1', 3, date '2026-01-01' + 258, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_fast_vakt set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1B1'', 3, date ''2026-01-01'' + 259, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde tablet_B1B2'', 3, date ''2026-01-01'' + 260, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1A1'', 3, date ''2026-01-01'' + 261, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

-- =====================================================================
-- bemanning_budsjett  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_budsjett');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_budsjett owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 1/6: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 1/6: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
