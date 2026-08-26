-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 6. Hele matrisen er for stor for Supabase SQL
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
-- --- bemanning_stasjon: forutsetninger og proberader ---
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000002', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('a1110000-0000-4000-8000-000000000003', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000001', 7);
insert into public.bemanning_stasjon (stasjon_id, maks_bemanning) values ('b1110000-0000-4000-8000-000000000002', 7);
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
-- --- produksjonsplan_hode: forutsetninger og proberader ---
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 27);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 28);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 29);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 30);
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 31);

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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 32, 'Sondevare fastA1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 33, 'Sondevare fastA2');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 34, 'Sondevare fastA3');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 35, 'Sondevare fastB1');
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 36, 'Sondevare fastB2');

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
-- --- avvik: forutsetninger og proberader ---
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be737-0000-4000-8000-0000007be737', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde fastA1');
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be738-0000-4000-8000-0000007be738', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'sonde fastA2');
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be739-0000-4000-8000-0000007be739', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'sonde fastA3');
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be756-0000-4000-8000-0000007be756', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde fastB1');
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be757-0000-4000-8000-0000007be757', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'sonde fastB2');

create or replace function pg_temp.nyrad_avvik(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values (p_retailer, p_stasjon, date '2026-08-01', 'sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass))
  returning id into ny;
  return ny;
end $fn$;

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
-- produksjonsplan_hode  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('produksjonsplan_hode');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A1 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e2-0000-4000-8000-00003628e8e2'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A2 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e3-0000-4000-8000-00003628e8e3'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT A3 -> ser', exists (select 1 from public.produksjonsplan_hode where id = '3628e8e4-0000-4000-8000-00003628e8e4'), 'positiv');
select pg_temp.paastand('produksjonsplan_hode owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.produksjonsplan_hode where id = '3628e901-0000-4000-8000-00003628e901'), 'negativ');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 237)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 238)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 239)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 240)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 241);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 242);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 243);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 244)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 245)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 246)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 247)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 248);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 249)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 250)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 251)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 252)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 253);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 254);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 255)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 256)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 257)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 258)');
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 260)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 261)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 262);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 263);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 264)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 265)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 266)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 267);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 268)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 269)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 270)');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 271, ''Sondevare owner_AA1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 272, ''Sondevare owner_AA2'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 273, ''Sondevare owner_AA3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 274, ''Sondevare owner_AB1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 275, 'Sondevare gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 276, 'Sondevare gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 277, 'Sondevare gjenowner_AA3');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 278, ''Sondevare manager_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 279, ''Sondevare manager_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 280, ''Sondevare manager_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 281, ''Sondevare manager_A1B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 282, 'Sondevare gjenmanager_A1A1');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 283, ''Sondevare manager_A12A1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 284, ''Sondevare manager_A12A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 285, ''Sondevare manager_A12A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 286, ''Sondevare manager_A12B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 287, 'Sondevare gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 288, 'Sondevare gjenmanager_A12A2');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 289, ''Sondevare tablet_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 290, ''Sondevare tablet_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 291, ''Sondevare tablet_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 292, ''Sondevare tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 293, ''Sondevare owner_BB1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 294, ''Sondevare owner_BB2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 295, ''Sondevare owner_BA1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 296, 'Sondevare gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 297, 'Sondevare gjenowner_BB2');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 298, ''Sondevare manager_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 299, ''Sondevare manager_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 300, ''Sondevare manager_B1A1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 301, 'Sondevare gjenmanager_B1B1');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 302, ''Sondevare tablet_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 303, ''Sondevare tablet_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 304, ''Sondevare tablet_B1A1'')');
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
-- avvik  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('avvik');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('avvik owner_A SELECT A1 -> ser', exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'positiv');
select pg_temp.paastand('avvik owner_A SELECT A2 -> ser', exists (select 1 from public.avvik where id = '007be738-0000-4000-8000-0000007be738'), 'positiv');
select pg_temp.paastand('avvik owner_A SELECT A3 -> ser', exists (select 1 from public.avvik where id = '007be739-0000-4000-8000-0000007be739'), 'positiv');
select pg_temp.paastand('avvik owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'negativ');
select pg_temp.skriv_tillatt('avvik owner_A INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde owner_AA1'')');
select pg_temp.skriv_tillatt('avvik owner_A INSERT A2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde owner_AA2'')');
select pg_temp.skriv_tillatt('avvik owner_A INSERT A3', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''sonde owner_AA3'')');
select pg_temp.skriv_avvist('avvik owner_A INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A UPDATE A2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be738-0000-4000-8000-0000007be738''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A UPDATE A3', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be739-0000-4000-8000-0000007be739''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('avvik owner_A UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be737-0000-4000-8000-0000007be737', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A DELETE A2', 'delete from public.avvik where id = ''007be738-0000-4000-8000-0000007be738''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be738-0000-4000-8000-0000007be738', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'sonde gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('avvik owner_A DELETE A3', 'delete from public.avvik where id = ''007be739-0000-4000-8000-0000007be739''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be739-0000-4000-8000-0000007be739', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'sonde gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('avvik owner_A DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.skriv_avvist('avvik owner_A FLYTTER egen rad -> kjede B', 'update public.avvik set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('avvik manager_A1 SELECT A1 -> ser', exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'positiv');
select pg_temp.paastand('avvik manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.avvik where id = '007be738-0000-4000-8000-0000007be738'), 'negativ');
select pg_temp.paastand('avvik manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.avvik where id = '007be739-0000-4000-8000-0000007be739'), 'negativ');
select pg_temp.paastand('avvik manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'negativ');
select pg_temp.skriv_tillatt('avvik manager_A1 INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_A1A1'')');
select pg_temp.skriv_avvist('avvik manager_A1 INSERT A2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde manager_A1A2'')');
select pg_temp.skriv_avvist('avvik manager_A1 INSERT A3', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''sonde manager_A1A3'')');
select pg_temp.skriv_avvist('avvik manager_A1 INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('avvik manager_A1 UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 UPDATE A2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be738-0000-4000-8000-0000007be738''', 'avvik', '007be738-0000-4000-8000-0000007be738', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 UPDATE A3', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('avvik manager_A1 DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be737-0000-4000-8000-0000007be737', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 DELETE A2', 'delete from public.avvik where id = ''007be738-0000-4000-8000-0000007be738''', 'avvik', '007be738-0000-4000-8000-0000007be738', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 DELETE A3', 'delete from public.avvik where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('avvik manager_A1 DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.skriv_avvist('avvik manager_A1 FLYTTER egen rad A1 -> A2', 'update public.avvik set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.skriv_avvist('avvik manager_A1 FLYTTER egen rad -> kjede B', 'update public.avvik set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('avvik manager_A12 SELECT A1 -> ser', exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'positiv');
select pg_temp.paastand('avvik manager_A12 SELECT A2 -> ser', exists (select 1 from public.avvik where id = '007be738-0000-4000-8000-0000007be738'), 'positiv');
select pg_temp.paastand('avvik manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.avvik where id = '007be739-0000-4000-8000-0000007be739'), 'negativ');
select pg_temp.paastand('avvik manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'negativ');
select pg_temp.skriv_tillatt('avvik manager_A12 INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_A12A1'')');
select pg_temp.skriv_tillatt('avvik manager_A12 INSERT A2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde manager_A12A2'')');
select pg_temp.skriv_avvist('avvik manager_A12 INSERT A3', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''sonde manager_A12A3'')');
select pg_temp.skriv_avvist('avvik manager_A12 INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('avvik manager_A12 UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('avvik manager_A12 UPDATE A2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be738-0000-4000-8000-0000007be738''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('avvik manager_A12 UPDATE A3', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('avvik manager_A12 UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('avvik manager_A12 DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be737-0000-4000-8000-0000007be737', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('avvik manager_A12 DELETE A2', 'delete from public.avvik where id = ''007be738-0000-4000-8000-0000007be738''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be738-0000-4000-8000-0000007be738', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'sonde gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('avvik manager_A12 DELETE A3', 'delete from public.avvik where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('avvik manager_A12 DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.skriv_avvist('avvik manager_A12 FLYTTER egen rad A1 -> A3', 'update public.avvik set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.skriv_avvist('avvik manager_A12 FLYTTER egen rad -> kjede B', 'update public.avvik set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('avvik tablet_A1 SELECT A1 -> ser', exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'positiv');
select pg_temp.paastand('avvik tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.avvik where id = '007be738-0000-4000-8000-0000007be738'), 'negativ');
select pg_temp.paastand('avvik tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.avvik where id = '007be739-0000-4000-8000-0000007be739'), 'negativ');
select pg_temp.paastand('avvik tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'negativ');
select pg_temp.skriv_tillatt('avvik tablet_A1 INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde tablet_A1A1'')');
select pg_temp.skriv_avvist('avvik tablet_A1 INSERT A2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde tablet_A1A2'')');
select pg_temp.skriv_avvist('avvik tablet_A1 INSERT A3', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-08-01'', ''sonde tablet_A1A3'')');
select pg_temp.skriv_avvist('avvik tablet_A1 INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 UPDATE A2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be738-0000-4000-8000-0000007be738''', 'avvik', '007be738-0000-4000-8000-0000007be738', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 UPDATE A3', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 DELETE A2', 'delete from public.avvik where id = ''007be738-0000-4000-8000-0000007be738''', 'avvik', '007be738-0000-4000-8000-0000007be738', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 DELETE A3', 'delete from public.avvik where id = ''007be739-0000-4000-8000-0000007be739''', 'avvik', '007be739-0000-4000-8000-0000007be739', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('avvik tablet_A1 DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('avvik owner_B SELECT B1 -> ser', exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'positiv');
select pg_temp.paastand('avvik owner_B SELECT B2 -> ser', exists (select 1 from public.avvik where id = '007be757-0000-4000-8000-0000007be757'), 'positiv');
select pg_temp.paastand('avvik owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'negativ');
select pg_temp.skriv_tillatt('avvik owner_B INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde owner_BB1'')');
select pg_temp.skriv_tillatt('avvik owner_B INSERT B2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde owner_BB2'')');
select pg_temp.skriv_avvist('avvik owner_B INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('avvik owner_B UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('avvik owner_B UPDATE B2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be757-0000-4000-8000-0000007be757''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('avvik owner_B UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('avvik owner_B DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be756-0000-4000-8000-0000007be756', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('avvik owner_B DELETE B2', 'delete from public.avvik where id = ''007be757-0000-4000-8000-0000007be757''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be757-0000-4000-8000-0000007be757', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'sonde gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('avvik owner_B DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.skriv_avvist('avvik owner_B FLYTTER egen rad -> kjede A', 'update public.avvik set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('avvik manager_B1 SELECT B1 -> ser', exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'positiv');
select pg_temp.paastand('avvik manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.avvik where id = '007be757-0000-4000-8000-0000007be757'), 'negativ');
select pg_temp.paastand('avvik manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'negativ');
select pg_temp.skriv_tillatt('avvik manager_B1 INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_B1B1'')');
select pg_temp.skriv_avvist('avvik manager_B1 INSERT B2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde manager_B1B2'')');
select pg_temp.skriv_avvist('avvik manager_B1 INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('avvik manager_B1 UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('avvik manager_B1 UPDATE B2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be757-0000-4000-8000-0000007be757''', 'avvik', '007be757-0000-4000-8000-0000007be757', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('avvik manager_B1 UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('avvik manager_B1 DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''');
select pg_temp.som_eier();
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values ('007be756-0000-4000-8000-0000007be756', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'sonde gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('avvik manager_B1 DELETE B2', 'delete from public.avvik where id = ''007be757-0000-4000-8000-0000007be757''', 'avvik', '007be757-0000-4000-8000-0000007be757', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('avvik manager_B1 DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.skriv_avvist('avvik manager_B1 FLYTTER egen rad B1 -> B2', 'update public.avvik set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.skriv_avvist('avvik manager_B1 FLYTTER egen rad -> kjede A', 'update public.avvik set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('avvik tablet_B1 SELECT B1 -> ser', exists (select 1 from public.avvik where id = '007be756-0000-4000-8000-0000007be756'), 'positiv');
select pg_temp.paastand('avvik tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.avvik where id = '007be757-0000-4000-8000-0000007be757'), 'negativ');
select pg_temp.paastand('avvik tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.avvik where id = '007be737-0000-4000-8000-0000007be737'), 'negativ');
select pg_temp.skriv_tillatt('avvik tablet_B1 INSERT B1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde tablet_B1B1'')');
select pg_temp.skriv_avvist('avvik tablet_B1 INSERT B2', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-08-01'', ''sonde tablet_B1B2'')');
select pg_temp.skriv_avvist('avvik tablet_B1 INSERT A1', 'insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-08-01'', ''sonde tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 UPDATE B1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 UPDATE B2', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be757-0000-4000-8000-0000007be757''', 'avvik', '007be757-0000-4000-8000-0000007be757', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 UPDATE A1', 'update public.avvik set dato = date ''2026-08-01'' where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 DELETE B1', 'delete from public.avvik where id = ''007be756-0000-4000-8000-0000007be756''', 'avvik', '007be756-0000-4000-8000-0000007be756', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 DELETE B2', 'delete from public.avvik where id = ''007be757-0000-4000-8000-0000007be757''', 'avvik', '007be757-0000-4000-8000-0000007be757', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_avvik('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('avvik tablet_B1 DELETE A1', 'delete from public.avvik where id = ''007be737-0000-4000-8000-0000007be737''', 'avvik', '007be737-0000-4000-8000-0000007be737', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 5/6: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/6: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
