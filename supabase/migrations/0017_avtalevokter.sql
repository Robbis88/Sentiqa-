-- =====================================================================
-- Sentiqa — Premium: Avtalevokter (PROSJEKT.md §11)
-- Fakturaer leses med AI-vision → forbruksprofil per leverandør på tvers av
-- stasjoner. Eier-nivå (premium). RLS: kun eier. Filer i privat Storage.
-- =====================================================================
create table if not exists public.fakturaer (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid references public.stasjoner(id) on delete set null,
  leverandor    text,
  kategori      text,
  faktura_dato  date,
  belop_kr      numeric,
  beskrivelse   text,
  storage_sti   text,
  parsedata     jsonb,
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists fakturaer_retailer_leverandor_idx on public.fakturaer (retailer_id, leverandor);

alter table public.fakturaer enable row level security;

drop policy if exists fakturaer_eier on public.fakturaer;
create policy fakturaer_eier on public.fakturaer for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.fakturaer to authenticated;

-- Privat Storage-bucket for fakturafiler (tenant-mappe, kun eier).
insert into storage.buckets (id, name, public)
values ('fakturaer', 'fakturaer', false)
on conflict (id) do nothing;

drop policy if exists fakturaer_storage_eier on storage.objects;
create policy fakturaer_storage_eier on storage.objects for all to authenticated
  using (
    bucket_id = 'fakturaer'
    and public.gjeldende_rolle() = 'retailer_admin'
    and (storage.foldername(name))[1] = public.gjeldende_retailer_id()::text
  )
  with check (
    bucket_id = 'fakturaer'
    and public.gjeldende_rolle() = 'retailer_admin'
    and (storage.foldername(name))[1] = public.gjeldende_retailer_id()::text
  );
