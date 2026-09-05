-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 5 AV 10. Hele matrisen er for stor for Supabase SQL
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
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f758c57b-0000-4000-8000-0000f758c57b', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f758c93d-0000-4000-8000-0000f758c93d', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f758ccff-0000-4000-8000-0000f758ccff', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort fastA3', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f75939dd-0000-4000-8000-0000f75939dd', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f7593d9f-0000-4000-8000-0000f7593d9f', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort fastB2', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86d940e-0000-4000-8000-0000a86d940e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e086e-0000-4000-8000-0000a86e086e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a86e7cce-0000-4000-8000-0000a86e7cce', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87bab92-0000-4000-8000-0000a87bab92', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('a87c1ff2-0000-4000-8000-0000a87c1ff2', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e018603-0000-4000-8000-00009e018603', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1827a38f-0000-4000-8000-00001827a38f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e01fa63-0000-4000-8000-00009e01fa63', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('182817ef-0000-4000-8000-0000182817ef', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e026ec3-0000-4000-8000-00009e026ec3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18288c4f-0000-4000-8000-000018288c4f', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e0f9d87-0000-4000-8000-00009e0f9d87', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('1835bb13-0000-4000-8000-00001835bb13', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('9e1011e7-0000-4000-8000-00009e1011e7', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('18362f73-0000-4000-8000-000018362f73', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea91-0000-4000-8000-0000f3bfea91', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0213-0000-4000-8000-0000f3ce0213', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_AB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea93-0000-4000-8000-0000f3bfea93', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_AA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea94-0000-4000-8000-0000f3bfea94', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0216-0000-4000-8000-0000f3ce0216', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea96-0000-4000-8000-0000f3bfea96', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_A12A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0218-0000-4000-8000-0000f3ce0218', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_A12B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfea98-0000-4000-8000-0000f3bfea98', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce021a-0000-4000-8000-0000f3ce021a', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_A1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce021b-0000-4000-8000-0000f3ce021b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort owner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfeab0-0000-4000-8000-0000f3bfeab0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort owner_BA1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0232-0000-4000-8000-0000f3ce0232', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort gjenowner_BB1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0233-0000-4000-8000-0000f3ce0233', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort manager_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfeab3-0000-4000-8000-0000f3bfeab3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort manager_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3ce0235-0000-4000-8000-0000f3ce0235', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1B1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef) values ('f3bfeab5-0000-4000-8000-0000f3bfeab5', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekort tablet_B1A1', 'omsetning', 'maaned', 'hoy', true, true);
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea42-0000-4000-8000-00006544ea42', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655301c4-0000-4000-8000-0000655301c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611946-0000-4000-8000-000065611946', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c2e4-0000-4000-8000-000066f9c2e4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea46-0000-4000-8000-00006544ea46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655301c8-0000-4000-8000-0000655301c8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6561194a-0000-4000-8000-00006561194a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea49-0000-4000-8000-00006544ea49', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655301e0-0000-4000-8000-0000655301e0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611962-0000-4000-8000-000065611962', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c300-0000-4000-8000-000066f9c300', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea62-0000-4000-8000-00006544ea62', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea63-0000-4000-8000-00006544ea63', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655301e5-0000-4000-8000-0000655301e5', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611967-0000-4000-8000-000065611967', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c305-0000-4000-8000-000066f9c305', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea67-0000-4000-8000-00006544ea67', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('655301e9-0000-4000-8000-0000655301e9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea7e-0000-4000-8000-00006544ea7e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65530200-0000-4000-8000-000065530200', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('65611982-0000-4000-8000-000065611982', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c320-0000-4000-8000-000066f9c320', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c321-0000-4000-8000-000066f9c321', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707daa3-0000-4000-8000-00006707daa3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea84-0000-4000-8000-00006544ea84', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c324-0000-4000-8000-000066f9c324', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707daa6-0000-4000-8000-00006707daa6', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c326-0000-4000-8000-000066f9c326', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dabd-0000-4000-8000-00006707dabd', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544ea9e-0000-4000-8000-00006544ea9e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c33e-0000-4000-8000-000066f9c33e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('66f9c33f-0000-4000-8000-000066f9c33f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6707dac1-0000-4000-8000-00006707dac1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('6544eaa2-0000-4000-8000-00006544eaa2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', date '2026-08-01');
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3428-0000-4000-8000-0000222f3428', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecccc81c-0000-4000-8000-0000ecccc81c', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4baa-0000-4000-8000-0000223d4baa', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdadf9e-0000-4000-8000-0000ecdadf9e', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b632c-0000-4000-8000-0000224b632c', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f720-0000-4000-8000-0000ece8f720', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40cca-0000-4000-8000-000023e40cca', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a0be-0000-4000-8000-0000ee81a0be', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36cc-0000-4000-8000-0000222f36cc', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccac0-0000-4000-8000-0000eccccac0', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4e4e-0000-4000-8000-0000223d4e4e', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae242-0000-4000-8000-0000ecdae242', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b65d0-0000-4000-8000-0000224b65d0', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f9c4-0000-4000-8000-0000ece8f9c4', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36cf-0000-4000-8000-0000222f36cf', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccac3-0000-4000-8000-0000eccccac3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4e51-0000-4000-8000-0000223d4e51', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae245-0000-4000-8000-0000ecdae245', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b65d3-0000-4000-8000-0000224b65d3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f9c7-0000-4000-8000-0000ece8f9c7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40f71-0000-4000-8000-000023e40f71', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a365-0000-4000-8000-0000ee81a365', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36d3-0000-4000-8000-0000222f36d3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccac7-0000-4000-8000-0000eccccac7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36d4-0000-4000-8000-0000222f36d4', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccac8-0000-4000-8000-0000eccccac8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4e56-0000-4000-8000-0000223d4e56', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae24a-0000-4000-8000-0000ecdae24a', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b65ed-0000-4000-8000-0000224b65ed', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f9e1-0000-4000-8000-0000ece8f9e1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40f8b-0000-4000-8000-000023e40f8b', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a37f-0000-4000-8000-0000ee81a37f', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36ed-0000-4000-8000-0000222f36ed', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccae1-0000-4000-8000-0000eccccae1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4e6f-0000-4000-8000-0000223d4e6f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae263-0000-4000-8000-0000ecdae263', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f36ef-0000-4000-8000-0000222f36ef', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccae3-0000-4000-8000-0000eccccae3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('223d4e71-0000-4000-8000-0000223d4e71', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ecdae265-0000-4000-8000-0000ecdae265', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('224b65f3-0000-4000-8000-0000224b65f3', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ece8f9e7-0000-4000-8000-0000ece8f9e7', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40f91-0000-4000-8000-000023e40f91', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a385-0000-4000-8000-0000ee81a385', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40f92-0000-4000-8000-000023e40f92', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a386-0000-4000-8000-0000ee81a386', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22714-0000-4000-8000-000023f22714', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fbb08-0000-4000-8000-0000ee8fbb08', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f370a-0000-4000-8000-0000222f370a', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccafe-0000-4000-8000-0000eccccafe', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40faa-0000-4000-8000-000023e40faa', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a39e-0000-4000-8000-0000ee81a39e', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f2272c-0000-4000-8000-000023f2272c', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fbb20-0000-4000-8000-0000ee8fbb20', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40fac-0000-4000-8000-000023e40fac', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a3a0-0000-4000-8000-0000ee81a3a0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f2272e-0000-4000-8000-000023f2272e', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fbb22-0000-4000-8000-0000ee8fbb22', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f370f-0000-4000-8000-0000222f370f', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccb03-0000-4000-8000-0000eccccb03', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40faf-0000-4000-8000-000023e40faf', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a3a3-0000-4000-8000-0000ee81a3a3', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23e40fb0-0000-4000-8000-000023e40fb0', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee81a3a4-0000-4000-8000-0000ee81a3a4', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('23f22732-0000-4000-8000-000023f22732', 'bbbb0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('ee8fbb26-0000-4000-8000-0000ee8fbb26', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sonde Sondesen', current_date);
insert into public.opplaering_oppgave (id, retailer_id, tittel, kategori) values ('222f3713-0000-4000-8000-0000222f3713', 'aaaa0000-0000-4000-8000-000000000000', 'Sondeoppgave', 'Kasse');
insert into public.opplaering_periode (id, retailer_id, stasjon_id, ansatt_navn, start_dato) values ('eccccb07-0000-4000-8000-0000eccccb07', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sonde Sondesen', current_date);
-- --- malekort_scope: forutsetninger og proberader ---
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', 'f758c57b-0000-4000-8000-0000f758c57b', 'avdeling', 'fastA1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bd-0000-4000-8000-00005d5db7bd', 'aaaa0000-0000-4000-8000-000000000000', 'f758c93d-0000-4000-8000-0000f758c93d', 'avdeling', 'fastA2');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7be-0000-4000-8000-00005d5db7be', 'aaaa0000-0000-4000-8000-000000000000', 'f758ccff-0000-4000-8000-0000f758ccff', 'avdeling', 'fastA3');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', 'f75939dd-0000-4000-8000-0000f75939dd', 'avdeling', 'fastB1');
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7dc-0000-4000-8000-00005d5db7dc', 'bbbb0000-0000-4000-8000-000000000000', 'f7593d9f-0000-4000-8000-0000f7593d9f', 'avdeling', 'fastB2');

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
-- --- opplaering_utfort: forutsetninger og proberader ---
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', '1827a38f-0000-4000-8000-00001827a38f', '9e018603-0000-4000-8000-00009e018603');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', '182817ef-0000-4000-8000-0000182817ef', '9e01fa63-0000-4000-8000-00009e01fa63');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', '18288c4f-0000-4000-8000-000018288c4f', '9e026ec3-0000-4000-8000-00009e026ec3');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', '1835bb13-0000-4000-8000-00001835bb13', '9e0f9d87-0000-4000-8000-00009e0f9d87');
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', '18362f73-0000-4000-8000-000018362f73', '9e1011e7-0000-4000-8000-00009e1011e7');

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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie fastA1', 100, date '2026-01-01' + 35);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie fastA2', 100, date '2026-01-01' + 36);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie fastA3', 100, date '2026-01-01' + 37);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie fastB1', 100, date '2026-01-01' + 38);
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie fastB2', 100, date '2026-01-01' + 39);

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

-- =====================================================================
-- malekort_scope  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('malekort_scope');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('malekort_scope owner_A SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope owner_A SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_tillatt('malekort_scope owner_A INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfea91-0000-4000-8000-0000f3bfea91'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('malekort_scope owner_A INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce0213-0000-4000-8000-0000f3ce0213'', ''avdeling'', ''owner_AB1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7bc-0000-4000-8000-00005d5db7bc', 'aaaa0000-0000-4000-8000-000000000000', 'f3bfea93-0000-4000-8000-0000f3bfea93', 'avdeling', 'gjenowner_AA1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('malekort_scope owner_A DELETE B', 'delete from public.malekort_scope where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_A FLYTTER egen rad -> kjede B', 'update public.malekort_scope set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('malekort_scope manager_A1 SELECT A -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'positiv');
select pg_temp.paastand('malekort_scope manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfea94-0000-4000-8000-0000f3bfea94'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce0216-0000-4000-8000-0000f3ce0216'', ''avdeling'', ''manager_A1B1'')');
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
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfea96-0000-4000-8000-0000f3bfea96'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('malekort_scope manager_A12 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce0218-0000-4000-8000-0000f3ce0218'', ''avdeling'', ''manager_A12B1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfea98-0000-4000-8000-0000f3bfea98'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_A1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce021a-0000-4000-8000-0000f3ce021a'', ''avdeling'', ''tablet_A1B1'')');
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
select pg_temp.skriv_tillatt('malekort_scope owner_B INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce021b-0000-4000-8000-0000f3ce021b'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('malekort_scope owner_B INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfeab0-0000-4000-8000-0000f3bfeab0'', ''avdeling'', ''owner_BA1'')');
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
insert into public.malekort_scope (id, retailer_id, malekort_id, nivaa, kode) values ('5d5db7db-0000-4000-8000-00005d5db7db', 'bbbb0000-0000-4000-8000-000000000000', 'f3ce0232-0000-4000-8000-0000f3ce0232', 'avdeling', 'gjenowner_BB1');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_malekort_scope('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('malekort_scope owner_B DELETE A', 'delete from public.malekort_scope where id = ''5d5db7bc-0000-4000-8000-00005d5db7bc''', 'malekort_scope', '5d5db7bc-0000-4000-8000-00005d5db7bc', 'id');
select pg_temp.skriv_avvist('malekort_scope owner_B FLYTTER egen rad -> kjede A', 'update public.malekort_scope set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''5d5db7db-0000-4000-8000-00005d5db7db''', 'malekort_scope', '5d5db7db-0000-4000-8000-00005d5db7db', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('malekort_scope manager_B1 SELECT B -> ser', exists (select 1 from public.malekort_scope where id = '5d5db7db-0000-4000-8000-00005d5db7db'), 'positiv');
select pg_temp.paastand('malekort_scope manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.malekort_scope where id = '5d5db7bc-0000-4000-8000-00005d5db7bc'), 'negativ');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce0233-0000-4000-8000-0000f3ce0233'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope manager_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfeab3-0000-4000-8000-0000f3bfeab3'', ''avdeling'', ''manager_B1A1'')');
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
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT B', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''f3ce0235-0000-4000-8000-0000f3ce0235'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('malekort_scope tablet_B1 INSERT A', 'insert into public.malekort_scope (retailer_id, malekort_id, nivaa, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''f3bfeab5-0000-4000-8000-0000f3bfeab5'', ''avdeling'', ''tablet_B1A1'')');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea42-0000-4000-8000-00006544ea42'', date ''2026-01-01'' + 162)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655301c4-0000-4000-8000-0000655301c4'', date ''2026-01-01'' + 163)');
select pg_temp.skriv_tillatt('opplaering_skift owner_A INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611946-0000-4000-8000-000065611946'', date ''2026-01-01'' + 164)');
select pg_temp.skriv_avvist('opplaering_skift owner_A INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c2e4-0000-4000-8000-000066f9c2e4'', date ''2026-01-01'' + 165)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ea46-0000-4000-8000-00006544ea46', date '2026-01-01' + 166);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '655301c8-0000-4000-8000-0000655301c8', date '2026-01-01' + 167);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_skift owner_A DELETE A3', 'delete from public.opplaering_skift where id = ''8cd86b87-0000-4000-8000-00008cd86b87''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b87-0000-4000-8000-00008cd86b87', '6561194a-0000-4000-8000-00006561194a', date '2026-01-01' + 168);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea49-0000-4000-8000-00006544ea49'', date ''2026-01-01'' + 169)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655301e0-0000-4000-8000-0000655301e0'', date ''2026-01-01'' + 170)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611962-0000-4000-8000-000065611962'', date ''2026-01-01'' + 171)');
select pg_temp.skriv_avvist('opplaering_skift manager_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c300-0000-4000-8000-000066f9c300'', date ''2026-01-01'' + 172)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ea62-0000-4000-8000-00006544ea62', date '2026-01-01' + 173);
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
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea63-0000-4000-8000-00006544ea63'', date ''2026-01-01'' + 174)');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''655301e5-0000-4000-8000-0000655301e5'', date ''2026-01-01'' + 175)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611967-0000-4000-8000-000065611967'', date ''2026-01-01'' + 176)');
select pg_temp.skriv_avvist('opplaering_skift manager_A12 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c305-0000-4000-8000-000066f9c305'', date ''2026-01-01'' + 177)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b85-0000-4000-8000-00008cd86b85', '6544ea67-0000-4000-8000-00006544ea67', date '2026-01-01' + 178);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_skift manager_A12 DELETE A2', 'delete from public.opplaering_skift where id = ''8cd86b86-0000-4000-8000-00008cd86b86''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86b86-0000-4000-8000-00008cd86b86', '655301e9-0000-4000-8000-0000655301e9', date '2026-01-01' + 179);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea7e-0000-4000-8000-00006544ea7e'', date ''2026-01-01'' + 180)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A2', 'insert into public.opplaering_skift (periode_id, dato) values (''65530200-0000-4000-8000-000065530200'', date ''2026-01-01'' + 181)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT A3', 'insert into public.opplaering_skift (periode_id, dato) values (''65611982-0000-4000-8000-000065611982'', date ''2026-01-01'' + 182)');
select pg_temp.skriv_avvist('opplaering_skift tablet_A1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c320-0000-4000-8000-000066f9c320'', date ''2026-01-01'' + 183)');
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
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c321-0000-4000-8000-000066f9c321'', date ''2026-01-01'' + 184)');
select pg_temp.skriv_tillatt('opplaering_skift owner_B INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707daa3-0000-4000-8000-00006707daa3'', date ''2026-01-01'' + 185)');
select pg_temp.skriv_avvist('opplaering_skift owner_B INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea84-0000-4000-8000-00006544ea84'', date ''2026-01-01'' + 186)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c324-0000-4000-8000-000066f9c324', date '2026-01-01' + 187);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_skift owner_B DELETE B2', 'delete from public.opplaering_skift where id = ''8cd86ba5-0000-4000-8000-00008cd86ba5''');
select pg_temp.som_eier();
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba5-0000-4000-8000-00008cd86ba5', '6707daa6-0000-4000-8000-00006707daa6', date '2026-01-01' + 188);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_skift('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_skift owner_B DELETE A1', 'delete from public.opplaering_skift where id = ''8cd86b85-0000-4000-8000-00008cd86b85''', 'opplaering_skift', '8cd86b85-0000-4000-8000-00008cd86b85', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_skift where id = '8cd86ba4-0000-4000-8000-00008cd86ba4'), 'positiv');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86ba5-0000-4000-8000-00008cd86ba5'), 'negativ');
select pg_temp.paastand('opplaering_skift manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_skift where id = '8cd86b85-0000-4000-8000-00008cd86b85'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_skift manager_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c326-0000-4000-8000-000066f9c326'', date ''2026-01-01'' + 189)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dabd-0000-4000-8000-00006707dabd'', date ''2026-01-01'' + 190)');
select pg_temp.skriv_avvist('opplaering_skift manager_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544ea9e-0000-4000-8000-00006544ea9e'', date ''2026-01-01'' + 191)');
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
insert into public.opplaering_skift (id, periode_id, dato) values ('8cd86ba4-0000-4000-8000-00008cd86ba4', '66f9c33e-0000-4000-8000-000066f9c33e', date '2026-01-01' + 192);
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
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B1', 'insert into public.opplaering_skift (periode_id, dato) values (''66f9c33f-0000-4000-8000-000066f9c33f'', date ''2026-01-01'' + 193)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT B2', 'insert into public.opplaering_skift (periode_id, dato) values (''6707dac1-0000-4000-8000-00006707dac1'', date ''2026-01-01'' + 194)');
select pg_temp.skriv_avvist('opplaering_skift tablet_B1 INSERT A1', 'insert into public.opplaering_skift (periode_id, dato) values (''6544eaa2-0000-4000-8000-00006544eaa2'', date ''2026-01-01'' + 195)');
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
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecccc81c-0000-4000-8000-0000ecccc81c'', ''222f3428-0000-4000-8000-0000222f3428'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdadf9e-0000-4000-8000-0000ecdadf9e'', ''223d4baa-0000-4000-8000-0000223d4baa'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f720-0000-4000-8000-0000ece8f720'', ''224b632c-0000-4000-8000-0000224b632c'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_A INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a0be-0000-4000-8000-0000ee81a0be'', ''23e40cca-0000-4000-8000-000023e40cca'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'eccccac0-0000-4000-8000-0000eccccac0', '222f36cc-0000-4000-8000-0000222f36cc');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdae242-0000-4000-8000-0000ecdae242', '223d4e4e-0000-4000-8000-0000223d4e4e');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_A DELETE A3', 'delete from public.opplaering_utfort where id = ''178fd42e-0000-4000-8000-0000178fd42e''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42e-0000-4000-8000-0000178fd42e', 'ece8f9c4-0000-4000-8000-0000ece8f9c4', '224b65d0-0000-4000-8000-0000224b65d0');
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
select pg_temp.skriv_tillatt('opplaering_utfort manager_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccac3-0000-4000-8000-0000eccccac3'', ''222f36cf-0000-4000-8000-0000222f36cf'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdae245-0000-4000-8000-0000ecdae245'', ''223d4e51-0000-4000-8000-0000223d4e51'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f9c7-0000-4000-8000-0000ece8f9c7'', ''224b65d3-0000-4000-8000-0000224b65d3'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a365-0000-4000-8000-0000ee81a365'', ''23e40f71-0000-4000-8000-000023e40f71'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'eccccac7-0000-4000-8000-0000eccccac7', '222f36d3-0000-4000-8000-0000222f36d3');
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
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccac8-0000-4000-8000-0000eccccac8'', ''222f36d4-0000-4000-8000-0000222f36d4'')');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdae24a-0000-4000-8000-0000ecdae24a'', ''223d4e56-0000-4000-8000-0000223d4e56'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f9e1-0000-4000-8000-0000ece8f9e1'', ''224b65ed-0000-4000-8000-0000224b65ed'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_A12 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a37f-0000-4000-8000-0000ee81a37f'', ''23e40f8b-0000-4000-8000-000023e40f8b'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42c-0000-4000-8000-0000178fd42c', 'eccccae1-0000-4000-8000-0000eccccae1', '222f36ed-0000-4000-8000-0000222f36ed');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('opplaering_utfort manager_A12 DELETE A2', 'delete from public.opplaering_utfort where id = ''178fd42d-0000-4000-8000-0000178fd42d''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd42d-0000-4000-8000-0000178fd42d', 'ecdae263-0000-4000-8000-0000ecdae263', '223d4e6f-0000-4000-8000-0000223d4e6f');
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
select pg_temp.skriv_tillatt('opplaering_utfort tablet_A1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccae3-0000-4000-8000-0000eccccae3'', ''222f36ef-0000-4000-8000-0000222f36ef'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ecdae265-0000-4000-8000-0000ecdae265'', ''223d4e71-0000-4000-8000-0000223d4e71'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT A3', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ece8f9e7-0000-4000-8000-0000ece8f9e7'', ''224b65f3-0000-4000-8000-0000224b65f3'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_A1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a385-0000-4000-8000-0000ee81a385'', ''23e40f91-0000-4000-8000-000023e40f91'')');
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
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a386-0000-4000-8000-0000ee81a386'', ''23e40f92-0000-4000-8000-000023e40f92'')');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fbb08-0000-4000-8000-0000ee8fbb08'', ''23f22714-0000-4000-8000-000023f22714'')');
select pg_temp.skriv_avvist('opplaering_utfort owner_B INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccafe-0000-4000-8000-0000eccccafe'', ''222f370a-0000-4000-8000-0000222f370a'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81a39e-0000-4000-8000-0000ee81a39e', '23e40faa-0000-4000-8000-000023e40faa');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('opplaering_utfort owner_B DELETE B2', 'delete from public.opplaering_utfort where id = ''178fd44c-0000-4000-8000-0000178fd44c''');
select pg_temp.som_eier();
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44c-0000-4000-8000-0000178fd44c', 'ee8fbb20-0000-4000-8000-0000ee8fbb20', '23f2272c-0000-4000-8000-000023f2272c');
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_opplaering_utfort('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('opplaering_utfort owner_B DELETE A1', 'delete from public.opplaering_utfort where id = ''178fd42c-0000-4000-8000-0000178fd42c''', 'opplaering_utfort', '178fd42c-0000-4000-8000-0000178fd42c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B1 -> ser', exists (select 1 from public.opplaering_utfort where id = '178fd44b-0000-4000-8000-0000178fd44b'), 'positiv');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd44c-0000-4000-8000-0000178fd44c'), 'negativ');
select pg_temp.paastand('opplaering_utfort manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.opplaering_utfort where id = '178fd42c-0000-4000-8000-0000178fd42c'), 'negativ');
select pg_temp.skriv_tillatt('opplaering_utfort manager_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a3a0-0000-4000-8000-0000ee81a3a0'', ''23e40fac-0000-4000-8000-000023e40fac'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fbb22-0000-4000-8000-0000ee8fbb22'', ''23f2272e-0000-4000-8000-000023f2272e'')');
select pg_temp.skriv_avvist('opplaering_utfort manager_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccb03-0000-4000-8000-0000eccccb03'', ''222f370f-0000-4000-8000-0000222f370f'')');
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
insert into public.opplaering_utfort (id, periode_id, oppgave_id) values ('178fd44b-0000-4000-8000-0000178fd44b', 'ee81a3a3-0000-4000-8000-0000ee81a3a3', '23e40faf-0000-4000-8000-000023e40faf');
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
select pg_temp.skriv_tillatt('opplaering_utfort tablet_B1 INSERT B1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee81a3a4-0000-4000-8000-0000ee81a3a4'', ''23e40fb0-0000-4000-8000-000023e40fb0'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT B2', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''ee8fbb26-0000-4000-8000-0000ee8fbb26'', ''23f22732-0000-4000-8000-000023f22732'')');
select pg_temp.skriv_avvist('opplaering_utfort tablet_B1 INSERT A1', 'insert into public.opplaering_utfort (periode_id, oppgave_id) values (''eccccb07-0000-4000-8000-0000eccccb07'', ''222f3713-0000-4000-8000-0000222f3713'')');
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
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AA1'', 100, date ''2026-01-01'' + 230)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_AA2'', 100, date ''2026-01-01'' + 231)');
select pg_temp.skriv_tillatt('pengepremie owner_A INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie owner_AA3'', 100, date ''2026-01-01'' + 232)');
select pg_temp.skriv_avvist('pengepremie owner_A INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_AB1'', 100, date ''2026-01-01'' + 233)');
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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_AA1', 100, date '2026-01-01' + 234);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_AA2', 100, date '2026-01-01' + 235);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('pengepremie owner_A DELETE A3', 'delete from public.pengepremie where id = ''d61e3cb3-0000-4000-8000-0000d61e3cb3''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb3-0000-4000-8000-0000d61e3cb3', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'Sondepremie gjenowner_AA3', 100, date '2026-01-01' + 236);
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
select pg_temp.skriv_tillatt('pengepremie manager_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1A1'', 100, date ''2026-01-01'' + 237)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A1A2'', 100, date ''2026-01-01'' + 238)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A1A3'', 100, date ''2026-01-01'' + 239)');
select pg_temp.skriv_avvist('pengepremie manager_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A1B1'', 100, date ''2026-01-01'' + 240)');
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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A1A1', 100, date '2026-01-01' + 241);
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
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12A1'', 100, date ''2026-01-01'' + 242)');
select pg_temp.skriv_tillatt('pengepremie manager_A12 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_A12A2'', 100, date ''2026-01-01'' + 243)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie manager_A12A3'', 100, date ''2026-01-01'' + 244)');
select pg_temp.skriv_avvist('pengepremie manager_A12 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_A12B1'', 100, date ''2026-01-01'' + 245)');
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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb1-0000-4000-8000-0000d61e3cb1', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_A12A1', 100, date '2026-01-01' + 246);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_tillatt('pengepremie manager_A12 DELETE A2', 'delete from public.pengepremie where id = ''d61e3cb2-0000-4000-8000-0000d61e3cb2''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cb2-0000-4000-8000-0000d61e3cb2', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'Sondepremie gjenmanager_A12A2', 100, date '2026-01-01' + 247);
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
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1A1'', 100, date ''2026-01-01'' + 248)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_A1A2'', 100, date ''2026-01-01'' + 249)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT A3', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''Sondepremie tablet_A1A3'', 100, date ''2026-01-01'' + 250)');
select pg_temp.skriv_avvist('pengepremie tablet_A1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_A1B1'', 100, date ''2026-01-01'' + 251)');
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
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BB1'', 100, date ''2026-01-01'' + 252)');
select pg_temp.skriv_tillatt('pengepremie owner_B INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie owner_BB2'', 100, date ''2026-01-01'' + 253)');
select pg_temp.skriv_avvist('pengepremie owner_B INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie owner_BA1'', 100, date ''2026-01-01'' + 254)');
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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenowner_BB1', 100, date '2026-01-01' + 255);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_pengepremie('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('pengepremie owner_B DELETE B2', 'delete from public.pengepremie where id = ''d61e3cd1-0000-4000-8000-0000d61e3cd1''');
select pg_temp.som_eier();
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd1-0000-4000-8000-0000d61e3cd1', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'Sondepremie gjenowner_BB2', 100, date '2026-01-01' + 256);
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
select pg_temp.skriv_tillatt('pengepremie manager_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1B1'', 100, date ''2026-01-01'' + 257)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie manager_B1B2'', 100, date ''2026-01-01'' + 258)');
select pg_temp.skriv_avvist('pengepremie manager_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie manager_B1A1'', 100, date ''2026-01-01'' + 259)');
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
insert into public.pengepremie (id, retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values ('d61e3cd0-0000-4000-8000-0000d61e3cd0', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'Sondepremie gjenmanager_B1B1', 100, date '2026-01-01' + 260);
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
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1B1'', 100, date ''2026-01-01'' + 261)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT B2', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''Sondepremie tablet_B1B2'', 100, date ''2026-01-01'' + 262)');
select pg_temp.skriv_avvist('pengepremie tablet_B1 INSERT A1', 'insert into public.pengepremie (retailer_id, stasjon_id, beskrivelse, belop_kr, dato) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''Sondepremie tablet_B1A1'', 100, date ''2026-01-01'' + 263)');
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
    raise exception 'TENANT-MATRISEN DEL 5/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 5/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
