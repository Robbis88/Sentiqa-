-- =====================================================================
-- Sentiqa — Tilbakemelding (tablet → butikksjef). «Send melding til sjef».
-- Alvorlighet: uhell / nestenuhell / generelt. Lest-sporing. Multi-tenant.
-- =====================================================================
-- uhell / nestenuhell / generelt + krenkelse (kunde mot ansatt)
do $$ begin
  create type public.alvorlighet_type as enum ('uhell', 'nestenuhell', 'generelt', 'krenkelse');
exception when duplicate_object then null; end $$;
alter type public.alvorlighet_type add value if not exists 'krenkelse';

create table if not exists public.tilbakemelding (
  id                    uuid primary key default gen_random_uuid(),
  retailer_id           uuid not null references public.retailers(id) on delete restrict,
  stasjon_id            uuid not null references public.stasjoner(id) on delete cascade,
  opprettet_av          uuid references auth.users(id) on delete set null,
  ansatt_id             uuid references public.ansatte(id) on delete set null,
  alvorlighet           public.alvorlighet_type not null default 'generelt',
  tekst                 text not null check (length(trim(tekst)) > 0),
  hendelse_tid          timestamptz,                 -- når hendelsen faktisk skjedde
  involvert_beskrivelse text,                          -- kort beskrivelse av kunden (kontekst)
  opprettet_tid         timestamptz not null default now(),
  lest_tid              timestamptz,
  lest_av               uuid references auth.users(id) on delete set null
);
create index if not exists tilbakemelding_stasjon_idx on public.tilbakemelding (stasjon_id, opprettet_tid desc);
create index if not exists tilbakemelding_ulest_idx on public.tilbakemelding (stasjon_id) where lest_tid is null;

alter table public.tilbakemelding enable row level security;

-- Lese: alle med stasjonstilgang.
drop policy if exists tilbakemelding_les on public.tilbakemelding;
create policy tilbakemelding_les on public.tilbakemelding for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

-- Opprette: alle med stasjonstilgang (også tablet).
drop policy if exists tilbakemelding_insert on public.tilbakemelding;
create policy tilbakemelding_insert on public.tilbakemelding for insert to authenticated
  with check (public.har_stasjonstilgang(stasjon_id));

-- Markere lest: eier/butikksjef (tablet blokkeres på rolle i app-laget).
drop policy if exists tilbakemelding_update on public.tilbakemelding;
create policy tilbakemelding_update on public.tilbakemelding for update to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.tilbakemelding to authenticated;
