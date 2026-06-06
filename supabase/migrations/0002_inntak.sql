-- =====================================================================
-- Sentiqa — Datainntak (PROSJEKT.md §16 steg 2, §6)
-- Dataens reise ledd 1–2: Inntak (rått mottak, lynraskt) + Prosessering (kø).
-- Format-uavhengig: tabellene her vet ingenting om St1/Visma-kolonner — det
-- kommer i parser-laget. Idempotent. retailer_id + slettet_tid overalt.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
do $$ begin
  create type public.mottakskanal as enum ('epost', 'drop_zone');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.importstatus as enum (
    'mottatt',    -- rå fil lagret, venter på arbeider
    'behandler',  -- arbeider plukket jobben
    'parset',     -- ferdig, data upsertet
    'feilet'      -- feilet (se feilmelding); kan retry-es
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.rapporttype as enum (
    'st1_salgsstatistikk',   -- daglig, produktnivå (§6)
    'st1_salesperhour',      -- 0758 salg pr time
    'st1_cashierstats',      -- 0018 kassererstatistikk
    'salesgrid_varetrans',   -- kasse-svinn (synlig)
    'visma_resultat',        -- månedlig regnskap
    'ukjent'                 -- ikke gjenkjent ennå
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- raa_filer — rått mottak (§2 ledd 1). Ingen parsing her.
-- ---------------------------------------------------------------------
create table if not exists public.raa_filer (
  id             uuid primary key default gen_random_uuid(),
  retailer_id    uuid not null references public.retailers(id) on delete restrict,
  filnavn        text not null,
  storage_bucket text not null default 'raa-filer',
  storage_sti    text not null,                 -- {retailer_id}/{uuid}-{filnavn}
  mottakskanal   public.mottakskanal not null,
  avsender       text,                           -- e-postavsender (null for drop_zone)
  storrelse_bytes bigint,
  sha256         text,                           -- dedup av identiske filer
  opprettet_tid  timestamptz not null default now(),
  slettet_tid    timestamptz
);
create index if not exists raa_filer_retailer_idx on public.raa_filer (retailer_id);
-- Samme fil (identisk innhold) skal ikke lagres to ganger per tenant
create unique index if not exists raa_filer_sha_unik
  on public.raa_filer (retailer_id, sha256) where sha256 is not null and slettet_tid is null;

-- ---------------------------------------------------------------------
-- import_jobber — prosesseringskø/status (§2 ledd 2, §6 import-status)
-- ---------------------------------------------------------------------
create table if not exists public.import_jobber (
  id            uuid primary key default gen_random_uuid(),
  raa_fil_id    uuid not null references public.raa_filer(id) on delete cascade,
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  rapporttype   public.rapporttype not null default 'ukjent',
  status        public.importstatus not null default 'mottatt',
  stasjon_id    uuid references public.stasjoner(id) on delete set null, -- matchet stasjon (§6)
  gjelder_dato  date,                            -- hvilken dato/periode filen dekker
  forsok        integer not null default 0,      -- antall forsøk (retry)
  feilmelding   text,
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now(),
  parset_tid    timestamptz
);
create index if not exists import_jobber_retailer_idx on public.import_jobber (retailer_id);
create index if not exists import_jobber_status_idx on public.import_jobber (status);
create index if not exists import_jobber_stasjon_idx on public.import_jobber (stasjon_id);

-- Hold oppdatert_tid fersk
create or replace function public.sett_oppdatert_tid()
returns trigger language plpgsql as $$
begin
  new.oppdatert_tid := now();
  return new;
end $$;

drop trigger if exists import_jobber_oppdatert on public.import_jobber;
create trigger import_jobber_oppdatert
  before update on public.import_jobber
  for each row execute function public.sett_oppdatert_tid();

-- ---------------------------------------------------------------------
-- RLS — import-status er tenant-data (§3). Admin ser alt eget; butikksjef
-- ser jobber for sine stasjoner. Arbeideren (service_role) omgår RLS.
-- ---------------------------------------------------------------------
alter table public.raa_filer    enable row level security;
alter table public.import_jobber enable row level security;

-- raa_filer: admin i egen tenant (rå filer er admin-nivå).
drop policy if exists raa_filer_admin on public.raa_filer;
create policy raa_filer_admin on public.raa_filer for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

-- import_jobber: admin ser/skriver alt eget; butikksjef LESER jobber for tildelte stasjoner.
drop policy if exists import_jobber_admin on public.import_jobber;
create policy import_jobber_admin on public.import_jobber for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

drop policy if exists import_jobber_sjef_les on public.import_jobber;
create policy import_jobber_sjef_les on public.import_jobber for select to authenticated
  using (stasjon_id is not null and public.har_stasjonstilgang(stasjon_id));

-- ---------------------------------------------------------------------
-- Storage-bucket for rå filer (privat) + RLS på objektene.
-- Filer ligger under {retailer_id}/... → tenant-isolasjon også i Storage.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('raa-filer', 'raa-filer', false)
on conflict (id) do nothing;

drop policy if exists raa_filer_storage_admin on storage.objects;
create policy raa_filer_storage_admin on storage.objects for all to authenticated
  using (
    bucket_id = 'raa-filer'
    and public.gjeldende_rolle() = 'retailer_admin'
    and (storage.foldername(name))[1] = public.gjeldende_retailer_id()::text
  )
  with check (
    bucket_id = 'raa-filer'
    and public.gjeldende_rolle() = 'retailer_admin'
    and (storage.foldername(name))[1] = public.gjeldende_retailer_id()::text
  );

-- ---------------------------------------------------------------------
-- Privilegier
-- ---------------------------------------------------------------------
grant select, insert, update, delete
  on public.raa_filer, public.import_jobber
  to authenticated;
