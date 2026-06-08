-- =====================================================================
-- Sentiqa — IK-mat / internkontroll (PROSJEKT.md §16.5)
-- Digitale versjoner av St1-skjemaene: temperaturkontroll (kjøl/frys/oppvarming/
-- varmholding/skyllevann) + S01 Avviksskjema. Avvik mot kravene flagges og
-- varsles. RLS via stasjonstilgang; avlesning kan gjøres av alle med tilgang.
-- =====================================================================
create table if not exists public.ik_kontrollpunkter (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  navn          text not null,
  type          text not null default 'kjol'
                  check (type in ('kjol', 'frys', 'oppvarming', 'varmholding', 'skyllevann', 'annet')),
  min_temp      numeric,   -- nedre krav (oppvarming/varmholding/skyllevann)
  max_temp      numeric,   -- øvre krav (kjøl/frys)
  frekvens      text not null default 'daglig',  -- daglig | to_ukentlig | ukentlig
  sortering     int not null default 0,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists ik_kontrollpunkter_stasjon_idx on public.ik_kontrollpunkter (stasjon_id);

create table if not exists public.ik_avlesninger (
  id               uuid primary key default gen_random_uuid(),
  kontrollpunkt_id uuid not null references public.ik_kontrollpunkter(id) on delete cascade,
  stasjon_id       uuid not null references public.stasjoner(id) on delete cascade,
  dato             date not null,
  temperatur       numeric not null,
  innenfor         boolean not null,
  tiltak           text,
  avlest_av        uuid references auth.users(id) on delete set null,
  avlest_tid       timestamptz not null default now()
);
create index if not exists ik_avlesninger_punkt_dato_idx on public.ik_avlesninger (kontrollpunkt_id, dato);

-- S01 Avviksskjema
create table if not exists public.avvik (
  id               uuid primary key default gen_random_uuid(),
  retailer_id      uuid not null references public.retailers(id) on delete restrict,
  stasjon_id       uuid not null references public.stasjoner(id) on delete cascade,
  lopenr           int not null default 0,
  kategori         text not null default 'produkt' check (kategori in ('produkt', 'utstyr')),
  dato             date not null,
  beskrivelse      text not null,        -- avvik/reklamasjon + årsak
  strakstiltak     text,                 -- avviksbehandling
  korrigerende     text,                 -- forhindre gjentakelse
  frist            date,
  varslet_til      text,                 -- marked@/retail@st1.no, leverandør
  gjennomfort      boolean not null default false,
  gjennomfort_dato date,
  opprettet_av     uuid references auth.users(id) on delete set null,
  opprettet_tid    timestamptz not null default now(),
  slettet_tid      timestamptz
);
create index if not exists avvik_stasjon_idx on public.avvik (stasjon_id, gjennomfort);

alter table public.ik_kontrollpunkter enable row level security;
alter table public.ik_avlesninger     enable row level security;
alter table public.avvik              enable row level security;

drop policy if exists ik_punkter_les on public.ik_kontrollpunkter;
create policy ik_punkter_les on public.ik_kontrollpunkter for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));
drop policy if exists ik_punkter_skriv on public.ik_kontrollpunkter;
create policy ik_punkter_skriv on public.ik_kontrollpunkter for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists ik_avlesninger_les on public.ik_avlesninger;
create policy ik_avlesninger_les on public.ik_avlesninger for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));
drop policy if exists ik_avlesninger_skriv on public.ik_avlesninger;
create policy ik_avlesninger_skriv on public.ik_avlesninger for insert to authenticated
  with check (public.har_stasjonstilgang(stasjon_id));

drop policy if exists avvik_les on public.avvik;
create policy avvik_les on public.avvik for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));
drop policy if exists avvik_skriv on public.avvik;
create policy avvik_skriv on public.avvik for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id))
  with check (public.har_stasjonstilgang(stasjon_id));

grant select, insert, update, delete on public.ik_kontrollpunkter to authenticated;
grant select, insert, update, delete on public.ik_avlesninger to authenticated;
grant select, insert, update, delete on public.avvik to authenticated;
