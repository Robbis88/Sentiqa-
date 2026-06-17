-- =====================================================================
-- Sentiqa - TREFFSIKKERHET + SELVLAERING for prognosene.
--   prognose_treff       : backtest-resultat (forventet vs faktisk) per dag,
--                          per type (produksjonsplan/salgsprognose) og kategori.
--                          kategori '*' = dags-total. Skrives av service-role
--                          (backtest i natt/knapp), leses av leder via RLS.
--   prognose_kalibrering : laert korreksjonsfaktor per stasjon/type/kategori,
--                          utledet av treffhistorikken. Motoren ganger forslaget
--                          med denne -> systemet blir bedre etter hvert.
-- (select ...)-moenster fra 0067 for RLS-ytelse paa store tabeller.
-- =====================================================================

create table if not exists public.prognose_treff (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  type          text not null check (type in ('produksjonsplan', 'salgsprognose')),
  dato          date not null,
  kategori      text not null default '*',   -- varegruppe/avdeling-kode; '*' = total
  forventet     numeric not null default 0,
  faktisk       numeric not null default 0,
  treff         numeric not null default 0,  -- 0-100
  beregnet_tid  timestamptz not null default now(),
  unique (stasjon_id, type, dato, kategori)
);

create index if not exists prognose_treff_stasjon_idx
  on public.prognose_treff (stasjon_id, type, dato);

create table if not exists public.prognose_kalibrering (
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  type          text not null check (type in ('produksjonsplan', 'salgsprognose')),
  kategori      text not null,               -- varegruppe/avdeling-kode
  korreksjon    numeric not null default 1,  -- ganges paa forslaget (klemt 0.6-1.6)
  n             integer not null default 0,  -- antall backtest-dager bak faktoren
  oppdatert_tid timestamptz not null default now(),
  primary key (stasjon_id, type, kategori)
);

-- RLS: leder leser egne tall; service-role (backtest) skriver og omgaar RLS.
alter table public.prognose_treff       enable row level security;
alter table public.prognose_kalibrering enable row level security;

drop policy if exists prognose_treff_les on public.prognose_treff;
create policy prognose_treff_les on public.prognose_treff for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid()))
    )
  );

drop policy if exists prognose_kalibrering_les on public.prognose_kalibrering;
create policy prognose_kalibrering_les on public.prognose_kalibrering for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid()))
    )
  );
