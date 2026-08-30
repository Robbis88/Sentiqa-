-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 2 AV 10. Hele matrisen er for stor for Supabase SQL
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
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('7e4623b7-0000-4000-8000-00007e4623b7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0035 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('7e469817-0000-4000-8000-00007e469817', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 2000 + 0036 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('7e470c77-0000-4000-8000-00007e470c77', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 2000 + 0037 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('7e543b3b-0000-4000-8000-00007e543b3b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0038 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('7e54af9b-0000-4000-8000-00007e54af9b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 2000 + 0039 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e52fc-0000-4000-8000-00004a7e52fc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0320 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332b9c-0000-4000-8000-00004c332b9c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0321 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e52fe-0000-4000-8000-00004a7e52fe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0322 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e52ff-0000-4000-8000-00004a7e52ff', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0323 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332b9f-0000-4000-8000-00004c332b9f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0324 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e5301-0000-4000-8000-00004a7e5301', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0325 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332ba1-0000-4000-8000-00004c332ba1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0326 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e5303-0000-4000-8000-00004a7e5303', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0327 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332ba3-0000-4000-8000-00004c332ba3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0328 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332ba4-0000-4000-8000-00004c332ba4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0329 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e531b-0000-4000-8000-00004a7e531b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0330 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332bbb-0000-4000-8000-00004c332bbb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0331 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332bbc-0000-4000-8000-00004c332bbc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0332 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e531e-0000-4000-8000-00004a7e531e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0333 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4c332bbe-0000-4000-8000-00004c332bbe', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2000 + 0334 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values ('4a7e5320-0000-4000-8000-00004a7e5320', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2000 + 0335 % 1000, 'st1_bp26', 12000);
-- --- bemanning_fast_vakt: forutsetninger og proberader ---
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde fastA1', 3, date '2026-01-01' + 0, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde fastA2', 3, date '2026-01-01' + 1, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde fastA3', 3, date '2026-01-01' + 2, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde fastB1', 3, date '2026-01-01' + 3, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde fastB2', 3, date '2026-01-01' + 4, 7, 15);

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
-- --- bemanning_fravaer: forutsetninger og proberader ---
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 5, date '2026-01-01' + 5, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 6, date '2026-01-01' + 6, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 7, date '2026-01-01' + 7, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 8, date '2026-01-01' + 8, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 9, date '2026-01-01' + 9, 'Sonde');

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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 25, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 26, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 27, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 28, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 29, 6, 22, 1);

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
-- --- bp_aar: forutsetninger og proberader ---
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7255-0000-4000-8000-0000f4eb7255', 'a1110000-0000-4000-8000-000000000001', 2000 + 0030 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7256-0000-4000-8000-0000f4eb7256', 'a1110000-0000-4000-8000-000000000002', 2000 + 0031 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7257-0000-4000-8000-0000f4eb7257', 'a1110000-0000-4000-8000-000000000003', 2000 + 0032 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7274-0000-4000-8000-0000f4eb7274', 'b1110000-0000-4000-8000-000000000001', 2000 + 0033 % 1000, 'st1_bp26', 12000);
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7275-0000-4000-8000-0000f4eb7275', 'b1110000-0000-4000-8000-000000000002', 2000 + 0034 % 1000, 'st1_bp26', 12000);

create or replace function pg_temp.nyrad_bp_aar(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bp_aar (stasjon_id, ar, format, timer_aar)
  values (p_stasjon, 2000 + (9000 + nextval('tenant_teller'::regclass) % 1000) % 1000, 'st1_bp26', 12000)
  returning id into ny;
  return ny;
end $fn$;
-- --- bp_linje: forutsetninger og proberader ---
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447cf-0000-4000-8000-00002ac447cf', 'aaaa0000-0000-4000-8000-000000000000', '7e4623b7-0000-4000-8000-00007e4623b7', 1, 'omsetning', 'fastA1', '120 Mat', 1000);
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447d0-0000-4000-8000-00002ac447d0', 'aaaa0000-0000-4000-8000-000000000000', '7e469817-0000-4000-8000-00007e469817', 1, 'omsetning', 'fastA2', '120 Mat', 1000);
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447d1-0000-4000-8000-00002ac447d1', 'aaaa0000-0000-4000-8000-000000000000', '7e470c77-0000-4000-8000-00007e470c77', 1, 'omsetning', 'fastA3', '120 Mat', 1000);
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447ee-0000-4000-8000-00002ac447ee', 'bbbb0000-0000-4000-8000-000000000000', '7e543b3b-0000-4000-8000-00007e543b3b', 1, 'omsetning', 'fastB1', '120 Mat', 1000);
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447ef-0000-4000-8000-00002ac447ef', 'bbbb0000-0000-4000-8000-000000000000', '7e54af9b-0000-4000-8000-00007e54af9b', 1, 'omsetning', 'fastB2', '120 Mat', 1000);

create or replace function pg_temp.nyrad_bp_linje(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_bpaar uuid := gen_random_uuid();
begin
  insert into public.bp_aar (id, retailer_id, stasjon_id, ar, format, timer_aar) values (v_bpaar, p_retailer, p_stasjon, 2000 + (9000 + nextval('tenant_teller'::regclass) % 1000) % 1000, 'st1_bp26', 12000);
  insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr)
  values (p_retailer, v_bpaar, 1, 'omsetning', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', '120 Mat', 1000)
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- bemanning_fast_vakt  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fast_vakt');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_AA1'', 3, date ''2026-01-01'' + 40, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde owner_AA2'', 3, date ''2026-01-01'' + 41, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde owner_AA3'', 3, date ''2026-01-01'' + 42, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_AB1'', 3, date ''2026-01-01'' + 43, 7, 15)');
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
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_AA1', 3, date '2026-01-01' + 44, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_AA2', 3, date '2026-01-01' + 45, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde gjenowner_AA3', 3, date '2026-01-01' + 46, 7, 15);
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
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1A1'', 3, date ''2026-01-01'' + 47, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A1A2'', 3, date ''2026-01-01'' + 48, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A1A3'', 3, date ''2026-01-01'' + 49, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1B1'', 3, date ''2026-01-01'' + 50, 7, 15)');
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
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A1A1', 3, date '2026-01-01' + 51, 7, 15);
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
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12A1'', 3, date ''2026-01-01'' + 52, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A12A2'', 3, date ''2026-01-01'' + 53, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A12A3'', 3, date ''2026-01-01'' + 54, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12B1'', 3, date ''2026-01-01'' + 55, 7, 15)');
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
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A12A1', 3, date '2026-01-01' + 56, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenmanager_A12A2', 3, date '2026-01-01' + 57, 7, 15);
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
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1A1'', 3, date ''2026-01-01'' + 58, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde tablet_A1A2'', 3, date ''2026-01-01'' + 59, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde tablet_A1A3'', 3, date ''2026-01-01'' + 60, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1B1'', 3, date ''2026-01-01'' + 61, 7, 15)');
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
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_BB1'', 3, date ''2026-01-01'' + 62, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde owner_BB2'', 3, date ''2026-01-01'' + 63, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_BA1'', 3, date ''2026-01-01'' + 64, 7, 15)');
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
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_BB1', 3, date '2026-01-01' + 65, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_BB2', 3, date '2026-01-01' + 66, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1B1'', 3, date ''2026-01-01'' + 67, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde manager_B1B2'', 3, date ''2026-01-01'' + 68, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1A1'', 3, date ''2026-01-01'' + 69, 7, 15)');
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
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_B1B1', 3, date '2026-01-01' + 70, 7, 15);
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
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1B1'', 3, date ''2026-01-01'' + 71, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde tablet_B1B2'', 3, date ''2026-01-01'' + 72, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1A1'', 3, date ''2026-01-01'' + 73, 7, 15)');
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
-- bemanning_fravaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fravaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 74, date ''2026-01-01'' + 74, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 75, date ''2026-01-01'' + 75, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 76, date ''2026-01-01'' + 76, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 77, date ''2026-01-01'' + 77, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 78, date '2026-01-01' + 78, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 79, date '2026-01-01' + 79, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 80, date '2026-01-01' + 80, 'Sonde');
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
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 81, date ''2026-01-01'' + 81, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 82, date ''2026-01-01'' + 82, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 83, date ''2026-01-01'' + 83, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 84, date ''2026-01-01'' + 84, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 85, date '2026-01-01' + 85, 'Sonde');
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
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 86, date ''2026-01-01'' + 86, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 87, date ''2026-01-01'' + 87, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 88, date ''2026-01-01'' + 88, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 89, date ''2026-01-01'' + 89, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 90, date '2026-01-01' + 90, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 91, date '2026-01-01' + 91, 'Sonde');
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
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 92, date ''2026-01-01'' + 92, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 93, date ''2026-01-01'' + 93, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 94, date ''2026-01-01'' + 94, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 95, date ''2026-01-01'' + 95, ''Sonde'')');
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
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 96, date ''2026-01-01'' + 96, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 97, date ''2026-01-01'' + 97, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 98, date ''2026-01-01'' + 98, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 99, date '2026-01-01' + 99, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 100, date '2026-01-01' + 100, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 101, date ''2026-01-01'' + 101, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 102, date ''2026-01-01'' + 102, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 103, date ''2026-01-01'' + 103, ''Sonde'')');
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
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 104, date '2026-01-01' + 104, 'Sonde');
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
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 105, date ''2026-01-01'' + 105, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 106, date ''2026-01-01'' + 106, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 107, date ''2026-01-01'' + 107, ''Sonde'')');
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
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 256, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 257, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 258, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_A INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 259, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 260, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 261, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 262, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 263, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 264, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 265, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 266, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 267, 6, 22, 1);
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
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 268, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 269, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 270, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 271, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 272, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 273, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 274, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 275, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 276, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 277, 6, 22, 1)');
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
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 278, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 279, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_B INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 280, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 281, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 282, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 283, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 284, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 285, 6, 22, 1)');
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
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 286, 6, 22, 1);
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
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 287, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 288, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 289, 6, 22, 1)');
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
-- bp_aar  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bp_aar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bp_aar owner_A SELECT A1 -> ser', exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'positiv');
select pg_temp.paastand('bp_aar owner_A SELECT A2 -> ser', exists (select 1 from public.bp_aar where id = 'f4eb7256-0000-4000-8000-0000f4eb7256'), 'positiv');
select pg_temp.paastand('bp_aar owner_A SELECT A3 -> ser', exists (select 1 from public.bp_aar where id = 'f4eb7257-0000-4000-8000-0000f4eb7257'), 'positiv');
select pg_temp.paastand('bp_aar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.skriv_tillatt('bp_aar owner_A INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0290 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_tillatt('bp_aar owner_A INSERT A2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000002'', 2000 + 0291 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_tillatt('bp_aar owner_A INSERT A3', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000003'', 2000 + 0292 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar owner_A INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0293 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A UPDATE A2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A UPDATE A3', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bp_aar owner_A UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''');
select pg_temp.som_eier();
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7255-0000-4000-8000-0000f4eb7255', 'a1110000-0000-4000-8000-000000000001', 2000 + 0294 % 1000, 'st1_bp26', 12000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A DELETE A2', 'delete from public.bp_aar where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''');
select pg_temp.som_eier();
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7256-0000-4000-8000-0000f4eb7256', 'a1110000-0000-4000-8000-000000000002', 2000 + 0295 % 1000, 'st1_bp26', 12000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_aar owner_A DELETE A3', 'delete from public.bp_aar where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''');
select pg_temp.som_eier();
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7257-0000-4000-8000-0000f4eb7257', 'a1110000-0000-4000-8000-000000000003', 2000 + 0296 % 1000, 'st1_bp26', 12000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bp_aar owner_A DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bp_aar manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.paastand('bp_aar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7256-0000-4000-8000-0000f4eb7256'), 'negativ');
select pg_temp.paastand('bp_aar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7257-0000-4000-8000-0000f4eb7257'), 'negativ');
select pg_temp.paastand('bp_aar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.skriv_avvist('bp_aar manager_A1 INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0297 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A1 INSERT A2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000002'', 2000 + 0298 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A1 INSERT A3', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000003'', 2000 + 0299 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A1 INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0300 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 UPDATE A2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 UPDATE A3', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 DELETE A2', 'delete from public.bp_aar where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 DELETE A3', 'delete from public.bp_aar where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_aar manager_A1 DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bp_aar manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.paastand('bp_aar manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7256-0000-4000-8000-0000f4eb7256'), 'negativ');
select pg_temp.paastand('bp_aar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7257-0000-4000-8000-0000f4eb7257'), 'negativ');
select pg_temp.paastand('bp_aar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.skriv_avvist('bp_aar manager_A12 INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0301 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A12 INSERT A2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000002'', 2000 + 0302 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A12 INSERT A3', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000003'', 2000 + 0303 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_A12 INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0304 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 UPDATE A2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 UPDATE A3', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 DELETE A2', 'delete from public.bp_aar where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 DELETE A3', 'delete from public.bp_aar where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_aar manager_A12 DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bp_aar tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.paastand('bp_aar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7256-0000-4000-8000-0000f4eb7256'), 'negativ');
select pg_temp.paastand('bp_aar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7257-0000-4000-8000-0000f4eb7257'), 'negativ');
select pg_temp.paastand('bp_aar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.skriv_avvist('bp_aar tablet_A1 INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0305 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar tablet_A1 INSERT A2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000002'', 2000 + 0306 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar tablet_A1 INSERT A3', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000003'', 2000 + 0307 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar tablet_A1 INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0308 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 UPDATE A2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 UPDATE A3', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 DELETE A2', 'delete from public.bp_aar where id = ''f4eb7256-0000-4000-8000-0000f4eb7256''', 'bp_aar', 'f4eb7256-0000-4000-8000-0000f4eb7256', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 DELETE A3', 'delete from public.bp_aar where id = ''f4eb7257-0000-4000-8000-0000f4eb7257''', 'bp_aar', 'f4eb7257-0000-4000-8000-0000f4eb7257', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_aar tablet_A1 DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bp_aar owner_B SELECT B1 -> ser', exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'positiv');
select pg_temp.paastand('bp_aar owner_B SELECT B2 -> ser', exists (select 1 from public.bp_aar where id = 'f4eb7275-0000-4000-8000-0000f4eb7275'), 'positiv');
select pg_temp.paastand('bp_aar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.skriv_tillatt('bp_aar owner_B INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0309 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_tillatt('bp_aar owner_B INSERT B2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000002'', 2000 + 0310 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar owner_B INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0311 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_aar owner_B UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_aar owner_B UPDATE B2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bp_aar owner_B UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_aar owner_B DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''');
select pg_temp.som_eier();
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7274-0000-4000-8000-0000f4eb7274', 'b1110000-0000-4000-8000-000000000001', 2000 + 0312 % 1000, 'st1_bp26', 12000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_aar owner_B DELETE B2', 'delete from public.bp_aar where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''');
select pg_temp.som_eier();
insert into public.bp_aar (id, stasjon_id, ar, format, timer_aar) values ('f4eb7275-0000-4000-8000-0000f4eb7275', 'b1110000-0000-4000-8000-000000000002', 2000 + 0313 % 1000, 'st1_bp26', 12000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bp_aar owner_B DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bp_aar manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.paastand('bp_aar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7275-0000-4000-8000-0000f4eb7275'), 'negativ');
select pg_temp.paastand('bp_aar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.skriv_avvist('bp_aar manager_B1 INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0314 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_B1 INSERT B2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000002'', 2000 + 0315 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar manager_B1 INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0316 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 UPDATE B2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''', 'bp_aar', 'f4eb7275-0000-4000-8000-0000f4eb7275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 DELETE B2', 'delete from public.bp_aar where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''', 'bp_aar', 'f4eb7275-0000-4000-8000-0000f4eb7275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_aar manager_B1 DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bp_aar tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7274-0000-4000-8000-0000f4eb7274'), 'negativ');
select pg_temp.paastand('bp_aar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7275-0000-4000-8000-0000f4eb7275'), 'negativ');
select pg_temp.paastand('bp_aar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bp_aar where id = 'f4eb7255-0000-4000-8000-0000f4eb7255'), 'negativ');
select pg_temp.skriv_avvist('bp_aar tablet_B1 INSERT B1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000001'', 2000 + 0317 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar tablet_B1 INSERT B2', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''b1110000-0000-4000-8000-000000000002'', 2000 + 0318 % 1000, ''st1_bp26'', 12000)');
select pg_temp.skriv_avvist('bp_aar tablet_B1 INSERT A1', 'insert into public.bp_aar (stasjon_id, ar, format, timer_aar) values (''a1110000-0000-4000-8000-000000000001'', 2000 + 0319 % 1000, ''st1_bp26'', 12000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 UPDATE B1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 UPDATE B2', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''', 'bp_aar', 'f4eb7275-0000-4000-8000-0000f4eb7275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 UPDATE A1', 'update public.bp_aar set timer_aar = 12500 where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 DELETE B1', 'delete from public.bp_aar where id = ''f4eb7274-0000-4000-8000-0000f4eb7274''', 'bp_aar', 'f4eb7274-0000-4000-8000-0000f4eb7274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 DELETE B2', 'delete from public.bp_aar where id = ''f4eb7275-0000-4000-8000-0000f4eb7275''', 'bp_aar', 'f4eb7275-0000-4000-8000-0000f4eb7275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_aar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_aar tablet_B1 DELETE A1', 'delete from public.bp_aar where id = ''f4eb7255-0000-4000-8000-0000f4eb7255''', 'bp_aar', 'f4eb7255-0000-4000-8000-0000f4eb7255', 'id');

-- =====================================================================
-- bp_linje  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bp_linje');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bp_linje owner_A SELECT A -> ser', exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'positiv');
select pg_temp.paastand('bp_linje owner_A SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.skriv_tillatt('bp_linje owner_A INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e52fc-0000-4000-8000-00004a7e52fc'', 1, ''omsetning'', ''owner_AA1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje owner_A INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332b9c-0000-4000-8000-00004c332b9c'', 1, ''omsetning'', ''owner_AB1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_linje owner_A UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bp_linje owner_A UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bp_linje owner_A DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''');
select pg_temp.som_eier();
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447cf-0000-4000-8000-00002ac447cf', 'aaaa0000-0000-4000-8000-000000000000', '4a7e52fe-0000-4000-8000-00004a7e52fe', 1, 'omsetning', 'gjenowner_AA1', '120 Mat', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bp_linje owner_A DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.skriv_avvist('bp_linje owner_A FLYTTER egen rad -> kjede B', 'update public.bp_linje set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bp_linje manager_A1 SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.paastand('bp_linje manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.skriv_avvist('bp_linje manager_A1 INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e52ff-0000-4000-8000-00004a7e52ff'', 1, ''omsetning'', ''manager_A1A1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje manager_A1 INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332b9f-0000-4000-8000-00004c332b9f'', 1, ''omsetning'', ''manager_A1B1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_linje manager_A1 UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_linje manager_A1 UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_linje manager_A1 DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bp_linje manager_A1 DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bp_linje manager_A12 SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.paastand('bp_linje manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.skriv_avvist('bp_linje manager_A12 INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e5301-0000-4000-8000-00004a7e5301'', 1, ''omsetning'', ''manager_A12A1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje manager_A12 INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332ba1-0000-4000-8000-00004c332ba1'', 1, ''omsetning'', ''manager_A12B1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_linje manager_A12 UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_linje manager_A12 UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_linje manager_A12 DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bp_linje manager_A12 DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bp_linje tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.paastand('bp_linje tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.skriv_avvist('bp_linje tablet_A1 INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e5303-0000-4000-8000-00004a7e5303'', 1, ''omsetning'', ''tablet_A1A1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje tablet_A1 INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332ba3-0000-4000-8000-00004c332ba3'', 1, ''omsetning'', ''tablet_A1B1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_linje tablet_A1 UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_linje tablet_A1 UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_linje tablet_A1 DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bp_linje tablet_A1 DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bp_linje owner_B SELECT B -> ser', exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'positiv');
select pg_temp.paastand('bp_linje owner_B SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.skriv_tillatt('bp_linje owner_B INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332ba4-0000-4000-8000-00004c332ba4'', 1, ''omsetning'', ''owner_BB1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje owner_B INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e531b-0000-4000-8000-00004a7e531b'', 1, ''omsetning'', ''owner_BA1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_linje owner_B UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bp_linje owner_B UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bp_linje owner_B DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''');
select pg_temp.som_eier();
insert into public.bp_linje (id, retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values ('2ac447ee-0000-4000-8000-00002ac447ee', 'bbbb0000-0000-4000-8000-000000000000', '4c332bbb-0000-4000-8000-00004c332bbb', 1, 'omsetning', 'gjenowner_BB1', '120 Mat', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bp_linje owner_B DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.skriv_avvist('bp_linje owner_B FLYTTER egen rad -> kjede A', 'update public.bp_linje set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bp_linje manager_B1 SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.paastand('bp_linje manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.skriv_avvist('bp_linje manager_B1 INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332bbc-0000-4000-8000-00004c332bbc'', 1, ''omsetning'', ''manager_B1B1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje manager_B1 INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e531e-0000-4000-8000-00004a7e531e'', 1, ''omsetning'', ''manager_B1A1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_linje manager_B1 UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_linje manager_B1 UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_linje manager_B1 DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bp_linje manager_B1 DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bp_linje tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447ee-0000-4000-8000-00002ac447ee'), 'negativ');
select pg_temp.paastand('bp_linje tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.bp_linje where id = '2ac447cf-0000-4000-8000-00002ac447cf'), 'negativ');
select pg_temp.skriv_avvist('bp_linje tablet_B1 INSERT B', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''4c332bbe-0000-4000-8000-00004c332bbe'', 1, ''omsetning'', ''tablet_B1B1'', ''120 Mat'', 1000)');
select pg_temp.skriv_avvist('bp_linje tablet_B1 INSERT A', 'insert into public.bp_linje (retailer_id, bp_aar_id, maned, seksjon, kode, post, belop_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''4a7e5320-0000-4000-8000-00004a7e5320'', 1, ''omsetning'', ''tablet_B1A1'', ''120 Mat'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_linje tablet_B1 UPDATE B', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_linje tablet_B1 UPDATE A', 'update public.bp_linje set belop_kr = 2000 where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_linje tablet_B1 DELETE B', 'delete from public.bp_linje where id = ''2ac447ee-0000-4000-8000-00002ac447ee''', 'bp_linje', '2ac447ee-0000-4000-8000-00002ac447ee', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bp_linje('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bp_linje tablet_B1 DELETE A', 'delete from public.bp_linje where id = ''2ac447cf-0000-4000-8000-00002ac447cf''', 'bp_linje', '2ac447cf-0000-4000-8000-00002ac447cf', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 2/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 2/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
