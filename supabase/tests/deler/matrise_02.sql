-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 2 AV 4. Hele matrisen er for stor for Supabase SQL
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

create or replace function pg_temp.skriv_avvist(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_id uuid default null, p_maal_kol text default 'id'
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
  elsif not pg_temp.finnes(p_maal_tabell, p_maal_id, p_maal_kol) then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men maalraden ' || p_maal_id || ' finnes ikke i ' || p_maal_tabell
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
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8f4dfe-0000-4000-8000-00009e8f4dfe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e8fc25e-0000-4000-8000-00009e8fc25e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9036be-0000-4000-8000-00009e9036be', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9d6582-0000-4000-8000-00009e9d6582', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('9e9dd9e2-0000-4000-8000-00009e9dd9e2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.merker (id, retailer_id, navn) values ('7589c146-0000-4000-8000-00007589c146', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 15');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c48ae91-0000-4000-8000-00004c48ae91', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-15');
insert into public.merker (id, retailer_id, navn) values ('758a35a6-0000-4000-8000-0000758a35a6', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 16');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c4922f1-0000-4000-8000-00004c4922f1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-16');
insert into public.merker (id, retailer_id, navn) values ('758aaa06-0000-4000-8000-0000758aaa06', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 17');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c499751-0000-4000-8000-00004c499751', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-17');
insert into public.merker (id, retailer_id, navn) values ('7597d8ca-0000-4000-8000-00007597d8ca', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 18');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c56c615-0000-4000-8000-00004c56c615', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-18');
insert into public.merker (id, retailer_id, navn) values ('75984d2a-0000-4000-8000-000075984d2a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 19');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('4c573a75-0000-4000-8000-00004c573a75', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-19');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a99e468-0000-4000-8000-00001a99e468', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9a58c8-0000-4000-8000-00001a9a58c8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1a9acd28-0000-4000-8000-00001a9acd28', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa7fbec-0000-4000-8000-00001aa7fbec', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('1aa8704c-0000-4000-8000-00001aa8704c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a71fa-0000-4000-8000-0000335a71fa', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3368897c-0000-4000-8000-00003368897c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a113-0000-4000-8000-00003376a113', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ab1-0000-4000-8000-0000350f4ab1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7213-0000-4000-8000-0000335a7213', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688995-0000-4000-8000-000033688995', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a117-0000-4000-8000-00003376a117', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7216-0000-4000-8000-0000335a7216', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('33688998-0000-4000-8000-000033688998', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a11a-0000-4000-8000-00003376a11a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ab8-0000-4000-8000-0000350f4ab8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a721a-0000-4000-8000-0000335a721a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7230-0000-4000-8000-0000335a7230', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('336889b2-0000-4000-8000-0000336889b2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a134-0000-4000-8000-00003376a134', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ad2-0000-4000-8000-0000350f4ad2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7234-0000-4000-8000-0000335a7234', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('336889b6-0000-4000-8000-0000336889b6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7236-0000-4000-8000-0000335a7236', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('336889b8-0000-4000-8000-0000336889b8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('3376a13a-0000-4000-8000-00003376a13a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4ad8-0000-4000-8000-0000350f4ad8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a724f-0000-4000-8000-0000335a724f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4aef-0000-4000-8000-0000350f4aef', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6271-0000-4000-8000-0000351d6271', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7252-0000-4000-8000-0000335a7252', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4af2-0000-4000-8000-0000350f4af2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6274-0000-4000-8000-0000351d6274', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4af4-0000-4000-8000-0000350f4af4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d6276-0000-4000-8000-0000351d6276', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7257-0000-4000-8000-0000335a7257', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4af7-0000-4000-8000-0000350f4af7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4b0d-0000-4000-8000-0000350f4b0d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('351d628f-0000-4000-8000-0000351d628f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('335a7270-0000-4000-8000-0000335a7270', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values ('350f4b10-0000-4000-8000-0000350f4b10', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondesporsmaal');
insert into public.merker (id, retailer_id, navn) values ('3bae678f-0000-4000-8000-00003bae678f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 144');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23a4-0000-4000-8000-00003ccd23a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-144');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f11-0000-4000-8000-00003bbc7f11', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 145');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b26-0000-4000-8000-00003cdb3b26', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-145');
insert into public.merker (id, retailer_id, navn) values ('3bca9693-0000-4000-8000-00003bca9693', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 146');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ce952a8-0000-4000-8000-00003ce952a8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-146');
insert into public.merker (id, retailer_id, navn) values ('3d634031-0000-4000-8000-00003d634031', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 147');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc46-0000-4000-8000-00003e81fc46', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-147');
insert into public.merker (id, retailer_id, navn) values ('3bae6793-0000-4000-8000-00003bae6793', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 148');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23a8-0000-4000-8000-00003ccd23a8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-148');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f15-0000-4000-8000-00003bbc7f15', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 149');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b2a-0000-4000-8000-00003cdb3b2a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-149');
insert into public.merker (id, retailer_id, navn) values ('3bca96ac-0000-4000-8000-00003bca96ac', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 150');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ce952c1-0000-4000-8000-00003ce952c1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-150');
insert into public.merker (id, retailer_id, navn) values ('3bae67ab-0000-4000-8000-00003bae67ab', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 151');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23c0-0000-4000-8000-00003ccd23c0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-151');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f2d-0000-4000-8000-00003bbc7f2d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 152');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b42-0000-4000-8000-00003cdb3b42', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-152');
insert into public.merker (id, retailer_id, navn) values ('3bca96af-0000-4000-8000-00003bca96af', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 153');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ce952c4-0000-4000-8000-00003ce952c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-153');
insert into public.merker (id, retailer_id, navn) values ('3d63404d-0000-4000-8000-00003d63404d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 154');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc62-0000-4000-8000-00003e81fc62', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-154');
insert into public.merker (id, retailer_id, navn) values ('3bae67af-0000-4000-8000-00003bae67af', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 155');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23c4-0000-4000-8000-00003ccd23c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-155');
insert into public.merker (id, retailer_id, navn) values ('3bae67b0-0000-4000-8000-00003bae67b0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 156');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23c5-0000-4000-8000-00003ccd23c5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-156');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f32-0000-4000-8000-00003bbc7f32', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 157');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b47-0000-4000-8000-00003cdb3b47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-157');
insert into public.merker (id, retailer_id, navn) values ('3bca96b4-0000-4000-8000-00003bca96b4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 158');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ce952c9-0000-4000-8000-00003ce952c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-158');
insert into public.merker (id, retailer_id, navn) values ('3d634052-0000-4000-8000-00003d634052', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 159');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc67-0000-4000-8000-00003e81fc67', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-159');
insert into public.merker (id, retailer_id, navn) values ('3bae67c9-0000-4000-8000-00003bae67c9', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 160');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23de-0000-4000-8000-00003ccd23de', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-160');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f4b-0000-4000-8000-00003bbc7f4b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 161');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b60-0000-4000-8000-00003cdb3b60', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-161');
insert into public.merker (id, retailer_id, navn) values ('3bae67cb-0000-4000-8000-00003bae67cb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 162');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23e0-0000-4000-8000-00003ccd23e0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-162');
insert into public.merker (id, retailer_id, navn) values ('3bbc7f4d-0000-4000-8000-00003bbc7f4d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 163');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3cdb3b62-0000-4000-8000-00003cdb3b62', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-163');
insert into public.merker (id, retailer_id, navn) values ('3bca96cf-0000-4000-8000-00003bca96cf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 164');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ce952e4-0000-4000-8000-00003ce952e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondeansatt', 'pin-merke-164');
insert into public.merker (id, retailer_id, navn) values ('3d63406d-0000-4000-8000-00003d63406d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 165');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc82-0000-4000-8000-00003e81fc82', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-165');
insert into public.merker (id, retailer_id, navn) values ('3d63406e-0000-4000-8000-00003d63406e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 166');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc83-0000-4000-8000-00003e81fc83', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-166');
insert into public.merker (id, retailer_id, navn) values ('3d7157f0-0000-4000-8000-00003d7157f0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 167');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e901405-0000-4000-8000-00003e901405', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-167');
insert into public.merker (id, retailer_id, navn) values ('3bae67d1-0000-4000-8000-00003bae67d1', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 168');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd23e6-0000-4000-8000-00003ccd23e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-168');
insert into public.merker (id, retailer_id, navn) values ('3d634071-0000-4000-8000-00003d634071', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 169');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc86-0000-4000-8000-00003e81fc86', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-169');
insert into public.merker (id, retailer_id, navn) values ('3d715808-0000-4000-8000-00003d715808', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 170');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e90141d-0000-4000-8000-00003e90141d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-170');
insert into public.merker (id, retailer_id, navn) values ('3d634088-0000-4000-8000-00003d634088', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 171');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fc9d-0000-4000-8000-00003e81fc9d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-171');
insert into public.merker (id, retailer_id, navn) values ('3d71580a-0000-4000-8000-00003d71580a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 172');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e90141f-0000-4000-8000-00003e90141f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-172');
insert into public.merker (id, retailer_id, navn) values ('3bae67eb-0000-4000-8000-00003bae67eb', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 173');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd2400-0000-4000-8000-00003ccd2400', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-173');
insert into public.merker (id, retailer_id, navn) values ('3d63408b-0000-4000-8000-00003d63408b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 174');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fca0-0000-4000-8000-00003e81fca0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-174');
insert into public.merker (id, retailer_id, navn) values ('3d63408c-0000-4000-8000-00003d63408c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 175');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e81fca1-0000-4000-8000-00003e81fca1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-175');
insert into public.merker (id, retailer_id, navn) values ('3d71580e-0000-4000-8000-00003d71580e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondemerke 176');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3e901423-0000-4000-8000-00003e901423', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondeansatt', 'pin-merke-176');
insert into public.merker (id, retailer_id, navn) values ('3bae67ef-0000-4000-8000-00003bae67ef', 'aaaa0000-0000-4000-8000-000000000000', 'Sondemerke 177');
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash) values ('3ccd2404-0000-4000-8000-00003ccd2404', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondeansatt', 'pin-merke-177');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a5e8-0000-4000-8000-000038a2a5e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bd6a-0000-4000-8000-000038b0bd6a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed501-0000-4000-8000-000038bed501', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577e9f-0000-4000-8000-00003a577e9f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a601-0000-4000-8000-000038a2a601', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bd83-0000-4000-8000-000038b0bd83', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed505-0000-4000-8000-000038bed505', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577ea3-0000-4000-8000-00003a577ea3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a605-0000-4000-8000-000038a2a605', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bd87-0000-4000-8000-000038b0bd87', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed509-0000-4000-8000-000038bed509', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577ea7-0000-4000-8000-00003a577ea7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a61e-0000-4000-8000-000038a2a61e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38b0bda0-0000-4000-8000-000038b0bda0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38bed522-0000-4000-8000-000038bed522', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577ec0-0000-4000-8000-00003a577ec0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577ec1-0000-4000-8000-00003a577ec1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659643-0000-4000-8000-00003a659643', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a624-0000-4000-8000-000038a2a624', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a577ec4-0000-4000-8000-00003a577ec4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a659646-0000-4000-8000-00003a659646', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a627-0000-4000-8000-000038a2a627', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a578167-0000-4000-8000-00003a578167', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('3a6598e9-0000-4000-8000-00003a6598e9', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepunkt');
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn) values ('38a2a8ca-0000-4000-8000-000038a2a8ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepunkt');
-- --- rutiner: forutsetninger og proberader ---
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine fastA1');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine fastA2');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62219-0000-4000-8000-000023d62219', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine fastA3');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine fastB1');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62237-0000-4000-8000-000023d62237', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine fastB2');

create or replace function pg_temp.nyrad_rutiner(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.rutiner (retailer_id, stasjon_id, tittel)
  values (p_retailer, p_stasjon, 'Sonderutine ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
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
-- --- sjekkpunkt_svar: forutsetninger og proberader ---
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '9e8f4dfe-0000-4000-8000-00009e8f4dfe', date '2026-01-01' + 10, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '9e8fc25e-0000-4000-8000-00009e8fc25e', date '2026-01-01' + 11, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '9e9036be-0000-4000-8000-00009e9036be', date '2026-01-01' + 12, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '9e9d6582-0000-4000-8000-00009e9d6582', date '2026-01-01' + 13, true);
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '9e9dd9e2-0000-4000-8000-00009e9dd9e2', date '2026-01-01' + 14, true);

create or replace function pg_temp.nyrad_sjekkpunkt_svar(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_sjekkpunkt uuid := gen_random_uuid();
begin
  insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal) values (v_sjekkpunkt, p_retailer, p_stasjon, 'Sondesporsmaal');
  insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar)
  values (p_stasjon, v_sjekkpunkt, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, true)
  returning id into ny;
  return ny;
end $fn$;
-- --- tildelte_merker: forutsetninger og proberader ---
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '7589c146-0000-4000-8000-00007589c146', '4c48ae91-0000-4000-8000-00004c48ae91', date '2026-01-01' + 15);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '758a35a6-0000-4000-8000-0000758a35a6', '4c4922f1-0000-4000-8000-00004c4922f1', date '2026-01-01' + 16);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '758aaa06-0000-4000-8000-0000758aaa06', '4c499751-0000-4000-8000-00004c499751', date '2026-01-01' + 17);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '7597d8ca-0000-4000-8000-00007597d8ca', '4c56c615-0000-4000-8000-00004c56c615', date '2026-01-01' + 18);
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '75984d2a-0000-4000-8000-000075984d2a', '4c573a75-0000-4000-8000-00004c573a75', date '2026-01-01' + 19);

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
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443d-0000-4000-8000-00001a11443d', 'a1110000-0000-4000-8000-000000000001', '1a99e468-0000-4000-8000-00001a99e468', date '2026-01-01' + 20, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443e-0000-4000-8000-00001a11443e', 'a1110000-0000-4000-8000-000000000002', '1a9a58c8-0000-4000-8000-00001a9a58c8', date '2026-01-01' + 21, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11443f-0000-4000-8000-00001a11443f', 'a1110000-0000-4000-8000-000000000003', '1a9acd28-0000-4000-8000-00001a9acd28', date '2026-01-01' + 22, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445c-0000-4000-8000-00001a11445c', 'b1110000-0000-4000-8000-000000000001', '1aa7fbec-0000-4000-8000-00001aa7fbec', date '2026-01-01' + 23, 4.0, true);
insert into public.ik_avlesninger (id, stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values ('1a11445d-0000-4000-8000-00001a11445d', 'b1110000-0000-4000-8000-000000000002', '1aa8704c-0000-4000-8000-00001aa8704c', date '2026-01-01' + 24, 4.0, true);

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

-- =====================================================================
-- rutiner  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutiner');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutiner owner_A SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT A2 -> ser', exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT A3 -> ser', exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'positiv');
select pg_temp.paastand('rutiner owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_AA1'')');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine owner_AA2'')');
select pg_temp.skriv_tillatt('rutiner owner_A INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine owner_AA3'')');
select pg_temp.skriv_avvist('rutiner owner_A INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutiner owner_A UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutiner owner_A DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62219-0000-4000-8000-000023d62219', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutiner owner_A DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner owner_A FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutiner manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'negativ');
select pg_temp.paastand('rutiner manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_A1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A1A1'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_A1A2'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine manager_A1A3'')');
select pg_temp.skriv_avvist('rutiner manager_A1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutiner manager_A1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutiner manager_A1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutiner manager_A1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutiner set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_A1 FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutiner manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'positiv');
select pg_temp.paastand('rutiner manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_A12 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A12A1'')');
select pg_temp.skriv_tillatt('rutiner manager_A12 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_A12A2'')');
select pg_temp.skriv_avvist('rutiner manager_A12 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine manager_A12A3'')');
select pg_temp.skriv_avvist('rutiner manager_A12 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62217-0000-4000-8000-000023d62217', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutiner manager_A12 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62218-0000-4000-8000-000023d62218', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutiner manager_A12 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutiner set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_A12 FLYTTER egen rad -> kjede B', 'update public.rutiner set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutiner tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'positiv');
select pg_temp.paastand('rutiner tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62218-0000-4000-8000-000023d62218'), 'negativ');
select pg_temp.paastand('rutiner tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62219-0000-4000-8000-000023d62219'), 'negativ');
select pg_temp.paastand('rutiner tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'negativ');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_A1A1'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sonderutine tablet_A1A2'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT A3', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sonderutine tablet_A1A3'')');
select pg_temp.skriv_avvist('rutiner tablet_A1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE A3', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A2', 'delete from public.rutiner where id = ''23d62218-0000-4000-8000-000023d62218''', 'rutiner', '23d62218-0000-4000-8000-000023d62218', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE A3', 'delete from public.rutiner where id = ''23d62219-0000-4000-8000-000023d62219''', 'rutiner', '23d62219-0000-4000-8000-000023d62219', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutiner tablet_A1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutiner owner_B SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner owner_B SELECT B2 -> ser', exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'positiv');
select pg_temp.paastand('rutiner owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_tillatt('rutiner owner_B INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_BB1'')');
select pg_temp.skriv_tillatt('rutiner owner_B INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine owner_BB2'')');
select pg_temp.skriv_avvist('rutiner owner_B INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutiner owner_B UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutiner owner_B DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62237-0000-4000-8000-000023d62237', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutiner owner_B DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner owner_B FLYTTER egen rad -> kjede A', 'update public.rutiner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutiner manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'negativ');
select pg_temp.paastand('rutiner manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_tillatt('rutiner manager_B1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_B1B1'')');
select pg_temp.skriv_avvist('rutiner manager_B1 INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine manager_B1B2'')');
select pg_temp.skriv_avvist('rutiner manager_B1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutiner manager_B1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutiner manager_B1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''');
select pg_temp.som_eier();
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('23d62236-0000-4000-8000-000023d62236', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutiner manager_B1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.skriv_avvist('rutiner manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutiner set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.skriv_avvist('rutiner manager_B1 FLYTTER egen rad -> kjede A', 'update public.rutiner set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutiner tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutiner where id = '23d62236-0000-4000-8000-000023d62236'), 'positiv');
select pg_temp.paastand('rutiner tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62237-0000-4000-8000-000023d62237'), 'negativ');
select pg_temp.paastand('rutiner tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutiner where id = '23d62217-0000-4000-8000-000023d62217'), 'negativ');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT B1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_B1B1'')');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT B2', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sonderutine tablet_B1B2'')');
select pg_temp.skriv_avvist('rutiner tablet_B1 INSERT A1', 'insert into public.rutiner (retailer_id, stasjon_id, tittel) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sonderutine tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE B1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE B2', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 UPDATE A1', 'update public.rutiner set beskrivelse = ''endret av sonden'' where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE B1', 'delete from public.rutiner where id = ''23d62236-0000-4000-8000-000023d62236''', 'rutiner', '23d62236-0000-4000-8000-000023d62236', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE B2', 'delete from public.rutiner where id = ''23d62237-0000-4000-8000-000023d62237''', 'rutiner', '23d62237-0000-4000-8000-000023d62237', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutiner('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutiner tablet_B1 DELETE A1', 'delete from public.rutiner where id = ''23d62217-0000-4000-8000-000023d62217''', 'rutiner', '23d62217-0000-4000-8000-000023d62217', 'id');

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
-- sjekkpunkt_svar  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('sjekkpunkt_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT A3 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a71fa-0000-4000-8000-0000335a71fa'', date ''2026-01-01'' + 108, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''3368897c-0000-4000-8000-00003368897c'', date ''2026-01-01'' + 109, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a113-0000-4000-8000-00003376a113'', date ''2026-01-01'' + 110, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ab1-0000-4000-8000-0000350f4ab1'', date ''2026-01-01'' + 111, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7213-0000-4000-8000-0000335a7213', date '2026-01-01' + 112, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '33688995-0000-4000-8000-000033688995', date '2026-01-01' + 113, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_A DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275885-0000-4000-8000-0000f0275885', 'a1110000-0000-4000-8000-000000000003', '3376a117-0000-4000-8000-00003376a117', date '2026-01-01' + 114, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_A DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7216-0000-4000-8000-0000335a7216'', date ''2026-01-01'' + 115, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''33688998-0000-4000-8000-000033688998'', date ''2026-01-01'' + 116, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a11a-0000-4000-8000-00003376a11a'', date ''2026-01-01'' + 117, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ab8-0000-4000-8000-0000350f4ab8'', date ''2026-01-01'' + 118, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a721a-0000-4000-8000-0000335a721a', date '2026-01-01' + 119, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A1 FLYTTER egen rad A1 -> A2', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7230-0000-4000-8000-0000335a7230'', date ''2026-01-01'' + 120, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''336889b2-0000-4000-8000-0000336889b2'', date ''2026-01-01'' + 121, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a134-0000-4000-8000-00003376a134'', date ''2026-01-01'' + 122, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ad2-0000-4000-8000-0000350f4ad2'', date ''2026-01-01'' + 123, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a7234-0000-4000-8000-0000335a7234', date '2026-01-01' + 124, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_A12 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275884-0000-4000-8000-0000f0275884', 'a1110000-0000-4000-8000-000000000002', '336889b6-0000-4000-8000-0000336889b6', date '2026-01-01' + 125, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_A12 FLYTTER egen rad A1 -> A3', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275884-0000-4000-8000-0000f0275884'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275885-0000-4000-8000-0000f0275885'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7236-0000-4000-8000-0000335a7236'', date ''2026-01-01'' + 126, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000002'', ''336889b8-0000-4000-8000-0000336889b8'', date ''2026-01-01'' + 127, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT A3', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000003'', ''3376a13a-0000-4000-8000-00003376a13a'', date ''2026-01-01'' + 128, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4ad8-0000-4000-8000-0000350f4ad8'', date ''2026-01-01'' + 129, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE A2', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE A3', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_A1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f0275883-0000-4000-8000-0000f0275883', 'a1110000-0000-4000-8000-000000000001', '335a724f-0000-4000-8000-0000335a724f', date '2026-01-01' + 130, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE A2', 'delete from public.sjekkpunkt_svar where id = ''f0275884-0000-4000-8000-0000f0275884''', 'sjekkpunkt_svar', 'f0275884-0000-4000-8000-0000f0275884', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE A3', 'delete from public.sjekkpunkt_svar where id = ''f0275885-0000-4000-8000-0000f0275885''', 'sjekkpunkt_svar', 'f0275885-0000-4000-8000-0000f0275885', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.sjekkpunkt_svar set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT B2 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4aef-0000-4000-8000-0000350f4aef'', date ''2026-01-01'' + 131, true)');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6271-0000-4000-8000-0000351d6271'', date ''2026-01-01'' + 132, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7252-0000-4000-8000-0000335a7252'', date ''2026-01-01'' + 133, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4af2-0000-4000-8000-0000350f4af2', date '2026-01-01' + 134, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('sjekkpunkt_svar owner_B DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a3-0000-4000-8000-0000f02758a3', 'b1110000-0000-4000-8000-000000000002', '351d6274-0000-4000-8000-0000351d6274', date '2026-01-01' + 135, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('sjekkpunkt_svar owner_B DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4af4-0000-4000-8000-0000350f4af4'', date ''2026-01-01'' + 136, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d6276-0000-4000-8000-0000351d6276'', date ''2026-01-01'' + 137, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7257-0000-4000-8000-0000335a7257'', date ''2026-01-01'' + 138, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('sjekkpunkt_svar manager_B1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4af7-0000-4000-8000-0000350f4af7', date '2026-01-01' + 139, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar manager_B1 FLYTTER egen rad B1 -> B2', 'update public.sjekkpunkt_svar set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT B1 -> ser', exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a2-0000-4000-8000-0000f02758a2'), 'positiv');
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f02758a3-0000-4000-8000-0000f02758a3'), 'negativ');
select pg_temp.paastand('sjekkpunkt_svar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.sjekkpunkt_svar where id = 'f0275883-0000-4000-8000-0000f0275883'), 'negativ');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 INSERT B1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000001'', ''350f4b0d-0000-4000-8000-0000350f4b0d'', date ''2026-01-01'' + 140, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT B2', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''b1110000-0000-4000-8000-000000000002'', ''351d628f-0000-4000-8000-0000351d628f'', date ''2026-01-01'' + 141, true)');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 INSERT A1', 'insert into public.sjekkpunkt_svar (stasjon_id, sjekkpunkt_id, dato, svar) values (''a1110000-0000-4000-8000-000000000001'', ''335a7270-0000-4000-8000-0000335a7270'', date ''2026-01-01'' + 142, true)');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 UPDATE B1', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 UPDATE B2', 'update public.sjekkpunkt_svar set svar = false where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 UPDATE A1', 'update public.sjekkpunkt_svar set svar = false where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('sjekkpunkt_svar tablet_B1 DELETE B1', 'delete from public.sjekkpunkt_svar where id = ''f02758a2-0000-4000-8000-0000f02758a2''');
select pg_temp.som_eier();
insert into public.sjekkpunkt_svar (id, stasjon_id, sjekkpunkt_id, dato, svar) values ('f02758a2-0000-4000-8000-0000f02758a2', 'b1110000-0000-4000-8000-000000000001', '350f4b10-0000-4000-8000-0000350f4b10', date '2026-01-01' + 143, true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 DELETE B2', 'delete from public.sjekkpunkt_svar where id = ''f02758a3-0000-4000-8000-0000f02758a3''', 'sjekkpunkt_svar', 'f02758a3-0000-4000-8000-0000f02758a3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_sjekkpunkt_svar('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 DELETE A1', 'delete from public.sjekkpunkt_svar where id = ''f0275883-0000-4000-8000-0000f0275883''', 'sjekkpunkt_svar', 'f0275883-0000-4000-8000-0000f0275883', 'id');
select pg_temp.skriv_avvist('sjekkpunkt_svar tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.sjekkpunkt_svar set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f02758a2-0000-4000-8000-0000f02758a2''', 'sjekkpunkt_svar', 'f02758a2-0000-4000-8000-0000f02758a2', 'id');

-- =====================================================================
-- tildelte_merker  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tildelte_merker');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tildelte_merker owner_A SELECT A1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A2 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacad-0000-4000-8000-00002addacad'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT A3 -> ser', exists (select 1 from public.tildelte_merker where id = '2addacae-0000-4000-8000-00002addacae'), 'positiv');
select pg_temp.paastand('tildelte_merker owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae678f-0000-4000-8000-00003bae678f'', ''3ccd23a4-0000-4000-8000-00003ccd23a4'', date ''2026-01-01'' + 144)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f11-0000-4000-8000-00003bbc7f11'', ''3cdb3b26-0000-4000-8000-00003cdb3b26'', date ''2026-01-01'' + 145)');
select pg_temp.skriv_tillatt('tildelte_merker owner_A INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca9693-0000-4000-8000-00003bca9693'', ''3ce952a8-0000-4000-8000-00003ce952a8'', date ''2026-01-01'' + 146)');
select pg_temp.skriv_avvist('tildelte_merker owner_A INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634031-0000-4000-8000-00003d634031'', ''3e81fc46-0000-4000-8000-00003e81fc46'', date ''2026-01-01'' + 147)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae6793-0000-4000-8000-00003bae6793', '3ccd23a8-0000-4000-8000-00003ccd23a8', date '2026-01-01' + 148);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc7f15-0000-4000-8000-00003bbc7f15', '3cdb3b2a-0000-4000-8000-00003cdb3b2a', date '2026-01-01' + 149);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tildelte_merker owner_A DELETE A3', 'delete from public.tildelte_merker where id = ''2addacae-0000-4000-8000-00002addacae''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacae-0000-4000-8000-00002addacae', 'a1110000-0000-4000-8000-000000000003', '3bca96ac-0000-4000-8000-00003bca96ac', '3ce952c1-0000-4000-8000-00003ce952c1', date '2026-01-01' + 150);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67ab-0000-4000-8000-00003bae67ab'', ''3ccd23c0-0000-4000-8000-00003ccd23c0'', date ''2026-01-01'' + 151)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f2d-0000-4000-8000-00003bbc7f2d'', ''3cdb3b42-0000-4000-8000-00003cdb3b42'', date ''2026-01-01'' + 152)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96af-0000-4000-8000-00003bca96af'', ''3ce952c4-0000-4000-8000-00003ce952c4'', date ''2026-01-01'' + 153)');
select pg_temp.skriv_avvist('tildelte_merker manager_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63404d-0000-4000-8000-00003d63404d'', ''3e81fc62-0000-4000-8000-00003e81fc62'', date ''2026-01-01'' + 154)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae67af-0000-4000-8000-00003bae67af', '3ccd23c4-0000-4000-8000-00003ccd23c4', date '2026-01-01' + 155);
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
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67b0-0000-4000-8000-00003bae67b0'', ''3ccd23c5-0000-4000-8000-00003ccd23c5'', date ''2026-01-01'' + 156)');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f32-0000-4000-8000-00003bbc7f32'', ''3cdb3b47-0000-4000-8000-00003cdb3b47'', date ''2026-01-01'' + 157)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96b4-0000-4000-8000-00003bca96b4'', ''3ce952c9-0000-4000-8000-00003ce952c9'', date ''2026-01-01'' + 158)');
select pg_temp.skriv_avvist('tildelte_merker manager_A12 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634052-0000-4000-8000-00003d634052'', ''3e81fc67-0000-4000-8000-00003e81fc67'', date ''2026-01-01'' + 159)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacac-0000-4000-8000-00002addacac', 'a1110000-0000-4000-8000-000000000001', '3bae67c9-0000-4000-8000-00003bae67c9', '3ccd23de-0000-4000-8000-00003ccd23de', date '2026-01-01' + 160);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tildelte_merker manager_A12 DELETE A2', 'delete from public.tildelte_merker where id = ''2addacad-0000-4000-8000-00002addacad''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addacad-0000-4000-8000-00002addacad', 'a1110000-0000-4000-8000-000000000002', '3bbc7f4b-0000-4000-8000-00003bbc7f4b', '3cdb3b60-0000-4000-8000-00003cdb3b60', date '2026-01-01' + 161);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67cb-0000-4000-8000-00003bae67cb'', ''3ccd23e0-0000-4000-8000-00003ccd23e0'', date ''2026-01-01'' + 162)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000002'', ''3bbc7f4d-0000-4000-8000-00003bbc7f4d'', ''3cdb3b62-0000-4000-8000-00003cdb3b62'', date ''2026-01-01'' + 163)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT A3', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000003'', ''3bca96cf-0000-4000-8000-00003bca96cf'', ''3ce952e4-0000-4000-8000-00003ce952e4'', date ''2026-01-01'' + 164)');
select pg_temp.skriv_avvist('tildelte_merker tablet_A1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63406d-0000-4000-8000-00003d63406d'', ''3e81fc82-0000-4000-8000-00003e81fc82'', date ''2026-01-01'' + 165)');
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
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63406e-0000-4000-8000-00003d63406e'', ''3e81fc83-0000-4000-8000-00003e81fc83'', date ''2026-01-01'' + 166)');
select pg_temp.skriv_tillatt('tildelte_merker owner_B INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d7157f0-0000-4000-8000-00003d7157f0'', ''3e901405-0000-4000-8000-00003e901405'', date ''2026-01-01'' + 167)');
select pg_temp.skriv_avvist('tildelte_merker owner_B INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67d1-0000-4000-8000-00003bae67d1'', ''3ccd23e6-0000-4000-8000-00003ccd23e6'', date ''2026-01-01'' + 168)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d634071-0000-4000-8000-00003d634071', '3e81fc86-0000-4000-8000-00003e81fc86', date '2026-01-01' + 169);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tildelte_merker owner_B DELETE B2', 'delete from public.tildelte_merker where id = ''2addaccc-0000-4000-8000-00002addaccc''');
select pg_temp.som_eier();
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccc-0000-4000-8000-00002addaccc', 'b1110000-0000-4000-8000-000000000002', '3d715808-0000-4000-8000-00003d715808', '3e90141d-0000-4000-8000-00003e90141d', date '2026-01-01' + 170);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_tildelte_merker('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tildelte_merker owner_B DELETE A1', 'delete from public.tildelte_merker where id = ''2addacac-0000-4000-8000-00002addacac''', 'tildelte_merker', '2addacac-0000-4000-8000-00002addacac', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B1 -> ser', exists (select 1 from public.tildelte_merker where id = '2addaccb-0000-4000-8000-00002addaccb'), 'positiv');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addaccc-0000-4000-8000-00002addaccc'), 'negativ');
select pg_temp.paastand('tildelte_merker manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tildelte_merker where id = '2addacac-0000-4000-8000-00002addacac'), 'negativ');
select pg_temp.skriv_tillatt('tildelte_merker manager_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d634088-0000-4000-8000-00003d634088'', ''3e81fc9d-0000-4000-8000-00003e81fc9d'', date ''2026-01-01'' + 171)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d71580a-0000-4000-8000-00003d71580a'', ''3e90141f-0000-4000-8000-00003e90141f'', date ''2026-01-01'' + 172)');
select pg_temp.skriv_avvist('tildelte_merker manager_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67eb-0000-4000-8000-00003bae67eb'', ''3ccd2400-0000-4000-8000-00003ccd2400'', date ''2026-01-01'' + 173)');
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
insert into public.tildelte_merker (id, stasjon_id, merke_id, ansatt_id, tildelt_dato) values ('2addaccb-0000-4000-8000-00002addaccb', 'b1110000-0000-4000-8000-000000000001', '3d63408b-0000-4000-8000-00003d63408b', '3e81fca0-0000-4000-8000-00003e81fca0', date '2026-01-01' + 174);
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
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000001'', ''3d63408c-0000-4000-8000-00003d63408c'', ''3e81fca1-0000-4000-8000-00003e81fca1'', date ''2026-01-01'' + 175)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT B2', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''b1110000-0000-4000-8000-000000000002'', ''3d71580e-0000-4000-8000-00003d71580e'', ''3e901423-0000-4000-8000-00003e901423'', date ''2026-01-01'' + 176)');
select pg_temp.skriv_avvist('tildelte_merker tablet_B1 INSERT A1', 'insert into public.tildelte_merker (stasjon_id, merke_id, ansatt_id, tildelt_dato) values (''a1110000-0000-4000-8000-000000000001'', ''3bae67ef-0000-4000-8000-00003bae67ef'', ''3ccd2404-0000-4000-8000-00003ccd2404'', date ''2026-01-01'' + 177)');
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
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a5e8-0000-4000-8000-000038a2a5e8'', date ''2026-01-01'' + 178, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bd6a-0000-4000-8000-000038b0bd6a'', date ''2026-01-01'' + 179, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_A INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed501-0000-4000-8000-000038bed501'', date ''2026-01-01'' + 180, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_A INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577e9f-0000-4000-8000-00003a577e9f'', date ''2026-01-01'' + 181, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a601-0000-4000-8000-000038a2a601'', date ''2026-01-01'' + 182, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bd83-0000-4000-8000-000038b0bd83'', date ''2026-01-01'' + 183, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed505-0000-4000-8000-000038bed505'', date ''2026-01-01'' + 184, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577ea3-0000-4000-8000-00003a577ea3'', date ''2026-01-01'' + 185, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a605-0000-4000-8000-000038a2a605'', date ''2026-01-01'' + 186, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger manager_A12 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bd87-0000-4000-8000-000038b0bd87'', date ''2026-01-01'' + 187, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed509-0000-4000-8000-000038bed509'', date ''2026-01-01'' + 188, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_A12 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577ea7-0000-4000-8000-00003a577ea7'', date ''2026-01-01'' + 189, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443e-0000-4000-8000-00001a11443e'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443f-0000-4000-8000-00001a11443f'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_A1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a61e-0000-4000-8000-000038a2a61e'', date ''2026-01-01'' + 190, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000002'', ''38b0bda0-0000-4000-8000-000038b0bda0'', date ''2026-01-01'' + 191, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT A3', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000003'', ''38bed522-0000-4000-8000-000038bed522'', date ''2026-01-01'' + 192, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_A1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577ec0-0000-4000-8000-00003a577ec0'', date ''2026-01-01'' + 193, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ik_avlesninger owner_B SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT B2 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'positiv');
select pg_temp.paastand('ik_avlesninger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577ec1-0000-4000-8000-00003a577ec1'', date ''2026-01-01'' + 194, 4.0, true)');
select pg_temp.skriv_tillatt('ik_avlesninger owner_B INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659643-0000-4000-8000-00003a659643'', date ''2026-01-01'' + 195, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger owner_B INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a624-0000-4000-8000-000038a2a624'', date ''2026-01-01'' + 196, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger manager_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a577ec4-0000-4000-8000-00003a577ec4'', date ''2026-01-01'' + 197, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a659646-0000-4000-8000-00003a659646'', date ''2026-01-01'' + 198, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger manager_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a627-0000-4000-8000-000038a2a627'', date ''2026-01-01'' + 199, 4.0, true)');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.ik_avlesninger where id = '1a11445c-0000-4000-8000-00001a11445c'), 'positiv');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11445d-0000-4000-8000-00001a11445d'), 'negativ');
select pg_temp.paastand('ik_avlesninger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ik_avlesninger where id = '1a11443d-0000-4000-8000-00001a11443d'), 'negativ');
select pg_temp.skriv_tillatt('ik_avlesninger tablet_B1 INSERT B1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000001'', ''3a578167-0000-4000-8000-00003a578167'', date ''2026-01-01'' + 200, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT B2', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''b1110000-0000-4000-8000-000000000002'', ''3a6598e9-0000-4000-8000-00003a6598e9'', date ''2026-01-01'' + 201, 4.0, true)');
select pg_temp.skriv_avvist('ik_avlesninger tablet_B1 INSERT A1', 'insert into public.ik_avlesninger (stasjon_id, kontrollpunkt_id, dato, temperatur, innenfor) values (''a1110000-0000-4000-8000-000000000001'', ''38a2a8ca-0000-4000-8000-000038a2a8ca'', date ''2026-01-01'' + 202, 4.0, true)');

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
    raise exception 'TENANT-MATRISEN DEL 2/4: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 2/4: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
