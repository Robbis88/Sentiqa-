-- =====================================================================
-- Sentiqa — Puls v2: runde-basert pulsmåling (PROSJEKT.md engasjement)
-- Spørsmålsbibliotek → runder (ett spørsmål, periode) → svar (skala 1–5).
-- Spørsmål + runder leses av alle i tenant (tableten trenger spørsmålet);
-- svar leses kun av leder (anonymitet). All skriving via admin/butikksjef.
-- =====================================================================
create table if not exists public.puls_sporsmal (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  kategori      text not null default 'Trivsel',
  tekst         text not null,
  aktiv         boolean not null default true,
  sortering     int not null default 0,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists puls_sporsmal_retailer_idx on public.puls_sporsmal (retailer_id);

create table if not exists public.puls_runde (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  sporsmal_id   uuid not null references public.puls_sporsmal(id) on delete cascade,
  start_dato    date not null,
  slutt_dato    date not null,
  status        text not null default 'aktiv' check (status in ('aktiv', 'avsluttet')),
  notat         text,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists puls_runde_retailer_idx on public.puls_runde (retailer_id, status);

-- Utvid svar-tabellen til runde-modellen (gamle humør/dato-kolonner gjøres valgfrie).
alter table public.puls_svar add column if not exists runde_id uuid references public.puls_runde(id) on delete cascade;
alter table public.puls_svar add column if not exists skala int;
alter table public.puls_svar add column if not exists ansatt_navn text;
alter table public.puls_svar alter column humor drop not null;
alter table public.puls_svar alter column dato drop not null;
do $$ begin
  alter table public.puls_svar add constraint puls_svar_skala_sjekk check (skala is null or skala between 1 and 5);
exception when duplicate_object then null; end $$;
-- Full (ikke-partiell) unik indeks → gyldig ON CONFLICT-mål. NULL-ansatt
-- (anonym) regnes som distinkt, så flere anonyme svar er greit.
create unique index if not exists puls_svar_runde_ansatt on public.puls_svar (runde_id, ansatt_id);

alter table public.puls_sporsmal enable row level security;
alter table public.puls_runde    enable row level security;

-- Spørsmål + runder leses av alle i tenant; kun leder skriver.
drop policy if exists puls_sporsmal_les on public.puls_sporsmal;
create policy puls_sporsmal_les on public.puls_sporsmal for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists puls_sporsmal_skriv on public.puls_sporsmal;
create policy puls_sporsmal_skriv on public.puls_sporsmal for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

drop policy if exists puls_runde_les on public.puls_runde;
create policy puls_runde_les on public.puls_runde for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());
drop policy if exists puls_runde_skriv on public.puls_runde;
create policy puls_runde_skriv on public.puls_runde for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.puls_sporsmal to authenticated;
grant select, insert, update, delete on public.puls_runde to authenticated;
