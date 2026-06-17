-- =====================================================================
-- Sentiqa - LAERT VAER-EFFEKT PER KATEGORI. Erstatter regex-gjettingen
-- (kald/varm ut fra varenavn) med ekte korrelasjon fra stasjonens egne tall:
-- ukedagsjustert Pearson-korr mellom temp/nedbor og salg, pr kategori.
--   niva='avdeling'   -> omsetning pr avdeling (salgsprognosen)
--   niva='varegruppe' -> antall pr varegruppe (produksjonsplanen)
-- Motoren bruker laert retning+styrke naar den finnes, ellers regex som fallback.
-- Alt regnes i SQL (corr()) -> skalerer uten 1000-rad-fella. Kjores natt + her.
-- =====================================================================

create table if not exists public.kategori_vaerprofil (
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  niva          text not null check (niva in ('avdeling', 'varegruppe')),
  kode          text not null,
  temp_korr     numeric,   -- -1..1, + = mer salg naar varmere
  nedbor_korr   numeric,   -- -1..1, + = mer salg naar mer nedbor
  n             integer not null default 0,
  oppdatert_tid timestamptz not null default now(),
  primary key (stasjon_id, niva, kode)
);

create or replace function public.beregn_kategori_vaerprofil()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare antall integer;
begin
  delete from public.kategori_vaerprofil;

  with base as (
    -- Avdeling: omsetning (eks drivstoff/pant/CR)
    select ds.retailer_id, ds.stasjon_id, 'avdeling'::text as niva, ds.avdeling_kode as kode,
           ds.dato, extract(dow from ds.dato)::int as ukedag, sum(ds.omsetning_eks_mva) as val
    from public.daglig_salg ds
    where ds.slettet_tid is null and ds.avdeling_kode is not null
      and ds.avdeling_kode not in ('10', '250', '40')
      and ds.dato >= (current_date - interval '400 days')
    group by ds.retailer_id, ds.stasjon_id, ds.avdeling_kode, ds.dato
    union all
    -- Varegruppe: antall
    select ds.retailer_id, ds.stasjon_id, 'varegruppe', ds.varegruppe_kode,
           ds.dato, extract(dow from ds.dato)::int, sum(ds.antall)
    from public.daglig_salg ds
    where ds.slettet_tid is null and ds.varegruppe_kode is not null
      and ds.dato >= (current_date - interval '400 days')
    group by ds.retailer_id, ds.stasjon_id, ds.varegruppe_kode, ds.dato
  ),
  wd as (
    select stasjon_id, niva, kode, ukedag, avg(val) as wd_mean
    from base group by stasjon_id, niva, kode, ukedag
  ),
  res as (
    select b.retailer_id, b.stasjon_id, b.niva, b.kode, b.dato, b.val - w.wd_mean as resid
    from base b join wd w on w.stasjon_id = b.stasjon_id and w.niva = b.niva and w.kode = b.kode and w.ukedag = b.ukedag
  ),
  korr as (
    select r.retailer_id, r.stasjon_id, r.niva, r.kode,
           corr(r.resid, v.temp_maks) as temp_korr,
           corr(r.resid, v.nedbor_mm) as nedbor_korr,
           count(*) as n
    from res r
    join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato and v.temp_maks is not null
    group by r.retailer_id, r.stasjon_id, r.niva, r.kode
  ), innsatt as (
    insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode, temp_korr, nedbor_korr, n)
    select retailer_id, stasjon_id, niva, kode, temp_korr, nedbor_korr, n
    from korr where n >= 30 -- krev nok historikk for en troverdig korrelasjon
    returning 1
  )
  select count(*) into antall from innsatt;
  return antall;
end $$;

revoke all on function public.beregn_kategori_vaerprofil() from public, anon, authenticated;
grant execute on function public.beregn_kategori_vaerprofil() to service_role;

-- RLS: leder leser egne kategorier; service-role (natt) skriver og omgaar RLS.
alter table public.kategori_vaerprofil enable row level security;

drop policy if exists kategori_vaerprofil_les on public.kategori_vaerprofil;
create policy kategori_vaerprofil_les on public.kategori_vaerprofil for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or stasjon_id in (select bs.stasjon_id from public.butikksjef_stasjoner bs where bs.profil_id = (select auth.uid()))
    )
  );

-- Kjor en gang naa (fyller profilen for alle stasjoner med nok data).
select public.beregn_kategori_vaerprofil();
