-- =====================================================================
-- Sentiqa — Ansatte + PIN-logging (PROSJEKT.md §16.5)
-- Ansatte identifiserer seg med 4-sifret PIN på tablet (delt innlogging).
-- PIN lagres hashet. ansatt_id legges på drift-loggene for sporbarhet («hvem»).
-- Identifikasjon, ikke datasikkerhet — RLS styrer fortsatt all tilgang.
-- =====================================================================
create table if not exists public.ansatte (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  navn          text not null,
  pin_hash      text not null,
  aktiv         boolean not null default true,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists ansatte_stasjon_idx on public.ansatte (stasjon_id);
-- Unik PIN per kjede (så innsjekk er entydig blant aktive).
create unique index if not exists ansatte_pin_unik
  on public.ansatte (retailer_id, pin_hash) where aktiv and slettet_tid is null;

alter table public.rutine_utforinger add column if not exists ansatt_id uuid references public.ansatte(id) on delete set null;
alter table public.sjekkpunkt_svar  add column if not exists ansatt_id uuid references public.ansatte(id) on delete set null;
alter table public.ik_avlesninger   add column if not exists ansatt_id uuid references public.ansatte(id) on delete set null;

alter table public.ansatte enable row level security;

drop policy if exists ansatte_les on public.ansatte;
create policy ansatte_les on public.ansatte for select to authenticated
  using (slettet_tid is null and public.har_stasjonstilgang(stasjon_id));

drop policy if exists ansatte_skriv on public.ansatte;
create policy ansatte_skriv on public.ansatte for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.ansatte to authenticated;
