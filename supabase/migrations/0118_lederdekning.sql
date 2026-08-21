-- =====================================================================
-- Er det en fastloennet butikksjef paa plass? En hake per maaned.
--
-- St1 trekker ett aarsverk (1695 t) fra timebudsjettet FORDI de antar
-- at butikksjefen gaar paa fastloenn. `bemanning_aar.timer_aar` er
-- altsaa rammen MINUS henne.
--
-- Det fratrekket er riktig naar antakelsen holder. Naar den ikke gjor
-- det, maa arbeidet hennes gjores av timeloennede - fra en ramme som
-- ikke er dimensjonert for det.
--
-- Robert, 2026-08-21: «hva om eier faar en egen side og administrere
-- dette her paa? Huke av for maaneder de har fastloennete butikksjefer.
-- Tilfelle permisjon eller vikariater som er inne? Saa hvis det ikke er
-- fastloennete i 6 maaneder saa legger den til halvparten i budsjettet
-- til den aktuelle butikken.»
--
-- EN HAKE PER MAANED, IKKE EN PERSON. Foerste utkast (forkastet foer
-- det ble kjort) registrerte HVEM som var butikksjef, per periode, paa
-- `ansatt_nr`. Det er en daarligere loesning:
--
--   * Den maa loese identitet. Samme person ligger under ansatt_nr,
--     ansatte.id og fritekst navn, og `profiler` har rollen men ikke
--     nummeret. Se [[sentiqa-tre-identiteter]].
--   * Den maa vite hvem som stempler, og folk stempler ulikt.
--   * Og den lot timene til en TIMELOENNET butikksjef forsvinne fra
--     begge sider av regnestykket: rammen manglet dem, og tellingen
--     hoppet over dem. Jobbet hun 2 200 i stedet for 1 695, ble 500
--     timer usynlige.
--
-- Denne stiller ETT spoersmaal som ingen trenger et register for aa
-- svare paa - «var det en fastloennet butikksjef her i mars?» - og
-- teller deretter ALLE timer uten unntak. Timeloennet butikksjef faar
-- rammen justert opp OG timene sine talt. Da gaar det opp naar hun
-- jobber et aarsverk, og vises naar hun jobber mer.
--
-- PERMISJON OG VIKARIAT FALLER UT AV SEG SELV. En butikksjef som er
-- fastloennet men i permisjon, er ikke paa plass: arbeidet hennes maa
-- gjores av noen andre fra den variable rammen. Da er svaret «nei» de
-- maanedene, uansett hva hun staar som paa papiret. Spoersmaalet er
-- ikke hva slags kontrakt hun har - det er om rammen daekker arbeidet.
-- =====================================================================

create table if not exists public.bemanning_lederdekning (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ar            int  not null check (ar between 2020 and 2100),
  maned         int  not null check (maned between 1 and 12),
  -- true  = fastloennet butikksjef paa plass og i arbeid. Fratrekket
  --         St1 gjorde er riktig, rammen staar.
  -- false = ingen. Timeloennet, permisjon, vikariat, vakanse - grunnen
  --         spiller ingen rolle, konsekvensen er den samme.
  fastlonnet    boolean not null,
  -- Hvorfor, for den som leser dette om et aar. «Sissel paa timeloenn»,
  -- «Bjoern i pappaperm». Ingenting kobles paa den.
  notat         text,
  oppdatert_av  uuid references auth.users(id) on delete set null,
  oppdatert_tid timestamptz not null default now(),
  unique (stasjon_id, ar, maned)
);

create index if not exists lederdekning_oppslag_idx
  on public.bemanning_lederdekning (stasjon_id, ar, maned);

comment on table public.bemanning_lederdekning is
  'En hake per stasjon per maaned: var det en fastloennet butikksjef '
  'paa plass? Nei betyr at St1s fratrekk paa ett aarsverk ikke holder, '
  'og at rammen justeres opp med 1/12 av det for den maaneden. '
  'Permisjon og vikariat er «nei» - spoersmaalet er om rammen daekker '
  'arbeidet, ikke hva slags kontrakt noen har.';
comment on column public.bemanning_lederdekning.fastlonnet is
  'INGEN RAD = UKJENT, ikke «ja». Viewet justerer ikke, og sier fra at '
  'maaneden er uavklart. En tom konfigurasjon skal se tom ut.';

alter table public.bemanning_lederdekning enable row level security;

-- EIER-ONLY. Butikksjefen skal ikke kunne utvide sin egen ramme.
-- Delt i select/insert/update/delete og ikke `for all`: USING i en
-- `for all`-policy gjelder ogsaa SELECT, og permissive policyer OR-es
-- sammen - da trekkes skrivepolicyen inn i hver leseplan.
drop policy if exists lederdekning_les on public.bemanning_lederdekning;
create policy lederdekning_les on public.bemanning_lederdekning
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists lederdekning_ny on public.bemanning_lederdekning;
create policy lederdekning_ny on public.bemanning_lederdekning
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists lederdekning_endre on public.bemanning_lederdekning;
create policy lederdekning_endre on public.bemanning_lederdekning
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin')
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists lederdekning_slett on public.bemanning_lederdekning;
create policy lederdekning_slett on public.bemanning_lederdekning
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete
  on public.bemanning_lederdekning to authenticated;
