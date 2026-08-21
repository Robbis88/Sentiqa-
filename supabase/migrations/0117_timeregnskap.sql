-- =====================================================================
-- v_timeregnskap: timene er ikke gitt, de er fortjent
--
-- DOMENEREGELEN, fra Robert 2026-08-21:
--
--   «Timebudsjettet vi har faatt skal matche mot timeforbruket vi faar.
--    Sier budsjettet 12 000 timer, da skal vi ha 5 millioner i brutto.
--    Saa kan man ikke bruke 12 000 timer om vi har 4,8 mill i brutto.»
--
--   Timer man har rett paa = timebudsjett x (realisert brutto / BP-brutto)
--
--     12 000 x (4 800 000 / 5 000 000) = 11 520
--
-- Bruker stasjonen 12 000 timer paa 4,8 mill, ligger den 480 timer over -
-- ikke fordi noen har sagt nei, men fordi de ikke er tjent inn.
--
-- Premisset finnes allerede i `bemanning.ts`: «konstant brutto per
-- bemanningstime, saa timene skal folge bruttoen». Det som manglet var
-- OPPGJOERET - timer tjent mot timer brukt, som ett tall.
--
-- HVILKEN BRUTTO? Robert, samme dag:
--
--   «Du bruker realisert brutto paa regnskapene du har. Hvis kassen sier
--    48 000 i brutto paa 55 % bruttomargin, men historisk er den 43 000
--    paa 50 %, skal den legges til grunn fram til regnskapet er lastet
--    opp - da maa den korrigeres enten ned eller opp.»
--
-- Altsaa: KASSENS OMSETNING ER GOD, KASSENS MARGIN ER IKKE. En aapen
-- maaned verdsettes med kassens omsetning ganget med den margen
-- regnskapet faktisk har vist i aar. Bruker vi kassens egen margin,
-- overvurderer vi timene stasjonen har rett paa - og den feilen peker
-- mot «du kan bemanne mer», som er den dyre retningen aa ta feil i.
--
-- `grunnlag` sier alltid hvilken av delene et tall er, saa et anslag
-- aldri kan leses som en maaling.
--
-- INGEN REALISERT MARGIN ENNAA -> NULL, ikke BP-margen som reserve. Med
-- BP-margen ville anslaget blitt lik budsjettet per konstruksjon: hver
-- stasjon ville ligget noeyaktig i rute, hver maaned, uansett drift.
-- Det er verre enn ingen tall.
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

  round(m.disponible_timer)                              as budsjett_timer,

  -- TIMENE STASJONEN HAR RETT PAA.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0 and m.disponible_timer is not null
      then round(m.disponible_timer
                 * (case when b.er_avlagt then b.regn_brt else k.oms * r.margin end)
                 / coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))
  end                                                    as opptjente_timer,

  round(t.brukte_timer)                                  as brukte_timer,

  -- OPPGJOERET. Positivt = brukt mer enn tjent inn.
  case
    when coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) > 0
     and m.disponible_timer is not null and t.brukte_timer is not null
      then round(t.brukte_timer
                 - m.disponible_timer
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
  case when m.disponible_timer > 0
       then round(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) / m.disponible_timer)
  end                                                    as bp_brutto_per_time

from bp b
left join realisert r
  on r.stasjon_id = b.stasjon_id
 and r.aar        = date_trunc('year', b.maned)::date
left join kassen k
  on k.stasjon_id = b.stasjon_id and k.maned = b.maned
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
