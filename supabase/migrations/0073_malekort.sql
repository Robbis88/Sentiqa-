-- =====================================================================
-- Sentiqa — Målekort (PROSJEKT.md §7/§14): admin-definerte KPI-er for
-- butikk-mot-butikk-måling INNEN eget cluster. Tenant-isolasjon via RLS
-- (retailer_id) → en kjede ser aldri en annen kjedes stasjoner.
--
-- malekort       = definisjonen (metrikk + periode + synlighet + regler)
-- malekort_scope = hvilke varer/kategorier KPI-en måles på (0 rader = alt salg)
-- =====================================================================

create table if not exists public.malekort (
  id                     uuid primary key default gen_random_uuid(),
  retailer_id            uuid not null references public.retailers(id) on delete cascade,
  navn                   text not null,
  -- hva som måles
  metrikk                text not null
    check (metrikk in ('omsetning','antall','brutto','snittpris_kunde','snittbong','kunder')),
  -- rettferdig sammenligning (rå sum favoriserer store butikker)
  normalisering          text not null default 'per_kunde'
    check (normalisering in ('ra','per_kunde','vekst_pst')),
  periode                text not null default 'uke'
    check (periode in ('uke','maaned','rullende4uker')),
  retning                text not null default 'hoy' check (retning in ('hoy','lav')),
  -- Datakompletthet (§): et uke-/måned-målekort skal IKKE vises på en halv
  -- periode (halv uke i år mot full uke i fjor blir misvisende). Når på, viser
  -- vi kun siste FULLSTENDIGE periode der alle dager er lastet opp. Håndheves
  -- i motoren + tablet-kortet. Tablet skal aldri se en ufullstendig uke.
  krev_fullstendig_periode boolean not null default true,
  vis_butikksjef         boolean not null default true,
  vis_tablet             boolean not null default true,
  anonymiser             boolean not null default false,
  -- Krok for variant B (sammenlign kun samme stasjonstype). null = alle egne.
  stasjonstype_filter    text,
  sortering              int not null default 0,
  opprettet_tid          timestamptz not null default now(),
  slettet_tid            timestamptz
);

create index if not exists malekort_retailer_idx on public.malekort (retailer_id) where slettet_tid is null;

create table if not exists public.malekort_scope (
  id          uuid primary key default gen_random_uuid(),
  malekort_id uuid not null references public.malekort(id) on delete cascade,
  retailer_id uuid not null references public.retailers(id) on delete cascade,
  nivaa       text not null check (nivaa in ('avdeling','vareomrade','varegruppe','ean')),
  kode        text not null,
  navn        text
);
create index if not exists malekort_scope_kort_idx on public.malekort_scope (malekort_id);

-- ---------------------------------------------------------------------
-- RLS — admin styrer alt eget; butikksjef/tablet leser eget cluster
-- (visnings-flagg filtreres i spørringen, ikke i policyen).
-- ---------------------------------------------------------------------
alter table public.malekort enable row level security;
drop policy if exists malekort_admin on public.malekort;
create policy malekort_admin on public.malekort for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id());
drop policy if exists malekort_les on public.malekort;
create policy malekort_les on public.malekort for select to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and slettet_tid is null);

alter table public.malekort_scope enable row level security;
drop policy if exists malekort_scope_admin on public.malekort_scope;
create policy malekort_scope_admin on public.malekort_scope for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id());
drop policy if exists malekort_scope_les on public.malekort_scope;
create policy malekort_scope_les on public.malekort_scope for select to authenticated
  using (retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.malekort to authenticated;
grant select, insert, update, delete on public.malekort_scope to authenticated;

-- ---------------------------------------------------------------------
-- Oppslag for scope-velgeren. security_invoker → RLS på daglig_salg gjelder,
-- så admin kun ser sitt eget clusters kategorier/varer.
-- ---------------------------------------------------------------------
create or replace view public.v_varehierarki
with (security_invoker = true) as
select distinct
  retailer_id,
  avdeling_kode, avdeling_navn,
  vareomrade_kode, vareomrade_navn,
  varegruppe_kode, varegruppe_navn
from public.daglig_salg
where slettet_tid is null;
grant select on public.v_varehierarki to authenticated;

-- Distinkt vareliste for EAN-søk (én rad per vare, narrowes med ilike).
create or replace view public.v_varer
with (security_invoker = true) as
select distinct retailer_id, ean, varenavn, varegruppe_kode, varegruppe_navn
from public.daglig_salg
where slettet_tid is null and varenavn is not null;
grant select on public.v_varer to authenticated;
