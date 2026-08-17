-- ---------------------------------------------------------------------
-- 0103: informasjonsplikt om kontrolltiltak, og tilgangslogg
-- ---------------------------------------------------------------------
-- To ting arbeidsmiljoloven og GDPR krever, og som systemet ikke kunne.
--
-- 1) aml. § 9-2 andre ledd: de som omfattes av et kontrolltiltak SKAL ha
--    informasjon om formaal, praktiske konsekvenser og antatt varighet.
--    Plikten er ubetinget - den gjelder ogsaa der det ikke finnes
--    tillitsvalgte aa droefte med.
--
--    Bekreftelsen er ikke et samtykke. Samtykke er sjelden gyldig i
--    arbeidsforhold, fordi den ansatte ikke staar fritt til aa si nei.
--    Dette er dokumentasjon paa at informasjonen ER GITT, og naar.
--
-- 2) GDPR art. 32: den som ser lonn, fodselsdato og sykefravaer om en
--    kollega skal kunne spores. Uten logg finnes det ikke noe svar naar
--    en ansatt spor «hvem har sett dette?».

-- ---------------------------------------------------------------------
create table if not exists public.kontrolltiltak_bekreftelse (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid references public.stasjoner(id) on delete cascade,
  -- Nettbrettidentitet ELLER innlogget bruker. Butikksjefer maales ogsaa,
  -- og de logger inn som seg selv, ikke med PIN.
  ansatt_id     uuid references public.ansatte(id) on delete cascade,
  bruker_id     uuid references auth.users(id) on delete cascade,
  -- Versjonen av teksten. Endres den vesentlig, ma folk se den paa nytt -
  -- en bekreftelse paa en tekst som senere ble endret dokumenterer
  -- ingenting.
  versjon       text not null,
  bekreftet_tid timestamptz not null default now(),
  check (ansatt_id is not null or bruker_id is not null)
);

create unique index if not exists kontrolltiltak_ansatt_unik
  on public.kontrolltiltak_bekreftelse (ansatt_id, versjon) where ansatt_id is not null;
create unique index if not exists kontrolltiltak_bruker_unik
  on public.kontrolltiltak_bekreftelse (bruker_id, versjon) where bruker_id is not null;

comment on table public.kontrolltiltak_bekreftelse is
  'Dokumentasjon paa at informasjonsplikten etter aml. § 9-2 er oppfylt. '
  'IKKE et samtykke - samtykke er sjelden gyldig i arbeidsforhold.';

-- ---------------------------------------------------------------------
create table if not exists public.persondata_logg (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid references public.stasjoner(id) on delete set null,
  -- Hvem oppslaget gjaldt. null naar handlingen gjelder hele stasjonen,
  -- som en lonnsfil.
  ansatt_nr     text,
  ansatt_navn   text,
  handling      text not null,
  bruker_id     uuid references auth.users(id) on delete set null,
  bruker_navn   text,
  detaljer      jsonb not null default '{}'::jsonb,
  tid           timestamptz not null default now()
);

create index if not exists persondata_logg_person_idx
  on public.persondata_logg (stasjon_id, ansatt_nr, tid desc);
create index if not exists persondata_logg_tid_idx
  on public.persondata_logg (retailer_id, tid desc);

comment on table public.persondata_logg is
  'Hvem har sett hva om hvem. Kan aldri endres eller slettes - en logg '
  'som lar seg redigere er ikke en logg.';

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.kontrolltiltak_bekreftelse enable row level security;
alter table public.persondata_logg            enable row level security;

drop policy if exists kontrolltiltak_les on public.kontrolltiltak_bekreftelse;
drop policy if exists kontrolltiltak_ins on public.kontrolltiltak_bekreftelse;

-- Alle kan se sin egen bekreftelse; ledere ser sine stasjoner. Uten det
-- forste kan ikke den ansatte selv sjekke hva hun har faatt vite.
create policy kontrolltiltak_les on public.kontrolltiltak_bekreftelse
  for select to authenticated
  using (
    bruker_id = (select auth.uid())
    or (stasjon_id in (select public.mine_stasjoner())
        and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  );

create policy kontrolltiltak_ins on public.kontrolltiltak_bekreftelse
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id()));

-- Ingen update- eller delete-policy: en bekreftelse skal staa.

drop policy if exists persondata_logg_les on public.persondata_logg;
drop policy if exists persondata_logg_ins on public.persondata_logg;

create policy persondata_logg_les on public.persondata_logg
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy persondata_logg_ins on public.persondata_logg
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and bruker_id = (select auth.uid()));

-- Ingen update- eller delete-policy, med vilje. En logg som lar seg
-- redigere av den som er logget, dokumenterer ingenting.

grant select, insert on public.kontrolltiltak_bekreftelse to authenticated;
grant select, insert on public.persondata_logg            to authenticated;
