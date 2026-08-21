-- =====================================================================
-- v_timeregnskap: maal mot RAMMEN, ikke mot planleggingstallet
--
-- 0117 maalte brukte timer mot `bemanning_maned.disponible_timer`. Det
-- er feil maalestokk, og feilen peker alltid samme vei:
--
--   disponible = timer_aar x (1 - reserve%) x (1 - sikkerhet%)
--
-- Reserven er holdt tilbake FOR SYKEFRAVAER. Den skal brukes. Maaler vi
-- faktisk forbruk mot en ramme som allerede har trukket fra
-- sykefravaeret, viser alle stasjoner overforbruk.
--
-- Og det gjorde de: fem av fem positive i produksjon 2026-08-21. Det
-- burde vaert et varsel i seg selv - et maal der alle feiler likt maaler
-- som regel ikke det man tror.
--
-- Maalt: fradragene er 1,8-2,4 % reserve og 3 % sikkerhet, altsaa rundt
-- 5 %. Det forklarte ikke funnene, men det forskjov dem: Dale gikk fra
-- +2 730 til +1 745 timer, Laguneparken fra +154 til -595.
--
-- RIKTIG MAALESTOKK er `bemanning_budsjett.timer` - aarsrammen fordelt
-- paa maaneder, foer fradrag. Det er den St1 faktisk har gitt.
--
-- KONSEKVENS FOR TILGANG, og den er med vilje: `bemanning_budsjett` er
-- `retailer_admin`-only (0082: «IKKE synlig for butikksjef»). Viewet er
-- `security_invoker`, saa en butikksjef faar null rader. Det er riktig
-- produkt: hun ser hva hun faar PLANLEGGE (disponible_timer, som staar
-- her som `plan_timer`), mens OPPGJOERET mot St1s ramme er eierens
-- spoersmaal. To ulike sporsmaal, to ulike lesere.
--
-- `budsjett_timer` BYTTER BETYDNING i denne migrasjonen: fra
-- planleggingstallet til rammen. Navnet passer rammen bedre - det er
-- den som ER budsjettet - og planleggingstallet finnes fortsatt, under
-- sitt eget navn.
--
-- IKKE RETTET HER: butikksjefens timer. `timer_aar` er den VARIABLE
-- rammen, og St1 har trukket fra ett aarsverk (1695 t) fordi de antar
-- at butikksjefen gaar paa fastloenn. Paa Dale gaar hun paa timeloenn
-- hele veien, paa Lone i deler av 2026. Da belaster hennes timer en
-- ramme som ikke er dimensjonert for dem, og `timer_over` blander to
-- ting. Det krever aa vite HVEM som er butikksjef, per stasjon og
-- periode, og det finnes ikke i basen: `profiler` har rollen men ingen
-- `ansatt_nr`, og `ansatte` har hverken rolle eller lonnsform.
-- Se [[sentiqa-tre-identiteter]] - koble aldri paa navn i stillhet.
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
  round(bb.timer)                                        as budsjett_timer,

  -- TIMENE STASJONEN HAR RETT PAA.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0 and bb.timer is not null
      then round(bb.timer
                 * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                 / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as opptjente_timer,

  round(t.brukte_timer)                                  as brukte_timer,

  -- OPPGJOERET. Positivt = brukt mer enn tjent inn.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0
     and bb.timer is not null and t.brukte_timer is not null
      then round(t.brukte_timer
                 - bb.timer
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
  case when bb.timer > 0
       then round(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) / bb.timer)
  end                                                    as bp_brutto_per_time,

  -- Det butikksjefen faar PLANLEGGE: rammen minus reserve for
  -- sykefravaer og sikkerhetsmargin. Staar med saa forskjellen
  -- mellom «faar planlegge» og «har faatt» kan etterregnes.
  round(m.disponible_timer)                              as plan_timer

from bp b
left join realisert r
  on r.stasjon_id = b.stasjon_id
 and r.aar        = date_trunc('year', b.maned)::date
left join kassen k
  on k.stasjon_id = b.stasjon_id and k.maned = b.maned
left join public.bemanning_budsjett bb
  on bb.stasjon_id = b.stasjon_id
 and bb.ar         = extract(year  from b.maned)::int
 and bb.maned      = extract(month from b.maned)::int
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

