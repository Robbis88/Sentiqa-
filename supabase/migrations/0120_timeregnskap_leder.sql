-- =====================================================================
-- v_timeregnskap: butikksjefens timer holdes utenfor tellingen
--
-- `timer_aar` er den VARIABLE rammen - St1 har trukket fra ett aarsverk
-- (1695 t) fordi butikksjefen normalt gaar paa fastloenn. Rammen er
-- altsaa definert UTEN henne, og da maa forbruket telles likedan.
--
-- Ellers sammenligner vi en befolkning MED butikksjef mot en ramme
-- UTEN, og faar et overforbruk ingen kan gjore noe med: det er ikke en
-- bemanningsbeslutning at butikksjefen er paa jobb.
--
-- Robert, 2026-08-21: «om jeg legger inn ansattnummeret til alle
-- butikksjefene da, saa regner vi ikke med de?»
--
-- HVA DETTE KOSTER, sagt hoeyt. Sissel paa Dale gaar paa TIMELOENN og
-- faar betalt for alt hun jobber - altsaa belaster hun konto 503, samme
-- budsjett som rammen. Holdes timene hennes utenfor, forsvinner de fra
-- begge sider av regnestykket. Jobber hun 1 695 gaar det opp; jobber
-- hun 2 200, blir 500 timer usynlige i timebildet.
--
-- Derfor staar `leder_timer` som EGET tall. Ikke i dommen - hun er ikke
-- en bemanningsbeslutning - men ikke skjult heller. Kronene fanges
-- uansett av `/regnskap`, som sammenligner loenn mot loennsbudsjett.
--
-- Fra 2026-11-01 er ingen butikksjef paa timeloenn lenger (ny leder paa
-- Dale gaar paa fastloenn), og da er blindsonen borte av seg selv.
--
-- INGEN LEDER REGISTRERT -> INGEN EKSKLUDERING. `stasjon_leder` er tom
-- til noen fyller den. Da teller viewet alle, akkurat som foer, og
-- `leder_timer` er null. Det er synlig i tallet, ikke en stille
-- antakelse - en tom konfigurasjon skal se tom ut.
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

-- Stemplede timer, delt i to av `stasjon_leder`. `left join` og ikke
-- `exists`: vi trenger aa vite hvilke rader som traff, ikke bare om
-- noen gjorde det.
timer as (
  select s.stasjon_id,
         s.maaned as maned,
         sum(s.timer) filter (where sl.id is null) as brukte_timer,
         sum(s.timer) filter (where sl.id is not null) as leder_timer
  from public.v_stempling_ansatt_mnd s
  left join public.stasjon_leder sl
    on sl.stasjon_id = s.stasjon_id
   and sl.ansatt_nr  = s.ansatt_nr
   -- Perioden maa overlappe maaneden, ikke bare inneholde dagen 1.
   -- En leder som slutter 15. i maaneden er leder DEN maaneden.
   and sl.fra_dato  <= (s.maaned + interval '1 month - 1 day')::date
   and (sl.til_dato is null or sl.til_dato >= s.maaned)
  group by s.stasjon_id, s.maaned
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
  round(m.disponible_timer)                              as plan_timer,

  -- Butikksjefens egne timer. STAAR UTENFOR DOMMEN over, men
  -- ikke skjult: er de langt over 1695/12 i maaneden, er det
  -- en kostnad noen boer se, selv om den ikke er en
  -- bemanningsbeslutning.
  round(t.leder_timer)                                   as leder_timer

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


