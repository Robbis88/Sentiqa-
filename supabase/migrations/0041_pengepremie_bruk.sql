-- =====================================================================
-- Sentiqa — Pengepremie-bruk (tablet «Premiesaldo»). Stasjonen registrerer
-- bruk av vunne pengepremier (julebord, gaver, utstyr). Saldo per stasjon =
-- sum(vunnet premie fra konkurranser) − sum(bruk). Multi-tenant.
-- =====================================================================
create table if not exists public.pengepremie_bruk (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  beskrivelse   text not null check (length(trim(beskrivelse)) > 0),
  belop_kr      numeric not null check (belop_kr > 0),
  dato          date not null default current_date,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now()
);
create index if not exists pengepremie_bruk_stasjon_idx on public.pengepremie_bruk (stasjon_id);

alter table public.pengepremie_bruk enable row level security;

drop policy if exists pengepremie_bruk_les on public.pengepremie_bruk;
create policy pengepremie_bruk_les on public.pengepremie_bruk for select to authenticated
  using (public.har_stasjonstilgang(stasjon_id));

drop policy if exists pengepremie_bruk_skriv on public.pengepremie_bruk;
create policy pengepremie_bruk_skriv on public.pengepremie_bruk for all to authenticated
  using (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (public.har_stasjonstilgang(stasjon_id) and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.pengepremie_bruk to authenticated;
