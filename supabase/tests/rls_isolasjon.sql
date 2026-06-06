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

-- Hjelper: utgi seg for en bruker
create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid::text, 'role', 'authenticated')::text, true);
end $$;

-- Hjelper: påstand
create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql as $$
begin
  if p_ok then raise notice 'OK   %', p_navn;
  else raise exception 'FEIL %', p_navn; end if;
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

-- === Butikksjef A (kun tildelt A-0001) ===
select pg_temp.logg_inn_som('00000000-0000-0000-0000-0000000000a2');
select pg_temp.paastand('Sjef A ser kun sin tildelte stasjon',
  (select count(*) = 1 from public.stasjoner));
select pg_temp.paastand('Sjef A ser den RIKTIGE stasjonen',
  exists (select 1 from public.stasjoner where id = 'aaaaaaaa-0000-0000-0000-000000000001'));

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
do $$ begin raise notice '--- Alle isolasjonspåstander bestått ---'; end $$;

-- Ruller tilbake all testdata. Bytt til COMMIT kun hvis du vil beholde seed.
rollback;
