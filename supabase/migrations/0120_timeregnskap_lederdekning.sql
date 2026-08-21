-- =====================================================================
-- v_timeregnskap: rammen justeres naar det ikke er fastloennet leder
--
-- St1 trekker ett aarsverk fra timebudsjettet FORDI de antar at
-- butikksjefen gaar paa fastloenn. Holder ikke antakelsen, maa arbeidet
-- hennes gjores av timeloennede - fra en ramme som ikke er dimensjonert
-- for det.
--
--   ramme = bemanning_budsjett.timer
--         + (aarsverket / 12) for hver maaned UTEN fastloennet leder
--
-- Robert: «hvis det ikke er fastloennete i 6 maaneder saa legger den
-- til halvparten i budsjettet til den aktuelle butikken.»
--
-- ALLE TIMER TELLES. Ingen unntak, ingen ansattnummer, ingen kobling
-- som kan gaa galt. En TIMELOENNET butikksjef faar rammen justert opp
-- OG timene sine talt: jobber hun et aarsverk gaar det opp, jobber hun
-- mer vises det. Det var noeyaktig blindsonen i forkastet 0119.
--
-- FLATT 1/12, IKKE ETTER BRUTTOKURVEN. Rammen fordeles ellers etter
-- BP-ens brutto, fordi timeloennede foelger salget. En butikksjef gjor
-- ikke det - hun er der i februar ogsaa. Aa vekte hennes aarsverk etter
-- julehandelen ville gitt for lite hjelp i lavsesongen, som er nettopp
-- naar rammen er trangest.
--
-- INGEN RAD = UKJENT, IKKE «JA». `lederdekning` sier 'ukjent' og
-- justeringen er null. En tom konfigurasjon skal se tom ut - ikke se ut
-- som om alt er i orden.
--
-- `arsverk_timer` er `bemanning_aar.fast_arsverk_timer`, som i dag er
-- 0 paa alle fem stasjoner. Da blir justeringen 0 selv om maaneden er
-- huket av. Kolonnen staar med saa det er SYNLIG at tallet mangler,
-- i stedet for at justeringen bare uteblir.
-- =====================================================================

create or replace view public.v_timeregnskap
with (security_invoker = true) as

with bp as (
  -- Stasjonens budsjett per maaned, summert over avdelingene.
  -- Samme utelatelser som v_bp_status_avdeling: drivstoff (10), pant
  -- (250) og regnskapets grand total (40).
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

-- Den realiserte margen: hva regnskapet FAKTISK har vist i aar.
-- Vektet over avlagte maaneder, ikke et snitt av maanedsprosenter.
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
         sum(v.omsetning_eks_mva)          as oms
  from public.v_butikksalg v
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato)
),

-- Rammen for maaneden, justert for manglende lederdekning.
ramme as (
  select bb.stasjon_id, bb.ar, bb.maned,
         bb.timer                                    as ramme_raa,
         coalesce(a.fast_arsverk_timer, 0)           as arsverk_timer,
         ld.fastlonnet,
         case when ld.fastlonnet is false
              then coalesce(a.fast_arsverk_timer, 0) / 12
              else 0 end                             as justering
  from public.bemanning_budsjett bb
  left join public.bemanning_aar a
    on a.stasjon_id = bb.stasjon_id and a.ar = bb.ar
  left join public.bemanning_lederdekning ld
    on ld.stasjon_id = bb.stasjon_id
   and ld.ar = bb.ar and ld.maned = bb.maned
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

  -- REALISERT BRUTTO. Regnskapet naar det finnes, ellers kassens
  -- omsetning verdsatt til aarets realiserte margin.
  case
    when b.er_avlagt then round(b.regn_brt)
    when r.margin is not null then round(k.oms * r.margin)
  end                                                    as realisert_brutto_kr,

  -- Sier ALLTID hvilken av delene tallet er. Et anslag som ikke er
  -- merket, blir lest som en maaling neste gang noen aapner sida.
  case
    when b.er_avlagt              then 'regnskap'
    when r.margin is not null     then 'anslag'
    else                               'ukjent'
  end                                                    as grunnlag,

  -- Kassens egne tall staar med, saa korreksjonen kan etterregnes.
  round(k.oms)                                           as kasse_omsetning_kr,
  round((r.margin * 100)::numeric, 1)                    as realisert_margin_pst,

  -- RAMMEN St1 ga, fordelt paa maaneder. Ikke planleggingstallet.
  round((rm.ramme_raa + rm.justering))                                        as budsjett_timer,

  -- TIMENE STASJONEN HAR RETT PAA.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0 and (rm.ramme_raa + rm.justering) is not null
      then round((rm.ramme_raa + rm.justering)
                 * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                 / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as opptjente_timer,

  round(t.brukte_timer)                                  as brukte_timer,

  -- OPPGJOERET. Positivt = brukt mer enn tjent inn.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0
     and (rm.ramme_raa + rm.justering) is not null and t.brukte_timer is not null
      then round(t.brukte_timer
                 - (rm.ramme_raa + rm.justering)
                   * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                   / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as timer_over,

  -- Brutto per time, bade oppnaadd og budsjettert. DET ER DENNE SOM
  -- VARER: mer brutto gir flere timer i aar, men hever baren neste aar,
  -- fordi BP bygges paa det som ble oppnaadd. Effektiviteten er det
  -- eneste som ikke spiser seg selv.
  case when t.brukte_timer > 0
       then round((case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                  / t.brukte_timer)
  end                                                    as brutto_per_time,
  case when (rm.ramme_raa + rm.justering) > 0
       then round(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) / (rm.ramme_raa + rm.justering))
  end                                                    as bp_brutto_per_time,

  -- Det butikksjefen faar PLANLEGGE: rammen minus reserve for
  -- sykefravaer og sikkerhetsmargin. Staar med saa forskjellen
  -- mellom «faar planlegge» og «har faatt» kan etterregnes.
  round(m.disponible_timer)                              as plan_timer,

  -- Justeringen, synlig. Blir den en usynlig tommel paa vekten,
  -- slutter tallet over aa vaere etterproevbart.
  round(rm.ramme_raa)                                    as ramme_for_justering,
  round(rm.justering)                                    as ramme_justering_timer,
  round(rm.arsverk_timer)                                as arsverk_timer,
  case when rm.fastlonnet is null then 'ukjent'
       when rm.fastlonnet        then 'fastlonnet'
       else                           'ikke_fastlonnet'
  end                                                    as lederdekning

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
left join public.bemanning_maned m
  on m.stasjon_id = b.stasjon_id
 and m.ar         = extract(year  from b.maned)::int
 and m.maned      = extract(month from b.maned)::int
left join timer t
  on t.stasjon_id = b.stasjon_id and t.maned = b.maned;

comment on view public.v_timeregnskap is
  'Timene er ikke gitt, de er fortjent: opptjente_timer = timebudsjett x '
  '(realisert brutto / BP-brutto). En avlagt maaned bruker regnskapet; '
  'en aapen maaned bruker kassens OMSETNING verdsatt til aarets '
  'REALISERTE margin - kassens egen margin ville overvurdert timene, og '
  'den feilen peker mot aa bemanne for mye. `grunnlag` sier alltid '
  'hvilken av delene tallet er.';

grant select on public.v_timeregnskap to authenticated;


