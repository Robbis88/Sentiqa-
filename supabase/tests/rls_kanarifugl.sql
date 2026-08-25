-- =====================================================================
-- Sentiqa - TENANT-KANARIFUGL (PORT 1)
--
-- rls_isolasjon.sql beviser at A ikke SER B. Denne beviser at A ikke kan
-- SKRIVE til B - og at butikksjefen med to av tre stasjoner faar
-- noeyaktig to.
--
-- Kjor HELE fila i Supabase SQL Editor. Den ruller tilbake selv og
-- etterlater ingenting. Kaster exception ved foerste funn.
--
-- ---------------------------------------------------------------------
-- DEN VIKTIGSTE LINJA I FILA
--
-- En BLOKKERT UPDATE ER IKKE EN FEIL. Naar `using` utelukker raden,
-- treffer setningen null rader og Postgres sier ingenting. Bare INSERT
-- (og UPDATE som bryter `with check`) kaster 42501.
--
--   insert forbudt rad   -> exception 42501
--   update forbudt rad   -> 0 rader, INGEN exception
--   delete forbudt rad   -> 0 rader, INGEN exception
--
-- En test som bare fanger unntak ville altsaa vaert groenn for update og
-- delete uansett hva policyen sa. `skriv_avvist` krever DERFOR enten et
-- unntak ELLER null rader - og `skriv_tillatt` krever minst en rad, saa
-- en policy som blokkerer for mye ogsaa blir sett.
--
-- ---------------------------------------------------------------------
-- KOLLIDERENDE DATA MED VILJE
--
-- Butikknummer, ansatt_nr, datoer og beskrivelser er BEVISST like paa
-- tvers av A og B. En test som bestaar fordi radene tilfeldigvis er
-- ulike, beviser ingenting. Finner sjef A en rad med teksten
-- 'Kjoledisk 4 grader for varm', skal den vaere HENNES - ikke B sin.
--
-- UUID-ENE ER OFFENTLIGE. Hver forbudt skriving bruker den EKTE id-en
-- til den forbudte stasjonen, slik en klient kunne sendt den inn fra et
-- manipulert skjema. Vanskelig aa gjette er ikke et vern.
-- =====================================================================
begin;

-- --- Identiteter -----------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a000', 'owner-a@kanari.local'),
  ('00000000-0000-0000-0000-00000000a001', 'manager-a1@kanari.local'),
  ('00000000-0000-0000-0000-00000000a012', 'manager-a12@kanari.local'),
  ('00000000-0000-0000-0000-00000000a101', 'tablet-a1@kanari.local'),
  ('00000000-0000-0000-0000-00000000b000', 'owner-b@kanari.local'),
  ('00000000-0000-0000-0000-00000000b001', 'manager-b1@kanari.local'),
  ('00000000-0000-0000-0000-00000000b101', 'tablet-b1@kanari.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('aaaa0000-0000-4000-8000-000000000000', 'Kanari A'),
  ('bbbb0000-0000-4000-8000-000000000000', 'Kanari B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'retailer_admin',       'Eier A'),
  ('00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef',           'Sjef A1'),
  ('00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef',           'Sjef A1+A2'),
  ('00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'butikkbruker_tablet',  'Nettbrett A1'),
  ('00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'retailer_admin',       'Eier B'),
  ('00000000-0000-0000-0000-00000000b001', 'bbbb0000-0000-4000-8000-000000000000', 'butikksjef',           'Sjef B1'),
  ('00000000-0000-0000-0000-00000000b101', 'bbbb0000-0000-4000-8000-000000000000', 'butikkbruker_tablet',  'Nettbrett B1');

-- SAMME BUTIKKNUMMER I BEGGE KJEDER. 0001 finnes to ganger med vilje.
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

-- SAMME ANSATT_NR I BEGGE KJEDER, og samme navn. Se
-- sentiqa-tre-identiteter: en kobling paa navn eller nummer alene ville
-- blandet disse to menneskene.
insert into public.ansatte (id, retailer_id, stasjon_id, navn, ansatt_nr, pin_hash) values
  ('a2220000-0000-4000-8000-000000000001', 'aaaa0000-0000-4000-8000-000000000000',
   'a1110000-0000-4000-8000-000000000001', 'Kim Hansen', '4501', 'x'),
  ('b2220000-0000-4000-8000-000000000001', 'bbbb0000-0000-4000-8000-000000000000',
   'b1110000-0000-4000-8000-000000000001', 'Kim Hansen', '4501', 'x');

-- SAMME DATO OG SAMME TEKST paa alle fem stasjoner.
insert into public.avvik (id, retailer_id, stasjon_id, dato, beskrivelse) values
  ('a3330000-0000-4000-8000-000000000001', 'aaaa0000-0000-4000-8000-000000000000',
   'a1110000-0000-4000-8000-000000000001', date '2026-08-01', 'Kjoledisk 4 grader for varm'),
  ('a3330000-0000-4000-8000-000000000002', 'aaaa0000-0000-4000-8000-000000000000',
   'a1110000-0000-4000-8000-000000000002', date '2026-08-01', 'Kjoledisk 4 grader for varm'),
  ('a3330000-0000-4000-8000-000000000003', 'aaaa0000-0000-4000-8000-000000000000',
   'a1110000-0000-4000-8000-000000000003', date '2026-08-01', 'Kjoledisk 4 grader for varm'),
  ('b3330000-0000-4000-8000-000000000001', 'bbbb0000-0000-4000-8000-000000000000',
   'b1110000-0000-4000-8000-000000000001', date '2026-08-01', 'Kjoledisk 4 grader for varm'),
  ('b3330000-0000-4000-8000-000000000002', 'bbbb0000-0000-4000-8000-000000000000',
   'b1110000-0000-4000-8000-000000000002', date '2026-08-01', 'Kjoledisk 4 grader for varm');

-- --- Hjelpere --------------------------------------------------------
--
-- RESULTATET SKAL VAERE EN TABELL, IKKE EN NOTICE. Supabase SQL Editor
-- viser ikke `raise notice` i resultatpanelet - bare siste setnings
-- resultat, og unntaket hvis det kommer et. Foerste utgave av denne fila
-- kjorte gjennom og viste en tom kolonne. Groenn uten synlig bevis ser
-- lik ut som en test som ikke maalte noe. Samme grunn som rls_funn.sql.
--
-- Derfor: hver paastand skriver en rad, og siste setning leser dem ut.
create temp table funn (
  nr     serial primary key,
  status text not null,
  navn   text not null,
  detalj text
) on commit drop;

-- SECURITY DEFINER, og det er noedvendig: naar en paastand kjorer er
-- rollen satt til `authenticated`, som ikke eier temp-tabellen.
create or replace function pg_temp.logg(p_status text, p_navn text, p_detalj text default null)
returns void language plpgsql security definer as $$
begin
  insert into pg_temp.funn (status, navn, detalj) values (p_status, p_navn, p_detalj);
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

create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql security definer as $$
begin
  perform pg_temp.logg(case when p_ok is true then 'ok' else 'FEIL' end, p_navn);
end $$;

-- SECURITY INVOKER, og det er like noedvendig: den dynamiske setningen
-- MAA kjore som testbrukeren. Ble denne definer, ville skrivingen gaatt
-- som eier, forbi RLS - og fila ville vaert groenn uansett hva policyen
-- sa. De to funksjonene under er de eneste som ikke kan vaere definer.
create or replace function pg_temp.skriv_avvist(p_navn text, p_sql text) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    perform pg_temp.logg('ok', p_navn, 'avvist med ' || sqlstate);
    return;
  end;
  if n > 0 then
    perform pg_temp.logg('FEIL', p_navn, 'skrivingen gikk gjennom, ' || n || ' rad(er)');
  else
    perform pg_temp.logg('ok', p_navn, '0 rader');
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
    perform pg_temp.logg('FEIL', p_navn, 'ble blokkert: ' || sqlstate);
    return;
  end;
  if n = 0 then
    perform pg_temp.logg('FEIL', p_navn, 'traff 0 rader - blokkert i stillhet');
  else
    perform pg_temp.logg('ok', p_navn, n || ' rad');
  end if;
end $$;

-- =====================================================================
-- 1) LESING: delmengden. manager_A12 er hele poenget.
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.paastand('A12 ser noeyaktig to stasjoner',
  (select count(*) = 2 from public.stasjoner));
select pg_temp.paastand('A12 ser A1',
  exists (select 1 from public.stasjoner where id = 'a1110000-0000-4000-8000-000000000001'));
select pg_temp.paastand('A12 ser A2',
  exists (select 1 from public.stasjoner where id = 'a1110000-0000-4000-8000-000000000002'));
select pg_temp.paastand('A12 ser IKKE A3',
  not exists (select 1 from public.stasjoner where id = 'a1110000-0000-4000-8000-000000000003'));
select pg_temp.paastand('A12 ser IKKE B1',
  not exists (select 1 from public.stasjoner where id = 'b1110000-0000-4000-8000-000000000001'));

-- Avvik: to rader, og det er A1 og A2 sine - ikke B sine med samme tekst.
select pg_temp.paastand('A12 ser to avvik',
  (select count(*) = 2 from public.avvik));
select pg_temp.paastand('A12 sitt avvik hoerer til retailer A',
  (select bool_and(retailer_id = 'aaaa0000-0000-4000-8000-000000000000') from public.avvik));

-- manager_A1: en stasjon, en rad.
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');
select pg_temp.paastand('A1 ser en stasjon',  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('A1 ser ett avvik',   (select count(*) = 1 from public.avvik));
select pg_temp.paastand('A1 ser IKKE A2 sitt avvik',
  not exists (select 1 from public.avvik where id = 'a3330000-0000-4000-8000-000000000002'));

-- Ansatte: samme navn og samme nummer i begge kjeder.
select pg_temp.paastand('A1 ser en ansatt',   (select count(*) = 1 from public.ansatte));
select pg_temp.paastand('...og det er A sin Kim Hansen',
  exists (select 1 from public.ansatte where id = 'a2220000-0000-4000-8000-000000000001'));

-- =====================================================================
-- 2) SKRIVING: den negative matrisen.
--    Ekte UUID fra den forbudte stasjonen, slik en klient ville sendt den.
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a001');

select pg_temp.skriv_tillatt('A1 INSERT paa egen A1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000001', date '2026-08-02', 'egen')
$s$);

select pg_temp.skriv_avvist('A1 INSERT paa A2', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000002', date '2026-08-02', 'forbudt')
$s$);

select pg_temp.skriv_avvist('A1 INSERT paa A3', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000003', date '2026-08-02', 'forbudt')
$s$);

-- KRYSS-RETAILER, og med B sin egen retailer_id saa raden er internt
-- konsistent. Det er den formen et manipulert skjema faktisk ville hatt.
select pg_temp.skriv_avvist('A1 INSERT paa B1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('bbbb0000-0000-4000-8000-000000000000',
          'b1110000-0000-4000-8000-000000000001', date '2026-08-02', 'forbudt')
$s$);

-- Og med A sin retailer_id paa B sin stasjon - den blandede formen.
select pg_temp.skriv_avvist('A1 INSERT paa B1 med A sin retailer_id', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'b1110000-0000-4000-8000-000000000001', date '2026-08-02', 'forbudt')
$s$);

select pg_temp.skriv_avvist('A1 UPDATE paa A2', $s$
  update public.avvik set beskrivelse = 'endret'
  where id = 'a3330000-0000-4000-8000-000000000002'
$s$);

select pg_temp.skriv_avvist('A1 UPDATE paa B1', $s$
  update public.avvik set beskrivelse = 'endret'
  where id = 'b3330000-0000-4000-8000-000000000001'
$s$);

-- FLYTT EGEN RAD TIL FORBUDT STASJON. Her er det `with check` som maa ta
-- den; `using` slipper raden inn fordi den ER hennes i utgangspunktet.
select pg_temp.skriv_avvist('A1 UPDATE flytter egen rad til A2', $s$
  update public.avvik set stasjon_id = 'a1110000-0000-4000-8000-000000000002'
  where id = 'a3330000-0000-4000-8000-000000000001'
$s$);

select pg_temp.skriv_avvist('A1 DELETE paa A2', $s$
  delete from public.avvik where id = 'a3330000-0000-4000-8000-000000000002'
$s$);

select pg_temp.skriv_avvist('A1 DELETE paa B1', $s$
  delete from public.avvik where id = 'b3330000-0000-4000-8000-000000000001'
$s$);

-- --- manager_A12: to tillatt, to avvist ------------------------------
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a012');

select pg_temp.skriv_tillatt('A12 INSERT paa A1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000001', date '2026-08-03', 'egen')
$s$);

select pg_temp.skriv_tillatt('A12 INSERT paa A2', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000002', date '2026-08-03', 'egen')
$s$);

select pg_temp.skriv_avvist('A12 INSERT paa A3', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000003', date '2026-08-03', 'forbudt')
$s$);

select pg_temp.skriv_avvist('A12 INSERT paa B1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('bbbb0000-0000-4000-8000-000000000000',
          'b1110000-0000-4000-8000-000000000001', date '2026-08-03', 'forbudt')
$s$);

select pg_temp.skriv_avvist('A12 UPDATE paa A3', $s$
  update public.avvik set beskrivelse = 'endret'
  where id = 'a3330000-0000-4000-8000-000000000003'
$s$);

-- --- Eier A: hele sitt cluster, aldri B ------------------------------
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a000');
select pg_temp.paastand('Eier A ser tre stasjoner', (select count(*) = 3 from public.stasjoner));
select pg_temp.paastand('Eier A ser INGEN B-stasjon',
  (select count(*) = 0 from public.stasjoner
    where retailer_id = 'bbbb0000-0000-4000-8000-000000000000'));

select pg_temp.skriv_tillatt('Eier A INSERT paa A3', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000003', date '2026-08-04', 'egen')
$s$);

select pg_temp.skriv_avvist('Eier A INSERT paa B1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('bbbb0000-0000-4000-8000-000000000000',
          'b1110000-0000-4000-8000-000000000001', date '2026-08-04', 'forbudt')
$s$);

select pg_temp.skriv_avvist('Eier A DELETE paa B1', $s$
  delete from public.avvik where id = 'b3330000-0000-4000-8000-000000000001'
$s$);

-- --- Eier B skal ikke se A sine nye rader -----------------------------
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b000');
select pg_temp.paastand('Eier B ser to stasjoner', (select count(*) = 2 from public.stasjoner));
select pg_temp.paastand('Eier B ser kun sine to avvik',
  (select count(*) = 2 from public.avvik));
select pg_temp.paastand('Eier B ser INGEN A-rad',
  (select count(*) = 0 from public.avvik
    where retailer_id = 'aaaa0000-0000-4000-8000-000000000000'));

-- =====================================================================
-- 3) NETTBRETTET. Maaler dagens tilstand, doemmer den ikke.
--
--    Produktkontrakten sier "ingen lederdata". Klassifiseringen av de
--    28 varme tabellene er ikke besluttet ennaa, saa disse paastandene
--    beskriver hva som ER tilfellet - ikke hva som BOER vaere det.
--    Endres kontrakten, skal de snus, og da sier de fra.
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

select pg_temp.paastand('Nettbrett A1 ser sin ene stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Nettbrett A1 ser IKKE A2',
  not exists (select 1 from public.stasjoner where id = 'a1110000-0000-4000-8000-000000000002'));
select pg_temp.paastand('Nettbrett A1 ser IKKE B',
  (select count(*) = 0 from public.stasjoner
    where retailer_id = 'bbbb0000-0000-4000-8000-000000000000'));

-- DAGENS TILSTAND: nettbrettet naar avvik paa egen stasjon, fordi
-- avvik_les ikke har noe rollepredikat. Se PORT 1, klasse D.
select pg_temp.paastand('DAGENS TILSTAND: nettbrett A1 leser avvik paa egen stasjon',
  exists (select 1 from public.avvik where id = 'a3330000-0000-4000-8000-000000000001'));

-- DAGENS TILSTAND: malekort_les er retailer-scopet uten rollepredikat,
-- og `vis_tablet` leses aldri av RLS. Kolonnen finnes fra 0073 og
-- brukes bare som visningsvilkaar i maaling/page.tsx.
select pg_temp.som_eier();
insert into public.malekort (id, retailer_id, navn, metrikk, periode, retning, vis_tablet, vis_butikksjef)
values ('a4440000-0000-4000-8000-000000000001', 'aaaa0000-0000-4000-8000-000000000000',
        'Skjult for nettbrett', 'omsetning', 'maaned', 'hoy', false, false);
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000a101');

-- SNUDD 2026-08-25, etter 0134. Paastanden sto som DAGENS TILSTAND og
-- maalte at nettbrettet naadde et kort merket vis_tablet = false. 0134
-- lot malekort_les lese flagget, og da sa paastanden fra - som den var
-- skrevet for aa gjore. Naa maaler den den nye tilstanden.
select pg_temp.paastand('Nettbrett A1 leser IKKE malekort med vis_tablet = false (0134)',
  not exists (select 1 from public.malekort where id = 'a4440000-0000-4000-8000-000000000001'));

-- Men aldri B sitt.
select pg_temp.paastand('Nettbrett A1 ser INGEN malekort fra B',
  (select count(*) = 0 from public.malekort
    where retailer_id = 'bbbb0000-0000-4000-8000-000000000000'));

-- Skriving: nettbrettet skal ikke kunne fjerne en hake (0133).
select pg_temp.skriv_avvist('Nettbrett A1 DELETE paa avvik', $s$
  delete from public.avvik where id = 'a3330000-0000-4000-8000-000000000001'
$s$);

-- --- Nettbrett B1 naar aldri A ---------------------------------------
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000b101');
select pg_temp.paastand('Nettbrett B1 ser INGEN A-stasjon',
  (select count(*) = 0 from public.stasjoner
    where retailer_id = 'aaaa0000-0000-4000-8000-000000000000'));
select pg_temp.skriv_avvist('Nettbrett B1 INSERT paa A1', $s$
  insert into public.avvik (retailer_id, stasjon_id, dato, beskrivelse)
  values ('aaaa0000-0000-4000-8000-000000000000',
          'a1110000-0000-4000-8000-000000000001', date '2026-08-05', 'forbudt')
$s$);

-- =====================================================================
-- RESULTATET. Feil foerst, saa rekkefolgen de ble maalt i.
--
-- Er `status` 'ok' paa alle radene, holdt hele matrisen. Er den tom, har
-- ingenting kjort - og det er sitt eget funn.
-- =====================================================================
select pg_temp.som_eier();

select status, navn, detalj
from pg_temp.funn
order by (status = 'FEIL') desc, nr;

-- EXIT-KODEN MAA FOELGE TABELLEN.
--
-- Paastandene er RADER, ikke unntak - det er derfor resultatet er
-- lesbart. Men da gaar psql ut med 0 selv naar tabellen er full av
-- FEIL, og CI-jobben blir groenn. Det skjedde 2026-08-25 i den
-- genererte matrisen: elleve FEIL, groenn jobb.
--
-- Selecten over kjorer foerst, saa tabellen staar i loggen.
do $$
declare n int;
begin
  select count(*) into n from pg_temp.funn where status = 'FEIL';
  if n > 0 then
    raise exception 'KANARIFUGLEN: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Kanarifuglen: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
