-- =====================================================================
-- Sentiqa - Kalender-kilder (iCal) -> arrangement-FORSLAG.
-- Lederen limer inn en .ics-URL (kampoppsett, festivaler, lokale kalendere).
-- Nattjobben henter den og lager arrangementer med status='forslag'. Lederen
-- bekrefter og setter faktor -- vi loefter aldri en plan paa noe ubekreftet.
-- =====================================================================

create table if not exists public.kalender_kilder (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete restrict,
  stasjon_id      uuid references public.stasjoner(id) on delete cascade, -- null = alle stasjoner
  navn            text not null,
  ical_url        text not null,
  standard_faktor numeric not null default 1.2 check (standard_faktor > 0 and standard_faktor <= 5),
  aktiv           boolean not null default true,
  opprettet_av    uuid references auth.users(id) on delete set null,
  opprettet_tid   timestamptz not null default now(),
  slettet_tid     timestamptz
);
create index if not exists kalender_kilder_retailer_idx on public.kalender_kilder (retailer_id);

alter table public.kalender_kilder enable row level security;

drop policy if exists kalender_kilder_les on public.kalender_kilder;
create policy kalender_kilder_les on public.kalender_kilder for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());

drop policy if exists kalender_kilder_skriv on public.kalender_kilder;
create policy kalender_kilder_skriv on public.kalender_kilder for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.kalender_kilder to authenticated;

-- Arrangementer: forslag/bekreftet + kobling til kilde (dedup ved re-import).
-- Eksisterende rader blir 'bekreftet' (de er manuelt lagt inn).
alter table public.arrangementer
  add column if not exists status      text not null default 'bekreftet'
    check (status in ('forslag', 'bekreftet')),
  add column if not exists kilde_id    uuid references public.kalender_kilder(id) on delete set null,
  add column if not exists ekstern_uid text;

-- (kilde_id, ekstern_uid) unik for dedup. Manuelle rader har begge null;
-- Postgres regner null som distinkt, saa de blokkeres ikke.
create unique index if not exists arrangementer_kilde_uid_idx
  on public.arrangementer (kilde_id, ekstern_uid);
