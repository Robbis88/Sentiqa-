-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 8. Hele matrisen er for stor for Supabase SQL
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
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e23434-0000-4000-8000-000047e23434', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e2a894-0000-4000-8000-000047e2a894', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47e31cf4-0000-4000-8000-000047e31cf4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f04bb8-0000-4000-8000-000047f04bb8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('47f0c018-0000-4000-8000-000047f0c018', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b643f45-0000-4000-8000-00004b643f45', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be01646-0000-4000-8000-00002be01646', 'aaaa0000-0000-4000-8000-000000000000', '4b643f45-0000-4000-8000-00004b643f45', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b64b3a5-0000-4000-8000-00004b64b3a5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be08aa6-0000-4000-8000-00002be08aa6', 'aaaa0000-0000-4000-8000-000000000000', '4b64b3a5-0000-4000-8000-00004b64b3a5', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b652805-0000-4000-8000-00004b652805', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2be0ff06-0000-4000-8000-00002be0ff06', 'aaaa0000-0000-4000-8000-000000000000', '4b652805-0000-4000-8000-00004b652805', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b7256c9-0000-4000-8000-00004b7256c9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2bee2dca-0000-4000-8000-00002bee2dca', 'bbbb0000-0000-4000-8000-000000000000', '4b7256c9-0000-4000-8000-00004b7256c9', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('4b72cb29-0000-4000-8000-00004b72cb29', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('2beea22a-0000-4000-8000-00002beea22a', 'bbbb0000-0000-4000-8000-000000000000', '4b72cb29-0000-4000-8000-00004b72cb29', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644edf-0000-4000-8000-0000b4644edf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b619277f-0000-4000-8000-0000b619277f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644ee1-0000-4000-8000-0000b4644ee1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644ee2-0000-4000-8000-0000b4644ee2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b6192782-0000-4000-8000-0000b6192782', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644ef9-0000-4000-8000-0000b4644ef9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644efa-0000-4000-8000-0000b4644efa', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b619279a-0000-4000-8000-0000b619279a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644efc-0000-4000-8000-0000b4644efc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644efd-0000-4000-8000-0000b4644efd', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b619279d-0000-4000-8000-0000b619279d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b619279e-0000-4000-8000-0000b619279e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644f00-0000-4000-8000-0000b4644f00', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b61927a0-0000-4000-8000-0000b61927a0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b61927a1-0000-4000-8000-0000b61927a1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644f18-0000-4000-8000-0000b4644f18', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b61927b8-0000-4000-8000-0000b61927b8', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b61927b9-0000-4000-8000-0000b61927b9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('b4644f1b-0000-4000-8000-0000b4644f1b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2a7-0000-4000-8000-00002123a2a7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022abc6-0000-4000-8000-00005022abc6', 'aaaa0000-0000-4000-8000-000000000000', '2123a2a7-0000-4000-8000-00002123a2a7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131ba29-0000-4000-8000-00002131ba29', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c348-0000-4000-8000-00005030c348', 'aaaa0000-0000-4000-8000-000000000000', '2131ba29-0000-4000-8000-00002131ba29', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd1ab-0000-4000-8000-0000213fd1ab', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503edaca-0000-4000-8000-0000503edaca', 'aaaa0000-0000-4000-8000-000000000000', '213fd1ab-0000-4000-8000-0000213fd1ab', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b49-0000-4000-8000-000022d87b49', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78468-0000-4000-8000-000051d78468', 'bbbb0000-0000-4000-8000-000000000000', '22d87b49-0000-4000-8000-000022d87b49', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2ab-0000-4000-8000-00002123a2ab', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022abca-0000-4000-8000-00005022abca', 'aaaa0000-0000-4000-8000-000000000000', '2123a2ab-0000-4000-8000-00002123a2ab', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131ba2d-0000-4000-8000-00002131ba2d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c34c-0000-4000-8000-00005030c34c', 'aaaa0000-0000-4000-8000-000000000000', '2131ba2d-0000-4000-8000-00002131ba2d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd1af-0000-4000-8000-0000213fd1af', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503edace-0000-4000-8000-0000503edace', 'aaaa0000-0000-4000-8000-000000000000', '213fd1af-0000-4000-8000-0000213fd1af', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b62-0000-4000-8000-000022d87b62', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78481-0000-4000-8000-000051d78481', 'bbbb0000-0000-4000-8000-000000000000', '22d87b62-0000-4000-8000-000022d87b62', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2c4-0000-4000-8000-00002123a2c4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022abe3-0000-4000-8000-00005022abe3', 'aaaa0000-0000-4000-8000-000000000000', '2123a2c4-0000-4000-8000-00002123a2c4', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131ba46-0000-4000-8000-00002131ba46', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c365-0000-4000-8000-00005030c365', 'aaaa0000-0000-4000-8000-000000000000', '2131ba46-0000-4000-8000-00002131ba46', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd1c8-0000-4000-8000-0000213fd1c8', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503edae7-0000-4000-8000-0000503edae7', 'aaaa0000-0000-4000-8000-000000000000', '213fd1c8-0000-4000-8000-0000213fd1c8', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b66-0000-4000-8000-000022d87b66', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78485-0000-4000-8000-000051d78485', 'bbbb0000-0000-4000-8000-000000000000', '22d87b66-0000-4000-8000-000022d87b66', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2c8-0000-4000-8000-00002123a2c8', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022abe7-0000-4000-8000-00005022abe7', 'aaaa0000-0000-4000-8000-000000000000', '2123a2c8-0000-4000-8000-00002123a2c8', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131ba4a-0000-4000-8000-00002131ba4a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c369-0000-4000-8000-00005030c369', 'aaaa0000-0000-4000-8000-000000000000', '2131ba4a-0000-4000-8000-00002131ba4a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd1cc-0000-4000-8000-0000213fd1cc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503edaeb-0000-4000-8000-0000503edaeb', 'aaaa0000-0000-4000-8000-000000000000', '213fd1cc-0000-4000-8000-0000213fd1cc', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b6a-0000-4000-8000-000022d87b6a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78489-0000-4000-8000-000051d78489', 'bbbb0000-0000-4000-8000-000000000000', '22d87b6a-0000-4000-8000-000022d87b6a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b6b-0000-4000-8000-000022d87b6b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d7848a-0000-4000-8000-000051d7848a', 'bbbb0000-0000-4000-8000-000000000000', '22d87b6b-0000-4000-8000-000022d87b6b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69302-0000-4000-8000-000022e69302', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59c21-0000-4000-8000-000051e59c21', 'bbbb0000-0000-4000-8000-000000000000', '22e69302-0000-4000-8000-000022e69302', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2e3-0000-4000-8000-00002123a2e3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ac02-0000-4000-8000-00005022ac02', 'aaaa0000-0000-4000-8000-000000000000', '2123a2e3-0000-4000-8000-00002123a2e3', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b83-0000-4000-8000-000022d87b83', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d784a2-0000-4000-8000-000051d784a2', 'bbbb0000-0000-4000-8000-000000000000', '22d87b83-0000-4000-8000-000022d87b83', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69305-0000-4000-8000-000022e69305', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59c24-0000-4000-8000-000051e59c24', 'bbbb0000-0000-4000-8000-000000000000', '22e69305-0000-4000-8000-000022e69305', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2e6-0000-4000-8000-00002123a2e6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ac05-0000-4000-8000-00005022ac05', 'aaaa0000-0000-4000-8000-000000000000', '2123a2e6-0000-4000-8000-00002123a2e6', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87b86-0000-4000-8000-000022d87b86', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d784a5-0000-4000-8000-000051d784a5', 'bbbb0000-0000-4000-8000-000000000000', '22d87b86-0000-4000-8000-000022d87b86', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69308-0000-4000-8000-000022e69308', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59c27-0000-4000-8000-000051e59c27', 'bbbb0000-0000-4000-8000-000000000000', '22e69308-0000-4000-8000-000022e69308', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a2e9-0000-4000-8000-00002123a2e9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022ac08-0000-4000-8000-00005022ac08', 'aaaa0000-0000-4000-8000-000000000000', '2123a2e9-0000-4000-8000-00002123a2e9', date '2026-08-01', date '2026-08-31');
-- --- produksjonsplan_hode: forutsetninger og proberader ---
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4);

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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 5, 'Sondevare fastA1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 6, 'Sondevare fastA2');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 7, 'Sondevare fastA3');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 8, 'Sondevare fastB1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 9, 'Sondevare fastB2');

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
-- --- prognose_kalibrering: forutsetninger og proberader ---
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastA1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastA2', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', 'fastA3', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', 'fastB1', 1.05, 30);
insert into public.prognose_kalibrering (retailer_id, stasjon_id, type, kategori, korreksjon, n) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', 'fastB2', 1.05, 30);
-- --- prognose_treff: forutsetninger og proberader ---
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f208589-0000-4000-8000-00009f208589', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 15, 'fastA1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858a-0000-4000-8000-00009f20858a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 16, 'fastA2', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f20858b-0000-4000-8000-00009f20858b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'produksjonsplan', date '2026-01-01' + 17, 'fastA3', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a8-0000-4000-8000-00009f2085a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'produksjonsplan', date '2026-01-01' + 18, 'fastB1', 100, 95);
insert into public.prognose_treff (id, retailer_id, stasjon_id, type, dato, kategori, forventet, faktisk) values ('9f2085a9-0000-4000-8000-00009f2085a9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'produksjonsplan', date '2026-01-01' + 19, 'fastB2', 100, 95);
-- --- puls_runde: forutsetninger og proberader ---
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', '47e23434-0000-4000-8000-000047e23434', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60e-0000-4000-8000-00001f2bd60e', 'aaaa0000-0000-4000-8000-000000000000', '47e2a894-0000-4000-8000-000047e2a894', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60f-0000-4000-8000-00001f2bd60f', 'aaaa0000-0000-4000-8000-000000000000', '47e31cf4-0000-4000-8000-000047e31cf4', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', '47f04bb8-0000-4000-8000-000047f04bb8', date '2026-08-01', date '2026-08-31');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62d-0000-4000-8000-00001f2bd62d', 'bbbb0000-0000-4000-8000-000000000000', '47f0c018-0000-4000-8000-000047f0c018', date '2026-08-01', date '2026-08-31');

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
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575b-0000-4000-8000-00003922575b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '2be01646-0000-4000-8000-00002be01646', 3, 'Sondesvar fastA1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575c-0000-4000-8000-00003922575c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '2be08aa6-0000-4000-8000-00002be08aa6', 3, 'Sondesvar fastA2');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922575d-0000-4000-8000-00003922575d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '2be0ff06-0000-4000-8000-00002be0ff06', 3, 'Sondesvar fastA3');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577a-0000-4000-8000-00003922577a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '2bee2dca-0000-4000-8000-00002bee2dca', 3, 'Sondesvar fastB1');
insert into public.puls_svar (id, retailer_id, stasjon_id, runde_id, skala, kommentar) values ('3922577b-0000-4000-8000-00003922577b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '2beea22a-0000-4000-8000-00002beea22a', 3, 'Sondesvar fastB2');

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
-- --- regnskap_usynlig_svinn: forutsetninger og proberader ---
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9874-0000-4000-8000-0000ca4b9874', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje fastA1', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9875-0000-4000-8000-0000ca4b9875', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje fastA2', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9876-0000-4000-8000-0000ca4b9876', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', '20010', 'Sondelinje fastA3', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9893-0000-4000-8000-0000ca4b9893', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje fastB1', 100);
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9894-0000-4000-8000-0000ca4b9894', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje fastB2', 100);

create or replace function pg_temp.nyrad_regnskap_usynlig_svinn(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr)
  values (p_retailer, p_stasjon, date '2026-08-01', '20010', 'Sondelinje ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 100)
  returning id into ny;
  return ny;
end $fn$;
-- --- regnskapslinjer: forutsetninger og proberader ---
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('576eb793-0000-4000-8000-0000576eb793', 'aaaa0000-0000-4000-8000-000000000000', null, date '2026-08-01', 'omsetning', 'Sondepost nullA', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('576eb794-0000-4000-8000-0000576eb794', 'bbbb0000-0000-4000-8000-000000000000', null, date '2026-08-01', 'omsetning', 'Sondepost nullB', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost fastA1', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost fastA2', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'omsetning', 'Sondepost fastA3', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost fastB1', 1000);
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost fastB2', 1000);

create or replace function pg_temp.nyrad_regnskapslinjer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap)
  values (p_retailer, p_stasjon, date '2026-08-01', 'omsetning', 'Sondepost ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 1000)
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- produksjonsplan_hode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_hode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 47)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 48)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 49)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 50)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 51);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 52);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 53);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 54)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 55)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 56)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 57)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 58);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 59)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 60)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 61)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 62)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 63);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 64);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 65)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 66)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 67)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 68)');
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 69)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 70)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 71)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 72);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 73);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 74)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 75)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 76)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 77);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 78)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 79)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 80)');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 81, ''Sondevare owner_AA1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 82, ''Sondevare owner_AA2'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 83, ''Sondevare owner_AA3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 84, ''Sondevare owner_AB1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 85, 'Sondevare gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 86, 'Sondevare gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 87, 'Sondevare gjenowner_AA3');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 88, ''Sondevare manager_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 89, ''Sondevare manager_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 90, ''Sondevare manager_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 91, ''Sondevare manager_A1B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 92, 'Sondevare gjenmanager_A1A1');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 93, ''Sondevare manager_A12A1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 94, ''Sondevare manager_A12A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 95, ''Sondevare manager_A12A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 96, ''Sondevare manager_A12B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 97, 'Sondevare gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 98, 'Sondevare gjenmanager_A12A2');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 99, ''Sondevare tablet_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 100, ''Sondevare tablet_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 101, ''Sondevare tablet_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 102, ''Sondevare tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 103, ''Sondevare owner_BB1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 104, ''Sondevare owner_BB2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 105, ''Sondevare owner_BA1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 106, 'Sondevare gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 107, 'Sondevare gjenowner_BB2');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 108, ''Sondevare manager_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 109, ''Sondevare manager_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 110, ''Sondevare manager_B1A1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 111, 'Sondevare gjenmanager_B1B1');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 112, ''Sondevare tablet_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 113, ''Sondevare tablet_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 114, ''Sondevare tablet_B1A1'')');
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
select pg_temp.skriv_tillatt('puls_runde owner_A INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644edf-0000-4000-8000-0000b4644edf'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_A INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b619277f-0000-4000-8000-0000b619277f'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4644ee1-0000-4000-8000-0000b4644ee1', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('puls_runde owner_A DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde owner_A FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('puls_runde manager_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644ee2-0000-4000-8000-0000b4644ee2'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b6192782-0000-4000-8000-0000b6192782'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4644ef9-0000-4000-8000-0000b4644ef9', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('puls_runde manager_A1 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A1 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('puls_runde manager_A12 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_A12 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644efa-0000-4000-8000-0000b4644efa'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_A12 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b619279a-0000-4000-8000-0000b619279a'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd60d-0000-4000-8000-00001f2bd60d', 'aaaa0000-0000-4000-8000-000000000000', 'b4644efc-0000-4000-8000-0000b4644efc', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('puls_runde manager_A12 DELETE B', 'delete from public.puls_runde where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');
select pg_temp.skriv_avvist('puls_runde manager_A12 FLYTTER egen rad -> kjede B', 'update public.puls_runde set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('puls_runde tablet_A1 SELECT A -> ser', exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'positiv');
select pg_temp.paastand('puls_runde tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644efd-0000-4000-8000-0000b4644efd'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_A1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b619279d-0000-4000-8000-0000b619279d'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_tillatt('puls_runde owner_B INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b619279e-0000-4000-8000-0000b619279e'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde owner_B INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644f00-0000-4000-8000-0000b4644f00'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b61927a0-0000-4000-8000-0000b61927a0', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('puls_runde owner_B DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde owner_B FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('puls_runde manager_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_tillatt('puls_runde manager_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b61927a1-0000-4000-8000-0000b61927a1'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde manager_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644f18-0000-4000-8000-0000b4644f18'', date ''2026-08-01'', date ''2026-08-31'')');
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
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('1f2bd62c-0000-4000-8000-00001f2bd62c', 'bbbb0000-0000-4000-8000-000000000000', 'b61927b8-0000-4000-8000-0000b61927b8', date '2026-08-01', date '2026-08-31');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_puls_runde('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('puls_runde manager_B1 DELETE A', 'delete from public.puls_runde where id = ''1f2bd60d-0000-4000-8000-00001f2bd60d''', 'puls_runde', '1f2bd60d-0000-4000-8000-00001f2bd60d', 'id');
select pg_temp.skriv_avvist('puls_runde manager_B1 FLYTTER egen rad -> kjede A', 'update public.puls_runde set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1f2bd62c-0000-4000-8000-00001f2bd62c''', 'puls_runde', '1f2bd62c-0000-4000-8000-00001f2bd62c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('puls_runde tablet_B1 SELECT B -> ser', exists (select 1 from public.puls_runde where id = '1f2bd62c-0000-4000-8000-00001f2bd62c'), 'positiv');
select pg_temp.paastand('puls_runde tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.puls_runde where id = '1f2bd60d-0000-4000-8000-00001f2bd60d'), 'negativ');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT B', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b61927b9-0000-4000-8000-0000b61927b9'', date ''2026-08-01'', date ''2026-08-31'')');
select pg_temp.skriv_avvist('puls_runde tablet_B1 INSERT A', 'insert into public.puls_runde (retailer_id, sporsmal_id, start_dato, slutt_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''b4644f1b-0000-4000-8000-0000b4644f1b'', date ''2026-08-01'', date ''2026-08-31'')');
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
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022abc6-0000-4000-8000-00005022abc6'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c348-0000-4000-8000-00005030c348'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503edaca-0000-4000-8000-0000503edaca'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78468-0000-4000-8000-000051d78468'', 3, ''Sondesvar owner_AB1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022abca-0000-4000-8000-00005022abca'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c34c-0000-4000-8000-00005030c34c'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503edace-0000-4000-8000-0000503edace'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78481-0000-4000-8000-000051d78481'', 3, ''Sondesvar manager_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022abe3-0000-4000-8000-00005022abe3'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c365-0000-4000-8000-00005030c365'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503edae7-0000-4000-8000-0000503edae7'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78485-0000-4000-8000-000051d78485'', 3, ''Sondesvar manager_A12B1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022abe7-0000-4000-8000-00005022abe7'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c369-0000-4000-8000-00005030c369'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503edaeb-0000-4000-8000-0000503edaeb'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78489-0000-4000-8000-000051d78489'', 3, ''Sondesvar tablet_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d7848a-0000-4000-8000-000051d7848a'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59c21-0000-4000-8000-000051e59c21'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ac02-0000-4000-8000-00005022ac02'', 3, ''Sondesvar owner_BA1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d784a2-0000-4000-8000-000051d784a2'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59c24-0000-4000-8000-000051e59c24'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ac05-0000-4000-8000-00005022ac05'', 3, ''Sondesvar manager_B1A1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d784a5-0000-4000-8000-000051d784a5'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59c27-0000-4000-8000-000051e59c27'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022ac08-0000-4000-8000-00005022ac08'', 3, ''Sondesvar tablet_B1A1'')');
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

-- =====================================================================
-- regnskap_usynlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('regnskap_usynlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA1'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA2'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AA3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_AB1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9874-0000-4000-8000-0000ca4b9874', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA1', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9875-0000-4000-8000-0000ca4b9875', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA2', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_A DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9876-0000-4000-8000-0000ca4b9876', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', '20010', 'Sondelinje gjenowner_AA3', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_A FLYTTER egen rad -> kjede B', 'update public.regnskap_usynlig_svinn set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A1B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_A12B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_A12 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9875-0000-4000-8000-0000ca4b9875'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9876-0000-4000-8000-0000ca4b9876'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT A3', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1A3'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_A1B1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE A3', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9875-0000-4000-8000-0000ca4b9875''', 'regnskap_usynlig_svinn', 'ca4b9875-0000-4000-8000-0000ca4b9875', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE A3', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9876-0000-4000-8000-0000ca4b9876''', 'regnskap_usynlig_svinn', 'ca4b9876-0000-4000-8000-0000ca4b9876', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_A1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT B1 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT B2 -> ser', exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'positiv');
select pg_temp.paastand('regnskap_usynlig_svinn owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BB1'', 100)');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BB2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje owner_BA1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9893-0000-4000-8000-0000ca4b9893', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', '20010', 'Sondelinje gjenowner_BB1', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskap_usynlig_svinn owner_B DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''');
select pg_temp.som_eier();
insert into public.regnskap_usynlig_svinn (id, retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values ('ca4b9894-0000-4000-8000-0000ca4b9894', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', '20010', 'Sondelinje gjenowner_BB2', 100);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn owner_B FLYTTER egen rad -> kjede A', 'update public.regnskap_usynlig_svinn set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1B1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1B2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje manager_B1A1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn manager_B1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9893-0000-4000-8000-0000ca4b9893'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9894-0000-4000-8000-0000ca4b9894'), 'negativ');
select pg_temp.paastand('regnskap_usynlig_svinn tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskap_usynlig_svinn where id = 'ca4b9874-0000-4000-8000-0000ca4b9874'), 'negativ');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT B1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1B1'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT B2', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1B2'', 100)');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 INSERT A1', 'insert into public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''20010'', ''Sondelinje tablet_B1A1'', 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE B1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE B2', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 UPDATE A1', 'update public.regnskap_usynlig_svinn set navn = ''endret av sonden'' where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE B1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9893-0000-4000-8000-0000ca4b9893''', 'regnskap_usynlig_svinn', 'ca4b9893-0000-4000-8000-0000ca4b9893', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE B2', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9894-0000-4000-8000-0000ca4b9894''', 'regnskap_usynlig_svinn', 'ca4b9894-0000-4000-8000-0000ca4b9894', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskap_usynlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskap_usynlig_svinn tablet_B1 DELETE A1', 'delete from public.regnskap_usynlig_svinn where id = ''ca4b9874-0000-4000-8000-0000ca4b9874''', 'regnskap_usynlig_svinn', 'ca4b9874-0000-4000-8000-0000ca4b9874', 'id');

-- =====================================================================
-- regnskapslinjer  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('regnskapslinjer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('regnskapslinjer owner_A SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT A2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT A3 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA1'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA2'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AA3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer owner_A INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_AB1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapslinjer owner_A UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA1', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA2', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_A DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_AA3', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('regnskapslinjer owner_A DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A1B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('regnskapslinjer manager_A1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_A12B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('regnskapslinjer manager_A12 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'positiv');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT A3', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1A3'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_A1B1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE A3', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A2', 'delete from public.regnskapslinjer where id = ''a2c8fe0d-0000-4000-8000-0000a2c8fe0d''', 'regnskapslinjer', 'a2c8fe0d-0000-4000-8000-0000a2c8fe0d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE A3', 'delete from public.regnskapslinjer where id = ''a2c8fe0e-0000-4000-8000-0000a2c8fe0e''', 'regnskapslinjer', 'a2c8fe0e-0000-4000-8000-0000a2c8fe0e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_A1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.paastand('regnskapslinjer tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('regnskapslinjer owner_B SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B SELECT B2 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BB1'', 1000)');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BB2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer owner_B INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost owner_BA1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapslinjer owner_B UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_BB1', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('regnskapslinjer owner_B DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''');
select pg_temp.som_eier();
insert into public.regnskapslinjer (id, retailer_id, stasjon_id, periode, seksjon, post, regnskap) values ('a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'omsetning', 'Sondepost gjenowner_BB2', 1000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('regnskapslinjer owner_B DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'positiv');
select pg_temp.paastand('regnskapslinjer owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1B1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1B2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost manager_B1A1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('regnskapslinjer manager_B1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');
select pg_temp.paastand('regnskapslinjer manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b'), 'positiv');
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.regnskapslinjer where id = 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c'), 'negativ');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT B1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1B1'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT B2', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1B2'', 1000)');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 INSERT A1', 'insert into public.regnskapslinjer (retailer_id, stasjon_id, periode, seksjon, post, regnskap) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''omsetning'', ''Sondepost tablet_B1A1'', 1000)');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE B1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE B2', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 UPDATE A1', 'update public.regnskapslinjer set post = ''endret av sonden'' where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE B1', 'delete from public.regnskapslinjer where id = ''a2c8fe2b-0000-4000-8000-0000a2c8fe2b''', 'regnskapslinjer', 'a2c8fe2b-0000-4000-8000-0000a2c8fe2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE B2', 'delete from public.regnskapslinjer where id = ''a2c8fe2c-0000-4000-8000-0000a2c8fe2c''', 'regnskapslinjer', 'a2c8fe2c-0000-4000-8000-0000a2c8fe2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_regnskapslinjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('regnskapslinjer tablet_B1 DELETE A1', 'delete from public.regnskapslinjer where id = ''a2c8fe0c-0000-4000-8000-0000a2c8fe0c''', 'regnskapslinjer', 'a2c8fe0c-0000-4000-8000-0000a2c8fe0c', 'id');
select pg_temp.paastand('regnskapslinjer tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.regnskapslinjer where id = '576eb794-0000-4000-8000-0000576eb794'), 'negativ');
select pg_temp.paastand('regnskapslinjer tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.regnskapslinjer where id = '576eb793-0000-4000-8000-0000576eb793'), 'negativ');

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
