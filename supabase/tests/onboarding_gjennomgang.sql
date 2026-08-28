-- =====================================================================
-- VIRKER ONBOARDINGEN ETTER SIKKERHETSARBEIDET?
--
-- Ni migrasjoner paa to dager (0140-0150) strammet policyer, tok bort
-- tilgang og la til rollepredikater. Atferdsmatrisen beviser at de
-- eksisterende kjedene fortsatt naar det de skal - men fikstureverdenen
-- dens har ALLTID stasjoner fra foer.
--
-- En helt ny konto har ingenting. `mine_stasjoner()` er tom, og hver
-- policy som sier `stasjon_id in (select public.mine_stasjoner())`
-- avviser alt. Det er riktig - det finnes ingen stasjon aa skrive rader
-- for - men det betyr at foerste steg maa virke uten den, ellers staar
-- en ny kunde bom fast paa ledd null.
--
-- Denne fila gaar veien: ny kjede, ny eier, foerste stasjon, foerste
-- opplasting, foerste tall, foerste maalekort. Som den nye brukeren,
-- gjennom RLS.
--
-- ---------------------------------------------------------------------
-- KJOERES SOM `postgres` (uten RLS paa oekten). Fila logger inn som den
-- nye eieren selv med `logg_inn_som()`, og trenger `som_eier()` for aa
-- seede. Alt ruller tilbake til slutt - den etterlater ingenting.
-- ---------------------------------------------------------------------

begin;

-- --- Hjelpere, som i atferdsmatrisen -------------------------------

create temp table funn (
  status text, navn text, detalj text, nr serial
) on commit drop;

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

-- LOGGEREN ER DEFINER, UTFOEREREN ER INVOKER. Temp-tabellen eies av
-- `postgres`, og oekten er `authenticated` fra og med innloggingen -
-- uten en definer-logger faar hver skriving 42501 paa selve loggen.
--
-- Men `steg` maa vaere INVOKER: blir den definer, kjoerer `execute` som
-- eier og forbi RLS, og fila blir groenn uansett hva policyen sier.
-- Samme skille som `skriv_avvist` i atferdsmatrisen.
create or replace function pg_temp.logg(p_status text, p_navn text, p_detalj text)
returns void language plpgsql security definer as $$
begin
  insert into funn values (p_status, p_navn, p_detalj);
end $$;

-- Et steg som SKAL gaa gjennom. Feiler det, staar den nye kunden fast.
create or replace function pg_temp.steg(p_navn text, p_sql text)
returns void language plpgsql security invoker as $$
begin
  execute p_sql;
  perform pg_temp.logg('ok', p_navn, 'gikk gjennom');
exception when others then
  perform pg_temp.logg('STOPPER', p_navn, sqlstate || ': ' || sqlerrm);
end $$;

-- En paastand om hva hun ser. Uttrykket er alt evaluert av kalleren, som
-- HENNE - det er derfor denne trygt kan vaere definer.
create or replace function pg_temp.ser(p_navn text, p_ok boolean) returns void
language plpgsql security definer as $$
begin
  perform pg_temp.logg(case when p_ok then 'ok' else 'FEIL' end, p_navn,
    case when p_ok then null else 'forventet det motsatte' end);
end $$;

-- --- Den nye kunden ------------------------------------------------
-- Bevisst IKKE St1: en kjede uten butikknummer i fasaden.

select pg_temp.som_eier();

insert into public.retailers (id, navn, slug) values
  ('cccc0000-0000-4000-8000-00000000cccc', 'Ny Kunde AS', 'ny-kunde-sonde');

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000c000', 'sonde-ny-kunde@example.invalid');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000c000',
   'cccc0000-0000-4000-8000-00000000cccc', 'retailer_admin', 'ny_eier');

-- NABOKJEDEN, seedet her og ikke laant fra basen.
--
-- Grensepaastandene under spoer om hun ser noe utenfor sin egen kjede.
-- I produksjon finnes Kelsar aa ikke se; i CI bygges basen bare av
-- migrasjonene, og da ville «ser ingen andres rader» vaert sant fordi
-- det ikke fantes noen. Da maaler fila ingenting - og den maa maale det
-- samme uansett hvor den kjoerer.

insert into public.retailers (id, navn, slug) values
  ('dddd0000-0000-4000-8000-00000000dddd', 'Nabokjeden AS', 'nabo-sonde');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
values ('dddd1110-0000-4000-8000-000000000001',
        'dddd0000-0000-4000-8000-00000000dddd', '9002', 'Nabo Sentrum', 'sentrum');

insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean)
values ('dddd0000-0000-4000-8000-00000000dddd',
        'dddd1110-0000-4000-8000-000000000001', current_date, '7050000000002');

insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash)
values ('dddd0000-0000-4000-8000-00000000dddd',
        'dddd1110-0000-4000-8000-000000000001', 'Nabo Naboson', '9002', 'x');

-- --- Fra og med her er hun seg selv --------------------------------

select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000c000');

-- LEDD 0: hjelperne maa kjenne henne. Uten dette svarer hver policy nei,
-- og alt under ville feilet av feil grunn.
select pg_temp.ser('hjelperen kjenner kjeden hennes',
  public.gjeldende_retailer_id() = 'cccc0000-0000-4000-8000-00000000cccc');
select pg_temp.ser('hjelperen kjenner rollen hennes',
  public.gjeldende_rolle()::text = 'retailer_admin');
select pg_temp.ser('hun har INGEN stasjoner enda',
  not exists (select 1 from public.stasjoner
              where retailer_id = 'cccc0000-0000-4000-8000-00000000cccc'));

-- LEDD 1: FOERSTE STASJON. Porten. Virker ikke denne, kommer hun
-- ingen vei - og policyen kan ikke hvile paa `mine_stasjoner()`, som er
-- tom for henne.
select pg_temp.steg('1. oppretter sin foerste stasjon', $s$
  insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
  values ('cccc1110-0000-4000-8000-000000000001',
          'cccc0000-0000-4000-8000-00000000cccc', '9001', 'Sonde Sentrum', 'sentrum')
$s$);

select pg_temp.ser('2. ser sin egen stasjon',
  exists (select 1 from public.stasjoner
          where id = 'cccc1110-0000-4000-8000-000000000001'));

-- LEDD 2: maalekortmotorens stasjonsliste. Det var denne som manglet i
-- produksjon (0075) og ga «Ingen stasjoner.»
select pg_temp.ser('3. malekort_stasjoner() gir henne stasjonen',
  (select count(*) from public.malekort_stasjoner()) = 1);

-- LEDD 3: OPPLASTINGEN. `0144` la et rollepredikat paa import_jobber.
select pg_temp.steg('4. lagrer en raafil', $s$
  insert into public.raa_filer (id, retailer_id, filnavn, storage_sti, mottakskanal)
  values ('cccc2220-0000-4000-8000-000000000001',
          'cccc0000-0000-4000-8000-00000000cccc',
          'sonde.csv', 'cccc/sonde.csv', 'drop_zone')
$s$);

select pg_temp.steg('5. oppretter en importjobb', $s$
  insert into public.import_jobber (retailer_id, raa_fil_id, stasjon_id)
  values ('cccc0000-0000-4000-8000-00000000cccc',
          'cccc2220-0000-4000-8000-000000000001',
          'cccc1110-0000-4000-8000-000000000001')
$s$);

-- LEDD 4: DE KRITISKE KILDENE. Salgsstatistikk baerer alt annet;
-- timesalg baerer bemanningen.
select pg_temp.steg('6. skriver salgstall', $s$
  insert into public.daglig_salg (retailer_id, stasjon_id, dato, ean)
  values ('cccc0000-0000-4000-8000-00000000cccc',
          'cccc1110-0000-4000-8000-000000000001', current_date, '7050000000001')
$s$);

select pg_temp.steg('7. skriver timesalg', $s$
  insert into public.timesalg (retailer_id, stasjon_id, dato, time)
  values ('cccc0000-0000-4000-8000-00000000cccc',
          'cccc1110-0000-4000-8000-000000000001', current_date, '12-13')
$s$);

-- LEDD 5: FOERSTE ANSATTE. Uten den finnes ingen nettbrettidentitet.
select pg_temp.steg('8. legger inn sin foerste ansatte', $s$
  insert into public.ansatte (retailer_id, stasjon_id, navn, ansatt_nr, pin_hash)
  values ('cccc0000-0000-4000-8000-00000000cccc',
          'cccc1110-0000-4000-8000-000000000001', 'Sonde Sondesen', '9001', 'x')
$s$);

-- LEDD 6: FOERSTE MAALEKORT. Det som ikke virket i dag.
select pg_temp.steg('9. lager sitt foerste maalekort', $s$
  insert into public.malekort (retailer_id, navn, metrikk)
  values ('cccc0000-0000-4000-8000-00000000cccc', 'Sondekort', 'omsetning')
$s$);

-- --- OG GRENSEN STAAR ----------------------------------------------
-- En ny kunde skal ikke se noe som helst av en annens kjede. Uten disse
-- ville en gjennomgang der ALT er aapent ogsaa sett vellykket ut.

select pg_temp.ser('GRENSE: ser INGEN stasjon utenfor egen kjede',
  not exists (select 1 from public.stasjoner
              where retailer_id <> 'cccc0000-0000-4000-8000-00000000cccc'));
select pg_temp.ser('GRENSE: ser INGEN salgsrad utenfor egen kjede',
  not exists (select 1 from public.daglig_salg
              where retailer_id <> 'cccc0000-0000-4000-8000-00000000cccc'));
select pg_temp.ser('GRENSE: ser INGEN ansatt utenfor egen kjede',
  not exists (select 1 from public.ansatte
              where retailer_id <> 'cccc0000-0000-4000-8000-00000000cccc'));
select pg_temp.ser('GRENSE: malekort_stasjoner() gir BARE hennes egen',
  (select count(*) from public.malekort_stasjoner()) = 1);

-- --- Oppsummering --------------------------------------------------

select pg_temp.som_eier();

-- KANARIFUGL PAA GRENSEN. «Ser ingen andres rader» er en tom seier hvis
-- det ikke FINNES andres rader. Denne kjoeres som eier, uten RLS, og
-- beviser at det var noe aa ikke se - nabokjeden vi seedet oeverst.
select pg_temp.ser('KANARIFUGL: nabokjedens rader fantes hele tiden',
  exists (select 1 from public.stasjoner
          where retailer_id = 'dddd0000-0000-4000-8000-00000000dddd')
  and exists (select 1 from public.daglig_salg
              where retailer_id = 'dddd0000-0000-4000-8000-00000000dddd')
  and exists (select 1 from public.ansatte
              where retailer_id = 'dddd0000-0000-4000-8000-00000000dddd'));

select status, navn, detalj from funn order by nr;

select case
    when exists (select 1 from funn where status <> 'ok')
      then 'STOPPER: onboardingen henger paa noe. Se radene over.'
    else 'OK - en helt ny kunde kommer fra tom konto til foerste maalekort.'
  end as konklusjon,
  (select count(*) from funn where status = 'ok')  as bestatt,
  (select count(*) from funn where status <> 'ok') as feilet;

rollback;
