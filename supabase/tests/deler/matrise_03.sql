-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 7. Hele matrisen er for stor for Supabase SQL
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
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea77-0000-4000-8000-0000f3bfea77', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3c05ed7-0000-4000-8000-0000f3c05ed7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3c0d337-0000-4000-8000-0000f3c0d337', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA3', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce01fb-0000-4000-8000-0000f3ce01fb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce765b-0000-4000-8000-0000f3ce765b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d603e-0000-4000-8000-0000843d603e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238de-0000-4000-8000-000085f238de', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_AB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6040-0000-4000-8000-0000843d6040', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6041-0000-4000-8000-0000843d6041', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238e1-0000-4000-8000-000085f238e1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6043-0000-4000-8000-0000843d6043', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A12A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238e3-0000-4000-8000-000085f238e3', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A12B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6045-0000-4000-8000-0000843d6045', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238e5-0000-4000-8000-000085f238e5', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238fb-0000-4000-8000-000085f238fb', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d605d-0000-4000-8000-0000843d605d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_BA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238fd-0000-4000-8000-000085f238fd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f238fe-0000-4000-8000-000085f238fe', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6060-0000-4000-8000-0000843d6060', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('85f23900-0000-4000-8000-000085f23900', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('843d6062-0000-4000-8000-0000843d6062', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
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
-- --- kampanjer: forutsetninger og proberader ---
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee5-0000-4000-8000-000047a8eee5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA1', date '2026-01-01' + 5, date '2026-01-01' + 5 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee6-0000-4000-8000-000047a8eee6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA2', date '2026-01-01' + 6, date '2026-01-01' + 6 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8eee7-0000-4000-8000-000047a8eee7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekampanje fastA3', date '2026-01-01' + 7, date '2026-01-01' + 7 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef04-0000-4000-8000-000047a8ef04', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB1', date '2026-01-01' + 8, date '2026-01-01' + 8 + 7);
insert into public.kampanjer (id, retailer_id, navn, fra_dato, til_dato) values ('47a8ef05-0000-4000-8000-000047a8ef05', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekampanje fastB2', date '2026-01-01' + 9, date '2026-01-01' + 9 + 7);

create or replace function pg_temp.nyrad_kampanjer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato)
  values (p_retailer, 'Sondekampanje ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, date '2030-01-01' + nextval('tenant_teller'::regclass)::int + 7)
  returning id into ny;
  return ny;
end $fn$;
-- --- kassererstatistikk: forutsetninger og proberader ---
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, 'fastA1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, 'fastA2', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 12, 'fastA3', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 13, 'fastB1', 'Sonde Sondesen', 1000, 10);
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 14, 'fastB2', 'Sonde Sondesen', 1000, 10);

create or replace function pg_temp.nyrad_kassererstatistikk(p_retailer uuid, p_stasjon uuid, p_merke text)
returns void language plpgsql security definer as $fn$
declare
begin
  insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 1000, 10);
end $fn$;
-- --- konkurranser: forutsetninger og proberader ---
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515953-0000-4000-8000-00001c515953', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA1', 'omsetning sonde', date '2026-01-01' + 15, date '2026-01-01' + 15 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515954-0000-4000-8000-00001c515954', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA2', 'omsetning sonde', date '2026-01-01' + 16, date '2026-01-01' + 16 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515955-0000-4000-8000-00001c515955', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastA3', 'omsetning sonde', date '2026-01-01' + 17, date '2026-01-01' + 17 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515972-0000-4000-8000-00001c515972', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastB1', 'omsetning sonde', date '2026-01-01' + 18, date '2026-01-01' + 18 + 30);
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515973-0000-4000-8000-00001c515973', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse fastB2', 'omsetning sonde', date '2026-01-01' + 19, date '2026-01-01' + 19 + 30);

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
-- --- kontrolltiltak_bekreftelse: forutsetninger og proberader ---
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea45-0000-4000-8000-00009d6fea45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'fastA1', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea46-0000-4000-8000-00009d6fea46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'fastA2', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea47-0000-4000-8000-00009d6fea47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'fastA3', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea64-0000-4000-8000-00009d6fea64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'fastB1', '00000000-0000-0000-0000-00000000b000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea65-0000-4000-8000-00009d6fea65', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'fastB2', '00000000-0000-0000-0000-00000000b000');
-- --- lenker: forutsetninger og proberader ---
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b97-0000-4000-8000-00009d717b97', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke fastA1', 'https://sonde.local/fastA1');
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b98-0000-4000-8000-00009d717b98', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke fastA2', 'https://sonde.local/fastA2');
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b99-0000-4000-8000-00009d717b99', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke fastA3', 'https://sonde.local/fastA3');
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717bb6-0000-4000-8000-00009d717bb6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondelenke fastB1', 'https://sonde.local/fastB1');
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717bb7-0000-4000-8000-00009d717bb7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondelenke fastB2', 'https://sonde.local/fastB2');

create or replace function pg_temp.nyrad_lenker(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.lenker (retailer_id, tittel, url)
  values (p_retailer, 'Sondelenke ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'https://sonde.local/' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', 'f3bfea77-0000-4000-8000-0000f3bfea77', 'avdeling', 'fastA1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bd-0000-4000-8000-00005d5db7bd', 'aaaa0000-0000-4000-8000-000000000000', 'f3c05ed7-0000-4000-8000-0000f3c05ed7', 'avdeling', 'fastA2');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7be-0000-4000-8000-00005d5db7be', 'aaaa0000-0000-4000-8000-000000000000', 'f3c0d337-0000-4000-8000-0000f3c0d337', 'avdeling', 'fastA3');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce01fb-0000-4000-8000-0000f3ce01fb', 'avdeling', 'fastB1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7dc-0000-4000-8000-00005d5db7dc', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce765b-0000-4000-8000-0000f3ce765b', 'avdeling', 'fastB2');

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
-- --- merker: forutsetninger og proberader ---
insert into public.merker (id, retailer_id, navn) values ('9e15dab2-0000-4000-8000-00009e15dab2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke fastA1');
insert into public.merker (id, retailer_id, navn) values ('9e15dab3-0000-4000-8000-00009e15dab3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke fastA2');
insert into public.merker (id, retailer_id, navn) values ('9e15dab4-0000-4000-8000-00009e15dab4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke fastA3');
insert into public.merker (id, retailer_id, navn) values ('9e15dad1-0000-4000-8000-00009e15dad1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke fastB1');
insert into public.merker (id, retailer_id, navn) values ('9e15dad2-0000-4000-8000-00009e15dad2', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke fastB2');

create or replace function pg_temp.nyrad_merker(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.merker (retailer_id, navn)
  values (p_retailer, 'Sondemerke ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
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
-- kampanjer  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kampanjer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kampanjer owner_A SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer owner_A SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer owner_A INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AA1'', date ''2026-01-01'' + 84, date ''2026-01-01'' + 84 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_A INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_AB1'', date ''2026-01-01'' + 85, date ''2026-01-01'' + 85 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kampanjer owner_A UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kampanjer owner_A DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kampanjer manager_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1A1'', date ''2026-01-01'' + 86, date ''2026-01-01'' + 86 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A1B1'', date ''2026-01-01'' + 87, date ''2026-01-01'' + 87 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kampanjer manager_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kampanjer manager_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kampanjer manager_A12 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12A1'', date ''2026-01-01'' + 88, date ''2026-01-01'' + 88 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_A12 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_A12B1'', date ''2026-01-01'' + 89, date ''2026-01-01'' + 89 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kampanjer manager_A12 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kampanjer manager_A12 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kampanjer tablet_A1 SELECT A -> ser', exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'positiv');
select pg_temp.paastand('kampanjer tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1A1'', date ''2026-01-01'' + 90, date ''2026-01-01'' + 90 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_A1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_A1B1'', date ''2026-01-01'' + 91, date ''2026-01-01'' + 91 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kampanjer tablet_A1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kampanjer tablet_A1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kampanjer owner_B SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer owner_B SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BB1'', date ''2026-01-01'' + 92, date ''2026-01-01'' + 92 + 7)');
select pg_temp.skriv_avvist('kampanjer owner_B INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje owner_BA1'', date ''2026-01-01'' + 93, date ''2026-01-01'' + 93 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kampanjer owner_B UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kampanjer owner_B DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kampanjer manager_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1B1'', date ''2026-01-01'' + 94, date ''2026-01-01'' + 94 + 7)');
select pg_temp.skriv_avvist('kampanjer manager_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje manager_B1A1'', date ''2026-01-01'' + 95, date ''2026-01-01'' + 95 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kampanjer manager_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kampanjer manager_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kampanjer tablet_B1 SELECT B -> ser', exists (select 1 from public.kampanjer where id = '47a8ef04-0000-4000-8000-000047a8ef04'), 'positiv');
select pg_temp.paastand('kampanjer tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.kampanjer where id = '47a8eee5-0000-4000-8000-000047a8eee5'), 'negativ');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT B', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1B1'', date ''2026-01-01'' + 96, date ''2026-01-01'' + 96 + 7)');
select pg_temp.skriv_avvist('kampanjer tablet_B1 INSERT A', 'insert into public.kampanjer (retailer_id, navn, fra_dato, til_dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekampanje tablet_B1A1'', date ''2026-01-01'' + 97, date ''2026-01-01'' + 97 + 7)');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE B', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kampanjer tablet_B1 UPDATE A', 'update public.kampanjer set navn = ''endret av sonden'' where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE B', 'delete from public.kampanjer where id = ''47a8ef04-0000-4000-8000-000047a8ef04''', 'kampanjer', '47a8ef04-0000-4000-8000-000047a8ef04', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kampanjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kampanjer tablet_B1 DELETE A', 'delete from public.kampanjer where id = ''47a8eee5-0000-4000-8000-000047a8eee5''', 'kampanjer', '47a8eee5-0000-4000-8000-000047a8eee5', 'id');

-- =====================================================================
-- kassererstatistikk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kassererstatistikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kassererstatistikk owner_A SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A3 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "kasserer_nr" = 'fastA3'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 98, ''owner_AA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 99, ''owner_AA2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 100, ''owner_AA3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_A INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 101, ''owner_AB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 10, 'fastA1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 11, 'fastA2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 12, 'fastA3', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_A FLYTTER egen rad -> kjede B', 'update public.kassererstatistikk set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 102, ''manager_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 103, ''manager_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 104, ''manager_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 105, ''manager_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 106, ''manager_A12A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 107, ''manager_A12A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 108, ''manager_A12A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 109, ''manager_A12B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_A12 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 11 and "kasserer_nr" = 'fastA2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 12 and "kasserer_nr" = 'fastA3'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 110, ''tablet_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 111, ''tablet_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 112, ''tablet_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 113, ''tablet_A1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE A3', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A2', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 11 and "kasserer_nr" = ''fastA2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE A3', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "dato" = date ''2026-01-01'' + 12 and "kasserer_nr" = ''fastA3''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_A1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kassererstatistikk owner_B SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT B2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "kasserer_nr" = 'fastB2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 114, ''owner_BB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 115, ''owner_BB2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_B INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 116, ''owner_BA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 13, 'fastB1', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 14, 'fastB2', 'Sonde Sondesen', 1000, 10);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kassererstatistikk owner_B FLYTTER egen rad -> kjede A', 'update public.kassererstatistikk set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 117, ''manager_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 118, ''manager_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 119, ''manager_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('kassererstatistikk manager_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 13 and "kasserer_nr" = 'fastB1'), 'positiv');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 14 and "kasserer_nr" = 'fastB2'), 'negativ');
select pg_temp.paastand('kassererstatistikk tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 10 and "kasserer_nr" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 120, ''tablet_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 121, ''tablet_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 122, ''tablet_B1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE B2', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 UPDATE A1', 'update public.kassererstatistikk set bonger = 11 where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B1', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 13 and "kasserer_nr" = ''fastB1''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE B2', 'delete from public.kassererstatistikk where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''', 'kassererstatistikk', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "dato" = date ''2026-01-01'' + 14 and "kasserer_nr" = ''fastB2''');
select pg_temp.som_eier();
select pg_temp.nyrad_kassererstatistikk('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('kassererstatistikk tablet_B1 DELETE A1', 'delete from public.kassererstatistikk where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''', 'kassererstatistikk', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "dato" = date ''2026-01-01'' + 10 and "kasserer_nr" = ''fastA1''');

-- =====================================================================
-- konkurranser  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('konkurranser');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('konkurranser owner_A SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser owner_A SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_tillatt('konkurranser owner_A INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AA1'', ''omsetning sonde'', date ''2026-01-01'' + 123, date ''2026-01-01'' + 123 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_A INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AB1'', ''omsetning sonde'', date ''2026-01-01'' + 124, date ''2026-01-01'' + 124 + 30)');
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
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515953-0000-4000-8000-00001c515953', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_AA1', 'omsetning sonde', date '2026-01-01' + 125, date '2026-01-01' + 125 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('konkurranser owner_A DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.skriv_avvist('konkurranser owner_A FLYTTER egen rad -> kjede B', 'update public.konkurranser set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('konkurranser manager_A1 SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 126, date ''2026-01-01'' + 126 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 127, date ''2026-01-01'' + 127 + 30)');
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
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12A1'', ''omsetning sonde'', date ''2026-01-01'' + 128, date ''2026-01-01'' + 128 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12B1'', ''omsetning sonde'', date ''2026-01-01'' + 129, date ''2026-01-01'' + 129 + 30)');
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
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 130, date ''2026-01-01'' + 130 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 131, date ''2026-01-01'' + 131 + 30)');
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
select pg_temp.skriv_tillatt('konkurranser owner_B INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BB1'', ''omsetning sonde'', date ''2026-01-01'' + 132, date ''2026-01-01'' + 132 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_B INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BA1'', ''omsetning sonde'', date ''2026-01-01'' + 133, date ''2026-01-01'' + 133 + 30)');
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
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515972-0000-4000-8000-00001c515972', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_BB1', 'omsetning sonde', date '2026-01-01' + 134, date '2026-01-01' + 134 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('konkurranser owner_B DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.skriv_avvist('konkurranser owner_B FLYTTER egen rad -> kjede A', 'update public.konkurranser set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('konkurranser manager_B1 SELECT B -> ser', exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'positiv');
select pg_temp.paastand('konkurranser manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 135, date ''2026-01-01'' + 135 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 136, date ''2026-01-01'' + 136 + 30)');
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
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 137, date ''2026-01-01'' + 137 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 138, date ''2026-01-01'' + 138 + 30)');
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
-- lenker  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('lenker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('lenker owner_A SELECT A -> ser', exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'positiv');
select pg_temp.paastand('lenker owner_A SELECT B -> ser ikke', not exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'negativ');
select pg_temp.skriv_tillatt('lenker owner_A INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke owner_AA1'', ''https://sonde.local/owner_AA1'')');
select pg_temp.skriv_avvist('lenker owner_A INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke owner_AB1'', ''https://sonde.local/owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lenker owner_A UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('lenker owner_A UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lenker owner_A DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b97-0000-4000-8000-00009d717b97', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke gjenowner_AA1', 'https://sonde.local/gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('lenker owner_A DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.skriv_avvist('lenker owner_A FLYTTER egen rad -> kjede B', 'update public.lenker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('lenker manager_A1 SELECT A -> ser', exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'positiv');
select pg_temp.paastand('lenker manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'negativ');
select pg_temp.skriv_tillatt('lenker manager_A1 INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke manager_A1A1'', ''https://sonde.local/manager_A1A1'')');
select pg_temp.skriv_avvist('lenker manager_A1 INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke manager_A1B1'', ''https://sonde.local/manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('lenker manager_A1 UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lenker manager_A1 UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('lenker manager_A1 DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b97-0000-4000-8000-00009d717b97', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke gjenmanager_A1A1', 'https://sonde.local/gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lenker manager_A1 DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.skriv_avvist('lenker manager_A1 FLYTTER egen rad -> kjede B', 'update public.lenker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('lenker manager_A12 SELECT A -> ser', exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'positiv');
select pg_temp.paastand('lenker manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'negativ');
select pg_temp.skriv_tillatt('lenker manager_A12 INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke manager_A12A1'', ''https://sonde.local/manager_A12A1'')');
select pg_temp.skriv_avvist('lenker manager_A12 INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke manager_A12B1'', ''https://sonde.local/manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('lenker manager_A12 UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lenker manager_A12 UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('lenker manager_A12 DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b97-0000-4000-8000-00009d717b97', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke gjenmanager_A12A1', 'https://sonde.local/gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lenker manager_A12 DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.skriv_avvist('lenker manager_A12 FLYTTER egen rad -> kjede B', 'update public.lenker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('lenker tablet_A1 SELECT A -> ser', exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'positiv');
select pg_temp.paastand('lenker tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'negativ');
select pg_temp.skriv_tillatt('lenker tablet_A1 INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke tablet_A1A1'', ''https://sonde.local/tablet_A1A1'')');
select pg_temp.skriv_avvist('lenker tablet_A1 INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke tablet_A1B1'', ''https://sonde.local/tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('lenker tablet_A1 UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lenker tablet_A1 UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('lenker tablet_A1 DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717b97-0000-4000-8000-00009d717b97', 'aaaa0000-0000-4000-8000-000000000000', 'Sondelenke gjentablet_A1A1', 'https://sonde.local/gjentablet_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lenker tablet_A1 DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');
select pg_temp.skriv_avvist('lenker tablet_A1 FLYTTER egen rad -> kjede B', 'update public.lenker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('lenker owner_B SELECT B -> ser', exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'positiv');
select pg_temp.paastand('lenker owner_B SELECT A -> ser ikke', not exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'negativ');
select pg_temp.skriv_tillatt('lenker owner_B INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke owner_BB1'', ''https://sonde.local/owner_BB1'')');
select pg_temp.skriv_avvist('lenker owner_B INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke owner_BA1'', ''https://sonde.local/owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lenker owner_B UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('lenker owner_B UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lenker owner_B DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717bb6-0000-4000-8000-00009d717bb6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondelenke gjenowner_BB1', 'https://sonde.local/gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('lenker owner_B DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.skriv_avvist('lenker owner_B FLYTTER egen rad -> kjede A', 'update public.lenker set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('lenker manager_B1 SELECT B -> ser', exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'positiv');
select pg_temp.paastand('lenker manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'negativ');
select pg_temp.skriv_tillatt('lenker manager_B1 INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke manager_B1B1'', ''https://sonde.local/manager_B1B1'')');
select pg_temp.skriv_avvist('lenker manager_B1 INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke manager_B1A1'', ''https://sonde.local/manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('lenker manager_B1 UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lenker manager_B1 UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('lenker manager_B1 DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717bb6-0000-4000-8000-00009d717bb6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondelenke gjenmanager_B1B1', 'https://sonde.local/gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lenker manager_B1 DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.skriv_avvist('lenker manager_B1 FLYTTER egen rad -> kjede A', 'update public.lenker set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('lenker tablet_B1 SELECT B -> ser', exists (select 1 from public.lenker where id = '9d717bb6-0000-4000-8000-00009d717bb6'), 'positiv');
select pg_temp.paastand('lenker tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.lenker where id = '9d717b97-0000-4000-8000-00009d717b97'), 'negativ');
select pg_temp.skriv_tillatt('lenker tablet_B1 INSERT B', 'insert into public.lenker (retailer_id, tittel, url) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondelenke tablet_B1B1'', ''https://sonde.local/tablet_B1B1'')');
select pg_temp.skriv_avvist('lenker tablet_B1 INSERT A', 'insert into public.lenker (retailer_id, tittel, url) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondelenke tablet_B1A1'', ''https://sonde.local/tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('lenker tablet_B1 UPDATE B', 'update public.lenker set sortering = 1 where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lenker tablet_B1 UPDATE A', 'update public.lenker set sortering = 1 where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('lenker tablet_B1 DELETE B', 'delete from public.lenker where id = ''9d717bb6-0000-4000-8000-00009d717bb6''');
select pg_temp.som_eier();
insert into public.lenker (id, retailer_id, tittel, url) values ('9d717bb6-0000-4000-8000-00009d717bb6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondelenke gjentablet_B1B1', 'https://sonde.local/gjentablet_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_lenker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lenker tablet_B1 DELETE A', 'delete from public.lenker where id = ''9d717b97-0000-4000-8000-00009d717b97''', 'lenker', '9d717b97-0000-4000-8000-00009d717b97', 'id');
select pg_temp.skriv_avvist('lenker tablet_B1 FLYTTER egen rad -> kjede A', 'update public.lenker set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''9d717bb6-0000-4000-8000-00009d717bb6''', 'lenker', '9d717bb6-0000-4000-8000-00009d717bb6', 'id');

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
select pg_temp.skriv_tillatt('malekort_scope owner_A INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d603e-0000-4000-8000-0000843d603e'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('malekort_scope owner_A INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238de-0000-4000-8000-000085f238de'', ''avdeling'', ''owner_AB1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', '843d6040-0000-4000-8000-0000843d6040', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort_scope owner_A DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_A FLYTTER egen rad -> kjede B', 'update public.malekort_scope set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('malekort_scope manager_A1 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d6041-0000-4000-8000-0000843d6041'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238e1-0000-4000-8000-000085f238e1'', ''avdeling'', ''manager_A1B1'')');
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
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d6043-0000-4000-8000-0000843d6043'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238e3-0000-4000-8000-000085f238e3'', ''avdeling'', ''manager_A12B1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d6045-0000-4000-8000-0000843d6045'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238e5-0000-4000-8000-000085f238e5'', ''avdeling'', ''tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('malekort_scope owner_B INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238fb-0000-4000-8000-000085f238fb'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('malekort_scope owner_B INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d605d-0000-4000-8000-0000843d605d'', ''avdeling'', ''owner_BA1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', '85f238fd-0000-4000-8000-000085f238fd', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort_scope owner_B DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_B FLYTTER egen rad -> kjede A', 'update public.malekort_scope set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('malekort_scope manager_B1 SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f238fe-0000-4000-8000-000085f238fe'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d6060-0000-4000-8000-0000843d6060'', ''avdeling'', ''manager_B1A1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''85f23900-0000-4000-8000-000085f23900'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''843d6062-0000-4000-8000-0000843d6062'', ''avdeling'', ''tablet_B1A1'')');
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
-- merker  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('merker owner_A SELECT A -> ser', exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'positiv');
select pg_temp.paastand('merker owner_A SELECT B -> ser ikke', not exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'negativ');
select pg_temp.skriv_tillatt('merker owner_A INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke owner_AA1'')');
select pg_temp.skriv_avvist('merker owner_A INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('merker owner_A UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('merker owner_A UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('merker owner_A DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
insert into public.merker (id, retailer_id, navn) values ('9e15dab2-0000-4000-8000-00009e15dab2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('merker owner_A DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.skriv_avvist('merker owner_A FLYTTER egen rad -> kjede B', 'update public.merker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('merker manager_A1 SELECT A -> ser', exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'positiv');
select pg_temp.paastand('merker manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'negativ');
select pg_temp.skriv_tillatt('merker manager_A1 INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke manager_A1A1'')');
select pg_temp.skriv_avvist('merker manager_A1 INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('merker manager_A1 UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('merker manager_A1 UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('merker manager_A1 DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
insert into public.merker (id, retailer_id, navn) values ('9e15dab2-0000-4000-8000-00009e15dab2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('merker manager_A1 DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.skriv_avvist('merker manager_A1 FLYTTER egen rad -> kjede B', 'update public.merker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('merker manager_A12 SELECT A -> ser', exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'positiv');
select pg_temp.paastand('merker manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'negativ');
select pg_temp.skriv_tillatt('merker manager_A12 INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke manager_A12A1'')');
select pg_temp.skriv_avvist('merker manager_A12 INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('merker manager_A12 UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('merker manager_A12 UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('merker manager_A12 DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''');
select pg_temp.som_eier();
insert into public.merker (id, retailer_id, navn) values ('9e15dab2-0000-4000-8000-00009e15dab2', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('merker manager_A12 DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.skriv_avvist('merker manager_A12 FLYTTER egen rad -> kjede B', 'update public.merker set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('merker tablet_A1 SELECT A -> ser', exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'positiv');
select pg_temp.paastand('merker tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'negativ');
select pg_temp.skriv_avvist('merker tablet_A1 INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke tablet_A1A1'')');
select pg_temp.skriv_avvist('merker tablet_A1 INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('merker tablet_A1 UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('merker tablet_A1 UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('merker tablet_A1 DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('merker tablet_A1 DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('merker owner_B SELECT B -> ser', exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'positiv');
select pg_temp.paastand('merker owner_B SELECT A -> ser ikke', not exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'negativ');
select pg_temp.skriv_tillatt('merker owner_B INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke owner_BB1'')');
select pg_temp.skriv_avvist('merker owner_B INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('merker owner_B UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('merker owner_B UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('merker owner_B DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''');
select pg_temp.som_eier();
insert into public.merker (id, retailer_id, navn) values ('9e15dad1-0000-4000-8000-00009e15dad1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('merker owner_B DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.skriv_avvist('merker owner_B FLYTTER egen rad -> kjede A', 'update public.merker set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('merker manager_B1 SELECT B -> ser', exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'positiv');
select pg_temp.paastand('merker manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'negativ');
select pg_temp.skriv_tillatt('merker manager_B1 INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke manager_B1B1'')');
select pg_temp.skriv_avvist('merker manager_B1 INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('merker manager_B1 UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('merker manager_B1 UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('merker manager_B1 DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''');
select pg_temp.som_eier();
insert into public.merker (id, retailer_id, navn) values ('9e15dad1-0000-4000-8000-00009e15dad1', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('merker manager_B1 DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.skriv_avvist('merker manager_B1 FLYTTER egen rad -> kjede A', 'update public.merker set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('merker tablet_B1 SELECT B -> ser', exists (select 1 from public.merker where id = '9e15dad1-0000-4000-8000-00009e15dad1'), 'positiv');
select pg_temp.paastand('merker tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.merker where id = '9e15dab2-0000-4000-8000-00009e15dab2'), 'negativ');
select pg_temp.skriv_avvist('merker tablet_B1 INSERT B', 'insert into public.merker (retailer_id, navn) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondemerke tablet_B1B1'')');
select pg_temp.skriv_avvist('merker tablet_B1 INSERT A', 'insert into public.merker (retailer_id, navn) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondemerke tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('merker tablet_B1 UPDATE B', 'update public.merker set sortering = 1 where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('merker tablet_B1 UPDATE A', 'update public.merker set sortering = 1 where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('merker tablet_B1 DELETE B', 'delete from public.merker where id = ''9e15dad1-0000-4000-8000-00009e15dad1''', 'merker', '9e15dad1-0000-4000-8000-00009e15dad1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('merker tablet_B1 DELETE A', 'delete from public.merker where id = ''9e15dab2-0000-4000-8000-00009e15dab2''', 'merker', '9e15dab2-0000-4000-8000-00009e15dab2', 'id');

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
