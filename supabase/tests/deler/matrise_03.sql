-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 7. Hele matrisen er for stor for Supabase SQL
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
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea39-0000-4000-8000-0000f3bfea39', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3c05e99-0000-4000-8000-0000f3c05e99', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3c0d2f9-0000-4000-8000-0000f3c0d2f9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA3', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce01bd-0000-4000-8000-0000f3ce01bd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce761d-0000-4000-8000-0000f3ce761d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d942d-0000-4000-8000-0000a86d942d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e088d-0000-4000-8000-0000a86e088d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7ced-0000-4000-8000-0000a86e7ced', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87babb1-0000-4000-8000-0000a87babb1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c2011-0000-4000-8000-0000a87c2011', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5c82-0000-4000-8000-0000843d5c82', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f23522-0000-4000-8000-000085f23522', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_AB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5c84-0000-4000-8000-0000843d5c84', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5c85-0000-4000-8000-0000843d5c85', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f2353a-0000-4000-8000-000085f2353a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5c9c-0000-4000-8000-0000843d5c9c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A12A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f2353c-0000-4000-8000-000085f2353c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A12B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5c9e-0000-4000-8000-0000843d5c9e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f2353e-0000-4000-8000-000085f2353e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f2353f-0000-4000-8000-000085f2353f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5ca1-0000-4000-8000-0000843d5ca1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_BA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f23541-0000-4000-8000-000085f23541', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f23542-0000-4000-8000-000085f23542', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5ca4-0000-4000-8000-0000843d5ca4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f23559-0000-4000-8000-000085f23559', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d5cbb-0000-4000-8000-0000843d5cbb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed50-0000-4000-8000-00006544ed50', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304e7-0000-4000-8000-0000655304e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c69-0000-4000-8000-000065611c69', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c607-0000-4000-8000-000066f9c607', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed69-0000-4000-8000-00006544ed69', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304eb-0000-4000-8000-0000655304eb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c6d-0000-4000-8000-000065611c6d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed6c-0000-4000-8000-00006544ed6c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304ee-0000-4000-8000-0000655304ee', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c70-0000-4000-8000-000065611c70', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c60e-0000-4000-8000-000066f9c60e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed85-0000-4000-8000-00006544ed85', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed86-0000-4000-8000-00006544ed86', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530508-0000-4000-8000-000065530508', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c8a-0000-4000-8000-000065611c8a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c628-0000-4000-8000-000066f9c628', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed8a-0000-4000-8000-00006544ed8a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553050c-0000-4000-8000-00006553050c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed8c-0000-4000-8000-00006544ed8c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553050e-0000-4000-8000-00006553050e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c90-0000-4000-8000-000065611c90', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c643-0000-4000-8000-000066f9c643', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c644-0000-4000-8000-000066f9c644', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707ddc6-0000-4000-8000-00006707ddc6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544eda7-0000-4000-8000-00006544eda7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c647-0000-4000-8000-000066f9c647', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707ddc9-0000-4000-8000-00006707ddc9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c649-0000-4000-8000-000066f9c649', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707ddcb-0000-4000-8000-00006707ddcb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544edac-0000-4000-8000-00006544edac', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c64c-0000-4000-8000-000066f9c64c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c662-0000-4000-8000-000066f9c662', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dde4-0000-4000-8000-00006707dde4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544edc5-0000-4000-8000-00006544edc5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
-- --- kassererstatistikk: forutsetninger og proberader ---
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0, 'fastA1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1, 'fastA2', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2, 'fastA3', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3, 'fastB1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4, 'fastB2', 'Sonde Sondesen', 1000, 10);

create or replace function pg_temp.nyrad_kassererstatistikk(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 1000, 10);
end $fn$;
-- --- kontrolltiltak_bekreftelse: forutsetninger og proberader ---
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea45-0000-4000-8000-00009d6fea45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'fastA1', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea46-0000-4000-8000-00009d6fea46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'fastA2', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea47-0000-4000-8000-00009d6fea47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'fastA3', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea64-0000-4000-8000-00009d6fea64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'fastB1', '00000000-0000-0000-0000-00000000b000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea65-0000-4000-8000-00009d6fea65', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'fastB2', '00000000-0000-0000-0000-00000000b000');
-- --- malekort: forutsetninger og proberader ---
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171ada7-0000-4000-8000-00008171ada7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171ada8-0000-4000-8000-00008171ada8', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171ada9-0000-4000-8000-00008171ada9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA3', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171adc6-0000-4000-8000-00008171adc6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171adc7-0000-4000-8000-00008171adc7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB2', 'omsetning', 'maaned', 'hoy', true, true);

create or replace function pg_temp.nyrad_malekort(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef)
  values (p_retailer, 'Sondekort ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'omsetning', 'maaned', 'hoy', true, true)
  returning id into ny;
  return ny;
end $fn$;
-- --- malekort_scope: forutsetninger og proberader ---
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', 'f3bfea39-0000-4000-8000-0000f3bfea39', 'avdeling', 'fastA1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bd-0000-4000-8000-00005d5db7bd', 'aaaa0000-0000-4000-8000-000000000000', 'f3c05e99-0000-4000-8000-0000f3c05e99', 'avdeling', 'fastA2');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7be-0000-4000-8000-00005d5db7be', 'aaaa0000-0000-4000-8000-000000000000', 'f3c0d2f9-0000-4000-8000-0000f3c0d2f9', 'avdeling', 'fastA3');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce01bd-0000-4000-8000-0000f3ce01bd', 'avdeling', 'fastB1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7dc-0000-4000-8000-00005d5db7dc', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce761d-0000-4000-8000-0000f3ce761d', 'avdeling', 'fastB2');

create or replace function pg_temp.nyrad_malekort_scope(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_malekort uuid := gen_random_uuid();
begin
  insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (v_malekort, p_retailer, 'Sondekort ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'omsetning', 'maaned', 'hoy', true, true);
  insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode)
  values (p_retailer, v_malekort, 'avdeling', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- oppgaver: forutsetninger og proberader ---
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave fastA1');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave fastA2');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7b0-0000-4000-8000-000021faa7b0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeoppgave fastA3');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave fastB1');
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ce-0000-4000-8000-000021faa7ce', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeoppgave fastB2');

create or replace function pg_temp.nyrad_oppgaver(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.oppgaver (retailer_id, stasjon_id, tittel)
  values (p_retailer, p_stasjon, 'Sondeoppgave ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- opplaering_oppgave: forutsetninger og proberader ---
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('4762309e-0000-4000-8000-00004762309e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave fastA1');
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('4762309f-0000-4000-8000-00004762309f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave fastA2');
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('476230a0-0000-4000-8000-0000476230a0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave fastA3');
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('476230bd-0000-4000-8000-0000476230bd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave fastB1');
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('476230be-0000-4000-8000-0000476230be', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave fastB2');

create or replace function pg_temp.nyrad_opplaering_oppgave(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.opplaering_oppgave (retailer_id, tittel)
  values (p_retailer, 'Sondeoppgave ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d942d-0000-4000-8000-0000a86d942d', date '2026-01-01' + 35);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e088d-0000-4000-8000-0000a86e088d', date '2026-01-01' + 36);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7ced-0000-4000-8000-0000a86e7ced', date '2026-01-01' + 37);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87babb1-0000-4000-8000-0000a87babb1', date '2026-01-01' + 38);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', 'a87c2011-0000-4000-8000-0000a87c2011', date '2026-01-01' + 39);

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

-- =====================================================================
-- kassererstatistikk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kassererstatistikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kassererstatistikk owner_A SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 1 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A3 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 2 and "kasserer_nr" = 'fastA3'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 40, ''owner_AA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 41, ''owner_AA2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 42, ''owner_AA3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_A INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 43, ''owner_AB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0, 'fastA1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1, 'fastA2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2, 'fastA3', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A FLYTTER egen rad -> kjede B', 'update public.kassererstatistikk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 1 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 2 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 44, ''manager_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 45, ''manager_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 46, ''manager_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 47, ''manager_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 1 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 2 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 48, ''manager_A12A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 49, ''manager_A12A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 50, ''manager_A12A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 51, ''manager_A12B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 1 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 2 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 52, ''tablet_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 53, ''tablet_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 54, ''tablet_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 55, ''tablet_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 1 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 2 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kassererstatistikk owner_B SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT B2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 4 and "kasserer_nr" = 'fastB2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 56, ''owner_BB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 57, ''owner_BB2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_B INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 58, ''owner_BA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3, 'fastB1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4, 'fastB2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B FLYTTER egen rad -> kjede A', 'update public.kassererstatistikk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 4 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 59, ''manager_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 60, ''manager_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 61, ''manager_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 4 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 62, ''tablet_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 63, ''tablet_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 64, ''tablet_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 3 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 4 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 0 and "kasserer_nr" = ''fastA1''');

-- =====================================================================
-- kontrolltiltak_bekreftelse  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kontrolltiltak_bekreftelse');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A3 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'')');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse tablet_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'')');

-- =====================================================================
-- malekort  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('malekort');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('malekort owner_A SELECT A -> ser', exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'positiv');
select pg_temp.paastand('malekort owner_A SELECT B -> ser ikke', not exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'negativ');
select pg_temp.skriv_tillatt('malekort owner_A INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort owner_AA1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort owner_A INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort owner_AB1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('malekort owner_A UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort owner_A UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('malekort owner_A DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''');
select pg_temp.som_eier();
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171ada7-0000-4000-8000-00008171ada7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort owner_A DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.skriv_avvist('malekort owner_A FLYTTER egen rad -> kjede B', 'update public.malekort set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('malekort manager_A1 SELECT A -> ser', exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'positiv');
select pg_temp.paastand('malekort manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'negativ');
select pg_temp.skriv_avvist('malekort manager_A1 INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort manager_A1A1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort manager_A1 INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort manager_A1B1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort manager_A1 UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort manager_A1 UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort manager_A1 DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('malekort manager_A1 DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('malekort manager_A12 SELECT A -> ser', exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'positiv');
select pg_temp.paastand('malekort manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'negativ');
select pg_temp.skriv_avvist('malekort manager_A12 INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort manager_A12A1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort manager_A12 INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort manager_A12B1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort manager_A12 UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort manager_A12 UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort manager_A12 DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('malekort manager_A12 DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('malekort tablet_A1 SELECT A -> ser', exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'positiv');
select pg_temp.paastand('malekort tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'negativ');
select pg_temp.skriv_avvist('malekort tablet_A1 INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort tablet_A1A1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort tablet_A1 INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort tablet_A1B1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort tablet_A1 UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort tablet_A1 UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort tablet_A1 DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('malekort tablet_A1 DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('malekort owner_B SELECT B -> ser', exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'positiv');
select pg_temp.paastand('malekort owner_B SELECT A -> ser ikke', not exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'negativ');
select pg_temp.skriv_tillatt('malekort owner_B INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort owner_BB1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort owner_B INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort owner_BA1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('malekort owner_B UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort owner_B UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('malekort owner_B DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''');
select pg_temp.som_eier();
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('8171adc6-0000-4000-8000-00008171adc6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort owner_B DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.skriv_avvist('malekort owner_B FLYTTER egen rad -> kjede A', 'update public.malekort set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('malekort manager_B1 SELECT B -> ser', exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'positiv');
select pg_temp.paastand('malekort manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'negativ');
select pg_temp.skriv_avvist('malekort manager_B1 INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort manager_B1B1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort manager_B1 INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort manager_B1A1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort manager_B1 UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort manager_B1 UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort manager_B1 DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('malekort manager_B1 DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('malekort tablet_B1 SELECT B -> ser', exists (select 1 from public.malekort where id = '8171adc6-0000-4000-8000-00008171adc6'), 'positiv');
select pg_temp.paastand('malekort tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort where id = '8171ada7-0000-4000-8000-00008171ada7'), 'negativ');
select pg_temp.skriv_avvist('malekort tablet_B1 INSERT B', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekort tablet_B1B1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.skriv_avvist('malekort tablet_B1 INSERT A', 'insert into public.malekort (retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekort tablet_B1A1'', ''omsetning'', ''maaned'', ''hoy'', true, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort tablet_B1 UPDATE B', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort tablet_B1 UPDATE A', 'update public.malekort set navn = ''Sondekort endret'' where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort tablet_B1 DELETE B', 'delete from public.malekort where id = ''8171adc6-0000-4000-8000-00008171adc6''', 'malekort', '8171adc6-0000-4000-8000-00008171adc6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('malekort tablet_B1 DELETE A', 'delete from public.malekort where id = ''8171ada7-0000-4000-8000-00008171ada7''', 'malekort', '8171ada7-0000-4000-8000-00008171ada7', 'id');

-- =====================================================================
-- malekort_scope  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('malekort_scope');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('malekort_scope owner_A SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope owner_A SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_tillatt('malekort_scope owner_A INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5c82-0000-4000-8000-0000843d5c82'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('malekort_scope owner_A INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f23522-0000-4000-8000-000085f23522'', ''avdeling'', ''owner_AB1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', '843d5c84-0000-4000-8000-0000843d5c84', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort_scope owner_A DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_A FLYTTER egen rad -> kjede B', 'update public.malekort_scope set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('malekort_scope manager_A1 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5c85-0000-4000-8000-0000843d5c85'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2353a-0000-4000-8000-000085f2353a'', ''avdeling'', ''manager_A1B1'')');
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
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5c9c-0000-4000-8000-0000843d5c9c'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2353c-0000-4000-8000-000085f2353c'', ''avdeling'', ''manager_A12B1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5c9e-0000-4000-8000-0000843d5c9e'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2353e-0000-4000-8000-000085f2353e'', ''avdeling'', ''tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('malekort_scope owner_B INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f2353f-0000-4000-8000-000085f2353f'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('malekort_scope owner_B INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5ca1-0000-4000-8000-0000843d5ca1'', ''avdeling'', ''owner_BA1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', '85f23541-0000-4000-8000-000085f23541', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort_scope owner_B DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_B FLYTTER egen rad -> kjede A', 'update public.malekort_scope set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('malekort_scope manager_B1 SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f23542-0000-4000-8000-000085f23542'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5ca4-0000-4000-8000-0000843d5ca4'', ''avdeling'', ''manager_B1A1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f23559-0000-4000-8000-000085f23559'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d5cbb-0000-4000-8000-0000843d5cbb'', ''avdeling'', ''tablet_B1A1'')');
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
-- oppgaver  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('oppgaver');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('oppgaver owner_A SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT A2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT A3 -> ser', exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'positiv');
select pg_temp.paastand('oppgaver owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_AA1'')');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave owner_AA2'')');
select pg_temp.skriv_tillatt('oppgaver owner_A INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave owner_AA3'')');
select pg_temp.skriv_avvist('oppgaver owner_A INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('oppgaver owner_A UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('oppgaver owner_A DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7b0-0000-4000-8000-000021faa7b0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeoppgave gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('oppgaver owner_A DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver owner_A FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('oppgaver manager_A1 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'negativ');
select pg_temp.paastand('oppgaver manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_A1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A1A1'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_A1A2'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave manager_A1A3'')');
select pg_temp.skriv_avvist('oppgaver manager_A1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('oppgaver manager_A1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('oppgaver manager_A1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('oppgaver manager_A1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A1 FLYTTER egen rad A1 -> A2', 'update public.oppgaver set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A1 FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('oppgaver manager_A12 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver manager_A12 SELECT A2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'positiv');
select pg_temp.paastand('oppgaver manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_A12 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A12A1'')');
select pg_temp.skriv_tillatt('oppgaver manager_A12 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_A12A2'')');
select pg_temp.skriv_avvist('oppgaver manager_A12 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave manager_A12A3'')');
select pg_temp.skriv_avvist('oppgaver manager_A12 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ae-0000-4000-8000-000021faa7ae', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('oppgaver manager_A12 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7af-0000-4000-8000-000021faa7af', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('oppgaver manager_A12 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A12 FLYTTER egen rad A1 -> A3', 'update public.oppgaver set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_A12 FLYTTER egen rad -> kjede B', 'update public.oppgaver set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('oppgaver tablet_A1 SELECT A1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'positiv');
select pg_temp.paastand('oppgaver tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7af-0000-4000-8000-000021faa7af'), 'negativ');
select pg_temp.paastand('oppgaver tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7b0-0000-4000-8000-000021faa7b0'), 'negativ');
select pg_temp.paastand('oppgaver tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'negativ');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_A1A1'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondeoppgave tablet_A1A2'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT A3', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondeoppgave tablet_A1A3'')');
select pg_temp.skriv_avvist('oppgaver tablet_A1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE A3', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A2', 'delete from public.oppgaver where id = ''21faa7af-0000-4000-8000-000021faa7af''', 'oppgaver', '21faa7af-0000-4000-8000-000021faa7af', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE A3', 'delete from public.oppgaver where id = ''21faa7b0-0000-4000-8000-000021faa7b0''', 'oppgaver', '21faa7b0-0000-4000-8000-000021faa7b0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('oppgaver tablet_A1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('oppgaver owner_B SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver owner_B SELECT B2 -> ser', exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'positiv');
select pg_temp.paastand('oppgaver owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver owner_B INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_BB1'')');
select pg_temp.skriv_tillatt('oppgaver owner_B INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave owner_BB2'')');
select pg_temp.skriv_avvist('oppgaver owner_B INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('oppgaver owner_B UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('oppgaver owner_B DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7ce-0000-4000-8000-000021faa7ce', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeoppgave gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('oppgaver owner_B DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver owner_B FLYTTER egen rad -> kjede A', 'update public.oppgaver set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('oppgaver manager_B1 SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'negativ');
select pg_temp.paastand('oppgaver manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_tillatt('oppgaver manager_B1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_B1B1'')');
select pg_temp.skriv_avvist('oppgaver manager_B1 INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave manager_B1B2'')');
select pg_temp.skriv_avvist('oppgaver manager_B1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('oppgaver manager_B1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('oppgaver manager_B1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''');
select pg_temp.som_eier();
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel) values ('21faa7cd-0000-4000-8000-000021faa7cd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeoppgave gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('oppgaver manager_B1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.skriv_avvist('oppgaver manager_B1 FLYTTER egen rad B1 -> B2', 'update public.oppgaver set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.skriv_avvist('oppgaver manager_B1 FLYTTER egen rad -> kjede A', 'update public.oppgaver set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('oppgaver tablet_B1 SELECT B1 -> ser', exists (select 1 from public.oppgaver where id = '21faa7cd-0000-4000-8000-000021faa7cd'), 'positiv');
select pg_temp.paastand('oppgaver tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ce-0000-4000-8000-000021faa7ce'), 'negativ');
select pg_temp.paastand('oppgaver tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.oppgaver where id = '21faa7ae-0000-4000-8000-000021faa7ae'), 'negativ');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT B1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_B1B1'')');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT B2', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondeoppgave tablet_B1B2'')');
select pg_temp.skriv_avvist('oppgaver tablet_B1 INSERT A1', 'insert into public.oppgaver (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondeoppgave tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE B1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE B2', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 UPDATE A1', 'update public.oppgaver set status = ''fullfort'' where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE B1', 'delete from public.oppgaver where id = ''21faa7cd-0000-4000-8000-000021faa7cd''', 'oppgaver', '21faa7cd-0000-4000-8000-000021faa7cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE B2', 'delete from public.oppgaver where id = ''21faa7ce-0000-4000-8000-000021faa7ce''', 'oppgaver', '21faa7ce-0000-4000-8000-000021faa7ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_oppgaver('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('oppgaver tablet_B1 DELETE A1', 'delete from public.oppgaver where id = ''21faa7ae-0000-4000-8000-000021faa7ae''', 'oppgaver', '21faa7ae-0000-4000-8000-000021faa7ae', 'id');

-- =====================================================================
-- opplaering_oppgave  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_oppgave');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_oppgave owner_A SELECT A -> ser', exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'positiv');
select pg_temp.paastand('opplaering_oppgave owner_A SELECT B -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_A INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave owner_AA1'')');
select pg_temp.skriv_avvist('opplaering_oppgave owner_A INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_A UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_oppgave owner_A UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_A DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('4762309e-0000-4000-8000-00004762309e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('opplaering_oppgave owner_A DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.skriv_avvist('opplaering_oppgave owner_A FLYTTER egen rad -> kjede B', 'update public.opplaering_oppgave set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('opplaering_oppgave manager_A1 SELECT A -> ser', exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'positiv');
select pg_temp.paastand('opplaering_oppgave manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A1 INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_A1A1'')');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A1 INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A1 UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A1 UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A1 DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('4762309e-0000-4000-8000-00004762309e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A1 DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A1 FLYTTER egen rad -> kjede B', 'update public.opplaering_oppgave set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('opplaering_oppgave manager_A12 SELECT A -> ser', exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'positiv');
select pg_temp.paastand('opplaering_oppgave manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A12 INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_A12A1'')');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A12 INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A12 UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A12 UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_A12 DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''');
select pg_temp.som_eier();
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('4762309e-0000-4000-8000-00004762309e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A12 DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.skriv_avvist('opplaering_oppgave manager_A12 FLYTTER egen rad -> kjede B', 'update public.opplaering_oppgave set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('opplaering_oppgave tablet_A1 SELECT A -> ser', exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'positiv');
select pg_temp.paastand('opplaering_oppgave tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'negativ');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave tablet_A1A1'')');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_A1 DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('opplaering_oppgave owner_B SELECT B -> ser', exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'positiv');
select pg_temp.paastand('opplaering_oppgave owner_B SELECT A -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_B INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave owner_BB1'')');
select pg_temp.skriv_avvist('opplaering_oppgave owner_B INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_B UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_oppgave owner_B UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_oppgave owner_B DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''');
select pg_temp.som_eier();
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('476230bd-0000-4000-8000-0000476230bd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_oppgave owner_B DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.skriv_avvist('opplaering_oppgave owner_B FLYTTER egen rad -> kjede A', 'update public.opplaering_oppgave set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_oppgave manager_B1 SELECT B -> ser', exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'positiv');
select pg_temp.paastand('opplaering_oppgave manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_B1 INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_B1B1'')');
select pg_temp.skriv_avvist('opplaering_oppgave manager_B1 INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_B1 UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_oppgave manager_B1 UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('opplaering_oppgave manager_B1 DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''');
select pg_temp.som_eier();
insert into public.opplaering_oppgave (id, retailer_id, tittel) values ('476230bd-0000-4000-8000-0000476230bd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('opplaering_oppgave manager_B1 DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.skriv_avvist('opplaering_oppgave manager_B1 FLYTTER egen rad -> kjede A', 'update public.opplaering_oppgave set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('opplaering_oppgave tablet_B1 SELECT B -> ser', exists (select 1 from public.opplaering_oppgave where id = '476230bd-0000-4000-8000-0000476230bd'), 'positiv');
select pg_temp.paastand('opplaering_oppgave tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.opplaering_oppgave where id = '4762309e-0000-4000-8000-00004762309e'), 'negativ');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 INSERT B', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondeoppgave tablet_B1B1'')');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 INSERT A', 'insert into public.opplaering_oppgave (retailer_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondeoppgave tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 UPDATE B', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 UPDATE A', 'update public.opplaering_oppgave set rekkefolge = 1 where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 DELETE B', 'delete from public.opplaering_oppgave where id = ''476230bd-0000-4000-8000-0000476230bd''', 'opplaering_oppgave', '476230bd-0000-4000-8000-0000476230bd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_oppgave('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('opplaering_oppgave tablet_B1 DELETE A', 'delete from public.opplaering_oppgave where id = ''4762309e-0000-4000-8000-00004762309e''', 'opplaering_oppgave', '4762309e-0000-4000-8000-00004762309e', 'id');

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
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed50-0000-4000-8000-00006544ed50'', date ''2026-01-01'' + 209)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655304e7-0000-4000-8000-0000655304e7'', date ''2026-01-01'' + 210)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c69-0000-4000-8000-000065611c69'', date ''2026-01-01'' + 211)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c607-0000-4000-8000-000066f9c607'', date ''2026-01-01'' + 212)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ed69-0000-4000-8000-00006544ed69', date '2026-01-01' + 213);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '655304eb-0000-4000-8000-0000655304eb', date '2026-01-01' + 214);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '65611c6d-0000-4000-8000-000065611c6d', date '2026-01-01' + 215);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed6c-0000-4000-8000-00006544ed6c'', date ''2026-01-01'' + 216)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655304ee-0000-4000-8000-0000655304ee'', date ''2026-01-01'' + 217)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c70-0000-4000-8000-000065611c70'', date ''2026-01-01'' + 218)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c60e-0000-4000-8000-000066f9c60e'', date ''2026-01-01'' + 219)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ed85-0000-4000-8000-00006544ed85', date '2026-01-01' + 220);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed86-0000-4000-8000-00006544ed86'', date ''2026-01-01'' + 221)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''65530508-0000-4000-8000-000065530508'', date ''2026-01-01'' + 222)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c8a-0000-4000-8000-000065611c8a'', date ''2026-01-01'' + 223)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c628-0000-4000-8000-000066f9c628'', date ''2026-01-01'' + 224)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ed8a-0000-4000-8000-00006544ed8a', date '2026-01-01' + 225);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '6553050c-0000-4000-8000-00006553050c', date '2026-01-01' + 226);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed8c-0000-4000-8000-00006544ed8c'', date ''2026-01-01'' + 227)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''6553050e-0000-4000-8000-00006553050e'', date ''2026-01-01'' + 228)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c90-0000-4000-8000-000065611c90'', date ''2026-01-01'' + 229)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c643-0000-4000-8000-000066f9c643'', date ''2026-01-01'' + 230)');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c644-0000-4000-8000-000066f9c644'', date ''2026-01-01'' + 231)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707ddc6-0000-4000-8000-00006707ddc6'', date ''2026-01-01'' + 232)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544eda7-0000-4000-8000-00006544eda7'', date ''2026-01-01'' + 233)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c647-0000-4000-8000-000066f9c647', date '2026-01-01' + 234);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '6707ddc9-0000-4000-8000-00006707ddc9', date '2026-01-01' + 235);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c649-0000-4000-8000-000066f9c649'', date ''2026-01-01'' + 236)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707ddcb-0000-4000-8000-00006707ddcb'', date ''2026-01-01'' + 237)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544edac-0000-4000-8000-00006544edac'', date ''2026-01-01'' + 238)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c64c-0000-4000-8000-000066f9c64c', date '2026-01-01' + 239);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c662-0000-4000-8000-000066f9c662'', date ''2026-01-01'' + 240)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dde4-0000-4000-8000-00006707dde4'', date ''2026-01-01'' + 241)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544edc5-0000-4000-8000-00006544edc5'', date ''2026-01-01'' + 242)');
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
    raise exception 'TENANT-MATRISEN DEL 3/7: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 3/7: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
