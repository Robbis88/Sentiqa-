-- ---------------------------------------------------------------------
-- 0087: fysisk tak paa bemanningen per stasjon
-- ---------------------------------------------------------------------
-- Motoren fordeler de frie timene proporsjonalt med kundetrykket, og
-- den MAA bruke opp rammen. Har stasjonen mye slakk og en dag som
-- skiller seg ut, havner alt der: sondagen fikk sju personer klokka 13
-- mens mandagen stod paa en. Matematisk riktig fordeling, fysisk umulig
-- butikk - det staar ikke sju bak to kasser.
--
-- Taket er stasjonens egen grense: antall kasser, plass bak disk, hva
-- butikksjefen vet at lokalet baerer. Naar alt har naadd taket, skal
-- resten av rammen rapporteres som ufordelt i stedet for a presses inn.
--
-- maks_bemanning null = intet tak (dagens oppforsel). Ingen backfill
-- med et gjettet tall; det er butikksjefen som vet hva lokalet taaler.
create table if not exists public.bemanning_stasjon (
  stasjon_id     uuid primary key references public.stasjoner(id) on delete cascade,
  maks_bemanning int,
  oppdatert_tid  timestamptz not null default now(),
  check (maks_bemanning is null or maks_bemanning between 1 and 20)
);

comment on table public.bemanning_stasjon is
  'Stasjonsgrenser for bemanningsplanen. En rad per stasjon.';
comment on column public.bemanning_stasjon.maks_bemanning is
  'Flest personer planen kan foresla i en enkelt time. null = intet tak.';

alter table public.bemanning_stasjon enable row level security;

-- Samme monster som 0081: aldri "for all", funksjonskall pakket i
-- (select ...) saa de blir initplan, og stasjonstilgang via
-- mine_stasjoner() i stedet for har_stasjonstilgang(kolonne).
drop policy if exists bemanning_stasjon_les   on public.bemanning_stasjon;
drop policy if exists bemanning_stasjon_ins   on public.bemanning_stasjon;
drop policy if exists bemanning_stasjon_upd   on public.bemanning_stasjon;
drop policy if exists bemanning_stasjon_del   on public.bemanning_stasjon;

create policy bemanning_stasjon_les on public.bemanning_stasjon
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

create policy bemanning_stasjon_ins on public.bemanning_stasjon
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy bemanning_stasjon_upd on public.bemanning_stasjon
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy bemanning_stasjon_del on public.bemanning_stasjon
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.bemanning_stasjon to authenticated;
