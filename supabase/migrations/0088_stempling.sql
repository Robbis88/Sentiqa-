-- ---------------------------------------------------------------------
-- 0088: stemplinger fra easy@work (Basis Export)
-- ---------------------------------------------------------------------
-- Salgstallene sier hvor mange kunder som kom. Denne sier hvor mange
-- hender som tok imot dem. Uten den kan bemanningsplanen bare foresla,
-- aldri male - og en butikksjef som overbemanner en rolig tirsdag ser
-- like effektiv ut som en som ikke gjor det.
--
-- En rad per stempling, ikke per vakt. Folk stempler ut og inn igjen pa
-- samme vakt (13 av 132 poster i juli 2026 var under 45 minutter), og
-- sammenslaingen horer hjemme i lesingen, ikke i lagringen. Rar data
-- lagres ra; tolkningen kan endres uten a laste opp pa nytt.
create table if not exists public.stempling (
  id            uuid primary key default gen_random_uuid(),
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ansatt_nr     text not null,
  ansatt_navn   text not null,
  dato          date not null,
  fra_tid       time not null,
  til_tid       time not null,
  minutter      int  not null check (minutter >= 0),
  betalt        boolean not null default true,
  kilde_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  -- Samme person kan ikke stemple inn to ganger pa samme minutt. Gjor
  -- opplasting av samme maaned to ganger til en no-op i stedet for en
  -- dobling - filene lastes opp om igjen naar noen retter en stempling.
  unique (stasjon_id, ansatt_nr, dato, fra_tid)
);

create index if not exists stempling_stasjon_dato_idx
  on public.stempling (stasjon_id, dato);
create index if not exists stempling_ansatt_idx
  on public.stempling (stasjon_id, ansatt_nr, dato);

comment on table public.stempling is
  'Faktiske stemplinger fra easy@work. En rad per stempling, ikke per vakt.';
comment on column public.stempling.ansatt_nr is
  'Stemplingsnummer fra easy@work. Stabil noekkel; navnet kan endres.';
comment on column public.stempling.til_tid is
  '00:00 betyr midnatt, altsaa slutten av dagen - ikke starten.';

alter table public.stempling enable row level security;

-- Samme monster som 0081/0087: aldri "for all", funksjonskall pakket i
-- (select ...) saa de blir initplan, stasjonstilgang via mine_stasjoner().
drop policy if exists stempling_les on public.stempling;
drop policy if exists stempling_ins on public.stempling;
drop policy if exists stempling_upd on public.stempling;
drop policy if exists stempling_del on public.stempling;

create policy stempling_les on public.stempling
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

create policy stempling_ins on public.stempling
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy stempling_upd on public.stempling
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy stempling_del on public.stempling
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.stempling to authenticated;

-- Rapporttypen maa finnes for at importjobben skal kunne merkes.
alter type public.rapporttype add value if not exists 'easyatwork_stempling';
