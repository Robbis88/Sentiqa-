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
