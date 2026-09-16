-- =====================================================================
-- TILGANGSPRIMITIVEN, TESTET DIREKTE
--
-- Kjorer i en transaksjon og ruller tilbake selv. Trygg i produksjon.
--
-- ---------------------------------------------------------------------
-- HVORFOR DENNE FINNES VED SIDEN AV ATFERDSMATRISEN
--
-- `rls_kanarifugl_generert.sql` beviser tilgang PER TABELL, for aktorene
-- owner_A, owner_B, manager_A1 og tablet_A1. Den daekker fire av de fem
-- tilfellene tilgangsmodellen lover.
--
-- Den femte - en butikksjef med FLERE tildelte stasjoner - staar i
-- fasitverdenen som `manager_A12`, men ingen paastand leser den. Jeg
-- trodde foerst den var daekket fordi soeket traff strengen
-- «manager_A1A2»; det var en fixture-VERDI, ikke en aktor. Et soeketreff
-- er ikke et bevis.
--
-- Aa legge aktoren inn i matrisen ville gitt N kopier av ETT faktum, én
-- per varm tabell. Egenskapen hoerer ikke til `basisvakt` eller
-- `lonnsregister` - den hoerer til `mine_stasjoner()` (0077), som er et
-- `union` over `butikksjef_stasjoner`. Husregelen sier at en
-- generatorantakelse skal ha en rask DIREKTE test, ikke full CI som
-- foerste detektor.
--
-- Feiler denne, ligger problemet i tildelingsmodellen - ikke i tabellen
-- som tilfeldigvis ble roed.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Fasitverden. Samme id-er som atferdsmatrisen, med vilje: skiller de
-- lag, er det to verdener aa holde i hodet i stedet for én.
-- ---------------------------------------------------------------------
-- `profiler.id` peker paa `auth.users`. Uten disse feiler innsettingen
-- paa fremmednoekkel i stedet for paa en paastand - og da har fila ikke
-- maalt noe som helst. Samme rekkefoelge som atferdsmatrisen.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a000', 'owner_A@kanari.local'),
  ('00000000-0000-0000-0000-00000000a001', 'manager_A1@kanari.local'),
  ('00000000-0000-0000-0000-00000000a012', 'manager_A12@kanari.local'),
  ('00000000-0000-0000-0000-00000000a101', 'tablet_A1@kanari.local'),
  ('00000000-0000-0000-0000-00000000b000', 'owner_B@kanari.local')
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  ('aaaa0000-0000-4000-8000-000000000000', 'Kanari A'),
  ('bbbb0000-0000-4000-8000-000000000000', 'Kanari B')
on conflict (id) do nothing;

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  ('a1110000-0000-4000-8000-000000000001', 'aaaa0000-0000-4000-8000-000000000000', '0001', 'Sentrum', 'sentrum'),
  ('a1110000-0000-4000-8000-000000000002', 'aaaa0000-0000-4000-8000-000000000000', '0002', 'Nord',    'pendler'),
  ('a1110000-0000-4000-8000-000000000003', 'aaaa0000-0000-4000-8000-000000000000', '0003', 'Vest',    'utfart'),
  ('b1110000-0000-4000-8000-000000000001', 'bbbb0000-0000-4000-8000-000000000000', '0001', 'Sentrum', 'sentrum')
on conflict (id) do nothing;

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
  ('00000000-0000-0000-0000-00000000a000', 'aaaa0000-0000-4000-8000-000000000000', 'retailer_admin',      'owner_A'),
  ('00000000-0000-0000-0000-00000000a001', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef',          'manager_A1'),
  ('00000000-0000-0000-0000-00000000a012', 'aaaa0000-0000-4000-8000-000000000000', 'butikksjef',          'manager_A12'),
  ('00000000-0000-0000-0000-00000000a101', 'aaaa0000-0000-4000-8000-000000000000', 'butikkbruker_tablet', 'tablet_A1'),
  ('00000000-0000-0000-0000-00000000b000', 'bbbb0000-0000-4000-8000-000000000000', 'retailer_admin',      'owner_B')
on conflict (id) do nothing;

insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
  ('00000000-0000-0000-0000-00000000a001', 'a1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000a012', 'a1110000-0000-4000-8000-000000000001'),
  ('00000000-0000-0000-0000-00000000a012', 'a1110000-0000-4000-8000-000000000002'),
  ('00000000-0000-0000-0000-00000000a101', 'a1110000-0000-4000-8000-000000000001')
on conflict do nothing;

create temporary table funn (navn text, status text, detalj text) on commit drop;

create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
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

-- Én paastand: ser aktoeren noeyaktig de stasjonene vi forventer?
create or replace function pg_temp.krev(
  p_navn text, p_uid uuid, p_forventet uuid[]
) returns void language plpgsql as $$
declare
  v_sett uuid[];
begin
  perform pg_temp.logg_inn_som(p_uid);
  select coalesce(array_agg(m order by m), '{}'::uuid[])
    into v_sett
    from public.mine_stasjoner() m;
  perform pg_temp.som_eier();
  insert into funn (navn, status, detalj)
  values (
    p_navn,
    case when v_sett = (select coalesce(array_agg(x order by x), '{}'::uuid[])
                          from unnest(p_forventet) x)
         then 'ok' else 'FEIL' end,
    'fikk ' || coalesce(array_length(v_sett, 1), 0)::text
      || ', forventet ' || coalesce(array_length(p_forventet, 1), 0)::text
      || ' | ' || coalesce(array_to_string(v_sett, ', '), '(ingen)')
  );
end $$;

-- ---------------------------------------------------------------------
-- PAASTANDENE
-- ---------------------------------------------------------------------
select pg_temp.krev(
  'retailer_admin A ser hele kjeden, aldri B',
  '00000000-0000-0000-0000-00000000a000',
  array['a1110000-0000-4000-8000-000000000001',
        'a1110000-0000-4000-8000-000000000002',
        'a1110000-0000-4000-8000-000000000003']::uuid[]);

select pg_temp.krev(
  'butikksjef tildelt A1 ser BARE A1',
  '00000000-0000-0000-0000-00000000a001',
  array['a1110000-0000-4000-8000-000000000001']::uuid[]);

-- DEN SOM MANGLET. Flere tildelinger er hele grunnen til at
-- `butikksjef_stasjoner` er en mange-til-mange og ikke en kolonne.
select pg_temp.krev(
  'butikksjef tildelt A1+A2 ser BEGGE, men ikke A3',
  '00000000-0000-0000-0000-00000000a012',
  array['a1110000-0000-4000-8000-000000000001',
        'a1110000-0000-4000-8000-000000000002']::uuid[]);

select pg_temp.krev(
  'nettbrett A1 er stasjonsbundet',
  '00000000-0000-0000-0000-00000000a101',
  array['a1110000-0000-4000-8000-000000000001']::uuid[]);

select pg_temp.krev(
  'retailer_admin B ser aldri A',
  '00000000-0000-0000-0000-00000000b000',
  array['b1110000-0000-4000-8000-000000000001']::uuid[]);

-- ---------------------------------------------------------------------
-- KANARIFUGLENE
-- ---------------------------------------------------------------------
-- To maater denne fila kan vaere groenn mens den er i stykker.
--
-- 1) `mine_stasjoner()` slutter aa returnere noe. Da ville hver aktoer
--    faatt tom liste - og en tom liste mot en tom liste er sann bare
--    hvis forventningen ogsaa er tom. Den er den ikke her, saa
--    paastandene over ville blitt roede. Men hvis noen SENERE endrer en
--    forventning til `'{}'`, forsvinner det vernet. Derfor maales det
--    direkte: minst én aktoer skal se minst én stasjon.
-- 2) Sammenligningen kan ikke feile. Testes ved aa holde to kjent ulike
--    lister mot hverandre - gir den `ok`, maaler ingen av paastandene
--    over noe som helst.
insert into funn (navn, status, detalj)
select 'KANARI: noen ser faktisk noe',
       case when exists (select 1 from funn where detalj like 'fikk 1%'
                                               or detalj like 'fikk 2%'
                                               or detalj like 'fikk 3%')
            then 'ok' else 'FEIL' end,
       'ellers maaler paastandene over ingenting';

insert into funn (navn, status, detalj)
select 'KANARI: sammenligningen kan feile',
       case when array['a']::text[] = array['b']::text[] then 'FEIL' else 'ok' end,
       'to kjent ulike lister skal ikke vaere like';

insert into funn (navn, status, detalj)
select 'KANARI: alle fem paastandene kjorte',
       case when (select count(*) from funn where navn not like 'KANARI%') = 5
            then 'ok' else 'FEIL' end,
       (select count(*)::text || ' paastander' from funn where navn not like 'KANARI%');

-- ---------------------------------------------------------------------
-- OPPSUMMERING
-- ---------------------------------------------------------------------
select navn, status, detalj from funn order by status desc, navn;

do $$
declare n integer;
begin
  select count(*) into n from funn where status = 'FEIL';
  if n > 0 then
    raise exception
      '% paastand(er) om mine_stasjoner() feilet. Problemet ligger i '
      'tildelingsmodellen, ikke i tabellen som ble roed.', n;
  end if;
end $$;

rollback;
