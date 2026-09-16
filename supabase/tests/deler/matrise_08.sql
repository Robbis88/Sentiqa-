-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 8 AV 11. Hele matrisen er for stor for Supabase SQL
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
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('0ba75a3e-0000-4000-8000-00000ba75a3e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 14', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('ec4ef186-0000-4000-8000-0000ec4ef186', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '0ba75a3e-0000-4000-8000-00000ba75a3e', 'Sonderutine 14');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('0ba7ce9e-0000-4000-8000-00000ba7ce9e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 15', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('ec4f65e6-0000-4000-8000-0000ec4f65e6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '0ba7ce9e-0000-4000-8000-00000ba7ce9e', 'Sonderutine 15');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('0ba842fe-0000-4000-8000-00000ba842fe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 16', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('ec4fda46-0000-4000-8000-0000ec4fda46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '0ba842fe-0000-4000-8000-00000ba842fe', 'Sonderutine 16');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('0bb571c2-0000-4000-8000-00000bb571c2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 17', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('ec5d090a-0000-4000-8000-0000ec5d090a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '0bb571c2-0000-4000-8000-00000bb571c2', 'Sonderutine 17');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('0bb5e622-0000-4000-8000-00000bb5e622', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 18', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('ec5d7d6a-0000-4000-8000-0000ec5d7d6a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '0bb5e622-0000-4000-8000-00000bb5e622', 'Sonderutine 18');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d60a68c-0000-4000-8000-00002d60a68c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d611b01-0000-4000-8000-00002d611b01', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d618f61-0000-4000-8000-00002d618f61', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6ebe25-0000-4000-8000-00002d6ebe25', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('2d6f3285-0000-4000-8000-00002d6f3285', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed76-0000-4000-8000-00006943ed76', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 122', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f2e-0000-4000-8000-00009d8f3f2e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed76-0000-4000-8000-00006943ed76', 'Sonderutine 122');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('695204f8-0000-4000-8000-0000695204f8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 123', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56b0-0000-4000-8000-00009d9d56b0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '695204f8-0000-4000-8000-0000695204f8', 'Sonderutine 123');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69601c7a-0000-4000-8000-000069601c7a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 124', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9dab6e32-0000-4000-8000-00009dab6e32', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '69601c7a-0000-4000-8000-000069601c7a', 'Sonderutine 124');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c618-0000-4000-8000-00006af8c618', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 125', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f4417d0-0000-4000-8000-00009f4417d0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c618-0000-4000-8000-00006af8c618', 'Sonderutine 125');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed7a-0000-4000-8000-00006943ed7a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 126', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f32-0000-4000-8000-00009d8f3f32', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed7a-0000-4000-8000-00006943ed7a', 'Sonderutine 126');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('695204fc-0000-4000-8000-0000695204fc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 127', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56b4-0000-4000-8000-00009d9d56b4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '695204fc-0000-4000-8000-0000695204fc', 'Sonderutine 127');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69601c7e-0000-4000-8000-000069601c7e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 128', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9dab6e36-0000-4000-8000-00009dab6e36', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '69601c7e-0000-4000-8000-000069601c7e', 'Sonderutine 128');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed7d-0000-4000-8000-00006943ed7d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 129', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f35-0000-4000-8000-00009d8f3f35', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed7d-0000-4000-8000-00006943ed7d', 'Sonderutine 129');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69520514-0000-4000-8000-000069520514', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 130', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56cc-0000-4000-8000-00009d9d56cc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '69520514-0000-4000-8000-000069520514', 'Sonderutine 130');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69601c96-0000-4000-8000-000069601c96', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 131', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9dab6e4e-0000-4000-8000-00009dab6e4e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '69601c96-0000-4000-8000-000069601c96', 'Sonderutine 131');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c634-0000-4000-8000-00006af8c634', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 132', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f4417ec-0000-4000-8000-00009f4417ec', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c634-0000-4000-8000-00006af8c634', 'Sonderutine 132');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed96-0000-4000-8000-00006943ed96', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 133', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f4e-0000-4000-8000-00009d8f3f4e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed96-0000-4000-8000-00006943ed96', 'Sonderutine 133');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed97-0000-4000-8000-00006943ed97', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 134', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f4f-0000-4000-8000-00009d8f3f4f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed97-0000-4000-8000-00006943ed97', 'Sonderutine 134');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69520519-0000-4000-8000-000069520519', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 135', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56d1-0000-4000-8000-00009d9d56d1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '69520519-0000-4000-8000-000069520519', 'Sonderutine 135');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69601c9b-0000-4000-8000-000069601c9b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 136', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9dab6e53-0000-4000-8000-00009dab6e53', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '69601c9b-0000-4000-8000-000069601c9b', 'Sonderutine 136');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c639-0000-4000-8000-00006af8c639', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 137', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f4417f1-0000-4000-8000-00009f4417f1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c639-0000-4000-8000-00006af8c639', 'Sonderutine 137');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943ed9b-0000-4000-8000-00006943ed9b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 138', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f53-0000-4000-8000-00009d8f3f53', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943ed9b-0000-4000-8000-00006943ed9b', 'Sonderutine 138');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6952051d-0000-4000-8000-00006952051d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 139', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56d5-0000-4000-8000-00009d9d56d5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '6952051d-0000-4000-8000-00006952051d', 'Sonderutine 139');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943edb2-0000-4000-8000-00006943edb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 140', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f6a-0000-4000-8000-00009d8f3f6a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943edb2-0000-4000-8000-00006943edb2', 'Sonderutine 140');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69520534-0000-4000-8000-000069520534', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 141', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d9d56ec-0000-4000-8000-00009d9d56ec', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', '69520534-0000-4000-8000-000069520534', 'Sonderutine 141');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('69601cb6-0000-4000-8000-000069601cb6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema 142', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9dab6e6e-0000-4000-8000-00009dab6e6e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', '69601cb6-0000-4000-8000-000069601cb6', 'Sonderutine 142');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c654-0000-4000-8000-00006af8c654', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 143', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f44180c-0000-4000-8000-00009f44180c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c654-0000-4000-8000-00006af8c654', 'Sonderutine 143');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943edb6-0000-4000-8000-00006943edb6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 144', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f6e-0000-4000-8000-00009d8f3f6e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943edb6-0000-4000-8000-00006943edb6', 'Sonderutine 144');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c656-0000-4000-8000-00006af8c656', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 145', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f44180e-0000-4000-8000-00009f44180e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c656-0000-4000-8000-00006af8c656', 'Sonderutine 145');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6b06ddd8-0000-4000-8000-00006b06ddd8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 146', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f522f90-0000-4000-8000-00009f522f90', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '6b06ddd8-0000-4000-8000-00006b06ddd8', 'Sonderutine 146');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943edb9-0000-4000-8000-00006943edb9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 147', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f71-0000-4000-8000-00009d8f3f71', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943edb9-0000-4000-8000-00006943edb9', 'Sonderutine 147');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c659-0000-4000-8000-00006af8c659', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 148', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f441811-0000-4000-8000-00009f441811', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c659-0000-4000-8000-00006af8c659', 'Sonderutine 148');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6b06dddb-0000-4000-8000-00006b06dddb', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 149', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f522f93-0000-4000-8000-00009f522f93', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '6b06dddb-0000-4000-8000-00006b06dddb', 'Sonderutine 149');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c670-0000-4000-8000-00006af8c670', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 150', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f441828-0000-4000-8000-00009f441828', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c670-0000-4000-8000-00006af8c670', 'Sonderutine 150');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6b06ddf2-0000-4000-8000-00006b06ddf2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 151', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f522faa-0000-4000-8000-00009f522faa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '6b06ddf2-0000-4000-8000-00006b06ddf2', 'Sonderutine 151');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943edd3-0000-4000-8000-00006943edd3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 152', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f8b-0000-4000-8000-00009d8f3f8b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943edd3-0000-4000-8000-00006943edd3', 'Sonderutine 152');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c673-0000-4000-8000-00006af8c673', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 153', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f44182b-0000-4000-8000-00009f44182b', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c673-0000-4000-8000-00006af8c673', 'Sonderutine 153');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c674-0000-4000-8000-00006af8c674', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 154', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f44182c-0000-4000-8000-00009f44182c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c674-0000-4000-8000-00006af8c674', 'Sonderutine 154');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6b06ddf6-0000-4000-8000-00006b06ddf6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema 155', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f522fae-0000-4000-8000-00009f522fae', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', '6b06ddf6-0000-4000-8000-00006b06ddf6', 'Sonderutine 155');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6943edd7-0000-4000-8000-00006943edd7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 156', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9d8f3f8f-0000-4000-8000-00009d8f3f8f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', '6943edd7-0000-4000-8000-00006943edd7', 'Sonderutine 156');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('6af8c677-0000-4000-8000-00006af8c677', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema 157', '06:00', '14:00');
insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values ('9f44182f-0000-4000-8000-00009f44182f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', '6af8c677-0000-4000-8000-00006af8c677', 'Sonderutine 157');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42ab0-0000-4000-8000-00007eb42ab0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24232-0000-4000-8000-00007ec24232', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059c9-0000-4000-8000-00007ed059c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690367-0000-4000-8000-000080690367', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42ac9-0000-4000-8000-00007eb42ac9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2424b-0000-4000-8000-00007ec2424b', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059cd-0000-4000-8000-00007ed059cd', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42acc-0000-4000-8000-00007eb42acc', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2424e-0000-4000-8000-00007ec2424e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059d0-0000-4000-8000-00007ed059d0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069036e-0000-4000-8000-00008069036e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42ad0-0000-4000-8000-00007eb42ad0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42ae6-0000-4000-8000-00007eb42ae6', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec24268-0000-4000-8000-00007ec24268', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059ea-0000-4000-8000-00007ed059ea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80690388-0000-4000-8000-000080690388', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42aea-0000-4000-8000-00007eb42aea', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2426c-0000-4000-8000-00007ec2426c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42aec-0000-4000-8000-00007eb42aec', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ec2426e-0000-4000-8000-00007ec2426e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7ed059f0-0000-4000-8000-00007ed059f0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('8069038e-0000-4000-8000-00008069038e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b05-0000-4000-8000-00007eb42b05', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903a5-0000-4000-8000-0000806903a5', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b27-0000-4000-8000-000080771b27', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b08-0000-4000-8000-00007eb42b08', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903a8-0000-4000-8000-0000806903a8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b2a-0000-4000-8000-000080771b2a', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903aa-0000-4000-8000-0000806903aa', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b2c-0000-4000-8000-000080771b2c', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b0d-0000-4000-8000-00007eb42b0d', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903ad-0000-4000-8000-0000806903ad', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903c3-0000-4000-8000-0000806903c3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('80771b45-0000-4000-8000-000080771b45', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('7eb42b26-0000-4000-8000-00007eb42b26', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonderutine');
insert into public.rutiner (id, retailer_id, stasjon_id, tittel) values ('806903c6-0000-4000-8000-0000806903c6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonderutine');
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
-- --- retailer_kodeerklaering: forutsetninger og proberader ---
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
-- --- retailer_koderegel: forutsetninger og proberader ---
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5b-0000-4000-8000-0000c922ed5b', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA1');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5c-0000-4000-8000-0000c922ed5c', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA2');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5d-0000-4000-8000-0000c922ed5d', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastA3');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7a-0000-4000-8000-0000c922ed7a', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastB1');
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7b-0000-4000-8000-0000c922ed7b', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'fastB2');

create or replace function pg_temp.nyrad_retailer_koderegel(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode)
  values (p_retailer, 'drivstoff', 'avdeling', '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- retailers: forutsetninger og proberader ---
-- Proberaden er en rad fasitverdenen alt har skrevet. Ingen seeding.
-- --- rutine_notat: forutsetninger og proberader ---
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'a1110000-0000-4000-8000-000000000001', 'ec4ef186-0000-4000-8000-0000ec4ef186', date '2026-01-01' + 14, 'Sondenotat fastA1');
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'a1110000-0000-4000-8000-000000000002', 'ec4f65e6-0000-4000-8000-0000ec4f65e6', date '2026-01-01' + 15, 'Sondenotat fastA2');
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'a1110000-0000-4000-8000-000000000003', 'ec4fda46-0000-4000-8000-0000ec4fda46', date '2026-01-01' + 16, 'Sondenotat fastA3');
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a49-0000-4000-8000-0000cfdd6a49', 'b1110000-0000-4000-8000-000000000001', 'ec5d090a-0000-4000-8000-0000ec5d090a', date '2026-01-01' + 17, 'Sondenotat fastB1');
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'b1110000-0000-4000-8000-000000000002', 'ec5d7d6a-0000-4000-8000-0000ec5d7d6a', date '2026-01-01' + 18, 'Sondenotat fastB2');

create or replace function pg_temp.nyrad_rutine_notat(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
  v_skjema uuid := gen_random_uuid();
  v_rutine uuid := gen_random_uuid();
begin
  insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (v_skjema, p_retailer, p_stasjon, 'morgen', 'Sondeskjema ' || 'rt' || nextval('tenant_teller'::regclass) || '', '06:00', '14:00');
  insert into public.rutiner (id, retailer_id, stasjon_id, skjema_id, tittel) values (v_rutine, p_retailer, p_stasjon, v_skjema, 'Sonderutine ' || 'rt' || nextval('tenant_teller'::regclass) || '');
  insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst)
  values (p_stasjon, v_rutine, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sondenotat ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- rutine_utforinger: forutsetninger og proberader ---
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '2d60a68c-0000-4000-8000-00002d60a68c', date '2026-01-01' + 19);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '2d611b01-0000-4000-8000-00002d611b01', date '2026-01-01' + 20);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '2d618f61-0000-4000-8000-00002d618f61', date '2026-01-01' + 21);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '2d6ebe25-0000-4000-8000-00002d6ebe25', date '2026-01-01' + 22);
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '2d6f3285-0000-4000-8000-00002d6f3285', date '2026-01-01' + 23);

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
-- --- rutineskjemaer: forutsetninger og proberader ---
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema fastA1', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema fastA2', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a579-0000-4000-8000-000027b1a579', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema fastA3', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema fastB1', '06:00', '14:00');
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a597-0000-4000-8000-000027b1a597', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema fastB2', '06:00', '14:00');

create or replace function pg_temp.nyrad_rutineskjemaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt)
  values (p_retailer, p_stasjon, 'morgen', 'Sondeskjema ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', '06:00', '14:00')
  returning id into ny;
  return ny;
end $fn$;

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

-- =====================================================================
-- retailer_kodeerklaering  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailer_kodeerklaering');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailer_kodeerklaering owner_A SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_kodeerklaering owner_A INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_A DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.som_eier();
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_A FLYTTER egen rad -> kjede B', 'update public.retailer_kodeerklaering set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailer_kodeerklaering manager_A1 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailer_kodeerklaering manager_A12 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A12 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_A12 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_A12 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailer_kodeerklaering tablet_A1 SELECT A -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_A1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_A1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_A1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailer_kodeerklaering owner_B SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_kodeerklaering owner_B INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_tillatt('retailer_kodeerklaering owner_B DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.som_eier();
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering owner_B FLYTTER egen rad -> kjede A', 'update public.retailer_kodeerklaering set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailer_kodeerklaering manager_B1 SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_B1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_kodeerklaering manager_B1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering manager_B1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailer_kodeerklaering tablet_B1 SELECT B -> ser', exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'positiv');
select pg_temp.paastand('retailer_kodeerklaering tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_kodeerklaering where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "rolle" = 'drivstoff'), 'negativ');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_B1 INSERT B', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'bbbb0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('bbbb0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_kodeerklaering tablet_B1 INSERT A', 'insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', true)');
select pg_temp.som_eier();
delete from public.retailer_kodeerklaering where retailer_id = 'aaaa0000-0000-4000-8000-000000000000';
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder) values ('aaaa0000-0000-4000-8000-000000000000', 'drivstoff', true);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 UPDATE B', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 UPDATE A', 'update public.retailer_kodeerklaering set gjelder = false where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 DELETE B', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''bbbb0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');
select pg_temp.skriv_avvist_pred('retailer_kodeerklaering tablet_B1 DELETE A', 'delete from public.retailer_kodeerklaering where "retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''', 'retailer_kodeerklaering', '"retailer_id" = ''aaaa0000-0000-4000-8000-000000000000'' and "rolle" = ''drivstoff''');

-- =====================================================================
-- retailer_koderegel  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailer_koderegel');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailer_koderegel owner_A SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('retailer_koderegel owner_A INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_koderegel owner_A UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_A DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''');
select pg_temp.som_eier();
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed5b-0000-4000-8000-0000c922ed5b', 'aaaa0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('retailer_koderegel owner_A DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.skriv_avvist('retailer_koderegel owner_A FLYTTER egen rad -> kjede B', 'update public.retailer_koderegel set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailer_koderegel manager_A1 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('retailer_koderegel manager_A1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailer_koderegel manager_A12 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('retailer_koderegel manager_A12 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailer_koderegel tablet_A1 SELECT A -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'positiv');
select pg_temp.paastand('retailer_koderegel tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_A1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailer_koderegel owner_B SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('retailer_koderegel owner_B INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_koderegel owner_B UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('retailer_koderegel owner_B DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''');
select pg_temp.som_eier();
insert into public.retailer_koderegel (id, retailer_id, rolle, nivaa, kode) values ('c922ed7a-0000-4000-8000-0000c922ed7a', 'bbbb0000-0000-4000-8000-000000000000', 'drivstoff', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('retailer_koderegel owner_B DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.skriv_avvist('retailer_koderegel owner_B FLYTTER egen rad -> kjede A', 'update public.retailer_koderegel set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailer_koderegel manager_B1 SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('retailer_koderegel manager_B1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailer_koderegel tablet_B1 SELECT B -> ser', exists (select 1 from public.retailer_koderegel where id = 'c922ed7a-0000-4000-8000-0000c922ed7a'), 'positiv');
select pg_temp.paastand('retailer_koderegel tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailer_koderegel where id = 'c922ed5b-0000-4000-8000-0000c922ed5b'), 'negativ');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 INSERT B', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 INSERT A', 'insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''drivstoff'', ''avdeling'', ''tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 UPDATE B', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 UPDATE A', 'update public.retailer_koderegel set navn = ''endret'' where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 DELETE B', 'delete from public.retailer_koderegel where id = ''c922ed7a-0000-4000-8000-0000c922ed7a''', 'retailer_koderegel', 'c922ed7a-0000-4000-8000-0000c922ed7a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_retailer_koderegel('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('retailer_koderegel tablet_B1 DELETE A', 'delete from public.retailer_koderegel where id = ''c922ed5b-0000-4000-8000-0000c922ed5b''', 'retailer_koderegel', 'c922ed5b-0000-4000-8000-0000c922ed5b', 'id');

-- =====================================================================
-- retailers  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('retailers');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('retailers owner_A SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers owner_A SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers owner_A INSERT A', 'insert into public.retailers (navn) values (''Sondekjede owner_AA1'')');
select pg_temp.skriv_avvist('retailers owner_A INSERT B', 'insert into public.retailers (navn) values (''Sondekjede owner_AB1'')');
select pg_temp.skriv_tillatt('retailers owner_A UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''');
select pg_temp.skriv_avvist('retailers owner_A UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_A DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_A DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('retailers manager_A1 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_A1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_A1A1'')');
select pg_temp.skriv_avvist('retailers manager_A1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_A1B1'')');
select pg_temp.skriv_avvist('retailers manager_A1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('retailers manager_A12 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_A12 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_A12A1'')');
select pg_temp.skriv_avvist('retailers manager_A12 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_A12B1'')');
select pg_temp.skriv_avvist('retailers manager_A12 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_A12 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('retailers tablet_A1 SELECT A -> ser', exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers tablet_A1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede tablet_A1A1'')');
select pg_temp.skriv_avvist('retailers tablet_A1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede tablet_A1B1'')');
select pg_temp.skriv_avvist('retailers tablet_A1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_A1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('retailers owner_B SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers owner_B SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers owner_B INSERT B', 'insert into public.retailers (navn) values (''Sondekjede owner_BB1'')');
select pg_temp.skriv_avvist('retailers owner_B INSERT A', 'insert into public.retailers (navn) values (''Sondekjede owner_BA1'')');
select pg_temp.skriv_tillatt('retailers owner_B UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''');
select pg_temp.skriv_avvist('retailers owner_B UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_B DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers owner_B DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('retailers manager_B1 SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers manager_B1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede manager_B1B1'')');
select pg_temp.skriv_avvist('retailers manager_B1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede manager_B1A1'')');
select pg_temp.skriv_avvist('retailers manager_B1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers manager_B1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('retailers tablet_B1 SELECT B -> ser', exists (select 1 from public.retailers where id = 'bbbb0000-0000-4000-8000-000000000000'), 'positiv');
select pg_temp.paastand('retailers tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.retailers where id = 'aaaa0000-0000-4000-8000-000000000000'), 'negativ');
select pg_temp.skriv_avvist('retailers tablet_B1 INSERT B', 'insert into public.retailers (navn) values (''Sondekjede tablet_B1B1'')');
select pg_temp.skriv_avvist('retailers tablet_B1 INSERT A', 'insert into public.retailers (navn) values (''Sondekjede tablet_B1A1'')');
select pg_temp.skriv_avvist('retailers tablet_B1 UPDATE B', 'update public.retailers set navn = ''endret av sonden'' where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 UPDATE A', 'update public.retailers set navn = ''endret av sonden'' where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 DELETE B', 'delete from public.retailers where id = ''bbbb0000-0000-4000-8000-000000000000''', 'retailers', 'bbbb0000-0000-4000-8000-000000000000', 'id');
select pg_temp.skriv_avvist('retailers tablet_B1 DELETE A', 'delete from public.retailers where id = ''aaaa0000-0000-4000-8000-000000000000''', 'retailers', 'aaaa0000-0000-4000-8000-000000000000', 'id');

-- =====================================================================
-- rutine_notat  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_notat');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_notat owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'positiv');
select pg_temp.paastand('rutine_notat owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b'), 'positiv');
select pg_temp.paastand('rutine_notat owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c'), 'positiv');
select pg_temp.paastand('rutine_notat owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat owner_A INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f2e-0000-4000-8000-00009d8f3f2e'', date ''2026-01-01'' + 122, ''Sondenotat owner_AA1'')');
select pg_temp.skriv_tillatt('rutine_notat owner_A INSERT A2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000002'', ''9d9d56b0-0000-4000-8000-00009d9d56b0'', date ''2026-01-01'' + 123, ''Sondenotat owner_AA2'')');
select pg_temp.skriv_tillatt('rutine_notat owner_A INSERT A3', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000003'', ''9dab6e32-0000-4000-8000-00009dab6e32'', date ''2026-01-01'' + 124, ''Sondenotat owner_AA3'')');
select pg_temp.skriv_avvist('rutine_notat owner_A INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f4417d0-0000-4000-8000-00009f4417d0'', date ''2026-01-01'' + 125, ''Sondenotat owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A UPDATE A2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A UPDATE A3', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_notat owner_A UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'a1110000-0000-4000-8000-000000000001', '9d8f3f32-0000-4000-8000-00009d8f3f32', date '2026-01-01' + 126, 'Sondenotat gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A DELETE A2', 'delete from public.rutine_notat where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'a1110000-0000-4000-8000-000000000002', '9d9d56b4-0000-4000-8000-00009d9d56b4', date '2026-01-01' + 127, 'Sondenotat gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_notat owner_A DELETE A3', 'delete from public.rutine_notat where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'a1110000-0000-4000-8000-000000000003', '9dab6e36-0000-4000-8000-00009dab6e36', date '2026-01-01' + 128, 'Sondenotat gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutine_notat owner_A DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutine_notat manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'positiv');
select pg_temp.paastand('rutine_notat manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b'), 'negativ');
select pg_temp.paastand('rutine_notat manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c'), 'negativ');
select pg_temp.paastand('rutine_notat manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat manager_A1 INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f35-0000-4000-8000-00009d8f3f35'', date ''2026-01-01'' + 129, ''Sondenotat manager_A1A1'')');
select pg_temp.skriv_avvist('rutine_notat manager_A1 INSERT A2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000002'', ''9d9d56cc-0000-4000-8000-00009d9d56cc'', date ''2026-01-01'' + 130, ''Sondenotat manager_A1A2'')');
select pg_temp.skriv_avvist('rutine_notat manager_A1 INSERT A3', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000003'', ''9dab6e4e-0000-4000-8000-00009dab6e4e'', date ''2026-01-01'' + 131, ''Sondenotat manager_A1A3'')');
select pg_temp.skriv_avvist('rutine_notat manager_A1 INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f4417ec-0000-4000-8000-00009f4417ec'', date ''2026-01-01'' + 132, ''Sondenotat manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_notat manager_A1 UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 UPDATE A2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''', 'rutine_notat', 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 UPDATE A3', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutine_notat manager_A1 DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'a1110000-0000-4000-8000-000000000001', '9d8f3f4e-0000-4000-8000-00009d8f3f4e', date '2026-01-01' + 133, 'Sondenotat gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 DELETE A2', 'delete from public.rutine_notat where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''', 'rutine_notat', 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 DELETE A3', 'delete from public.rutine_notat where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutine_notat manager_A1 DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.skriv_avvist('rutine_notat manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_notat set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutine_notat manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'positiv');
select pg_temp.paastand('rutine_notat manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b'), 'positiv');
select pg_temp.paastand('rutine_notat manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c'), 'negativ');
select pg_temp.paastand('rutine_notat manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f4f-0000-4000-8000-00009d8f3f4f'', date ''2026-01-01'' + 134, ''Sondenotat manager_A12A1'')');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 INSERT A2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000002'', ''9d9d56d1-0000-4000-8000-00009d9d56d1'', date ''2026-01-01'' + 135, ''Sondenotat manager_A12A2'')');
select pg_temp.skriv_avvist('rutine_notat manager_A12 INSERT A3', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000003'', ''9dab6e53-0000-4000-8000-00009dab6e53'', date ''2026-01-01'' + 136, ''Sondenotat manager_A12A3'')');
select pg_temp.skriv_avvist('rutine_notat manager_A12 INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f4417f1-0000-4000-8000-00009f4417f1'', date ''2026-01-01'' + 137, ''Sondenotat manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 UPDATE A2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_notat manager_A12 UPDATE A3', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_notat manager_A12 UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'a1110000-0000-4000-8000-000000000001', '9d8f3f53-0000-4000-8000-00009d8f3f53', date '2026-01-01' + 138, 'Sondenotat gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_notat manager_A12 DELETE A2', 'delete from public.rutine_notat where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'a1110000-0000-4000-8000-000000000002', '9d9d56d5-0000-4000-8000-00009d9d56d5', date '2026-01-01' + 139, 'Sondenotat gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_notat manager_A12 DELETE A3', 'delete from public.rutine_notat where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutine_notat manager_A12 DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.skriv_avvist('rutine_notat manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutine_notat set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutine_notat tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'positiv');
select pg_temp.paastand('rutine_notat tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b'), 'negativ');
select pg_temp.paastand('rutine_notat tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c'), 'negativ');
select pg_temp.paastand('rutine_notat tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat tablet_A1 INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f6a-0000-4000-8000-00009d8f3f6a'', date ''2026-01-01'' + 140, ''Sondenotat tablet_A1A1'')');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 INSERT A2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000002'', ''9d9d56ec-0000-4000-8000-00009d9d56ec'', date ''2026-01-01'' + 141, ''Sondenotat tablet_A1A2'')');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 INSERT A3', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000003'', ''9dab6e6e-0000-4000-8000-00009dab6e6e'', date ''2026-01-01'' + 142, ''Sondenotat tablet_A1A3'')');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f44180c-0000-4000-8000-00009f44180c'', date ''2026-01-01'' + 143, ''Sondenotat tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_notat tablet_A1 UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 UPDATE A2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''', 'rutine_notat', 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 UPDATE A3', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_tillatt('rutine_notat tablet_A1 DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'a1110000-0000-4000-8000-000000000001', '9d8f3f6e-0000-4000-8000-00009d8f3f6e', date '2026-01-01' + 144, 'Sondenotat gjentablet_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 DELETE A2', 'delete from public.rutine_notat where id = ''cfdd6a2b-0000-4000-8000-0000cfdd6a2b''', 'rutine_notat', 'cfdd6a2b-0000-4000-8000-0000cfdd6a2b', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 DELETE A3', 'delete from public.rutine_notat where id = ''cfdd6a2c-0000-4000-8000-0000cfdd6a2c''', 'rutine_notat', 'cfdd6a2c-0000-4000-8000-0000cfdd6a2c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');
select pg_temp.skriv_avvist('rutine_notat tablet_A1 FLYTTER egen rad A1 -> A2', 'update public.rutine_notat set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutine_notat owner_B SELECT B1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'positiv');
select pg_temp.paastand('rutine_notat owner_B SELECT B2 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a'), 'positiv');
select pg_temp.paastand('rutine_notat owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat owner_B INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f44180e-0000-4000-8000-00009f44180e'', date ''2026-01-01'' + 145, ''Sondenotat owner_BB1'')');
select pg_temp.skriv_tillatt('rutine_notat owner_B INSERT B2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000002'', ''9f522f90-0000-4000-8000-00009f522f90'', date ''2026-01-01'' + 146, ''Sondenotat owner_BB2'')');
select pg_temp.skriv_avvist('rutine_notat owner_B INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f71-0000-4000-8000-00009d8f3f71'', date ''2026-01-01'' + 147, ''Sondenotat owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_notat owner_B UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_notat owner_B UPDATE B2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_notat owner_B UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_notat owner_B DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a49-0000-4000-8000-0000cfdd6a49', 'b1110000-0000-4000-8000-000000000001', '9f441811-0000-4000-8000-00009f441811', date '2026-01-01' + 148, 'Sondenotat gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_notat owner_B DELETE B2', 'delete from public.rutine_notat where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'b1110000-0000-4000-8000-000000000002', '9f522f93-0000-4000-8000-00009f522f93', date '2026-01-01' + 149, 'Sondenotat gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_notat owner_B DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_notat manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'positiv');
select pg_temp.paastand('rutine_notat manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a'), 'negativ');
select pg_temp.paastand('rutine_notat manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat manager_B1 INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f441828-0000-4000-8000-00009f441828'', date ''2026-01-01'' + 150, ''Sondenotat manager_B1B1'')');
select pg_temp.skriv_avvist('rutine_notat manager_B1 INSERT B2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000002'', ''9f522faa-0000-4000-8000-00009f522faa'', date ''2026-01-01'' + 151, ''Sondenotat manager_B1B2'')');
select pg_temp.skriv_avvist('rutine_notat manager_B1 INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f8b-0000-4000-8000-00009d8f3f8b'', date ''2026-01-01'' + 152, ''Sondenotat manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_notat manager_B1 UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_notat manager_B1 UPDATE B2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''', 'rutine_notat', 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_notat manager_B1 UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutine_notat manager_B1 DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a49-0000-4000-8000-0000cfdd6a49', 'b1110000-0000-4000-8000-000000000001', '9f44182b-0000-4000-8000-00009f44182b', date '2026-01-01' + 153, 'Sondenotat gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_notat manager_B1 DELETE B2', 'delete from public.rutine_notat where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''', 'rutine_notat', 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutine_notat manager_B1 DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');
select pg_temp.skriv_avvist('rutine_notat manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_notat set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutine_notat tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_notat where id = 'cfdd6a49-0000-4000-8000-0000cfdd6a49'), 'positiv');
select pg_temp.paastand('rutine_notat tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a'), 'negativ');
select pg_temp.paastand('rutine_notat tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_notat where id = 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a'), 'negativ');
select pg_temp.skriv_tillatt('rutine_notat tablet_B1 INSERT B1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000001'', ''9f44182c-0000-4000-8000-00009f44182c'', date ''2026-01-01'' + 154, ''Sondenotat tablet_B1B1'')');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 INSERT B2', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''b1110000-0000-4000-8000-000000000002'', ''9f522fae-0000-4000-8000-00009f522fae'', date ''2026-01-01'' + 155, ''Sondenotat tablet_B1B2'')');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 INSERT A1', 'insert into public.rutine_notat (stasjon_id, rutine_id, dato, tekst) values (''a1110000-0000-4000-8000-000000000001'', ''9d8f3f8f-0000-4000-8000-00009d8f3f8f'', date ''2026-01-01'' + 156, ''Sondenotat tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_notat tablet_B1 UPDATE B1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 UPDATE B2', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''', 'rutine_notat', 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 UPDATE A1', 'update public.rutine_notat set tekst = ''Rettet notat'' where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_tillatt('rutine_notat tablet_B1 DELETE B1', 'delete from public.rutine_notat where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''');
select pg_temp.som_eier();
insert into public.rutine_notat (id, stasjon_id, rutine_id, dato, tekst) values ('cfdd6a49-0000-4000-8000-0000cfdd6a49', 'b1110000-0000-4000-8000-000000000001', '9f44182f-0000-4000-8000-00009f44182f', date '2026-01-01' + 157, 'Sondenotat gjentablet_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 DELETE B2', 'delete from public.rutine_notat where id = ''cfdd6a4a-0000-4000-8000-0000cfdd6a4a''', 'rutine_notat', 'cfdd6a4a-0000-4000-8000-0000cfdd6a4a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_notat('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 DELETE A1', 'delete from public.rutine_notat where id = ''cfdd6a2a-0000-4000-8000-0000cfdd6a2a''', 'rutine_notat', 'cfdd6a2a-0000-4000-8000-0000cfdd6a2a', 'id');
select pg_temp.skriv_avvist('rutine_notat tablet_B1 FLYTTER egen rad B1 -> B2', 'update public.rutine_notat set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''cfdd6a49-0000-4000-8000-0000cfdd6a49''', 'rutine_notat', 'cfdd6a49-0000-4000-8000-0000cfdd6a49', 'id');

-- =====================================================================
-- rutine_utforinger  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutine_utforinger');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutine_utforinger owner_A SELECT A1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A2 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88a-0000-4000-8000-00007d5cd88a'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT A3 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd88b-0000-4000-8000-00007d5cd88b'), 'positiv');
select pg_temp.paastand('rutine_utforinger owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42ab0-0000-4000-8000-00007eb42ab0'', date ''2026-01-01'' + 158)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec24232-0000-4000-8000-00007ec24232'', date ''2026-01-01'' + 159)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059c9-0000-4000-8000-00007ed059c9'', date ''2026-01-01'' + 160)');
select pg_temp.skriv_avvist('rutine_utforinger owner_A INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690367-0000-4000-8000-000080690367'', date ''2026-01-01'' + 161)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42ac9-0000-4000-8000-00007eb42ac9', date '2026-01-01' + 162);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec2424b-0000-4000-8000-00007ec2424b', date '2026-01-01' + 163);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_A DELETE A3', 'delete from public.rutine_utforinger where id = ''7d5cd88b-0000-4000-8000-00007d5cd88b''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88b-0000-4000-8000-00007d5cd88b', 'a1110000-0000-4000-8000-000000000003', '7ed059cd-0000-4000-8000-00007ed059cd', date '2026-01-01' + 164);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42acc-0000-4000-8000-00007eb42acc'', date ''2026-01-01'' + 165)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec2424e-0000-4000-8000-00007ec2424e'', date ''2026-01-01'' + 166)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059d0-0000-4000-8000-00007ed059d0'', date ''2026-01-01'' + 167)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''8069036e-0000-4000-8000-00008069036e'', date ''2026-01-01'' + 168)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42ad0-0000-4000-8000-00007eb42ad0', date '2026-01-01' + 169);
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
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42ae6-0000-4000-8000-00007eb42ae6'', date ''2026-01-01'' + 170)');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec24268-0000-4000-8000-00007ec24268'', date ''2026-01-01'' + 171)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059ea-0000-4000-8000-00007ed059ea'', date ''2026-01-01'' + 172)');
select pg_temp.skriv_avvist('rutine_utforinger manager_A12 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''80690388-0000-4000-8000-000080690388'', date ''2026-01-01'' + 173)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42aea-0000-4000-8000-00007eb42aea', date '2026-01-01' + 174);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutine_utforinger manager_A12 DELETE A2', 'delete from public.rutine_utforinger where id = ''7d5cd88a-0000-4000-8000-00007d5cd88a''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd88a-0000-4000-8000-00007d5cd88a', 'a1110000-0000-4000-8000-000000000002', '7ec2426c-0000-4000-8000-00007ec2426c', date '2026-01-01' + 175);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_A1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42aec-0000-4000-8000-00007eb42aec'', date ''2026-01-01'' + 176)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000002'', ''7ec2426e-0000-4000-8000-00007ec2426e'', date ''2026-01-01'' + 177)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT A3', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000003'', ''7ed059f0-0000-4000-8000-00007ed059f0'', date ''2026-01-01'' + 178)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_A1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''8069038e-0000-4000-8000-00008069038e'', date ''2026-01-01'' + 179)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd889-0000-4000-8000-00007d5cd889', 'a1110000-0000-4000-8000-000000000001', '7eb42b05-0000-4000-8000-00007eb42b05', date '2026-01-01' + 180);
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
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903a5-0000-4000-8000-0000806903a5'', date ''2026-01-01'' + 181)');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771b27-0000-4000-8000-000080771b27'', date ''2026-01-01'' + 182)');
select pg_temp.skriv_avvist('rutine_utforinger owner_B INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b08-0000-4000-8000-00007eb42b08'', date ''2026-01-01'' + 183)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '806903a8-0000-4000-8000-0000806903a8', date '2026-01-01' + 184);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutine_utforinger owner_B DELETE B2', 'delete from public.rutine_utforinger where id = ''7d5cd8a9-0000-4000-8000-00007d5cd8a9''');
select pg_temp.som_eier();
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a9-0000-4000-8000-00007d5cd8a9', 'b1110000-0000-4000-8000-000000000002', '80771b2a-0000-4000-8000-000080771b2a', date '2026-01-01' + 185);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutine_utforinger('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutine_utforinger owner_B DELETE A1', 'delete from public.rutine_utforinger where id = ''7d5cd889-0000-4000-8000-00007d5cd889''', 'rutine_utforinger', '7d5cd889-0000-4000-8000-00007d5cd889', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutine_utforinger where id = '7d5cd8a8-0000-4000-8000-00007d5cd8a8'), 'positiv');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd8a9-0000-4000-8000-00007d5cd8a9'), 'negativ');
select pg_temp.paastand('rutine_utforinger manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutine_utforinger where id = '7d5cd889-0000-4000-8000-00007d5cd889'), 'negativ');
select pg_temp.skriv_tillatt('rutine_utforinger manager_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903aa-0000-4000-8000-0000806903aa'', date ''2026-01-01'' + 186)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771b2c-0000-4000-8000-000080771b2c'', date ''2026-01-01'' + 187)');
select pg_temp.skriv_avvist('rutine_utforinger manager_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b0d-0000-4000-8000-00007eb42b0d'', date ''2026-01-01'' + 188)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '806903ad-0000-4000-8000-0000806903ad', date '2026-01-01' + 189);
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
select pg_temp.skriv_tillatt('rutine_utforinger tablet_B1 INSERT B1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000001'', ''806903c3-0000-4000-8000-0000806903c3'', date ''2026-01-01'' + 190)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT B2', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''b1110000-0000-4000-8000-000000000002'', ''80771b45-0000-4000-8000-000080771b45'', date ''2026-01-01'' + 191)');
select pg_temp.skriv_avvist('rutine_utforinger tablet_B1 INSERT A1', 'insert into public.rutine_utforinger (stasjon_id, rutine_id, dato) values (''a1110000-0000-4000-8000-000000000001'', ''7eb42b26-0000-4000-8000-00007eb42b26'', date ''2026-01-01'' + 192)');
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
insert into public.rutine_utforinger (id, stasjon_id, rutine_id, dato) values ('7d5cd8a8-0000-4000-8000-00007d5cd8a8', 'b1110000-0000-4000-8000-000000000001', '806903c6-0000-4000-8000-0000806903c6', date '2026-01-01' + 193);
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
-- rutineskjemaer  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('rutineskjemaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('rutineskjemaer owner_A SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT A2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT A3 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_AA1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema owner_AA2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema owner_AA3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer owner_A INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_AB1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutineskjemaer owner_A UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenowner_AA1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenowner_AA2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_A DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a579-0000-4000-8000-000027b1a579', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'morgen', 'Sondeskjema gjenowner_AA3', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('rutineskjemaer owner_A DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer owner_A FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A1A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_A1A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema manager_A1A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A1B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_A1A1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 FLYTTER egen rad A1 -> A2', 'update public.rutineskjemaer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A1 FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A12A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_A12A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema manager_A12A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_A12B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a577-0000-4000-8000-000027b1a577', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_A12A1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('rutineskjemaer manager_A12 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a578-0000-4000-8000-000027b1a578', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenmanager_A12A2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 FLYTTER egen rad A1 -> A3', 'update public.rutineskjemaer set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_A12 FLYTTER egen rad -> kjede B', 'update public.rutineskjemaer set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'positiv');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a578-0000-4000-8000-000027b1a578'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a579-0000-4000-8000-000027b1a579'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'negativ');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_A1A1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema tablet_A1A2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT A3', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''morgen'', ''Sondeskjema tablet_A1A3'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_A1B1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE A3', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A2', 'delete from public.rutineskjemaer where id = ''27b1a578-0000-4000-8000-000027b1a578''', 'rutineskjemaer', '27b1a578-0000-4000-8000-000027b1a578', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE A3', 'delete from public.rutineskjemaer where id = ''27b1a579-0000-4000-8000-000027b1a579''', 'rutineskjemaer', '27b1a579-0000-4000-8000-000027b1a579', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_A1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('rutineskjemaer owner_B SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_B SELECT B2 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'positiv');
select pg_temp.paastand('rutineskjemaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_BB1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema owner_BB2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer owner_B INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema owner_BA1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutineskjemaer owner_B UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenowner_BB1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('rutineskjemaer owner_B DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a597-0000-4000-8000-000027b1a597', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'morgen', 'Sondeskjema gjenowner_BB2', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('rutineskjemaer owner_B DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer owner_B FLYTTER egen rad -> kjede A', 'update public.rutineskjemaer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'negativ');
select pg_temp.paastand('rutineskjemaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_B1B1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema manager_B1B2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema manager_B1A1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('rutineskjemaer manager_B1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''');
select pg_temp.som_eier();
insert into public.rutineskjemaer (id, retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values ('27b1a596-0000-4000-8000-000027b1a596', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'morgen', 'Sondeskjema gjenmanager_B1B1', '06:00', '14:00');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 FLYTTER egen rad B1 -> B2', 'update public.rutineskjemaer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.skriv_avvist('rutineskjemaer manager_B1 FLYTTER egen rad -> kjede A', 'update public.rutineskjemaer set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT B1 -> ser', exists (select 1 from public.rutineskjemaer where id = '27b1a596-0000-4000-8000-000027b1a596'), 'positiv');
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a597-0000-4000-8000-000027b1a597'), 'negativ');
select pg_temp.paastand('rutineskjemaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.rutineskjemaer where id = '27b1a577-0000-4000-8000-000027b1a577'), 'negativ');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT B1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_B1B1'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT B2', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''morgen'', ''Sondeskjema tablet_B1B2'', ''06:00'', ''14:00'')');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 INSERT A1', 'insert into public.rutineskjemaer (retailer_id, stasjon_id, vakttype, navn, tid_start, tid_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''morgen'', ''Sondeskjema tablet_B1A1'', ''06:00'', ''14:00'')');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE B1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE B2', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 UPDATE A1', 'update public.rutineskjemaer set navn = ''endret av sonden'' where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE B1', 'delete from public.rutineskjemaer where id = ''27b1a596-0000-4000-8000-000027b1a596''', 'rutineskjemaer', '27b1a596-0000-4000-8000-000027b1a596', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE B2', 'delete from public.rutineskjemaer where id = ''27b1a597-0000-4000-8000-000027b1a597''', 'rutineskjemaer', '27b1a597-0000-4000-8000-000027b1a597', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_rutineskjemaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('rutineskjemaer tablet_B1 DELETE A1', 'delete from public.rutineskjemaer where id = ''27b1a577-0000-4000-8000-000027b1a577''', 'rutineskjemaer', '27b1a577-0000-4000-8000-000027b1a577', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 8/11: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 8/11: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
