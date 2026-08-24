-- =====================================================================
-- Sentiqa - RLS-dekning for AI-spoerrelaget
--
-- `rls_isolasjon.sql` beviser at tenant A aldri ser tenant B. Denne
-- gjoer det samme for HVERT domene AI-katalogen naa leser, fordi et
-- spoerrelag er nettopp saa trygt som den svakeste kilden i katalogen.
--
-- DEN VIKTIGE PAASTANDEN ER IKKE "sjefen ser ikke naboen". Den er
-- PARET: for hver kilde staar det en positiv paastand (sjefen ser sin
-- EGEN rad) ved siden av den negative. Uten den positive ville en tabell
-- der RLS ved et uhell nekter alt bestaatt hele fila - og en katalog
-- der ingenting kan leses ser noeyaktig ut som en katalog uten lekkasjer.
--
-- Kjoeres i Supabase SQL Editor. Ruller tilbake selv, trygg i produksjon.
-- Kjoer den etter enhver migrasjon som roerer policyer, sammen med
-- `rls_vakthund.sql`.
-- =====================================================================
begin;

-- --- Testdata --------------------------------------------------------
-- Tenant A: eier + butikksjef med KUN A-0001 av to stasjoner.
-- Tenant B: en stasjon som ingen i A skal naa.

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ea01', 'ai-eier-a@test.local'),
  ('00000000-0000-0000-0000-00000000e502', 'ai-sjef-a@test.local'),
  ('00000000-0000-0000-0000-00000000eb01', 'ai-eier-b@test.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('a1111111-1111-1111-1111-111111111111', 'AI Tenant A'),
  ('b2222222-2222-2222-2222-222222222222', 'AI Tenant B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000ea01', 'a1111111-1111-1111-1111-111111111111', 'retailer_admin', 'AI Eier A'),
  ('00000000-0000-0000-0000-00000000e502', 'a1111111-1111-1111-1111-111111111111', 'butikksjef',     'AI Sjef A'),
  ('00000000-0000-0000-0000-00000000eb01', 'b2222222-2222-2222-2222-222222222222', 'retailer_admin', 'AI Eier B');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('a0000000-0000-0000-0000-000000000001', 'a1111111-1111-1111-1111-111111111111', '9001', 'AI Dale',  'pendler'),
  ('a0000000-0000-0000-0000-000000000002', 'a1111111-1111-1111-1111-111111111111', '9002', 'AI Lone',  'utfart'),
  ('b0000000-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222', '9003', 'AI Fremmed','sentrum');

insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('00000000-0000-0000-0000-00000000e502', 'a0000000-0000-0000-0000-000000000001');

-- Hver kilde faar en rad paa ALLE TRE stasjonene, saa hver paastand kan
-- stilles som et par: ser jeg min egen, og ser jeg ingen andres.

-- Salg (v_butikksalg = daglig_salg uten drivstoff). Drivstoffraden er
-- med med vilje: den skal filtreres bort av viewet, ikke av RLS.
insert into public.daglig_salg
  (retailer_id, stasjon_id, dato, ean, varenavn, avdeling_kode, avdeling_navn,
   varegruppe_kode, antall, omsetning_eks_mva, bto_fortjeneste_kr) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, '111','Kaffe','130','VARM DRIKKE','13010', 10, 1000, 400),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, '999','Diesel','10','ENERGI','10', 5, 9000, 100),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', current_date - 1, '111','Kaffe','130','VARM DRIKKE','13010', 20, 2000, 800),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', current_date - 1, '111','Kaffe','130','VARM DRIKKE','13010', 30, 3000, 900);

insert into public.timesalg (retailer_id, stasjon_id, dato, time, salg, antall_kunder) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, '8-9', 500, 20),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', current_date - 1, '8-9', 700, 30),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', current_date - 1, '8-9', 900, 40);

insert into public.kassererstatistikk
  (retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn, bonger, makulerte_antall) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, '1', 'Kasserer A', 100, 2),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', current_date - 1, '1', 'Kasserer B', 200, 3),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', current_date - 1, '1', 'Kasserer C', 300, 4);

insert into public.synlig_svinn
  (retailer_id, stasjon_id, dato, varenavn, arsakskode, nettopris_total, antall) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, 'Bolle', 'KAST', 100, 2),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', current_date - 1, 'Bolle', 'KAST', 200, 4),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', current_date - 1, 'Bolle', 'KAST', 300, 6);

insert into public.regnskapslinjer
  (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett, sortering) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', date_trunc('month', current_date)::date, 'omsetning','110','Dagligvarer', 1000, 900, 1),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', date_trunc('month', current_date)::date, 'omsetning','110','Dagligvarer', 2000, 1800, 1),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', date_trunc('month', current_date)::date, 'omsetning','110','Dagligvarer', 3000, 2700, 1),
  -- Cluster-linje (stasjon_id null): kun eier skal naa den.
  ('a1111111-1111-1111-1111-111111111111', null, date_trunc('month', current_date)::date, 'omsetning','110','Dagligvarer sum', 3000, 2700, 1);

insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer) values
  ('a0000000-0000-0000-0000-000000000001', extract(year from current_date)::int, 1, 500),
  ('a0000000-0000-0000-0000-000000000002', extract(year from current_date)::int, 1, 600),
  ('b0000000-0000-0000-0000-000000000001', extract(year from current_date)::int, 1, 700);

-- bemanning_aar er retailer_admin-only (0082). Den ER grunnen til at
-- hent_timeregnskap er eier-only i katalogen, og paastanden under er
-- det som holder den begrunnelsen aerlig.
insert into public.bemanning_aar (stasjon_id, ar, timer_aar, fast_arsverk_timer) values
  ('a0000000-0000-0000-0000-000000000001', extract(year from current_date)::int, 6000, 1695);

insert into public.stempling (stasjon_id, ansatt_nr, ansatt_navn, dato, fra_tid, til_tid, minutter, betalt) values
  ('a0000000-0000-0000-0000-000000000001', '11', 'Ansatt A', current_date - 1, '08:00', '16:00', 480, true),
  ('a0000000-0000-0000-0000-000000000002', '22', 'Ansatt B', current_date - 1, '08:00', '16:00', 480, true),
  ('b0000000-0000-0000-0000-000000000001', '33', 'Ansatt C', current_date - 1, '08:00', '16:00', 480, true);

-- `type` og `kategori` er check-constraints, ikke fritekst. Verdiene
-- staar i 0023_ikmat.sql; oppfinner man egne, feiler fila paa
-- testdataene i stedet for paa det den skal maale.
insert into public.ik_kontrollpunkter (retailer_id, stasjon_id, navn, type) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001','Kjoel A','kjol'),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002','Kjoel B','kjol'),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001','Kjoel C','kjol');

insert into public.rutiner (retailer_id, stasjon_id, tittel) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001','Rutine A'),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002','Rutine B'),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001','Rutine C');

insert into public.avvik (retailer_id, stasjon_id, kategori, dato, beskrivelse) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001','produkt', current_date - 1, 'Avvik A'),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002','produkt', current_date - 1, 'Avvik B'),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001','produkt', current_date - 1, 'Avvik C');

insert into public.produksjonsplan_linjer (retailer_id, stasjon_id, dato, varenavn, planlagt) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', current_date - 1, 'Bolle', 10),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', current_date - 1, 'Bolle', 20),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', current_date - 1, 'Bolle', 30);

insert into public.skills_score (retailer_id, stasjon_id, prosent) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001', 80),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002', 90),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001', 70);

insert into public.oppgaver (retailer_id, stasjon_id, tittel) values
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000001','Oppgave A'),
  ('a1111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-000000000002','Oppgave B'),
  ('b2222222-2222-2222-2222-222222222222','b0000000-0000-0000-0000-000000000001','Oppgave C');

-- --- Hjelpere --------------------------------------------------------

create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid::text, 'role', 'authenticated')::text, true);
end $$;

create temp table if not exists ai_paastander (nr int, navn text, ok boolean);
grant all on ai_paastander to public;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql as $$
begin
  insert into ai_paastander (nr, navn, ok)
    select coalesce(max(nr), 0) + 1, p_navn, coalesce(p_ok, false) from ai_paastander;
end $$;

-- Paret. `p_egen` maa vaere sant OG `p_andres` usant. En kilde der alt
-- er stengt gir p_egen = false og faller her, i stedet for aa gli
-- gjennom som "ingen lekkasje".
create or replace function pg_temp.par(p_kilde text, p_egen boolean, p_andres boolean)
returns void language plpgsql as $$
begin
  perform pg_temp.paastand(p_kilde || ': sjefen SER sin egen rad', coalesce(p_egen, false));
  perform pg_temp.paastand(p_kilde || ': sjefen ser IKKE andre stasjoner', not coalesce(p_andres, true));
end $$;

set local role authenticated;

-- =====================================================================
-- BUTIKKSJEF A - tildelt kun 9001 AI Dale
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000e502');

select pg_temp.paastand('Scopet: sjefen ser NOEYAKTIG EN stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Scopet: og det er hennes egen',
  exists (select 1 from public.stasjoner where butikknummer = '9001'));
select pg_temp.paastand('Scopet: mine_stasjoner() gir samme svar',
  (select count(*) = 1 from public.mine_stasjoner()));

select pg_temp.par('v_butikksalg',
  exists (select 1 from public.v_butikksalg where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.v_butikksalg where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('timesalg',
  exists (select 1 from public.timesalg where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.timesalg where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('kassererstatistikk',
  exists (select 1 from public.kassererstatistikk where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.kassererstatistikk where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('synlig_svinn',
  exists (select 1 from public.synlig_svinn where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.synlig_svinn where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('regnskapslinjer',
  exists (select 1 from public.regnskapslinjer where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.regnskapslinjer where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('bemanning_maned',
  exists (select 1 from public.bemanning_maned where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.bemanning_maned where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('stempling',
  exists (select 1 from public.stempling where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.stempling where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('ik_kontrollpunkter',
  exists (select 1 from public.ik_kontrollpunkter where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.ik_kontrollpunkter where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('rutiner',
  exists (select 1 from public.rutiner where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.rutiner where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('avvik',
  exists (select 1 from public.avvik where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.avvik where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('produksjonsplan_linjer',
  exists (select 1 from public.produksjonsplan_linjer where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.produksjonsplan_linjer where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('skills_score',
  exists (select 1 from public.skills_score where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.skills_score where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('oppgaver',
  exists (select 1 from public.oppgaver where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.oppgaver where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('v_datadekning',
  exists (select 1 from public.v_datadekning where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.v_datadekning where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.par('v_bp_status_avdeling',
  exists (select 1 from public.v_bp_status_avdeling where stasjon_id = 'a0000000-0000-0000-0000-000000000001'),
  exists (select 1 from public.v_bp_status_avdeling where stasjon_id <> 'a0000000-0000-0000-0000-000000000001'));

-- Kjedetotalen ligger paa admin-nivaa. Katalogen sier `ingen_tilgang`;
-- her staar det hvorfor det er sant.
select pg_temp.paastand('regnskapslinjer: sjefen naar IKKE cluster-linjen (stasjon_id null)',
  (select count(*) = 0 from public.regnskapslinjer where stasjon_id is null));

-- Timeregnskapet er eier-only i katalogen NETTOPP fordi denne er stengt.
select pg_temp.paastand('bemanning_aar: sjefen naar den IKKE (grunnlaget for eier-only timeregnskap)',
  (select count(*) = 0 from public.bemanning_aar));

-- Drivstoff: filtrert av viewet, ikke av RLS. Faller denne, leser
-- salgsverktoeyet plutselig 68 % omsetning som ikke er butikkens.
select pg_temp.paastand('v_butikksalg: drivstoff er filtrert bort',
  (select count(*) = 0 from public.v_butikksalg where avdeling_kode = '10'));
select pg_temp.paastand('daglig_salg: drivstoffraden finnes fortsatt under viewet',
  exists (select 1 from public.daglig_salg
          where stasjon_id = 'a0000000-0000-0000-0000-000000000001' and avdeling_kode = '10'));

-- =====================================================================
-- EIER A - hele clusteret, aldri tenant B
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000ea01');

select pg_temp.paastand('Eier A ser begge sine stasjoner',
  (select count(*) = 2 from public.stasjoner));
select pg_temp.paastand('Eier A ser IKKE tenant B',
  (select count(*) = 0 from public.stasjoner
   where retailer_id = 'b2222222-2222-2222-2222-222222222222'));

select pg_temp.paastand('Eier A ser salg for BEGGE stasjoner (cluster-aggregering)',
  (select count(distinct stasjon_id) = 2 from public.v_butikksalg));
select pg_temp.paastand('Eier A ser regnskap for begge stasjoner',
  (select count(distinct stasjon_id) = 2 from public.regnskapslinjer where stasjon_id is not null));
select pg_temp.paastand('Eier A naar cluster-linjen',
  exists (select 1 from public.regnskapslinjer where stasjon_id is null));
select pg_temp.paastand('Eier A naar bemanning_aar (grunnlaget for timeregnskap)',
  exists (select 1 from public.bemanning_aar));
select pg_temp.paastand('Eier A ser svinn for begge stasjoner',
  (select count(distinct stasjon_id) = 2 from public.synlig_svinn));
select pg_temp.paastand('Eier A ser stempling for begge stasjoner',
  (select count(distinct stasjon_id) = 2 from public.stempling));

select pg_temp.paastand('Eier A ser INGEN salgsdata fra tenant B',
  (select count(*) = 0 from public.v_butikksalg
   where retailer_id = 'b2222222-2222-2222-2222-222222222222'));
select pg_temp.paastand('Eier A ser INGEN avvik fra tenant B',
  (select count(*) = 0 from public.avvik
   where retailer_id = 'b2222222-2222-2222-2222-222222222222'));
select pg_temp.paastand('Eier A ser INGEN stempling fra tenant B',
  (select count(*) = 0 from public.stempling
   where stasjon_id = 'b0000000-0000-0000-0000-000000000001'));

-- =====================================================================
-- EIER B - speilvendt, saa isolasjonen ikke bare gjelder en vei
-- =====================================================================
select pg_temp.logg_inn_som('00000000-0000-0000-0000-00000000eb01');

select pg_temp.paastand('Eier B ser sin egen stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Eier B ser sitt eget salg',
  exists (select 1 from public.v_butikksalg
          where stasjon_id = 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.paastand('Eier B ser INGEN av tenant A sine stasjoner',
  (select count(*) = 0 from public.stasjoner
   where retailer_id = 'a1111111-1111-1111-1111-111111111111'));
select pg_temp.paastand('Eier B ser INGEN av tenant A sine salgsrader',
  (select count(*) = 0 from public.v_butikksalg
   where retailer_id = 'a1111111-1111-1111-1111-111111111111'));
select pg_temp.paastand('Eier B ser INGEN av tenant A sitt regnskap',
  (select count(*) = 0 from public.regnskapslinjer
   where retailer_id = 'a1111111-1111-1111-1111-111111111111'));

reset role;

-- =====================================================================
-- SVARET. Feil foerst, saa raden som betyr noe staar oeverst.
-- =====================================================================
select
  case when ok then 'ok' else 'FEIL' end as status,
  navn                                   as paastand
from ai_paastander
order by ok, nr;

rollback;
