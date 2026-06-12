-- =====================================================================
-- Sentiqa - Ukerapport pr stasjon (forrige komplette uke vs samme uke i fjor).
-- Caches lazy ved forste dashbord-aapning etter sondagsdata. RLS: admin alt
-- eget, butikksjef sine stasjoner.
-- =====================================================================
create table if not exists public.uke_rapport (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete restrict,
  stasjon_id      uuid not null references public.stasjoner(id) on delete cascade,
  uke_mandag      date not null,
  omsetning       numeric,
  omsetning_ifjor numeric,
  brutto          numeric,
  brutto_ifjor    numeric,
  avdelinger      jsonb not null default '[]'::jsonb,
  ai_sammendrag   text,
  modell          text,
  opprettet_tid   timestamptz not null default now(),
  unique (stasjon_id, uke_mandag)
);
create index if not exists uke_rapport_retailer_idx on public.uke_rapport (retailer_id, uke_mandag);

alter table public.uke_rapport enable row level security;

drop policy if exists uke_rapport_les on public.uke_rapport;
create policy uke_rapport_les on public.uke_rapport for select to authenticated
  using (
    (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
    or public.har_stasjonstilgang(stasjon_id)
  );

drop policy if exists uke_rapport_skriv on public.uke_rapport;
create policy uke_rapport_skriv on public.uke_rapport for all to authenticated
  using (
    (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
    or public.har_stasjonstilgang(stasjon_id)
  )
  with check (
    (public.gjeldende_rolle() = 'retailer_admin' and retailer_id = public.gjeldende_retailer_id())
    or public.har_stasjonstilgang(stasjon_id)
  );

grant select, insert, update, delete on public.uke_rapport to authenticated;

-- Ukeaggregat pr avdeling (security invoker -> RLS paa daglig_salg gjelder).
create or replace function public.uke_avdeling_aggregat(p_stasjon uuid, p_fra date, p_til date)
returns table(avdeling_kode text, avdeling_navn text, omsetning numeric, brutto numeric)
language sql stable as $$
  select avdeling_kode,
         max(avdeling_navn) as avdeling_navn,
         coalesce(sum(omsetning_eks_mva), 0) as omsetning,
         coalesce(sum(bto_fortjeneste_kr), 0) as brutto
  from public.daglig_salg
  where stasjon_id = p_stasjon and dato between p_fra and p_til and slettet_tid is null
  group by avdeling_kode
$$;

grant execute on function public.uke_avdeling_aggregat(uuid, date, date) to authenticated;
