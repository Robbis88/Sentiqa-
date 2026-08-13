-- =====================================================================
-- Sentiqa - 0084_uten_drivstoff.sql
-- Drivstoff (ENERGI) ut av salgsvisningene.
--
-- HVORFOR DETTE ER VIKTIGERE ENN DET HORES UT SOM:
--
-- Drivstoff kom inn i salgsstatistikken i lopet av april 2026 og var fullt
-- med fra mai. Det er ~68 % av omsetningen. Ingen av visningene filtrerte
-- det bort, saa ukerapporten sammenlignet AARETS uke MED drivstoff mot
-- FJORARETS uke UTEN.
--
-- Regnestykket: gaar man fra 32 % av totalen til 100 %, blir veksten
-- +212 %. Forsiden viste +216 %. "Den sterke uken" var ikke en sterk uke -
-- det var drivstoff som dukket opp i datagrunnlaget. Kategorisignalene
-- malte mot den samme falske butikkveksten.
--
-- Drivstoff bidrar dessuten ikke til stasjonens P&L i det hele tatt (kode
-- 10 staar paa 0 baade i omsetning og bruttofortjeneste i regnskapet), og
-- det betjener seg selv paa pumpa. Det hverken kan eller skal males mot
-- butikkens bemanning og kategoriutvikling.
--
-- FILTERET treffer bade paa kode og navn. Det er ikke slurv: kode 10 er
-- observert i regnskapslinjer og BP-en, navnet ENERGI er observert i
-- daglig_salg. Med begge overlever filteret at kjeden doper om avdelingen
-- eller flytter koden, og et drivstoffsalg som slipper gjennom er verre
-- enn en avdeling som feilaktig utelates (det finnes ingen andre).
--
-- Idempotent: kun "create or replace view/function".
-- =====================================================================


-- ---------------------------------------------------------------------
-- v_salg_per_stasjon_dag - mater salgssidene og "siste salgsdag"
-- Kolonnene beholdes i samme rekkefolge (0046), ellers avvises replace.
-- ---------------------------------------------------------------------
create or replace view public.v_salg_per_stasjon_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  sum(omsetning_eks_mva)                                          as omsetning,
  sum(antall)                                                     as antall,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '120')     as mat_omsetning,
  sum(bto_fortjeneste_kr)                                         as bto_fortjeneste,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '140')     as kald_drikke_omsetning
from public.daglig_salg
where slettet_tid is null
  and coalesce(avdeling_kode, '') <> '10'
  and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
group by retailer_id, stasjon_id, dato;

grant select on public.v_salg_per_stasjon_dag to authenticated;


-- ---------------------------------------------------------------------
-- v_salg_per_avdeling_dag / v_salg_per_varegruppe_stasjon_dag (0056)
-- ---------------------------------------------------------------------
create or replace view public.v_salg_per_avdeling_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  avdeling_kode,
  avdeling_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and avdeling_kode is not null
  and avdeling_kode <> '10'
  and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
group by retailer_id, stasjon_id, dato, avdeling_kode, avdeling_navn;

create or replace view public.v_salg_per_varegruppe_stasjon_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  varegruppe_kode,
  varegruppe_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and varegruppe_kode is not null
  and coalesce(avdeling_kode, '') <> '10'
  and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
group by retailer_id, stasjon_id, dato, varegruppe_kode, varegruppe_navn;

grant select on public.v_salg_per_avdeling_dag           to authenticated;
grant select on public.v_salg_per_varegruppe_stasjon_dag to authenticated;


-- ---------------------------------------------------------------------
-- v_salg_per_varegruppe_dag (0004) - kjede-nivaa
-- ---------------------------------------------------------------------
create or replace view public.v_salg_per_varegruppe_dag
with (security_invoker = true) as
select
  retailer_id,
  dato,
  varegruppe_kode,
  varegruppe_navn,
  sum(omsetning_eks_mva) as omsetning,
  sum(antall)            as antall
from public.daglig_salg
where slettet_tid is null and varegruppe_kode is not null
  and coalesce(avdeling_kode, '') <> '10'
  and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
group by retailer_id, dato, varegruppe_kode, varegruppe_navn;

grant select on public.v_salg_per_varegruppe_dag to authenticated;


-- ---------------------------------------------------------------------
-- uke_avdeling_aggregat (0051) - mater ukerapporten, pulsen og
-- kategorisignalene paa begge forsidene. Den viktigste av dem alle.
-- ---------------------------------------------------------------------
create or replace function public.uke_avdeling_aggregat(p_stasjon uuid, p_fra date, p_til date)
returns table(avdeling_kode text, avdeling_navn text, omsetning numeric, brutto numeric)
language sql stable as $$
  select avdeling_kode,
         max(avdeling_navn) as avdeling_navn,
         coalesce(sum(omsetning_eks_mva), 0) as omsetning,
         coalesce(sum(bto_fortjeneste_kr), 0) as brutto
  from public.daglig_salg
  where stasjon_id = p_stasjon and dato between p_fra and p_til and slettet_tid is null
    and coalesce(avdeling_kode, '') <> '10'
    and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
  group by avdeling_kode
$$;

grant execute on function public.uke_avdeling_aggregat(uuid, date, date) to authenticated;


-- ---------------------------------------------------------------------
-- utsolgt_kandidater (0071) - drivstoff kan ikke gaa "utsolgt" paa den
-- maaten funksjonen leter etter, og ville bare stoyet.
-- ---------------------------------------------------------------------
create or replace function public.utsolgt_kandidater(p_stasjon uuid, p_dager integer default 35)
returns table(ean text, varenavn text, dato date, antall numeric, omsetning numeric)
language sql
stable
security invoker
set search_path = public
as $$
  with dag as (
    select ds.ean,
           max(ds.varenavn)            as varenavn,
           ds.dato,
           sum(ds.antall)              as antall,
           sum(ds.omsetning_eks_mva)   as omsetning
    from public.daglig_salg ds
    where ds.stasjon_id = p_stasjon
      and ds.slettet_tid is null
      and ds.ean is not null
      and ds.dato >= (current_date - p_dager)
      and ds.dato <  current_date
      and coalesce(ds.avdeling_kode, '') <> '10'
      and upper(coalesce(ds.avdeling_navn, '')) <> 'ENERGI'
    group by ds.ean, ds.dato
  ),
  kval as (
    select ean
    from dag
    group by ean
    having count(*) filter (where antall > 0) >= greatest(2, floor(p_dager * 0.6)) -- selger de fleste dager
       and sum(antall) / nullif(count(*) filter (where antall > 0), 0) >= 1.5       -- snitt >= 1.5 pr salgsdag
  )
  select d.ean, d.varenavn, d.dato, d.antall, d.omsetning
  from dag d
  join kval k on k.ean = d.ean
  order by d.ean, d.dato
$$;

grant execute on function public.utsolgt_kandidater(uuid, integer) to authenticated;
