-- =====================================================================
-- Sentiqa — RLS-isolasjonstest (PROSJEKT.md §14: "den eksistensielle feilen")
-- Beviser at tenant A ALDRI ser tenant B, og at plattform-redaktør aldri
-- ser forretningsdata. Kjør HELE filen i Supabase SQL Editor etter at
-- 0001_fundament.sql er kjørt. Den rydder opp etter seg (rollback).
--
-- Simulerer en innlogget bruker ved å sette request.jwt.claims (auth.uid())
-- og bytte til rollen "authenticated" — nøyaktig slik en ekte forespørsel ser ut.
-- =====================================================================
begin;

-- --- Testdata: to tenanter, hver med admin + butikksjef + stasjon ---
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin-a@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'sjef-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'admin-b@test.local'),
  ('00000000-0000-0000-0000-0000000000ed', 'redaktor@test.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('11111111-1111-1111-1111-111111111111', 'Tenant A'),
  ('22222222-2222-2222-2222-222222222222', 'Tenant B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111', 'retailer_admin', 'Admin A'),
  ('00000000-0000-0000-0000-0000000000a2', '11111111-1111-1111-1111-111111111111', 'butikksjef',     'Sjef A'),
  ('00000000-0000-0000-0000-0000000000b1', '22222222-2222-2222-2222-222222222222', 'retailer_admin', 'Admin B'),
  ('00000000-0000-0000-0000-0000000000ed', null,                                   'plattform_redaktor', 'Redaktør');

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '0001', 'A Bønes',  'pendler'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '0002', 'A Varden', 'utfart'),
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '0001', 'B Sentrum','sentrum');

-- Sjef A tildeles kun stasjon A-0001 (ikke A-0002)
insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('00000000-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-000000000001');

-- Kaffesvinn paa BEGGE A-stasjonene og paa B. Sjef A er bare tildelt
-- A-0001, saa hun skal se én rad - ikke A-0002 og ikke B.
--
-- 13010 er kaffe, 12011 er poelse. Policyen fra 0127 slipper bare
-- 130xx gjennom til butikksjefen; resten av svinnrapporten er
-- eierens sak, og poelseraden er der for aa bevise nettopp det.
insert into public.regnskap_usynlig_svinn
  (retailer_id, stasjon_id, periode, kode, navn, usynlig_kr) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001',
   date_trunc('month', current_date)::date, '13010', '13010 KAFFE', 5000),
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001',
   date_trunc('month', current_date)::date, '12011', '12011 POELSE', 9000),
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000002',
   date_trunc('month', current_date)::date, '13010', '13010 KAFFE', 7000),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-000000000001',
   date_trunc('month', current_date)::date, '13010', '13010 KAFFE', 8000);

-- Hjelper: utgi seg for en bruker
create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid::text, 'role', 'authenticated')::text, true);
end $$;

-- Hjelper: paastand
--
-- SAMLER I STEDET FOR AA KASTE, og det er en rettelse. Foerste utgave
-- gjorde `raise notice` paa hver bestaatt paastand - og SQL Editor
-- viser ikke notices. Resultatet var én tom celle, og en test som
-- besto saa noeyaktig ut som en test som aldri kjoerte.
--
-- Kaster den paa foerste feil, forsvinner ogsaa alle paastandene
-- ETTER den. Da vet man at noe er galt, men ikke hvor mye.
--
-- Naa fylles en temp-tabell, og siste setning i fila er et `select`
-- som lister hver eneste paastand med status. Feil foerst.
-- INGEN `serial`, og et eksplisitt grant. Tabellen opprettes som den
-- rollen fila startes med, mens paastandene kjoerer som
-- `authenticated` - uten grantet ville innsettingen blitt avvist, og
-- testen feilet paa noe som ikke handler om RLS i det hele tatt.
-- Sekvensen bak `serial` ville trengt sitt eget grant, saa nummeret
-- regnes i stedet av tabellen selv.
create temp table if not exists paastander (
  nr    int,
  navn  text,
  ok    boolean
);
grant all on paastander to public;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql as $$
begin
  insert into paastander (nr, navn, ok)
    select coalesce(max(nr), 0) + 1, p_navn, coalesce(p_ok, false) from paastander;
end $$;

set local role authenticated;

-- === Admin A ===
select pg_temp.logg_inn_som('00000000-0000-0000-0000-0000000000a1');
select pg_temp.paastand('Admin A ser begge egne stasjoner',
  (select count(*) = 2 from public.stasjoner));
select pg_temp.paastand('Admin A ser IKKE tenant B sin stasjon',
  (select count(*) = 0 from public.stasjoner where retailer_id = '22222222-2222-2222-2222-222222222222'));
select pg_temp.paastand('Admin A ser kun egen retailer-rad',
  (select count(*) = 1 from public.retailers));
-- KONTRASTEN. Eieren ser hele svinnrapporten for begge sine stasjoner,
-- ogsaa poelsa. Uten denne paastanden kunne policyen fra 0127 vaert for
-- SNEVER uten at noe sa fra - og en tom rapport ser ut som «ingen svinn».
select pg_temp.paastand('Admin A ser hele svinnrapporten for begge stasjoner',
  (select count(*) = 3 from public.regnskap_usynlig_svinn));

-- === Butikksjef A (kun tildelt A-0001) ===
select pg_temp.logg_inn_som('00000000-0000-0000-0000-0000000000a2');
select pg_temp.paastand('Sjef A ser kun sin tildelte stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Sjef A ser den RIKTIGE stasjonen',
  exists (select 1 from public.stasjoner where id = 'aaaaaaaa-0000-0000-0000-000000000001'));

-- Kaffesvinn: kun EGEN stasjon, og kun kaffen.
select pg_temp.paastand('Sjef A ser kaffesvinn for sin egen stasjon',
  exists (select 1 from public.regnskap_usynlig_svinn
          where stasjon_id = 'aaaaaaaa-0000-0000-0000-000000000001' and kode = '13010'));
select pg_temp.paastand('Sjef A ser IKKE kaffesvinn for stasjonen hun ikke har',
  (select count(*) = 0 from public.regnskap_usynlig_svinn
   where stasjon_id = 'aaaaaaaa-0000-0000-0000-000000000002'));
select pg_temp.paastand('Sjef A ser IKKE tenant B sitt kaffesvinn',
  (select count(*) = 0 from public.regnskap_usynlig_svinn
   where retailer_id = '22222222-2222-2222-2222-222222222222'));
select pg_temp.paastand('Sjef A ser IKKE poelsesvinn - bare 130xx slipper gjennom',
  (select count(*) = 0 from public.regnskap_usynlig_svinn where kode = '12011'));
select pg_temp.paastand('Sjef A ser NOEYAKTIG én svinnrad totalt',
  (select count(*) = 1 from public.regnskap_usynlig_svinn));

-- Og det samme gjennom viewet AI-en spoer.
select pg_temp.paastand('v_kaffe_svinn gir Sjef A kun hennes egen stasjon',
  (select count(*) = 1 from public.v_kaffe_svinn)
  and exists (select 1 from public.v_kaffe_svinn
              where stasjon_id = 'aaaaaaaa-0000-0000-0000-000000000001'));

-- === Admin B ===
select pg_temp.logg_inn_som('00000000-0000-0000-0000-0000000000b1');
select pg_temp.paastand('Admin B ser kun sin egen stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Admin B ser IKKE tenant A sine stasjoner',
  (select count(*) = 0 from public.stasjoner where retailer_id = '11111111-1111-1111-1111-111111111111'));

-- === Plattform-redaktør: skal ALDRI se forretningsdata (§3) ===
select pg_temp.logg_inn_som('00000000-0000-0000-0000-0000000000ed');
select pg_temp.paastand('Redaktør ser INGEN retailers', (select count(*) = 0 from public.retailers));
select pg_temp.paastand('Redaktør ser INGEN stasjoner', (select count(*) = 0 from public.stasjoner));

reset role;

-- SVARET. Siste setning som gir rader, saa SQL Editor viser den.
--
-- Feil foerst: staar det «FEIL» oeverst, er det den raden som
-- betyr noe. Er alt «ok», er testen bestaatt - og da SER man det,
-- i stedet for aa slutte seg til det av at ingenting skjedde.
select
  case when ok then 'ok' else 'FEIL' end   as status,
  navn                                     as paastand
from paastander
order by ok, nr;

rollback;
