-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 9. Hele matrisen er for stor for Supabase SQL
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
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcb4cb-0000-4000-8000-000084fcb4cb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcb88d-0000-4000-8000-000084fcb88d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fcbc4f-0000-4000-8000-000084fcbc4f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fd292d-0000-4000-8000-000084fd292d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('84fd2cef-0000-4000-8000-000084fd2cef', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f1f6af-0000-4000-8000-000075f1f6af', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-15.csv', 'sonde/15.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('76000e31-0000-4000-8000-000076000e31', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-16.csv', 'sonde/16.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f1f6b1-0000-4000-8000-000075f1f6b1', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-17.csv', 'sonde/17.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f26b11-0000-4000-8000-000075f26b11', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-18.csv', 'sonde/18.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('75f2df71-0000-4000-8000-000075f2df71', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-19.csv', 'sonde/19.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('76000e4a-0000-4000-8000-000076000e4a', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-20.csv', 'sonde/20.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('760082aa-0000-4000-8000-0000760082aa', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-21.csv', 'sonde/21.csv', 'epost');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e50a-0000-4000-8000-00001a99e50a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a596a-0000-4000-8000-00001a9a596a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acdca-0000-4000-8000-00001a9acdca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fca3-0000-4000-8000-00001aa7fca3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e523-0000-4000-8000-00001a99e523', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a5983-0000-4000-8000-00001a9a5983', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acde3-0000-4000-8000-00001a9acde3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fca7-0000-4000-8000-00001aa7fca7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e527-0000-4000-8000-00001a99e527', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a5987-0000-4000-8000-00001a9a5987', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acde7-0000-4000-8000-00001a9acde7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcab-0000-4000-8000-00001aa7fcab', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e52b-0000-4000-8000-00001a99e52b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a59a0-0000-4000-8000-00001a9a59a0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9ace00-0000-4000-8000-00001a9ace00', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc4-0000-4000-8000-00001aa7fcc4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc5-0000-4000-8000-00001aa7fcc5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87125-0000-4000-8000-00001aa87125', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e546-0000-4000-8000-00001a99e546', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fcc8-0000-4000-8000-00001aa7fcc8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa87128-0000-4000-8000-00001aa87128', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e549-0000-4000-8000-00001a99e549', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fccb-0000-4000-8000-00001aa7fccb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659527-0000-4000-8000-00003a659527', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a508-0000-4000-8000-000038a2a508', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf29-0000-4000-8000-0000484cdf29', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-136.csv', 'sonde/136.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af6ab-0000-4000-8000-0000485af6ab', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-137.csv', 'sonde/137.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690e2d-0000-4000-8000-000048690e2d', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-138.csv', 'sonde/138.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b7cb-0000-4000-8000-00004a01b7cb', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-139.csv', 'sonde/139.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf42-0000-4000-8000-0000484cdf42', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-140.csv', 'sonde/140.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af6c4-0000-4000-8000-0000485af6c4', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-141.csv', 'sonde/141.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690e46-0000-4000-8000-000048690e46', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-142.csv', 'sonde/142.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf45-0000-4000-8000-0000484cdf45', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-143.csv', 'sonde/143.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af6c7-0000-4000-8000-0000485af6c7', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-144.csv', 'sonde/144.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690e49-0000-4000-8000-000048690e49', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-145.csv', 'sonde/145.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b7e7-0000-4000-8000-00004a01b7e7', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-146.csv', 'sonde/146.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf49-0000-4000-8000-0000484cdf49', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-147.csv', 'sonde/147.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af6cb-0000-4000-8000-0000485af6cb', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-148.csv', 'sonde/148.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690e4d-0000-4000-8000-000048690e4d', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-149.csv', 'sonde/149.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b800-0000-4000-8000-00004a01b800', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-150.csv', 'sonde/150.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf62-0000-4000-8000-0000484cdf62', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-151.csv', 'sonde/151.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('485af6e4-0000-4000-8000-0000485af6e4', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-152.csv', 'sonde/152.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('48690e66-0000-4000-8000-000048690e66', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-153.csv', 'sonde/153.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b804-0000-4000-8000-00004a01b804', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-154.csv', 'sonde/154.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b805-0000-4000-8000-00004a01b805', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-155.csv', 'sonde/155.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fcf87-0000-4000-8000-00004a0fcf87', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-156.csv', 'sonde/156.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf68-0000-4000-8000-0000484cdf68', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-157.csv', 'sonde/157.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b808-0000-4000-8000-00004a01b808', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-158.csv', 'sonde/158.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fcf8a-0000-4000-8000-00004a0fcf8a', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-159.csv', 'sonde/159.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b81f-0000-4000-8000-00004a01b81f', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-160.csv', 'sonde/160.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fcfa1-0000-4000-8000-00004a0fcfa1', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-161.csv', 'sonde/161.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf82-0000-4000-8000-0000484cdf82', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-162.csv', 'sonde/162.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a01b822-0000-4000-8000-00004a01b822', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-163.csv', 'sonde/163.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('4a0fcfa4-0000-4000-8000-00004a0fcfa4', 'bbbb0000-0000-4000-8000-000000000000', 'sonde-164.csv', 'sonde/164.csv', 'epost');
insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal) values ('484cdf85-0000-4000-8000-0000484cdf85', 'aaaa0000-0000-4000-8000-000000000000', 'sonde-165.csv', 'sonde/165.csv', 'epost');
-- --- fokuspunkter: forutsetninger og proberader ---
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0, 'forbedring', 'Sondepunkt fastA1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1, 'forbedring', 'Sondepunkt fastA2');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2, 'forbedring', 'Sondepunkt fastA3');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3, 'forbedring', 'Sondepunkt fastB1');
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4, 'forbedring', 'Sondepunkt fastB2');

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
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '84fcb4cb-0000-4000-8000-000084fcb4cb', date '2026-01-01' + 5, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '84fcb88d-0000-4000-8000-000084fcb88d', date '2026-01-01' + 6, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '84fcbc4f-0000-4000-8000-000084fcbc4f', date '2026-01-01' + 7, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '84fd292d-0000-4000-8000-000084fd292d', date '2026-01-01' + 8, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '84fd2cef-0000-4000-8000-000084fd2cef', date '2026-01-01' + 9, 4.0, true);
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
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('4ebec887-0000-4000-8000-00004ebec887', 'aaaa0000-0000-4000-8000-000000000000', null, '75f1f6af-0000-4000-8000-000075f1f6af', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('4ebec888-0000-4000-8000-00004ebec888', 'bbbb0000-0000-4000-8000-000000000000', null, '76000e31-0000-4000-8000-000076000e31', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc00-0000-4000-8000-00000d10bc00', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '75f1f6b1-0000-4000-8000-000075f1f6b1', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc01-0000-4000-8000-00000d10bc01', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '75f26b11-0000-4000-8000-000075f26b11', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc02-0000-4000-8000-00000d10bc02', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '75f2df71-0000-4000-8000-000075f2df71', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc1f-0000-4000-8000-00000d10bc1f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '76000e4a-0000-4000-8000-000076000e4a', 'st1_salgsstatistikk');
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc20-0000-4000-8000-00000d10bc20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '760082aa-0000-4000-8000-0000760082aa', 'st1_salgsstatistikk');

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
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee5-0000-4000-8000-000047a8eee5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA1', date '2026-01-01' + 27, date '2026-01-01' + 27 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee6-0000-4000-8000-000047a8eee6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA2', date '2026-01-01' + 28, date '2026-01-01' + 28 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee7-0000-4000-8000-000047a8eee7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA3', date '2026-01-01' + 29, date '2026-01-01' + 29 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef04-0000-4000-8000-000047a8ef04', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB1', date '2026-01-01' + 30, date '2026-01-01' + 30 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef05-0000-4000-8000-000047a8ef05', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB2', date '2026-01-01' + 31, date '2026-01-01' + 31 + 7);
-- --- kassererstatistikk: forutsetninger og proberader ---
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 32, 'fastA1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 33, 'fastA2', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 34, 'fastA3', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 'fastB1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 'fastB2', 'Sonde Sondesen', 1000, 10);

create or replace function pg_temp.nyrad_kassererstatistikk(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 1000, 10);
end $fn$;
-- --- kategori_vaerprofil: forutsetninger og proberader ---
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'avdeling', 'fastA1');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'avdeling', 'fastA2');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'avdeling', 'fastA3');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'avdeling', 'fastB1');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'avdeling', 'fastB2');
-- --- konkurranser: forutsetninger og proberader ---
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515953-0000-4000-8000-00001c515953', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA1', 'omsetning sonde', date '2026-01-01' + 42, date '2026-01-01' + 42 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515954-0000-4000-8000-00001c515954', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA2', 'omsetning sonde', date '2026-01-01' + 43, date '2026-01-01' + 43 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515955-0000-4000-8000-00001c515955', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA3', 'omsetning sonde', date '2026-01-01' + 44, date '2026-01-01' + 44 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515972-0000-4000-8000-00001c515972', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastB1', 'omsetning sonde', date '2026-01-01' + 45, date '2026-01-01' + 45 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515973-0000-4000-8000-00001c515973', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastB2', 'omsetning sonde', date '2026-01-01' + 46, date '2026-01-01' + 46 + 30);

create or replace function pg_temp.nyrad_konkurranser(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt)
  values (p_retailer, 'Sondekonkurranse ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'omsetning sonde', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, date '2030-01-01' + nextval('tenant_teller'::regclass)::int + 30)
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- fokuspunkter  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('fokuspunkter');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('fokuspunkter owner_A SELECT A1 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f3-0000-4000-8000-0000384b12f3'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT A2 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f4-0000-4000-8000-0000384b12f4'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT A3 -> ser', exists (select 1 from public.fokuspunkter where id = '384b12f5-0000-4000-8000-0000384b12f5'), 'positiv');
select pg_temp.paastand('fokuspunkter owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.fokuspunkter where id = '384b1312-0000-4000-8000-0000384b1312'), 'negativ');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 47, ''forbedring'', ''Sondepunkt owner_AA1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 48, ''forbedring'', ''Sondepunkt owner_AA2'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_A INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 49, ''forbedring'', ''Sondepunkt owner_AA3'')');
select pg_temp.skriv_avvist('fokuspunkter owner_A INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 50, ''forbedring'', ''Sondepunkt owner_AB1'')');
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
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f3-0000-4000-8000-0000384b12f3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 51, 'forbedring', 'Sondepunkt gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A2', 'delete from public.fokuspunkter where id = ''384b12f4-0000-4000-8000-0000384b12f4''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f4-0000-4000-8000-0000384b12f4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 52, 'forbedring', 'Sondepunkt gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('fokuspunkter owner_A DELETE A3', 'delete from public.fokuspunkter where id = ''384b12f5-0000-4000-8000-0000384b12f5''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b12f5-0000-4000-8000-0000384b12f5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 53, 'forbedring', 'Sondepunkt gjenowner_AA3');
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
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 54, ''forbedring'', ''Sondepunkt manager_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 55, ''forbedring'', ''Sondepunkt manager_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 56, ''forbedring'', ''Sondepunkt manager_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 57, ''forbedring'', ''Sondepunkt manager_A1B1'')');
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
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 58, ''forbedring'', ''Sondepunkt manager_A12A1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 59, ''forbedring'', ''Sondepunkt manager_A12A2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 60, ''forbedring'', ''Sondepunkt manager_A12A3'')');
select pg_temp.skriv_avvist('fokuspunkter manager_A12 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 61, ''forbedring'', ''Sondepunkt manager_A12B1'')');
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
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 62, ''forbedring'', ''Sondepunkt tablet_A1A1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 63, ''forbedring'', ''Sondepunkt tablet_A1A2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT A3', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 64, ''forbedring'', ''Sondepunkt tablet_A1A3'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_A1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 65, ''forbedring'', ''Sondepunkt tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 66, ''forbedring'', ''Sondepunkt owner_BB1'')');
select pg_temp.skriv_tillatt('fokuspunkter owner_B INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 67, ''forbedring'', ''Sondepunkt owner_BB2'')');
select pg_temp.skriv_avvist('fokuspunkter owner_B INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 68, ''forbedring'', ''Sondepunkt owner_BA1'')');
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
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1312-0000-4000-8000-0000384b1312', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 69, 'forbedring', 'Sondepunkt gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_fokuspunkter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('fokuspunkter owner_B DELETE B2', 'delete from public.fokuspunkter where id = ''384b1313-0000-4000-8000-0000384b1313''');
select pg_temp.som_eier();
insert into public.fokuspunkter (id, retailer_id, stasjon_id, periode, type, tekst) values ('384b1313-0000-4000-8000-0000384b1313', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 70, 'forbedring', 'Sondepunkt gjenowner_BB2');
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
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 71, ''forbedring'', ''Sondepunkt manager_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 72, ''forbedring'', ''Sondepunkt manager_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter manager_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 73, ''forbedring'', ''Sondepunkt manager_B1A1'')');
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
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 74, ''forbedring'', ''Sondepunkt tablet_B1B1'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT B2', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 75, ''forbedring'', ''Sondepunkt tablet_B1B2'')');
select pg_temp.skriv_avvist('fokuspunkter tablet_B1 INSERT A1', 'insert into public.fokuspunkter (retailer_id, stasjon_id, periode, type, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 76, ''forbedring'', ''Sondepunkt tablet_B1A1'')');
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
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e50a-0000-4000-8000-00001a99e50a'', date ''2026-01-01'' + 77, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a596a-0000-4000-8000-00001a9a596a'', date ''2026-01-01'' + 78, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acdca-0000-4000-8000-00001a9acdca'', date ''2026-01-01'' + 79, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fca3-0000-4000-8000-00001aa7fca3'', date ''2026-01-01'' + 80, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e523-0000-4000-8000-00001a99e523'', date ''2026-01-01'' + 81, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a5983-0000-4000-8000-00001a9a5983'', date ''2026-01-01'' + 82, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acde3-0000-4000-8000-00001a9acde3'', date ''2026-01-01'' + 83, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fca7-0000-4000-8000-00001aa7fca7'', date ''2026-01-01'' + 84, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e527-0000-4000-8000-00001a99e527'', date ''2026-01-01'' + 85, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a5987-0000-4000-8000-00001a9a5987'', date ''2026-01-01'' + 86, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9acde7-0000-4000-8000-00001a9acde7'', date ''2026-01-01'' + 87, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcab-0000-4000-8000-00001aa7fcab'', date ''2026-01-01'' + 88, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e52b-0000-4000-8000-00001a99e52b'', date ''2026-01-01'' + 89, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''1a9a59a0-0000-4000-8000-00001a9a59a0'', date ''2026-01-01'' + 90, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''1a9ace00-0000-4000-8000-00001a9ace00'', date ''2026-01-01'' + 91, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc4-0000-4000-8000-00001aa7fcc4'', date ''2026-01-01'' + 92, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc5-0000-4000-8000-00001aa7fcc5'', date ''2026-01-01'' + 93, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''1aa87125-0000-4000-8000-00001aa87125'', date ''2026-01-01'' + 94, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e546-0000-4000-8000-00001a99e546'', date ''2026-01-01'' + 95, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fcc8-0000-4000-8000-00001aa7fcc8'', date ''2026-01-01'' + 96, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''1aa87128-0000-4000-8000-00001aa87128'', date ''2026-01-01'' + 97, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''1a99e549-0000-4000-8000-00001a99e549'', date ''2026-01-01'' + 98, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''1aa7fccb-0000-4000-8000-00001aa7fccb'', date ''2026-01-01'' + 99, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659527-0000-4000-8000-00003a659527'', date ''2026-01-01'' + 100, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a508-0000-4000-8000-000038a2a508'', date ''2026-01-01'' + 101, 4.0, true)');

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
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf29-0000-4000-8000-0000484cdf29'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af6ab-0000-4000-8000-0000485af6ab'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_A INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690e2d-0000-4000-8000-000048690e2d'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber owner_A INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b7cb-0000-4000-8000-00004a01b7cb'', ''st1_salgsstatistikk'')');
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
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc00-0000-4000-8000-00000d10bc00', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '484cdf42-0000-4000-8000-0000484cdf42', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A DELETE A2', 'delete from public.import_jobber where id = ''0d10bc01-0000-4000-8000-00000d10bc01''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc01-0000-4000-8000-00000d10bc01', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '485af6c4-0000-4000-8000-0000485af6c4', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('import_jobber owner_A DELETE A3', 'delete from public.import_jobber where id = ''0d10bc02-0000-4000-8000-00000d10bc02''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc02-0000-4000-8000-00000d10bc02', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '48690e46-0000-4000-8000-000048690e46', 'st1_salgsstatistikk');
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
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf45-0000-4000-8000-0000484cdf45'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af6c7-0000-4000-8000-0000485af6c7'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690e49-0000-4000-8000-000048690e49'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b7e7-0000-4000-8000-00004a01b7e7'', ''st1_salgsstatistikk'')');
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
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf49-0000-4000-8000-0000484cdf49'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af6cb-0000-4000-8000-0000485af6cb'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690e4d-0000-4000-8000-000048690e4d'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_A12 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b800-0000-4000-8000-00004a01b800'', ''st1_salgsstatistikk'')');
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
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf62-0000-4000-8000-0000484cdf62'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''485af6e4-0000-4000-8000-0000485af6e4'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT A3', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''48690e66-0000-4000-8000-000048690e66'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_A1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b804-0000-4000-8000-00004a01b804'', ''st1_salgsstatistikk'')');
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
select pg_temp.skriv_tillatt('import_jobber owner_B INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b805-0000-4000-8000-00004a01b805'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_tillatt('import_jobber owner_B INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fcf87-0000-4000-8000-00004a0fcf87'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber owner_B INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf68-0000-4000-8000-0000484cdf68'', ''st1_salgsstatistikk'')');
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
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc1f-0000-4000-8000-00000d10bc1f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '4a01b808-0000-4000-8000-00004a01b808', 'st1_salgsstatistikk');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_import_jobber('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('import_jobber owner_B DELETE B2', 'delete from public.import_jobber where id = ''0d10bc20-0000-4000-8000-00000d10bc20''');
select pg_temp.som_eier();
insert into public.import_jobber (id, retailer_id, stasjon_id, raa_fil_id, rapporttype) values ('0d10bc20-0000-4000-8000-00000d10bc20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '4a0fcf8a-0000-4000-8000-00004a0fcf8a', 'st1_salgsstatistikk');
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
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b81f-0000-4000-8000-00004a01b81f'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fcfa1-0000-4000-8000-00004a0fcfa1'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber manager_B1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf82-0000-4000-8000-0000484cdf82'', ''st1_salgsstatistikk'')');
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
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT B1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4a01b822-0000-4000-8000-00004a01b822'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT B2', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4a0fcfa4-0000-4000-8000-00004a0fcfa4'', ''st1_salgsstatistikk'')');
select pg_temp.skriv_avvist('import_jobber tablet_B1 INSERT A1', 'insert into public.import_jobber (retailer_id, stasjon_id, raa_fil_id, rapporttype) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''484cdf85-0000-4000-8000-0000484cdf85'', ''st1_salgsstatistikk'')');
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
select pg_temp.skriv_avvist('kampanjer owner_A INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AA1'', date ''2026-01-01'' + 185, date ''2026-01-01'' + 185 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_A INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AB1'', date ''2026-01-01'' + 186, date ''2026-01-01'' + 186 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kampanjer manager_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1A1'', date ''2026-01-01'' + 187, date ''2026-01-01'' + 187 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1B1'', date ''2026-01-01'' + 188, date ''2026-01-01'' + 188 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kampanjer manager_A12 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12A1'', date ''2026-01-01'' + 189, date ''2026-01-01'' + 189 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12B1'', date ''2026-01-01'' + 190, date ''2026-01-01'' + 190 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kampanjer tablet_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1A1'', date ''2026-01-01'' + 191, date ''2026-01-01'' + 191 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1B1'', date ''2026-01-01'' + 192, date ''2026-01-01'' + 192 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kampanjer owner_B SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer owner_B SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BB1'', date ''2026-01-01'' + 193, date ''2026-01-01'' + 193 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BA1'', date ''2026-01-01'' + 194, date ''2026-01-01'' + 194 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kampanjer manager_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1B1'', date ''2026-01-01'' + 195, date ''2026-01-01'' + 195 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1A1'', date ''2026-01-01'' + 196, date ''2026-01-01'' + 196 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kampanjer tablet_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1B1'', date ''2026-01-01'' + 197, date ''2026-01-01'' + 197 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1A1'', date ''2026-01-01'' + 198, date ''2026-01-01'' + 198 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

-- =====================================================================
-- kassererstatistikk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kassererstatistikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kassererstatistikk owner_A SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A3 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastA3'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 199, ''owner_AA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 200, ''owner_AA2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 201, ''owner_AA3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_A INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 202, ''owner_AB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 32, 'fastA1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 33, 'fastA2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 34, 'fastA3', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A FLYTTER egen rad -> kjede B', 'update public.kassererstatistikk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 203, ''manager_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 204, ''manager_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 205, ''manager_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 206, ''manager_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 207, ''manager_A12A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 208, ''manager_A12A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 209, ''manager_A12A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 210, ''manager_A12B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 33 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 34 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 211, ''tablet_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 212, ''tablet_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 213, ''tablet_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 214, ''tablet_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 33 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 34 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kassererstatistikk owner_B SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT B2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36 and "kasserer_nr" = 'fastB2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 215, ''owner_BB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 216, ''owner_BB2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_B INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 217, ''owner_BA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 'fastB1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 'fastB2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B FLYTTER egen rad -> kjede A', 'update public.kassererstatistikk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 218, ''manager_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 219, ''manager_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 220, ''manager_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 35 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 36 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 32 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 221, ''tablet_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 222, ''tablet_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 223, ''tablet_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 35 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 36 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 32 and "kasserer_nr" = ''fastA1''');

-- =====================================================================
-- kategori_vaerprofil  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kategori_vaerprofil');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A3 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''owner_AA2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''owner_AA3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_AB1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_A1A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''manager_A1A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A1B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_A12A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''manager_A12A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A12B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''tablet_A1A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''tablet_A1A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_A1B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT B2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''owner_BB2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_BA1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_B1B2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_B1A1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''tablet_B1B2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_B1A1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

-- =====================================================================
-- konkurranser  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('konkurranser');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('konkurranser owner_A SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser owner_A SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_tillatt('konkurranser owner_A INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AA1'', ''omsetning sonde'', date ''2026-01-01'' + 249, date ''2026-01-01'' + 249 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_A INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AB1'', ''omsetning sonde'', date ''2026-01-01'' + 250, date ''2026-01-01'' + 250 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('konkurranser owner_A UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('konkurranser owner_A UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('konkurranser owner_A DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''');
select pg_temp.som_eier();
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515953-0000-4000-8000-00001c515953', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_AA1', 'omsetning sonde', date '2026-01-01' + 251, date '2026-01-01' + 251 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('konkurranser owner_A DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.skriv_avvist('konkurranser owner_A FLYTTER egen rad -> kjede B', 'update public.konkurranser set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('konkurranser manager_A1 SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 252, date ''2026-01-01'' + 252 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 253, date ''2026-01-01'' + 253 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('konkurranser manager_A1 UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('konkurranser manager_A1 UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('konkurranser manager_A1 DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('konkurranser manager_A1 DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('konkurranser manager_A12 SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12A1'', ''omsetning sonde'', date ''2026-01-01'' + 254, date ''2026-01-01'' + 254 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12B1'', ''omsetning sonde'', date ''2026-01-01'' + 255, date ''2026-01-01'' + 255 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('konkurranser manager_A12 UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('konkurranser manager_A12 UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('konkurranser manager_A12 DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('konkurranser manager_A12 DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('konkurranser tablet_A1 SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 256, date ''2026-01-01'' + 256 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 257, date ''2026-01-01'' + 257 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('konkurranser tablet_A1 UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('konkurranser tablet_A1 UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('konkurranser tablet_A1 DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('konkurranser tablet_A1 DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('konkurranser owner_B SELECT B -> ser', exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'positiv');
select pg_temp.paastand('konkurranser owner_B SELECT A -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'negativ');
select pg_temp.skriv_tillatt('konkurranser owner_B INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BB1'', ''omsetning sonde'', date ''2026-01-01'' + 258, date ''2026-01-01'' + 258 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_B INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BA1'', ''omsetning sonde'', date ''2026-01-01'' + 259, date ''2026-01-01'' + 259 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('konkurranser owner_B UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('konkurranser owner_B UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('konkurranser owner_B DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''');
select pg_temp.som_eier();
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515972-0000-4000-8000-00001c515972', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_BB1', 'omsetning sonde', date '2026-01-01' + 260, date '2026-01-01' + 260 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('konkurranser owner_B DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.skriv_avvist('konkurranser owner_B FLYTTER egen rad -> kjede A', 'update public.konkurranser set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('konkurranser manager_B1 SELECT B -> ser', exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'positiv');
select pg_temp.paastand('konkurranser manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 261, date ''2026-01-01'' + 261 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 262, date ''2026-01-01'' + 262 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('konkurranser manager_B1 UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('konkurranser manager_B1 UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('konkurranser manager_B1 DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('konkurranser manager_B1 DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('konkurranser tablet_B1 SELECT B -> ser', exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'positiv');
select pg_temp.paastand('konkurranser tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'negativ');
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 263, date ''2026-01-01'' + 263 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 264, date ''2026-01-01'' + 264 + 30)');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('konkurranser tablet_B1 UPDATE B', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('konkurranser tablet_B1 UPDATE A', 'update public.konkurranser set status = ''avsluttet'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('konkurranser tablet_B1 DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('konkurranser tablet_B1 DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 3/9: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 3/9: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
