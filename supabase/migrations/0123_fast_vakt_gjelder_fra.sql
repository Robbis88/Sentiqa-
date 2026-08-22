-- =====================================================================
-- Faste vakter faar en periode - saa historikken slutter aa skrive seg om
--
-- `bemanning_fast_vakt` beskrev hvordan det er NAA. Endres en vakt fra
-- timeloenn til fastloenn 1. november, forsvant justeringen i
-- timeregnskapet for januar til oktober ogsaa: Dales overforbruk hoppet
-- ~1 350 timer den dagen, uten at noe faktisk skjedde.
--
-- Robert tok alternativ A 2026-08-22 - «ta a naa du» - med oeynene
-- aapne, og ba om B rett etterpaa. Dette er B.
--
-- DET RETTER TO TING, IKKE EN:
--
--   * Timeregnskapet: tall du saa i mars stemmer fortsatt i november.
--   * Bemanningsplanleggeren, som i dag ikke vet at Bjoern var i
--     permisjon i vaar. Den planlegger mars med dagens vakter.
--
-- NOEKKELEN MAA UTVIDES. `unique (stasjon_id, navn, ukedag)` gjorde
-- historikk umulig: en vakt kan bare finnes en gang. Med `gjelder_fra` i
-- noekkelen kan «butikksjef mandag» vaere timeloennet fram til 31.10 og
-- fastloennet fra 01.11, som to rader.
--
-- INGEN OVERLAPP - HAANDHEVET AV SERVERHANDLINGEN, IKKE AV EN SKRANKE.
-- To gyldige rader for samme vakt samtidig ville dobbelttelt dekningen i
-- planleggeren. En `exclude`-skranke ville fanget det i basen, men
-- krever btree_gist og gjor feilmeldingen uleselig. I stedet lukker
-- `leggTilFastVakt` den forrige perioden naar en ny legges inn - og
-- `bemanning.test.ts` feller hvis den slutter aa gjore det.
--
-- 2020-01-01 SOM STANDARD, ikke `now()`. Eksisterende rader har alltid
-- gjeldt; setter vi dagens dato, ville alle maaneder foer i dag
-- plutselig staatt uten faste vakter - og timeregnskapet ville gitt
-- hver stasjon 141 timer i maaneden for hele aaret.
-- =====================================================================

alter table public.bemanning_fast_vakt
  add column if not exists gjelder_fra date not null default date '2020-01-01';
alter table public.bemanning_fast_vakt
  add column if not exists gjelder_til date;

alter table public.bemanning_fast_vakt
  drop constraint if exists fast_vakt_periode_gyldig;
alter table public.bemanning_fast_vakt
  add constraint fast_vakt_periode_gyldig
  check (gjelder_til is null or gjelder_til >= gjelder_fra);

comment on column public.bemanning_fast_vakt.gjelder_fra is
  'Foerste dag vakten gjelder. 2020-01-01 paa rader fra for perioder '
  'fantes - de har alltid gjeldt.';
comment on column public.bemanning_fast_vakt.gjelder_til is
  'Siste dag vakten gjelder. Null = fortsatt. Settes av '
  'serverhandlingen naar en ny periode legges inn, saa to rader for '
  'samme vakt aldri gjelder samtidig.';

-- Noekkelen utvides. `drop ... if exists` foerst: hele settet 0001 ->
-- kjores av og til om igjen, og en constraint som allerede finnes ville
-- felt andre gang.
alter table public.bemanning_fast_vakt
  drop constraint if exists bemanning_fast_vakt_stasjon_id_navn_ukedag_key;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bemanning_fast_vakt'::regclass
      and conname = 'fast_vakt_periode_unik'
  ) then
    alter table public.bemanning_fast_vakt
      add constraint fast_vakt_periode_unik
      unique (stasjon_id, navn, ukedag, gjelder_fra);
  end if;
end $$;

create index if not exists fast_vakt_periode_idx
  on public.bemanning_fast_vakt (stasjon_id, gjelder_fra, gjelder_til);

comment on table public.bemanning_fast_vakt is
  'Faste bindinger, f.eks. butikksjef 07-15 man-fre. En rad per ukedag '
  'per PERIODE. timelonnet skiller de som koster timerammen fra de som '
  'ikke gjor det; gjelder_fra/gjelder_til gjor at en endring i dag ikke '
  'skriver om hvordan det var i mars.';


-- --- Viewet: dekningen vurderes per maaned -------------------------

create or replace view public.v_timeregnskap
with (security_invoker = true) as

with bp as (
  -- utelatte_koder := array['10', '250', '40']
  select r.stasjon_id,
         r.periode                                                          as maned,
         sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste')  as bp_brt_aapen,
         sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste')     as bp_brt_avlagt,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste')     as regn_brt,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')             as regn_oms,
         count(*) filter (where r.seksjon in ('omsetning', 'bruttofortjeneste')) > 0
                                                                            as er_avlagt
  from public.regnskapslinjer r
  where r.kode is not null
    and r.kode not in ('10', '250', '40')
    and r.seksjon in ('omsetning', 'bruttofortjeneste',
                      'bp_omsetning', 'bp_bruttofortjeneste')
  group by r.stasjon_id, r.periode
),

realisert as (
  select stasjon_id,
         date_trunc('year', maned)::date  as aar,
         sum(regn_brt) / nullif(sum(regn_oms), 0) as margin
  from bp
  where er_avlagt
  group by stasjon_id, date_trunc('year', maned)
  having sum(regn_oms) > 0
),

kassen as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date as maned,
         sum(v.omsetning_eks_mva)          as oms,
         max(v.dato)                       as siste_dato
  from public.v_butikksalg v
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato)
),

-- Faste vakter som gjaldt DEN MAANEDEN. `timelonnet` er allerede
-- definert i 0086 som «belaster timerammen», saa dette er ikke en ny
-- tolkning - bare en som kjenner kalenderen.
--
-- En vakt teller for maaneden hvis perioden OVERLAPPER den: en leder som
-- sluttet 15. mars var leder i mars.
dekning as (
  select bm.stasjon_id, bm.ar, bm.maned,
         count(fv.id)                                as faste_vakter,
         count(fv.id) filter (where not fv.timelonnet) as fastlonnede
  from public.bemanning_maned bm
  left join public.bemanning_fast_vakt fv
    on fv.stasjon_id = bm.stasjon_id
   and fv.gjelder_fra <= (make_date(bm.ar, bm.maned, 1)
                          + interval '1 month - 1 day')::date
   and (fv.gjelder_til is null or fv.gjelder_til >= make_date(bm.ar, bm.maned, 1))
  group by bm.stasjon_id, bm.ar, bm.maned
),

ramme as (
  select bm.stasjon_id, bm.ar, bm.maned,
         bm.disponible_timer                     as ramme_raa,
         -- arsverk_timer := 1695
         coalesce(nullif(a.fast_arsverk_timer, 0), 1695) as arsverk_timer,
         d.faste_vakter,
         d.fastlonnede,
         case
           when coalesce(d.faste_vakter, 0) = 0    then 0
           when coalesce(d.fastlonnede, 0) > 0     then 0
           else coalesce(nullif(a.fast_arsverk_timer, 0), 1695) / 12
         end                                     as justering
  from public.bemanning_maned bm
  left join public.bemanning_aar a
    on a.stasjon_id = bm.stasjon_id and a.ar = bm.ar
  left join dekning d
    on d.stasjon_id = bm.stasjon_id and d.ar = bm.ar and d.maned = bm.maned
),

timer as (
  select stasjon_id,
         maaned      as maned,
         sum(timer)  as brukte_timer
  from public.v_stempling_ansatt_mnd
  group by stasjon_id, maaned
)

select
  b.stasjon_id,
  b.maned,
  b.er_avlagt,

  round(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))       as bp_brutto_kr,

  case
    when b.er_avlagt then round(b.regn_brt)
    when r.margin is not null then round(k.oms * r.margin)
  end                                                    as realisert_brutto_kr,

  case
    when b.er_avlagt              then 'regnskap'
    when r.margin is not null     then 'anslag'
    else                               'ukjent'
  end                                                    as grunnlag,

  round(k.oms)                                           as kasse_omsetning_kr,
  round((r.margin * 100)::numeric, 1)                    as realisert_margin_pst,

  round(rm.ramme_raa + rm.justering)                     as budsjett_timer,

  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0
     and (rm.ramme_raa + rm.justering) is not null
      then round((rm.ramme_raa + rm.justering)
                 * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                 / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as opptjente_timer,

  round(t.brukte_timer)                                  as brukte_timer,

  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0
     and (rm.ramme_raa + rm.justering) is not null and t.brukte_timer is not null
      then round(t.brukte_timer
                 - (rm.ramme_raa + rm.justering)
                   * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                   / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as timer_over,

  case when t.brukte_timer > 0
       then round((case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                  / t.brukte_timer)
  end                                                    as brutto_per_time,
  case when (rm.ramme_raa + rm.justering) > 0
       then round(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen)
                  / (rm.ramme_raa + rm.justering))
  end                                                    as bp_brutto_per_time,

  round(rm.ramme_raa)                                    as ramme_for_justering,
  round(rm.justering, 2)                                 as ramme_justering_timer,
  round(rm.arsverk_timer)                                as arsverk_timer,

  case
    when coalesce(rm.faste_vakter, 0) = 0 then 'ukjent'
    when coalesce(rm.fastlonnede, 0) > 0  then 'fastlonnet'
    else                                       'ikke_fastlonnet'
  end                                                    as lederdekning,

  extract(day from k.siste_dato)::int                    as dager_med_salg,
  extract(days from (b.maned + interval '1 month - 1 day'))::int
                                                         as dager_i_maaned

from bp b
left join realisert r
  on r.stasjon_id = b.stasjon_id
 and r.aar        = date_trunc('year', b.maned)::date
left join kassen k
  on k.stasjon_id = b.stasjon_id and k.maned = b.maned
left join ramme rm
  on rm.stasjon_id = b.stasjon_id
 and rm.ar         = extract(year  from b.maned)::int
 and rm.maned      = extract(month from b.maned)::int
left join timer t
  on t.stasjon_id = b.stasjon_id and t.maned = b.maned;

comment on view public.v_timeregnskap is
  'Timene er ikke gitt, de er fortjent: opptjente_timer = ramme x '
  '(realisert brutto / BP-brutto). Rammen er `disponible_timer` pluss '
  'ett aarsverk/12 for maaneder der stasjonen IKKE hadde en fastloennet '
  'fast vakt. Lederdekningen leses per maaned fra '
  '`bemanning_fast_vakt`, som naa har gjelder_fra/gjelder_til - en '
  'endring i dag skriver ikke om hvordan det var i mars.';

grant select on public.v_timeregnskap to authenticated;
