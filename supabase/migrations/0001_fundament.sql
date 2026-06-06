-- =====================================================================
-- Sentiqa — Fundament (PROSJEKT.md §16 steg 1)
-- Multi-tenancy: delt skjema + retailer_id + Row Level Security (§3).
-- Norsk bokmål i domenekode. slettet_tid (soft-delete) overalt (§18).
-- All tid i timestamptz; visning tvinges til Europe/Oslo i app-laget.
--
-- Idempotent: trygt å kjøre flere ganger.
-- service_role-nøkkelen omgår RLS (bakgrunnsarbeidere/onboarding) — bruk
-- den ALDRI i klient. authenticated/anon gates av policyene under.
-- =====================================================================

-- gen_random_uuid()
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
do $$ begin
  create type public.brukerrolle as enum (
    'retailer_admin',       -- eier: alt innenfor egen tenant
    'butikksjef',           -- tildelte stasjoner + valgte regnskapskoder
    'butikkbruker_tablet',  -- delt stasjonskonto, kun publisert innhold
    'plattform_redaktor'    -- over tenant-nivå, leser ALDRI forretningsdata
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stasjonstype as enum (
    'utfart','pendler','bydel','gjennomfart','sentrum'  -- §7
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- Tabeller
-- ---------------------------------------------------------------------

-- Tenant / cluster (§3, §4)
create table if not exists public.retailers (
  id            uuid primary key default gen_random_uuid(),
  navn          text not null,
  slug          text unique,                       -- white-label-identifikator
  org_nr        text,
  branding      jsonb not null default '{}'::jsonb, -- white-label per tenant (§3)
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);

-- Brukerprofil — utvider auth.users 1:1 (§5)
create table if not exists public.profiler (
  id            uuid primary key references auth.users(id) on delete cascade,
  retailer_id   uuid references public.retailers(id) on delete restrict,
  fullt_navn    text,
  rolle         public.brukerrolle not null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz,
  -- Plattform-redaktør står utenfor tenant; alle andre MÅ tilhøre én (§3)
  constraint profil_retailer_paakrevd check (
    (rolle  = 'plattform_redaktor' and retailer_id is null) or
    (rolle <> 'plattform_redaktor' and retailer_id is not null)
  )
);
create index if not exists profiler_retailer_idx on public.profiler (retailer_id);

-- Stasjoner (§3, §7, §8)
create table if not exists public.stasjoner (
  id                     uuid primary key default gen_random_uuid(),
  retailer_id            uuid not null references public.retailers(id) on delete restrict,
  butikknummer           text not null check (butikknummer ~ '^[0-9]{4}$'),
  navn                   text not null,
  stasjonstype           public.stasjonstype not null,
  stasjonstype_sekundaer public.stasjonstype,        -- virkeligheten er ofte miks (§7)
  svinnterskel_prosent   numeric(5,2),               -- §11 (Sentiqa foreslår fra historikk)
  opprettet_tid          timestamptz not null default now(),
  slettet_tid            timestamptz
);
create index if not exists stasjoner_retailer_idx on public.stasjoner (retailer_id);
-- Butikknummer unikt per tenant (vi binder til retailer_id uansett, §6)
create unique index if not exists stasjoner_retailer_butikknr_unik
  on public.stasjoner (retailer_id, butikknummer) where slettet_tid is null;

-- Hvilke stasjoner en butikksjef/tablet-bruker har (§3 tillatelser)
-- retailer_admin trenger ingen rader her — ser alle egne stasjoner implisitt.
create table if not exists public.butikksjef_stasjoner (
  profil_id     uuid not null references public.profiler(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  opprettet_tid timestamptz not null default now(),
  primary key (profil_id, stasjon_id)
);
create index if not exists butikksjef_stasjoner_stasjon_idx
  on public.butikksjef_stasjoner (stasjon_id);

-- ---------------------------------------------------------------------
-- Hjelpefunksjoner for RLS
-- SECURITY DEFINER → kjører som eier og omgår RLS på profiler, slik at
-- policyer på andre tabeller kan slå opp brukerens tenant uten rekursjon.
-- ---------------------------------------------------------------------
create or replace function public.gjeldende_retailer_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select retailer_id from public.profiler
  where id = auth.uid() and slettet_tid is null
$$;

create or replace function public.gjeldende_rolle()
returns public.brukerrolle
language sql stable security definer set search_path = public
as $$
  select rolle from public.profiler
  where id = auth.uid() and slettet_tid is null
$$;

create or replace function public.har_stasjonstilgang(p_stasjon uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case public.gjeldende_rolle()
    when 'retailer_admin' then exists (
      select 1 from public.stasjoner s
      where s.id = p_stasjon
        and s.retailer_id = public.gjeldende_retailer_id()
        and s.slettet_tid is null
    )
    when 'butikksjef' then exists (
      select 1 from public.butikksjef_stasjoner bs
      where bs.stasjon_id = p_stasjon and bs.profil_id = auth.uid()
    )
    when 'butikkbruker_tablet' then exists (
      select 1 from public.butikksjef_stasjoner bs
      where bs.stasjon_id = p_stasjon and bs.profil_id = auth.uid()
    )
    else false
  end
$$;

-- ---------------------------------------------------------------------
-- Row Level Security
-- Salgsløftet (§3): ingen ser på tvers av tenanter — heller ikke vi.
-- ---------------------------------------------------------------------
alter table public.retailers            enable row level security;
alter table public.profiler             enable row level security;
alter table public.stasjoner            enable row level security;
alter table public.butikksjef_stasjoner enable row level security;

-- retailers: kun egen tenant. Plattform-redaktør (retailer_id = null)
-- matcher ingenting → ser ingen forretningsdata (§3 strengt enveis).
drop policy if exists retailers_select on public.retailers;
create policy retailers_select on public.retailers for select to authenticated
  using (id = public.gjeldende_retailer_id() and slettet_tid is null);

drop policy if exists retailers_update on public.retailers;
create policy retailers_update on public.retailers for update to authenticated
  using (id = public.gjeldende_retailer_id() and public.gjeldende_rolle() = 'retailer_admin')
  with check (id = public.gjeldende_retailer_id() and public.gjeldende_rolle() = 'retailer_admin');
-- INSERT/DELETE av retailers skjer kun via service_role (onboarding) — omgår RLS.

-- profiler: ser seg selv; admin ser alle i egen tenant.
drop policy if exists profiler_select on public.profiler;
create policy profiler_select on public.profiler for select to authenticated
  using (
    id = auth.uid()
    or (public.gjeldende_rolle() = 'retailer_admin'
        and retailer_id = public.gjeldende_retailer_id())
  );

-- Bruker kan oppdatere egen profil, men ikke bytte tenant eller rolle
-- (det håndheves i app-laget/DAL; her gates skriving til egne rader + admin).
drop policy if exists profiler_update_selv on public.profiler;
create policy profiler_update_selv on public.profiler for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiler_admin_alt on public.profiler;
create policy profiler_admin_alt on public.profiler for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

-- stasjoner: admin ser alle egne; butikksjef/tablet ser tildelte.
drop policy if exists stasjoner_select on public.stasjoner;
create policy stasjoner_select on public.stasjoner for select to authenticated
  using (
    slettet_tid is null
    and (
      (public.gjeldende_rolle() = 'retailer_admin'
       and retailer_id = public.gjeldende_retailer_id())
      or public.har_stasjonstilgang(id)
    )
  );

-- Kun admin oppretter/endrer stasjoner, og kun i egen tenant.
drop policy if exists stasjoner_admin_skriv on public.stasjoner;
create policy stasjoner_admin_skriv on public.stasjoner for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

-- butikksjef_stasjoner: bruker ser egne koblinger; admin styrer i egen tenant.
drop policy if exists bs_select on public.butikksjef_stasjoner;
create policy bs_select on public.butikksjef_stasjoner for select to authenticated
  using (
    profil_id = auth.uid()
    or (public.gjeldende_rolle() = 'retailer_admin' and exists (
         select 1 from public.stasjoner s
         where s.id = stasjon_id
           and s.retailer_id = public.gjeldende_retailer_id()))
  );

drop policy if exists bs_admin_skriv on public.butikksjef_stasjoner;
create policy bs_admin_skriv on public.butikksjef_stasjoner for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and exists (
           select 1 from public.stasjoner s
           where s.id = stasjon_id
             and s.retailer_id = public.gjeldende_retailer_id()))
  with check (public.gjeldende_rolle() = 'retailer_admin' and exists (
           select 1 from public.stasjoner s
           where s.id = stasjon_id
             and s.retailer_id = public.gjeldende_retailer_id()));

-- ---------------------------------------------------------------------
-- Privilegier (RLS gater radene; rollen trenger fortsatt tabelltilgang)
-- ---------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete
  on public.retailers, public.profiler, public.stasjoner, public.butikksjef_stasjoner
  to authenticated;
grant execute on function
  public.gjeldende_retailer_id(),
  public.gjeldende_rolle(),
  public.har_stasjonstilgang(uuid)
  to authenticated;
