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

insert into public.butikksjef_stasjoner (profil_id, stasjon_id)
values
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-111111111111'),
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-222222222222'),
  ('33333333-3333-4333-8333-333333333333', '44444444-4444-4444-8444-333333333333')
on conflict do nothing;


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
   date '2026-03-17', '301', 'Siri Kasserer', 40000, 400, 1, 400, 0, 0, 0, 0)
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
