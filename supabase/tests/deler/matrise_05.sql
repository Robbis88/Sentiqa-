-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 9. Hele matrisen er for stor for Supabase SQL
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a140d0a-0000-4000-8000-00009a140d0a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a1410cc-0000-4000-8000-00009a1410cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14148e-0000-4000-8000-00009a14148e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14816c-0000-4000-8000-00009a14816c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('9a14852e-0000-4000-8000-00009a14852e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0185c5-0000-4000-8000-00009e0185c5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a351-0000-4000-8000-00001827a351', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fa25-0000-4000-8000-00009e01fa25', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('182817b1-0000-4000-8000-0000182817b1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026e85-0000-4000-8000-00009e026e85', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288c11-0000-4000-8000-000018288c11', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9d49-0000-4000-8000-00009e0f9d49', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bad5-0000-4000-8000-00001835bad5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e1011a9-0000-4000-8000-00009e1011a9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18362f35-0000-4000-8000-000018362f35', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d266f-0000-4000-8000-0000227d266f', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 32');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2670-0000-4000-8000-0000227d2670', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 33');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2671-0000-4000-8000-0000227d2671', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 34');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('227d2672-0000-4000-8000-0000227d2672', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 35');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3df4-0000-4000-8000-0000228b3df4', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 36');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3df5-0000-4000-8000-0000228b3df5', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 37');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('228b3df6-0000-4000-8000-0000228b3df6', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 38');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94c8-0000-4000-8000-0000a86d94c8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0928-0000-4000-8000-0000a86e0928', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7d88-0000-4000-8000-0000a86e7d88', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac4c-0000-4000-8000-0000a87bac4c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94cc-0000-4000-8000-0000a86d94cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0941-0000-4000-8000-0000a86e0941', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7da1-0000-4000-8000-0000a86e7da1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94e4-0000-4000-8000-0000a86d94e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0944-0000-4000-8000-0000a86e0944', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7da4-0000-4000-8000-0000a86e7da4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bac68-0000-4000-8000-0000a87bac68', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94e8-0000-4000-8000-0000a86d94e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d94e9-0000-4000-8000-0000a86d94e9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e0949-0000-4000-8000-0000a86e0949', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7da9-0000-4000-8000-0000a86e7da9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c225-0000-4000-8000-000066f9c225', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544e987-0000-4000-8000-00006544e987', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530109-0000-4000-8000-000065530109', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544e989-0000-4000-8000-00006544e989', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553010b-0000-4000-8000-00006553010b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6561188d-0000-4000-8000-00006561188d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c22b-0000-4000-8000-000066f9c22b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c22c-0000-4000-8000-000066f9c22c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707d9ae-0000-4000-8000-00006707d9ae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544e98f-0000-4000-8000-00006544e98f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c244-0000-4000-8000-000066f9c244', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707d9c6-0000-4000-8000-00006707d9c6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c246-0000-4000-8000-000066f9c246', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707d9c8-0000-4000-8000-00006707d9c8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544e9a9-0000-4000-8000-00006544e9a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c249-0000-4000-8000-000066f9c249', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c24a-0000-4000-8000-000066f9c24a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707d9cc-0000-4000-8000-00006707d9cc', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544e9ad-0000-4000-8000-00006544e9ad', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3333-0000-4000-8000-0000222f3333', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc727-0000-4000-8000-0000ecccc727', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4aca-0000-4000-8000-0000223d4aca', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadebe-0000-4000-8000-0000ecdadebe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b624c-0000-4000-8000-0000224b624c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f640-0000-4000-8000-0000ece8f640', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bea-0000-4000-8000-000023e40bea', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fde-0000-4000-8000-0000ee819fde', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f334c-0000-4000-8000-0000222f334c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc740-0000-4000-8000-0000ecccc740', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4ace-0000-4000-8000-0000223d4ace', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadec2-0000-4000-8000-0000ecdadec2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6250-0000-4000-8000-0000224b6250', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f644-0000-4000-8000-0000ece8f644', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f334f-0000-4000-8000-0000222f334f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc743-0000-4000-8000-0000ecccc743', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4ad1-0000-4000-8000-0000223d4ad1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadec5-0000-4000-8000-0000ecdadec5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6253-0000-4000-8000-0000224b6253', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f647-0000-4000-8000-0000ece8f647', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40bf1-0000-4000-8000-000023e40bf1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fe5-0000-4000-8000-0000ee819fe5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3368-0000-4000-8000-0000222f3368', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc75c-0000-4000-8000-0000ecccc75c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3369-0000-4000-8000-0000222f3369', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc75d-0000-4000-8000-0000ecccc75d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4aeb-0000-4000-8000-0000223d4aeb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadedf-0000-4000-8000-0000ecdadedf', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b626d-0000-4000-8000-0000224b626d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f661-0000-4000-8000-0000ece8f661', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c0b-0000-4000-8000-000023e40c0b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee819fff-0000-4000-8000-0000ee819fff', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f336d-0000-4000-8000-0000222f336d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc761-0000-4000-8000-0000ecccc761', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4aef-0000-4000-8000-0000223d4aef', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadee3-0000-4000-8000-0000ecdadee3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f336f-0000-4000-8000-0000222f336f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc763-0000-4000-8000-0000ecccc763', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4af1-0000-4000-8000-0000223d4af1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadee5-0000-4000-8000-0000ecdadee5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6273-0000-4000-8000-0000224b6273', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f667-0000-4000-8000-0000ece8f667', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c26-0000-4000-8000-000023e40c26', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a01a-0000-4000-8000-0000ee81a01a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c27-0000-4000-8000-000023e40c27', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a01b-0000-4000-8000-0000ee81a01b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f223a9-0000-4000-8000-000023f223a9', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb79d-0000-4000-8000-0000ee8fb79d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f338a-0000-4000-8000-0000222f338a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc77e-0000-4000-8000-0000ecccc77e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c2a-0000-4000-8000-000023e40c2a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a01e-0000-4000-8000-0000ee81a01e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f223ac-0000-4000-8000-000023f223ac', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb7a0-0000-4000-8000-0000ee8fb7a0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c2c-0000-4000-8000-000023e40c2c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a020-0000-4000-8000-0000ee81a020', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f223ae-0000-4000-8000-000023f223ae', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb7a2-0000-4000-8000-0000ee8fb7a2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f338f-0000-4000-8000-0000222f338f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc783-0000-4000-8000-0000ecccc783', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c2f-0000-4000-8000-000023e40c2f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a023-0000-4000-8000-0000ee81a023', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40c45-0000-4000-8000-000023e40c45', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a039-0000-4000-8000-0000ee81a039', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f223c7-0000-4000-8000-000023f223c7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fb7bb-0000-4000-8000-0000ee8fb7bb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f33a8-0000-4000-8000-0000222f33a8', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc79c-0000-4000-8000-0000ecccc79c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a440-0000-4000-8000-00002d27a440', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 253');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a441-0000-4000-8000-00002d27a441', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 254');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a442-0000-4000-8000-00002d27a442', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 255');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a443-0000-4000-8000-00002d27a443', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 256');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a444-0000-4000-8000-00002d27a444', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 257');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a445-0000-4000-8000-00002d27a445', '00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 258');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a446-0000-4000-8000-00002d27a446', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 259');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a45c-0000-4000-8000-00002d27a45c', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 260');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a45d-0000-4000-8000-00002d27a45d', '00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 261');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a45e-0000-4000-8000-00002d27a45e', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 262');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a45f-0000-4000-8000-00002d27a45f', '00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 263');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2d27a460-0000-4000-8000-00002d27a460', '00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'Sondepunkt 264');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d00-0000-4000-8000-00002edc7d00', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 265');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d01-0000-4000-8000-00002edc7d01', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 266');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d02-0000-4000-8000-00002edc7d02', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 267');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d03-0000-4000-8000-00002edc7d03', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 268');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d04-0000-4000-8000-00002edc7d04', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 269');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d1a-0000-4000-8000-00002edc7d1a', '00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 270');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d1b-0000-4000-8000-00002edc7d1b', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 271');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d1c-0000-4000-8000-00002edc7d1c', '00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 272');
insert into public.personlig_punkt (id, user_id, retailer_id, tittel) values ('2edc7d1d-0000-4000-8000-00002edc7d1d', '00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'Sondepunkt 273');
-- --- opplaering_periode: forutsetninger og proberader ---
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen fastA1', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen fastA2', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2c-0000-4000-8000-0000d0771b2c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen fastA3', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen fastB1', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b4a-0000-4000-8000-0000d0771b4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen fastB2', date '2026-08-01');

create or replace function pg_temp.nyrad_opplaering_periode(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato)
  values (p_retailer, p_stasjon, 'Sonde Sondesen ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', date '2026-08-01')
  returning id into ny;
  return ny;
end $fn$;
-- --- opplaering_skift: forutsetninger og proberader ---
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '9a140d0a-0000-4000-8000-00009a140d0a', date '2026-01-01' + 5);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '9a1410cc-0000-4000-8000-00009a1410cc', date '2026-01-01' + 6);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '9a14148e-0000-4000-8000-00009a14148e', date '2026-01-01' + 7);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '9a14816c-0000-4000-8000-00009a14816c', date '2026-01-01' + 8);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '9a14852e-0000-4000-8000-00009a14852e', date '2026-01-01' + 9);

create or replace function pg_temp.nyrad_opplaering_skift(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_periode uuid := gen_random_uuid();
begin
  insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values (v_periode, p_retailer, p_stasjon, 'Sonde Sondesen', date '2026-08-01');
  insert into public.opplaering_skift (periode_id, dato)
  values (v_periode, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- opplaering_utfort: forutsetninger og proberader ---
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a351-0000-4000-8000-00001827a351', '9e0185c5-0000-4000-8000-00009e0185c5');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', '182817b1-0000-4000-8000-0000182817b1', '9e01fa25-0000-4000-8000-00009e01fa25');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', '18288c11-0000-4000-8000-000018288c11', '9e026e85-0000-4000-8000-00009e026e85');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', '1835bad5-0000-4000-8000-00001835bad5', '9e0f9d49-0000-4000-8000-00009e0f9d49');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', '18362f35-0000-4000-8000-000018362f35', '9e1011a9-0000-4000-8000-00009e1011a9');

create or replace function pg_temp.nyrad_opplaering_utfort(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_oppgave uuid := gen_random_uuid();
  v_periode uuid := gen_random_uuid();
begin
  insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values (v_oppgave, p_retailer, 'Sondeoppgave', 'Kasse');
  insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values (v_periode, p_retailer, p_stasjon, 'Sonde Sondesen', current_date);
  insert into public.opplaering_utfort (periode_id, oppgave_id)
  values (v_periode, v_oppgave)
  returning id into ny;
  return ny;
end $fn$;
-- --- pengepremie: forutsetninger og proberader ---
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie fastA1', 100, date '2026-01-01' + 15);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie fastA2', 100, date '2026-01-01' + 16);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie fastA3', 100, date '2026-01-01' + 17);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie fastB1', 100, date '2026-01-01' + 18);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie fastB2', 100, date '2026-01-01' + 19);

create or replace function pg_temp.nyrad_pengepremie(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato)
  values (p_retailer, p_stasjon, 'Sondepremie ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 100, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
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
-- --- persondata_logg: forutsetninger og proberader ---
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('33f7439e-0000-4000-8000-000033f7439e', 'aaaa0000-0000-4000-8000-000000000000', null, 'sonde_oppslag', 'nullA', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('33f7439f-0000-4000-8000-000033f7439f', 'bbbb0000-0000-4000-8000-000000000000', null, 'sonde_oppslag', 'nullB', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d7-0000-4000-8000-0000a78b10d7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastA1', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d8-0000-4000-8000-0000a78b10d8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastA2', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10d9-0000-4000-8000-0000a78b10d9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'sonde_oppslag', 'fastA3', '00000000-0000-0000-0000-00000000a000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f6-0000-4000-8000-0000a78b10f6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'sonde_oppslag', 'fastB1', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
insert into public.persondata_logg (id, retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values ('a78b10f7-0000-4000-8000-0000a78b10f7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'sonde_oppslag', 'fastB2', '00000000-0000-0000-0000-00000000b000', 'Sonde Sondesen');
-- --- personlig_kryss: forutsetninger og proberader ---
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '227d266f-0000-4000-8000-0000227d266f', date '2026-01-01' + 32);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '227d2670-0000-4000-8000-0000227d2670', date '2026-01-01' + 33);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '227d2671-0000-4000-8000-0000227d2671', date '2026-01-01' + 34);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '227d2672-0000-4000-8000-0000227d2672', date '2026-01-01' + 35);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '228b3df4-0000-4000-8000-0000228b3df4', date '2026-01-01' + 36);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '228b3df5-0000-4000-8000-0000228b3df5', date '2026-01-01' + 37);
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '228b3df6-0000-4000-8000-0000228b3df6', date '2026-01-01' + 38);
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

-- =====================================================================
-- opplaering_periode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_periode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_periode owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_AA1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen owner_AA2'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_A INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen owner_AA3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode owner_A INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_AB1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_periode owner_A UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenowner_AA1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenowner_AA2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_periode owner_A DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2c-0000-4000-8000-0000d0771b2c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen gjenowner_AA3', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_periode owner_A DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode owner_A FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A1A1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_A1A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen manager_A1A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A1B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_periode manager_A1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_A1A1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 FLYTTER egen rad A1 -> A2', 'update public.opplaering_periode set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A1 FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A12A1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_A12A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen manager_A12A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_A12B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2a-0000-4000-8000-0000d0771b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_A12A1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_periode manager_A12 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b2b-0000-4000-8000-0000d0771b2b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenmanager_A12A2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 FLYTTER egen rad A1 -> A3', 'update public.opplaering_periode set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_A12 FLYTTER egen rad -> kjede B', 'update public.opplaering_periode set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'positiv');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2b-0000-4000-8000-0000d0771b2b'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2c-0000-4000-8000-0000d0771b2c'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'negativ');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_A1A1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen tablet_A1A2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT A3', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen tablet_A1A3'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_A1B1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE A3', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A2', 'delete from public.opplaering_periode where id = ''d0771b2b-0000-4000-8000-0000d0771b2b''', 'opplaering_periode', 'd0771b2b-0000-4000-8000-0000d0771b2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE A3', 'delete from public.opplaering_periode where id = ''d0771b2c-0000-4000-8000-0000d0771b2c''', 'opplaering_periode', 'd0771b2c-0000-4000-8000-0000d0771b2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_periode tablet_A1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_periode owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'positiv');
select pg_temp.paastand('opplaering_periode owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode owner_B INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_BB1'', date ''2026-08-01'')');
select pg_temp.skriv_tillatt('opplaering_periode owner_B INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen owner_BB2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode owner_B INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen owner_BA1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_periode owner_B UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenowner_BB1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_periode owner_B DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b4a-0000-4000-8000-0000d0771b4a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen gjenowner_BB2', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_periode owner_B DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode owner_B FLYTTER egen rad -> kjede A', 'update public.opplaering_periode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_periode manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'negativ');
select pg_temp.paastand('opplaering_periode manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_B1B1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen manager_B1B2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen manager_B1A1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_periode manager_B1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''');
select pg_temp.som_eier();
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('d0771b49-0000-4000-8000-0000d0771b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen gjenmanager_B1B1', date '2026-08-01');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 FLYTTER egen rad B1 -> B2', 'update public.opplaering_periode set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.skriv_avvist('opplaering_periode manager_B1 FLYTTER egen rad -> kjede A', 'update public.opplaering_periode set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_periode where id = 'd0771b49-0000-4000-8000-0000d0771b49'), 'positiv');
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b4a-0000-4000-8000-0000d0771b4a'), 'negativ');
select pg_temp.paastand('opplaering_periode tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_periode where id = 'd0771b2a-0000-4000-8000-0000d0771b2a'), 'negativ');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT B1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_B1B1'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT B2', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen tablet_B1B2'', date ''2026-08-01'')');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 INSERT A1', 'insert into public.opplaering_periode (retailer_id, stasjon_id, ansatt_navn, start_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen tablet_B1A1'', date ''2026-08-01'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE B1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE B2', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 UPDATE A1', 'update public.opplaering_periode set notater = ''endret av sonden'' where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE B1', 'delete from public.opplaering_periode where id = ''d0771b49-0000-4000-8000-0000d0771b49''', 'opplaering_periode', 'd0771b49-0000-4000-8000-0000d0771b49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE B2', 'delete from public.opplaering_periode where id = ''d0771b4a-0000-4000-8000-0000d0771b4a''', 'opplaering_periode', 'd0771b4a-0000-4000-8000-0000d0771b4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_periode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_periode tablet_B1 DELETE A1', 'delete from public.opplaering_periode where id = ''d0771b2a-0000-4000-8000-0000d0771b2a''', 'opplaering_periode', 'd0771b2a-0000-4000-8000-0000d0771b2a', 'id');

-- =====================================================================
-- opplaering_skift  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_skift');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_skift owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94c8-0000-4000-8000-0000a86d94c8'', date ''2026-01-01'' + 85)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e0928-0000-4000-8000-0000a86e0928'', date ''2026-01-01'' + 86)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7d88-0000-4000-8000-0000a86e7d88'', date ''2026-01-01'' + 87)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac4c-0000-4000-8000-0000a87bac4c'', date ''2026-01-01'' + 88)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_skift owner_A UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d94cc-0000-4000-8000-0000a86d94cc', date '2026-01-01' + 89);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e0941-0000-4000-8000-0000a86e0941', date '2026-01-01' + 90);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7da1-0000-4000-8000-0000a86e7da1', date '2026-01-01' + 91);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_skift owner_A DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94e4-0000-4000-8000-0000a86d94e4'', date ''2026-01-01'' + 92)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e0944-0000-4000-8000-0000a86e0944'', date ''2026-01-01'' + 93)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7da4-0000-4000-8000-0000a86e7da4'', date ''2026-01-01'' + 94)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''a87bac68-0000-4000-8000-0000a87bac68'', date ''2026-01-01'' + 95)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d94e8-0000-4000-8000-0000a86d94e8', date '2026-01-01' + 96);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''a86d94e9-0000-4000-8000-0000a86d94e9'', date ''2026-01-01'' + 97)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e0949-0000-4000-8000-0000a86e0949'', date ''2026-01-01'' + 98)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''a86e7da9-0000-4000-8000-0000a86e7da9'', date ''2026-01-01'' + 99)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c225-0000-4000-8000-000066f9c225'', date ''2026-01-01'' + 100)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544e987-0000-4000-8000-00006544e987', date '2026-01-01' + 101);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '65530109-0000-4000-8000-000065530109', date '2026-01-01' + 102);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544e989-0000-4000-8000-00006544e989'', date ''2026-01-01'' + 103)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''6553010b-0000-4000-8000-00006553010b'', date ''2026-01-01'' + 104)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''6561188d-0000-4000-8000-00006561188d'', date ''2026-01-01'' + 105)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c22b-0000-4000-8000-000066f9c22b'', date ''2026-01-01'' + 106)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE A3', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''', 'opplaering_skift', '8cd86b86-0000-4000-8000-00008cd86b86', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''', 'opplaering_skift', '8cd86b87-0000-4000-8000-00008cd86b87', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_skift owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c22c-0000-4000-8000-000066f9c22c'', date ''2026-01-01'' + 107)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707d9ae-0000-4000-8000-00006707d9ae'', date ''2026-01-01'' + 108)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544e98f-0000-4000-8000-00006544e98f'', date ''2026-01-01'' + 109)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c244-0000-4000-8000-000066f9c244', date '2026-01-01' + 110);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '6707d9c6-0000-4000-8000-00006707d9c6', date '2026-01-01' + 111);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c246-0000-4000-8000-000066f9c246'', date ''2026-01-01'' + 112)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707d9c8-0000-4000-8000-00006707d9c8'', date ''2026-01-01'' + 113)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544e9a9-0000-4000-8000-00006544e9a9'', date ''2026-01-01'' + 114)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c249-0000-4000-8000-000066f9c249', date '2026-01-01' + 115);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c24a-0000-4000-8000-000066f9c24a'', date ''2026-01-01'' + 116)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707d9cc-0000-4000-8000-00006707d9cc'', date ''2026-01-01'' + 117)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544e9ad-0000-4000-8000-00006544e9ad'', date ''2026-01-01'' + 118)');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE B1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE B2', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 UPDATE A1', 'update public.opplaering_skift set notater = ''endret av sonden'' where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE B1', 'delete from public.opplaering_skift where id = ''8cd86ba4-0000-4000-8000-00008cd86ba4''', 'opplaering_skift', '8cd86ba4-0000-4000-8000-00008cd86ba4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''', 'opplaering_skift', '8cd86ba5-0000-4000-8000-00008cd86ba5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

-- =====================================================================
-- opplaering_utfort  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_utfort');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_utfort owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc727-0000-4000-8000-0000ecccc727'', ''222f3333-0000-4000-8000-0000222f3333'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdadebe-0000-4000-8000-0000ecdadebe'', ''223d4aca-0000-4000-8000-0000223d4aca'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f640-0000-4000-8000-0000ece8f640'', ''224b624c-0000-4000-8000-0000224b624c'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_A INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fde-0000-4000-8000-0000ee819fde'', ''23e40bea-0000-4000-8000-000023e40bea'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_utfort owner_A UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccc740-0000-4000-8000-0000ecccc740', '222f334c-0000-4000-8000-0000222f334c');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdadec2-0000-4000-8000-0000ecdadec2', '223d4ace-0000-4000-8000-0000223d4ace');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', 'ece8f644-0000-4000-8000-0000ece8f644', '224b6250-0000-4000-8000-0000224b6250');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_utfort owner_A DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc743-0000-4000-8000-0000ecccc743'', ''222f334f-0000-4000-8000-0000222f334f'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdadec5-0000-4000-8000-0000ecdadec5'', ''223d4ad1-0000-4000-8000-0000223d4ad1'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f647-0000-4000-8000-0000ece8f647'', ''224b6253-0000-4000-8000-0000224b6253'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fe5-0000-4000-8000-0000ee819fe5'', ''23e40bf1-0000-4000-8000-000023e40bf1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccc75c-0000-4000-8000-0000ecccc75c', '222f3368-0000-4000-8000-0000222f3368');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc75d-0000-4000-8000-0000ecccc75d'', ''222f3369-0000-4000-8000-0000222f3369'')');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdadedf-0000-4000-8000-0000ecdadedf'', ''223d4aeb-0000-4000-8000-0000223d4aeb'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f661-0000-4000-8000-0000ece8f661'', ''224b626d-0000-4000-8000-0000224b626d'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee819fff-0000-4000-8000-0000ee819fff'', ''23e40c0b-0000-4000-8000-000023e40c0b'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccc761-0000-4000-8000-0000ecccc761', '222f336d-0000-4000-8000-0000222f336d');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdadee3-0000-4000-8000-0000ecdadee3', '223d4aef-0000-4000-8000-0000223d4aef');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc763-0000-4000-8000-0000ecccc763'', ''222f336f-0000-4000-8000-0000222f336f'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdadee5-0000-4000-8000-0000ecdadee5'', ''223d4af1-0000-4000-8000-0000223d4af1'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f667-0000-4000-8000-0000ece8f667'', ''224b6273-0000-4000-8000-0000224b6273'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a01a-0000-4000-8000-0000ee81a01a'', ''23e40c26-0000-4000-8000-000023e40c26'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE A2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE A3', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''', 'opplaering_utfort', '178fd42d-0000-4000-8000-0000178fd42d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''', 'opplaering_utfort', '178fd42e-0000-4000-8000-0000178fd42e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_utfort owner_B SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_B SELECT B2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a01b-0000-4000-8000-0000ee81a01b'', ''23e40c27-0000-4000-8000-000023e40c27'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb79d-0000-4000-8000-0000ee8fb79d'', ''23f223a9-0000-4000-8000-000023f223a9'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_B INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc77e-0000-4000-8000-0000ecccc77e'', ''222f338a-0000-4000-8000-0000222f338a'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81a01e-0000-4000-8000-0000ee81a01e', '23e40c2a-0000-4000-8000-000023e40c2a');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', 'ee8fb7a0-0000-4000-8000-0000ee8fb7a0', '23f223ac-0000-4000-8000-000023f223ac');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a020-0000-4000-8000-0000ee81a020'', ''23e40c2c-0000-4000-8000-000023e40c2c'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb7a2-0000-4000-8000-0000ee8fb7a2'', ''23f223ae-0000-4000-8000-000023f223ae'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc783-0000-4000-8000-0000ecccc783'', ''222f338f-0000-4000-8000-0000222f338f'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81a023-0000-4000-8000-0000ee81a023', '23e40c2f-0000-4000-8000-000023e40c2f');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a039-0000-4000-8000-0000ee81a039'', ''23e40c45-0000-4000-8000-000023e40c45'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fb7bb-0000-4000-8000-0000ee8fb7bb'', ''23f223c7-0000-4000-8000-000023f223c7'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc79c-0000-4000-8000-0000ecccc79c'', ''222f33a8-0000-4000-8000-0000222f33a8'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 UPDATE B1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44b-0000-4000-8000-0000178fd44b''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 UPDATE B2', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 UPDATE A1', 'update public.opplaering_utfort set notater = ''endret av sonden'' where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE B1', 'delete from public.opplaering_utfort where id = ''178fd44b-0000-4000-8000-0000178fd44b''', 'opplaering_utfort', '178fd44b-0000-4000-8000-0000178fd44b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''', 'opplaering_utfort', '178fd44c-0000-4000-8000-0000178fd44c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

-- =====================================================================
-- pengepremie  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('pengepremie');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('pengepremie owner_A SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT A2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT A3 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'positiv');
select pg_temp.paastand('pengepremie owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AA1'', 100, date ''2026-01-01'' + 153)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_AA2'', 100, date ''2026-01-01'' + 154)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie owner_AA3'', 100, date ''2026-01-01'' + 155)');
select pg_temp.skriv_avvist('pengepremie owner_A INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AB1'', 100, date ''2026-01-01'' + 156)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie owner_A UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_AA1', 100, date '2026-01-01' + 157);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_AA2', 100, date '2026-01-01' + 158);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie gjenowner_AA3', 100, date '2026-01-01' + 159);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('pengepremie owner_A DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie owner_A FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pengepremie manager_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'negativ');
select pg_temp.paastand('pengepremie manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1A1'', 100, date ''2026-01-01'' + 160)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A1A2'', 100, date ''2026-01-01'' + 161)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A1A3'', 100, date ''2026-01-01'' + 162)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1B1'', 100, date ''2026-01-01'' + 163)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie manager_A1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('pengepremie manager_A1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A1A1', 100, date '2026-01-01' + 164);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('pengepremie manager_A1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A1 FLYTTER egen rad A1 -> A2', 'update public.pengepremie set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A1 FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pengepremie manager_A12 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie manager_A12 SELECT A2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'positiv');
select pg_temp.paastand('pengepremie manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12A1'', 100, date ''2026-01-01'' + 165)');
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A12A2'', 100, date ''2026-01-01'' + 166)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A12A3'', 100, date ''2026-01-01'' + 167)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12B1'', 100, date ''2026-01-01'' + 168)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A12A1', 100, date '2026-01-01' + 169);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenmanager_A12A2', 100, date '2026-01-01' + 170);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('pengepremie manager_A12 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A12 FLYTTER egen rad A1 -> A3', 'update public.pengepremie set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_A12 FLYTTER egen rad -> kjede B', 'update public.pengepremie set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pengepremie tablet_A1 SELECT A1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'positiv');
select pg_temp.paastand('pengepremie tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb2-0000-4000-8000-0000d61e3cb2'), 'negativ');
select pg_temp.paastand('pengepremie tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb3-0000-4000-8000-0000d61e3cb3'), 'negativ');
select pg_temp.paastand('pengepremie tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'negativ');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1A1'', 100, date ''2026-01-01'' + 171)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_A1A2'', 100, date ''2026-01-01'' + 172)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie tablet_A1A3'', 100, date ''2026-01-01'' + 173)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1B1'', 100, date ''2026-01-01'' + 174)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE A3', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''', 'pengepremie', 'd61e3cb2-0000-4000-8000-0000d61e3cb2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''', 'pengepremie', 'd61e3cb3-0000-4000-8000-0000d61e3cb3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('pengepremie tablet_A1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pengepremie owner_B SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie owner_B SELECT B2 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'positiv');
select pg_temp.paastand('pengepremie owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BB1'', 100, date ''2026-01-01'' + 175)');
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_BB2'', 100, date ''2026-01-01'' + 176)');
select pg_temp.skriv_avvist('pengepremie owner_B INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BA1'', 100, date ''2026-01-01'' + 177)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie owner_B UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_BB1', 100, date '2026-01-01' + 178);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_BB2', 100, date '2026-01-01' + 179);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('pengepremie owner_B DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie owner_B FLYTTER egen rad -> kjede A', 'update public.pengepremie set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pengepremie manager_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'negativ');
select pg_temp.paastand('pengepremie manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_tillatt('pengepremie manager_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1B1'', 100, date ''2026-01-01'' + 180)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_B1B2'', 100, date ''2026-01-01'' + 181)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1A1'', 100, date ''2026-01-01'' + 182)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie manager_B1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('pengepremie manager_B1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_B1B1', 100, date '2026-01-01' + 183);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('pengepremie manager_B1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.skriv_avvist('pengepremie manager_B1 FLYTTER egen rad B1 -> B2', 'update public.pengepremie set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.skriv_avvist('pengepremie manager_B1 FLYTTER egen rad -> kjede A', 'update public.pengepremie set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pengepremie tablet_B1 SELECT B1 -> ser', exists (select 1 from public.pengepremie where id = 'd61e3cd0-0000-4000-8000-0000d61e3cd0'), 'positiv');
select pg_temp.paastand('pengepremie tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cd1-0000-4000-8000-0000d61e3cd1'), 'negativ');
select pg_temp.paastand('pengepremie tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.pengepremie where id = 'd61e3cb1-0000-4000-8000-0000d61e3cb1'), 'negativ');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1B1'', 100, date ''2026-01-01'' + 184)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_B1B2'', 100, date ''2026-01-01'' + 185)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1A1'', 100, date ''2026-01-01'' + 186)');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE B1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE B2', 'update public.pengepremie set utbetalt = true where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 UPDATE A1', 'update public.pengepremie set utbetalt = true where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE B1', 'delete from public.pengepremie where id = ''d61e3cd0-0000-4000-8000-0000d61e3cd0''', 'pengepremie', 'd61e3cd0-0000-4000-8000-0000d61e3cd0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''', 'pengepremie', 'd61e3cd1-0000-4000-8000-0000d61e3cd1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('pengepremie tablet_B1 DELETE A1', 'delete from public.pengepremie where id = ''d61e3cb1-0000-4000-8000-0000d61e3cb1''', 'pengepremie', 'd61e3cb1-0000-4000-8000-0000d61e3cb1', 'id');

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
-- persondata_logg  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('persondata_logg');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('persondata_logg owner_A SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT A3 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_A INSERT med manager_A1 sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_Asomannen'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_A INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_A INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'positiv');
select pg_temp.paastand('persondata_logg owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('persondata_logg manager_A1 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A1 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('persondata_logg manager_A12 SELECT A1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'positiv');
select pg_temp.paastand('persondata_logg manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A12 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_A12 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_A12 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d8-0000-4000-8000-0000a78b10d8'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d9-0000-4000-8000-0000a78b10d9'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_A1 INSERT med owner_A sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1somannen'', ''00000000-0000-0000-0000-00000000a000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_A1 INSERT A3', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''sonde_oppslag'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_A1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('persondata_logg owner_B SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT B2 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_B INSERT med manager_B1 sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_Bsomannen'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg owner_B INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg owner_B INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'positiv');
select pg_temp.paastand('persondata_logg owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('persondata_logg manager_B1 SELECT B1 -> ser', exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'positiv');
select pg_temp.paastand('persondata_logg manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'negativ');
select pg_temp.paastand('persondata_logg manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_B1 INSERT med owner_B sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1somannen'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg manager_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg manager_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');
select pg_temp.paastand('persondata_logg manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f6-0000-4000-8000-0000a78b10f6'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10f7-0000-4000-8000-0000a78b10f7'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.persondata_logg where id = 'a78b10d7-0000-4000-8000-0000a78b10d7'), 'negativ');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_B1 INSERT med owner_B sin bruker_id', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1somannen'', ''00000000-0000-0000-0000-00000000b000'', ''Sonde Sondesen'')');
select pg_temp.skriv_tillatt('persondata_logg tablet_B1 INSERT B2', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''sonde_oppslag'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.skriv_avvist('persondata_logg tablet_B1 INSERT A1', 'insert into public.persondata_logg (retailer_id, stasjon_id, handling, ansatt_nr, bruker_id, bruker_navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''sonde_oppslag'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'', ''Sonde Sondesen'')');
select pg_temp.paastand('persondata_logg tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.persondata_logg where id = '33f7439f-0000-4000-8000-000033f7439f'), 'negativ');
select pg_temp.paastand('persondata_logg tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.persondata_logg where id = '33f7439e-0000-4000-8000-000033f7439e'), 'negativ');

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
select pg_temp.skriv_tillatt('personlig_kryss owner_A INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a440-0000-4000-8000-00002d27a440'', date ''2026-01-01'' + 253)');
select pg_temp.skriv_avvist('personlig_kryss owner_A INSERT paa manager_A1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''2d27a441-0000-4000-8000-00002d27a441'', date ''2026-01-01'' + 254)');
select pg_temp.skriv_tillatt('personlig_kryss owner_A UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.skriv_avvist('personlig_kryss owner_A UPDATE manager_A1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_A DELETE manager_A1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''', 'personlig_kryss', 'eb9fbad7-0000-4000-8000-0000eb9fbad7', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_A DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e0-0000-4000-8000-000014c1b0e0', '00000000-0000-0000-0000-00000000a000', '2d27a442-0000-4000-8000-00002d27a442', date '2026-01-01' + 255);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('personlig_kryss manager_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a001'', ''2d27a443-0000-4000-8000-00002d27a443'', date ''2026-01-01'' + 256)');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a444-0000-4000-8000-00002d27a444'', date ''2026-01-01'' + 257)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbad7-0000-4000-8000-0000eb9fbad7''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbad7-0000-4000-8000-0000eb9fbad7', '00000000-0000-0000-0000-00000000a001', '2d27a445-0000-4000-8000-00002d27a445', date '2026-01-01' + 258);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('personlig_kryss manager_A12 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_A12 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a012'', ''2d27a446-0000-4000-8000-00002d27a446'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a45c-0000-4000-8000-00002d27a45c'', date ''2026-01-01'' + 260)');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_A12 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_A12 DELETE egen rad', 'delete from public.personlig_kryss where id = ''8857a03b-0000-4000-8000-00008857a03b''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('8857a03b-0000-4000-8000-00008857a03b', '00000000-0000-0000-0000-00000000a012', '2d27a45d-0000-4000-8000-00002d27a45d', date '2026-01-01' + 261);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_A1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a101'', ''2d27a45e-0000-4000-8000-00002d27a45e'', date ''2026-01-01'' + 262)');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 INSERT paa owner_A sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000a000'', ''2d27a45f-0000-4000-8000-00002d27a45f'', date ''2026-01-01'' + 263)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 UPDATE owner_A sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_A1 DELETE owner_A sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e0-0000-4000-8000-000014c1b0e0''', 'personlig_kryss', '14c1b0e0-0000-4000-8000-000014c1b0e0', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_A1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f40f4-0000-4000-8000-0000738f40f4''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f40f4-0000-4000-8000-0000738f40f4', '00000000-0000-0000-0000-00000000a101', '2d27a460-0000-4000-8000-00002d27a460', date '2026-01-01' + 264);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('personlig_kryss owner_B SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'positiv');
select pg_temp.paastand('personlig_kryss owner_B SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.paastand('personlig_kryss owner_B SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss owner_B INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7d00-0000-4000-8000-00002edc7d00'', date ''2026-01-01'' + 265)');
select pg_temp.skriv_avvist('personlig_kryss owner_B INSERT paa manager_B1 sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc7d01-0000-4000-8000-00002edc7d01'', date ''2026-01-01'' + 266)');
select pg_temp.skriv_tillatt('personlig_kryss owner_B UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.skriv_avvist('personlig_kryss owner_B UPDATE manager_B1 sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_avvist('personlig_kryss owner_B DELETE manager_B1 sin rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''', 'personlig_kryss', 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6', 'id');
select pg_temp.skriv_tillatt('personlig_kryss owner_B DELETE egen rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('14c1b0e1-0000-4000-8000-000014c1b0e1', '00000000-0000-0000-0000-00000000b000', '2edc7d02-0000-4000-8000-00002edc7d02', date '2026-01-01' + 267);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('personlig_kryss manager_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'positiv');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss manager_B1 SELECT tablet_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b001'', ''2edc7d03-0000-4000-8000-00002edc7d03'', date ''2026-01-01'' + 268)');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7d04-0000-4000-8000-00002edc7d04'', date ''2026-01-01'' + 269)');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss manager_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss manager_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''eb9fbaf6-0000-4000-8000-0000eb9fbaf6''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('eb9fbaf6-0000-4000-8000-0000eb9fbaf6', '00000000-0000-0000-0000-00000000b001', '2edc7d1a-0000-4000-8000-00002edc7d1a', date '2026-01-01' + 270);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT egen rad -> ser', exists (select 1 from public.personlig_kryss where id = '738f4113-0000-4000-8000-0000738f4113'), 'positiv');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_A sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e0-0000-4000-8000-000014c1b0e0'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbad7-0000-4000-8000-0000eb9fbad7'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_A12 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '8857a03b-0000-4000-8000-00008857a03b'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT tablet_A1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '738f40f4-0000-4000-8000-0000738f40f4'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT owner_B sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = '14c1b0e1-0000-4000-8000-000014c1b0e1'), 'negativ');
select pg_temp.paastand('personlig_kryss tablet_B1 SELECT manager_B1 sin rad -> ser ikke', not exists (select 1 from public.personlig_kryss where id = 'eb9fbaf6-0000-4000-8000-0000eb9fbaf6'), 'negativ');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 INSERT paa seg selv', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b101'', ''2edc7d1b-0000-4000-8000-00002edc7d1b'', date ''2026-01-01'' + 271)');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 INSERT paa owner_B sin liste', 'insert into public.personlig_kryss (user_id, punkt_id, dato) values (''00000000-0000-0000-0000-00000000b000'', ''2edc7d1c-0000-4000-8000-00002edc7d1c'', date ''2026-01-01'' + 272)');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 UPDATE egen rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 UPDATE owner_B sin rad', 'update public.personlig_kryss set opprettet_tid = now() where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_avvist('personlig_kryss tablet_B1 DELETE owner_B sin rad', 'delete from public.personlig_kryss where id = ''14c1b0e1-0000-4000-8000-000014c1b0e1''', 'personlig_kryss', '14c1b0e1-0000-4000-8000-000014c1b0e1', 'id');
select pg_temp.skriv_tillatt('personlig_kryss tablet_B1 DELETE egen rad', 'delete from public.personlig_kryss where id = ''738f4113-0000-4000-8000-0000738f4113''');
select pg_temp.som_eier();
insert into public.personlig_kryss (id, user_id, punkt_id, dato) values ('738f4113-0000-4000-8000-0000738f4113', '00000000-0000-0000-0000-00000000b101', '2edc7d1d-0000-4000-8000-00002edc7d1d', date '2026-01-01' + 273);
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
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_A DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('pin_forsok manager_A1 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('pin_forsok manager_A12 SELECT A -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_A12A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_A12 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_A12B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_A12 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('pin_forsok tablet_A1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_A1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_A1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_A1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_A1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('pin_forsok owner_B SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok owner_B SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''owner_BB1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok owner_B INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''owner_BA1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok owner_B DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('pin_forsok manager_B1 SELECT B -> ser', exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('pin_forsok manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''manager_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok manager_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''manager_B1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok manager_B1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('pin_forsok tablet_B1 SELECT B -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastB1'), 'negativ');
select pg_temp.paastand('pin_forsok tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.pin_forsok where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "ansatt_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT B', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''bbbb0000-0000-4000-8000-000000000000'', ''tablet_B1B1'', ''vakt'', false)');
select pg_temp.skriv_avvist('pin_forsok tablet_B1 INSERT A', 'insert into public.pin_forsok (retailer_id, ansatt_nr, kilde, ok) values (''aaaa0000-0000-4000-8000-000000000000'', ''tablet_B1A1'', ''vakt'', false)');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE B', 'update public.pin_forsok set ok = true where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 UPDATE A', 'update public.pin_forsok set ok = true where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 DELETE B', 'delete from public.pin_forsok where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''', 'pin_forsok', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('pin_forsok tablet_B1 DELETE A', 'delete from public.pin_forsok where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''', 'pin_forsok', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "ansatt_nr" = ''fastA1''');

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
    raise exception 'TENANT-MATRISEN DEL 5/9: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/9: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
