-- =====================================================================
-- Hvem er butikksjef, og naar? - og hvorfor timene deres holdes utenfor
--
-- `bemanning_aar.timer_aar` er den VARIABLE rammen. St1 har trukket fra
-- ett aarsverk (1695 t) fordi butikksjefen normalt gaar paa fastloenn.
-- Rammen er altsaa definert UTEN henne.
--
-- Da maa forbruket telles paa samme maate. Ellers sammenligner vi en
-- befolkning med butikksjef mot en ramme uten, og resultatet er et
-- overforbruk som ingen kan gjore noe med - det er ikke en
-- bemanningsbeslutning at butikksjefen er paa jobb.
--
-- Robert, 2026-08-21: «om jeg legger inn ansattnummeret til alle
-- butikksjefene da, saa regner vi ikke med de?» Ja - og kronene fanges
-- fortsatt av `/regnskap`, som sammenligner loenn mot loennsbudsjett.
--
-- HVORFOR DETTE MAA KONFIGURERES, og ikke kan utledes:
--
--   `profiler` har rollen `butikksjef`, men ingen `ansatt_nr` - det er
--   innloggingsbrukeren, ikke stemplingsnummeret.
--   `ansatte` har hverken rolle eller loennsform.
--
--   Se [[sentiqa-tre-identiteter]]: samme person ligger under ansatt_nr,
--   ansatte.id og fritekst navn. Aa koble paa NAVN i stillhet er
--   noeyaktig den feilen som lager doble ansatte, saa denne tabellen
--   peker paa `ansatt_nr` - nummeret som foelger med til loenn.
--
-- PERIODER, IKKE ETT NAVN PER STASJON. Folk bytter rolle:
--   Hasan ble butikksjef paa Varden 2026-08-01. Foer det var han
--   timeloennet ansatt, og timene hans hoerte hjemme i rammen.
--   Paa Dale kommer det ny butikksjef 2026-11-01.
-- Uten `fra_dato`/`til_dato` ville en rollendring omskrevet historikken.
--
-- LOENNSFORM STAAR IKKE HER, med vilje. Den avgjor hvilken konto som
-- belastes, ikke hvor mange timer som ble jobbet. 1 700 timer er 1 700
-- timer enten de er fastloenn eller timeloenn, og de skal holdes utenfor
-- bemanningstellingen uansett. Da slipper vi ogsaa aa vedlikeholde et
-- felt som endrer seg uten at noen sier fra.
-- =====================================================================

create table if not exists public.stasjon_leder (
  id          uuid primary key default gen_random_uuid(),
  retailer_id uuid not null references public.retailers(id) on delete restrict,
  stasjon_id  uuid not null references public.stasjoner(id) on delete cascade,
  -- Nummeret, ikke ansatte.id: det er dette stemplingene baerer.
  ansatt_nr   text not null,
  -- Navnet slik det var da raden ble lagt inn. Ren lesehjelp - ingenting
  -- kobles paa den. Uten den er tabellen fem tall ingen kan kontrollere.
  navn        text,
  fra_dato    date not null,
  til_dato    date,
  notat       text,
  opprettet_tid timestamptz not null default now(),
  check (til_dato is null or til_dato >= fra_dato)
);

create index if not exists stasjon_leder_oppslag_idx
  on public.stasjon_leder (stasjon_id, ansatt_nr, fra_dato);

comment on table public.stasjon_leder is
  'Hvem er butikksjef paa hvilken stasjon, i hvilken periode. Timene '
  'deres holdes utenfor bemanningstellingen fordi timer_aar er definert '
  'uten butikksjefens aarsverk. Loennsform staar IKKE her - den avgjor '
  'konto, ikke timetall.';
comment on column public.stasjon_leder.ansatt_nr is
  'Stemplingsnummeret. IKKE ansatte.id og IKKE navn - se de tre '
  'identitetene: samme person finnes under alle tre.';
comment on column public.stasjon_leder.til_dato is
  'Null = fortsatt butikksjef. Settes naar noen slutter i rollen, saa '
  'historikken ikke skrives om av dagens organisasjon.';

alter table public.stasjon_leder enable row level security;

-- KONFIGURASJON, ALTSAA EIER. Butikksjefen skal ikke kunne ta seg selv
-- ut av tellingen. Delt i select/insert/update/delete og ikke `for all`:
-- USING i en `for all`-policy gjelder ogsaa SELECT, og permissive
-- policyer OR-es sammen - da trekkes skrivepolicyen inn i hver leseplan.
drop policy if exists stasjon_leder_les on public.stasjon_leder;
create policy stasjon_leder_les on public.stasjon_leder
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists stasjon_leder_ny on public.stasjon_leder;
create policy stasjon_leder_ny on public.stasjon_leder
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists stasjon_leder_endre on public.stasjon_leder;
create policy stasjon_leder_endre on public.stasjon_leder
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin')
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists stasjon_leder_slett on public.stasjon_leder;
create policy stasjon_leder_slett on public.stasjon_leder
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.stasjon_leder to authenticated;
