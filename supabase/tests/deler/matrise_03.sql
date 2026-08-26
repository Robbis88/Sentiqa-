-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 3 AV 5. Hele matrisen er for stor for Supabase SQL
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d940e-0000-4000-8000-0000a86d940e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e086e-0000-4000-8000-0000a86e086e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7cce-0000-4000-8000-0000a86e7cce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bab92-0000-4000-8000-0000a87bab92', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c1ff2-0000-4000-8000-0000a87c1ff2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
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
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea87-0000-4000-8000-00006544ea87', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6553021e-0000-4000-8000-00006553021e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('656119a0-0000-4000-8000-0000656119a0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c33e-0000-4000-8000-000066f9c33e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544eaa0-0000-4000-8000-00006544eaa0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530222-0000-4000-8000-000065530222', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('656119a4-0000-4000-8000-0000656119a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544eaa3-0000-4000-8000-00006544eaa3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530225-0000-4000-8000-000065530225', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('656119a7-0000-4000-8000-0000656119a7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c345-0000-4000-8000-000066f9c345', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed47-0000-4000-8000-00006544ed47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed48-0000-4000-8000-00006544ed48', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304ca-0000-4000-8000-0000655304ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c4c-0000-4000-8000-000065611c4c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c5ea-0000-4000-8000-000066f9c5ea', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed4c-0000-4000-8000-00006544ed4c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304ce-0000-4000-8000-0000655304ce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed4e-0000-4000-8000-00006544ed4e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655304d0-0000-4000-8000-0000655304d0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611c52-0000-4000-8000-000065611c52', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c605-0000-4000-8000-000066f9c605', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c606-0000-4000-8000-000066f9c606', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dd88-0000-4000-8000-00006707dd88', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed69-0000-4000-8000-00006544ed69', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c609-0000-4000-8000-000066f9c609', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dd8b-0000-4000-8000-00006707dd8b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c60b-0000-4000-8000-000066f9c60b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dd8d-0000-4000-8000-00006707dd8d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed6e-0000-4000-8000-00006544ed6e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c60e-0000-4000-8000-000066f9c60e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c624-0000-4000-8000-000066f9c624', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dda6-0000-4000-8000-00006707dda6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ed87-0000-4000-8000-00006544ed87', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a60b-0000-4000-8000-00002123a60b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af2a-0000-4000-8000-00005022af2a', 'aaaa0000-0000-4000-8000-000000000000', '2123a60b-0000-4000-8000-00002123a60b', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bd8d-0000-4000-8000-00002131bd8d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6ac-0000-4000-8000-00005030c6ac', 'aaaa0000-0000-4000-8000-000000000000', '2131bd8d-0000-4000-8000-00002131bd8d', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd50f-0000-4000-8000-0000213fd50f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede2e-0000-4000-8000-0000503ede2e', 'aaaa0000-0000-4000-8000-000000000000', '213fd50f-0000-4000-8000-0000213fd50f', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ead-0000-4000-8000-000022d87ead', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787cc-0000-4000-8000-000051d787cc', 'bbbb0000-0000-4000-8000-000000000000', '22d87ead-0000-4000-8000-000022d87ead', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a60f-0000-4000-8000-00002123a60f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af2e-0000-4000-8000-00005022af2e', 'aaaa0000-0000-4000-8000-000000000000', '2123a60f-0000-4000-8000-00002123a60f', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bd91-0000-4000-8000-00002131bd91', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6b0-0000-4000-8000-00005030c6b0', 'aaaa0000-0000-4000-8000-000000000000', '2131bd91-0000-4000-8000-00002131bd91', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd513-0000-4000-8000-0000213fd513', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede32-0000-4000-8000-0000503ede32', 'aaaa0000-0000-4000-8000-000000000000', '213fd513-0000-4000-8000-0000213fd513', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ec6-0000-4000-8000-000022d87ec6', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787e5-0000-4000-8000-000051d787e5', 'bbbb0000-0000-4000-8000-000000000000', '22d87ec6-0000-4000-8000-000022d87ec6', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a628-0000-4000-8000-00002123a628', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af47-0000-4000-8000-00005022af47', 'aaaa0000-0000-4000-8000-000000000000', '2123a628-0000-4000-8000-00002123a628', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdaa-0000-4000-8000-00002131bdaa', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6c9-0000-4000-8000-00005030c6c9', 'aaaa0000-0000-4000-8000-000000000000', '2131bdaa-0000-4000-8000-00002131bdaa', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd52c-0000-4000-8000-0000213fd52c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede4b-0000-4000-8000-0000503ede4b', 'aaaa0000-0000-4000-8000-000000000000', '213fd52c-0000-4000-8000-0000213fd52c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87eca-0000-4000-8000-000022d87eca', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787e9-0000-4000-8000-000051d787e9', 'bbbb0000-0000-4000-8000-000000000000', '22d87eca-0000-4000-8000-000022d87eca', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a62c-0000-4000-8000-00002123a62c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af4b-0000-4000-8000-00005022af4b', 'aaaa0000-0000-4000-8000-000000000000', '2123a62c-0000-4000-8000-00002123a62c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2131bdae-0000-4000-8000-00002131bdae', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5030c6cd-0000-4000-8000-00005030c6cd', 'aaaa0000-0000-4000-8000-000000000000', '2131bdae-0000-4000-8000-00002131bdae', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('213fd530-0000-4000-8000-0000213fd530', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('503ede4f-0000-4000-8000-0000503ede4f', 'aaaa0000-0000-4000-8000-000000000000', '213fd530-0000-4000-8000-0000213fd530', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ece-0000-4000-8000-000022d87ece', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787ed-0000-4000-8000-000051d787ed', 'bbbb0000-0000-4000-8000-000000000000', '22d87ece-0000-4000-8000-000022d87ece', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ecf-0000-4000-8000-000022d87ecf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d787ee-0000-4000-8000-000051d787ee', 'bbbb0000-0000-4000-8000-000000000000', '22d87ecf-0000-4000-8000-000022d87ecf', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69666-0000-4000-8000-000022e69666', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59f85-0000-4000-8000-000051e59f85', 'bbbb0000-0000-4000-8000-000000000000', '22e69666-0000-4000-8000-000022e69666', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a647-0000-4000-8000-00002123a647', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af66-0000-4000-8000-00005022af66', 'aaaa0000-0000-4000-8000-000000000000', '2123a647-0000-4000-8000-00002123a647', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87ee7-0000-4000-8000-000022d87ee7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78806-0000-4000-8000-000051d78806', 'bbbb0000-0000-4000-8000-000000000000', '22d87ee7-0000-4000-8000-000022d87ee7', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e69669-0000-4000-8000-000022e69669', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59f88-0000-4000-8000-000051e59f88', 'bbbb0000-0000-4000-8000-000000000000', '22e69669-0000-4000-8000-000022e69669', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a64a-0000-4000-8000-00002123a64a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af69-0000-4000-8000-00005022af69', 'aaaa0000-0000-4000-8000-000000000000', '2123a64a-0000-4000-8000-00002123a64a', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22d87eea-0000-4000-8000-000022d87eea', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51d78809-0000-4000-8000-000051d78809', 'bbbb0000-0000-4000-8000-000000000000', '22d87eea-0000-4000-8000-000022d87eea', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('22e6966c-0000-4000-8000-000022e6966c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('51e59f8b-0000-4000-8000-000051e59f8b', 'bbbb0000-0000-4000-8000-000000000000', '22e6966c-0000-4000-8000-000022e6966c', date '2026-08-01', date '2026-08-31');
insert into public.puls_sporsmal (id, retailer_id, tekst) values ('2123a64d-0000-4000-8000-00002123a64d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondesporsmaal');
insert into public.puls_runde (id, retailer_id, sporsmal_id, start_dato, slutt_dato) values ('5022af6c-0000-4000-8000-00005022af6c', 'aaaa0000-0000-4000-8000-000000000000', '2123a64d-0000-4000-8000-00002123a64d', date '2026-08-01', date '2026-08-31');
-- --- synlig_svinn: forutsetninger og proberader ---
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 0, 'fastA1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 1, 'fastA2', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 2, 'fastA3', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 3, 'fastB1', 'Sondevare', 1, 25);
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 4, 'fastB2', 'Sondevare', 1, 25);

create or replace function pg_temp.nyrad_synlig_svinn(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sondevare', 1, 25)
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
-- --- stempling: forutsetninger og proberader ---
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', date '2026-01-01' + 10, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', date '2026-01-01' + 11, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', date '2026-01-01' + 12, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', date '2026-01-01' + 13, clock_timestamp()::time, time '16:00', 480);
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', date '2026-01-01' + 14, clock_timestamp()::time, time '16:00', 480);

create or replace function pg_temp.nyrad_stempling(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter)
  values (p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, clock_timestamp()::time, time '16:00', 480)
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
-- --- tilbakemelding: forutsetninger og proberader ---
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc56-0000-4000-8000-0000bcf4dc56', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondemelding fastA1');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc57-0000-4000-8000-0000bcf4dc57', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondemelding fastA2');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc58-0000-4000-8000-0000bcf4dc58', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondemelding fastA3');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc75-0000-4000-8000-0000bcf4dc75', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondemelding fastB1');
insert into public.tilbakemelding (id, retailer_id, stasjon_id, tekst) values ('bcf4dc76-0000-4000-8000-0000bcf4dc76', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondemelding fastB2');

create or replace function pg_temp.nyrad_tilbakemelding(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.tilbakemelding (retailer_id, stasjon_id, tekst)
  values (p_retailer, p_stasjon, 'Sondemelding ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- opplaering_skift: forutsetninger og proberader ---
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', 'a86d940e-0000-4000-8000-0000a86d940e', date '2026-01-01' + 25);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', 'a86e086e-0000-4000-8000-0000a86e086e', date '2026-01-01' + 26);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', 'a86e7cce-0000-4000-8000-0000a86e7cce', date '2026-01-01' + 27);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', 'a87bab92-0000-4000-8000-0000a87bab92', date '2026-01-01' + 28);
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', 'a87c1ff2-0000-4000-8000-0000a87c1ff2', date '2026-01-01' + 29);

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

-- =====================================================================
-- synlig_svinn  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('synlig_svinn');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('synlig_svinn owner_A SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT A3 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 40, ''owner_AA1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 41, ''owner_AA2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_A INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 42, ''owner_AA3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_A INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 43, ''owner_AB1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('synlig_svinn owner_A UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05d-0000-4000-8000-0000f74fb05d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 44, 'gjenowner_AA1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05e-0000-4000-8000-0000f74fb05e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 45, 'gjenowner_AA2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('synlig_svinn owner_A DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb05f-0000-4000-8000-0000f74fb05f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 46, 'gjenowner_AA3', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('synlig_svinn owner_A DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.skriv_avvist('synlig_svinn owner_A FLYTTER egen rad -> kjede B', 'update public.synlig_svinn set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 47, ''manager_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 48, ''manager_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 49, ''manager_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 50, ''manager_A1B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('synlig_svinn manager_A1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 51, ''manager_A12A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 52, ''manager_A12A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 53, ''manager_A12A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 54, ''manager_A12B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('synlig_svinn manager_A12 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'positiv');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05e-0000-4000-8000-0000f74fb05e'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05f-0000-4000-8000-0000f74fb05f'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 55, ''tablet_A1A1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 56, ''tablet_A1A2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT A3', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 57, ''tablet_A1A3'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 58, ''tablet_A1B1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE A3', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A2', 'delete from public.synlig_svinn where id = ''f74fb05e-0000-4000-8000-0000f74fb05e''', 'synlig_svinn', 'f74fb05e-0000-4000-8000-0000f74fb05e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE A3', 'delete from public.synlig_svinn where id = ''f74fb05f-0000-4000-8000-0000f74fb05f''', 'synlig_svinn', 'f74fb05f-0000-4000-8000-0000f74fb05f', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('synlig_svinn tablet_A1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('synlig_svinn owner_B SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_B SELECT B2 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'positiv');
select pg_temp.paastand('synlig_svinn owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 59, ''owner_BB1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_tillatt('synlig_svinn owner_B INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 60, ''owner_BB2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn owner_B INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 61, ''owner_BA1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('synlig_svinn owner_B UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07c-0000-4000-8000-0000f74fb07c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 62, 'gjenowner_BB1', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('synlig_svinn owner_B DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''');
select pg_temp.som_eier();
insert into public.synlig_svinn (id, retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values ('f74fb07d-0000-4000-8000-0000f74fb07d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 63, 'gjenowner_BB2', 'Sondevare', 1, 25);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('synlig_svinn owner_B DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.skriv_avvist('synlig_svinn owner_B FLYTTER egen rad -> kjede A', 'update public.synlig_svinn set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('synlig_svinn manager_B1 SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'negativ');
select pg_temp.paastand('synlig_svinn manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 64, ''manager_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 65, ''manager_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 66, ''manager_B1A1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('synlig_svinn manager_B1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT B1 -> ser', exists (select 1 from public.synlig_svinn where id = 'f74fb07c-0000-4000-8000-0000f74fb07c'), 'positiv');
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb07d-0000-4000-8000-0000f74fb07d'), 'negativ');
select pg_temp.paastand('synlig_svinn tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.synlig_svinn where id = 'f74fb05d-0000-4000-8000-0000f74fb05d'), 'negativ');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 67, ''tablet_B1B1'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT B2', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 68, ''tablet_B1B2'', ''Sondevare'', 1, 25)');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 INSERT A1', 'insert into public.synlig_svinn (retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 69, ''tablet_B1A1'', ''Sondevare'', 1, 25)');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE B1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE B2', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 UPDATE A1', 'update public.synlig_svinn set varenavn = ''endret av sonden'' where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE B1', 'delete from public.synlig_svinn where id = ''f74fb07c-0000-4000-8000-0000f74fb07c''', 'synlig_svinn', 'f74fb07c-0000-4000-8000-0000f74fb07c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE B2', 'delete from public.synlig_svinn where id = ''f74fb07d-0000-4000-8000-0000f74fb07d''', 'synlig_svinn', 'f74fb07d-0000-4000-8000-0000f74fb07d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_synlig_svinn('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('synlig_svinn tablet_B1 DELETE A1', 'delete from public.synlig_svinn where id = ''f74fb05d-0000-4000-8000-0000f74fb05d''', 'synlig_svinn', 'f74fb05d-0000-4000-8000-0000f74fb05d', 'id');

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
-- stempling  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling owner_A SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT A3 -> ser', exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'positiv');
select pg_temp.paastand('stempling owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 100, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', date ''2026-01-01'' + 101, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_A INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', date ''2026-01-01'' + 102, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_A INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 103, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling owner_A UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b1-0000-4000-8000-0000a36040b1', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', date '2026-01-01' + 104, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b2-0000-4000-8000-0000a36040b2', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', date '2026-01-01' + 105, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling owner_A DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040b3-0000-4000-8000-0000a36040b3', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', date '2026-01-01' + 106, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling owner_A DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stempling manager_A1 SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'negativ');
select pg_temp.paastand('stempling manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 107, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 108, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 109, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 110, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stempling manager_A1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling manager_A1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.skriv_avvist('stempling manager_A1 FLYTTER egen rad A1 -> A2', 'update public.stempling set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stempling manager_A12 SELECT A1 -> ser', exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'positiv');
select pg_temp.paastand('stempling manager_A12 SELECT A2 -> ser', exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'positiv');
select pg_temp.paastand('stempling manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 111, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling manager_A12 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 112, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 113, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_A12 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 114, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling manager_A12 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling manager_A12 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling manager_A12 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.skriv_avvist('stempling manager_A12 FLYTTER egen rad A1 -> A3', 'update public.stempling set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stempling tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b2-0000-4000-8000-0000a36040b2'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b3-0000-4000-8000-0000a36040b3'), 'negativ');
select pg_temp.paastand('stempling tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 115, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', date ''2026-01-01'' + 116, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT A3', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', date ''2026-01-01'' + 117, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_A1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 118, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A2', 'update public.stempling set minutter = 470 where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE A3', 'update public.stempling set minutter = 470 where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A2', 'delete from public.stempling where id = ''a36040b2-0000-4000-8000-0000a36040b2''', 'stempling', 'a36040b2-0000-4000-8000-0000a36040b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE A3', 'delete from public.stempling where id = ''a36040b3-0000-4000-8000-0000a36040b3''', 'stempling', 'a36040b3-0000-4000-8000-0000a36040b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling tablet_A1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stempling owner_B SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling owner_B SELECT B2 -> ser', exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'positiv');
select pg_temp.paastand('stempling owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', date ''2026-01-01'' + 119, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_tillatt('stempling owner_B INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', date ''2026-01-01'' + 120, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling owner_B INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', date ''2026-01-01'' + 121, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d0-0000-4000-8000-0000a36040d0', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', date '2026-01-01' + 122, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling owner_B DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''');
select pg_temp.som_eier();
insert into public.stempling (id, stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values ('a36040d1-0000-4000-8000-0000a36040d1', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', date '2026-01-01' + 123, clock_timestamp()::time, time '16:00', 480);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling owner_B DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'positiv');
select pg_temp.paastand('stempling manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_tillatt('stempling manager_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 124, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 125, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling manager_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 126, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stempling manager_B1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling manager_B1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.skriv_avvist('stempling manager_B1 FLYTTER egen rad B1 -> B2', 'update public.stempling set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stempling tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d0-0000-4000-8000-0000a36040d0'), 'negativ');
select pg_temp.paastand('stempling tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040d1-0000-4000-8000-0000a36040d1'), 'negativ');
select pg_temp.paastand('stempling tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling where id = 'a36040b1-0000-4000-8000-0000a36040b1'), 'negativ');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', date ''2026-01-01'' + 127, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT B2', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', date ''2026-01-01'' + 128, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.skriv_avvist('stempling tablet_B1 INSERT A1', 'insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', date ''2026-01-01'' + 129, clock_timestamp()::time, time ''16:00'', 480)');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE B1', 'update public.stempling set minutter = 470 where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE B2', 'update public.stempling set minutter = 470 where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 UPDATE A1', 'update public.stempling set minutter = 470 where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE B1', 'delete from public.stempling where id = ''a36040d0-0000-4000-8000-0000a36040d0''', 'stempling', 'a36040d0-0000-4000-8000-0000a36040d0', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE B2', 'delete from public.stempling where id = ''a36040d1-0000-4000-8000-0000a36040d1''', 'stempling', 'a36040d1-0000-4000-8000-0000a36040d1', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling tablet_B1 DELETE A1', 'delete from public.stempling where id = ''a36040b1-0000-4000-8000-0000a36040b1''', 'stempling', 'a36040b1-0000-4000-8000-0000a36040b1', 'id');

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
-- tilbakemelding  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('tilbakemelding');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('tilbakemelding owner_A SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT A2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT A3 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AA1'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_AA2'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_A INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding owner_AA3'')');
select pg_temp.skriv_avvist('tilbakemelding owner_A INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('tilbakemelding owner_A UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('tilbakemelding owner_A UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding owner_A FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_A1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1A1'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A1A2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A1A3'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('tilbakemelding manager_A1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''', 'tilbakemelding', 'bcf4dc57-0000-4000-8000-0000bcf4dc57', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 FLYTTER egen rad A1 -> A2', 'update public.tilbakemelding set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A1 FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12A1'')');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_A12A2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding manager_A12A3'')');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('tilbakemelding manager_A12 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 FLYTTER egen rad A1 -> A3', 'update public.tilbakemelding set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_A12 FLYTTER egen rad -> kjede B', 'update public.tilbakemelding set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'positiv');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc57-0000-4000-8000-0000bcf4dc57'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc58-0000-4000-8000-0000bcf4dc58'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding tablet_A1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1A1'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT A2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_A1A2'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT A3', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondemelding tablet_A1A3'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc57-0000-4000-8000-0000bcf4dc57''', 'tilbakemelding', 'bcf4dc57-0000-4000-8000-0000bcf4dc57', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE A3', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc58-0000-4000-8000-0000bcf4dc58''', 'tilbakemelding', 'bcf4dc58-0000-4000-8000-0000bcf4dc58', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('tilbakemelding tablet_A1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('tilbakemelding owner_B SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_B SELECT B2 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'positiv');
select pg_temp.paastand('tilbakemelding owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding owner_B INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BB1'')');
select pg_temp.skriv_tillatt('tilbakemelding owner_B INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding owner_BB2'')');
select pg_temp.skriv_avvist('tilbakemelding owner_B INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tilbakemelding owner_B UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('tilbakemelding owner_B UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('tilbakemelding owner_B UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding owner_B FLYTTER egen rad -> kjede A', 'update public.tilbakemelding set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('tilbakemelding manager_B1 SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'negativ');
select pg_temp.paastand('tilbakemelding manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding manager_B1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1B1'')');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding manager_B1B2'')');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('tilbakemelding manager_B1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''', 'tilbakemelding', 'bcf4dc76-0000-4000-8000-0000bcf4dc76', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 FLYTTER egen rad B1 -> B2', 'update public.tilbakemelding set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.skriv_avvist('tilbakemelding manager_B1 FLYTTER egen rad -> kjede A', 'update public.tilbakemelding set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT B1 -> ser', exists (select 1 from public.tilbakemelding where id = 'bcf4dc75-0000-4000-8000-0000bcf4dc75'), 'positiv');
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc76-0000-4000-8000-0000bcf4dc76'), 'negativ');
select pg_temp.paastand('tilbakemelding tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.tilbakemelding where id = 'bcf4dc56-0000-4000-8000-0000bcf4dc56'), 'negativ');
select pg_temp.skriv_tillatt('tilbakemelding tablet_B1 INSERT B1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1B1'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 INSERT B2', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondemelding tablet_B1B2'')');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 INSERT A1', 'insert into public.tilbakemelding (retailer_id, stasjon_id, tekst) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondemelding tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE B1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc75-0000-4000-8000-0000bcf4dc75''', 'tilbakemelding', 'bcf4dc75-0000-4000-8000-0000bcf4dc75', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE B2', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc76-0000-4000-8000-0000bcf4dc76''', 'tilbakemelding', 'bcf4dc76-0000-4000-8000-0000bcf4dc76', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_tilbakemelding('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('tilbakemelding tablet_B1 UPDATE A1', 'update public.tilbakemelding set lest_tid = now() where id = ''bcf4dc56-0000-4000-8000-0000bcf4dc56''', 'tilbakemelding', 'bcf4dc56-0000-4000-8000-0000bcf4dc56', 'id');

-- =====================================================================
-- opplaering_skift  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_skift');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_skift owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b86-0000-4000-8000-00008cd86b86'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86b87-0000-4000-8000-00008cd86b87'), 'positiv');
select pg_temp.paastand('opplaering_skift owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea87-0000-4000-8000-00006544ea87'', date ''2026-01-01'' + 189)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''6553021e-0000-4000-8000-00006553021e'', date ''2026-01-01'' + 190)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''656119a0-0000-4000-8000-0000656119a0'', date ''2026-01-01'' + 191)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c33e-0000-4000-8000-000066f9c33e'', date ''2026-01-01'' + 192)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544eaa0-0000-4000-8000-00006544eaa0', date '2026-01-01' + 193);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '65530222-0000-4000-8000-000065530222', date '2026-01-01' + 194);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '656119a4-0000-4000-8000-0000656119a4', date '2026-01-01' + 195);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544eaa3-0000-4000-8000-00006544eaa3'', date ''2026-01-01'' + 196)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''65530225-0000-4000-8000-000065530225'', date ''2026-01-01'' + 197)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''656119a7-0000-4000-8000-0000656119a7'', date ''2026-01-01'' + 198)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c345-0000-4000-8000-000066f9c345'', date ''2026-01-01'' + 199)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ed47-0000-4000-8000-00006544ed47', date '2026-01-01' + 200);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed48-0000-4000-8000-00006544ed48'', date ''2026-01-01'' + 201)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655304ca-0000-4000-8000-0000655304ca'', date ''2026-01-01'' + 202)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c4c-0000-4000-8000-000065611c4c'', date ''2026-01-01'' + 203)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c5ea-0000-4000-8000-000066f9c5ea'', date ''2026-01-01'' + 204)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ed4c-0000-4000-8000-00006544ed4c', date '2026-01-01' + 205);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '655304ce-0000-4000-8000-0000655304ce', date '2026-01-01' + 206);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed4e-0000-4000-8000-00006544ed4e'', date ''2026-01-01'' + 207)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655304d0-0000-4000-8000-0000655304d0'', date ''2026-01-01'' + 208)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611c52-0000-4000-8000-000065611c52'', date ''2026-01-01'' + 209)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c605-0000-4000-8000-000066f9c605'', date ''2026-01-01'' + 210)');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c606-0000-4000-8000-000066f9c606'', date ''2026-01-01'' + 211)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dd88-0000-4000-8000-00006707dd88'', date ''2026-01-01'' + 212)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed69-0000-4000-8000-00006544ed69'', date ''2026-01-01'' + 213)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c609-0000-4000-8000-000066f9c609', date '2026-01-01' + 214);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '6707dd8b-0000-4000-8000-00006707dd8b', date '2026-01-01' + 215);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c60b-0000-4000-8000-000066f9c60b'', date ''2026-01-01'' + 216)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dd8d-0000-4000-8000-00006707dd8d'', date ''2026-01-01'' + 217)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed6e-0000-4000-8000-00006544ed6e'', date ''2026-01-01'' + 218)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c60e-0000-4000-8000-000066f9c60e', date '2026-01-01' + 219);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c624-0000-4000-8000-000066f9c624'', date ''2026-01-01'' + 220)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dda6-0000-4000-8000-00006707dda6'', date ''2026-01-01'' + 221)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ed87-0000-4000-8000-00006544ed87'', date ''2026-01-01'' + 222)');
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
-- puls_svar  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('puls_svar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('puls_svar owner_A SELECT A1 -> ser', exists (select 1 from public.puls_svar where id = '3922575b-0000-4000-8000-00003922575b'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A2 -> ser', exists (select 1 from public.puls_svar where id = '3922575c-0000-4000-8000-00003922575c'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT A3 -> ser', exists (select 1 from public.puls_svar where id = '3922575d-0000-4000-8000-00003922575d'), 'positiv');
select pg_temp.paastand('puls_svar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.puls_svar where id = '3922577a-0000-4000-8000-00003922577a'), 'negativ');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af2a-0000-4000-8000-00005022af2a'', 3, ''Sondesvar owner_AA1'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6ac-0000-4000-8000-00005030c6ac'', 3, ''Sondesvar owner_AA2'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede2e-0000-4000-8000-0000503ede2e'', 3, ''Sondesvar owner_AA3'')');
select pg_temp.skriv_avvist('puls_svar owner_A INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787cc-0000-4000-8000-000051d787cc'', 3, ''Sondesvar owner_AB1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af2e-0000-4000-8000-00005022af2e'', 3, ''Sondesvar manager_A1A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6b0-0000-4000-8000-00005030c6b0'', 3, ''Sondesvar manager_A1A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede32-0000-4000-8000-0000503ede32'', 3, ''Sondesvar manager_A1A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787e5-0000-4000-8000-000051d787e5'', 3, ''Sondesvar manager_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af47-0000-4000-8000-00005022af47'', 3, ''Sondesvar manager_A12A1'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6c9-0000-4000-8000-00005030c6c9'', 3, ''Sondesvar manager_A12A2'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede4b-0000-4000-8000-0000503ede4b'', 3, ''Sondesvar manager_A12A3'')');
select pg_temp.skriv_avvist('puls_svar manager_A12 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787e9-0000-4000-8000-000051d787e9'', 3, ''Sondesvar manager_A12B1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af4b-0000-4000-8000-00005022af4b'', 3, ''Sondesvar tablet_A1A1'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''5030c6cd-0000-4000-8000-00005030c6cd'', 3, ''Sondesvar tablet_A1A2'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT A3', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''503ede4f-0000-4000-8000-0000503ede4f'', 3, ''Sondesvar tablet_A1A3'')');
select pg_temp.skriv_avvist('puls_svar tablet_A1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787ed-0000-4000-8000-000051d787ed'', 3, ''Sondesvar tablet_A1B1'')');
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
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d787ee-0000-4000-8000-000051d787ee'', 3, ''Sondesvar owner_BB1'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59f85-0000-4000-8000-000051e59f85'', 3, ''Sondesvar owner_BB2'')');
select pg_temp.skriv_avvist('puls_svar owner_B INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af66-0000-4000-8000-00005022af66'', 3, ''Sondesvar owner_BA1'')');
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
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78806-0000-4000-8000-000051d78806'', 3, ''Sondesvar manager_B1B1'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59f88-0000-4000-8000-000051e59f88'', 3, ''Sondesvar manager_B1B2'')');
select pg_temp.skriv_avvist('puls_svar manager_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af69-0000-4000-8000-00005022af69'', 3, ''Sondesvar manager_B1A1'')');
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
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''51d78809-0000-4000-8000-000051d78809'', 3, ''Sondesvar tablet_B1B1'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT B2', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''51e59f8b-0000-4000-8000-000051e59f8b'', 3, ''Sondesvar tablet_B1B2'')');
select pg_temp.skriv_avvist('puls_svar tablet_B1 INSERT A1', 'insert into public.puls_svar (retailer_id, stasjon_id, runde_id, skala, kommentar) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''5022af6c-0000-4000-8000-00005022af6c'', 3, ''Sondesvar tablet_B1A1'')');
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
    raise exception 'TENANT-MATRISEN DEL 3/5: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 3/5: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
