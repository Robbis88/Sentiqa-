-- =====================================================================
-- KOMMENTAR PAA EN RUTINE — OGSAA NAAR DEN IKKE BLE GJORT
--
-- «Rengjor kaffemaskin» er hake av eller ikke. Men noen ganger er det
-- viktigste hverken hake eller bilde: at maskinen lekker, at kunden sto
-- i doera, at delen ikke kom. I dag finnes det ingen plass for det, og
-- da havner det paa en gul lapp eller ingen steder.
--
-- ---------------------------------------------------------------------
-- HVORFOR EN EGEN TABELL, OG IKKE EN KOLONNE PAA `rutine_utforinger`
--
-- Fordi en `rutine_utforinger`-rad BETYR «gjort». Den er selve telleren:
-- `rutinerForDato()` og rutinestatistikken regner prosent av dem, og
-- ukebriefen sender tallet ut hver mandag.
--
-- Skulle en kommentar paa en IKKE-utfoert rutine ligge der, matte den
-- enten faa en rad — og da ville rutinen telt som gjort — eller en
-- `utfort`-boolsk kolonne som hver eneste teller maatte huske aa filtrere
-- paa. Den foerste er feil med en gang. Den andre er feil den dagen noen
-- glemmer filteret, og da er den stille.
--
-- Et notat er derfor en egen ting: den sier noe OM dagen, ikke at den er
-- gjort. De to kan staa sammen, hver for seg, eller ingen av delene.
--
-- ---------------------------------------------------------------------
-- ETT NOTAT PER RUTINE PER DAG
--
-- `unique (rutine_id, dato)` — som utfoeringene. Skriver noen paa nytt,
-- er det en RETTELSE av det som sto der, ikke en ny lapp ved siden av.
-- En trad med flere lapper per dag ville vaert en samtale, og en samtale
-- hoerer hjemme i «Send melding til sjef».
--
-- Idempotent: `if not exists` / `drop policy if exists`.
-- =====================================================================

create table if not exists public.rutine_notat (
  id            uuid primary key default gen_random_uuid(),
  rutine_id     uuid not null references public.rutiner(id)    on delete cascade,
  -- Staar her selv om den kan naas via rutinen. RLS trenger et sargbart
  -- predikat paa raden selv; et oppslag gjennom `rutiner` ville gjort
  -- hver lesing avhengig av en join.
  stasjon_id    uuid not null references public.stasjoner(id)  on delete cascade,
  dato          date not null,
  -- En tom kommentar er ikke en kommentar. Uten skranken ville et uhell
  -- i skjemaet lagt igjen en lapp uten innhold, og den ser ut som noe.
  tekst         text not null check (length(btrim(tekst)) > 0),
  -- Hvem paa vakta som skrev den. Nettbrettet deler paalogging, saa
  -- `opprettet_av` peker paa tablet-kontoen — `ansatt_id` er personen.
  ansatt_id     uuid references public.ansatte(id) on delete set null,
  opprettet_av  uuid references auth.users(id)     on delete set null,
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now(),
  unique (rutine_id, dato)
);

-- Samme spoerring som rutinesida gjoer: hent dagens notater for stasjonen.
create index if not exists rutine_notat_stasjon_dato_idx
  on public.rutine_notat (stasjon_id, dato);

comment on table public.rutine_notat is
  'Fritekst om en rutine en gitt dag. IKKE et bevis paa at den er gjort - '
  'det er rutine_utforinger. Et notat kan staa alene paa en rutine som '
  'ikke ble utfoert, og det er hele poenget med at den er en egen tabell.';

-- ---------------------------------------------------------------------
-- RETTIGHETER
--
-- `revoke ... from anon` er ikke overfloedig: Supabase-standarden
-- `alter default privileges ... grant all on tables to anon` treffer hver
-- nye tabell, og `anon` er rollen bak den offentlige noekkelen. Se `0134`.
-- ---------------------------------------------------------------------
revoke all on public.rutine_notat from anon, authenticated;
grant select, insert, update, delete on public.rutine_notat to authenticated;
grant all on public.rutine_notat to service_role;

alter table public.rutine_notat enable row level security;

-- Samme tilgang som utfoeringene: den som kan hake av rutinen, kan
-- skrive hva som skjedde med den. Nettbrettet er nettopp den rollen.
--
-- ALDRI `for all`: `using` i en `for all`-policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen - skrivepolicyen ville blitt trukket
-- inn i hver leseplan.
--
-- `mine_stasjoner()` og ikke `har_stasjonstilgang(stasjon_id)`: den siste
-- tar en KOLONNE som argument og kan derfor aldri bli initplan. Den
-- evalueres da per rad, og tabellen vokser med hver vakt.
drop policy if exists rutine_notat_les on public.rutine_notat;
create policy rutine_notat_les on public.rutine_notat
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists rutine_notat_ins on public.rutine_notat;
create policy rutine_notat_ins on public.rutine_notat
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists rutine_notat_upd on public.rutine_notat;
create policy rutine_notat_upd on public.rutine_notat
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner()))
  with check (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists rutine_notat_del on public.rutine_notat;
create policy rutine_notat_del on public.rutine_notat
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));
