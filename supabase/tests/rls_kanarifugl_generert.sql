-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
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
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a6e2-0000-4000-8000-00002d60a6e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b42-0000-4000-8000-00002d611b42', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618fa2-0000-4000-8000-00002d618fa2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe66-0000-4000-8000-00002d6ebe66', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f32c6-0000-4000-8000-00002d6f32c6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e018643-0000-4000-8000-00009e018643', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a3cf-0000-4000-8000-00001827a3cf', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01faa3-0000-4000-8000-00009e01faa3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1828182f-0000-4000-8000-00001828182f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026f03-0000-4000-8000-00009e026f03', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288c8f-0000-4000-8000-000018288c8f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9dc7-0000-4000-8000-00009e0f9dc7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bb53-0000-4000-8000-00001835bb53', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e101227-0000-4000-8000-00009e101227', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18362fb3-0000-4000-8000-000018362fb3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb43233-0000-4000-8000-00007eb43233', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249ca-0000-4000-8000-00007ec249ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed0614c-0000-4000-8000-00007ed0614c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690aea-0000-4000-8000-000080690aea', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb4324c-0000-4000-8000-00007eb4324c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249ce-0000-4000-8000-00007ec249ce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed06150-0000-4000-8000-00007ed06150', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb4324f-0000-4000-8000-00007eb4324f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249d1-0000-4000-8000-00007ec249d1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed06153-0000-4000-8000-00007ed06153', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690af1-0000-4000-8000-000080690af1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb43268-0000-4000-8000-00007eb43268', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb43269-0000-4000-8000-00007eb43269', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249eb-0000-4000-8000-00007ec249eb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed0616d-0000-4000-8000-00007ed0616d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b0b-0000-4000-8000-000080690b0b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb4326d-0000-4000-8000-00007eb4326d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249ef-0000-4000-8000-00007ec249ef', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb4326f-0000-4000-8000-00007eb4326f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec249f1-0000-4000-8000-00007ec249f1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed06173-0000-4000-8000-00007ed06173', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b26-0000-4000-8000-000080690b26', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb43288-0000-4000-8000-00007eb43288', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b28-0000-4000-8000-000080690b28', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('807722aa-0000-4000-8000-0000807722aa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb4328b-0000-4000-8000-00007eb4328b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b2b-0000-4000-8000-000080690b2b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('807722ad-0000-4000-8000-0000807722ad', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b2d-0000-4000-8000-000080690b2d', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('807722af-0000-4000-8000-0000807722af', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb43290-0000-4000-8000-00007eb43290', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b45-0000-4000-8000-000080690b45', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b46-0000-4000-8000-000080690b46', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('807722c8-0000-4000-8000-0000807722c8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb432a9-0000-4000-8000-00007eb432a9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690b49-0000-4000-8000-000080690b49', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e6e-0000-4000-8000-0000222f3e6e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd262-0000-4000-8000-0000ecccd262', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d55f0-0000-4000-8000-0000223d55f0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae9e4-0000-4000-8000-0000ecdae9e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6d72-0000-4000-8000-0000224b6d72', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece90166-0000-4000-8000-0000ece90166', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e41710-0000-4000-8000-000023e41710', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab04-0000-4000-8000-0000ee81ab04', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e72-0000-4000-8000-0000222f3e72', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd266-0000-4000-8000-0000ecccd266', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d55f4-0000-4000-8000-0000223d55f4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae9e8-0000-4000-8000-0000ecdae9e8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6d76-0000-4000-8000-0000224b6d76', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece9016a-0000-4000-8000-0000ece9016a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e75-0000-4000-8000-0000222f3e75', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd269-0000-4000-8000-0000ecccd269', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d55f7-0000-4000-8000-0000223d55f7', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae9eb-0000-4000-8000-0000ecdae9eb', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6d8e-0000-4000-8000-0000224b6d8e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece90182-0000-4000-8000-0000ece90182', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e4172c-0000-4000-8000-000023e4172c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab20-0000-4000-8000-0000ee81ab20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e8e-0000-4000-8000-0000222f3e8e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd282-0000-4000-8000-0000ecccd282', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e8f-0000-4000-8000-0000222f3e8f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd283-0000-4000-8000-0000ecccd283', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d5611-0000-4000-8000-0000223d5611', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdaea05-0000-4000-8000-0000ecdaea05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6d93-0000-4000-8000-0000224b6d93', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece90187-0000-4000-8000-0000ece90187', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e41731-0000-4000-8000-000023e41731', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab25-0000-4000-8000-0000ee81ab25', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e93-0000-4000-8000-0000222f3e93', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd287-0000-4000-8000-0000ecccd287', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d5615-0000-4000-8000-0000223d5615', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdaea09-0000-4000-8000-0000ecdaea09', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3e95-0000-4000-8000-0000222f3e95', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd289-0000-4000-8000-0000ecccd289', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d562c-0000-4000-8000-0000223d562c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdaea20-0000-4000-8000-0000ecdaea20', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b6dae-0000-4000-8000-0000224b6dae', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece901a2-0000-4000-8000-0000ece901a2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e4174c-0000-4000-8000-000023e4174c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab40-0000-4000-8000-0000ee81ab40', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e4174d-0000-4000-8000-000023e4174d', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab41-0000-4000-8000-0000ee81ab41', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22ecf-0000-4000-8000-000023f22ecf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fc2c3-0000-4000-8000-0000ee8fc2c3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3eb0-0000-4000-8000-0000222f3eb0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd2a4-0000-4000-8000-0000ecccd2a4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e41750-0000-4000-8000-000023e41750', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab44-0000-4000-8000-0000ee81ab44', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22ed2-0000-4000-8000-000023f22ed2', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fc2c6-0000-4000-8000-0000ee8fc2c6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e41752-0000-4000-8000-000023e41752', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab46-0000-4000-8000-0000ee81ab46', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22ed4-0000-4000-8000-000023f22ed4', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fc2c8-0000-4000-8000-0000ee8fc2c8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3eca-0000-4000-8000-0000222f3eca', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd2be-0000-4000-8000-0000ecccd2be', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e4176a-0000-4000-8000-000023e4176a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab5e-0000-4000-8000-0000ee81ab5e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e4176b-0000-4000-8000-000023e4176b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81ab5f-0000-4000-8000-0000ee81ab5f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22eed-0000-4000-8000-000023f22eed', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fc2e1-0000-4000-8000-0000ee8fc2e1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3ece-0000-4000-8000-0000222f3ece', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccd2c2-0000-4000-8000-0000ecccd2c2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
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
-- --- rutine_utforinger: forutsetninger og proberader ---
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a6e2-0000-4000-8000-00002d60a6e2', date '2026-01-01' + 42);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611b42-0000-4000-8000-00002d611b42', date '2026-01-01' + 43);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '2d618fa2-0000-4000-8000-00002d618fa2', date '2026-01-01' + 44);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebe66-0000-4000-8000-00002d6ebe66', date '2026-01-01' + 45);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '2d6f32c6-0000-4000-8000-00002d6f32c6', date '2026-01-01' + 46);

create or replace function pg_temp.nyrad_rutine_utforinger(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_rutine uuid := gen_random_uuid();
begin
  insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values (v_rutine, p_retailer, p_stasjon, 'Sonderutine');
  insert into public.rutine_utforinger (stasjon_id, rutine_id, dato)
  values (p_stasjon, v_rutine, date '2030-01-01' + nextval('tenant_teller'::regclass)::int)
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
-- --- opplaering_utfort: forutsetninger og proberader ---
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a3cf-0000-4000-8000-00001827a3cf', '9e018643-0000-4000-8000-00009e018643');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', '1828182f-0000-4000-8000-00001828182f', '9e01faa3-0000-4000-8000-00009e01faa3');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', '18288c8f-0000-4000-8000-000018288c8f', '9e026f03-0000-4000-8000-00009e026f03');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', '1835bb53-0000-4000-8000-00001835bb53', '9e0f9dc7-0000-4000-8000-00009e0f9dc7');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', '18362fb3-0000-4000-8000-000018362fb3', '9e101227-0000-4000-8000-00009e101227');

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
-- --- stempling_hendelse: forutsetninger og proberader ---
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e262-0000-4000-8000-0000fd47e262', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e263-0000-4000-8000-0000fd47e263', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e264-0000-4000-8000-0000fd47e264', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e281-0000-4000-8000-0000fd47e281', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');
insert into public.stempling_hendelse (id, retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values ('fd47e282-0000-4000-8000-0000fd47e282', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet');

create or replace function pg_temp.nyrad_stempling_hendelse(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde)
  values (p_retailer, p_stasjon, '4501', 'Kim Hansen', 'inn', clock_timestamp(), 'tablet')
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 257)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 258)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 259)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_A INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 260)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 261);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 262);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_A DELETE A3', 'delete from public.produksjonsplan_hode where id = ''3628e8e4-0000-4000-8000-00003628e8e4''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e4-0000-4000-8000-00003628e8e4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 263);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 264)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 265)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 266)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 267)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 268);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 269)');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 270)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 271)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_A12 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 272)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e2-0000-4000-8000-00003628e8e2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 273);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_A12 DELETE A2', 'delete from public.produksjonsplan_hode where id = ''3628e8e3-0000-4000-8000-00003628e8e3''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e8e3-0000-4000-8000-00003628e8e3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 274);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 275)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 276)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT A3', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 277)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_A1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 278)');
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
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 279)');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 280)');
select pg_temp.skriv_avvist('produksjonsplan_hode owner_B INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 281)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 282);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_hode('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_hode owner_B DELETE B2', 'delete from public.produksjonsplan_hode where id = ''3628e902-0000-4000-8000-00003628e902''');
select pg_temp.som_eier();
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e902-0000-4000-8000-00003628e902', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 283);
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
select pg_temp.skriv_tillatt('produksjonsplan_hode manager_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 284)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 285)');
select pg_temp.skriv_avvist('produksjonsplan_hode manager_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 286)');
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
insert into public.produksjonsplan_hode (id, retailer_id, stasjon_id, dato) values ('3628e901-0000-4000-8000-00003628e901', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 287);
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
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 288)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT B2', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 289)');
select pg_temp.skriv_avvist('produksjonsplan_hode tablet_B1 INSERT A1', 'insert into public.produksjonsplan_hode (retailer_id, stasjon_id, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 290)');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 291, ''Sondevare owner_AA1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 292, ''Sondevare owner_AA2'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 293, ''Sondevare owner_AA3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_A INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 294, ''Sondevare owner_AB1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 295, 'Sondevare gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 296, 'Sondevare gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_A DELETE A3', 'delete from public.produksjonsplan_linjer where id = ''d0ba0802-0000-4000-8000-0000d0ba0802''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0802-0000-4000-8000-0000d0ba0802', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 297, 'Sondevare gjenowner_AA3');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 298, ''Sondevare manager_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 299, ''Sondevare manager_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 300, ''Sondevare manager_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 301, ''Sondevare manager_A1B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 302, 'Sondevare gjenmanager_A1A1');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 303, ''Sondevare manager_A12A1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 304, ''Sondevare manager_A12A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 305, ''Sondevare manager_A12A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_A12 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 306, ''Sondevare manager_A12B1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0800-0000-4000-8000-0000d0ba0800', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 307, 'Sondevare gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_A12 DELETE A2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0801-0000-4000-8000-0000d0ba0801''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0801-0000-4000-8000-0000d0ba0801', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 308, 'Sondevare gjenmanager_A12A2');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 309, ''Sondevare tablet_A1A1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 310, ''Sondevare tablet_A1A2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT A3', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 311, ''Sondevare tablet_A1A3'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_A1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 312, ''Sondevare tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 313, ''Sondevare owner_BB1'')');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 314, ''Sondevare owner_BB2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer owner_B INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 315, ''Sondevare owner_BA1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 316, 'Sondevare gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_produksjonsplan_linjer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('produksjonsplan_linjer owner_B DELETE B2', 'delete from public.produksjonsplan_linjer where id = ''d0ba0820-0000-4000-8000-0000d0ba0820''');
select pg_temp.som_eier();
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba0820-0000-4000-8000-0000d0ba0820', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 317, 'Sondevare gjenowner_BB2');
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
select pg_temp.skriv_tillatt('produksjonsplan_linjer manager_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 318, ''Sondevare manager_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 319, ''Sondevare manager_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer manager_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 320, ''Sondevare manager_B1A1'')');
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
insert into public.produksjonsplan_linjer (id, retailer_id, stasjon_id, dato, varenavn) values ('d0ba081f-0000-4000-8000-0000d0ba081f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 321, 'Sondevare gjenmanager_B1B1');
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
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 322, ''Sondevare tablet_B1B1'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT B2', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 323, ''Sondevare tablet_B1B2'')');
select pg_temp.skriv_avvist('produksjonsplan_linjer tablet_B1 INSERT A1', 'insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 324, ''Sondevare tablet_B1A1'')');
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

-- =====================================================================
-- rutine_utforinger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_utforinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_utforinger owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb43233-0000-4000-8000-00007eb43233'', date ''2026-01-01'' + 359)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec249ca-0000-4000-8000-00007ec249ca'', date ''2026-01-01'' + 360)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed0614c-0000-4000-8000-00007ed0614c'', date ''2026-01-01'' + 361)');
select pg_temp.skriv_avvist('rutine_utforinger owner_A INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690aea-0000-4000-8000-000080690aea'', date ''2026-01-01'' + 362)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_utforinger owner_A UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb4324c-0000-4000-8000-00007eb4324c', date '2026-01-01' + 363);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec249ce-0000-4000-8000-00007ec249ce', date '2026-01-01' + 364);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '7ed06150-0000-4000-8000-00007ed06150', date '2026-01-01' + 365);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_utforinger owner_A DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb4324f-0000-4000-8000-00007eb4324f'', date ''2026-01-01'' + 366)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec249d1-0000-4000-8000-00007ec249d1'', date ''2026-01-01'' + 367)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed06153-0000-4000-8000-00007ed06153'', date ''2026-01-01'' + 368)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690af1-0000-4000-8000-000080690af1'', date ''2026-01-01'' + 369)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb43268-0000-4000-8000-00007eb43268', date '2026-01-01' + 370);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb43269-0000-4000-8000-00007eb43269'', date ''2026-01-01'' + 371)');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec249eb-0000-4000-8000-00007ec249eb'', date ''2026-01-01'' + 372)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed0616d-0000-4000-8000-00007ed0616d'', date ''2026-01-01'' + 373)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690b0b-0000-4000-8000-000080690b0b'', date ''2026-01-01'' + 374)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb4326d-0000-4000-8000-00007eb4326d', date '2026-01-01' + 375);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec249ef-0000-4000-8000-00007ec249ef', date '2026-01-01' + 376);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb4326f-0000-4000-8000-00007eb4326f'', date ''2026-01-01'' + 377)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec249f1-0000-4000-8000-00007ec249f1'', date ''2026-01-01'' + 378)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed06173-0000-4000-8000-00007ed06173'', date ''2026-01-01'' + 379)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690b26-0000-4000-8000-000080690b26'', date ''2026-01-01'' + 380)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE A2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE A3', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb43288-0000-4000-8000-00007eb43288', date '2026-01-01' + 381);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''', 'rutine_utforinger', '7d5cd88a-0000-4000-8000-00007d5cd88a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''', 'rutine_utforinger', '7d5cd88b-0000-4000-8000-00007d5cd88b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_utforinger set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutine_utforinger owner_B SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_B SELECT B2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690b28-0000-4000-8000-000080690b28'', date ''2026-01-01'' + 382)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''807722aa-0000-4000-8000-0000807722aa'', date ''2026-01-01'' + 383)');
select pg_temp.skriv_avvist('rutine_utforinger owner_B INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb4328b-0000-4000-8000-00007eb4328b'', date ''2026-01-01'' + 384)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '80690b2b-0000-4000-8000-000080690b2b', date '2026-01-01' + 385);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '807722ad-0000-4000-8000-0000807722ad', date '2026-01-01' + 386);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690b2d-0000-4000-8000-000080690b2d'', date ''2026-01-01'' + 387)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''807722af-0000-4000-8000-0000807722af'', date ''2026-01-01'' + 388)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb43290-0000-4000-8000-00007eb43290'', date ''2026-01-01'' + 389)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '80690b45-0000-4000-8000-000080690b45', date '2026-01-01' + 390);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_utforinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690b46-0000-4000-8000-000080690b46'', date ''2026-01-01'' + 391)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''807722c8-0000-4000-8000-0000807722c8'', date ''2026-01-01'' + 392)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb432a9-0000-4000-8000-00007eb432a9'', date ''2026-01-01'' + 393)');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 UPDATE B1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 UPDATE B2', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 UPDATE A1', 'update public.rutine_utforinger set utfort_tid = now() where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 DELETE B1', 'delete from public.rutine_utforinger where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '80690b49-0000-4000-8000-000080690b49', date '2026-01-01' + 394);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''', 'rutine_utforinger', '7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_utforinger set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''7d5cd8a8-0000-4000-8000-00007d5cd8a8''', 'rutine_utforinger', '7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'id');

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
-- opplaering_utfort  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('opplaering_utfort');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('opplaering_utfort owner_A SELECT A1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A2 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42d-0000-4000-8000-0000178fd42d'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT A3 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd42e-0000-4000-8000-0000178fd42e'), 'positiv');
select pg_temp.paastand('opplaering_utfort owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd262-0000-4000-8000-0000ecccd262'', ''222f3e6e-0000-4000-8000-0000222f3e6e'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdae9e4-0000-4000-8000-0000ecdae9e4'', ''223d55f0-0000-4000-8000-0000223d55f0'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece90166-0000-4000-8000-0000ece90166'', ''224b6d72-0000-4000-8000-0000224b6d72'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_A INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab04-0000-4000-8000-0000ee81ab04'', ''23e41710-0000-4000-8000-000023e41710'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccd266-0000-4000-8000-0000ecccd266', '222f3e72-0000-4000-8000-0000222f3e72');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdae9e8-0000-4000-8000-0000ecdae9e8', '223d55f4-0000-4000-8000-0000223d55f4');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', 'ece9016a-0000-4000-8000-0000ece9016a', '224b6d76-0000-4000-8000-0000224b6d76');
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
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd269-0000-4000-8000-0000ecccd269'', ''222f3e75-0000-4000-8000-0000222f3e75'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdae9eb-0000-4000-8000-0000ecdae9eb'', ''223d55f7-0000-4000-8000-0000223d55f7'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece90182-0000-4000-8000-0000ece90182'', ''224b6d8e-0000-4000-8000-0000224b6d8e'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab20-0000-4000-8000-0000ee81ab20'', ''23e4172c-0000-4000-8000-000023e4172c'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccd282-0000-4000-8000-0000ecccd282', '222f3e8e-0000-4000-8000-0000222f3e8e');
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
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd283-0000-4000-8000-0000ecccd283'', ''222f3e8f-0000-4000-8000-0000222f3e8f'')');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdaea05-0000-4000-8000-0000ecdaea05'', ''223d5611-0000-4000-8000-0000223d5611'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece90187-0000-4000-8000-0000ece90187'', ''224b6d93-0000-4000-8000-0000224b6d93'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab25-0000-4000-8000-0000ee81ab25'', ''23e41731-0000-4000-8000-000023e41731'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'ecccd287-0000-4000-8000-0000ecccd287', '222f3e93-0000-4000-8000-0000222f3e93');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdaea09-0000-4000-8000-0000ecdaea09', '223d5615-0000-4000-8000-0000223d5615');
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
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd289-0000-4000-8000-0000ecccd289'', ''222f3e95-0000-4000-8000-0000222f3e95'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdaea20-0000-4000-8000-0000ecdaea20'', ''223d562c-0000-4000-8000-0000223d562c'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece901a2-0000-4000-8000-0000ece901a2'', ''224b6dae-0000-4000-8000-0000224b6dae'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab40-0000-4000-8000-0000ee81ab40'', ''23e4174c-0000-4000-8000-000023e4174c'')');
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
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab41-0000-4000-8000-0000ee81ab41'', ''23e4174d-0000-4000-8000-000023e4174d'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fc2c3-0000-4000-8000-0000ee8fc2c3'', ''23f22ecf-0000-4000-8000-000023f22ecf'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_B INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd2a4-0000-4000-8000-0000ecccd2a4'', ''222f3eb0-0000-4000-8000-0000222f3eb0'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81ab44-0000-4000-8000-0000ee81ab44', '23e41750-0000-4000-8000-000023e41750');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', 'ee8fc2c6-0000-4000-8000-0000ee8fc2c6', '23f22ed2-0000-4000-8000-000023f22ed2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab46-0000-4000-8000-0000ee81ab46'', ''23e41752-0000-4000-8000-000023e41752'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fc2c8-0000-4000-8000-0000ee8fc2c8'', ''23f22ed4-0000-4000-8000-000023f22ed4'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd2be-0000-4000-8000-0000ecccd2be'', ''222f3eca-0000-4000-8000-0000222f3eca'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81ab5e-0000-4000-8000-0000ee81ab5e', '23e4176a-0000-4000-8000-000023e4176a');
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
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81ab5f-0000-4000-8000-0000ee81ab5f'', ''23e4176b-0000-4000-8000-000023e4176b'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fc2e1-0000-4000-8000-0000ee8fc2e1'', ''23f22eed-0000-4000-8000-000023f22eed'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccd2c2-0000-4000-8000-0000ecccd2c2'', ''222f3ece-0000-4000-8000-0000222f3ece'')');
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
-- stempling_hendelse  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('stempling_hendelse');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('stempling_hendelse owner_A SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT A2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT A3 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse owner_A INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_A UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('stempling_hendelse owner_A UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse owner_A FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''', 'stempling_hendelse', 'fd47e263-0000-4000-8000-0000fd47e263', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 FLYTTER egen rad A1 -> A2', 'update public.stempling_hendelse set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A1 FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('stempling_hendelse manager_A12 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 FLYTTER egen rad A1 -> A3', 'update public.stempling_hendelse set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_A12 FLYTTER egen rad -> kjede B', 'update public.stempling_hendelse set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'positiv');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e263-0000-4000-8000-0000fd47e263'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e264-0000-4000-8000-0000fd47e264'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse tablet_A1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT A2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT A3', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e263-0000-4000-8000-0000fd47e263''', 'stempling_hendelse', 'fd47e263-0000-4000-8000-0000fd47e263', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE A3', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e264-0000-4000-8000-0000fd47e264''', 'stempling_hendelse', 'fd47e264-0000-4000-8000-0000fd47e264', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_A1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('stempling_hendelse owner_B SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_B SELECT B2 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'positiv');
select pg_temp.paastand('stempling_hendelse owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse owner_B INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('stempling_hendelse owner_B UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('stempling_hendelse owner_B UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse owner_B FLYTTER egen rad -> kjede A', 'update public.stempling_hendelse set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'negativ');
select pg_temp.paastand('stempling_hendelse manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse manager_B1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('stempling_hendelse manager_B1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''', 'stempling_hendelse', 'fd47e282-0000-4000-8000-0000fd47e282', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 FLYTTER egen rad B1 -> B2', 'update public.stempling_hendelse set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.skriv_avvist('stempling_hendelse manager_B1 FLYTTER egen rad -> kjede A', 'update public.stempling_hendelse set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT B1 -> ser', exists (select 1 from public.stempling_hendelse where id = 'fd47e281-0000-4000-8000-0000fd47e281'), 'positiv');
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e282-0000-4000-8000-0000fd47e282'), 'negativ');
select pg_temp.paastand('stempling_hendelse tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.stempling_hendelse where id = 'fd47e262-0000-4000-8000-0000fd47e262'), 'negativ');
select pg_temp.skriv_tillatt('stempling_hendelse tablet_B1 INSERT B1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 INSERT B2', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 INSERT A1', 'insert into public.stempling_hendelse (retailer_id, stasjon_id, ansatt_nr, ansatt_navn, type, tidspunkt, kilde) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''4501'', ''Kim Hansen'', ''inn'', clock_timestamp(), ''tablet'')');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE B1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e281-0000-4000-8000-0000fd47e281''', 'stempling_hendelse', 'fd47e281-0000-4000-8000-0000fd47e281', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE B2', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e282-0000-4000-8000-0000fd47e282''', 'stempling_hendelse', 'fd47e282-0000-4000-8000-0000fd47e282', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_stempling_hendelse('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('stempling_hendelse tablet_B1 UPDATE A1', 'update public.stempling_hendelse set ansatt_nr = ''4501'' where id = ''fd47e262-0000-4000-8000-0000fd47e262''', 'stempling_hendelse', 'fd47e262-0000-4000-8000-0000fd47e262', 'id');

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
    raise exception 'TENANT-MATRISEN: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
