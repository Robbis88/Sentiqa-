-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.
--
-- DEL 4 AV 10. Hele matrisen er for stor for Supabase SQL
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
-- --- kastbudsjett: forutsetninger og proberader ---
insert into public.kastbudsjett (id, retailer_id, stasjon_id, ar, nivaa, kode, kast_pst_av_salg, kast_budsjett_kr) values ('7a3491c8-0000-4000-8000-00007a3491c8', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 2105, 'vareomrade', 'fastA1', 0.08, 1000);
insert into public.kastbudsjett (id, retailer_id, stasjon_id, ar, nivaa, kode, kast_pst_av_salg, kast_budsjett_kr) values ('7a3491c9-0000-4000-8000-00007a3491c9', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 2106, 'vareomrade', 'fastA2', 0.08, 1000);
insert into public.kastbudsjett (id, retailer_id, stasjon_id, ar, nivaa, kode, kast_pst_av_salg, kast_budsjett_kr) values ('7a3491ca-0000-4000-8000-00007a3491ca', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 2107, 'vareomrade', 'fastA3', 0.08, 1000);
insert into public.kastbudsjett (id, retailer_id, stasjon_id, ar, nivaa, kode, kast_pst_av_salg, kast_budsjett_kr) values ('7a3491e7-0000-4000-8000-00007a3491e7', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 2108, 'vareomrade', 'fastB1', 0.08, 1000);
insert into public.kastbudsjett (id, retailer_id, stasjon_id, ar, nivaa, kode, kast_pst_av_salg, kast_budsjett_kr) values ('7a3491e8-0000-4000-8000-00007a3491e8', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 2109, 'vareomrade', 'fastB2', 0.08, 1000);
-- --- kategori_vaerprofil: forutsetninger og proberader ---
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'avdeling', 'fastA1');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'avdeling', 'fastA2');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'avdeling', 'fastA3');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'avdeling', 'fastB1');
insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values ('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'avdeling', 'fastB2');
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
-- --- kontraktmal: forutsetninger og proberader ---
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a172058a-0000-4000-8000-0000a172058a', 'aaaa0000-0000-4000-8000-000000000000', 'fast', 'sonde-fastA1.pdf', 'sonde/fastA1.pdf', 0020::int);
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a172058b-0000-4000-8000-0000a172058b', 'aaaa0000-0000-4000-8000-000000000000', 'fast', 'sonde-fastA2.pdf', 'sonde/fastA2.pdf', 0021::int);
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a172058c-0000-4000-8000-0000a172058c', 'aaaa0000-0000-4000-8000-000000000000', 'fast', 'sonde-fastA3.pdf', 'sonde/fastA3.pdf', 0022::int);
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a17205a9-0000-4000-8000-0000a17205a9', 'bbbb0000-0000-4000-8000-000000000000', 'fast', 'sonde-fastB1.pdf', 'sonde/fastB1.pdf', 0023::int);
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a17205aa-0000-4000-8000-0000a17205aa', 'bbbb0000-0000-4000-8000-000000000000', 'fast', 'sonde-fastB2.pdf', 'sonde/fastB2.pdf', 0024::int);

create or replace function pg_temp.nyrad_kontraktmal(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon)
  values (p_retailer, 'fast', 'sonde-' || p_merke || '-' || nextval('tenant_teller'::regclass) || '.pdf', 'sonde/' || p_merke || '-' || nextval('tenant_teller'::regclass) || '.pdf', (9000 + nextval('tenant_teller'::regclass) % 1000)::int)
  returning id into ny;
  return ny;
end $fn$;
-- --- kontrolltiltak_bekreftelse: forutsetninger og proberader ---
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('440b798c-0000-4000-8000-0000440b798c', 'aaaa0000-0000-4000-8000-000000000000', null, 'nullA', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('440b798d-0000-4000-8000-0000440b798d', 'bbbb0000-0000-4000-8000-000000000000', null, 'nullB', '00000000-0000-0000-0000-00000000b000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea45-0000-4000-8000-00009d6fea45', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'fastA1', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea46-0000-4000-8000-00009d6fea46', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'fastA2', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea47-0000-4000-8000-00009d6fea47', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'fastA3', '00000000-0000-0000-0000-00000000a000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea64-0000-4000-8000-00009d6fea64', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'fastB1', '00000000-0000-0000-0000-00000000b000');
insert into public.kontrolltiltak_bekreftelse (id, retailer_id, stasjon_id, versjon, bruker_id) values ('9d6fea65-0000-4000-8000-00009d6fea65', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'fastB2', '00000000-0000-0000-0000-00000000b000');
-- --- kunnskap: forutsetninger og proberader ---
insert into public.kunnskap (id, tittel, innhold) values ('e3a71f0c-0000-4000-8000-0000e3a71f0c', 'Sondeartikkel global', 'Sondetekst');
-- --- lederstotte_rapporter: forutsetninger og proberader ---
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8273-0000-4000-8000-0000d8ff8273', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 33, '{}'::jsonb);
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8274-0000-4000-8000-0000d8ff8274', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 34, '{}'::jsonb);
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8275-0000-4000-8000-0000d8ff8275', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 35, '{}'::jsonb);
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8292-0000-4000-8000-0000d8ff8292', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 36, '{}'::jsonb);
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8293-0000-4000-8000-0000d8ff8293', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 37, '{}'::jsonb);

create or replace function pg_temp.nyrad_lederstotte_rapporter(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare
  ny uuid;
begin
  insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport)
  values (p_retailer, p_stasjon, date '2030-01-01' + nextval('tenant_teller'::regclass)::int, '{}'::jsonb)
  returning id into ny;
  return ny;
end $fn$;
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

-- =====================================================================
-- kassererstatistikk  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kassererstatistikk');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kassererstatistikk owner_A SELECT A1 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 0 and "kasserer_nr" = 'fastA1'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A2 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "dato" = date '2026-01-01' + 1 and "kasserer_nr" = 'fastA2'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT A3 -> ser', exists (select 1 from public.kassererstatistikk where "retailer_id" = 'aaaa0000-0000-4000-8000-000000000000' and "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "dato" = date '2026-01-01' + 2 and "kasserer_nr" = 'fastA3'), 'positiv');
select pg_temp.paastand('kassererstatistikk owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kassererstatistikk where "retailer_id" = 'bbbb0000-0000-4000-8000-000000000000' and "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "dato" = date '2026-01-01' + 3 and "kasserer_nr" = 'fastB1'), 'negativ');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 48, ''owner_AA1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 49, ''owner_AA2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_A INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 50, ''owner_AA3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_A INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 51, ''owner_AB1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 52, ''manager_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 53, ''manager_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 54, ''manager_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 55, ''manager_A1B1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 56, ''manager_A12A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 57, ''manager_A12A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 58, ''manager_A12A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_A12 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 59, ''manager_A12B1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 60, ''tablet_A1A1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 61, ''tablet_A1A2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT A3', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 62, ''tablet_A1A3'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_A1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 63, ''tablet_A1B1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 64, ''owner_BB1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_tillatt('kassererstatistikk owner_B INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 65, ''owner_BB2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk owner_B INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 66, ''owner_BA1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 67, ''manager_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 68, ''manager_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk manager_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 69, ''manager_B1A1'', ''Sonde Sondesen'', 1000, 10)');
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
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 70, ''tablet_B1B1'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT B2', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 71, ''tablet_B1B2'', ''Sonde Sondesen'', 1000, 10)');
select pg_temp.skriv_avvist('kassererstatistikk tablet_B1 INSERT A1', 'insert into public.kassererstatistikk (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, omsetning_ink_mva, bonger) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 72, ''tablet_B1A1'', ''Sonde Sondesen'', 1000, 10)');
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
-- kastbudsjett  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kastbudsjett');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kastbudsjett owner_A SELECT A1 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'positiv');
select pg_temp.paastand('kastbudsjett owner_A SELECT A2 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491c9-0000-4000-8000-00007a3491c9'), 'positiv');
select pg_temp.paastand('kastbudsjett owner_A SELECT A3 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491ca-0000-4000-8000-00007a3491ca'), 'positiv');
select pg_temp.paastand('kastbudsjett owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kastbudsjett manager_A1 SELECT A1 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'positiv');
select pg_temp.paastand('kastbudsjett manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c9-0000-4000-8000-00007a3491c9'), 'negativ');
select pg_temp.paastand('kastbudsjett manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491ca-0000-4000-8000-00007a3491ca'), 'negativ');
select pg_temp.paastand('kastbudsjett manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kastbudsjett manager_A12 SELECT A1 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'positiv');
select pg_temp.paastand('kastbudsjett manager_A12 SELECT A2 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491c9-0000-4000-8000-00007a3491c9'), 'positiv');
select pg_temp.paastand('kastbudsjett manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491ca-0000-4000-8000-00007a3491ca'), 'negativ');
select pg_temp.paastand('kastbudsjett manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kastbudsjett tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'negativ');
select pg_temp.paastand('kastbudsjett tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c9-0000-4000-8000-00007a3491c9'), 'negativ');
select pg_temp.paastand('kastbudsjett tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491ca-0000-4000-8000-00007a3491ca'), 'negativ');
select pg_temp.paastand('kastbudsjett tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kastbudsjett owner_B SELECT B1 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'positiv');
select pg_temp.paastand('kastbudsjett owner_B SELECT B2 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491e8-0000-4000-8000-00007a3491e8'), 'positiv');
select pg_temp.paastand('kastbudsjett owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kastbudsjett manager_B1 SELECT B1 -> ser', exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'positiv');
select pg_temp.paastand('kastbudsjett manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e8-0000-4000-8000-00007a3491e8'), 'negativ');
select pg_temp.paastand('kastbudsjett manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kastbudsjett tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e7-0000-4000-8000-00007a3491e7'), 'negativ');
select pg_temp.paastand('kastbudsjett tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491e8-0000-4000-8000-00007a3491e8'), 'negativ');
select pg_temp.paastand('kastbudsjett tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kastbudsjett where id = '7a3491c8-0000-4000-8000-00007a3491c8'), 'negativ');

-- =====================================================================
-- kategori_vaerprofil  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kategori_vaerprofil');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT A3 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_AA1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''owner_AA2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''owner_AA3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_A INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_AB1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_A DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A1A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_A1A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''manager_A1A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A1B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A12A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_A12A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''manager_A12A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_A12 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_A12B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_A12 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastA2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000003' and "niva" = 'avdeling' and "kode" = 'fastA3'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_A1A1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''avdeling'', ''tablet_A1A2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT A3', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''avdeling'', ''tablet_A1A3'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_A1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_A1B1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE A3', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastA2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE A3', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000003'' and "niva" = ''avdeling'' and "kode" = ''fastA3''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_A1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT B2 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_BB1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''owner_BB2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil owner_B INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''owner_BA1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil owner_B DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_B1B1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''manager_B1B2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil manager_B1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''manager_B1A1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil manager_B1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT B1 -> ser', exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastB1'), 'positiv');
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'b1110000-0000-4000-8000-000000000002' and "niva" = 'avdeling' and "kode" = 'fastB2'), 'negativ');
select pg_temp.paastand('kategori_vaerprofil tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kategori_vaerprofil where "stasjon_id" = 'a1110000-0000-4000-8000-000000000001' and "niva" = 'avdeling' and "kode" = 'fastA1'), 'negativ');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT B1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_B1B1'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT B2', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''avdeling'', ''tablet_B1B2'')');
select pg_temp.skriv_avvist('kategori_vaerprofil tablet_B1 INSERT A1', 'insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''avdeling'', ''tablet_B1A1'')');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE B1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE B2', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 UPDATE A1', 'update public.kategori_vaerprofil set n = 1 where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE B1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastB1''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE B2', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''', 'kategori_vaerprofil', '"stasjon_id" = ''b1110000-0000-4000-8000-000000000002'' and "niva" = ''avdeling'' and "kode" = ''fastB2''');
select pg_temp.skriv_avvist_pred('kategori_vaerprofil tablet_B1 DELETE A1', 'delete from public.kategori_vaerprofil where "stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''', 'kategori_vaerprofil', '"stasjon_id" = ''a1110000-0000-4000-8000-000000000001'' and "niva" = ''avdeling'' and "kode" = ''fastA1''');

-- =====================================================================
-- konkurranser  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('konkurranser');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('konkurranser owner_A SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser owner_A SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_tillatt('konkurranser owner_A INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AA1'', ''omsetning sonde'', date ''2026-01-01'' + 98, date ''2026-01-01'' + 98 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_A INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_AB1'', ''omsetning sonde'', date ''2026-01-01'' + 99, date ''2026-01-01'' + 99 + 30)');
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
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515953-0000-4000-8000-00001c515953', 'aaaa0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_AA1', 'omsetning sonde', date '2026-01-01' + 100, date '2026-01-01' + 100 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('konkurranser owner_A DELETE B', 'delete from public.konkurranser where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');
select pg_temp.skriv_avvist('konkurranser owner_A FLYTTER egen rad -> kjede B', 'update public.konkurranser set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('konkurranser manager_A1 SELECT A -> ser', exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'positiv');
select pg_temp.paastand('konkurranser manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 101, date ''2026-01-01'' + 101 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 102, date ''2026-01-01'' + 102 + 30)');
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
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12A1'', ''omsetning sonde'', date ''2026-01-01'' + 103, date ''2026-01-01'' + 103 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_A12 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_A12B1'', ''omsetning sonde'', date ''2026-01-01'' + 104, date ''2026-01-01'' + 104 + 30)');
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
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1A1'', ''omsetning sonde'', date ''2026-01-01'' + 105, date ''2026-01-01'' + 105 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_A1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_A1B1'', ''omsetning sonde'', date ''2026-01-01'' + 106, date ''2026-01-01'' + 106 + 30)');
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
select pg_temp.skriv_tillatt('konkurranser owner_B INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BB1'', ''omsetning sonde'', date ''2026-01-01'' + 107, date ''2026-01-01'' + 107 + 30)');
select pg_temp.skriv_avvist('konkurranser owner_B INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse owner_BA1'', ''omsetning sonde'', date ''2026-01-01'' + 108, date ''2026-01-01'' + 108 + 30)');
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
insert into public.konkurranser (id, retailer_id, navn, kpi, periode_start, periode_slutt) values ('1c515972-0000-4000-8000-00001c515972', 'bbbb0000-0000-4000-8000-000000000000', 'Sondekonkurranse gjenowner_BB1', 'omsetning sonde', date '2026-01-01' + 109, date '2026-01-01' + 109 + 30);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_konkurranser('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('konkurranser owner_B DELETE A', 'delete from public.konkurranser where id = ''1c515953-0000-4000-8000-00001c515953''', 'konkurranser', '1c515953-0000-4000-8000-00001c515953', 'id');
select pg_temp.skriv_avvist('konkurranser owner_B FLYTTER egen rad -> kjede A', 'update public.konkurranser set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''1c515972-0000-4000-8000-00001c515972''', 'konkurranser', '1c515972-0000-4000-8000-00001c515972', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('konkurranser manager_B1 SELECT B -> ser', exists (select 1 from public.konkurranser where id = '1c515972-0000-4000-8000-00001c515972'), 'positiv');
select pg_temp.paastand('konkurranser manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.konkurranser where id = '1c515953-0000-4000-8000-00001c515953'), 'negativ');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 110, date ''2026-01-01'' + 110 + 30)');
select pg_temp.skriv_avvist('konkurranser manager_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse manager_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 111, date ''2026-01-01'' + 111 + 30)');
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
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT B', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''bbbb0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1B1'', ''omsetning sonde'', date ''2026-01-01'' + 112, date ''2026-01-01'' + 112 + 30)');
select pg_temp.skriv_avvist('konkurranser tablet_B1 INSERT A', 'insert into public.konkurranser (retailer_id, navn, kpi, periode_start, periode_slutt) values (''aaaa0000-0000-4000-8000-000000000000'', ''Sondekonkurranse tablet_B1A1'', ''omsetning sonde'', date ''2026-01-01'' + 113, date ''2026-01-01'' + 113 + 30)');
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
-- kontraktmal  (retailer, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kontraktmal');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kontraktmal owner_A SELECT A -> ser', exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'positiv');
select pg_temp.paastand('kontraktmal owner_A SELECT B -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'negativ');
select pg_temp.skriv_tillatt('kontraktmal owner_A INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-owner_AA1.pdf'', ''sonde/owner_AA1.pdf'', 0114::int)');
select pg_temp.skriv_avvist('kontraktmal owner_A INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-owner_AB1.pdf'', ''sonde/owner_AB1.pdf'', 0115::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kontraktmal owner_A UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kontraktmal owner_A UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('kontraktmal owner_A DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''');
select pg_temp.som_eier();
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a172058a-0000-4000-8000-0000a172058a', 'aaaa0000-0000-4000-8000-000000000000', 'fast', 'sonde-gjenowner_AA1.pdf', 'sonde/gjenowner_AA1.pdf', 0116::int);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('kontraktmal owner_A DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.skriv_avvist('kontraktmal owner_A FLYTTER egen rad -> kjede B', 'update public.kontraktmal set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kontraktmal manager_A1 SELECT A -> ser', exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'positiv');
select pg_temp.paastand('kontraktmal manager_A1 SELECT B -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'negativ');
select pg_temp.skriv_avvist('kontraktmal manager_A1 INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_A1A1.pdf'', ''sonde/manager_A1A1.pdf'', 0117::int)');
select pg_temp.skriv_avvist('kontraktmal manager_A1 INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_A1B1.pdf'', ''sonde/manager_A1B1.pdf'', 0118::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kontraktmal manager_A1 UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kontraktmal manager_A1 UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kontraktmal manager_A1 DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('kontraktmal manager_A1 DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kontraktmal manager_A12 SELECT A -> ser', exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'positiv');
select pg_temp.paastand('kontraktmal manager_A12 SELECT B -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'negativ');
select pg_temp.skriv_avvist('kontraktmal manager_A12 INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_A12A1.pdf'', ''sonde/manager_A12A1.pdf'', 0119::int)');
select pg_temp.skriv_avvist('kontraktmal manager_A12 INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_A12B1.pdf'', ''sonde/manager_A12B1.pdf'', 0120::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kontraktmal manager_A12 UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kontraktmal manager_A12 UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kontraktmal manager_A12 DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('kontraktmal manager_A12 DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kontraktmal tablet_A1 SELECT A -> ser', exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'positiv');
select pg_temp.paastand('kontraktmal tablet_A1 SELECT B -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'negativ');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-tablet_A1A1.pdf'', ''sonde/tablet_A1A1.pdf'', 0121::int)');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-tablet_A1B1.pdf'', ''sonde/tablet_A1B1.pdf'', 0122::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('kontraktmal tablet_A1 DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kontraktmal owner_B SELECT B -> ser', exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'positiv');
select pg_temp.paastand('kontraktmal owner_B SELECT A -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'negativ');
select pg_temp.skriv_tillatt('kontraktmal owner_B INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-owner_BB1.pdf'', ''sonde/owner_BB1.pdf'', 0123::int)');
select pg_temp.skriv_avvist('kontraktmal owner_B INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-owner_BA1.pdf'', ''sonde/owner_BA1.pdf'', 0124::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kontraktmal owner_B UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kontraktmal owner_B UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('kontraktmal owner_B DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''');
select pg_temp.som_eier();
insert into public.kontraktmal (id, retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values ('a17205a9-0000-4000-8000-0000a17205a9', 'bbbb0000-0000-4000-8000-000000000000', 'fast', 'sonde-gjenowner_BB1.pdf', 'sonde/gjenowner_BB1.pdf', 0125::int);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('kontraktmal owner_B DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.skriv_avvist('kontraktmal owner_B FLYTTER egen rad -> kjede A', 'update public.kontraktmal set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kontraktmal manager_B1 SELECT B -> ser', exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'positiv');
select pg_temp.paastand('kontraktmal manager_B1 SELECT A -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'negativ');
select pg_temp.skriv_avvist('kontraktmal manager_B1 INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_B1B1.pdf'', ''sonde/manager_B1B1.pdf'', 0126::int)');
select pg_temp.skriv_avvist('kontraktmal manager_B1 INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-manager_B1A1.pdf'', ''sonde/manager_B1A1.pdf'', 0127::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kontraktmal manager_B1 UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kontraktmal manager_B1 UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kontraktmal manager_B1 DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('kontraktmal manager_B1 DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kontraktmal tablet_B1 SELECT B -> ser', exists (select 1 from public.kontraktmal where id = 'a17205a9-0000-4000-8000-0000a17205a9'), 'positiv');
select pg_temp.paastand('kontraktmal tablet_B1 SELECT A -> ser ikke', not exists (select 1 from public.kontraktmal where id = 'a172058a-0000-4000-8000-0000a172058a'), 'negativ');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 INSERT B', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''bbbb0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-tablet_B1B1.pdf'', ''sonde/tablet_B1B1.pdf'', 0128::int)');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 INSERT A', 'insert into public.kontraktmal (retailer_id, ansettelsesform, filnavn, storage_sti, versjon) values (''aaaa0000-0000-4000-8000-000000000000'', ''fast'', ''sonde-tablet_B1A1.pdf'', ''sonde/tablet_B1A1.pdf'', 0129::int)');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 UPDATE B', 'update public.kontraktmal set aktiv = false where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 UPDATE A', 'update public.kontraktmal set aktiv = false where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 DELETE B', 'delete from public.kontraktmal where id = ''a17205a9-0000-4000-8000-0000a17205a9''', 'kontraktmal', 'a17205a9-0000-4000-8000-0000a17205a9', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_kontraktmal('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('kontraktmal tablet_B1 DELETE A', 'delete from public.kontraktmal where id = ''a172058a-0000-4000-8000-0000a172058a''', 'kontraktmal', 'a172058a-0000-4000-8000-0000a172058a', 'id');

-- =====================================================================
-- kontrolltiltak_bekreftelse  (retailer_or_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kontrolltiltak_bekreftelse');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT A3 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_AA1'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A INSERT med manager_A1 sin bruker_id', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_Asomannen'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''owner_AA2'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_A INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''owner_AA3'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_AB1'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A FLYTTER raden til manager_A1', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000a001'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A UPDATE A2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A UPDATE A3', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A DELETE A2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A DELETE A3', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_A DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A ser kjedens null-stasjonsrad', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_A ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A1A1'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT med owner_A sin bruker_id', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A1somannen'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A1A2'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A1A3'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A1B1'', ''00000000-0000-0000-0000-00000000a001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 FLYTTER raden til owner_A', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000a000'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 UPDATE A2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 UPDATE A3', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 DELETE A2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 DELETE A3', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A1 DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A12A1'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 INSERT med owner_A sin bruker_id', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_A12somannen'', ''00000000-0000-0000-0000-00000000a000'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_A12 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''manager_A12A2'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''manager_A12A3'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_A12B1'', ''00000000-0000-0000-0000-00000000a012'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 FLYTTER raden til owner_A', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000a000'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 UPDATE A2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 UPDATE A3', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 DELETE A2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 DELETE A3', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_A12 DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_A12 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea46-0000-4000-8000-00009d6fea46'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea47-0000-4000-8000-00009d6fea47'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_A1A1'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT A2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', ''tablet_A1A2'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT A3', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', ''tablet_A1A3'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_A1B1'', ''00000000-0000-0000-0000-00000000a101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 FLYTTER raden til owner_A', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000a000'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 UPDATE A2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 UPDATE A3', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 DELETE A2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea46-0000-4000-8000-00009d6fea46''', 'kontrolltiltak_bekreftelse', '9d6fea46-0000-4000-8000-00009d6fea46', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 DELETE A3', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea47-0000-4000-8000-00009d6fea47''', 'kontrolltiltak_bekreftelse', '9d6fea47-0000-4000-8000-00009d6fea47', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_A1 DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_A1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT B2 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_BB1'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B INSERT med manager_B1 sin bruker_id', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''owner_Bsomannen'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse owner_B INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''owner_BB2'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''owner_BA1'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B FLYTTER raden til manager_B1', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000b001'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B UPDATE B2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B DELETE B2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse owner_B DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B ser kjedens null-stasjonsrad', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse owner_B ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B1 -> ser', exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'positiv');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_tillatt('kontrolltiltak_bekreftelse manager_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_B1B1'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 INSERT med owner_B sin bruker_id', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''manager_B1somannen'', ''00000000-0000-0000-0000-00000000b000'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''manager_B1B2'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''manager_B1A1'', ''00000000-0000-0000-0000-00000000b001'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 FLYTTER raden til owner_B', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000b000'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 UPDATE B2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 DELETE B2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse manager_B1 DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse manager_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea64-0000-4000-8000-00009d6fea64'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea65-0000-4000-8000-00009d6fea65'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '9d6fea45-0000-4000-8000-00009d6fea45'), 'negativ');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 INSERT B1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', ''tablet_B1B1'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 INSERT B2', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', ''tablet_B1B2'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 INSERT A1', 'insert into public.kontrolltiltak_bekreftelse (retailer_id, stasjon_id, versjon, bruker_id) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', ''tablet_B1A1'', ''00000000-0000-0000-0000-00000000b101'')');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 UPDATE B1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 FLYTTER raden til owner_B', 'update public.kontrolltiltak_bekreftelse set bruker_id = ''00000000-0000-0000-0000-00000000b000'' where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 UPDATE B2', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 UPDATE A1', 'update public.kontrolltiltak_bekreftelse set versjon = ''endret av sonden'' where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 DELETE B1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea64-0000-4000-8000-00009d6fea64''', 'kontrolltiltak_bekreftelse', '9d6fea64-0000-4000-8000-00009d6fea64', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 DELETE B2', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea65-0000-4000-8000-00009d6fea65''', 'kontrolltiltak_bekreftelse', '9d6fea65-0000-4000-8000-00009d6fea65', 'id');
select pg_temp.skriv_avvist('kontrolltiltak_bekreftelse tablet_B1 DELETE A1', 'delete from public.kontrolltiltak_bekreftelse where id = ''9d6fea45-0000-4000-8000-00009d6fea45''', 'kontrolltiltak_bekreftelse', '9d6fea45-0000-4000-8000-00009d6fea45', 'id');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 ser IKKE kjedens null-stasjonsrad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798d-0000-4000-8000-0000440b798d'), 'negativ');
select pg_temp.paastand('kontrolltiltak_bekreftelse tablet_B1 ser IKKE den andre kjedens null-rad', not exists (select 1 from public.kontrolltiltak_bekreftelse where id = '440b798c-0000-4000-8000-0000440b798c'), 'negativ');

-- =====================================================================
-- kunnskap  (global, warm)
-- =====================================================================
select pg_temp.sett_gruppe('kunnskap');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('kunnskap owner_A SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap owner_A INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gowner_Ainsert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap owner_A UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap owner_A DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('kunnskap manager_A1 SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap manager_A1 INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gmanager_A1insert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap manager_A1 UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap manager_A1 DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('kunnskap manager_A12 SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap manager_A12 INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gmanager_A12insert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap manager_A12 UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap manager_A12 DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('kunnskap tablet_A1 SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap tablet_A1 INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gtablet_A1insert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap tablet_A1 UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap tablet_A1 DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('kunnskap owner_B SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap owner_B INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gowner_Binsert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap owner_B UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap owner_B DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('kunnskap manager_B1 SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap manager_B1 INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gmanager_B1insert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap manager_B1 UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap manager_B1 DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('kunnskap tablet_B1 SELECT den globale raden -> ser', exists (select 1 from public.kunnskap where id = 'e3a71f0c-0000-4000-8000-0000e3a71f0c'), 'positiv');
select pg_temp.skriv_avvist('kunnskap tablet_B1 INSERT den globale raden', 'insert into public.kunnskap (tittel, innhold) values (''Sondeartikkel gtablet_B1insert'', ''Sondetekst'')');
select pg_temp.skriv_avvist('kunnskap tablet_B1 UPDATE den globale raden', 'update public.kunnskap set kategori = ''endret'' where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');
select pg_temp.skriv_avvist('kunnskap tablet_B1 DELETE den globale raden', 'delete from public.kunnskap where id = ''e3a71f0c-0000-4000-8000-0000e3a71f0c''', 'kunnskap', 'e3a71f0c-0000-4000-8000-0000e3a71f0c', 'id');

-- =====================================================================
-- lederstotte_rapporter  (retailer_and_station, warm)
-- =====================================================================
select pg_temp.sett_gruppe('lederstotte_rapporter');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');   -- owner_A
select pg_temp.paastand('lederstotte_rapporter owner_A SELECT A1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter owner_A SELECT A2 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8274-0000-4000-8000-0000d8ff8274'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter owner_A SELECT A3 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8275-0000-4000-8000-0000d8ff8275'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter owner_A SELECT B1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'negativ');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 181, ''{}''::jsonb)');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A INSERT A2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 182, ''{}''::jsonb)');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A INSERT A3', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 183, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_A INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 184, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A UPDATE A2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A UPDATE A3', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_A UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''');
select pg_temp.som_eier();
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8273-0000-4000-8000-0000d8ff8273', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', date '2026-01-01' + 185, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A DELETE A2', 'delete from public.lederstotte_rapporter where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''');
select pg_temp.som_eier();
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8274-0000-4000-8000-0000d8ff8274', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', date '2026-01-01' + 186, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_A DELETE A3', 'delete from public.lederstotte_rapporter where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''');
select pg_temp.som_eier();
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8275-0000-4000-8000-0000d8ff8275', 'aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', date '2026-01-01' + 187, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_A-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_A DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_A FLYTTER egen rad -> kjede B', 'update public.lederstotte_rapporter set retailer_id = ''bbbb0000-0000-4000-8000-000000000000'' where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');   -- manager_A1
select pg_temp.paastand('lederstotte_rapporter manager_A1 SELECT A1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter manager_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8274-0000-4000-8000-0000d8ff8274'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter manager_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8275-0000-4000-8000-0000d8ff8275'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter manager_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'negativ');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 188, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 INSERT A2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 189, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 INSERT A3', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 190, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 191, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 UPDATE A2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 UPDATE A3', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 DELETE A2', 'delete from public.lederstotte_rapporter where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 DELETE A3', 'delete from public.lederstotte_rapporter where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A1 DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');   -- manager_A12
select pg_temp.paastand('lederstotte_rapporter manager_A12 SELECT A1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter manager_A12 SELECT A2 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8274-0000-4000-8000-0000d8ff8274'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter manager_A12 SELECT A3 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8275-0000-4000-8000-0000d8ff8275'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter manager_A12 SELECT B1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'negativ');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 192, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 INSERT A2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 193, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 INSERT A3', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 194, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 195, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 UPDATE A2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 UPDATE A3', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 DELETE A2', 'delete from public.lederstotte_rapporter where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 DELETE A3', 'delete from public.lederstotte_rapporter where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_A12-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_A12 DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');   -- tablet_A1
select pg_temp.paastand('lederstotte_rapporter tablet_A1 SELECT A1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter tablet_A1 SELECT A2 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8274-0000-4000-8000-0000d8ff8274'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter tablet_A1 SELECT A3 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8275-0000-4000-8000-0000d8ff8275'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter tablet_A1 SELECT B1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'negativ');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 196, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 INSERT A2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 197, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 INSERT A3', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000003'', date ''2026-01-01'' + 198, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 199, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 UPDATE A2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 UPDATE A3', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000002', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 DELETE A2', 'delete from public.lederstotte_rapporter where id = ''d8ff8274-0000-4000-8000-0000d8ff8274''', 'lederstotte_rapporter', 'd8ff8274-0000-4000-8000-0000d8ff8274', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000003', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 DELETE A3', 'delete from public.lederstotte_rapporter where id = ''d8ff8275-0000-4000-8000-0000d8ff8275''', 'lederstotte_rapporter', 'd8ff8275-0000-4000-8000-0000d8ff8275', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_A1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_A1 DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');   -- owner_B
select pg_temp.paastand('lederstotte_rapporter owner_B SELECT B1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter owner_B SELECT B2 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8293-0000-4000-8000-0000d8ff8293'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter owner_B SELECT A1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'negativ');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 200, ''{}''::jsonb)');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B INSERT B2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 201, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_B INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 202, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B UPDATE B2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_B UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''');
select pg_temp.som_eier();
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8292-0000-4000-8000-0000d8ff8292', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', date '2026-01-01' + 203, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_tillatt('lederstotte_rapporter owner_B DELETE B2', 'delete from public.lederstotte_rapporter where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''');
select pg_temp.som_eier();
insert into public.lederstotte_rapporter (id, retailer_id, stasjon_id, periode, rapport) values ('d8ff8293-0000-4000-8000-0000d8ff8293', 'bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', date '2026-01-01' + 204, '{}'::jsonb);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'owner_B-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_B DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.skriv_avvist('lederstotte_rapporter owner_B FLYTTER egen rad -> kjede A', 'update public.lederstotte_rapporter set retailer_id = ''aaaa0000-0000-4000-8000-000000000000'' where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');   -- manager_B1
select pg_temp.paastand('lederstotte_rapporter manager_B1 SELECT B1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter manager_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8293-0000-4000-8000-0000d8ff8293'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter manager_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'negativ');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 205, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 INSERT B2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 206, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 207, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 UPDATE B2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''', 'lederstotte_rapporter', 'd8ff8293-0000-4000-8000-0000d8ff8293', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 DELETE B2', 'delete from public.lederstotte_rapporter where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''', 'lederstotte_rapporter', 'd8ff8293-0000-4000-8000-0000d8ff8293', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'manager_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b001');
select pg_temp.skriv_avvist('lederstotte_rapporter manager_B1 DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');   -- tablet_B1
select pg_temp.paastand('lederstotte_rapporter tablet_B1 SELECT B1 -> ser', exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8292-0000-4000-8000-0000d8ff8292'), 'positiv');
select pg_temp.paastand('lederstotte_rapporter tablet_B1 SELECT B2 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8293-0000-4000-8000-0000d8ff8293'), 'negativ');
select pg_temp.paastand('lederstotte_rapporter tablet_B1 SELECT A1 -> ser ikke', not exists (select 1 from public.lederstotte_rapporter where id = 'd8ff8273-0000-4000-8000-0000d8ff8273'), 'negativ');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 INSERT B1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 208, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 INSERT B2', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''bbbb0000-0000-4000-8000-000000000000'', ''b1110000-0000-4000-8000-000000000002'', date ''2026-01-01'' + 209, ''{}''::jsonb)');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 INSERT A1', 'insert into public.lederstotte_rapporter (retailer_id, stasjon_id, periode, rapport) values (''aaaa0000-0000-4000-8000-000000000000'', ''a1110000-0000-4000-8000-000000000001'', date ''2026-01-01'' + 210, ''{}''::jsonb)');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 UPDATE B1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 UPDATE B2', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''', 'lederstotte_rapporter', 'd8ff8293-0000-4000-8000-0000d8ff8293', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-update') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 UPDATE A1', 'update public.lederstotte_rapporter set rapport = ''{"endret": true}''::jsonb where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 DELETE B1', 'delete from public.lederstotte_rapporter where id = ''d8ff8292-0000-4000-8000-0000d8ff8292''', 'lederstotte_rapporter', 'd8ff8292-0000-4000-8000-0000d8ff8292', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('bbbb0000-0000-4000-8000-000000000000', 'b1110000-0000-4000-8000-000000000002', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 DELETE B2', 'delete from public.lederstotte_rapporter where id = ''d8ff8293-0000-4000-8000-0000d8ff8293''', 'lederstotte_rapporter', 'd8ff8293-0000-4000-8000-0000d8ff8293', 'id');
select pg_temp.som_eier();
select pg_temp.nyrad_lederstotte_rapporter('aaaa0000-0000-4000-8000-000000000000', 'a1110000-0000-4000-8000-000000000001', 'tablet_B1-delete') as _;
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.skriv_avvist('lederstotte_rapporter tablet_B1 DELETE A1', 'delete from public.lederstotte_rapporter where id = ''d8ff8273-0000-4000-8000-0000d8ff8273''', 'lederstotte_rapporter', 'd8ff8273-0000-4000-8000-0000d8ff8273', 'id');

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
    raise exception 'TENANT-MATRISEN DEL 4/10: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen DEL 4/10: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
