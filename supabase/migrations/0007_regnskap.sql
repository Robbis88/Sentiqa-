-- =====================================================================
-- Sentiqa — Regnskapslinjer (PROSJEKT.md §8C, §16 steg 3)
-- Strukturert P&L fra den månedlige regnskapsrapporten (Azets m.fl.).
-- stasjon_id null = cluster-nivå. Idempotens: arbeideren sletter alt for
-- (retailer, periode) før innsetting (én rapport per periode). RLS som ellers.
-- =====================================================================
create table if not exists public.regnskapslinjer (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete restrict,
  stasjon_id      uuid references public.stasjoner(id) on delete restrict, -- null = cluster
  periode         date not null,                 -- første i måneden
  seksjon         text not null,                 -- omsetning|bruttofortjeneste|driftskostnader|resultat
  kode            text,                           -- regnskapskode, f.eks. '120'
  post            text not null,                  -- "120 Mat", "RESULTAT", …
  sortering       integer,
  regnskap        numeric,
  budsjett        numeric,
  avvik           numeric,
  index_pct       numeric,
  regnskap_hittil numeric,
  budsjett_hittil numeric,
  kilde_jobb_id   uuid references public.import_jobber(id) on delete set null,
  opprettet_tid   timestamptz not null default now(),
  slettet_tid     timestamptz
);
create index if not exists regnskapslinjer_retailer_periode_idx
  on public.regnskapslinjer (retailer_id, periode);

alter table public.regnskapslinjer enable row level security;

drop policy if exists regnskapslinjer_les on public.regnskapslinjer;
create policy regnskapslinjer_les on public.regnskapslinjer for select to authenticated
  using (
    slettet_tid is null and (
      (public.gjeldende_rolle() = 'retailer_admin'
       and retailer_id = public.gjeldende_retailer_id())
      or (stasjon_id is not null and public.har_stasjonstilgang(stasjon_id))
    )
  );

drop policy if exists regnskapslinjer_skriv on public.regnskapslinjer;
create policy regnskapslinjer_skriv on public.regnskapslinjer for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.regnskapslinjer to authenticated;
