-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 10. Hele matrisen er for stor for Supabase SQL
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
insert into auth.users (id, email) values ('c908142e-0000-4000-8000-0000c908142e', 'sonde-0@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('c908142e-0000-4000-8000-0000c908142e', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 0');
insert into auth.users (id, email) values ('c90817f0-0000-4000-8000-0000c90817f0', 'sonde-1@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('c90817f0-0000-4000-8000-0000c90817f0', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 1');
insert into auth.users (id, email) values ('c9081bb2-0000-4000-8000-0000c9081bb2', 'sonde-2@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('c9081bb2-0000-4000-8000-0000c9081bb2', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 2');
insert into auth.users (id, email) values ('c9088890-0000-4000-8000-0000c9088890', 'sonde-3@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('c9088890-0000-4000-8000-0000c9088890', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 3');
insert into auth.users (id, email) values ('c9088c52-0000-4000-8000-0000c9088c52', 'sonde-4@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('c9088c52-0000-4000-8000-0000c9088c52', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 4');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e44e-0000-4000-8000-00001a99e44e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a58ae-0000-4000-8000-00001a9a58ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acd0e-0000-4000-8000-00001a9acd0e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fbd2-0000-4000-8000-00001aa7fbd2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87032-0000-4000-8000-00001aa87032', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f1f6ce-0000-4000-8000-000075f1f6ce', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-25.csv', 'sonde/25.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('76000e50-0000-4000-8000-000076000e50', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-26.csv', 'sonde/26.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f1f6d0-0000-4000-8000-000075f1f6d0', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-27.csv', 'sonde/27.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f26b30-0000-4000-8000-000075f26b30', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-28.csv', 'sonde/28.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f2df90-0000-4000-8000-000075f2df90', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-29.csv', 'sonde/29.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('76000e69-0000-4000-8000-000076000e69', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-30.csv', 'sonde/30.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('760082c9-0000-4000-8000-0000760082c9', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-31.csv', 'sonde/31.csv', 'epost');
insert into auth.users (id, email) values ('57fa7240-0000-4000-8000-000057fa7240', 'sonde-42@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7240-0000-4000-8000-000057fa7240', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 42');
insert into auth.users (id, email) values ('57fae6a0-0000-4000-8000-000057fae6a0', 'sonde-43@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae6a0-0000-4000-8000-000057fae6a0', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 43');
insert into auth.users (id, email) values ('57fb5b00-0000-4000-8000-000057fb5b00', 'sonde-44@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5b00-0000-4000-8000-000057fb5b00', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 44');
insert into auth.users (id, email) values ('580889c4-0000-4000-8000-0000580889c4', 'sonde-45@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889c4-0000-4000-8000-0000580889c4', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 45');
insert into auth.users (id, email) values ('57fa7244-0000-4000-8000-000057fa7244', 'sonde-46@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7244-0000-4000-8000-000057fa7244', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 46');
insert into auth.users (id, email) values ('57fae6a4-0000-4000-8000-000057fae6a4', 'sonde-47@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae6a4-0000-4000-8000-000057fae6a4', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 47');
insert into auth.users (id, email) values ('57fb5b04-0000-4000-8000-000057fb5b04', 'sonde-48@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5b04-0000-4000-8000-000057fb5b04', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 48');
insert into auth.users (id, email) values ('580889c8-0000-4000-8000-0000580889c8', 'sonde-49@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889c8-0000-4000-8000-0000580889c8', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 49');
insert into auth.users (id, email) values ('57fa725d-0000-4000-8000-000057fa725d', 'sonde-50@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa725d-0000-4000-8000-000057fa725d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 50');
insert into auth.users (id, email) values ('57fae6bd-0000-4000-8000-000057fae6bd', 'sonde-51@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae6bd-0000-4000-8000-000057fae6bd', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 51');
insert into auth.users (id, email) values ('57fb5b1d-0000-4000-8000-000057fb5b1d', 'sonde-52@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5b1d-0000-4000-8000-000057fb5b1d', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 52');
insert into auth.users (id, email) values ('580889e1-0000-4000-8000-0000580889e1', 'sonde-53@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889e1-0000-4000-8000-0000580889e1', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 53');
insert into auth.users (id, email) values ('57fa7261-0000-4000-8000-000057fa7261', 'sonde-54@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7261-0000-4000-8000-000057fa7261', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 54');
insert into auth.users (id, email) values ('57fae6c1-0000-4000-8000-000057fae6c1', 'sonde-55@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fae6c1-0000-4000-8000-000057fae6c1', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 55');
insert into auth.users (id, email) values ('57fb5b21-0000-4000-8000-000057fb5b21', 'sonde-56@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fb5b21-0000-4000-8000-000057fb5b21', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 56');
insert into auth.users (id, email) values ('580889e5-0000-4000-8000-0000580889e5', 'sonde-57@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889e5-0000-4000-8000-0000580889e5', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 57');
insert into auth.users (id, email) values ('580889e6-0000-4000-8000-0000580889e6', 'sonde-58@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889e6-0000-4000-8000-0000580889e6', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 58');
insert into auth.users (id, email) values ('5808fe46-0000-4000-8000-00005808fe46', 'sonde-59@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('5808fe46-0000-4000-8000-00005808fe46', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 59');
insert into auth.users (id, email) values ('57fa727c-0000-4000-8000-000057fa727c', 'sonde-60@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa727c-0000-4000-8000-000057fa727c', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 60');
insert into auth.users (id, email) values ('580889fe-0000-4000-8000-0000580889fe', 'sonde-61@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('580889fe-0000-4000-8000-0000580889fe', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 61');
insert into auth.users (id, email) values ('5808fe5e-0000-4000-8000-00005808fe5e', 'sonde-62@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('5808fe5e-0000-4000-8000-00005808fe5e', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 62');
insert into auth.users (id, email) values ('57fa727f-0000-4000-8000-000057fa727f', 'sonde-63@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa727f-0000-4000-8000-000057fa727f', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 63');
insert into auth.users (id, email) values ('58088a01-0000-4000-8000-000058088a01', 'sonde-64@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('58088a01-0000-4000-8000-000058088a01', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 64');
insert into auth.users (id, email) values ('5808fe61-0000-4000-8000-00005808fe61', 'sonde-65@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('5808fe61-0000-4000-8000-00005808fe61', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 65');
insert into auth.users (id, email) values ('57fa7282-0000-4000-8000-000057fa7282', 'sonde-66@kanari.local') on conflict (id) do nothing;
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values ('57fa7282-0000-4000-8000-000057fa7282', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef', 'Sondesjef 66');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a54c-0000-4000-8000-000038a2a54c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bcce-0000-4000-8000-000038b0bcce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed450-0000-4000-8000-000038bed450', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e03-0000-4000-8000-00003a577e03', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a565-0000-4000-8000-000038a2a565', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bce7-0000-4000-8000-000038b0bce7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed469-0000-4000-8000-000038bed469', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e07-0000-4000-8000-00003a577e07', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a569-0000-4000-8000-000038a2a569', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bceb-0000-4000-8000-000038b0bceb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed46d-0000-4000-8000-000038bed46d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e0b-0000-4000-8000-00003a577e0b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a56d-0000-4000-8000-000038a2a56d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bd04-0000-4000-8000-000038b0bd04', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed486-0000-4000-8000-000038bed486', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e24-0000-4000-8000-00003a577e24', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e25-0000-4000-8000-00003a577e25', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6595a7-0000-4000-8000-00003a6595a7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a588-0000-4000-8000-000038a2a588', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e28-0000-4000-8000-00003a577e28', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6595aa-0000-4000-8000-00003a6595aa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a58b-0000-4000-8000-000038a2a58b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e2b-0000-4000-8000-00003a577e2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6595c2-0000-4000-8000-00003a6595c2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a5a3-0000-4000-8000-000038a2a5a3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdfc4-0000-4000-8000-0000484cdfc4', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-186.csv', 'sonde/186.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af746-0000-4000-8000-0000485af746', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-187.csv', 'sonde/187.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690ec8-0000-4000-8000-000048690ec8', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-188.csv', 'sonde/188.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b866-0000-4000-8000-00004a01b866', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-189.csv', 'sonde/189.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdfdd-0000-4000-8000-0000484cdfdd', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-190.csv', 'sonde/190.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af75f-0000-4000-8000-0000485af75f', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-191.csv', 'sonde/191.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690ee1-0000-4000-8000-000048690ee1', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-192.csv', 'sonde/192.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdfe0-0000-4000-8000-0000484cdfe0', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-193.csv', 'sonde/193.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af762-0000-4000-8000-0000485af762', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-194.csv', 'sonde/194.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690ee4-0000-4000-8000-000048690ee4', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-195.csv', 'sonde/195.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b882-0000-4000-8000-00004a01b882', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-196.csv', 'sonde/196.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdfe4-0000-4000-8000-0000484cdfe4', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-197.csv', 'sonde/197.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af766-0000-4000-8000-0000485af766', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-198.csv', 'sonde/198.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690ee8-0000-4000-8000-000048690ee8', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-199.csv', 'sonde/199.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb26-0000-4000-8000-00004a01bb26', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-200.csv', 'sonde/200.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484ce288-0000-4000-8000-0000484ce288', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-201.csv', 'sonde/201.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485afa0a-0000-4000-8000-0000485afa0a', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-202.csv', 'sonde/202.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4869118c-0000-4000-8000-00004869118c', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-203.csv', 'sonde/203.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb2a-0000-4000-8000-00004a01bb2a', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-204.csv', 'sonde/204.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb2b-0000-4000-8000-00004a01bb2b', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-205.csv', 'sonde/205.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fd2ad-0000-4000-8000-00004a0fd2ad', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-206.csv', 'sonde/206.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484ce28e-0000-4000-8000-0000484ce28e', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-207.csv', 'sonde/207.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb2e-0000-4000-8000-00004a01bb2e', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-208.csv', 'sonde/208.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fd2b0-0000-4000-8000-00004a0fd2b0', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-209.csv', 'sonde/209.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb45-0000-4000-8000-00004a01bb45', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-210.csv', 'sonde/210.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fd2c7-0000-4000-8000-00004a0fd2c7', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-211.csv', 'sonde/211.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484ce2a8-0000-4000-8000-0000484ce2a8', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-212.csv', 'sonde/212.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01bb48-0000-4000-8000-00004a01bb48', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-213.csv', 'sonde/213.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fd2ca-0000-4000-8000-00004a0fd2ca', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-214.csv', 'sonde/214.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484ce2ab-0000-4000-8000-0000484ce2ab', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-215.csv', 'sonde/215.csv', 'epost');
-- --- butikksjef_stasjoner: forutsetninger og proberader ---
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', 'c908142e-0000-4000-8000-0000c908142e');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', 'c90817f0-0000-4000-8000-0000c90817f0');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', 'c9081bb2-0000-4000-8000-0000c9081bb2');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', 'c9088890-0000-4000-8000-0000c9088890');
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', 'c9088c52-0000-4000-8000-0000c9088c52');

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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 5, 'fastA1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 6, 'fastA2', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 7, 'fastA3', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 8, 'fastB1', 'Sondevare', 100);
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 9, 'fastB2', 'Sondevare', 100);

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
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, 'forbedring', 'Sondepunkt fastA1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, 'forbedring', 'Sondepunkt fastA2');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 12, 'forbedring', 'Sondepunkt fastA3');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 13, 'forbedring', 'Sondepunkt fastB1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 14, 'forbedring', 'Sondepunkt fastB2');

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
-- --- ik_avlesninger: forutsetninger og proberader ---
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '1a99e44e-0000-4000-8000-00001a99e44e', date '2026-01-01' + 15, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '1a9a58ae-0000-4000-8000-00001a9a58ae', date '2026-01-01' + 16, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '1a9acd0e-0000-4000-8000-00001a9acd0e', date '2026-01-01' + 17, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '1aa7fbd2-0000-4000-8000-00001aa7fbd2', date '2026-01-01' + 18, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '1aa87032-0000-4000-8000-00001aa87032', date '2026-01-01' + 19, 4.0, true);
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
-- --- import_jobber: forutsetninger og proberader ---
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('4ebec887-0000-4000-8000-00004ebec887', 'aaaa0000-0000-4000-8000-000000000000', null, '75f1f6ce-0000-4000-8000-000075f1f6ce', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('4ebec888-0000-4000-8000-00004ebec888', 'bbbb0000-0000-4000-8000-000000000000', null, '76000e50-0000-4000-8000-000076000e50', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc00-0000-4000-8000-00000d10bc00', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '75f1f6d0-0000-4000-8000-000075f1f6d0', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc01-0000-4000-8000-00000d10bc01', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '75f26b30-0000-4000-8000-000075f26b30', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc02-0000-4000-8000-00000d10bc02', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '75f2df90-0000-4000-8000-000075f2df90', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc1f-0000-4000-8000-00000d10bc1f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '76000e69-0000-4000-8000-000076000e69', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc20-0000-4000-8000-00000d10bc20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '760082c9-0000-4000-8000-0000760082c9', 'st1_salgsstatistikk');

create or replace function pg_temp.nyrad_import_jobber(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_fil uuid := gen_random_uuid();
begin
  insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values (v_fil, p_retailer, 'sonde-' || 'rt' || nextval('tenant_teller'::regclass) || '.csv', 'sonde/' || 'rt' || nextval('tenant_teller'::regclass) || '.csv', 'epost');
  insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype)
  values (p_retailer, p_stasjon, v_fil, 'st1_salgsstatistikk')
  returning id into ny;
  return ny;
end $fn$;
-- --- kalender_kilder: forutsetninger og proberader ---
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf24-0000-4000-8000-0000c95baf24', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde fastA1', 'https://sonde.local/fastA1.ics');
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf25-0000-4000-8000-0000c95baf25', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde fastA2', 'https://sonde.local/fastA2.ics');
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf26-0000-4000-8000-0000c95baf26', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde fastA3', 'https://sonde.local/fastA3.ics');
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf43-0000-4000-8000-0000c95baf43', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekilde fastB1', 'https://sonde.local/fastB1.ics');
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf44-0000-4000-8000-0000c95baf44', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekilde fastB2', 'https://sonde.local/fastB2.ics');

create or replace function pg_temp.nyrad_kalender_kilder(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.kalender_kilder (retailer_id, navn, ical_url)
  values (p_retailer, 'Sondekilde ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'https://sonde.local/' || p_merke || '-' || nextval('tenant_teller'::regclass) || '.ics')
  returning id into ny;
  return ny;
end $fn$;
-- --- kampanjer: forutsetninger og proberader ---
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee5-0000-4000-8000-000047a8eee5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA1', date '2026-01-01' + 37, date '2026-01-01' + 37 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee6-0000-4000-8000-000047a8eee6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA2', date '2026-01-01' + 38, date '2026-01-01' + 38 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee7-0000-4000-8000-000047a8eee7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA3', date '2026-01-01' + 39, date '2026-01-01' + 39 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef04-0000-4000-8000-000047a8ef04', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB1', date '2026-01-01' + 40, date '2026-01-01' + 40 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef05-0000-4000-8000-000047a8ef05', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB2', date '2026-01-01' + 41, date '2026-01-01' + 41 + 7);

-- =====================================================================
-- butikksjef_stasjoner  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('butikksjef_stasjoner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c90817f0-0000-4000-8000-0000c90817f0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT A3 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9081bb2-0000-4000-8000-0000c9081bb2' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa7240-0000-4000-8000-000057fa7240'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''57fae6a0-0000-4000-8000-000057fae6a0'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''57fb5b00-0000-4000-8000-000057fb5b00'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_A INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889c4-0000-4000-8000-0000580889c4'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000001', 'c908142e-0000-4000-8000-0000c908142e');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000002', 'c90817f0-0000-4000-8000-0000c90817f0');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_A DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('a1110000-0000-4000-8000-000000000003', 'c9081bb2-0000-4000-8000-0000c9081bb2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_A DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c90817f0-0000-4000-8000-0000c90817f0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9081bb2-0000-4000-8000-0000c9081bb2' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa7244-0000-4000-8000-000057fa7244'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''57fae6a4-0000-4000-8000-000057fae6a4'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''57fb5b04-0000-4000-8000-000057fb5b04'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889c8-0000-4000-8000-0000580889c8'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c90817f0-0000-4000-8000-0000c90817f0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9081bb2-0000-4000-8000-0000c9081bb2' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa725d-0000-4000-8000-000057fa725d'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''57fae6bd-0000-4000-8000-000057fae6bd'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''57fb5b1d-0000-4000-8000-000057fb5b1d'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_A12 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889e1-0000-4000-8000-0000580889e1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_A12 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c90817f0-0000-4000-8000-0000c90817f0' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9081bb2-0000-4000-8000-0000c9081bb2' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa7261-0000-4000-8000-000057fa7261'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000002'', ''57fae6c1-0000-4000-8000-000057fae6c1'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT A3', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000003'', ''57fb5b21-0000-4000-8000-000057fb5b21'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_A1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889e5-0000-4000-8000-0000580889e5'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE A3', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c90817f0-0000-4000-8000-0000c90817f0'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE A3', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''', 'butikksjef_stasjoner', '"profil_id" = ''c9081bb2-0000-4000-8000-0000c9081bb2'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_A1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B1 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT B2 -> ser', exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088c52-0000-4000-8000-0000c9088c52' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'positiv');
select pg_temp.paastand('butikksjef_stasjoner owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889e6-0000-4000-8000-0000580889e6'')');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''5808fe46-0000-4000-8000-00005808fe46'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner owner_B INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa727c-0000-4000-8000-000057fa727c'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000001', 'c9088890-0000-4000-8000-0000c9088890');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('butikksjef_stasjoner owner_B DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values ('b1110000-0000-4000-8000-000000000002', 'c9088c52-0000-4000-8000-0000c9088c52');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner owner_B DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088c52-0000-4000-8000-0000c9088c52' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''580889fe-0000-4000-8000-0000580889fe'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''5808fe5e-0000-4000-8000-00005808fe5e'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner manager_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa727f-0000-4000-8000-000057fa727f'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner manager_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088890-0000-4000-8000-0000c9088890' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c9088c52-0000-4000-8000-0000c9088c52' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002'), 'negativ');
select pg_temp.paastand('butikksjef_stasjoner tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.butikksjef_stasjoner where "profil_id" = 'c908142e-0000-4000-8000-0000c908142e' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001'), 'negativ');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000001'', ''58088a01-0000-4000-8000-000058088a01'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT B2', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''b1110000-0000-4000-8000-000000000002'', ''5808fe61-0000-4000-8000-00005808fe61'')');
select pg_temp.skriv_avvist('butikksjef_stasjoner tablet_B1 INSERT A1', 'insert into public.butikksjef_stasjoner (stasjon_id, profil_id) values (''a1110000-0000-4000-8000-000000000001'', ''57fa7282-0000-4000-8000-000057fa7282'')');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE B2', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 UPDATE A1', 'update public.butikksjef_stasjoner set opprettet_tid = now() where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c9088890-0000-4000-8000-0000c9088890'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE B2', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''', 'butikksjef_stasjoner', '"profil_id" = ''c9088c52-0000-4000-8000-0000c9088c52'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002''');
select pg_temp.som_eier();
select pg_temp.nyrad_butikksjef_stasjoner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('butikksjef_stasjoner tablet_B1 DELETE A1', 'delete from public.butikksjef_stasjoner where "profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''', 'butikksjef_stasjoner', '"profil_id" = ''c908142e-0000-4000-8000-0000c908142e'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001''');

-- =====================================================================
-- daglig_salg  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('daglig_salg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('daglig_salg owner_A SELECT A1 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dc-0000-4000-8000-00008c5a54dc'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A2 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54dd-0000-4000-8000-00008c5a54dd'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT A3 -> ser', exists (select 1 from public.daglig_salg where id = '8c5a54de-0000-4000-8000-00008c5a54de'), 'positiv');
select pg_temp.paastand('daglig_salg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.daglig_salg where id = '8c5a54fb-0000-4000-8000-00008c5a54fb'), 'negativ');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 67, ''owner_AA1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 68, ''owner_AA2'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_A INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 69, ''owner_AA3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_A INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 70, ''owner_AB1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dc-0000-4000-8000-00008c5a54dc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 71, 'gjenowner_AA1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A2', 'delete from public.daglig_salg where id = ''8c5a54dd-0000-4000-8000-00008c5a54dd''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54dd-0000-4000-8000-00008c5a54dd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 72, 'gjenowner_AA2', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('daglig_salg owner_A DELETE A3', 'delete from public.daglig_salg where id = ''8c5a54de-0000-4000-8000-00008c5a54de''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54de-0000-4000-8000-00008c5a54de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 73, 'gjenowner_AA3', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 74, ''manager_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 75, ''manager_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 76, ''manager_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 77, ''manager_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 78, ''manager_A12A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 79, ''manager_A12A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 80, ''manager_A12A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_A12 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 81, ''manager_A12B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 82, ''tablet_A1A1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 83, ''tablet_A1A2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT A3', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 84, ''tablet_A1A3'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_A1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 85, ''tablet_A1B1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 86, ''owner_BB1'', ''Sondevare'', 100)');
select pg_temp.skriv_tillatt('daglig_salg owner_B INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 87, ''owner_BB2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg owner_B INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 88, ''owner_BA1'', ''Sondevare'', 100)');
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
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fb-0000-4000-8000-00008c5a54fb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 89, 'gjenowner_BB1', 'Sondevare', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_daglig_salg('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('daglig_salg owner_B DELETE B2', 'delete from public.daglig_salg where id = ''8c5a54fc-0000-4000-8000-00008c5a54fc''');
select pg_temp.som_eier();
insert into public.daglig_salg (id, retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values ('8c5a54fc-0000-4000-8000-00008c5a54fc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 90, 'gjenowner_BB2', 'Sondevare', 100);
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
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 91, ''manager_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 92, ''manager_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg manager_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 93, ''manager_B1A1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 94, ''tablet_B1B1'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT B2', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 95, ''tablet_B1B2'', ''Sondevare'', 100)');
select pg_temp.skriv_avvist('daglig_salg tablet_B1 INSERT A1', 'insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean, varenavn, omsetning_eks_mva) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 96, ''tablet_B1A1'', ''Sondevare'', 100)');
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
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 97, ''forbedring'', ''Sondepunkt owner_AA1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 98, ''forbedring'', ''Sondepunkt owner_AA2'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 99, ''forbedring'', ''Sondepunkt owner_AA3'')');
select pg_temp.skriv_avvist('fokuspunkter owner_A INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 100, ''forbedring'', ''Sondepunkt owner_AB1'')');
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
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 101, 'forbedring', 'Sondepunkt gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 102, 'forbedring', 'Sondepunkt gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 103, 'forbedring', 'Sondepunkt gjenowner_AA3');
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
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 104, ''forbedring'', ''Sondepunkt manager_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 105, ''forbedring'', ''Sondepunkt manager_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 106, ''forbedring'', ''Sondepunkt manager_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 107, ''forbedring'', ''Sondepunkt manager_A1B1'')');
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
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 108, ''forbedring'', ''Sondepunkt manager_A12A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 109, ''forbedring'', ''Sondepunkt manager_A12A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 110, ''forbedring'', ''Sondepunkt manager_A12A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 111, ''forbedring'', ''Sondepunkt manager_A12B1'')');
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
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 112, ''forbedring'', ''Sondepunkt tablet_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 113, ''forbedring'', ''Sondepunkt tablet_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 114, ''forbedring'', ''Sondepunkt tablet_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 115, ''forbedring'', ''Sondepunkt tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 116, ''forbedring'', ''Sondepunkt owner_BB1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 117, ''forbedring'', ''Sondepunkt owner_BB2'')');
select pg_temp.skriv_avvist('fokuspunkter owner_B INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 118, ''forbedring'', ''Sondepunkt owner_BA1'')');
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
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 119, 'forbedring', 'Sondepunkt gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B DELETE B2', 'delete from public.fokuspunkter where id = ''384b1313-0000-4000-8000-0000384b1313''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 120, 'forbedring', 'Sondepunkt gjenowner_BB2');
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
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 121, ''forbedring'', ''Sondepunkt manager_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 122, ''forbedring'', ''Sondepunkt manager_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 123, ''forbedring'', ''Sondepunkt manager_B1A1'')');
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
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 124, ''forbedring'', ''Sondepunkt tablet_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 125, ''forbedring'', ''Sondepunkt tablet_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 126, ''forbedring'', ''Sondepunkt tablet_B1A1'')');
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

-- =====================================================================
-- ik_avlesninger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ik_avlesninger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ik_avlesninger owner_A SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT A3 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a54c-0000-4000-8000-000038a2a54c'', date ''2026-01-01'' + 127, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bcce-0000-4000-8000-000038b0bcce'', date ''2026-01-01'' + 128, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed450-0000-4000-8000-000038bed450'', date ''2026-01-01'' + 129, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e03-0000-4000-8000-00003a577e03'', date ''2026-01-01'' + 130, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a565-0000-4000-8000-000038a2a565'', date ''2026-01-01'' + 131, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bce7-0000-4000-8000-000038b0bce7'', date ''2026-01-01'' + 132, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed469-0000-4000-8000-000038bed469'', date ''2026-01-01'' + 133, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e07-0000-4000-8000-00003a577e07'', date ''2026-01-01'' + 134, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a569-0000-4000-8000-000038a2a569'', date ''2026-01-01'' + 135, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bceb-0000-4000-8000-000038b0bceb'', date ''2026-01-01'' + 136, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed46d-0000-4000-8000-000038bed46d'', date ''2026-01-01'' + 137, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e0b-0000-4000-8000-00003a577e0b'', date ''2026-01-01'' + 138, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a56d-0000-4000-8000-000038a2a56d'', date ''2026-01-01'' + 139, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bd04-0000-4000-8000-000038b0bd04'', date ''2026-01-01'' + 140, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed486-0000-4000-8000-000038bed486'', date ''2026-01-01'' + 141, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e24-0000-4000-8000-00003a577e24'', date ''2026-01-01'' + 142, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e25-0000-4000-8000-00003a577e25'', date ''2026-01-01'' + 143, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6595a7-0000-4000-8000-00003a6595a7'', date ''2026-01-01'' + 144, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a588-0000-4000-8000-000038a2a588'', date ''2026-01-01'' + 145, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e28-0000-4000-8000-00003a577e28'', date ''2026-01-01'' + 146, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6595aa-0000-4000-8000-00003a6595aa'', date ''2026-01-01'' + 147, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a58b-0000-4000-8000-000038a2a58b'', date ''2026-01-01'' + 148, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e2b-0000-4000-8000-00003a577e2b'', date ''2026-01-01'' + 149, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6595c2-0000-4000-8000-00003a6595c2'', date ''2026-01-01'' + 150, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a5a3-0000-4000-8000-000038a2a5a3'', date ''2026-01-01'' + 151, 4.0, true)');

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

-- =====================================================================
-- import_jobber  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('import_jobber');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('import_jobber owner_A SELECT A1 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'positiv');
select pg_temp.paastand('import_jobber owner_A SELECT A2 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc01-0000-4000-8000-00000d10bc01'), 'positiv');
select pg_temp.paastand('import_jobber owner_A SELECT A3 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc02-0000-4000-8000-00000d10bc02'), 'positiv');
select pg_temp.paastand('import_jobber owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'negativ');
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdfc4-0000-4000-8000-0000484cdfc4'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af746-0000-4000-8000-0000485af746'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690ec8-0000-4000-8000-000048690ec8'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber owner_A INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b866-0000-4000-8000-00004a01b866'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A UPDATE A2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc01-0000-4000-8000-00000d10bc01''');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A UPDATE A3', 'update public.import_jobber set forsok = 1 where id = ''0d10bc02-0000-4000-8000-00000d10bc02''');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('import_jobber owner_A UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc00-0000-4000-8000-00000d10bc00', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '484cdfdd-0000-4000-8000-0000484cdfdd', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A DELETE A2', 'delete from public.import_jobber where id = ''0d10bc01-0000-4000-8000-00000d10bc01''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc01-0000-4000-8000-00000d10bc01', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '485af75f-0000-4000-8000-0000485af75f', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A DELETE A3', 'delete from public.import_jobber where id = ''0d10bc02-0000-4000-8000-00000d10bc02''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc02-0000-4000-8000-00000d10bc02', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '48690ee1-0000-4000-8000-000048690ee1', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('import_jobber owner_A DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.paastand('import_jobber owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'positiv');
select pg_temp.paastand('import_jobber owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('import_jobber manager_A1 SELECT A1 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'positiv');
select pg_temp.paastand('import_jobber manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc01-0000-4000-8000-00000d10bc01'), 'negativ');
select pg_temp.paastand('import_jobber manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc02-0000-4000-8000-00000d10bc02'), 'negativ');
select pg_temp.paastand('import_jobber manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'negativ');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdfe0-0000-4000-8000-0000484cdfe0'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af762-0000-4000-8000-0000485af762'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690ee4-0000-4000-8000-000048690ee4'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b882-0000-4000-8000-00004a01b882'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 UPDATE A2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 UPDATE A3', 'update public.import_jobber set forsok = 1 where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 DELETE A2', 'delete from public.import_jobber where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 DELETE A3', 'delete from public.import_jobber where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('import_jobber manager_A1 DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.paastand('import_jobber manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');
select pg_temp.paastand('import_jobber manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('import_jobber manager_A12 SELECT A1 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'positiv');
select pg_temp.paastand('import_jobber manager_A12 SELECT A2 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc01-0000-4000-8000-00000d10bc01'), 'positiv');
select pg_temp.paastand('import_jobber manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc02-0000-4000-8000-00000d10bc02'), 'negativ');
select pg_temp.paastand('import_jobber manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'negativ');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdfe4-0000-4000-8000-0000484cdfe4'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af766-0000-4000-8000-0000485af766'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690ee8-0000-4000-8000-000048690ee8'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01bb26-0000-4000-8000-00004a01bb26'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 UPDATE A2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 UPDATE A3', 'update public.import_jobber set forsok = 1 where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 DELETE A2', 'delete from public.import_jobber where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 DELETE A3', 'delete from public.import_jobber where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('import_jobber manager_A12 DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.paastand('import_jobber manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');
select pg_temp.paastand('import_jobber manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('import_jobber tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'negativ');
select pg_temp.paastand('import_jobber tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc01-0000-4000-8000-00000d10bc01'), 'negativ');
select pg_temp.paastand('import_jobber tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc02-0000-4000-8000-00000d10bc02'), 'negativ');
select pg_temp.paastand('import_jobber tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'negativ');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484ce288-0000-4000-8000-0000484ce288'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485afa0a-0000-4000-8000-0000485afa0a'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4869118c-0000-4000-8000-00004869118c'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01bb2a-0000-4000-8000-00004a01bb2a'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 UPDATE A2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 UPDATE A3', 'update public.import_jobber set forsok = 1 where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 DELETE A2', 'delete from public.import_jobber where id = ''0d10bc01-0000-4000-8000-00000d10bc01''', 'import_jobber', '0d10bc01-0000-4000-8000-00000d10bc01', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 DELETE A3', 'delete from public.import_jobber where id = ''0d10bc02-0000-4000-8000-00000d10bc02''', 'import_jobber', '0d10bc02-0000-4000-8000-00000d10bc02', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('import_jobber tablet_A1 DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.paastand('import_jobber tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');
select pg_temp.paastand('import_jobber tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('import_jobber owner_B SELECT B1 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'positiv');
select pg_temp.paastand('import_jobber owner_B SELECT B2 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc20-0000-4000-8000-00000d10bc20'), 'positiv');
select pg_temp.paastand('import_jobber owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'negativ');
select pg_temp.skriv_tillatt('import_jobber owner_B INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01bb2b-0000-4000-8000-00004a01bb2b'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_B INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fd2ad-0000-4000-8000-00004a0fd2ad'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber owner_B INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484ce28e-0000-4000-8000-0000484ce28e'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('import_jobber owner_B UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('import_jobber owner_B UPDATE B2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc20-0000-4000-8000-00000d10bc20''');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('import_jobber owner_B UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('import_jobber owner_B DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc1f-0000-4000-8000-00000d10bc1f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '4a01bb2e-0000-4000-8000-00004a01bb2e', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('import_jobber owner_B DELETE B2', 'delete from public.import_jobber where id = ''0d10bc20-0000-4000-8000-00000d10bc20''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc20-0000-4000-8000-00000d10bc20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '4a0fd2b0-0000-4000-8000-00004a0fd2b0', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('import_jobber owner_B DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.paastand('import_jobber owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'positiv');
select pg_temp.paastand('import_jobber owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('import_jobber manager_B1 SELECT B1 -> ser', exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'positiv');
select pg_temp.paastand('import_jobber manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc20-0000-4000-8000-00000d10bc20'), 'negativ');
select pg_temp.paastand('import_jobber manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'negativ');
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01bb45-0000-4000-8000-00004a01bb45'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fd2c7-0000-4000-8000-00004a0fd2c7'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484ce2a8-0000-4000-8000-0000484ce2a8'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 UPDATE B2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc20-0000-4000-8000-00000d10bc20''', 'import_jobber', '0d10bc20-0000-4000-8000-00000d10bc20', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 DELETE B2', 'delete from public.import_jobber where id = ''0d10bc20-0000-4000-8000-00000d10bc20''', 'import_jobber', '0d10bc20-0000-4000-8000-00000d10bc20', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('import_jobber manager_B1 DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.paastand('import_jobber manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');
select pg_temp.paastand('import_jobber manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('import_jobber tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc1f-0000-4000-8000-00000d10bc1f'), 'negativ');
select pg_temp.paastand('import_jobber tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc20-0000-4000-8000-00000d10bc20'), 'negativ');
select pg_temp.paastand('import_jobber tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.import_jobber where id = '0d10bc00-0000-4000-8000-00000d10bc00'), 'negativ');
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01bb48-0000-4000-8000-00004a01bb48'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fd2ca-0000-4000-8000-00004a0fd2ca'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484ce2ab-0000-4000-8000-0000484ce2ab'', ''st1_salgsstatistikk'')');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 UPDATE B1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 UPDATE B2', 'update public.import_jobber set forsok = 1 where id = ''0d10bc20-0000-4000-8000-00000d10bc20''', 'import_jobber', '0d10bc20-0000-4000-8000-00000d10bc20', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 UPDATE A1', 'update public.import_jobber set forsok = 1 where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 DELETE B1', 'delete from public.import_jobber where id = ''0d10bc1f-0000-4000-8000-00000d10bc1f''', 'import_jobber', '0d10bc1f-0000-4000-8000-00000d10bc1f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 DELETE B2', 'delete from public.import_jobber where id = ''0d10bc20-0000-4000-8000-00000d10bc20''', 'import_jobber', '0d10bc20-0000-4000-8000-00000d10bc20', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('import_jobber tablet_B1 DELETE A1', 'delete from public.import_jobber where id = ''0d10bc00-0000-4000-8000-00000d10bc00''', 'import_jobber', '0d10bc00-0000-4000-8000-00000d10bc00', 'id');
select pg_temp.paastand('import_jobber tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.import_jobber where id = '4ebec888-0000-4000-8000-00004ebec888'), 'negativ');
select pg_temp.paastand('import_jobber tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.import_jobber where id = '4ebec887-0000-4000-8000-00004ebec887'), 'negativ');

-- =====================================================================
-- kalender_kilder  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kalender_kilder');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kalender_kilder owner_A SELECT A -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'positiv');
select pg_temp.paastand('kalender_kilder owner_A SELECT B -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'negativ');
select pg_temp.skriv_tillatt('kalender_kilder owner_A INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde owner_AA1'', ''https://sonde.local/owner_AA1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder owner_A INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde owner_AB1'', ''https://sonde.local/owner_AB1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kalender_kilder owner_A UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kalender_kilder owner_A UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kalender_kilder owner_A DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf24-0000-4000-8000-0000c95baf24', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde gjenowner_AA1', 'https://sonde.local/gjenowner_AA1.ics');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kalender_kilder owner_A DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.skriv_avvist('kalender_kilder owner_A FLYTTER egen rad -> kjede B', 'update public.kalender_kilder set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kalender_kilder manager_A1 SELECT A -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'positiv');
select pg_temp.paastand('kalender_kilder manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'negativ');
select pg_temp.skriv_tillatt('kalender_kilder manager_A1 INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde manager_A1A1'', ''https://sonde.local/manager_A1A1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder manager_A1 INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde manager_A1B1'', ''https://sonde.local/manager_A1B1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('kalender_kilder manager_A1 UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kalender_kilder manager_A1 UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('kalender_kilder manager_A1 DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf24-0000-4000-8000-0000c95baf24', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde gjenmanager_A1A1', 'https://sonde.local/gjenmanager_A1A1.ics');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kalender_kilder manager_A1 DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.skriv_avvist('kalender_kilder manager_A1 FLYTTER egen rad -> kjede B', 'update public.kalender_kilder set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kalender_kilder manager_A12 SELECT A -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'positiv');
select pg_temp.paastand('kalender_kilder manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'negativ');
select pg_temp.skriv_tillatt('kalender_kilder manager_A12 INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde manager_A12A1'', ''https://sonde.local/manager_A12A1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder manager_A12 INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde manager_A12B1'', ''https://sonde.local/manager_A12B1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('kalender_kilder manager_A12 UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kalender_kilder manager_A12 UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('kalender_kilder manager_A12 DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''');
select pg_temp.som_eier();
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf24-0000-4000-8000-0000c95baf24', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekilde gjenmanager_A12A1', 'https://sonde.local/gjenmanager_A12A1.ics');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kalender_kilder manager_A12 DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.skriv_avvist('kalender_kilder manager_A12 FLYTTER egen rad -> kjede B', 'update public.kalender_kilder set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kalender_kilder tablet_A1 SELECT A -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'positiv');
select pg_temp.paastand('kalender_kilder tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'negativ');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde tablet_A1A1'', ''https://sonde.local/tablet_A1A1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde tablet_A1B1'', ''https://sonde.local/tablet_A1B1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kalender_kilder tablet_A1 DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kalender_kilder owner_B SELECT B -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'positiv');
select pg_temp.paastand('kalender_kilder owner_B SELECT A -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'negativ');
select pg_temp.skriv_tillatt('kalender_kilder owner_B INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde owner_BB1'', ''https://sonde.local/owner_BB1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder owner_B INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde owner_BA1'', ''https://sonde.local/owner_BA1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kalender_kilder owner_B UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kalender_kilder owner_B UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kalender_kilder owner_B DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''');
select pg_temp.som_eier();
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf43-0000-4000-8000-0000c95baf43', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekilde gjenowner_BB1', 'https://sonde.local/gjenowner_BB1.ics');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kalender_kilder owner_B DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.skriv_avvist('kalender_kilder owner_B FLYTTER egen rad -> kjede A', 'update public.kalender_kilder set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kalender_kilder manager_B1 SELECT B -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'positiv');
select pg_temp.paastand('kalender_kilder manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'negativ');
select pg_temp.skriv_tillatt('kalender_kilder manager_B1 INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde manager_B1B1'', ''https://sonde.local/manager_B1B1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder manager_B1 INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde manager_B1A1'', ''https://sonde.local/manager_B1A1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('kalender_kilder manager_B1 UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kalender_kilder manager_B1 UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('kalender_kilder manager_B1 DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''');
select pg_temp.som_eier();
insert into public.kalender_kilder (id, retailer_id, navn, ical_url) values ('c95baf43-0000-4000-8000-0000c95baf43', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekilde gjenmanager_B1B1', 'https://sonde.local/gjenmanager_B1B1.ics');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kalender_kilder manager_B1 DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.skriv_avvist('kalender_kilder manager_B1 FLYTTER egen rad -> kjede A', 'update public.kalender_kilder set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kalender_kilder tablet_B1 SELECT B -> ser', exists (select 1 from public.kalender_kilder where id = 'c95baf43-0000-4000-8000-0000c95baf43'), 'positiv');
select pg_temp.paastand('kalender_kilder tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.kalender_kilder where id = 'c95baf24-0000-4000-8000-0000c95baf24'), 'negativ');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 INSERT B', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekilde tablet_B1B1'', ''https://sonde.local/tablet_B1B1.ics'')');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 INSERT A', 'insert into public.kalender_kilder (retailer_id, navn, ical_url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekilde tablet_B1A1'', ''https://sonde.local/tablet_B1A1.ics'')');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 UPDATE B', 'update public.kalender_kilder set aktiv = false where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 UPDATE A', 'update public.kalender_kilder set aktiv = false where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 DELETE B', 'delete from public.kalender_kilder where id = ''c95baf43-0000-4000-8000-0000c95baf43''', 'kalender_kilder', 'c95baf43-0000-4000-8000-0000c95baf43', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kalender_kilder('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kalender_kilder tablet_B1 DELETE A', 'delete from public.kalender_kilder where id = ''c95baf24-0000-4000-8000-0000c95baf24''', 'kalender_kilder', 'c95baf24-0000-4000-8000-0000c95baf24', 'id');

-- =====================================================================
-- kampanjer  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kampanjer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kampanjer owner_A SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer owner_A SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer owner_A INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AA1'', date ''2026-01-01'' + 235, date ''2026-01-01'' + 235 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_A INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AB1'', date ''2026-01-01'' + 236, date ''2026-01-01'' + 236 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kampanjer manager_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1A1'', date ''2026-01-01'' + 237, date ''2026-01-01'' + 237 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1B1'', date ''2026-01-01'' + 238, date ''2026-01-01'' + 238 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kampanjer manager_A12 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12A1'', date ''2026-01-01'' + 239, date ''2026-01-01'' + 239 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12B1'', date ''2026-01-01'' + 240, date ''2026-01-01'' + 240 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kampanjer tablet_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1A1'', date ''2026-01-01'' + 241, date ''2026-01-01'' + 241 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1B1'', date ''2026-01-01'' + 242, date ''2026-01-01'' + 242 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kampanjer owner_B SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer owner_B SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BB1'', date ''2026-01-01'' + 243, date ''2026-01-01'' + 243 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BA1'', date ''2026-01-01'' + 244, date ''2026-01-01'' + 244 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kampanjer manager_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1B1'', date ''2026-01-01'' + 245, date ''2026-01-01'' + 245 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1A1'', date ''2026-01-01'' + 246, date ''2026-01-01'' + 246 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kampanjer tablet_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1B1'', date ''2026-01-01'' + 247, date ''2026-01-01'' + 247 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1A1'', date ''2026-01-01'' + 248, date ''2026-01-01'' + 248 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 3/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 3/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
