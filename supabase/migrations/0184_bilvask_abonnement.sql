-- ---------------------------------------------------------------------
-- 0184: bilvaskabonnementene som kassa aldri ser
-- ---------------------------------------------------------------------
-- Abonnementene betales rett til konto. Kassa registrerer bare
-- enkeltvasker, saa bruttofortjenesten som loennsrommet regnes av blir
-- for lav hver eneste maaned.
--
-- BARE BRUTTOBIDRAGET, IKKE OMSETNINGEN. Omsetningen har sin egen
-- bilvaskkolonne; det som mangler er de 75 prosentene som er
-- fortjeneste. Aa legge beloepet inn to steder ville gjort ett hull til
-- to tall som ikke stemmer.
--
-- Regnskapet har det riktige tallet naar det kommer. Det er derfor
-- bilvask paa regnskapsrapporten alltid er hoeyere enn kassaomsetningen.
-- Beloepene her hoerer altsaa hjemme i maanedene som IKKE er avlagt -
-- legges de inn i en avlagt maaned, telles de to ganger. Samme asymmetri
-- som fastloenn og sykeloenn: regnskapet er komplett, det som mangler er
-- underveis.
--
-- ---------------------------------------------------------------------
-- EN UKE ER IKKE EN MAANED
--
-- Rapporten kommer per uke, og uke 26 kan ligge halvt i juni og halvt i
-- juli. Beloepet deles derfor paa sju og fordeles per dag; hver maaned
-- faar dagene sine. Lagres det som «uke 26 = juli», ville juni mistet
-- sin del og juli faatt for mye - i to maaneder paa rad.
--
-- Delingen skjer i lesingen, ikke her. Raa data lagres raatt: endres
-- fordelingsregelen, skal det ikke kreve at noen taster inn paa nytt.
--
-- ---------------------------------------------------------------------
-- ÉN RAD PER STASJON PER UKE
--
-- Baade eier og butikksjef skal kunne legge inn. Uten en unik noekkel
-- ville samme uke blitt registrert to ganger av to personer som ikke
-- visste om hverandre - og et dobbelt beloep ser ut som en god uke.
create table if not exists public.bilvask_abonnement (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ar            int  not null check (ar between 2000 and 2100),
  uke           int  not null check (uke between 1 and 53),
  belop_kr      numeric(12,2) not null check (belop_kr >= 0),
  registrert_av uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now(),
  slettet_tid   timestamptz,
  unique (stasjon_id, ar, uke)
);

create index if not exists bilvask_abonnement_stasjon_idx
  on public.bilvask_abonnement (stasjon_id, ar, uke);

comment on table public.bilvask_abonnement is
  'Ukentlige abonnementsinntekter paa bilvask, fra rapporten som kommer paa e-post. '
  'Kassa ser dem ikke - de betales rett til konto. 75 prosent er bruttofortjeneste.';
comment on column public.bilvask_abonnement.belop_kr is
  'Hele beloepet for uka, slik det staar i rapporten. Bare BRUTTOBIDRAGET brukes '
  '- 75 prosent - fordi omsetningen alt har sin egen bilvaskkolonne. Andelen '
  'ligger i koden, ikke her, saa den kan endres uten at noen taster inn paa nytt.';
comment on column public.bilvask_abonnement.uke is
  'ISO-uke. En uke kan krysse maanedsskiftet; delingen skjer i lesingen.';

alter table public.bilvask_abonnement enable row level security;

-- Samme monster som 0088/0179: aldri "for all", funksjonskall pakket i
-- (select ...) saa de blir initplan, stasjonstilgang via mine_stasjoner().
drop policy if exists bilvask_abonnement_les on public.bilvask_abonnement;
drop policy if exists bilvask_abonnement_ins on public.bilvask_abonnement;
drop policy if exists bilvask_abonnement_upd on public.bilvask_abonnement;
drop policy if exists bilvask_abonnement_del on public.bilvask_abonnement;

-- LESING FOR ALLE SOM NAAR STASJONEN, ogsaa nettbrettet. Et beloep for
-- en uke er ikke personopplysninger, og butikksjefen maa se hva eieren
-- alt har lagt inn - ellers legges uka inn to ganger.
create policy bilvask_abonnement_les on public.bilvask_abonnement
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

create policy bilvask_abonnement_ins on public.bilvask_abonnement
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy bilvask_abonnement_upd on public.bilvask_abonnement
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy bilvask_abonnement_del on public.bilvask_abonnement
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.bilvask_abonnement to authenticated;
-- Standardrettighetene i schema public treffer hver ny tabell, og anon er
-- rollen bak den offentlige noekkelen i hver sidelast (0134).
revoke all on public.bilvask_abonnement from anon;

-- Kvittering.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'bilvask_abonnement')       as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'bilvask_abonnement'
      and grantee = 'anon')                                                 as anon;
