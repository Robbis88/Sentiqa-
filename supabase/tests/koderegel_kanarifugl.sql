-- =====================================================================
-- BEVISER DEN SEMANTISKE KODEMAPPINGEN
--
-- Skrevet FOER 0152, med vilje. En vakt som lages etter en migrasjon
-- fester det som allerede skjedde, og beviser ingenting om hva som ble
-- endret. Denne feiler til 0152 finnes.
--
-- Kjoerer i en transaksjon som rulles tilbake. Seeder sin egen kjede med
-- drivstoff paa avdelingskode 77 - en kode St1 ikke bruker - saa den
-- beviser generaliseringen og ikke bare at Kelsars tall staar.
--
-- ---------------------------------------------------------------------
-- HVA DEN MAALER, OG HVA DEN IKKE MAALER
--
-- Fila kjoerer som `postgres`. `v_butikksalg` er `security_invoker`, saa
-- viewet leses da som eier og RLS filtrerer ikke. Det er MED VILJE:
-- seksjon A-E maaler viewets EGEN fail-close-logikk, som ligger i
-- `where`-klausulen og ikke i RLS.
--
-- Seksjon F logger inn som en ekte bruker og maaler det andre: at RLS og
-- policyene paa de nye tabellene slipper henne til. **Uten F ville en
-- glemt select-policy paa `retailer_kodeerklaering` gitt null rader for
-- hver eneste bruker** - joinen i viewet ville ikke funnet erklaeringen.
-- Det er den feilen som er lettest aa gjoere og vanskeligst aa se.
-- =====================================================================

begin;

create temp table funn (status text, navn text, detalj text, nr serial)
  on commit drop;

create or replace function pg_temp.sjekk(p_navn text, p_faktisk bigint, p_ventet bigint)
returns void language plpgsql as $$
begin
  insert into funn (status, navn, detalj)
  values (case when p_faktisk = p_ventet then 'ok' else 'FEIL' end, p_navn,
          'ventet ' || p_ventet || ', fikk ' || p_faktisk);
end $$;

create or replace function pg_temp.ser(p_navn text, p_ok boolean) returns void
language plpgsql as $$
begin
  insert into funn (status, navn, detalj)
  values (case when p_ok then 'ok' else 'FEIL' end, p_navn,
          case when p_ok then null else 'forventet det motsatte' end);
end $$;

-- --- Kanarikjeden: drivstoff paa kode 77, ikke 1000 -----------------

insert into public.retailers (id, navn, slug) values
  ('ffff0000-0000-4000-8000-00000000ffff', 'Kanari Energi AS', 'kanari-sonde');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
values ('ffff1110-0000-4000-8000-000000000001',
        'ffff0000-0000-4000-8000-00000000ffff', '7701', 'Kanari Sentrum', 'sentrum');

-- Brukeren seedes her og ikke i seksjon F, fordi `kontrollert_av` er en
-- fremmednoekkel mot `profiler` og constrainten
-- `(kontrollert_av is null) = (kontrollert_tid is null)` krever at begge
-- settes sammen. En kontroll uten hvem som kontrollerte finnes ikke.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000f000', 'sonde-kanari@example.invalid');
insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000f000',
   'ffff0000-0000-4000-8000-00000000ffff', 'retailer_admin', 'kanari_eier');

-- Tre butikkrader og to drivstoffrader. Drivstoffet heter ikke ENERGI
-- heller - hverken koden eller navnet er St1s, saa en mapping som
-- fortsatt hviler paa litteralene ville ikke truffet.
insert into public.daglig_salg
  (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
   varegruppe_kode, omsetning_eks_mva, antall)
values
  ('ffff0000-0000-4000-8000-00000000ffff','ffff1110-0000-4000-8000-000000000001',
   current_date,'7050000000101','120','MAT','1201',100,1),
  ('ffff0000-0000-4000-8000-00000000ffff','ffff1110-0000-4000-8000-000000000001',
   current_date,'7050000000102','120','MAT','1216',200,2),
  ('ffff0000-0000-4000-8000-00000000ffff','ffff1110-0000-4000-8000-000000000001',
   current_date,'7050000000103','130','VARM DRIKKE','1301',50,1),
  ('ffff0000-0000-4000-8000-00000000ffff','ffff1110-0000-4000-8000-000000000001',
   current_date,'7050000000201','77','PUMPE','7701',9000,1),
  ('ffff0000-0000-4000-8000-00000000ffff','ffff1110-0000-4000-8000-000000000001',
   current_date,'7050000000202','77','PUMPE','7702',8000,1);

-- --- Nabokjeden, seedet her og ikke laant fra basen ------------------
-- Uten den ville "ser ingen andres rader" vaert sant fordi det ikke
-- fantes noen. I CI bygges basen bare av migrasjonene.

insert into public.retailers (id, navn, slug) values
  ('eeee0000-0000-4000-8000-00000000eeee', 'Nabo Drift AS', 'nabo-kode-sonde');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
values ('eeee1110-0000-4000-8000-000000000001',
        'eeee0000-0000-4000-8000-00000000eeee', '8801', 'Nabo Nord', 'bydel');

insert into public.daglig_salg
  (retailer_id, stasjon_id, dato, ean, avdeling_kode, avdeling_navn,
   varegruppe_kode, omsetning_eks_mva, antall)
values
  ('eeee0000-0000-4000-8000-00000000eeee','eeee1110-0000-4000-8000-000000000001',
   current_date,'7050000000301','120','MAT','1201',300,3);

-- Naboen erklaerer og mapper, saa den er "aapen" og kan lekke hvis
-- viewet skulle blande kjedene.
insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder)
values ('eeee0000-0000-4000-8000-00000000eeee', 'drivstoff', true);
insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
values ('eeee0000-0000-4000-8000-00000000eeee', 'drivstoff', 'avdeling', '99', null);

-- =====================================================================
-- A. UTEN ERKLAERING: INGENTING SLIPPER GJENNOM
-- =====================================================================
-- Fail-closed. Tom mapping betyr IKKE "ingen drivstoff" - den betyr
-- "uavklart", og uavklart gir null rader, ikke gale tall.

select pg_temp.sjekk('A1 daglig_salg har radene',
  (select count(*) from public.daglig_salg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 5);

select pg_temp.sjekk('A2 uten erklaering ser v_butikksalg INGEN',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 0);

-- =====================================================================
-- B. OPPGITT "INGEN DRIVSTOFF", IKKE KONTROLLERT: FORTSATT LAAST
-- =====================================================================
-- Paastanden aapner ALLE rader. Derfor teller den ikke foer noen hos
-- Sentiqa har sett paa den.

insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder)
values ('ffff0000-0000-4000-8000-00000000ffff', 'drivstoff', false);

select pg_temp.sjekk('B1 oppgitt ingen, ikke kontrollert: fortsatt 0',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 0);

-- =====================================================================
-- C. KONTROLLERT "INGEN DRIVSTOFF": ALT KOMMER GJENNOM
-- =====================================================================
-- Den lett aa glemme. En kjede som har erklaert at de ikke har
-- drivstoff skal ikke faa NOE filtrert bort - heller ikke ved et uhell
-- paa en annen kjedes regler. Uten denne kunne viewet filtrert paa
-- Kelsars koder for alle, og A og E ville likevel bestaatt.

update public.retailer_kodeerklaering
   set kontrollert_tid = now(),
       kontrollert_av  = '00000000-0000-0000-0000-00000000f000'
 where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff';

select pg_temp.sjekk('C1 kontrollert ingen drivstoff: ALLE 5 rader',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 5);

-- =====================================================================
-- D. "HAR DRIVSTOFF" UTEN REGLER: LAAST IGJEN
-- =====================================================================
-- Halvferdig konfigurasjon er like farlig som ingen.

update public.retailer_kodeerklaering
   set gjelder = true, kontrollert_tid = null, kontrollert_av = null
 where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff';

select pg_temp.sjekk('D1 har drivstoff, ingen regler: 0 rader',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 0);

-- =====================================================================
-- E. REGEL PAA KODE 77: DRIVSTOFFET FORSVINNER, BUTIKKEN STAAR
-- =====================================================================
-- Generaliseringen. 77 er ikke St1s kode, og PUMPE er ikke ENERGI.

insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
values ('ffff0000-0000-4000-8000-00000000ffff', 'drivstoff', 'avdeling', '77', null);

select pg_temp.sjekk('E1 med regel 77: 3 butikkrader igjen',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 3);

select pg_temp.sjekk('E2 og drivstoffkronene er borte',
  (select coalesce(sum(omsetning_eks_mva), 0)::bigint from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 350);

select pg_temp.ser('E3 ingen rad med avdeling 77 igjen',
  not exists (select 1 from public.v_butikksalg
              where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'
                and avdeling_kode = '77'));

-- Navneregelen skal virke alene ogsaa - det var navnet som reddet
-- Kelsars filter da koden var feil i to aar.
delete from public.retailer_koderegel
 where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff';
insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
values ('ffff0000-0000-4000-8000-00000000ffff', 'drivstoff', 'avdeling', null, 'pumpe');

select pg_temp.sjekk('E4 regel paa NAVN alene, uten hensyn til store bokstaver',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 3);

-- =====================================================================
-- F. EN EKTE BRUKER SER SINE EGNE RADER
-- =====================================================================
-- Viewet joiner `retailer_kodeerklaering`. Mangler select-policyen der,
-- finner joinen ingenting, og HVER bruker ser null rader - mens denne
-- fila, som kjoerer som eier, ville vaert helt groenn.

create or replace function pg_temp.som_bruker(p_uid uuid) returns void
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

select pg_temp.som_bruker('00000000-0000-0000-0000-00000000f000');

create temp table sett as
select (select count(*) from public.retailer_kodeerklaering)      as erklaeringer,
       (select count(*) from public.retailer_koderegel)           as regler,
       (select count(*) from public.v_butikksalg)                 as butikkrader,
       (select count(*) from public.v_retailer_kodestatus)        as statusrader;

select pg_temp.som_eier();

select pg_temp.sjekk('F1 brukeren ser sin egen erklaering',
  (select erklaeringer from sett), 1);
select pg_temp.sjekk('F2 brukeren ser sin egen regel',
  (select regler from sett), 1);
select pg_temp.sjekk('F3 brukeren ser sine 3 butikkrader gjennom viewet',
  (select butikkrader from sett), 3);
select pg_temp.ser('F4 brukeren ser INGEN andres erklaering',
  (select erklaeringer from sett) = 1);

-- =====================================================================
-- G. NABOEN ER UROERT
-- =====================================================================

select pg_temp.sjekk('G1 naboens ene butikkrad staar',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'eeee0000-0000-4000-8000-00000000eeee'), 1);

select pg_temp.ser('KANARIFUGL: naboens rader fantes hele tiden',
  exists (select 1 from public.daglig_salg
          where retailer_id = 'eeee0000-0000-4000-8000-00000000eeee')
  and exists (select 1 from public.retailer_koderegel
              where retailer_id = 'eeee0000-0000-4000-8000-00000000eeee'));

select pg_temp.ser('KANARIFUGL: kanarikjeden har drivstoff aa filtrere',
  exists (select 1 from public.daglig_salg
          where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'
            and avdeling_kode = '77'));

-- =====================================================================
-- H. STATUSVIEWET SIER DET SAMME
-- =====================================================================
-- Ingen egen sannhet: samme konfigurasjon, samme svar.

select pg_temp.ser('H1 drivstoffstatus er mappet',
  (select status from public.v_retailer_kodestatus
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'
     and rolle = 'drivstoff') = 'mappet');

select pg_temp.ser('H2 produksjonsstatus er ikke konfigurert',
  (select status from public.v_retailer_kodestatus
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'
     and rolle = 'produksjon') = 'ikke_konfigurert');

insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
values ('ffff0000-0000-4000-8000-00000000ffff', 'produksjon', 'varegruppe', '1201', null);

select pg_temp.ser('H3 med en varegrupperegel er produksjon mappet',
  (select status from public.v_retailer_kodestatus
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'
     and rolle = 'produksjon') = 'mappet');

-- =====================================================================
-- I. TREFFKONTROLLEN SER OM MAPPINGEN GJOER NOE
-- =====================================================================

select pg_temp.ser('I1 mappingen treffer data',
  (select treff_rader from public.v_retailer_drivstofftreff
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff') = 2);

delete from public.retailer_koderegel
 where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff' and rolle = 'drivstoff';
insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
values ('ffff0000-0000-4000-8000-00000000ffff', 'drivstoff', 'avdeling', '9999', null);

select pg_temp.ser('I2 feil kode: treffer 0, men det finnes salg',
  (select treff_rader = 0 and rader_i_vindu > 0
   from public.v_retailer_drivstofftreff
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'));

select pg_temp.sjekk('I3 og da er drivstoffet TILBAKE i butikktallene',
  (select count(*) from public.v_butikksalg
   where retailer_id = 'ffff0000-0000-4000-8000-00000000ffff'), 5);

-- I3 er ikke en feil i modellen - det er grunnen til at treffkontrollen
-- finnes. Statusen sier fortsatt "mappet", og bare tallet 0 avsloerer at
-- koden er feil.

-- --- Oppsummering ---------------------------------------------------

select status, navn, detalj from funn order by nr;

select case when exists (select 1 from funn where status <> 'ok')
            then 'FEIL: se radene over.'
            else 'OK - kodemappingen fail-closer, generaliserer til kode 77, '
                 || 'og en ekte bruker naar sine egne rader.' end as konklusjon,
       (select count(*) from funn where status = 'ok')  as bestatt,
       (select count(*) from funn where status <> 'ok') as feilet;

rollback;
