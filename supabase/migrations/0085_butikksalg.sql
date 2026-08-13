-- =====================================================================
-- Sentiqa - 0085_butikksalg.sql
-- Ett sted som definerer "butikkens salg", saa drivstoff ikke kan snike
-- seg inn i en ny beregning neste gang noen skriver en spoerring.
--
-- 0084 luket drivstoff ut av salgsvisningene. Men flere steder leser
-- daglig_salg DIREKTE, og der lever drivstoffet videre:
--
--   beregn_malekort_salg   maalekortene maaler omsetning og brutto med
--                          drivstoff naar maalekortet ikke er scopet.
--   beregn_kategori_vaerprofil  varegruppenivaa, men uten avdelingsfilter.
--   konkurranse.ts / verktoy.ts  en salgskonkurranse UTEN varegruppe ville
--                          i praksis blitt avgjort av drivstoffvolum.
--
-- Loesningen er ikke aa lappe hver enkelt: det loser i dag og ikke i
-- morgen. v_butikksalg har samme kolonner som daglig_salg, minus
-- drivstoff, og er det alt skal lese fra. Se AGENTS.md.
--
-- Kode 10 er verifisert som drivstoff: beregn_vaerprofil (0068) filtrerer
-- allerede paa "avdeling_kode not in ('10', '250') -- eks drivstoff/pant".
-- Navnet tas med i tillegg saa filteret overlever en omdoping.
--
-- Idempotent: kun "create or replace".
-- =====================================================================

create or replace view public.v_butikksalg
with (security_invoker = true) as
select *
from public.daglig_salg
where slettet_tid is null
  and coalesce(avdeling_kode, '') <> '10'
  and upper(coalesce(avdeling_navn, '')) <> 'ENERGI';

comment on view public.v_butikksalg is
  'Butikkens salg: daglig_salg uten drivstoff. LES DENNE, ikke daglig_salg, '
  'i alt som summerer kroner eller antall. Drivstoff er ~68 % av omsetningen '
  'og betjener seg selv paa pumpa - det hverken kan eller skal maales mot '
  'butikkens bemanning, kategorier eller konkurranser.';

grant select on public.v_butikksalg to authenticated;


-- ---------------------------------------------------------------------
-- beregn_malekort_salg (0074) - kun kilden byttet, resten ordrett.
-- ---------------------------------------------------------------------
create or replace function public.beregn_malekort_salg(p_malekort uuid, p_fra date, p_til date)
returns table(stasjon_id uuid, omsetning numeric, antall numeric, brutto numeric)
language sql stable security definer set search_path = public as $$
  select ds.stasjon_id,
         coalesce(sum(ds.omsetning_eks_mva), 0) as omsetning,
         coalesce(sum(ds.antall), 0)            as antall,
         coalesce(sum(ds.bto_fortjeneste_kr), 0) as brutto
  from public.v_butikksalg ds
  where ds.dato between p_fra and p_til
    and ds.slettet_tid is null
    and ds.retailer_id = public.gjeldende_retailer_id()
    and exists (
      select 1 from public.malekort m
      where m.id = p_malekort and m.retailer_id = ds.retailer_id and m.slettet_tid is null
    )
    and (
      not exists (select 1 from public.malekort_scope s where s.malekort_id = p_malekort)
      or exists (
        select 1 from public.malekort_scope s
        where s.malekort_id = p_malekort
          and ((s.nivaa = 'avdeling'   and s.kode = ds.avdeling_kode)
            or (s.nivaa = 'vareomrade' and s.kode = ds.vareomrade_kode)
            or (s.nivaa = 'varegruppe' and s.kode = ds.varegruppe_kode)
            or (s.nivaa = 'ean'        and s.kode = ds.ean))
      )
    )
  group by ds.stasjon_id
$$;
grant execute on function public.beregn_malekort_salg(uuid, date, date) to authenticated;
