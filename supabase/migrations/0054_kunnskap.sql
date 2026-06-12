-- =====================================================================
-- Sentiqa - Kunnskapsbase for AI-chatboten: rutiner, prosedyrer, HMS og
-- tariffavtale (Energistasjonsoverenskomsten + lonnssatser). Global kunnskap
-- (retailer_id null, f.eks. tariff) deles av alle; tenant-artikler er egne.
-- Norsk fulltekstsok via generert tsvector + GIN.
-- =====================================================================
create table if not exists public.kunnskap (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid references public.retailers(id) on delete cascade, -- null = global (tariff o.l.)
  kategori      text not null default 'rutine',  -- tariff|lonn|arbeidsrett|rutine|hms|prosedyre|annet
  tittel        text not null,
  innhold       text not null,
  kilde         text,                            -- f.eks. 'SS 5.2' eller 'Tariffsatser Energi 2025'
  opprettet_av  uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz,
  fts tsvector generated always as (to_tsvector('norwegian', coalesce(tittel, '') || ' ' || coalesce(innhold, ''))) stored
);
create index if not exists kunnskap_fts_idx on public.kunnskap using gin (fts);
create index if not exists kunnskap_retailer_idx on public.kunnskap (retailer_id);

alter table public.kunnskap enable row level security;

-- Les: global kunnskap (retailer_id null) + egen tenants artikler.
drop policy if exists kunnskap_les on public.kunnskap;
create policy kunnskap_les on public.kunnskap for select to authenticated
  using (slettet_tid is null and (retailer_id is null or retailer_id = public.gjeldende_retailer_id()));

-- Skriv: leder kan redigere EGEN tenants artikler (ikke global — den seedes
-- via service-role / migrasjon).
drop policy if exists kunnskap_skriv on public.kunnskap;
create policy kunnskap_skriv on public.kunnskap for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'))
  with check (retailer_id = public.gjeldende_retailer_id() and public.gjeldende_rolle() in ('retailer_admin', 'butikksjef'));

grant select, insert, update, delete on public.kunnskap to authenticated;
