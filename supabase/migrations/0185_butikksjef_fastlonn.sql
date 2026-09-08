-- ---------------------------------------------------------------------
-- 0185: butikksjefens faktiske grunnloenn
-- ---------------------------------------------------------------------
-- Regnskapets konto 501 er FAKTISK fastloenn, og for avlagte maaneder er
-- den fasit. Problemet er maaneden som ikke er avlagt: der baerer
-- `medFastlonn` sist kjente 501 framover, og en loennsoekning eller en
-- ny butikksjef gjoer at anslaget ligger etter i inntil halvannen maaned.
--
-- Her legger eieren inn den faktiske grunnloennen, og systemet regner
-- resten: feriepenger, arbeidsgiveravgift, pensjon. Satsene ligger i
-- `SATSER` i lonnskost/easyatwork.ts - ikke her - saa de kan endres uten
-- at noen taster inn paa nytt.
--
-- ---------------------------------------------------------------------
-- BARE DEN AAPNE MAANEDEN
--
-- Tallet retter IKKE maalestokken. BP-en foerer kjedesnittet for
-- fastloenn, saa `loennsandel = BP-loenn / BP-brutto` er litt urettferdig
-- mellom stasjoner - en butikksjef over snittet gir sin stasjon et for
-- stramt maal.
--
-- Det er en ekte skjevhet, og den kunne rettes her. Men aa gjoere det
-- ville endret prosenten alle er blitt maalt mot, ogsaa bakover, og det
-- skal vaere et bevisst valg - ikke en foelge av at noen fylte ut en
-- tabell. Valgt bort med vilje, 2026-09-08.
--
-- ---------------------------------------------------------------------
-- ÉN PER STASJON PER MAANED
--
-- Bare butikksjefer har fastloenn, og en stasjon har én. Noekkelen er
-- derfor stasjon og maaned - ingen personkolonne, som ogsaa er én
-- personopplysning mindre lagret enn noedvendig.
create table if not exists public.butikksjef_fastlonn (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ar            int  not null check (ar between 2000 and 2100),
  maned         int  not null check (maned between 1 and 12),
  -- Grunnloenn for maaneden, foer paaslag. Ikke arbeidsgiverkost.
  grunnlonn_kr  numeric(12,2) not null check (grunnlonn_kr >= 0),
  registrert_av uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now(),
  slettet_tid   timestamptz,
  unique (stasjon_id, ar, maned)
);

create index if not exists butikksjef_fastlonn_stasjon_idx
  on public.butikksjef_fastlonn (stasjon_id, ar, maned);

comment on table public.butikksjef_fastlonn is
  'Butikksjefens faktiske grunnloenn per maaned. Fyller den aapne maaneden der '
  'regnskapets konto 501 enda ikke finnes. Retter ikke maalestokken - se 0185.';
comment on column public.butikksjef_fastlonn.grunnlonn_kr is
  'Grunnloenn foer paaslag. Feriepenger, aga og pensjon regnes av den i koden.';

alter table public.butikksjef_fastlonn enable row level security;

drop policy if exists butikksjef_fastlonn_les on public.butikksjef_fastlonn;
drop policy if exists butikksjef_fastlonn_ins on public.butikksjef_fastlonn;
drop policy if exists butikksjef_fastlonn_upd on public.butikksjef_fastlonn;
drop policy if exists butikksjef_fastlonn_del on public.butikksjef_fastlonn;

-- EIERENS ALENE, OGSAA AA LESE.
--
-- Dette er én navngitt persons loenn - stasjonen har én butikksjef, saa
-- raden PEKER paa en person selv uten en navnekolonne. Butikksjefen ble
-- stengt ute fra konto 501 i #201 nettopp fordi den raden var én persons
-- loenn; denne tabellen er strengere enn det, ikke loesere.
--
-- Funksjonskall pakket i (select ...) saa de blir initplan, og aldri
-- "for all" - `USING` der ville trukket skrivepolicyen inn i hver
-- leseplan.
create policy butikksjef_fastlonn_les on public.butikksjef_fastlonn
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

create policy butikksjef_fastlonn_ins on public.butikksjef_fastlonn
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

create policy butikksjef_fastlonn_upd on public.butikksjef_fastlonn
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

create policy butikksjef_fastlonn_del on public.butikksjef_fastlonn
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.butikksjef_fastlonn to authenticated;
revoke all on public.butikksjef_fastlonn from anon;

-- Kvittering.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'butikksjef_fastlonn')       as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'butikksjef_fastlonn'
      and grantee = 'anon')                                                  as anon;
