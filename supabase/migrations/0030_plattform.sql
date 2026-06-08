-- =====================================================================
-- Sentiqa — Plattform-innlegg (PROSJEKT.md §3 plattform-redaktør)
-- Sentiqa publiserer nyheter/kampanjer/beste praksis til ALLE kjeder.
-- Plattform-globalt (ingen retailer_id). Redaktøren skriver; alle innloggede
-- ser publiserte. Redaktøren leser aldri forretningsdata (§3).
-- =====================================================================
create table if not exists public.plattform_innlegg (
  id            uuid primary key default gen_random_uuid(),
  tittel        text not null,
  innhold       text not null,
  publisert     boolean not null default false,
  publisert_tid timestamptz,
  forfatter     uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz
);
create index if not exists plattform_innlegg_publisert_idx on public.plattform_innlegg (publisert, publisert_tid);

alter table public.plattform_innlegg enable row level security;

-- Alle innloggede ser publiserte; redaktøren ser også utkast.
drop policy if exists plattform_les on public.plattform_innlegg;
create policy plattform_les on public.plattform_innlegg for select to authenticated
  using (slettet_tid is null and (publisert or public.gjeldende_rolle() = 'plattform_redaktor'));

-- Kun plattform-redaktør skriver.
drop policy if exists plattform_skriv on public.plattform_innlegg;
create policy plattform_skriv on public.plattform_innlegg for all to authenticated
  using (public.gjeldende_rolle() = 'plattform_redaktor')
  with check (public.gjeldende_rolle() = 'plattform_redaktor');

grant select, insert, update, delete on public.plattform_innlegg to authenticated;
