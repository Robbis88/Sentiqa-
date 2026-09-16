-- =====================================================================
-- SIKKERHETSMATRISE FOR `a1_registeroppslag` (0221)
--
-- Kjoerer i EN transaksjon og ruller tilbake. Ingenting blir liggende.
-- Trygg i produksjon - men tenantisolasjonen bevises mot en FIXTURE,
-- aldri ved aa forsoeke aa lese en ekte annen kunde.
--
-- ---------------------------------------------------------------------
-- HVA DEN MAA BEVISE
--
-- Funksjonen er `security definer` og gaar forbi RLS. Da er den ikke en
-- bekvemmelighet, den er en sikkerhetsgrense rundt loennsdata, og den
-- skal bevises som en.
--
--   N1  en registerrad for en som IKKE arbeidet her returneres ikke
--   N2  ingen enumerering: Lones register kan ikke listes
--   N3  samme ansattnummer i en annen kjede gir null lekkasje
--   N4  uautorisert stasjon gir 42501, ikke []
--   N5  blandet liste feiler HELT - ingen delvis suksess
--   P1  noedvendig kryssarbeid virker (Carmen)
--   P2  retailer_admin i egen kjede far det legitime
--   P3  to kandidater paa samme nummer kommer ut som TO rader
--   R1  nettbrettet avvises ogsaa paa sin EGEN stasjon
--   R2  plattform_redaktor avvises
--   R3  anon har ikke execute
--   V1  ugyldig maaned -> 22023
--   V2  null/tom stasjonsliste -> 22023
--   V3  [A, A] gir samme svar som [A]
--
-- EN POSITIV KONTROLL MAA LYKKES FOER DE NEGATIVE ER GYLDIGE. Lykkes
-- ingen tillatt operasjon, vet vi ikke om fixturen i det hele tatt ble
-- seedet - og da beviser ingen avvisning noe.
--
-- ---------------------------------------------------------------------
-- FIXTUREN
--
--   Kjede A   A-Boenes, A-Lone
--   Kjede B   B-Sentrum
--
--   sjef-A    butikksjef, tildelt BARE A-Boenes
--   admin-A   retailer_admin i A
--   tablet-A  butikkbruker_tablet, tildelt A-Boenes
--   redaktor  plattform_redaktor, ingen kjede
--   admin-B   retailer_admin i B
--
--   basisvakt 2026-08
--     A-Boenes   1104265 Carmen, 1009 Ola
--     A-Lone     118 Sandra
--     B-Sentrum  1104265 Annen Person     <- samme nummer, annen kjede
--
--   lonnsregister 2026-08
--     A-Lone     1104265 Carmen   138
--     A-Lone     118     Sandra 48736
--     A-Lone     9001    Kari     200    <- arbeidet ALDRI paa Boenes
--     A-Lone     1009    Ola L    195    <- kollisjonspartner for P3
--     A-Boenes   1009    Ola B    210
--     B-Sentrum  1104265 Annen    999
-- =====================================================================

begin;

-- --------------------------------------------------------------- SEED
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin-a@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'sjef-a@test.local'),
  ('00000000-0000-0000-0000-0000000000a3', 'tablet-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'admin-b@test.local'),
  ('00000000-0000-0000-0000-0000000000ed', 'redaktor@test.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('11111111-1111-1111-1111-111111111111', 'A1-test kjede A'),
  ('22222222-2222-2222-2222-222222222222', 'A1-test kjede B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111', 'retailer_admin',      'Admin A'),
  ('00000000-0000-0000-0000-0000000000a2', '11111111-1111-1111-1111-111111111111', 'butikksjef',          'Sjef A'),
  ('00000000-0000-0000-0000-0000000000a3', '11111111-1111-1111-1111-111111111111', 'butikkbruker_tablet', 'Nettbrett A'),
  ('00000000-0000-0000-0000-0000000000b1', '22222222-2222-2222-2222-222222222222', 'retailer_admin',      'Admin B'),
  ('00000000-0000-0000-0000-0000000000ed', null,                                   'plattform_redaktor',  'Redaktor');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('aaaaaaaa-0000-0000-0000-00000000b001', '11111111-1111-1111-1111-111111111111', '9001', 'A-Boenes',  'pendler'),
  ('aaaaaaaa-0000-0000-0000-00000000e001', '11111111-1111-1111-1111-111111111111', '9002', 'A-Lone',    'utfart'),
  ('bbbbbbbb-0000-0000-0000-00000000c001', '22222222-2222-2222-2222-222222222222', '9001', 'B-Sentrum', 'sentrum');

-- Sjefen og nettbrettet er tildelt BARE A-Boenes. Ikke A-Lone.
insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('00000000-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-00000000b001'),
  ('00000000-0000-0000-0000-0000000000a3', 'aaaaaaaa-0000-0000-0000-00000000b001');

insert into public.basisvakt
  (stasjon_id, kilde_maaned, ansatt_nr, ansatt_navn, dato, fra_dato,
   fra_tid, til_tid, minutter, type, betalt, lokasjon) values
  ('aaaaaaaa-0000-0000-0000-00000000b001', '2026-08', '1104265', 'Carmen Toro',
   '2026-08-03', '2026-08-03', '07:00', '15:00', 480, 'Betalt tid', true, 'A-Boenes'),
  ('aaaaaaaa-0000-0000-0000-00000000b001', '2026-08', '1009', 'Ola Nordmann',
   '2026-08-04', '2026-08-04', '07:00', '15:00', 480, 'Betalt tid', true, 'A-Boenes'),
  ('aaaaaaaa-0000-0000-0000-00000000e001', '2026-08', '118', 'Sandra',
   '2026-08-05', '2026-08-05', '07:00', '15:00', 480, 'Betalt tid', true, 'A-Lone'),
  ('bbbbbbbb-0000-0000-0000-00000000c001', '2026-08', '1104265', 'Annen Person',
   '2026-08-06', '2026-08-06', '07:00', '15:00', 480, 'Betalt tid', true, 'B-Sentrum');

insert into public.lonnsregister
  (stasjon_id, kilde_maaned, ansatt_nr, navn, timesats, betalingsfrekvens) values
  ('aaaaaaaa-0000-0000-0000-00000000e001', '2026-08', '1104265', 'Carmen Toro',   138, 'time'),
  ('aaaaaaaa-0000-0000-0000-00000000e001', '2026-08', '118',     'Sandra',      48736, 'maaned'),
  ('aaaaaaaa-0000-0000-0000-00000000e001', '2026-08', '9001',    'Kari Aldri',    200, 'time'),
  ('aaaaaaaa-0000-0000-0000-00000000e001', '2026-08', '1009',    'Ola L',         195, 'time'),
  ('aaaaaaaa-0000-0000-0000-00000000b001', '2026-08', '1009',    'Ola B',         210, 'time'),
  ('bbbbbbbb-0000-0000-0000-00000000c001', '2026-08', '1104265', 'Annen Person',  999, 'time');


-- ------------------------------------------------------------ HJELPERE
-- SECURITY INVOKER, ikke definer. Ble de definer, kjoerte kallet som
-- eier og fila ville vaert groenn uansett hva funksjonen slipper
-- gjennom. Ingen dynamisk SQL - funksjonen kalles direkte.
create function pg_temp.tell(p_maaned text, p_ider uuid[])
returns integer language plpgsql security invoker as $$
declare n integer;
begin
  select count(*) into n from public.a1_registeroppslag(p_maaned, p_ider);
  return n;
end $$;

create function pg_temp.feilkode(p_maaned text, p_ider uuid[])
returns text language plpgsql security invoker as $$
declare n integer;
begin
  select count(*) into n from public.a1_registeroppslag(p_maaned, p_ider);
  return 'INGEN FEIL - ' || n || ' rader';
exception when others then
  return sqlstate;
end $$;

create function pg_temp.har(p_maaned text, p_ider uuid[], p_stasjon uuid, p_nr text)
returns boolean language plpgsql security invoker as $$
declare b boolean;
begin
  select exists (
    select 1 from public.a1_registeroppslag(p_maaned, p_ider) r
     where r.stasjon_id = p_stasjon and r.ansatt_nr = p_nr
  ) into b;
  return b;
end $$;

create temporary table resultat (nr text, dom text, detalj text) on commit drop;

-- SECURITY DEFINER, og det er trygt: den MAALER ingenting. Argumentene
-- er ferdig evaluert av invoker-hjelperne foer kallet, saa det eneste
-- som kjoerer som eier er selve noteringen. Temp-tabellen eies av
-- postgres, og `authenticated` kan ikke skrive i den.
create function pg_temp.sjekk(p_nr text, p_ok boolean, p_detalj text)
returns void language sql security definer as $$
  insert into pg_temp.resultat
  values (p_nr, case when p_ok then 'OK' else 'FAIL' end, p_detalj);
$$;


-- ============================================================ SJEF A
-- Butikksjef paa A-Boenes. Ser IKKE A-Lone.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;

-- P1  POSITIV KONTROLL FOERST. Lykkes ikke denne, beviser ingen av de
--     negative noe - da er fixturen, ikke sikkerheten, det vi maaler.
select pg_temp.sjekk('P1',
  pg_temp.har('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[],
              'aaaaaaaa-0000-0000-0000-00000000e001', '1104265'),
  'Carmen arbeidet Boenes, registerrad paa Lone -> returneres');

-- P3  To kandidater paa samme nummer. Ingen distinct on, ingen limit 1.
select pg_temp.sjekk('P3',
  (select count(*) = 2 from public.a1_registeroppslag(
     '2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]) r
    where r.ansatt_nr = '1009'),
  '1009 finnes paa to stasjoner -> to rader, ikke en');

-- N1  Kari staar i Lones register og arbeidet aldri paa Boenes.
select pg_temp.sjekk('N1',
  not pg_temp.har('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[],
                  'aaaaaaaa-0000-0000-0000-00000000e001', '9001'),
  'Lone-ansatt uten arbeidstid paa Boenes -> ingen rad');

-- N2  INGEN ENUMERERING. Lones register har fire rader; sjefen naar to,
--     og bare fordi de to personene faktisk arbeidet hos henne.
select pg_temp.sjekk('N2',
  (select count(*) = 2 from public.a1_registeroppslag(
     '2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]) r
    where r.stasjon_id = 'aaaaaaaa-0000-0000-0000-00000000e001'),
  'Lones register har 4 rader, sjefen naar 2 - ingen katalog');

-- N3  Samme nummer i kjede B.
select pg_temp.sjekk('N3',
  not pg_temp.har('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[],
                  'bbbbbbbb-0000-0000-0000-00000000c001', '1104265'),
  'samme ansattnummer i annen kjede -> ingen rad');

-- N4  Uautorisert stasjon. 42501, ikke [].
select pg_temp.sjekk('N4',
  pg_temp.feilkode('2026-08', array['aaaaaaaa-0000-0000-0000-00000000e001']::uuid[]) = '42501',
  'ber om A-Lone som arbeidsstasjon -> 42501');

-- N5  Blandet liste. HELE kallet feiler.
select pg_temp.sjekk('N5',
  pg_temp.feilkode('2026-08', array[
    'aaaaaaaa-0000-0000-0000-00000000b001',
    'aaaaaaaa-0000-0000-0000-00000000e001']::uuid[]) = '42501',
  '[autorisert, uautorisert] -> 42501, ingen delvis suksess');

-- V1  Ugyldig maaned.
select pg_temp.sjekk('V1',
  pg_temp.feilkode('august', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]) = '22023',
  'ugyldig maaned -> 22023');

-- V2  Null og tom liste.
select pg_temp.sjekk('V2a',
  pg_temp.feilkode('2026-08', null) = '22023', 'null stasjonsliste -> 22023');
select pg_temp.sjekk('V2b',
  pg_temp.feilkode('2026-08', array[]::uuid[]) = '22023', 'tom stasjonsliste -> 22023');

-- V3  Duplikat i lista multipliserer ingenting.
select pg_temp.sjekk('V3',
  pg_temp.tell('2026-08', array[
    'aaaaaaaa-0000-0000-0000-00000000b001',
    'aaaaaaaa-0000-0000-0000-00000000b001']::uuid[])
  = pg_temp.tell('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]),
  '[A, A] gir samme antall som [A]');

reset role;


-- ========================================================== ADMIN A
-- Hele kjeden. Skal virke - ellers er vi strenge paa en maate som
-- stopper legitim drift.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;

-- P2  Begge stasjoner: numrene blir {1104265, 1009, 118}, og radene
--     Carmen@Lone, Ola L@Lone, Ola B@Boenes, Sandra@Lone = 4.
--     Kari er fortsatt UTE - behovsregelen gjelder ogsaa eieren.
select pg_temp.sjekk('P2',
  pg_temp.tell('2026-08', array[
    'aaaaaaaa-0000-0000-0000-00000000b001',
    'aaaaaaaa-0000-0000-0000-00000000e001']::uuid[]) = 4,
  'retailer_admin i egen kjede far de fire legitime kandidatene');

select pg_temp.sjekk('P2b',
  not pg_temp.har('2026-08', array[
    'aaaaaaaa-0000-0000-0000-00000000b001',
    'aaaaaaaa-0000-0000-0000-00000000e001']::uuid[],
    'aaaaaaaa-0000-0000-0000-00000000e001', '9001'),
  'behovsregelen gjelder ogsaa eieren - Kari er ute');

reset role;


-- ========================================================== ADMIN B
-- Speilbildet: B ser sin egen rad og ingenting fra A.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
set local role authenticated;

select pg_temp.sjekk('N3b',
  pg_temp.har('2026-08', array['bbbbbbbb-0000-0000-0000-00000000c001']::uuid[],
              'bbbbbbbb-0000-0000-0000-00000000c001', '1104265')
  and not pg_temp.har('2026-08', array['bbbbbbbb-0000-0000-0000-00000000c001']::uuid[],
                      'aaaaaaaa-0000-0000-0000-00000000e001', '1104265'),
  'kjede B ser sin egen 1104265 og ingen av A sine');

reset role;


-- ========================================================== NETTBRETT
-- `mine_stasjoner()` GIR nettbrettet A-Boenes. Bare rollekravet stopper
-- det. Dette er hele grunnen til at rolle og stasjon maa kontrolleres
-- hver for seg.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;

select pg_temp.sjekk('R1',
  pg_temp.feilkode('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]) = '42501',
  'nettbrettet avvises paa SIN EGEN stasjon');

-- Kanarifugl: stasjonen ER faktisk nettbrettets, saa R1 maaler rollen
-- og ikke en manglende tildeling.
select pg_temp.sjekk('R1b',
  exists (select 1 from public.mine_stasjoner() m
           where m = 'aaaaaaaa-0000-0000-0000-00000000b001'),
  'nettbrettet HAR stasjonen i mine_stasjoner() - R1 maaler rollen');

reset role;


-- ========================================================== REDAKTOR
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000ed","role":"authenticated"}', true);
set local role authenticated;

select pg_temp.sjekk('R2',
  pg_temp.feilkode('2026-08', array['aaaaaaaa-0000-0000-0000-00000000b001']::uuid[]) = '42501',
  'plattform_redaktor avvises');

reset role;


-- ============================================================== ANON
select pg_temp.sjekk('R3',
  not has_function_privilege('anon', 'public.a1_registeroppslag(text, uuid[])', 'execute'),
  'anon har ikke EXECUTE');

select pg_temp.sjekk('R3b',
  not has_function_privilege('public', 'public.a1_registeroppslag(text, uuid[])', 'execute'),
  'PUBLIC har ikke EXECUTE');


-- ========================================================= OPPSUMMERING
-- EN setning, fordi SQL Editor bare viser den siste. Summeringsraden
-- sorteres sist.
select nr, dom, detalj from pg_temp.resultat
union all
select
  'ZZ SUM',
  case when count(*) filter (where dom = 'FAIL') = 0 then 'INGEN FUNN' else 'FUNN' end,
  count(*)::text || ' paastander, '
    || count(*) filter (where dom = 'FAIL')::text || ' feilende'
from pg_temp.resultat
order by 1;

rollback;
