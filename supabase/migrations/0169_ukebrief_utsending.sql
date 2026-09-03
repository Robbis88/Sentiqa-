-- =====================================================================
-- UKEBRIEFEN: HVEM FIKK HVA, OG NAAR
--
-- Uten en logg er en ukentlig utsending umulig aa kjoere trygt. Feiler
-- jobben halvveis, finnes det ingen maate aa vite hvem som allerede har
-- faatt brevet - og valget staar da mellom aa sende alt paa nytt (noen
-- faar det to ganger) eller ikke sende noe (noen faar det aldri).
--
-- Denne tabellen gjoer det til et ikke-valg.
--
-- ---------------------------------------------------------------------
-- DUPLIKATSPERREN GJELDER BARE DET SOM FAKTISK GIKK UT
--
-- En full `unique (stasjon_id, uke_mandag, profil_id)` ville laast igjen
-- ogsaa de FEILEDE forsoekene, og da kunne en midlertidig feil hos Resend
-- aldri forsoekes paa nytt: raden staar i veien for sin egen retry.
--
-- Derfor en PARTIELL unik indeks `where status = 'sendt'`. Et vellykket
-- brev kan aldri sendes to ganger; et feilet kan forsoekes saa mange
-- ganger som noedvendig, og hvert forsoek staar igjen som spor.
--
-- ---------------------------------------------------------------------
-- INGEN E-POSTADRESSE HER
--
-- Bare `profil_id`. Adressen bor i `auth.users`, og aa kopiere den inn i
-- en driftslogg ville spredt persondata til et sted til uten aa loese
-- noe: mottakeren er identifisert av profilen, og adressen slaas opp naar
-- brevet faktisk skal sendes.
--
-- ---------------------------------------------------------------------
-- INGEN MENNESKEROLLE SKRIVER HER
--
-- Jobben skriver som service_role. Samme moenster som `prognose_treff`
-- (0069) og `trafikk`: en logg som kan redigeres i ettertid er ikke en
-- logg. Derfor finnes BARE en select-policy - fravaeret av de andre er
-- en beslutning, ikke en forglemmelse, og tenantmatrisen beviser det.
--
-- Idempotent: `if not exists` / `drop policy if exists` / ingen uvaktede
-- oppdateringer.
-- =====================================================================

create table if not exists public.ukebrief_utsending (
  id            uuid primary key default gen_random_uuid(),
  -- `retailer_id` staar her selv om den kan utledes av stasjonen. RLS
  -- trenger et sargbart predikat; `stasjon_id in (mine_stasjoner())` kan
  -- aldri bli initplan, og tabellen vokser med hver uke og hver stasjon.
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  -- Mandagen i uken brevet handlet OM - ikke dagen det ble sendt.
  uke_mandag    date not null,
  profil_id     uuid not null references public.profiler(id) on delete cascade,
  status        text not null check (status in ('sendt', 'feilet')),
  -- Resend sin id, saa en enkelt sending kan spores hos leverandoeren.
  ekstern_id    text,
  -- Kun satt naar status = 'feilet'. Meldingen fra leverandoeren, ordrett.
  feil          text,
  sendt_tid     timestamptz not null default now()
);

-- SPERREN. Se toppen: bare vellykkede sendinger er unike.
create unique index if not exists ukebrief_utsending_en_gang
  on public.ukebrief_utsending (stasjon_id, uke_mandag, profil_id)
  where status = 'sendt';

-- Oppslaget jobben gjoer foerst: hvem har alt faatt denne uken?
create index if not exists ukebrief_utsending_uke_idx
  on public.ukebrief_utsending (retailer_id, uke_mandag);

comment on table public.ukebrief_utsending is
  'Logg over sendte ukebriefer. Duplikatsperren er partiell og gjelder '
  'bare status = sendt, saa et feilet forsoek kan gjentas. Skrives kun '
  'av service_role; ingen menneskerolle har insert/update/delete.';

-- ---------------------------------------------------------------------
-- RETTIGHETER
--
-- `revoke ... from anon` er ikke overfloedig: Supabase-standarden
-- `alter default privileges ... grant all on tables to anon` treffer hver
-- nye tabell, og `anon` er rollen bak den offentlige noekkelen i hver
-- sidelast. Se `0134`.
-- ---------------------------------------------------------------------
revoke all on public.ukebrief_utsending from anon, authenticated;
grant select on public.ukebrief_utsending to authenticated;
grant all    on public.ukebrief_utsending to service_role;

alter table public.ukebrief_utsending enable row level security;

-- EIERENS LOGG. Den svarer paa «gikk brevene ut i morges?», som er et
-- driftsspoersmaal for kjeden. Butikksjefen har brevet sitt; hun har
-- ingen bruk for aa se at det ble sendt.
--
-- ALDRI `for all`: `using` i en `for all`-policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen - en skrivepolicy ville blitt trukket
-- inn i leseplanen og gjort `retailer_id` ikke-sargbar.
--
-- Funksjonskallene er pakket i `(select ...)` saa de evalueres en gang
-- som initplan, ikke per rad.
drop policy if exists ukebrief_utsending_les on public.ukebrief_utsending;
create policy ukebrief_utsending_les on public.ukebrief_utsending
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');
