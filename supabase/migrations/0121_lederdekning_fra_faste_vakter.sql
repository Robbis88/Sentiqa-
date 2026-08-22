-- =====================================================================
-- Lederdekningen leses fra faste vakter - ett sted, ikke to
--
-- Robert, 2026-08-22: «vi har jo denne her da? Hva om vi bare bruker
-- denne? Slipper den å ligge to steder. Hvis det ikke er fastlønnet
-- butikksjef skrevet her, så får de timene?»
--
-- Han har rett, og 0086 sier det allerede ordrett om `timelonnet`:
--
--   true  = vakten er bundet, men belaster timerammen (timeloennet NK)
--   false = fastloenn, dekker gulvet uten aa koste rammen
--
-- Det er noeyaktig samme faktum som `bemanning_lederdekning` ba om paa
-- nytt, i et eget skjema, med fire kontroller per maaned. Skjemaet
-- motsa til og med seg selv paa skjermen - nedtrekket beholdt brukerens
-- klikk mens teksten under kom fra serveren.
--
-- REGELEN, UTEN NAVNEGJENKJENNING:
--
--   Har stasjonen faste vakter, men INGEN av dem er fastloennet, saa
--   holder ikke St1s antakelse om en fastloennet butikksjef. Da legges
--   aarsverket/12 tilbake i rammen.
--
-- Vi trenger altsaa ikke vite HVILKEN rad som er butikksjefen. `navn`
-- er fritekst - «butikksjef», «BS», «daglig leder» - og aa koble paa
-- den ville vaert samme feil som aa koble ansatte paa navn.
--
-- INGEN FASTE VAKTER = UKJENT, IKKE «NEI». En stasjon som ikke har satt
-- opp bemanning i det hele tatt skal ikke faa 141 timer i maaneden av
-- en tom tabell. Da er svaret at vi ikke vet, og rammen staar.
--
-- HVA DETTE KOSTER, og det skal staa skrevet: `bemanning_fast_vakt` har
-- ingen gyldighetsperiode. Den beskriver hvordan det er NAA. Endres en
-- vakt fra timeloenn til fastloenn 1. november, forsvinner justeringen
-- for januar til oktober ogsaa - tallet beskriver «slik det er naa,
-- gjennom hele aaret». Valgt bevisst: alternativet er `gjelder_fra` paa
-- faste vakter, som ogsaa ville rettet bemanningsplanleggeren, men som
-- er en stoerre endring enn dette.
-- =====================================================================

-- Tabellen fra 0118 var i drift i under et doegn og er erstattet av et
-- faktum som allerede fantes. Den droppes i stedet for aa bli liggende:
-- en ubrukt tabell med RLS-policyer maa staa i `rls_vakthund`-listene
-- for alltid, og en tabell ingen skriver til er en tabell ingen
-- oppdager at er feil.
drop table if exists public.bemanning_lederdekning;

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
         sum(v.omsetning_eks_mva)          as oms
  from public.v_butikksalg v
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato)
),

-- Faste vakter, oppsummert. `timelonnet` er allerede definert som
-- «belaster timerammen», saa dette er ikke en ny tolkning av dataene -
-- det er den som staar i 0086.
dekning as (
  select stasjon_id,
         count(*)                                as faste_vakter,
         count(*) filter (where not timelonnet)  as fastlonnede
  from public.bemanning_fast_vakt
  group by stasjon_id
),

ramme as (
  select bm.stasjon_id, bm.ar, bm.maned,
         bm.disponible_timer                     as ramme_raa,
         -- ETT AARSVERK = 1695 TIMER. Staar i 0082 som «timene St1
         -- trekker fra for butikksjefens fastloenn», og speiles av
         -- ARSVERK_TIMER i src/lib/bemanning/lederdekning.ts.
         -- `lederdekning.test.ts` feller hvis de to gaar fra hverandre.
         -- arsverk_timer := 1695
         coalesce(nullif(a.fast_arsverk_timer, 0), 1695) as arsverk_timer,
         d.faste_vakter,
         d.fastlonnede,
         case
           -- Ingen faste vakter i det hele tatt: vi vet ikke, og en tom
           -- tabell skal ikke dele ut timer.
           when coalesce(d.faste_vakter, 0) = 0    then 0
           -- Minst en fastloennet: St1s fratrekk holder.
           when coalesce(d.fastlonnede, 0) > 0     then 0
           else coalesce(nullif(a.fast_arsverk_timer, 0), 1695) / 12
         end                                     as justering
  from public.bemanning_maned bm
  left join public.bemanning_aar a
    on a.stasjon_id = bm.stasjon_id and a.ar = bm.ar
  left join dekning d
    on d.stasjon_id = bm.stasjon_id
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

  -- Hvor justeringen kommer fra, i klartekst - saa tallet over kan
  -- etterproeves uten aa lese denne fila.
  case
    when coalesce(rm.faste_vakter, 0) = 0 then 'ukjent'
    when coalesce(rm.fastlonnede, 0) > 0  then 'fastlonnet'
    else                                       'ikke_fastlonnet'
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
left join timer t
  on t.stasjon_id = b.stasjon_id and t.maned = b.maned;

comment on view public.v_timeregnskap is
  'Timene er ikke gitt, de er fortjent: opptjente_timer = ramme x '
  '(realisert brutto / BP-brutto). Rammen er `disponible_timer` - '
  'eierens fradrag deles aldri ut - pluss ett aarsverk/12 for stasjoner '
  'som IKKE har en fastloennet fast vakt. Lederdekningen leses fra '
  '`bemanning_fast_vakt.timelonnet` og vedlikeholdes ett sted: paa '
  'bemanningssida, der de faste vaktene allerede staar.';

grant select on public.v_timeregnskap to authenticated;
