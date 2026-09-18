-- 0230 - tilbudsforespørsler, tilbud og avtaler.
-- Plattformdata: kun plattform_redaktor. Offentlig innsending går gjennom en
-- server-endpoint som validerer og skriver med service-klienten.
create table if not exists public.tilbudsforesporsler (
  id uuid primary key default gen_random_uuid(),
  virksomhet text not null,
  org_nr text,
  kontaktperson text not null,
  epost text not null,
  telefon text not null,
  antall_stasjoner integer not null check (antall_stasjoner > 0),
  retailer_limit integer not null default 1 check (retailer_limit >= 0),
  butikksjef_limit integer not null default 0 check (butikksjef_limit >= 0),
  tablet_station_limit integer not null default 0 check (tablet_station_limit >= 0),
  onsket_oppstart date,
  kommentar text,
  samtykke boolean not null default false check (samtykke),
  status text not null default 'ny' check (status in ('ny','kontaktet','tilbud_klargjoeres','tilbud_sendt','akseptert','avslatt','utloopt')),
  spam_nokkel text,
  epost_status text not null default 'ikke_sendt',
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now()
);
create index if not exists tilbudsforesporsler_status_idx on public.tilbudsforesporsler(status, opprettet_tid desc);

create table if not exists public.tilbud (
  id uuid primary key default gen_random_uuid(),
  foresporsel_id uuid not null unique references public.tilbudsforesporsler(id) on delete restrict,
  retailer_id uuid references public.retailers(id) on delete restrict,
  retailer_limit integer not null default 1 check (retailer_limit >= 0),
  butikksjef_limit integer not null default 0 check (butikksjef_limit >= 0),
  tablet_station_limit integer not null default 0 check (tablet_station_limit >= 0),
  maanedspris_kr integer,
  rabatt_kr integer not null default 0,
  oppstartsgebyr_kr integer not null default 0,
  trial_maaneder integer not null default 2 check (trial_maaneder >= 0),
  binding_maaneder integer not null default 12 check (binding_maaneder >= 0),
  trial_starts_at date,
  trial_ends_at date,
  first_payment_date date,
  commitment_starts_at date,
  commitment_ends_at date,
  offer_expires_at date,
  accepted_at timestamptz,
  accepted_by text,
  acceptance_reference text,
  activated_at timestamptz,
  spesielle_vilkaar text,
  dokument_url text,
  status text not null default 'utkast' check (status in ('utkast','sendt','akseptert','utloopt','aktivert','pauset','avsluttet')),
  opprettet_tid timestamptz not null default now(),
  oppdatert_tid timestamptz not null default now()
);

create table if not exists public.avtale_revisjon (
  id uuid primary key default gen_random_uuid(),
  tilbud_id uuid not null references public.tilbud(id) on delete restrict,
  utfort_av uuid,
  handling text not null,
  endringer jsonb not null default '{}'::jsonb,
  opprettet_tid timestamptz not null default now()
);
create table if not exists public.tilbudsforesporsel_revisjon (
  id uuid primary key default gen_random_uuid(),
  foresporsel_id uuid not null references public.tilbudsforesporsler(id) on delete restrict,
  utfort_av uuid,
  handling text not null,
  endringer jsonb not null default '{}'::jsonb,
  opprettet_tid timestamptz not null default now()
);

alter table public.tilbudsforesporsler enable row level security;
alter table public.tilbud enable row level security;
alter table public.avtale_revisjon enable row level security;
alter table public.tilbudsforesporsel_revisjon enable row level security;
drop policy if exists tilbudsforesporsler_plattform on public.tilbudsforesporsler;
drop policy if exists tilbudsforesporsler_plattform_select on public.tilbudsforesporsler;
drop policy if exists tilbudsforesporsler_plattform_insert on public.tilbudsforesporsler;
drop policy if exists tilbudsforesporsler_plattform_update on public.tilbudsforesporsler;
drop policy if exists tilbudsforesporsler_plattform_delete on public.tilbudsforesporsler;
create policy tilbudsforesporsler_plattform_select on public.tilbudsforesporsler for select to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsler_plattform_insert on public.tilbudsforesporsler for insert to authenticated with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsler_plattform_update on public.tilbudsforesporsler for update to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor') with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsler_plattform_delete on public.tilbudsforesporsler for delete to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
drop policy if exists tilbud_plattform on public.tilbud;
drop policy if exists tilbud_plattform_select on public.tilbud;
drop policy if exists tilbud_plattform_insert on public.tilbud;
drop policy if exists tilbud_plattform_update on public.tilbud;
drop policy if exists tilbud_plattform_delete on public.tilbud;
create policy tilbud_plattform_select on public.tilbud for select to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbud_plattform_insert on public.tilbud for insert to authenticated with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbud_plattform_update on public.tilbud for update to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor') with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbud_plattform_delete on public.tilbud for delete to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
drop policy if exists avtale_revisjon_plattform on public.avtale_revisjon;
drop policy if exists avtale_revisjon_plattform_select on public.avtale_revisjon;
drop policy if exists avtale_revisjon_plattform_insert on public.avtale_revisjon;
drop policy if exists avtale_revisjon_plattform_update on public.avtale_revisjon;
drop policy if exists avtale_revisjon_plattform_delete on public.avtale_revisjon;
create policy avtale_revisjon_plattform_select on public.avtale_revisjon for select to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy avtale_revisjon_plattform_insert on public.avtale_revisjon for insert to authenticated with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy avtale_revisjon_plattform_update on public.avtale_revisjon for update to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor') with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy avtale_revisjon_plattform_delete on public.avtale_revisjon for delete to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
drop policy if exists tilbudsforesporsel_revisjon_plattform on public.tilbudsforesporsel_revisjon;
drop policy if exists tilbudsforesporsel_revisjon_plattform_select on public.tilbudsforesporsel_revisjon;
drop policy if exists tilbudsforesporsel_revisjon_plattform_insert on public.tilbudsforesporsel_revisjon;
drop policy if exists tilbudsforesporsel_revisjon_plattform_update on public.tilbudsforesporsel_revisjon;
drop policy if exists tilbudsforesporsel_revisjon_plattform_delete on public.tilbudsforesporsel_revisjon;
create policy tilbudsforesporsel_revisjon_plattform_select on public.tilbudsforesporsel_revisjon for select to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsel_revisjon_plattform_insert on public.tilbudsforesporsel_revisjon for insert to authenticated with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsel_revisjon_plattform_update on public.tilbudsforesporsel_revisjon for update to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor') with check ((select public.gjeldende_rolle()) = 'plattform_redaktor');
create policy tilbudsforesporsel_revisjon_plattform_delete on public.tilbudsforesporsel_revisjon for delete to authenticated using ((select public.gjeldende_rolle()) = 'plattform_redaktor');
grant select, insert, update, delete on public.tilbudsforesporsler, public.tilbud, public.avtale_revisjon, public.tilbudsforesporsel_revisjon to authenticated;
revoke all on public.tilbudsforesporsler, public.tilbud, public.avtale_revisjon, public.tilbudsforesporsel_revisjon from anon;
