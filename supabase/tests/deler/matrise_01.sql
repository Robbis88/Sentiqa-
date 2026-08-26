-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 1 AV 5. Hele matrisen er for stor for Supabase SQL
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

-- --- bemanning_vindu: forutsetninger og proberader ---
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 0, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 1, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 2, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 3, 6, 22, 1);
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 4, 6, 22, 1);

create or replace function pg_temp.nyrad_bemanning_vindu(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning)
  values (p_stasjon, 1, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 6, 22, 1)
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_krav: forutsetninger og proberader ---
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde fastA1');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde fastA2');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a6-0000-4000-8000-00005dec22a6', 'a1110000-0000-4000-8000-000000000003', 2, 8, 10, 2, 'Sonde fastA3');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde fastB1');
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c4-0000-4000-8000-00005dec22c4', 'b1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde fastB2');

create or replace function pg_temp.nyrad_bemanning_krav(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse)
  values (p_stasjon, 2, 8, 10, 2, 'Sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '')
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_fast_vakt: forutsetninger og proberader ---
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde fastA1', 3, date '2026-01-01' + 10, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde fastA2', 3, date '2026-01-01' + 11, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde fastA3', 3, date '2026-01-01' + 12, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde fastB1', 3, date '2026-01-01' + 13, 7, 15);
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde fastB2', 3, date '2026-01-01' + 14, 7, 15);

create or replace function pg_temp.nyrad_bemanning_fast_vakt(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time)
  values (p_stasjon, 'Sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 3, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 7, 15)
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_budsjett: forutsetninger og proberader ---
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
-- --- bemanning_aar: forutsetninger og proberader ---
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d612-0000-4000-8000-0000db98d612', 'b1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
-- --- bemanning_maned: forutsetninger og proberader ---
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
-- --- ansatt_avtale: forutsetninger og proberader ---
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'fastA1', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'fastA2', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de395-0000-4000-8000-00008b2de395', 'a1110000-0000-4000-8000-000000000003', 'fastA3', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'fastB1', 'Sonde Sondesen', 80);
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b3-0000-4000-8000-00008b2de3b3', 'b1110000-0000-4000-8000-000000000002', 'fastB2', 'Sonde Sondesen', 80);

create or replace function pg_temp.nyrad_ansatt_avtale(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent)
  values (p_stasjon, '' || p_merke || '-' || nextval('tenant_teller'::regclass) || '', 'Sonde Sondesen', 80)
  returning id into ny;
  return ny;
end $fn$;
-- --- bemanning_fravaer: forutsetninger og proberader ---
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 35, date '2026-01-01' + 35, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 36, date '2026-01-01' + 36, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 37, date '2026-01-01' + 37, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 38, date '2026-01-01' + 38, 'Sonde');
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 39, date '2026-01-01' + 39, 'Sonde');

create or replace function pg_temp.nyrad_bemanning_fravaer(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak)
  values (p_stasjon, 'Sonde Sondesen', date '2030-01-01' + nextval('tenant_teller'::regclass)::int, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, 'Sonde')
  returning id into ny;
  return ny;
end $fn$;

-- =====================================================================
-- bemanning_vindu  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_vindu');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_vindu owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 40, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 41, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 42, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_A INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 43, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_vindu owner_A UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 44, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 45, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_A DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28e-0000-4000-8000-0000f753c28e', 'a1110000-0000-4000-8000-000000000003', 1, date '2026-01-01' + 46, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_vindu owner_A DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 47, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 48, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 49, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 50, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 51, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_vindu set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 52, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 53, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 54, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 55, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28c-0000-4000-8000-0000f753c28c', 'a1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 56, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_vindu manager_A12 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c28d-0000-4000-8000-0000f753c28d', 'a1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 57, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_vindu set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'positiv');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28d-0000-4000-8000-0000f753c28d'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28e-0000-4000-8000-0000f753c28e'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'negativ');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 58, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 59, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT A3', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000003'', 1, date ''2026-01-01'' + 60, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 61, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE A3', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A2', 'delete from public.bemanning_vindu where id = ''f753c28d-0000-4000-8000-0000f753c28d''', 'bemanning_vindu', 'f753c28d-0000-4000-8000-0000f753c28d', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE A3', 'delete from public.bemanning_vindu where id = ''f753c28e-0000-4000-8000-0000f753c28e''', 'bemanning_vindu', 'f753c28e-0000-4000-8000-0000f753c28e', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_A1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_vindu owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'positiv');
select pg_temp.paastand('bemanning_vindu owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 62, 6, 22, 1)');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 63, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu owner_B INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 64, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 65, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_vindu owner_B DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ac-0000-4000-8000-0000f753c2ac', 'b1110000-0000-4000-8000-000000000002', 1, date '2026-01-01' + 66, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_vindu owner_B DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 67, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 68, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 69, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_vindu manager_B1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''');
select pg_temp.som_eier();
insert into public.bemanning_vindu (id, stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values ('f753c2ab-0000-4000-8000-0000f753c2ab', 'b1110000-0000-4000-8000-000000000001', 1, date '2026-01-01' + 70, 6, 22, 1);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.skriv_avvist('bemanning_vindu manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_vindu set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_vindu where id = 'f753c2ab-0000-4000-8000-0000f753c2ab'), 'positiv');
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c2ac-0000-4000-8000-0000f753c2ac'), 'negativ');
select pg_temp.paastand('bemanning_vindu tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_vindu where id = 'f753c28c-0000-4000-8000-0000f753c28c'), 'negativ');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 71, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT B2', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''b1110000-0000-4000-8000-000000000002'', 1, date ''2026-01-01'' + 72, 6, 22, 1)');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 INSERT A1', 'insert into public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra, fra_time, til_time, min_bemanning) values (''a1110000-0000-4000-8000-000000000001'', 1, date ''2026-01-01'' + 73, 6, 22, 1)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE B1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE B2', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 UPDATE A1', 'update public.bemanning_vindu set min_bemanning = 2 where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE B1', 'delete from public.bemanning_vindu where id = ''f753c2ab-0000-4000-8000-0000f753c2ab''', 'bemanning_vindu', 'f753c2ab-0000-4000-8000-0000f753c2ab', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE B2', 'delete from public.bemanning_vindu where id = ''f753c2ac-0000-4000-8000-0000f753c2ac''', 'bemanning_vindu', 'f753c2ac-0000-4000-8000-0000f753c2ac', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_vindu('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_vindu tablet_B1 DELETE A1', 'delete from public.bemanning_vindu where id = ''f753c28c-0000-4000-8000-0000f753c28c''', 'bemanning_vindu', 'f753c28c-0000-4000-8000-0000f753c28c', 'id');

-- =====================================================================
-- bemanning_krav  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_krav');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_krav owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_AA1'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde owner_AA2'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_A INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde owner_AA3'')');
select pg_temp.skriv_avvist('bemanning_krav owner_A INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_AB1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_krav owner_A UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenowner_AA2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_krav owner_A DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a6-0000-4000-8000-00005dec22a6', 'a1110000-0000-4000-8000-000000000003', 2, 8, 10, 2, 'Sonde gjenowner_AA3');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_krav owner_A DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A1A1'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_A1A2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde manager_A1A3'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_krav manager_A1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_A1A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_krav set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A12A1'')');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_A12A2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde manager_A12A3'')');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_A12B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a4-0000-4000-8000-00005dec22a4', 'a1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_A12A1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_krav manager_A12 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22a5-0000-4000-8000-00005dec22a5', 'a1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenmanager_A12A2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_krav set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'positiv');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a5-0000-4000-8000-00005dec22a5'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a6-0000-4000-8000-00005dec22a6'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'negativ');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_A1A1'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde tablet_A1A2'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT A3', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000003'', 2, 8, 10, 2, ''Sonde tablet_A1A3'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_A1B1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE A3', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A2', 'delete from public.bemanning_krav where id = ''5dec22a5-0000-4000-8000-00005dec22a5''', 'bemanning_krav', '5dec22a5-0000-4000-8000-00005dec22a5', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE A3', 'delete from public.bemanning_krav where id = ''5dec22a6-0000-4000-8000-00005dec22a6''', 'bemanning_krav', '5dec22a6-0000-4000-8000-00005dec22a6', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_krav tablet_A1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_krav owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'positiv');
select pg_temp.paastand('bemanning_krav owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav owner_B INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_BB1'')');
select pg_temp.skriv_tillatt('bemanning_krav owner_B INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde owner_BB2'')');
select pg_temp.skriv_avvist('bemanning_krav owner_B INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde owner_BA1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_krav owner_B UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_krav owner_B DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c4-0000-4000-8000-00005dec22c4', 'b1110000-0000-4000-8000-000000000002', 2, 8, 10, 2, 'Sonde gjenowner_BB2');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_krav owner_B DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_krav manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'negativ');
select pg_temp.paastand('bemanning_krav manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_B1B1'')');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde manager_B1B2'')');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde manager_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_krav manager_B1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''');
select pg_temp.som_eier();
insert into public.bemanning_krav (id, stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values ('5dec22c3-0000-4000-8000-00005dec22c3', 'b1110000-0000-4000-8000-000000000001', 2, 8, 10, 2, 'Sonde gjenmanager_B1B1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.skriv_avvist('bemanning_krav manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_krav set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_krav where id = '5dec22c3-0000-4000-8000-00005dec22c3'), 'positiv');
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22c4-0000-4000-8000-00005dec22c4'), 'negativ');
select pg_temp.paastand('bemanning_krav tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_krav where id = '5dec22a4-0000-4000-8000-00005dec22a4'), 'negativ');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT B1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_B1B1'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT B2', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''b1110000-0000-4000-8000-000000000002'', 2, 8, 10, 2, ''Sonde tablet_B1B2'')');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 INSERT A1', 'insert into public.bemanning_krav (stasjon_id, ukedag, fra_time, til_time, antall, begrunnelse) values (''a1110000-0000-4000-8000-000000000001'', 2, 8, 10, 2, ''Sonde tablet_B1A1'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE B1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE B2', 'update public.bemanning_krav set antall = 3 where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 UPDATE A1', 'update public.bemanning_krav set antall = 3 where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE B1', 'delete from public.bemanning_krav where id = ''5dec22c3-0000-4000-8000-00005dec22c3''', 'bemanning_krav', '5dec22c3-0000-4000-8000-00005dec22c3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE B2', 'delete from public.bemanning_krav where id = ''5dec22c4-0000-4000-8000-00005dec22c4''', 'bemanning_krav', '5dec22c4-0000-4000-8000-00005dec22c4', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_krav('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_krav tablet_B1 DELETE A1', 'delete from public.bemanning_krav where id = ''5dec22a4-0000-4000-8000-00005dec22a4''', 'bemanning_krav', '5dec22a4-0000-4000-8000-00005dec22a4', 'id');

-- =====================================================================
-- bemanning_fast_vakt  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fast_vakt');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_AA1'', 3, date ''2026-01-01'' + 108, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde owner_AA2'', 3, date ''2026-01-01'' + 109, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde owner_AA3'', 3, date ''2026-01-01'' + 110, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_AB1'', 3, date ''2026-01-01'' + 111, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_AA1', 3, date '2026-01-01' + 112, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_AA2', 3, date '2026-01-01' + 113, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_A DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef9-0000-4000-8000-0000e15ccef9', 'a1110000-0000-4000-8000-000000000003', 'Sonde gjenowner_AA3', 3, date '2026-01-01' + 114, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_A DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1A1'', 3, date ''2026-01-01'' + 115, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A1A2'', 3, date ''2026-01-01'' + 116, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A1A3'', 3, date ''2026-01-01'' + 117, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A1B1'', 3, date ''2026-01-01'' + 118, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A1A1', 3, date '2026-01-01' + 119, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_fast_vakt set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12A1'', 3, date ''2026-01-01'' + 120, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde manager_A12A2'', 3, date ''2026-01-01'' + 121, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde manager_A12A3'', 3, date ''2026-01-01'' + 122, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_A12B1'', 3, date ''2026-01-01'' + 123, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef7-0000-4000-8000-0000e15ccef7', 'a1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_A12A1', 3, date '2026-01-01' + 124, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_A12 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccef8-0000-4000-8000-0000e15ccef8', 'a1110000-0000-4000-8000-000000000002', 'Sonde gjenmanager_A12A2', 3, date '2026-01-01' + 125, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_fast_vakt set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef8-0000-4000-8000-0000e15ccef8'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef9-0000-4000-8000-0000e15ccef9'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1A1'', 3, date ''2026-01-01'' + 126, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde tablet_A1A2'', 3, date ''2026-01-01'' + 127, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT A3', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde tablet_A1A3'', 3, date ''2026-01-01'' + 128, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_A1B1'', 3, date ''2026-01-01'' + 129, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE A3', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A2', 'delete from public.bemanning_fast_vakt where id = ''e15ccef8-0000-4000-8000-0000e15ccef8''', 'bemanning_fast_vakt', 'e15ccef8-0000-4000-8000-0000e15ccef8', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE A3', 'delete from public.bemanning_fast_vakt where id = ''e15ccef9-0000-4000-8000-0000e15ccef9''', 'bemanning_fast_vakt', 'e15ccef9-0000-4000-8000-0000e15ccef9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_A1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde owner_BB1'', 3, date ''2026-01-01'' + 130, 7, 15)');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde owner_BB2'', 3, date ''2026-01-01'' + 131, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde owner_BA1'', 3, date ''2026-01-01'' + 132, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenowner_BB1', 3, date '2026-01-01' + 133, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fast_vakt owner_B DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf17-0000-4000-8000-0000e15ccf17', 'b1110000-0000-4000-8000-000000000002', 'Sonde gjenowner_BB2', 3, date '2026-01-01' + 134, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fast_vakt owner_B DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1B1'', 3, date ''2026-01-01'' + 135, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde manager_B1B2'', 3, date ''2026-01-01'' + 136, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde manager_B1A1'', 3, date ''2026-01-01'' + 137, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fast_vakt manager_B1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''');
select pg_temp.som_eier();
insert into public.bemanning_fast_vakt (id, stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values ('e15ccf16-0000-4000-8000-0000e15ccf16', 'b1110000-0000-4000-8000-000000000001', 'Sonde gjenmanager_B1B1', 3, date '2026-01-01' + 138, 7, 15);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.skriv_avvist('bemanning_fast_vakt manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_fast_vakt set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf16-0000-4000-8000-0000e15ccf16'), 'positiv');
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccf17-0000-4000-8000-0000e15ccf17'), 'negativ');
select pg_temp.paastand('bemanning_fast_vakt tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fast_vakt where id = 'e15ccef7-0000-4000-8000-0000e15ccef7'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1B1'', 3, date ''2026-01-01'' + 139, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT B2', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde tablet_B1B2'', 3, date ''2026-01-01'' + 140, 7, 15)');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 INSERT A1', 'insert into public.bemanning_fast_vakt (stasjon_id, navn, ukedag, gjelder_fra, fra_time, til_time) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde tablet_B1A1'', 3, date ''2026-01-01'' + 141, 7, 15)');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE B1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE B2', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 UPDATE A1', 'update public.bemanning_fast_vakt set til_time = 16 where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE B1', 'delete from public.bemanning_fast_vakt where id = ''e15ccf16-0000-4000-8000-0000e15ccf16''', 'bemanning_fast_vakt', 'e15ccf16-0000-4000-8000-0000e15ccf16', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE B2', 'delete from public.bemanning_fast_vakt where id = ''e15ccf17-0000-4000-8000-0000e15ccf17''', 'bemanning_fast_vakt', 'e15ccf17-0000-4000-8000-0000e15ccf17', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fast_vakt('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fast_vakt tablet_B1 DELETE A1', 'delete from public.bemanning_fast_vakt where id = ''e15ccef7-0000-4000-8000-0000e15ccef7''', 'bemanning_fast_vakt', 'e15ccef7-0000-4000-8000-0000e15ccef7', 'id');

-- =====================================================================
-- bemanning_budsjett  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_budsjett');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_A DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_A DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_A12 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT A3', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE A3', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A2', 'delete from public.bemanning_budsjett where id = ''c4b6d3e6-0000-4000-8000-0000c4b6d3e6''', 'bemanning_budsjett', 'c4b6d3e6-0000-4000-8000-0000c4b6d3e6', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE A3', 'delete from public.bemanning_budsjett where id = ''c4b6d3e7-0000-4000-8000-0000c4b6d3e7''', 'bemanning_budsjett', 'c4b6d3e7-0000-4000-8000-0000c4b6d3e7', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_A1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_budsjett owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'positiv');
select pg_temp.paastand('bemanning_budsjett owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_budsjett owner_B DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''');
select pg_temp.som_eier();
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_budsjett owner_B DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'negativ');
select pg_temp.paastand('bemanning_budsjett manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett manager_B1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d404-0000-4000-8000-0000c4b6d404'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d405-0000-4000-8000-0000c4b6d405'), 'negativ');
select pg_temp.paastand('bemanning_budsjett tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_budsjett where id = 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT B1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d404-0000-4000-8000-0000c4b6d404', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT B2', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d405-0000-4000-8000-0000c4b6d405', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 INSERT A1', 'insert into public.bemanning_budsjett (stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 1000, 400000, 900000)');
select pg_temp.som_eier();
delete from public.bemanning_budsjett where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_budsjett (id, stasjon_id, ar, maned, timer, lonn_kr, brutto_bp_kr) values ('c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 1000, 400000, 900000);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE B1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE B2', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 UPDATE A1', 'update public.bemanning_budsjett set timer = 1100 where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE B1', 'delete from public.bemanning_budsjett where id = ''c4b6d404-0000-4000-8000-0000c4b6d404''', 'bemanning_budsjett', 'c4b6d404-0000-4000-8000-0000c4b6d404', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE B2', 'delete from public.bemanning_budsjett where id = ''c4b6d405-0000-4000-8000-0000c4b6d405''', 'bemanning_budsjett', 'c4b6d405-0000-4000-8000-0000c4b6d405', 'id');
select pg_temp.skriv_avvist('bemanning_budsjett tablet_B1 DELETE A1', 'delete from public.bemanning_budsjett where id = ''c4b6d3e5-0000-4000-8000-0000c4b6d3e5''', 'bemanning_budsjett', 'c4b6d3e5-0000-4000-8000-0000c4b6d3e5', 'id');

-- =====================================================================
-- bemanning_aar  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_aar');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_aar owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'positiv');
select pg_temp.paastand('bemanning_aar owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_aar where id = 'db98d5f3-0000-4000-8000-0000db98d5f3'), 'positiv');
select pg_temp.paastand('bemanning_aar owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_aar where id = 'db98d5f4-0000-4000-8000-0000db98d5f4'), 'positiv');
select pg_temp.paastand('bemanning_aar owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A INSERT A2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A INSERT A3', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_aar owner_A INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''');
select pg_temp.skriv_tillatt('bemanning_aar owner_A UPDATE A2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''');
select pg_temp.skriv_tillatt('bemanning_aar owner_A UPDATE A3', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''');
select pg_temp.skriv_avvist('bemanning_aar owner_A UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_tillatt('bemanning_aar owner_A DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''');
select pg_temp.som_eier();
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A DELETE A2', 'delete from public.bemanning_aar where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''');
select pg_temp.som_eier();
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_aar owner_A DELETE A3', 'delete from public.bemanning_aar where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''');
select pg_temp.som_eier();
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_aar owner_A DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_aar manager_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f3-0000-4000-8000-0000db98d5f3'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f4-0000-4000-8000-0000db98d5f4'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 INSERT A2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 INSERT A3', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 UPDATE A2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 UPDATE A3', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 DELETE A2', 'delete from public.bemanning_aar where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 DELETE A3', 'delete from public.bemanning_aar where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A1 DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_aar manager_A12 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A12 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f3-0000-4000-8000-0000db98d5f3'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f4-0000-4000-8000-0000db98d5f4'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 INSERT A2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 INSERT A3', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 UPDATE A2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 UPDATE A3', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 DELETE A2', 'delete from public.bemanning_aar where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 DELETE A3', 'delete from public.bemanning_aar where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_A12 DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_aar tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.paastand('bemanning_aar tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f3-0000-4000-8000-0000db98d5f3'), 'negativ');
select pg_temp.paastand('bemanning_aar tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f4-0000-4000-8000-0000db98d5f4'), 'negativ');
select pg_temp.paastand('bemanning_aar tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 INSERT A2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f3-0000-4000-8000-0000db98d5f3', 'a1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 INSERT A3', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f4-0000-4000-8000-0000db98d5f4', 'a1110000-0000-4000-8000-000000000003', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 UPDATE A2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 UPDATE A3', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 DELETE A2', 'delete from public.bemanning_aar where id = ''db98d5f3-0000-4000-8000-0000db98d5f3''', 'bemanning_aar', 'db98d5f3-0000-4000-8000-0000db98d5f3', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 DELETE A3', 'delete from public.bemanning_aar where id = ''db98d5f4-0000-4000-8000-0000db98d5f4''', 'bemanning_aar', 'db98d5f4-0000-4000-8000-0000db98d5f4', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_A1 DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_aar owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'positiv');
select pg_temp.paastand('bemanning_aar owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_aar where id = 'db98d612-0000-4000-8000-0000db98d612'), 'positiv');
select pg_temp.paastand('bemanning_aar owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_aar owner_B INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_aar owner_B INSERT B2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d612-0000-4000-8000-0000db98d612', 'b1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_aar owner_B INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_aar owner_B UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''');
select pg_temp.skriv_tillatt('bemanning_aar owner_B UPDATE B2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d612-0000-4000-8000-0000db98d612''');
select pg_temp.skriv_avvist('bemanning_aar owner_B UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_tillatt('bemanning_aar owner_B DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''');
select pg_temp.som_eier();
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_aar owner_B DELETE B2', 'delete from public.bemanning_aar where id = ''db98d612-0000-4000-8000-0000db98d612''');
select pg_temp.som_eier();
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d612-0000-4000-8000-0000db98d612', 'b1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_aar owner_B DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_aar manager_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d612-0000-4000-8000-0000db98d612'), 'negativ');
select pg_temp.paastand('bemanning_aar manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 INSERT B2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d612-0000-4000-8000-0000db98d612', 'b1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 UPDATE B2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d612-0000-4000-8000-0000db98d612''', 'bemanning_aar', 'db98d612-0000-4000-8000-0000db98d612', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 DELETE B2', 'delete from public.bemanning_aar where id = ''db98d612-0000-4000-8000-0000db98d612''', 'bemanning_aar', 'db98d612-0000-4000-8000-0000db98d612', 'id');
select pg_temp.skriv_avvist('bemanning_aar manager_B1 DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_aar tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d611-0000-4000-8000-0000db98d611'), 'negativ');
select pg_temp.paastand('bemanning_aar tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d612-0000-4000-8000-0000db98d612'), 'negativ');
select pg_temp.paastand('bemanning_aar tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_aar where id = 'db98d5f2-0000-4000-8000-0000db98d5f2'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 INSERT B1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d611-0000-4000-8000-0000db98d611', 'b1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 INSERT B2', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d612-0000-4000-8000-0000db98d612', 'b1110000-0000-4000-8000-000000000002', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 INSERT A1', 'insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 12000, 1800)');
select pg_temp.som_eier();
delete from public.bemanning_aar where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_aar (id, stasjon_id, ar, timer_aar, fast_arsverk_timer) values ('db98d5f2-0000-4000-8000-0000db98d5f2', 'a1110000-0000-4000-8000-000000000001', 2026, 12000, 1800);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 UPDATE B1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 UPDATE B2', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d612-0000-4000-8000-0000db98d612''', 'bemanning_aar', 'db98d612-0000-4000-8000-0000db98d612', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 UPDATE A1', 'update public.bemanning_aar set timer_aar = 12500 where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 DELETE B1', 'delete from public.bemanning_aar where id = ''db98d611-0000-4000-8000-0000db98d611''', 'bemanning_aar', 'db98d611-0000-4000-8000-0000db98d611', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 DELETE B2', 'delete from public.bemanning_aar where id = ''db98d612-0000-4000-8000-0000db98d612''', 'bemanning_aar', 'db98d612-0000-4000-8000-0000db98d612', 'id');
select pg_temp.skriv_avvist('bemanning_aar tablet_B1 DELETE A1', 'delete from public.bemanning_aar where id = ''db98d5f2-0000-4000-8000-0000db98d5f2''', 'bemanning_aar', 'db98d5f2-0000-4000-8000-0000db98d5f2', 'id');

-- =====================================================================
-- bemanning_maned  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_maned');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_maned owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_maned owner_A INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''');
select pg_temp.skriv_tillatt('bemanning_maned owner_A UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''');
select pg_temp.skriv_avvist('bemanning_maned owner_A UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_maned owner_A DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_maned owner_A DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_A12 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'positiv');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1a-0000-4000-8000-000072e96f1a'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f1b-0000-4000-8000-000072e96f1b'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1a-0000-4000-8000-000072e96f1a', 'a1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT A3', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000003'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000003';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f1b-0000-4000-8000-000072e96f1b', 'a1110000-0000-4000-8000-000000000003', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE A3', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A2', 'delete from public.bemanning_maned where id = ''72e96f1a-0000-4000-8000-000072e96f1a''', 'bemanning_maned', '72e96f1a-0000-4000-8000-000072e96f1a', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE A3', 'delete from public.bemanning_maned where id = ''72e96f1b-0000-4000-8000-000072e96f1b''', 'bemanning_maned', '72e96f1b-0000-4000-8000-000072e96f1b', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_A1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_maned owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'positiv');
select pg_temp.paastand('bemanning_maned owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_maned owner_B INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''');
select pg_temp.skriv_tillatt('bemanning_maned owner_B UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''');
select pg_temp.skriv_avvist('bemanning_maned owner_B UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_tillatt('bemanning_maned owner_B DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_maned owner_B DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''');
select pg_temp.som_eier();
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_maned owner_B DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_maned manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'negativ');
select pg_temp.paastand('bemanning_maned manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned manager_B1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_maned where id = '72e96f38-0000-4000-8000-000072e96f38'), 'positiv');
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f39-0000-4000-8000-000072e96f39'), 'negativ');
select pg_temp.paastand('bemanning_maned tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_maned where id = '72e96f19-0000-4000-8000-000072e96f19'), 'negativ');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT B1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f38-0000-4000-8000-000072e96f38', 'b1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT B2', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''b1110000-0000-4000-8000-000000000002'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'b1110000-0000-4000-8000-000000000002';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f39-0000-4000-8000-000072e96f39', 'b1110000-0000-4000-8000-000000000002', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 INSERT A1', 'insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values (''a1110000-0000-4000-8000-000000000001'', 2026, 8, 950)');
select pg_temp.som_eier();
delete from public.bemanning_maned where stasjon_id = 'a1110000-0000-4000-8000-000000000001';
insert into public.bemanning_maned (id, stasjon_id, ar, maned, disponible_timer) values ('72e96f19-0000-4000-8000-000072e96f19', 'a1110000-0000-4000-8000-000000000001', 2026, 8, 950);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE B1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE B2', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 UPDATE A1', 'update public.bemanning_maned set disponible_timer = 900 where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE B1', 'delete from public.bemanning_maned where id = ''72e96f38-0000-4000-8000-000072e96f38''', 'bemanning_maned', '72e96f38-0000-4000-8000-000072e96f38', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE B2', 'delete from public.bemanning_maned where id = ''72e96f39-0000-4000-8000-000072e96f39''', 'bemanning_maned', '72e96f39-0000-4000-8000-000072e96f39', 'id');
select pg_temp.skriv_avvist('bemanning_maned tablet_B1 DELETE A1', 'delete from public.bemanning_maned where id = ''72e96f19-0000-4000-8000-000072e96f19''', 'bemanning_maned', '72e96f19-0000-4000-8000-000072e96f19', 'id');

-- =====================================================================
-- ansatt_avtale  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('ansatt_avtale');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('ansatt_avtale owner_A SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT A2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT A3 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale owner_A INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_avtale owner_A UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenowner_AA1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'gjenowner_AA2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_A DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de395-0000-4000-8000-00008b2de395', 'a1110000-0000-4000-8000-000000000003', 'gjenowner_AA3', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('ansatt_avtale owner_A DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A1A1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_A1 FLYTTER egen rad A1 -> A2', 'update public.ansatt_avtale set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de393-0000-4000-8000-00008b2de393', 'a1110000-0000-4000-8000-000000000001', 'gjenmanager_A12A1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('ansatt_avtale manager_A12 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de394-0000-4000-8000-00008b2de394', 'a1110000-0000-4000-8000-000000000002', 'gjenmanager_A12A2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_A12 FLYTTER egen rad A1 -> A3', 'update public.ansatt_avtale set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de394-0000-4000-8000-00008b2de394'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de395-0000-4000-8000-00008b2de395'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT A3', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE A3', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A2', 'delete from public.ansatt_avtale where id = ''8b2de394-0000-4000-8000-00008b2de394''', 'ansatt_avtale', '8b2de394-0000-4000-8000-00008b2de394', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE A3', 'delete from public.ansatt_avtale where id = ''8b2de395-0000-4000-8000-00008b2de395''', 'ansatt_avtale', '8b2de395-0000-4000-8000-00008b2de395', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_A1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('ansatt_avtale owner_B SELECT B1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_B SELECT B2 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'positiv');
select pg_temp.paastand('ansatt_avtale owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale owner_B INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_avtale owner_B UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'gjenowner_BB1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('ansatt_avtale owner_B DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b3-0000-4000-8000-00008b2de3b3', 'b1110000-0000-4000-8000-000000000002', 'gjenowner_BB2', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('ansatt_avtale owner_B DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT B1 -> ser', exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'positiv');
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'negativ');
select pg_temp.paastand('ansatt_avtale manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('ansatt_avtale manager_B1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''');
select pg_temp.som_eier();
insert into public.ansatt_avtale (id, stasjon_id, ansatt_nr, navn, stillingsprosent) values ('8b2de3b2-0000-4000-8000-00008b2de3b2', 'b1110000-0000-4000-8000-000000000001', 'gjenmanager_B1B1', 'Sonde Sondesen', 80);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.skriv_avvist('ansatt_avtale manager_B1 FLYTTER egen rad B1 -> B2', 'update public.ansatt_avtale set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b2-0000-4000-8000-00008b2de3b2'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de3b3-0000-4000-8000-00008b2de3b3'), 'negativ');
select pg_temp.paastand('ansatt_avtale tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.ansatt_avtale where id = '8b2de393-0000-4000-8000-00008b2de393'), 'negativ');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT B1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT B2', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''Sonde Sondesen'', 80)');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 INSERT A1', 'insert into public.ansatt_avtale (stasjon_id, ansatt_nr, navn, stillingsprosent) values (''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''Sonde Sondesen'', 80)');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE B1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE B2', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 UPDATE A1', 'update public.ansatt_avtale set stillingsprosent = 90 where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE B1', 'delete from public.ansatt_avtale where id = ''8b2de3b2-0000-4000-8000-00008b2de3b2''', 'ansatt_avtale', '8b2de3b2-0000-4000-8000-00008b2de3b2', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE B2', 'delete from public.ansatt_avtale where id = ''8b2de3b3-0000-4000-8000-00008b2de3b3''', 'ansatt_avtale', '8b2de3b3-0000-4000-8000-00008b2de3b3', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_ansatt_avtale('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('ansatt_avtale tablet_B1 DELETE A1', 'delete from public.ansatt_avtale where id = ''8b2de393-0000-4000-8000-00008b2de393''', 'ansatt_avtale', '8b2de393-0000-4000-8000-00008b2de393', 'id');

-- =====================================================================
-- bemanning_fravaer  (station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('bemanning_fravaer');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT A3 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 341, date ''2026-01-01'' + 341, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 342, date ''2026-01-01'' + 342, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 343, date ''2026-01-01'' + 343, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 344, date ''2026-01-01'' + 344, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 345, date '2026-01-01' + 345, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 346, date '2026-01-01' + 346, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_A DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-01-01' + 347, date '2026-01-01' + 347, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_A DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 348, date ''2026-01-01'' + 348, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 349, date ''2026-01-01'' + 349, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 350, date ''2026-01-01'' + 350, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 351, date ''2026-01-01'' + 351, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 352, date '2026-01-01' + 352, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A1 FLYTTER egen rad A1 -> A2', 'update public.bemanning_fravaer set stasjon_id = ''a1110000-0000-4000-8000-000000000002'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 353, date ''2026-01-01'' + 353, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 354, date ''2026-01-01'' + 354, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 355, date ''2026-01-01'' + 355, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 356, date ''2026-01-01'' + 356, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 357, date '2026-01-01' + 357, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_A12 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 358, date '2026-01-01' + 358, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_A12 FLYTTER egen rad A1 -> A3', 'update public.bemanning_fravaer set stasjon_id = ''a1110000-0000-4000-8000-000000000003'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 359, date ''2026-01-01'' + 359, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 360, date ''2026-01-01'' + 360, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT A3', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000003'', ''Sonde Sondesen'', date ''2026-01-01'' + 361, date ''2026-01-01'' + 361, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 362, date ''2026-01-01'' + 362, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE A3', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ce-0000-4000-8000-0000ebd5f3ce''', 'bemanning_fravaer', 'ebd5f3ce-0000-4000-8000-0000ebd5f3ce', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE A3', 'delete from public.bemanning_fravaer where id = ''ebd5f3cf-0000-4000-8000-0000ebd5f3cf''', 'bemanning_fravaer', 'ebd5f3cf-0000-4000-8000-0000ebd5f3cf', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_A1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('bemanning_fravaer owner_B SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_B SELECT B2 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'positiv');
select pg_temp.paastand('bemanning_fravaer owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 363, date ''2026-01-01'' + 363, ''Sonde'')');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 364, date ''2026-01-01'' + 364, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 365, date ''2026-01-01'' + 365, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 366, date '2026-01-01' + 366, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('bemanning_fravaer owner_B DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-01-01' + 367, date '2026-01-01' + 367, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('bemanning_fravaer owner_B DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B1 -> ser', exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'positiv');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 368, date ''2026-01-01'' + 368, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 369, date ''2026-01-01'' + 369, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 370, date ''2026-01-01'' + 370, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_tillatt('bemanning_fravaer manager_B1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''');
select pg_temp.som_eier();
insert into public.bemanning_fravaer (id, stasjon_id, navn, fra_dato, til_dato, arsak) values ('ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-01-01' + 371, date '2026-01-01' + 371, 'Sonde');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.skriv_avvist('bemanning_fravaer manager_B1 FLYTTER egen rad B1 -> B2', 'update public.bemanning_fravaer set stasjon_id = ''b1110000-0000-4000-8000-000000000002'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed'), 'negativ');
select pg_temp.paastand('bemanning_fravaer tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.bemanning_fravaer where id = 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd'), 'negativ');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 372, date ''2026-01-01'' + 372, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT B2', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''b1110000-0000-4000-8000-000000000002'', ''Sonde Sondesen'', date ''2026-01-01'' + 373, date ''2026-01-01'' + 373, ''Sonde'')');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 INSERT A1', 'insert into public.bemanning_fravaer (stasjon_id, navn, fra_dato, til_dato, arsak) values (''a1110000-0000-4000-8000-000000000001'', ''Sonde Sondesen'', date ''2026-01-01'' + 374, date ''2026-01-01'' + 374, ''Sonde'')');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE B1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE B2', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 UPDATE A1', 'update public.bemanning_fravaer set arsak = ''endret av sonden'' where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE B1', 'delete from public.bemanning_fravaer where id = ''ebd5f3ec-0000-4000-8000-0000ebd5f3ec''', 'bemanning_fravaer', 'ebd5f3ec-0000-4000-8000-0000ebd5f3ec', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE B2', 'delete from public.bemanning_fravaer where id = ''ebd5f3ed-0000-4000-8000-0000ebd5f3ed''', 'bemanning_fravaer', 'ebd5f3ed-0000-4000-8000-0000ebd5f3ed', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_bemanning_fravaer('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('bemanning_fravaer tablet_B1 DELETE A1', 'delete from public.bemanning_fravaer where id = ''ebd5f3cd-0000-4000-8000-0000ebd5f3cd''', 'bemanning_fravaer', 'ebd5f3cd-0000-4000-8000-0000ebd5f3cd', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 1/5: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 1/5: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
