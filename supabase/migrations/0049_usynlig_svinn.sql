-- =====================================================================
-- Sentiqa - Usynlig svinn pr stasjon/produkt (fra regnskapsfila, kol "Usynlig").
-- Fortegn: + = manko (penger borte), - = overskudd (oftest feilslag/registrering).
-- Mater admin-regnskapsanalysen (kryss-stasjon-monstre). Kun eier (SS8C).
-- =====================================================================
create table if not exists public.regnskap_usynlig_svinn (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid references public.stasjoner(id) on delete cascade,
  periode       date not null,
  kode          text,
  navn          text not null,
  salg          numeric,
  brf_pst       numeric,
  usynlig_kr    numeric,   -- + manko, - overskudd
  usynlig_pst   numeric,
  kilde_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists usynlig_svinn_retailer_periode_idx on public.regnskap_usynlig_svinn (retailer_id, periode);

alter table public.regnskap_usynlig_svinn enable row level security;

drop policy if exists usynlig_svinn_les on public.regnskap_usynlig_svinn;
create policy usynlig_svinn_les on public.regnskap_usynlig_svinn for select to authenticated
  using (slettet_tid is null and public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id());

drop policy if exists usynlig_svinn_skriv on public.regnskap_usynlig_svinn;
create policy usynlig_svinn_skriv on public.regnskap_usynlig_svinn for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.regnskap_usynlig_svinn to authenticated;
