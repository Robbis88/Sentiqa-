-- =====================================================================
-- Sentiqa 0160 - Bilvask: hva som kom over kassa, og hva som ikke gjorde det
--
-- BILVASK ER DEN ENESTE AVDELINGEN MED TO INNTEKTER
--
-- En over kassa, og abonnementsvask som bare finnes i regnskapet. Alle
-- andre avdelinger selger over kassa og bare der.
--
-- Det gjoer at BP-kortet sammenligner to ulike inntektsgrunnlag for
-- nettopp denne avdelingen:
--
--   «Kassen, perfekt dag»  regnes fra salgsstatistikken - bare kassa
--   «Regnskapet viser»     er regnskapet - kassa PLUSS abonnement
--
-- I enhver annen avdeling er kassa et tak regnskapet ikke kan overstige.
-- Her kan det, og gjoer det. Uten tallet ved siden av maa man ta det paa
-- tro; med det ser man hvorfor.
--
-- MAALT 2026, sju avlagte maaneder:
--   Lone           kassa   518 643   abo 209 697   28,8 %
--   Laguneparken   kassa 1 566 983   abo 346 346   18,1 %
--   Varden         kassa 1 691 096   abo 312 501   15,6 %
--   Boenes         kassa 1 486 029   abo 289 539   16,3 %
--   Dale           ingen vaskehall
--
-- HVORFOR IKKE ANSLAA DET FOR INNEVAERENDE MAANED
--
-- Andelen varierer for mye: Lone svinger mellom 24,5 og 39,4 % gjennom
-- de samme sju maanedene, og den er ulik per stasjon (16-29 %). Verre:
-- Varden hadde vaskehallen stengt fem uker i juni, og da faller
-- forutsetningen helt bort - kassa naer null, abonnementer kreditert,
-- forholdet meningsloest. Et paaslag ville lagt til abonnementsinntekt
-- for uker det ikke var noe aa abonnere paa.
--
-- Derfor: eksakt tall for avlagte maaneder, og INGEN tall for den
-- inneveaerende. «Kommer naar maaneden avlegges» er et bedre svar enn et
-- estimat som kan bomme med 15 prosentpoeng.
-- =====================================================================

create or replace view public.v_bilvask_abonnement
with (security_invoker = true) as
with regn as (
  select
    retailer_id,
    stasjon_id,
    date_trunc('year',  periode)::date as aar,
    date_trunc('month', periode)::date as mnd,
    sum(regnskap) filter (where seksjon = 'omsetning') as regn_oms
  from public.regnskapslinjer
  where kode = '210'
    and stasjon_id is not null
  group by retailer_id, stasjon_id,
           date_trunc('year', periode), date_trunc('month', periode)
),
kasse as (
  select
    stasjon_id,
    date_trunc('month', dato)::date as mnd,
    sum(omsetning_eks_mva) as kasse_oms
  from public.v_butikksalg
  where avdeling_kode = '210'
  group by stasjon_id, date_trunc('month', dato)
)
select
  r.retailer_id,
  r.stasjon_id,
  r.aar,
  count(*)::bigint                            as maaneder,
  round(sum(k.kasse_oms))                     as kasse_kr,
  round(sum(r.regn_oms))                      as regnskap_kr,
  round(sum(r.regn_oms - k.kasse_oms))        as abonnement_kr,
  -- Prosenten bare naar den betyr noe. En maaned med stengt hall kan gi
  -- negativ nevner, og da er andelen ikke et tall vi skal vise.
  case when sum(r.regn_oms) > 0
       then round(100.0 * sum(r.regn_oms - k.kasse_oms) / sum(r.regn_oms), 1)
       end                                    as abonnement_pst
from regn r
join kasse k on k.stasjon_id = r.stasjon_id and k.mnd = r.mnd
group by r.retailer_id, r.stasjon_id, r.aar
having sum(r.regn_oms) > 0;

comment on view public.v_bilvask_abonnement is
  'Bilvask (kode 210) delt i det som kom over kassa og det som bare '
  'finnes i regnskapet - abonnementsvask. Bare avlagte maaneder, der '
  'begge sider finnes. Se migrasjon 0160.';

grant select on public.v_bilvask_abonnement to authenticated;
revoke all on public.v_bilvask_abonnement from anon;
