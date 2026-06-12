-- =====================================================================
-- Sentiqa - Produksjonsplan: per-stasjon vaerfolsomhet + arrangementer
-- (Brann-kamp o.l.) som egen faktor i forslaget.
-- =====================================================================
alter table public.stasjoner
  add column if not exists vaerfolsomhet numeric not null default 0.5
    check (vaerfolsomhet >= 0 and vaerfolsomhet <= 1);

create table if not exists public.arrangementer (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid references public.stasjoner(id) on delete cascade, -- null = alle stasjoner
  dato          date not null,
  navn          text not null,
  faktor        numeric not null default 1.2 check (faktor > 0 and faktor <= 5),
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists arrangementer_retailer_dato_idx on public.arrangementer (retailer_id, dato);

alter table public.arrangementer enable row level security;

drop policy if exists arrangementer_les on public.arrangementer;
create policy arrangementer_les on public.arrangementer for select to authenticated
  using (slettet_tid is null and retailer_id = public.gjeldende_retailer_id());

drop policy if exists arrangementer_skriv on public.arrangementer;
create policy arrangementer_skriv on public.arrangementer for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.arrangementer to authenticated;
