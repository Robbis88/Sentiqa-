-- =====================================================================
-- Sentiqa - svinn per maaned: isolasjon og regnestykke
--
-- Kjoeres i Supabase SQL Editor ETTER 0129_svinn_maaned.sql. Hele fila
-- kjoerer i én transaksjon og ruller tilbake til slutt - den lar
-- ingenting ligge igjen, og er trygg i produksjon.
--
-- DEN BEVISER TO TING SOM IKKE KAN BEVISES I VITEST:
--
--   1  At de fire viewene faktisk arver RLS. De er `security_invoker`,
--      men det staar bare i en `with`-klausul - og en view som mister
--      den ser noeyaktig ut som en som har den, helt til en butikksjef
--      ser en annen stasjons tall.
--
--   2  At `varekost_kr` kommer ut som NULL og ikke 0 naar en varegruppe
--      svinner uten aa selge. Den forskjellen forsvinner i hver eneste
--      aggregering nedstroems, og en 0-er her blir til «0,0 % svinn» -
--      et svar systemet ikke har dekning for.
--
-- KANARIFUGL: siste paastand krever at Admin A ser MER ENN NULL rader.
-- Uten den ville en view som returnerte tomt bestaatt hver eneste
-- «ser IKKE»-paastand over - og en test som ikke ser noe, ser noeyaktig
-- ut som en test som ikke finner noe galt.
-- =====================================================================
begin;

-- --- To kjeder, tre stasjoner ----------------------------------------
insert into auth.users (id, email) values
  ('5e000000-0000-4000-8000-000000000001', 'sv-admin-a@test.local'),
  ('5e000000-0000-4000-8000-000000000002', 'sv-sjef-a@test.local'),
  ('5e000000-0000-4000-8000-000000000003', 'sv-admin-b@test.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('5e111111-1111-4111-8111-111111111111', 'Svinn A'),
  ('5e222222-2222-4222-8222-222222222222', 'Svinn B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('5e000000-0000-4000-8000-000000000001', '5e111111-1111-4111-8111-111111111111', 'retailer_admin', 'Admin A'),
  ('5e000000-0000-4000-8000-000000000002', '5e111111-1111-4111-8111-111111111111', 'butikksjef',     'Sjef A'),
  ('5e000000-0000-4000-8000-000000000003', '5e222222-2222-4222-8222-222222222222', 'retailer_admin', 'Admin B');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('5eaa0000-0000-4000-8000-000000000001', '5e111111-1111-4111-8111-111111111111', '0001', 'A Ein',  'pendler'),
  ('5eaa0000-0000-4000-8000-000000000002', '5e111111-1111-4111-8111-111111111111', '0002', 'A Tvei', 'bydel'),
  ('5ebb0000-0000-4000-8000-000000000001', '5e222222-2222-4222-8222-222222222222', '0001', 'B Ein',  'sentrum');

-- Sjef A er tildelt KUN A-0001.
insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('5e000000-0000-4000-8000-000000000002', '5eaa0000-0000-4000-8000-000000000001');

-- --- Salget: nevneren ------------------------------------------------
--
-- FORRIGE MAANED, IKKE DENNE. En avsluttet maaned har `dager_hittil =
-- dager_i_maaned` uansett naar fila kjoeres. Laa dataene i
-- inneveaerende maaned, ville dekningspaastanden gitt ulikt svar den
-- 1. og den 28., og en test som svarer forskjellig fra dag til dag er
-- ikke en test.
--
-- To varegrupper med vilje. 9001 baade selger og svinner. 9002 SELGER
-- MEN SVINNER IKKE - og maa likevel telle i nevneren, ellers blir
-- stasjonens varekost summen av bare de gruppene som svinner, og
-- prosenten for hoey. Det er den samme feilen som den gamle
-- beregningen gjorde, bare et hakk finere.
--
-- Avdeling 120, ikke 10: drivstoff filtreres bort av `v_butikksalg`.
insert into public.daglig_salg (
  retailer_id, stasjon_id, dato, ean, varenavn,
  avdeling_kode, avdeling_navn, varegruppe_kode, varegruppe_navn,
  antall, omsetning_eks_mva, bto_fortjeneste_kr
) values
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-KOBLET', 'Koblet vare',
   '120', 'MAT', '9001', 'A-GRUPPE', 100, 100000, 60000),
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-SELGER', 'Selger uten svinn',
   '120', 'MAT', '9002', 'B-GRUPPE', 50, 50000, 30000),
  ('5e222222-2222-4222-8222-222222222222', '5ebb0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-KOBLET', 'Koblet vare',
   '120', 'MAT', '9001', 'A-GRUPPE', 900, 900000, 500000);

-- --- Svinnet: telleren -----------------------------------------------
--
-- TO ULIKE DAGER PAA A-0001, saa dekningen har noe aa telle. `SV-LOEST`
-- finnes ikke i salget - det er varmmat paa produksjonskode i
-- miniatyr, og skal komme ut som `koblet = false` med `varekost_kr`
-- NULL, ikke 0.
insert into public.synlig_svinn (
  retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total
) values
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-KOBLET', 'Koblet vare', 10, 1000),
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date + 1, 'SV-KOBLET', 'Koblet vare', 10, 1000),
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-LOEST', 'Loes vare', 5, 500),
  ('5e111111-1111-4111-8111-111111111111', '5eaa0000-0000-4000-8000-000000000002',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-KOBLET', 'Koblet vare', 7, 700),
  ('5e222222-2222-4222-8222-222222222222', '5ebb0000-0000-4000-8000-000000000001',
   date_trunc('month', current_date - interval '1 month')::date, 'SV-KOBLET', 'Koblet vare', 99, 9900);

-- --- Hjelpere --------------------------------------------------------
create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid::text, 'role', 'authenticated')::text, true);
end $$;

-- SAMLER I STEDET FOR AA KASTE. Kaster den paa foerste feil, forsvinner
-- alle paastandene etter den - da vet man at noe er galt, men ikke hvor
-- mye. Siste setning lister hver paastand med status, feil foerst.
create temp table if not exists paastander (
  nr int, navn text, ok boolean
);
grant all on paastander to public;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql as $$
begin
  insert into paastander (nr, navn, ok)
    select coalesce(max(nr), 0) + 1, p_navn, coalesce(p_ok, false) from paastander;
end $$;

set local role authenticated;

-- =====================================================================
-- ADMIN A - hele egen kjede, ikke ett tegn mer
-- =====================================================================
select pg_temp.logg_inn_som('5e000000-0000-4000-8000-000000000001');

select pg_temp.paastand('Admin A ser begge egne stasjoner i v_svinn_maaned',
  (select count(distinct stasjon_id) = 2 from public.v_svinn_maaned
   where svinn_kr > 0));

select pg_temp.paastand('Admin A ser IKKE kjede B i v_svinn_maaned',
  (select count(*) = 0 from public.v_svinn_maaned
   where retailer_id = '5e222222-2222-4222-8222-222222222222'));

-- 1000 + 1000 + 500 + 700 = 3200
select pg_temp.paastand('Admin A ser 3200 kr svinn i egen kjede',
  (select coalesce(sum(svinn_kr), 0) = 3200 from public.v_svinn_maaned));

-- 100000 - 60000 = 40000
select pg_temp.paastand('Varekost for gruppe 9001 er 40000, ikke omsetningen',
  (select varekost_kr = 40000 from public.v_svinn_maaned
   where gruppe_kode = '9001'
     and stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

-- FULL OUTER, IKKE LEFT. Gruppa som selger uten aa svinne maa vaere med.
select pg_temp.paastand('Gruppe som selger uten aa svinne er MED i nevneren',
  (select svinn_kr = 0 and varekost_kr = 20000 from public.v_svinn_maaned
   where gruppe_kode = '9002'
     and stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

-- =====================================================================
-- NULL ER IKKE NULL KRONER
-- =====================================================================
select pg_temp.paastand('Ukoblet svinn har gruppe_kode null og koblet = false',
  exists (select 1 from public.v_svinn_maaned
          where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'
            and gruppe_kode is null and koblet = false and svinn_kr = 500));

-- HELE POENGET. Kommer det ut 0 her, blir det til «0,0 % svinn»
-- nedstroems - en maaling systemet ikke har gjort.
select pg_temp.paastand('Ukoblet svinn har varekost_kr NULL, ikke 0',
  (select varekost_kr is null from public.v_svinn_maaned
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'
     and gruppe_kode is null));

select pg_temp.paastand('SV-LOEST har ingen varegruppe i v_vare_gruppe',
  (select count(*) = 0 from public.v_vare_gruppe where ean = 'SV-LOEST'));

select pg_temp.paastand('SV-KOBLET har noeyaktig én varegruppe',
  (select gruppe_kode = '9001' and antall_grupper = 1
   from public.v_vare_gruppe where ean = 'SV-KOBLET'));

-- =====================================================================
-- DEKNING - manglende registrering er ikke null svinn
-- =====================================================================
select pg_temp.paastand('A-0001 har to registrerte svinndager',
  (select dager_registrert = 2 from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

select pg_temp.paastand('dager_hittil overstiger aldri dager_i_maaned',
  (select bool_and(dager_hittil <= dager_i_maaned) from public.v_svinn_dekning));

-- AVSTANDEN MELLOM FOERINGENE. Maten kastes hver dag; det som varierer
-- er naar det blir foert. Her ligger de to foeringene én dag fra
-- hverandre.
select pg_temp.paastand('Snittintervallet mellom foeringene er 1 dag',
  (select snitt_intervall_dager = 1 from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

-- A-0002 har bare én foering, og én foering har ingen avstand til noe.
select pg_temp.paastand('Én foering gir NULL intervall, ikke 0',
  (select snitt_intervall_dager is null from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000002'));

-- STOERSTE ENKELTLINJE. A-0001 har tre foeringer: 1000, 1000 og 500.
-- Den stoerste er 1000 av 2500 = 40 %.
select pg_temp.paastand('Stoerste enkeltlinje er 1000 kr',
  (select storste_linje_kr = 1000 from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

select pg_temp.paastand('...og det er 40 % av maaneden',
  (select storste_linje_andel = 0.4000 from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

-- ANDELEN ER ALLTID SATT, ogsaa naar den er liten. Et felt som bare
-- dukker opp naar systemet mener det er verdt det, er en skjult
-- terskel med en annen frakk.
select pg_temp.paastand('A-0002 har ogsaa en stoerste linje, med andel 1',
  (select storste_linje_kr = 700 and storste_linje_andel = 1.0000
   from public.v_svinn_dekning
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000002'));

-- =====================================================================
-- VARENIVAA
-- =====================================================================
select pg_temp.paastand('SV-KOBLET ligger under gruppe 9001 i vare-viewet',
  (select svinn_kr = 2000 and gruppe_kode = '9001'
   from public.v_svinn_vare_maaned
   where ean = 'SV-KOBLET'
     and stasjon_id = '5eaa0000-0000-4000-8000-000000000001'));

select pg_temp.paastand('SV-LOEST ligger uten gruppe, men er ikke borte',
  (select svinn_kr = 500 and gruppe_kode is null
   from public.v_svinn_vare_maaned where ean = 'SV-LOEST'));

-- =====================================================================
-- BUTIKKSJEF A - kun sin tildelte stasjon
-- =====================================================================
select pg_temp.logg_inn_som('5e000000-0000-4000-8000-000000000002');

select pg_temp.paastand('Sjef A ser kun A-0001 i v_svinn_maaned',
  (select count(*) = 0 from public.v_svinn_maaned
   where stasjon_id <> '5eaa0000-0000-4000-8000-000000000001'));

select pg_temp.paastand('Sjef A ser 2500 kr - sin egen stasjon, hele den',
  (select coalesce(sum(svinn_kr), 0) = 2500 from public.v_svinn_maaned));

select pg_temp.paastand('Sjef A ser IKKE stasjonen hun ikke er tildelt',
  (select count(*) = 0 from public.v_svinn_vare_maaned
   where stasjon_id = '5eaa0000-0000-4000-8000-000000000002'));

select pg_temp.paastand('Sjef A ser IKKE kjede B',
  (select count(*) = 0 from public.v_svinn_maaned
   where retailer_id = '5e222222-2222-4222-8222-222222222222'));

select pg_temp.paastand('Sjef A ser kun én dekningsrad',
  (select count(*) = 1 from public.v_svinn_dekning));

-- KANARIFUGL. Uten denne ville alle «ser IKKE»-paastandene over
-- bestaatt ogsaa om viewene returnerte tomt for alle.
select pg_temp.paastand('KANARIFUGL: Sjef A ser faktisk noe i det hele tatt',
  (select count(*) > 0 from public.v_svinn_maaned)
  and (select count(*) > 0 from public.v_svinn_vare_maaned));

-- =====================================================================
-- ADMIN B - den andre veien
-- =====================================================================
select pg_temp.logg_inn_som('5e000000-0000-4000-8000-000000000003');

select pg_temp.paastand('Admin B ser IKKE kjede A',
  (select count(*) = 0 from public.v_svinn_maaned
   where retailer_id = '5e111111-1111-4111-8111-111111111111'));

select pg_temp.paastand('Admin B ser sitt eget svinn paa 9900',
  (select coalesce(sum(svinn_kr), 0) = 9900 from public.v_svinn_maaned));

-- =====================================================================
-- RESULTATET - feil foerst
-- =====================================================================
reset role;

select
  case when ok then 'ok' else 'FEIL' end as status,
  nr,
  navn
from paastander
order by ok, nr;

rollback;
