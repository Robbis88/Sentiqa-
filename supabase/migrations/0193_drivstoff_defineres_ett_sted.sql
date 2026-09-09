-- =====================================================================
-- 0193 - DRIVSTOFF DEFINERES ETT STED
--
-- `0152` gjorde `retailer_koderegel` til kilden for hva drivstoff ER, og
-- `v_butikksalg` leser den. De fem objektene fra `0084` ble staaende med
-- litteralen sin:
--
--     coalesce(avdeling_kode, '') <> '10'
--     and upper(coalesce(avdeling_navn, '')) <> 'ENERGI'
--
-- Den er KORREKT for Kelsar i dag. Den er ogsaa gjeld, og
-- `salgskilde.test.ts` har telt den siden `0152` med teksten «tallet skal
-- bare NED. Naar det naar null, er drivstoff definert ett sted i hele
-- basen». Dette er den kjoeringen som naar null.
--
-- ---------------------------------------------------------------------
-- HVORFOR DET IKKE ER KOSMETIKK
--
-- Halvparten av litteralen traff aldri noe. AGENTS.md sier det rett ut:
-- avdelingskoden hos Kelsar er `1000`, ikke `10`. Filteret saa bredt ut
-- og hvilte i praksis paa navnesjekken alene - og et filter som ser
-- bredere ut enn det er, er nettopp det som skjulte at vaerprofilen
-- laerte paa drivstoff i to aar (`0151`).
--
-- Og for neste kjede er litteralen direkte feil. En kjede som kaller
-- avdelingen noe annet enn «ENERGI» ville faatt drivstoff inn i
-- ukerapporten, i utsolgt-varslene og paa begge forsidene - uten at noe
-- feilet. Se [[sentiqa-flerkunde-foer-kelsar]].
--
-- ---------------------------------------------------------------------
-- FAIL-CLOSED FOELGER MED, OG DET ER MED VILJE
--
-- `v_butikksalg` gir NULL RADER for en kjede uten
-- `retailer_kodeerklaering`. Etter denne migrasjonen arver de fem det.
--
-- Det er riktig retning - «vi vet ikke hva drivstoff er her» skal gi
-- ingenting, ikke alt - men det er en ekte endring i oppfoersel, og den
-- skal ses. Kvitteringen nederst teller rader FOER og ETTER for hver
-- kjede med salg. Er `etter` null der `foer` ikke er, mangler en
-- erklaering, og den skal fikses foer noen ser paa tallene.
--
-- `slettet_tid is null` BEHOLDES selv om `v_butikksalg` alt har den.
-- Redefineres viewet senere uten predikatet, teller disse fem ellers
-- slettede rader - og et view som stille slutter aa filtrere er den
-- formen `0130` handlet om.
--
-- Idempotent: kun `create or replace`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) v_salg_per_avdeling_dag
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
from public.v_butikksalg
where slettet_tid is null and avdeling_kode is not null
group by retailer_id, stasjon_id, dato, avdeling_kode, avdeling_navn;

-- ---------------------------------------------------------------------
-- 2) v_salg_per_varegruppe_stasjon_dag
-- ---------------------------------------------------------------------
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
from public.v_butikksalg
where slettet_tid is null and varegruppe_kode is not null
group by retailer_id, stasjon_id, dato, varegruppe_kode, varegruppe_navn;

-- ---------------------------------------------------------------------
-- 3) v_salg_per_varegruppe_dag (kjede-nivaa)
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
from public.v_butikksalg
where slettet_tid is null and varegruppe_kode is not null
group by retailer_id, dato, varegruppe_kode, varegruppe_navn;

grant select on public.v_salg_per_avdeling_dag           to authenticated;
grant select on public.v_salg_per_varegruppe_stasjon_dag to authenticated;
grant select on public.v_salg_per_varegruppe_dag         to authenticated;
revoke all on public.v_salg_per_avdeling_dag           from anon;
revoke all on public.v_salg_per_varegruppe_stasjon_dag from anon;
revoke all on public.v_salg_per_varegruppe_dag         from anon;

-- ---------------------------------------------------------------------
-- 4) uke_avdeling_aggregat - mater ukerapporten, pulsen og
--    kategorisignalene paa begge forsidene. Den viktigste av dem.
-- ---------------------------------------------------------------------
create or replace function public.uke_avdeling_aggregat(p_stasjon uuid, p_fra date, p_til date)
returns table(avdeling_kode text, avdeling_navn text, omsetning numeric, brutto numeric)
language sql stable as $$
  select avdeling_kode,
         max(avdeling_navn) as avdeling_navn,
         coalesce(sum(omsetning_eks_mva), 0) as omsetning,
         coalesce(sum(bto_fortjeneste_kr), 0) as brutto
  from public.v_butikksalg
  where stasjon_id = p_stasjon and dato between p_fra and p_til and slettet_tid is null
  group by avdeling_kode
$$;

grant execute on function public.uke_avdeling_aggregat(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------
-- 5) utsolgt_kandidater
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
    from public.v_butikksalg ds
    where ds.stasjon_id = p_stasjon
      and ds.slettet_tid is null
      and ds.ean is not null
      and ds.dato >= (current_date - p_dager)
      and ds.dato <  current_date
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

-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som rader.
--
-- `litteral_igjen` skal vaere 0: ingen av de fem naevner lenger '10'
-- eller 'ENERGI'.
--
-- `rader_foer` mot `rader_etter` per kjede: er `etter` null der `foer`
-- ikke er, mangler kjeden en drivstofferklaering, og de fem returnerer
-- ingenting. Da skal erklaeringen paa plass FOER noen ser paa tallene.
select
  'litteral' as hva,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('uke_avdeling_aggregat', 'utsolgt_kandidater')
      and (p.prosrc like '%''10''%' or p.prosrc like '%ENERGI%'))          as funksjoner_med_litteral,
  (select count(*) from pg_views
    where schemaname = 'public'
      and viewname in ('v_salg_per_avdeling_dag', 'v_salg_per_varegruppe_dag',
                       'v_salg_per_varegruppe_stasjon_dag')
      and (definition like '%''10''%' or definition like '%ENERGI%'))      as views_med_litteral,
  (select count(*) from pg_views
    where schemaname = 'public'
      and viewname in ('v_salg_per_avdeling_dag', 'v_salg_per_varegruppe_dag',
                       'v_salg_per_varegruppe_stasjon_dag')
      and definition like '%v_butikksalg%')                                as views_paa_butikksalg;

select
  'rader' as hva,
  d.retailer_id,
  count(*)                                              as rader_foer,
  (select count(*) from public.v_butikksalg b
    where b.retailer_id = d.retailer_id)                as rader_etter
from public.daglig_salg d
where d.slettet_tid is null
group by d.retailer_id
order by rader_foer desc;
