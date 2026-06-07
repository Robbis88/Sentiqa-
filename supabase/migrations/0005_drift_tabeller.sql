-- =====================================================================
-- Sentiqa — Lagring for timesalg, kassererstatistikk og synlig svinn
-- (PROSJEKT.md §6, §11). Lavere volum enn daglig_salg → ikke partisjonert.
-- retailer_id + slettet_tid overalt. RLS som daglig_salg: admin ser alt eget,
-- butikksjef sine tildelte stasjoner. service_role (arbeider) omgår RLS.
-- =====================================================================

-- --- Timesalg (St1 0758) → heatmap/bemanning ---
create table if not exists public.timesalg (
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete restrict,
  dato          date not null,
  time          text not null,                 -- "0-1" … "23-24"
  salg          numeric,
  kostpris      numeric,
  mva           numeric,
  antall_varer  numeric,
  antall_kunder numeric,
  kilde_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  slettet_tid   timestamptz,
  primary key (retailer_id, stasjon_id, dato, time)
);

-- --- Kassererstatistikk (St1 0018) ---
create table if not exists public.kassererstatistikk (
  retailer_id       uuid not null references public.retailers(id) on delete restrict,
  stasjon_id        uuid not null references public.stasjoner(id) on delete restrict,
  dato              date not null,
  kasserer_nr       text not null,
  kasserer_navn     text,
  omsetning_ink_mva numeric,
  bonger            numeric,
  retur_antall      numeric,
  retur_belop       numeric,
  makulerte_antall  numeric,
  makulerte_belop   numeric,
  slettede_antall   numeric,
  slettede_belop    numeric,
  kilde_jobb_id     uuid references public.import_jobber(id) on delete set null,
  opprettet_tid     timestamptz not null default now(),
  slettet_tid       timestamptz,
  primary key (retailer_id, stasjon_id, dato, kasserer_nr)
);

-- --- Synlig svinn (St1 0452 Varetransaksjonsliste) ---
-- Transaksjoner uten naturlig nøkkel → surrogat-id. Idempotens håndteres i
-- arbeideren ved å slette eksisterende rader for (stasjon, dato) før innsetting.
create table if not exists public.synlig_svinn (
  id                uuid primary key default gen_random_uuid(),
  retailer_id       uuid not null references public.retailers(id) on delete restrict,
  stasjon_id        uuid not null references public.stasjoner(id) on delete restrict,
  dato              date,
  ean               text,
  varenavn          text,
  varenummer        text,
  operatornr        text,
  transaksjonstype  text,
  arsakskode        text,
  nettopris         numeric,
  antall            numeric,
  nettopris_total   numeric,
  kilde_jobb_id     uuid references public.import_jobber(id) on delete set null,
  opprettet_tid     timestamptz not null default now(),
  slettet_tid       timestamptz
);
create index if not exists synlig_svinn_stasjon_dato_idx
  on public.synlig_svinn (stasjon_id, dato);

-- ---------------------------------------------------------------------
-- RLS (samme mønster for alle tre)
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['timesalg', 'kassererstatistikk', 'synlig_svinn'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_les', t);
    execute format($f$
      create policy %I on public.%I for select to authenticated
      using (
        slettet_tid is null and (
          (public.gjeldende_rolle() = 'retailer_admin'
           and retailer_id = public.gjeldende_retailer_id())
          or public.har_stasjonstilgang(stasjon_id)
        )
      )$f$, t || '_les', t);

    execute format('drop policy if exists %I on public.%I', t || '_skriv', t);
    execute format($f$
      create policy %I on public.%I for all to authenticated
      using (public.gjeldende_rolle() = 'retailer_admin'
             and retailer_id = public.gjeldende_retailer_id())
      with check (public.gjeldende_rolle() = 'retailer_admin'
                  and retailer_id = public.gjeldende_retailer_id())$f$, t || '_skriv', t);

    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;
