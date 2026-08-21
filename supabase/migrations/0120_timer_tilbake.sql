-- =====================================================================
-- Timer tilbake er en BESLUTNING, ikke en konsekvens
--
-- 0119 lot `fastlonnet = false` utloese justeringen automatisk:
--
--   case when ld.fastlonnet is false
--        then coalesce(a.fast_arsverk_timer, 0) / 12
--        else 0 end
--
-- Robert, 2026-08-21: «Det skulle vaere en eierstyrt mulighet til aa
-- legge tilbake timer i de maanedene det faktisk er riktig. Systemet
-- skal ikke automatisk gi fra seg timer bare fordi en lederstatus sier
-- nei.»
--
-- HVORFOR DET ER EN EKTE FORSKJELL, maalt paa produksjonsdata:
--
--   Laguneparken har Bjoern som butikksjef paa FASTLOENN, men han var i
--   pappaperm til august. `fastlonnet = false` er sant for de
--   maanedene. Med automatikken ville stasjonen faatt 953 opptjente
--   timer tilbake og gaatt fra +154 til -799 - fra saa vidt over til
--   800 timer til gode. Uten at noen hadde tatt stilling til om det
--   faktisk gikk med timeloennede til aa daekke ham.
--
--   Det er ikke en maalefeil. Det er automatikk som gir bort noe som
--   er eierens.
--
-- TO FELTER, TO SPOERSMAAL, og de skal kunne vaere uenige:
--
--   `fastlonnet`     Var det en fastloennet butikksjef paa plass?
--                    Et FAKTUM. Beholdes selv naar det ikke styrer noe -
--                    «ingen leder, og jeg ga likevel ikke tilbake timer»
--                    er en beslutning verdt aa kunne lese om et aar.
--   `timer_tilbake`  Hva eieren VALGTE aa legge tilbake. Null er ikke
--                    «ikke bestemt» - det er «ingenting».
--
-- ETT FELT FOR JUSTERINGEN, IKKE HAKE PLUSS TALL. Et tall som finnes ER
-- haken. To felter kan bli uenige - avhuket med 141 i feltet, eller
-- haket av med tomt felt - og da maa noen bestemme hvilket som gjelder.
--
-- 0 NORMALISERES TIL NULL, og skranken haandhever det. Ellers ville
-- «ingenting» hatt to representasjoner, og en spoerring som leter etter
-- `is null` ville bommet paa halvparten.
-- =====================================================================

alter table public.bemanning_lederdekning
  add column if not exists timer_tilbake numeric;

-- Skranken droppes og settes paa nytt: hele settet 0001 -> kjores av og
-- til om igjen, og `add constraint` uten dette feiler andre gang.
alter table public.bemanning_lederdekning
  drop constraint if exists lederdekning_timer_tilbake_positiv;
alter table public.bemanning_lederdekning
  add constraint lederdekning_timer_tilbake_positiv
  check (timer_tilbake is null or timer_tilbake > 0);

comment on column public.bemanning_lederdekning.timer_tilbake is
  'Timene EIEREN har valgt aa legge tilbake i rammen denne maaneden. '
  'NULL = ingenting. Aldri utledet av `fastlonnet` - et forslag paa '
  'aarsverk/12 vises i skjemaet, men fylles aldri inn automatisk. '
  '0 er forbudt ved skranke: «ingenting» skal ha en representasjon.';

comment on column public.bemanning_lederdekning.fastlonnet is
  'Var det en fastloennet butikksjef paa plass denne maaneden? Et '
  'FAKTUM, og styrer ikke lenger justeringen - se `timer_tilbake`. '
  'Beholdt fordi «ingen leder, og jeg ga likevel ikke tilbake timer» '
  'er en beslutning verdt aa kunne lese om et aar.';

-- --- Viewet: justeringen er det eieren satte -------------------------

create or replace view public.v_timeregnskap
with (security_invoker = true) as

with bp as (
  -- Stasjonens budsjett per maaned, summert over avdelingene.
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

-- Rammen: det som faktisk deles ut, pluss det EIEREN har valgt aa legge
-- tilbake. Ingen `case` paa `fastlonnet` - den registrerer et faktum,
-- den bestemmer ikke.
ramme as (
  select bm.stasjon_id, bm.ar, bm.maned,
         bm.disponible_timer                        as ramme_raa,
         coalesce(a.fast_arsverk_timer, 0)          as arsverk_timer,
         ld.fastlonnet,
         coalesce(ld.timer_tilbake, 0)              as justering
  from public.bemanning_maned bm
  left join public.bemanning_aar a
    on a.stasjon_id = bm.stasjon_id and a.ar = bm.ar
  left join public.bemanning_lederdekning ld
    on ld.stasjon_id = bm.stasjon_id
   and ld.ar = bm.ar and ld.maned = bm.maned
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
  -- TO DESIMALER. Forslaget for en hel maaned er 1695/12 = 141,25, og
  -- med EN desimal ville viewet meldt 141,3 tilbake - et annet tall enn
  -- det eieren satte. Det du skrev skal vaere det du ser.
  round(rm.justering, 2)                                 as ramme_justering_timer,
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
left join timer t
  on t.stasjon_id = b.stasjon_id and t.maned = b.maned;

comment on view public.v_timeregnskap is
  'Timene er ikke gitt, de er fortjent: opptjente_timer = ramme x '
  '(realisert brutto / BP-brutto). Rammen er `disponible_timer` - '
  'eierens fradrag deles aldri ut - pluss `timer_tilbake`, som eieren '
  'setter eksplisitt per maaned. `fastlonnet` registrerer om det var en '
  'fastloennet butikksjef, men styrer INGENTING: en leder i permisjon '
  'gjor ikke automatisk at stasjonen har krav paa hennes aarsverk.';

grant select on public.v_timeregnskap to authenticated;
