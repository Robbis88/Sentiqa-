-- =====================================================================
-- Sentiqa - testdata for den lokale basen.
--
-- Kjores AUTOMATISK av `supabase start` og `supabase db reset`, etter at
-- migrasjonene 0001-> har gaatt. Den er derfor bare for LOKAL/CI-bruk, og
-- skal aldri kjores mot en base med ekte data.
--
-- Tidligere laa det en manuell utgave her med en <AUTH_UUID>-plassholder
-- som skulle limes inn for haand. Den ville krasjet hver eneste
-- `supabase start`, fordi plassholderen ikke er gyldig SQL.
--
-- HVORFOR AUTH-BRUKERE LAGES I SQL og ikke via admin-API-et: da trengs
-- ingen service-noekkel noe sted - ikke i repoet, ikke i CI, ikke i en
-- chat. Passordene under er kjente med vilje og gjelder KUN denne
-- lokale basen, som slettes naar kjoringen er ferdig.
--
-- MFA: eier og plattform-redaktor tvinges gjennom TOTP (se
-- src/lib/auth/mfa.ts). Derfor seedes bare butikksjef og nettbrett -
-- de to som kan logge inn uten en autentiseringsapp. Eier-flytene
-- trenger en seedet TOTP-faktor og hoerer til en senere runde.
-- =====================================================================

-- Faste UUID-er saa seeden er idempotent og testene kan referere dem.
--
--   kjede      11111111-1111-4111-8111-111111111111
--   stasjon A  22222222-2222-4222-8222-222222222222   (4177 Testby)
--   stasjon B  22222222-2222-4222-8222-333333333333   (9145 Testvik)
--   butikksjef 33333333-3333-4333-8333-111111111111
--   nettbrett  33333333-3333-4333-8333-222222222222
--
-- Skrevet ut i klartekst, ikke som psql-variabler. Foerste utgave brukte
-- `\set` og `:'navn'`, og feilet med «syntax error at or near ":"` -
-- Supabase-CLI-en sender fila som en BATCH til Postgres, ikke gjennom
-- psql, saa meta-kommandoene finnes ikke der.

insert into public.retailers (id, navn, slug, org_nr)
values ('11111111-1111-4111-8111-111111111111', 'Testkjeden', 'test', '999999999')
on conflict (id) do nothing;

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype, svinnterskel_prosent)
values
  ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111',
   '4177', 'Testby',  'pendler', 2.5),
  ('22222222-2222-4222-8222-333333333333', '11111111-1111-4111-8111-111111111111',
   '9145', 'Testvik', 'bydel',   2.5)
on conflict (id) do nothing;

-- --- Auth-brukere ----------------------------------------------------
-- Formen under er GoTrues egen. `identities` maa med: uten den finner
-- ikke passordinnlogging brukeren, og feilen ser ut som feil passord.
-- TOKEN-KOLONNENE MAA VAERE TOMME STRENGER, ikke NULL.
--
-- GoTrue leser dem inn i Go-strenger ved paalogging, og NULL gir
-- «converting NULL to string is unsupported». Feilen kommer paa
-- innlogging, ikke paa insert - saa seeden ser vellykket ut, og det er
-- forst i testen man ser at ingen kommer inn.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-111111111111',
   'authenticated', 'authenticated',
   'butikksjef@test.sentiqa.no', crypt('test-butikksjef-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-222222222222',
   'authenticated', 'authenticated',
   'nettbrett@test.sentiqa.no', crypt('test-nettbrett-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(), '33333333-3333-4333-8333-111111111111',
   '{"sub":"33333333-3333-4333-8333-111111111111","email":"butikksjef@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-111111111111', now(), now(), now()),
  (gen_random_uuid(), '33333333-3333-4333-8333-222222222222',
   '{"sub":"33333333-3333-4333-8333-222222222222","email":"nettbrett@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-222222222222', now(), now(), now())
on conflict (provider, provider_id) do nothing;

-- --- Profiler og stasjonstilgang -------------------------------------
insert into public.profiler (id, retailer_id, rolle, fullt_navn)
values
  ('33333333-3333-4333-8333-111111111111', '11111111-1111-4111-8111-111111111111',
   'butikksjef',          'Test Butikksjef'),
  ('33333333-3333-4333-8333-222222222222', '11111111-1111-4111-8111-111111111111',
   'butikkbruker_tablet', 'Test Nettbrett')
on conflict (id) do nothing;

-- har_stasjonstilgang() slaar opp i denne for BEGGE rollene (se 0001).
insert into public.butikksjef_stasjoner (profil_id, stasjon_id)
values
  ('33333333-3333-4333-8333-111111111111', '22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-111111111111', '22222222-2222-4222-8222-333333333333'),
  ('33333333-3333-4333-8333-222222222222', '22222222-2222-4222-8222-222222222222')
on conflict do nothing;

-- Ingen salgsdata med vilje. Sidene skal moete testene i TOM TILSTAND,
-- og det er en gyldig ting aa teste: tomme tilstander er de som aldri
-- ses under utvikling, fordi utvikleren alltid har data.
--
-- Det gjelder FORTSATT Testkjeden over. Analysedataene under ligger i en
-- EGEN kjede, nettopp for at begge tilstandene skal finnes samtidig:
-- Testkjeden er tom, Analysekjeden har tall. RLS holder dem fra
-- hverandre, saa den tomme tilstanden er like ekte som for.


-- =====================================================================
-- ANALYSEKJEDEN - deterministisk fixture for analysesidene.
--
-- HVORFOR EN EGEN KJEDE OG IKKE DATA I TESTKJEDEN:
--
-- Sju ruter testes i «taaler tom database» (e2e/innlogget.spec.ts). La
-- vi svinn- og salgsrader i Testkjeden, ville de testene fortsatt vaere
-- groenne - men de ville ikke lenger teste det de sier. En test som har
-- sluttet aa maale ser ut som en test som ikke finner noe.
--
-- Med to kjeder er BEGGE produkttilstandene ekte samtidig, og skillet
-- gaar gjennom RLS - altsaa den samme mekanismen som skiller to ekte
-- kunder. Tomtilstandstesten er derfor ogsaa en isolasjonstest.
--
-- ALLE TALL ER VALGT FOR AA TREFFE EKSISTERENDE LOGIKK. Ingen terskel er
-- endret, ingen beregning er rort. Se regnestykket ved hver blokk.
--
--   kjede       11111111-1111-4111-8111-222222222222
--   Underby     44444444-4444-4444-8444-111111111111  5101  2,0 % svinn
--   Grenseby    44444444-4444-4444-8444-222222222222  5102  2,8 % svinn
--   Overby      44444444-4444-4444-8444-333333333333  5103  4,0 % svinn
--   analysesjef 33333333-3333-4333-8333-333333333333
-- =====================================================================

insert into public.retailers (id, navn, slug, org_nr)
values ('11111111-1111-4111-8111-222222222222', 'Analysekjeden', 'analyse', '999999998')
on conflict (id) do nothing;

-- TERSKELEN ER DEN SAMME 2.5 SOM I TESTKJEDEN. Tre stasjoner fordi
-- terskelstatusen er per stasjon: skal alle tre tilstandene vises
-- samtidig, trengs tre rader. Det er testdata tilpasset systemet, ikke
-- omvendt.
insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype, svinnterskel_prosent)
values
  ('44444444-4444-4444-8444-111111111111', '11111111-1111-4111-8111-222222222222',
   '5101', 'Underby',  'pendler', 2.5),
  ('44444444-4444-4444-8444-222222222222', '11111111-1111-4111-8111-222222222222',
   '5102', 'Grenseby', 'bydel',   2.5),
  ('44444444-4444-4444-8444-333333333333', '11111111-1111-4111-8111-222222222222',
   '5103', 'Overby',   'bydel',   2.5)
on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-333333333333',
   'authenticated', 'authenticated',
   'analyse@test.sentiqa.no', crypt('test-analyse-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(), '33333333-3333-4333-8333-333333333333',
   '{"sub":"33333333-3333-4333-8333-333333333333","email":"analyse@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-333333333333', now(), now(), now())
on conflict (provider, provider_id) do nothing;

insert into public.profiler (id, retailer_id, rolle, fullt_navn)
values
  ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-222222222222',
   'butikksjef', 'Test Analysesjef')
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- EIEREN - og hvorfor hun ikke fantes for naa (bolge 3, port 0).
--
-- `retailer_admin` og `plattform_redaktor` TVINGES gjennom to-faktor
-- (src/lib/auth/mfa.ts). Fram til naa var TOTP slaatt AV i den lokale
-- Supabase-en, og da kunne ingen av de to rollene logge inn i CI i det
-- hele tatt. Folgen: eiergrenene - forsiden hans, regnskapets
-- kjedevisning, /analyse, /dekning, /plattform - hadde null dekning
-- gjennom hele redesignet, og testene hoppet over dem med en begrunnelse
-- som saa fornuftig ut.
--
-- INGEN FAKTOR SEEDES HER. Den kunne vaert stappet rett inn i
-- auth.mfa_factors, men da ville testen bevist at en seedet rad virker -
-- ikke at innrulleringen gjor det. I stedet logger testen inn, blir
-- tvunget til /sikkerhet slik en ekte ny eier blir, ruller inn gjennom
-- det ekte API-et, leser hemmeligheten fra manuell-inntastingsfeltet og
-- regner ut engangskoden selv. Samme kontrakt som et menneske.
--
-- Eieren ligger i Analysekjeden, der dataene er: da har eiergrenene
-- faktisk noe aa vise.
-- ---------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-444444444444',
   'authenticated', 'authenticated',
   'eier@test.sentiqa.no', crypt('test-eier-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(), '33333333-3333-4333-8333-444444444444',
   '{"sub":"33333333-3333-4333-8333-444444444444","email":"eier@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-444444444444', now(), now(), now())
on conflict (provider, provider_id) do nothing;

-- Eier trenger ingen rad i butikksjef_stasjoner: RLS gir retailer_admin
-- hele kjeden sin (stasjoner_select, 0001). Aa legge inn en likevel
-- ville skjult om den regelen slutter aa gjelde.
insert into public.profiler (id, retailer_id, rolle, fullt_navn)
values
  ('33333333-3333-4333-8333-444444444444', '11111111-1111-4111-8111-222222222222',
   'retailer_admin', 'Test Eier')
on conflict (id) do nothing;

insert into public.butikksjef_stasjoner (profil_id, stasjon_id)
values
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-111111111111'),
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-222222222222'),
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-333333333333')
on conflict do nothing;


-- ---------------------------------------------------------------------
-- PLATTFORM-REDAKTOREN - siste rolle uten CI-dekning (port 0, 4B).
--
-- Bolge 4A avslorte hullet: /plattform avviste eieren, fordi ruta er
-- plattform-redaktorens. Den rollen tvinges ogsaa gjennom to-faktor
-- (mfaPaakrevd), saa den hadde samme problem som eieren hadde for
-- bolge 3 - ingen kunne logge inn som den i CI, og /plattform,
-- /redaktor og /kunnskap sto dermed uten dekning.
--
-- STAAR UTENFOR ALLE KJEDER. `profil_retailer_paakrevd` (0001) krever
-- at nettopp denne rollen har retailer_id = null: hun publiserer PAA
-- TVERS av kunder og skal ikke hoere til noen av dem. Seeden foelger
-- den regelen i stedet for aa omgaa den - hadde vi gitt henne en kjede,
-- ville testen bevist noe annet enn det produksjonen gjor.
-- ---------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-555555555555',
   'authenticated', 'authenticated',
   'redaktor@test.sentiqa.no', crypt('test-redaktor-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(), '33333333-3333-4333-8333-555555555555',
   '{"sub":"33333333-3333-4333-8333-555555555555","email":"redaktor@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-555555555555', now(), now(), now())
on conflict (provider, provider_id) do nothing;

insert into public.profiler (id, retailer_id, rolle, fullt_navn)
values
  ('33333333-3333-4333-8333-555555555555', null,
   'plattform_redaktor', 'Test Redaktor')
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- MATSALGET - naevneren i svinn%.
--
-- Svinn% regnes IKKE av sida. `matsalg_vindu_sum` summerer
-- `v_salg_per_stasjon_dag.mat_omsetning`, som er
-- `sum(omsetning_eks_mva) filter (where avdeling_kode = '120')` over
-- `daglig_salg` (mig 0084). Derfor seedes avdeling 120, ikke et ferdig
-- prosenttall: fixturen skal gaa den samme veien som en ekte import.
--
-- 100 000 kr per stasjon gjor regnestykket lesbart - svinn i kroner blir
-- prosenten ganget med tusen.
--
-- AVDELING 120, IKKE 10. Drivstoff (ENERGI/10) filtreres bort av
-- visningen, og en fixture paa 10 ville gitt matsalg = 0 og svinn% =
-- null. Se AGENTS.md.
-- ---------------------------------------------------------------------
insert into public.daglig_salg (
  retailer_id, stasjon_id, dato, ean, varenavn,
  avdeling_kode, avdeling_navn, antall, omsetning_eks_mva, bto_fortjeneste_kr
)
values
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '7090000000120', 'Matsalg samlet', '120', 'MAT', 1000, 100000, 35000),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-222222222222',
   date '2026-03-17', '7090000000120', 'Matsalg samlet', '120', 'MAT', 1000, 100000, 35000),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-333333333333',
   date '2026-03-17', '7090000000120', 'Matsalg samlet', '120', 'MAT', 1000, 100000, 35000)
on conflict (retailer_id, stasjon_id, dato, ean) do nothing;


-- ---------------------------------------------------------------------
-- SVINNET PAA MAALEDAGEN - 2026-03-17, en TIRSDAG.
--
-- Sida finner selv siste dato med svinn og legger et rullende
-- 30-dagersvindu bakover: 2026-02-16 .. 2026-03-17. Alt svinn i vinduet
-- ligger paa denne ene dagen, saa vindussummen ER dagssummen:
--
--   Underby   1200 +  800 = 2000  /100000 = 2,0 %  <= 2,5   under terskel
--   Grenseby  1800 + 1000 = 2800  /100000 = 2,8 %  > 2,5, <= 3,125  like over
--   Overby    2500 + 1500 = 4000  /100000 = 4,0 %  > 3,125          godt over
--
-- Den midterste grensa er terskel * 1.25 = 3,125 - satt i sida, ikke
-- her, og ikke rort.
--
-- To varelinjer per stasjon, alle med ulikt belop, saa «Mest svinn
-- (varer)» faar en entydig rekkefolge: 2500, 1800, 1500, 1200, 1000, 800.
-- Uten ulike belop ville sorteringen vaert uavgjort, og testen flaky.
--
-- FORTEGNET ER POSITIVT. Det er konvensjonen sida regner med: KPI-en
-- viser `kr.format(total)` uten fortegnsvending, og AI-verktoyet summerer
-- likedan (src/lib/ai/verktoy.ts).
-- ---------------------------------------------------------------------
insert into public.synlig_svinn (
  retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total
)
select v.* from (values
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-111111111111'::uuid,
   date '2026-03-17', '7090000000011', 'Baguette skinke', 12::numeric, 1200::numeric),
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-111111111111'::uuid,
   date '2026-03-17', '7090000000012', 'Kaffe filter',     8::numeric,  800::numeric),
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-222222222222'::uuid,
   date '2026-03-17', '7090000000021', 'Wienerbrod',      18::numeric, 1800::numeric),
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-222222222222'::uuid,
   date '2026-03-17', '7090000000022', 'Yoghurt stor',    10::numeric, 1000::numeric),
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-333333333333'::uuid,
   date '2026-03-17', '7090000000031', 'Grillpolse',      25::numeric, 2500::numeric),
  ('11111111-1111-4111-8111-222222222222'::uuid, '44444444-4444-4444-8444-333333333333'::uuid,
   date '2026-03-17', '7090000000032', 'Salatbolle',      15::numeric, 1500::numeric)
) as v
where not exists (
  select 1 from public.synlig_svinn
  where retailer_id = '11111111-1111-4111-8111-222222222222'
);


-- ---------------------------------------------------------------------
-- PRODUKSJONSSALGET - grunnlaget for /produksjonsplan (pilot C).
--
-- LIGGER I JANUAR MED VILJE, altsaa UTENFOR svinnvinduet
-- (2026-02-16..2026-03-17). Bakevarer hoerer hjemme i avdeling 120, den
-- samme naevneren svinn% deles paa - laa de i vinduet, ville
-- produksjonsfixturen flyttet svinnprosentene i pilot B, og to fixturer
-- som drar i hverandre er verre enn ingen. Datoene holder dem fra
-- hverandre; ingen av dem trengte aa bli mindre ekte for det.
--
-- SLIK REGNER MOTOREN (src/lib/produksjonsplan.ts):
--   maaldag 2026-02-02 er en MANDAG. Siste salgsdag er 2026-02-01, saa
--   «nylig»-vinduet er 2026-01-05..2026-02-01 - 28 dager med nøyaktig
--   fire mandager. Fire er over grensa paa to, saa basis blir snittet av
--   MANDAGENE, ikke av alle dager.
--
--   Ingen fjoraarsdata finnes (fjorbasen er 2025-02-03), saa hvert
--   produkt faar flagget «ny» og basis fra nylig salg. Uten vaervarsel er
--   vaerfaktoren 1, uten fjoraar er trendfaktoren 1, og uten arrangement
--   er den faktoren 1. Forslaget blir da nøyaktig snittet:
--
--     Grovbaguette      20/dag  ->  20
--     Rundstykke grovt  12/dag  ->  12
--     Polse i lompe      8/dag  ->   8
--
--   1201 BAKEVARER = 32 stk, 1216 VARMMAT = 8 stk, i alt 40.
--
-- Konstant antall per dag er ikke latskap: da er snittet det samme
-- uansett hvilke fire mandager motoren plukker, og testen kan ikke bli
-- flaky paa en grense i vinduet.
-- ---------------------------------------------------------------------
insert into public.daglig_salg (
  retailer_id, stasjon_id, dato, ean, varenavn,
  avdeling_kode, avdeling_navn, varegruppe_kode, varegruppe_navn,
  antall, omsetning_eks_mva, bto_fortjeneste_kr
)
select
  '11111111-1111-4111-8111-222222222222'::uuid,
  '44444444-4444-4444-8444-111111111111'::uuid,
  g.d::date, v.ean, v.varenavn,
  '120', 'MAT', v.vg_kode, v.vg_navn,
  v.antall, v.antall * 25, v.antall * 10
from (values
  ('7091000000011', 'Grovbaguette',     '1201', 'BAKEVARER', 20::numeric),
  ('7091000000012', 'Rundstykke grovt', '1201', 'BAKEVARER', 12::numeric),
  ('7091000000021', 'Polse i lompe',    '1216', 'VARMMAT',    8::numeric)
) as v(ean, varenavn, vg_kode, vg_navn, antall)
cross join generate_series(date '2026-01-05', date '2026-02-01', interval '1 day') as g(d)
on conflict (retailer_id, stasjon_id, dato, ean) do nothing;


-- ---------------------------------------------------------------------
-- TIMESALGET - doegnrytmen (bolge 2).
--
-- ALLE TRE STASJONENE, ikke bare en. Hadde bare Underby hatt tall,
-- ville sida vist Underby uansett hvilken stasjon toppstripen sto paa -
-- den filtrerer til stasjoner SOM HAR DATA. Det er den samme doble
-- konteksten trinn 09 lukket, i ny form: skallet sier 5102, sida regner
-- paa 5101. En fixture som bare dekker en stasjon ville skjult det.
--
-- Formen er en ekte doegnrytme: rolig morgen, lunsjtopp, ettermiddag,
-- stille kveld. Toppen ligger paa 11-12 hos alle tre, saa «travleste
-- time» er entydig baade per stasjon og for kjeden samlet.
--
--   5101 Underby   1000 + 3000 + 12000 + 6000 + 3000 = 25000
--   5102 Grenseby   600 + 1800 +  7200 + 3600 + 1800 = 15000
--   5103 Overby     400 + 1200 +  4800 + 2400 + 1200 = 10000
--                                              kjeden  50000
--
-- `inne_kunder`/`ute_kunder` er skilt fordi bemanningsplanleggeren
-- fordeler timer etter kunder INNE (mig 0081). Fixturen holder det
-- skillet ekte i stedet for aa fylle begge med samme tall.
-- ---------------------------------------------------------------------
insert into public.timesalg (
  retailer_id, stasjon_id, dato, time, salg, antall_kunder, inne_kunder, ute_kunder
)
select
  '11111111-1111-4111-8111-222222222222'::uuid, st.id, date '2026-03-17',
  t.time, t.andel * st.faktor, (t.kunder * st.faktor)::numeric,
  (t.inne * st.faktor)::numeric, (t.ute * st.faktor)::numeric
from (values
  ('44444444-4444-4444-8444-111111111111'::uuid, 1.0::numeric),
  ('44444444-4444-4444-8444-222222222222'::uuid, 0.6::numeric),
  ('44444444-4444-4444-8444-333333333333'::uuid, 0.4::numeric)
) as st(id, faktor)
cross join (values
  ('06-07',  1000::numeric,  30::numeric, 20::numeric, 10::numeric),
  ('07-08',  3000::numeric,  90::numeric, 60::numeric, 30::numeric),
  ('11-12', 12000::numeric, 260::numeric, 200::numeric, 60::numeric),
  ('15-16',  6000::numeric, 140::numeric, 100::numeric, 40::numeric),
  ('20-21',  3000::numeric,  60::numeric,  40::numeric, 20::numeric)
) as t(time, andel, kunder, inne, ute)
on conflict (retailer_id, stasjon_id, dato, time) do nothing;


-- ---------------------------------------------------------------------
-- KASSEREROPPGJORET - avvik per kasserer (bolge 2).
--
-- Sida regner avvik som andel av omsetningen og feller dom ved 2 %.
-- Fixturen treffer BEGGE SIDER av den grensa med vilje, saa baade
-- «i orden» og «se paa dette» kan maales:
--
--   5101 Underby   100 000 oms, 2 500 i avvik = 2,5 %   OVER grensa
--   5102 Grenseby   50 000 oms,     0 i avvik = 0,0 %   ren
--   5103 Overby     40 000 oms,   400 i avvik = 1,0 %   under grensa
--
-- Avviket er delt paa alle tre kildene (retur, makulert, slettet) hos
-- den ene som har det - en kasserer med bare returer og en med alle tre
-- er ulike historier, og sida summerer dem.
--
-- MERK at retningen og dommen peker hver sin vei her, som paa svinn:
-- mer avvik er verre. Testen sjekker det eksplisitt.
-- ---------------------------------------------------------------------
insert into public.kassererstatistikk (
  retailer_id, stasjon_id, dato, kasserer_nr, kasserer_navn,
  omsetning_ink_mva, bonger,
  retur_antall, retur_belop, makulerte_antall, makulerte_belop,
  slettede_antall, slettede_belop
)
values
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '101', 'Kari Kasserer', 60000, 600, 3, 1200, 2, 800, 1, 500),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '102', 'Ola Kasserer',  30000, 300, 0, 0, 0, 0, 0, 0),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '103', 'Nina Kasserer', 10000, 100, 0, 0, 0, 0, 0, 0),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-222222222222',
   date '2026-03-17', '201', 'Per Kasserer',  50000, 500, 0, 0, 0, 0, 0, 0),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-333333333333',
   date '2026-03-17', '301', 'Siri Kasserer', 40000, 400, 1, 400, 0, 0, 0, 0),
  -- KASSA SELV. 999999 er ikke en medarbeider, og sonden mot produksjon
  -- 2026-08-24 viste at den baerer 18-35 % av ALLE bonger. Uten en slik
  -- rad i fixturen finnes «Kassa selv»-tabellen bare i koden, og en
  -- seksjon ingen test ser er en seksjon som kan forsvinne i stillhet.
  --
  -- 500 av 1500 bonger paa Underby = 33 %, midt i det produksjon viser.
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '999999', null, 150000, 500, 0, 0, 0, 0, 0, 0),

  -- EN MAANED FOER, saa «mot eget snitt» har noe aa maale mot.
  --
  -- Uten februar sto hver kasserer med «ingen historikk», og selve
  -- kjernen i sida - at en kasserer maales mot SEG SELV og ikke mot
  -- kollegaene - hadde null dekning i nettleseren. Da er det bare en
  -- paastand i en kommentar.
  --
  -- Kari, februar:  600 avvik / 600 bonger * 100 =  100 kr per 100
  -- Kari, mars:   2 500 avvik / 600 bonger * 100 =  417 kr per 100
  -- mot eget snitt                                = +317
  --
  -- Og stasjonen samlet: 60 i februar mot 250 i mars. Pila peker opp,
  -- og opp er daarlig her - samme skille mellom retning og dom som paa
  -- /salg og /svinn.
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-02-17', '101', 'Kari Kasserer', 60000, 600, 0, 0, 1, 400, 1, 200),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-02-17', '102', 'Ola Kasserer',  30000, 300, 0, 0, 0, 0, 0, 0),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-02-17', '103', 'Nina Kasserer', 10000, 100, 0, 0, 0, 0, 0, 0)
on conflict (retailer_id, stasjon_id, dato, kasserer_nr) do nothing;


-- ---------------------------------------------------------------------
-- HISTORIKKEN - fire like tirsdager, og hvorfor det er akkurat fire.
--
-- `motNormalen` krever MIN_GRUNNLAG = 4 dager med samme ukedag for den
-- sier noe i det hele tatt (src/lib/salg/normalen.ts). Sida henter 56
-- dager bakover, og disse fire er de eneste tirsdagene der som har
-- svinn:
--
--   2026-01-20, 2026-01-27, 2026-02-03, 2026-02-10
--
-- ALLE FIRE LIGGER UTENFOR 30-DAGERSVINDUET (som starter 2026-02-16).
-- Det er med vilje: historikken skal styre normalen UTEN aa flytte
-- terskelprosentene over.
--
-- Hver tirsdag har kjedesum 1000 + 1400 + 2000 = 4400. Medianen av fire
-- like tall er 4400, og maaledagen er 8800:
--
--   (8800 - 4400) / 4400 = +100,0 % mot en vanlig tirsdag
--
-- Det er langt over verdtEtBlikk sin grense paa 10 %, saa dommen SKAL
-- felles - og paa svinn er opp daarlig. Det er nettopp dette som gjor at
-- «pil opp» og «roed dom» kan testes hver for seg.
-- ---------------------------------------------------------------------
insert into public.synlig_svinn (
  retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total
)
select
  '11111111-1111-4111-8111-222222222222'::uuid, s.stasjon_id, d.dato,
  s.ean, 'Historisk svinn', 10::numeric, s.belop
from (values
  ('44444444-4444-4444-8444-111111111111'::uuid, '7090000000091', 1000::numeric),
  ('44444444-4444-4444-8444-222222222222'::uuid, '7090000000092', 1400::numeric),
  ('44444444-4444-4444-8444-333333333333'::uuid, '7090000000093', 2000::numeric)
) as s(stasjon_id, ean, belop)
cross join (values
  (date '2026-01-20'), (date '2026-01-27'), (date '2026-02-03'), (date '2026-02-10')
) as d(dato)
where not exists (
  select 1 from public.synlig_svinn
  where retailer_id = '11111111-1111-4111-8111-222222222222'
    and dato < date '2026-02-16'
);


-- =====================================================================
-- SIGNALER PAA FORSIDEN (bolge 4B.2).
--
-- HVORFOR DETTE MAA SEEDES: /oversikt er den eneste sida der innholdet
-- ER rangeringen. Uten funn moeter testene «Ingenting trenger
-- oppmerksomhet» - en gyldig og viktig tilstand, men den beviser
-- ingenting om rekkefolgen. Og rekkefolgen er hele produktet her.
--
-- ALLE RADENE GAAR GJENNOM DEN EKSISTERENDE MOTOREN. Ingen terskel er
-- rort, ingen `niva` er skrevet inn i basen - nivaaet regnes av
-- signaler.ts, og poengsummen av `poengFor`. Regnestykket, med tallene
-- fra GRUNNPOENG + min(200, dager*25):
--
--   Melding om krenkelse    kritisk  1000 + 0   = 1000
--   1 oppgave over frist    folg      300 + 200 =  500
--   Bemanningen er innenfor info       50 + 0   =   50
--
-- Rekkefolgen er derfor gitt av motoren, ikke av innsettingsrekkefolgen
-- her - og et bevis paa forsiden kan sammenligne mot den.
--
-- TESTKJEDEN ROERES IKKE. Den er tom med vilje (se over): sju ruter
-- testes i tom tilstand, og butikksjefen der er ogsaa den eneste som
-- kan bevise at «ingenting trenger oppmerksomhet» faktisk vises.
-- =====================================================================

-- Krenkelse: den ene tingen som alltid skal staa forst. Butikksjefen ser
-- den som «Melding om krenkelse», eieren som stasjonens navn.
insert into public.tilbakemelding (id, retailer_id, stasjon_id, alvorlighet, tekst, opprettet_tid)
values
  ('55555555-5555-4555-8555-000000000001', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'krenkelse',
   'En ansatt melder fra om grov oppforsel fra en kunde ved nattskiftet.',
   '2026-03-01T22:10:00Z'),
  -- Ulest, men ikke alvorlig. Gir eieren info-nivaaet; hos butikksjefen
  -- undertrykkes den med vilje naar det finnes en krenkelse (se
  -- byggSignaler) - to meldinger om det samme innboksen ville dyttet
  -- krenkelsen nedover.
  ('55555555-5555-4555-8555-000000000002', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-222222222222', 'generelt',
   'Kaffemaskinen paa selvbetjeningen lekker litt naar den er full.',
   '2026-03-02T09:00:00Z')
on conflict (id) do nothing;

-- Oppgave over frist -> folg-nivaa, og `dager` gir den poeng over en
-- naken folg. Fristen er fast og i fortiden, saa dagtallet vokser med
-- kalenderen men treffer taket paa 200 poeng uansett.
insert into public.oppgaver (id, retailer_id, stasjon_id, tittel, beskrivelse, status, frist)
values
  ('55555555-5555-4555-8555-000000000004', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111',
   'Bytte pakning paa kaffemaskinen', 'Meldt inn fra nettbrettet.', 'apen', '2026-03-10')
on conflict (id) do nothing;

-- To varsler paa info-nivaa. Det ene er SKJULT under, og det er hele
-- poenget med aa ha to: uten et synlig soesken kan et bevis ikke skille
-- «skjulingen virker» fra «varsler vises ikke i det hele tatt».
insert into public.varsler (id, retailer_id, stasjon_id, type, tittel, tekst, lenke, opprettet_tid)
values
  ('55555555-5555-4555-8555-000000000005', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'bemanning_ok',
   'Bemanningen er innenfor rammen',
   'Neste ukes plan bruker 96 % av timerammen.', '/bemanning', '2026-03-03T06:00:00Z'),
  ('55555555-5555-4555-8555-000000000006', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'bemanning_ok',
   'Skjult varsel som ikke skal vises',
   'Lukket i signal_lukket under, og skal derfor ikke staa i lista.',
   '/bemanning', '2026-03-03T06:05:00Z')
on conflict (id) do nothing;

-- Skjulingen. `filtrerLukkede` fjerner funn som er lukket og fortsatt
-- innenfor fristen; datoen her er satt langt fram slik at beviset ikke
-- gaar ut av seg selv en dag i framtiden.
insert into public.signal_lukket (id, retailer_id, stasjon_id, signal_id, gjelder_til, notat)
values
  ('55555555-5555-4555-8555-000000000007', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111',
   'varsel-55555555-5555-4555-8555-000000000006', '2099-12-31',
   'Fixtur: beviser at skjulte funn holder seg skjult.')
on conflict (id) do nothing;


-- =====================================================================
-- UKA SOM GJOR PORTEFOLJEBILDET EKTE (bolge 4B.2).
--
-- Uten en komplett uke returnerer `hentEllerLagUkerapport` tom liste,
-- og da faller BAADE pulsen og «Stasjonene mot hverandre» bort. Eierens
-- halvdel av forsiden - hele «hvor i portefoljen skal blikket» - var
-- dermed utestet.
--
-- UKA VELGES AV DATAENE, IKKE AV KLOKKA. Motoren tar siste dato i
-- `v_butikksalg` og gaar til naermeste soendag paa/for den. Derfor kan
-- en fast fixture treffe: 2026-03-22 ER en soendag, og den er den siste
-- datoen i basen.
--
--   uke naa    2026-03-16 .. 2026-03-22   (mandag .. soendag)
--   uke ifjor  2025-03-17 .. 2025-03-23   (mandag - 364 dager)
--
-- 2026-03-17 ligger ALLEREDE i uka med 100 000 per stasjon (maaledagen
-- for svinn). Radene under er derfor DIFFERANSER opp til uketotalen, og
-- svinnvinduet 2026-02-16..2026-03-17 roeres ikke:
--
--              ifjor      naa               vekst
--   Underby   200 000    160 000  (100+60)  -20,0 %
--   Grenseby  120 000    120 000  (100+20)    0,0 %
--   Overby    100 000    100 000  (100+ 0)    0,0 %
--
-- HVA MOTOREN GJOR MED DET, uten at en eneste terskel er rort:
--
--   Underby maalt mot DE ANDRE (0,0 %) gir -20 pp, over grensa paa 12,
--   og en residual paa 40 000 kr - over 15 000, under 60 000. Altsaa
--   ETT stasjonssignal paa `folg`. De to andre havner over sin egen
--   maalestokk og staar som «Foran de andre».
--
--   Klyngen faller 9,5 %, men «Alle stasjonene faller» krever at ALLE
--   har negativ vekst. To av tre ligger flatt, saa det signalet uteblir
--   - med vilje: markedssignalet og stasjonssignalet skal kunne testes
--   hver for seg.
--
--   Alt salget ligger paa EN avdeling, saa avdelingens vekst er lik
--   butikkens. `avdelingsSignaler` krever 25 prosentpoengs avvik fra
--   butikken, og faar 0. Butikksjefens saksliste er derfor uendret av
--   denne blokka - beviset paa rekkefolgen hennes staar.
-- =====================================================================
insert into public.daglig_salg (
  retailer_id, stasjon_id, dato, ean, varenavn,
  avdeling_kode, avdeling_navn, antall, omsetning_eks_mva, bto_fortjeneste_kr
)
values
  -- Uka i aar: differansen opp til uketotalen.
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-22', '7090000000120', 'Matsalg samlet', '120', 'MAT', 600, 60000, 21000),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-222222222222',
   date '2026-03-22', '7090000000120', 'Matsalg samlet', '120', 'MAT', 200, 20000, 7000),
  -- Samme uke i fjor, hele beloepet paa en dag.
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2025-03-23', '7090000000120', 'Matsalg samlet', '120', 'MAT', 2000, 200000, 70000),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-222222222222',
   date '2025-03-23', '7090000000120', 'Matsalg samlet', '120', 'MAT', 1200, 120000, 42000),
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-333333333333',
   date '2025-03-23', '7090000000120', 'Matsalg samlet', '120', 'MAT', 1000, 100000, 35000)
on conflict (retailer_id, stasjon_id, dato, ean) do nothing;


-- =====================================================================
-- NETTBRETTET MED DATA (bolge 5).
--
-- HVORFOR ET TIL. `nettbrett@test.sentiqa.no` staar i Testkjeden, som er
-- tom med vilje - den beviser tomtilstanden, og det skal den fortsette
-- med. Men da kan den ikke bevise en ARBEIDSFLYT: en koe uten oppgaver
-- er ikke en koe.
--
-- Denne staar i Analysekjeden, paa 5101 Underby, og har IK-mat-punkter
-- aa maale. Samme skille som mellom butikksjef@ og analyse@, og av samme
-- grunn: begge produkttilstandene skal vaere ekte samtidig.
--
-- Rollen `butikkbruker_tablet` er unntatt to-faktor (delt PIN-enhet,
-- mfa.ts), saa den logger inn med passord som de ovrige.
-- =====================================================================
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-666666666666',
   'authenticated', 'authenticated',
   'nettbrett-analyse@test.sentiqa.no', crypt('test-nettbrett-analyse-2026', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
   '', '', '', '', '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(), '33333333-3333-4333-8333-666666666666',
   '{"sub":"33333333-3333-4333-8333-666666666666","email":"nettbrett-analyse@test.sentiqa.no"}'::jsonb,
   'email', '33333333-3333-4333-8333-666666666666', now(), now(), now())
on conflict (provider, provider_id) do nothing;

insert into public.profiler (id, retailer_id, rolle, fullt_navn)
values
  ('33333333-3333-4333-8333-666666666666', '11111111-1111-4111-8111-222222222222',
   'butikkbruker_tablet', 'Nettbrett Underby')
on conflict (id) do nothing;

-- Ett nettbrett staar i EN butikk. Det er hele premisset for flata.
insert into public.butikksjef_stasjoner (profil_id, stasjon_id)
values
  ('33333333-3333-4333-8333-666666666666', '44444444-4444-4444-8444-111111111111')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- IK-MAT-PUNKTENE hun skal maale.
--
-- TO FREKVENSER MED VILJE. Nettbrettets IK-mat-side er en koe med en rad
-- per gruppe, og med bare en gruppe kunne et bevis ikke skille «riktig
-- gruppert» fra «alt i en haug».
--
--   daglig     3 punkter
--   ukentlig   2 punkter
--
-- Ingen avlesninger seedes. Koen skal starte full - det er tilstanden
-- hun moeter naar hun kommer paa vakt, og den arbeidsflyten et bevis
-- skal kunne gaa gjennom fra start.
-- ---------------------------------------------------------------------
insert into public.ik_kontrollpunkter (id, retailer_id, stasjon_id, navn, type, min_temp, max_temp, frekvens, sortering)
values
  ('66666666-6666-4666-8666-000000000001', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Kjoledisk pakkemat', 'kjol', null, 4, 'daglig', 1),
  ('66666666-6666-4666-8666-000000000002', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Fryser bakeri', 'frys', null, -18, 'daglig', 2),
  ('66666666-6666-4666-8666-000000000003', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Varmedisk polser', 'varmholding', 60, null, 'daglig', 3),
  ('66666666-6666-4666-8666-000000000004', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Oppvaskmaskin skyllevann', 'skyllevann', 82, null, 'ukentlig', 4),
  ('66666666-6666-4666-8666-000000000005', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Kjolerom drikke', 'kjol', null, 7, 'ukentlig', 5)
on conflict (id) do nothing;
-- ---------------------------------------------------------------------
-- SJEKKPUNKTENE hun skal svare paa.
--
-- Koen paa «I dag» legger sjekkpunktene oeverst, kritisk foerst, og
-- lenker til /sjekkpunkt. Uten data her er den raden aldri der, og
-- beviset for at koens hoyest prioriterte rad foerer til en flate hun
-- kan svare paa, ville kjort paa tomtilstanden i stedet. En test som
-- ikke kan feile er ikke et bevis - den er en paastand med gronn hake.
--
-- DET KRITISKE HAR DET SENESTE KLOKKESLETTET, og det er hele poenget.
-- Rekkefolgen er kritisk foerst, DERETTER klokkeslett. Ga det kritiske
-- punktet ogsaa foerst i tid, ville en sortering som ignorerte
-- kritikalitet gitt samme svar - og beviset kunne ikke merke forskjell.
--
-- Begge tidspunktene er tidlig paa dagen: koen viser bare punkter der
-- tidspunktet har passert, og et sjekkpunkt satt til 22:00 ville vaert
-- usynlig i en kjoring som starter om morgenen.
-- ---------------------------------------------------------------------
insert into public.sjekkpunkter (id, retailer_id, stasjon_id, sporsmaal, klokkeslett, kritisk)
values
  ('77777777-7777-4777-8777-000000000001', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Er kassen talt opp?', '06:00', false),
  ('77777777-7777-4777-8777-000000000002', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Er kjolerommet laast?', '06:30', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- ANSATTE, for identitetskontrakten.
--
--   ansatt_nr      utpeker personen
--   PIN            beviser at det er riktig person
--   sentiqa_vakt   husker resultatet, og er aldri selv bevis
--
-- Hashen er sha256('<retailer_id>:<pin>') — samme salt for hele kjeden,
-- fordi PIN-en fram til korrekthetstrinnet var et databaseoppslag. Den
-- bindingen er borte naa, og hashen kan bli en ekte passordhash i et
-- eget trinn.
--
-- FEM RADER, HVER MED EN JOBB. En seed som bare hadde «en ansatt» kunne
-- ikke skille «riktig person» fra «noen person», og det er hele skillet
-- korrekthetstrinnet handler om.
--
--   1001 / 1234   Ada     — den normale veien inn
--   1002 / 5678   Bo      — beviser at As nummer + Bs PIN avvises
--   (uten nr)     Kim     — har PIN, men ikke nummer: kan ikke starte vakt
--   1003 / 1111   Dag     — deaktivert: en kapsel med hans ID er ikke vakt
--   2001 / 4321   Eir     — ANNEN KJEDE: en kapsel med hennes ID skal
--                           avvises selv om raden finnes og er aktiv
--
-- Merk at Dag har bade `aktiv = false` og `slettet_tid`. Den unike
-- PIN-indeksen er delvis (`where aktiv and slettet_tid is null`), saa en
-- deaktivert rad frigjor PIN-en sin - og innsjekken filtrerer paa begge.
-- ---------------------------------------------------------------------
insert into public.ansatte (id, retailer_id, stasjon_id, navn, pin_hash, ansatt_nr, aktiv, slettet_tid)
values
  ('88888888-8888-4888-8888-000000000001', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Ada Testad',
   '21b058637a2d60b80b7b34b773dc2abd820fe0a72998b859e4014a1e17d4e8bf', '1001', true, null),
  ('88888888-8888-4888-8888-000000000002', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Bo Testad',
   'b5f6c9aafa1ec6fb02eb962a05db28186d123e865b2c40cec38ff1a994249f60', '1002', true, null),
  ('88888888-8888-4888-8888-000000000003', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Kim Utennummer',
   '3a4093504ec215255bced4e5aa0f1bd576254d45ffea239f44e980a67e1dd548', null, true, null),
  ('88888888-8888-4888-8888-000000000004', '11111111-1111-4111-8111-222222222222',
   '44444444-4444-4444-8444-111111111111', 'Dag Deaktivert',
   '5e705061bb2f0dcef6311a172079c287e5f1147aa1e97048c0b7947b222fe3cf', '1003', false, '2026-01-01T00:00:00Z'),
  ('88888888-8888-4888-8888-000000000005', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'Eir Annenkjede',
   '5755e52d07e8445add373b1b16ec561e6ffb61787eff3c57f9926fb04d216ae9', '2001', true, null)
on conflict (id) do nothing;



-- ---------------------------------------------------------------------
-- KOST MOT KOST - fixturen som beviser den nye svinnprosenten.
--
-- INGEN AV DE SEKS SVINN-EAN-ENE OVER FINNES I `daglig_salg`. Det er
-- riktig for det de maaler - alt blir «ikke koblet», og prosenten skal
-- da staa som «ikke maalbart» - men det gjoer at selve regnestykket,
-- svinn til kostpris delt paa varekost av solgte varer, ikke kunne
-- bevises av noen test.
--
-- Her er én vare som finnes BEGGE steder, paa Underby 5101:
--
--   salg    omsetning 500 000 - brutto 300 000 = varekost 200 000
--   svinn    10 000 kr
--   svinn%   10 000 / 200 000 = 5,0 %  for varegruppe 1290
--
-- Underby samlet i mars blir da 2 000 (ikke koblet) + 10 000 = 12 000 kr
-- mot 200 000 i varekost = 6,0 %, og 83 % kategorisert.
--
-- 2026-03-17 MED VILJE. Det er den samme maaledagen som resten av
-- analysefixturen, saa /svinn-testen ikke raatner en maaned tidligere
-- enn de andre naar det rullende 13-maaneders-vinduet flytter seg.
--
-- VAREGRUPPE 1290 BRUKES IKKE ANDRE STEDER. 1201 og 1216 hoerer til
-- bemanningsfixturen i januar; laa denne i en av dem, ville to fixturer
-- dratt i hverandre.
--
-- Alle andre mars-rader i `daglig_salg` har `varegruppe_kode = null` og
-- teller derfor ikke i nevneren. Endres det, skal disse tallene feile.
-- ---------------------------------------------------------------------
insert into public.daglig_salg (
  retailer_id, stasjon_id, dato, ean, varenavn,
  avdeling_kode, avdeling_navn, varegruppe_kode, varegruppe_navn,
  antall, omsetning_eks_mva, bto_fortjeneste_kr
)
values
  ('11111111-1111-4111-8111-222222222222', '44444444-4444-4444-8444-111111111111',
   date '2026-03-17', '7090000000131', 'Grovbrod halv',
   '120', 'MAT', '1290', 'FERSKVARER', 2000, 500000, 300000)
on conflict (retailer_id, stasjon_id, dato, ean) do nothing;

insert into public.synlig_svinn (
  retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total
)
select v.* from (values
  ('11111111-1111-4111-8111-222222222222'::uuid,
   '44444444-4444-4444-8444-111111111111'::uuid,
   date '2026-03-17', '7090000000131', 'Grovbrod halv', 40::numeric, 10000::numeric)
) as v(retailer_id, stasjon_id, dato, ean, varenavn, antall, nettopris_total)
where not exists (
  select 1 from public.synlig_svinn s
  where s.ean = '7090000000131' and s.dato = date '2026-03-17'
);


-- =====================================================================
-- OPPLAERING SOM NAAR NETTBRETTET
--
-- Skift-kalenderen er utloeseren: nettbrettet spoer ikke «finnes det
-- opplaering?», men «finnes det et skift i dag, paa min stasjon, i en
-- periode som ikke er fullfoert?».
--
-- DERFOR `current_date`, IKKE EN FAST DATO. En fixture med 2026-08-29
-- ville vaert usynlig alle andre dager enn den ene, og testen ville
-- bestaatt fordi den ikke fant noe - ikke fordi det ikke var noe galt.
-- Det er den samme feilen som en vakt som slutter aa se.
--
-- Testkjeden, Testby (4177), som `nettbrett@test.sentiqa.no` staar paa.
-- =====================================================================
insert into public.opplaering_oppgave
  (id, retailer_id, tittel, kategori, rekkefolge)
values
  ('0bbb0000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   'Kassaoppgjoer',      'Kasse', 1),
  ('0bbb0000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   'Aldersgrense tobakk', 'Kasse', 2),
  ('0bbb0000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111',
   'Steke boller',        'Bake',  3)
on conflict (id) do nothing;

insert into public.opplaering_periode
  (id, retailer_id, stasjon_id, ansatt_navn, start_dato)
values
  ('0ccc0000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'Nora Nyansatt', current_date)
on conflict (id) do nothing;

-- 16-23 med vilje: det er tidsrommet Robert beskrev. Tidene VISES paa
-- nettbrettet, men de skjuler ikke lista - man haker av etter at noe er
-- laert bort, og en liste som forsvinner 23:00 forsvinner midt i jobben.
insert into public.opplaering_skift
  (id, periode_id, dato, start_tid, slutt_tid)
values
  ('0ddd0000-0000-4000-8000-000000000001',
   '0ccc0000-0000-4000-8000-000000000001', current_date, '16:00', '23:00')
on conflict (id) do nothing;

-- ÉN OPPGAVE ER ALT GJORT, saa testen kan skille de to tilstandene fra
-- hverandre. Er alt ugjort, ville en visning som aldri merker noe som
-- ferdig bestaatt like godt.
insert into public.opplaering_utfort (periode_id, oppgave_id)
select '0ccc0000-0000-4000-8000-000000000001'::uuid,
       '0bbb0000-0000-4000-8000-000000000003'::uuid
where not exists (
  select 1 from public.opplaering_utfort
  where periode_id = '0ccc0000-0000-4000-8000-000000000001'
    and oppgave_id = '0bbb0000-0000-4000-8000-000000000003'
);
