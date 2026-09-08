-- ---------------------------------------------------------------------
-- 0190: selvbetjent registrering, men med port
-- ---------------------------------------------------------------------
-- `/registrer` var aapen selvbetjening. En hvem som helst kunne
-- opprette en ny kjede med seg selv som `retailer_admin`, uten
-- e-postbekreftelse, uten godkjenning, uten grense.
--
-- Isolasjonen holdt - RLS gir dem bare sin egen tomme kjede, og MFA er
-- paatvunget - saa dette var aldri en lekkasje. Det var fire aapninger:
--
--   1. E-posten ble ALDRI verifisert. `createUser({email_confirm: true})`
--      markerer adressen som bekreftet uten aa sende noe. Man kunne
--      registrere seg paa en adresse man ikke eier - og da gaar «glemt
--      passord» til den ekte eieren, med en lenke inn i en konto de
--      aldri opprettet. Den skarpeste av de fire.
--   2. Hver registrering provisjonerte `<slug>@sentiqa.ai`.
--   3. `org_nr` var ni siffer og ikke noe mer. Ingen unikhet, saa
--      «St1 Norge AS» kunne registreres av hvem som helst, flere ganger.
--   4. Ingen godkjenning. Kjeden var live i det sekundet skjemaet gikk.
--
-- Denne migrasjonen tar 3 og 4. E-postbekreftelsen (1) og grensen (2)
-- ligger i koden - se `app/registrer/handlinger.ts`.

-- ---------------------------------------------------------------------
-- 1) GODKJENNING
-- ---------------------------------------------------------------------
-- null = venter. Kjeden finnes, eieren kan logge inn, men naar ingenting
-- annet enn en side som sier at det ventes.
--
-- HVORFOR IKKE BARE NEKTE INNLOGGING: da ville en soeker ikke kunne
-- fullfoere e-postbekreftelsen sin, og vi ville ikke visst om adressen
-- var ekte. Bekreftelsen skjer FOER godkjenningen, og det er riktig
-- rekkefoelge: vi godkjenner en verifisert e-post, ikke en paastand.
alter table public.retailers
  add column if not exists godkjent_tid timestamptz;
alter table public.retailers
  add column if not exists godkjent_av uuid references public.profiler(id);

comment on column public.retailers.godkjent_tid is
  'null = venter paa godkjenning i /plattform. Kjeden naar ingenting foer den er satt.';

-- De som alt finnes er godkjent. Datoen er fast, ikke `now()`, saa en
-- ny kjoering av migrasjonen ikke stempler en som venter naa.
update public.retailers
   set godkjent_tid = opprettet_tid
 where godkjent_tid is null
   and opprettet_tid < timestamptz '2026-09-08 00:00:00+02';

-- ---------------------------------------------------------------------
-- 2) ORGANISASJONSNUMMERET SKAL VAERE ETT SELSKAP
-- ---------------------------------------------------------------------
-- Delvis indeks: en slettet kjede skal ikke sperre for at selskapet
-- kommer tilbake. `if not exists` gjor den re-kjoerbar - og finnes det
-- alt duplikater, feiler den hoeyt, hvilket er riktig svar.
create unique index if not exists retailers_org_nr_unik
  on public.retailers (org_nr)
  where slettet_tid is null and org_nr is not null;

-- ---------------------------------------------------------------------
-- 3) GRENSE PAA REGISTRERINGSFORSOEK
-- ---------------------------------------------------------------------
-- Registreringen gaar gjennom service_role og forbi Supabase sine egne
-- auth-grenser. Uten en teller kan noen lage ubegrenset antall kjeder,
-- og hver av dem tar en `@sentiqa.ai`-adresse.
--
-- INGEN RAA IP, INGEN RAA E-POST. Begge hashes med en hemmelighet foer
-- de lagres. Tabellen skal kunne svare «har denne kilden proevd fem
-- ganger den siste timen», ikke «hvem proevde». En liste over hvilke
-- adresser folk har proevd aa registrere er personopplysninger vi ikke
-- trenger.
create table if not exists public.registrering_forsok (
  id         uuid primary key default gen_random_uuid(),
  kilde_hash text not null,
  tid        timestamptz not null default now()
);

create index if not exists registrering_forsok_kilde_idx
  on public.registrering_forsok (kilde_hash, tid desc);

comment on table public.registrering_forsok is
  'Teller for grensen paa /registrer. Hashet kilde, ingen identitet. Ingen policy med vilje.';

-- ---------------------------------------------------------------------
-- LAAST, IKKE BARE UPOLICYET
-- ---------------------------------------------------------------------
-- Tabellen har ingen `retailer_id` - den skrives FOER en tenant finnes -
-- saa tenantmodellen passer ikke paa den. Da er svaret aa stenge den
-- helt: RLS paa, ingen policy, ingen grants. Bare service_role naar den,
-- og det er registreringshandlingen som trenger.
--
-- Samme form som `oversettelse_cache`, og den laa usett i to aar nettopp
-- fordi «trygg» og «sett» er to forskjellige ting. Derfor foeres den inn
-- i `kalde` i vakthunden og i tenant-kontrakten med `ingen_policy` i
-- samme slengen.
alter table public.registrering_forsok enable row level security;
revoke all on public.registrering_forsok from anon, authenticated;

-- ---------------------------------------------------------------------
-- Kvittering
-- ---------------------------------------------------------------------
select
  (select count(*) from public.retailers where godkjent_tid is not null) as godkjente,
  (select count(*) from public.retailers where godkjent_tid is null)     as venter,
  (select count(*) from pg_indexes
    where indexname = 'retailers_org_nr_unik')                           as orgnr_indeks,
  (select count(*) from pg_policies
    where tablename = 'registrering_forsok')                             as forsok_policyer,
  (select count(*) from information_schema.role_table_grants
    where table_name = 'registrering_forsok'
      and grantee in ('anon', 'authenticated'))                          as forsok_grants;
