-- =====================================================================
-- Sentiqa - LÆRT VÆRPROFIL per stasjon (erstatter manuell «vaerfolsomhet»-glider
-- med data). Regner ukedagsjustert Pearson-korrelasjon mellom temp/nedbør og
-- butikkomsetning (eks drivstoff/pant) i SQL (corr()), pr stasjon — skalerer til
-- enhver datamengde uten 1000-rad-fella. Motoren bruker lært verdi når den finnes,
-- ellers manuell som fallback. Kjøres ved opplasting/natt + her én gang.
-- =====================================================================

alter table public.stasjoner
  add column if not exists vaerfolsomhet_laert numeric,   -- 0–1, utledet av korrelasjon
  add column if not exists vaer_temp_korr      numeric,   -- ukedagsjustert temp-korr
  add column if not exists vaer_nedbor_korr    numeric,   -- ukedagsjustert nedbør-korr
  add column if not exists vaer_profil_tid     timestamptz;

create or replace function public.beregn_vaerprofil()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare antall integer;
begin
  with dag as (
    select ds.stasjon_id, ds.dato,
           extract(dow from ds.dato)::int as ukedag,
           sum(ds.omsetning_eks_mva)      as oms
    from public.daglig_salg ds
    where ds.slettet_tid is null
      and (ds.avdeling_kode is null or ds.avdeling_kode not in ('10', '250')) -- eks drivstoff/pant
      and ds.dato >= (current_date - interval '400 days')
    group by ds.stasjon_id, ds.dato
  ),
  wd as (
    select stasjon_id, ukedag, avg(oms) as wd_mean from dag group by stasjon_id, ukedag
  ),
  res as (
    select d.stasjon_id, d.dato, d.oms - w.wd_mean as resid
    from dag d join wd w on w.stasjon_id = d.stasjon_id and w.ukedag = d.ukedag
  ),
  korr as (
    select r.stasjon_id,
           corr(r.resid, v.temp_maks)  as temp_korr,
           corr(r.resid, v.nedbor_mm)  as nedbor_korr,
           count(*)                    as n
    from res r
    join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato and v.temp_maks is not null
    group by r.stasjon_id
  ), oppdatert as (
    update public.stasjoner s set
      vaer_temp_korr      = k.temp_korr,
      vaer_nedbor_korr    = k.nedbor_korr,
      vaerfolsomhet_laert = least(1.0, greatest(0.1, greatest(abs(coalesce(k.temp_korr, 0)), abs(coalesce(k.nedbor_korr, 0))) * 2.0)),
      vaer_profil_tid     = now()
    from korr k
    where s.id = k.stasjon_id and k.n >= 30 -- krev nok historikk
    returning 1
  )
  select count(*) into antall from oppdatert;
  return antall;
end $$;

revoke all on function public.beregn_vaerprofil() from public, anon, authenticated;
grant execute on function public.beregn_vaerprofil() to service_role;

-- Kjør én gang nå (fyller profilen for alle stasjoner med nok data).
select public.beregn_vaerprofil();
