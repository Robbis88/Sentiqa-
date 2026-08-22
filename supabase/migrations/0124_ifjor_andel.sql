-- =====================================================================
-- v_timeregnskap: hvor stor del av maaneden er normalt unnagjort?
--
-- Robert, 2026-08-22: «underveis i august - har du brukt mer enn X timer
-- bor du justere. Vi vet jo ish forventet brutto, vi har omsetning
-- hittil i august.»
--
-- Det som manglet var ANDELEN. 20 av 31 dager er ikke 65 % av maanedens
-- brutto: helger, lonningsdager og utfartshelger ligger ikke jevnt. Blir
-- andelen regnet lineaert, ser en stasjon som har hatt en travel foerste
-- halvdel ut til aa ligge foran - og butikksjefen som stoler paa det,
-- bemanner opp inn i en rolig uke.
--
-- FJORAARETS EGEN KURVE, samme grep som `burde_naa` i
-- v_bp_status_avdeling: hvor stor del av fjoraarets samme maaned laa paa
-- dag 1 til dagnr? Det er den andelen aarets brutto skal maales mot.
--
-- PAA STASJONSNIVAA, ikke per avdeling. Timene er en stasjonsressurs, og
-- en avdelingsvis kurve ville svart paa et spoersmaal ingen stiller.
--
-- INGEN FJORAARSTALL -> NULL. Ikke lineaert som reserve: en ny stasjon
-- ville da faatt et anslag som ser ut som en maaling, og den feilen
-- peker mot aa bemanne etter et tall ingen har staatt for.
-- =====================================================================

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

-- Fjoraarets kurve: hvor stor del av samme maaned laa paa dag 1..dagnr?
-- Dagnummeret er dagen aarets salgstall stopper paa, og det varierer per
-- stasjon - derfor joines `kassen` inn i stedet for en global dato.
ifjor_kurve as (
  select v.stasjon_id,
         (date_trunc('month', v.dato) + interval '1 year')::date as maned,
         sum(v.omsetning_eks_mva)                                as oms_hel,
         sum(v.omsetning_eks_mva) filter (
           where extract(day from v.dato) <= extract(day from k2.siste_dato)
         )                                                       as oms_hittil
  from public.v_butikksalg v
  join kassen k2
    on k2.stasjon_id = v.stasjon_id
   and k2.maned = (date_trunc('month', v.dato) + interval '1 year')::date
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato), k2.siste_dato
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
                                                         as dager_i_maaned,

  -- ANDELEN AV MAANEDEN SOM NORMALT ER UNNAGJORT paa dette dagnummeret,
  -- maalt paa fjoraarets EGEN kurve. Null naar fjoraaret mangler - et
  -- lineaert anslag ville sett ut som en maaling.
  round((f.oms_hittil / nullif(f.oms_hel, 0))::numeric, 4) as ifjor_andel

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
  on t.stasjon_id = b.stasjon_id and t.maned = b.maned
left join ifjor_kurve f
  on f.stasjon_id = b.stasjon_id and f.maned = b.maned;

comment on view public.v_timeregnskap is
  'Timene er ikke gitt, de er fortjent: opptjente_timer = ramme x '
  '(realisert brutto / BP-brutto). Rammen er `disponible_timer` pluss '
  'ett aarsverk/12 for maaneder der stasjonen IKKE hadde en fastloennet '
  'fast vakt. Lederdekningen leses per maaned fra '
  '`bemanning_fast_vakt`, som naa har gjelder_fra/gjelder_til - en '
  'endring i dag skriver ikke om hvordan det var i mars.';

grant select on public.v_timeregnskap to authenticated;

