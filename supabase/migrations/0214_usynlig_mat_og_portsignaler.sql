-- =====================================================================
-- 0214  USYNLIG MATSVINN ER IKKE «RESTEN», OG PORTENE TRENGER EN KILDE
-- =====================================================================
-- TRE KOLONNER TIL PAA `v_kurs_maanedstall`. `0213` redigeres ikke.
--
-- ---------------------------------------------------------------------
-- 1) `usynlig_mat_kr`
--
-- `usynlig_rest_kr` er alt UTENOM mat, vask og pant. Den ble presentert
-- som «usynlig matsvinn» i P2-motoren, og det er en annen stoerrelse.
--
-- Usynlig matsvinn er identiteten paa MATgruppen:
--
--     teoretisk BF mat - faktisk BF mat - synlig matkast
--
-- Maalt med produksjonsparseren over julifila 2026-09-13, paa
-- gruppenivaa. De tre uttrykkene gir samme tall paa hver stasjon:
--
--     stasjon   sum(usynlig_kr) 12%   kode 120   teoretisk-faktisk-kast
--     4185 Dale        31 902,47      31 902,47        31 902,47
--     4177 Lone        15 268,25      15 268,25        15 268,25
--     9145 Varden       3 814,60       3 814,60         3 814,60
--     9038 Lagunep.     1 404,77       1 404,77         1 404,77
--     9467 Boenes       1 079,67       1 079,67         1 079,67
--
-- Paa gruppenivaa ER `120` den eneste `12%`-raden, saa filteret er det
-- samme som `matkast_kr` bruker. FORTEGNET BEHOLDES: pluss er manko,
-- minus er overskudd - og et overskudd er ikke automatisk en gevinst.
--
-- `usynlig_rest_kr` staar uendret ved siden av. De to skal aldri
-- summeres: `rest` holder mat utenfor nettopp for ikke aa telle det to
-- ganger.
--
-- ---------------------------------------------------------------------
-- 2) `avvik_antall`  -  port 4 i confidence gate
--
-- `avviksstatus` settes per rad av parseren naar identiteten ikke gaar
-- opp (`0208`). Uten dette tallet i viewet hadde porten ingen kilde, og
-- «avstemt» maatte antas. En antatt kontroll er ingen kontroll.
--
-- ---------------------------------------------------------------------
-- 3) `mat_rader`  -  port 6 i confidence gate
--
-- Antall rader som faktisk traff `kode like '12%'`. Er den 0 mens
-- maaneden har svinngrunnlag, betyr det at MATKODENE ikke lenger heter
-- 12xxx - og da er `matkast_kr = 0` en mappingfeil, ikke et null-kast.
--
-- St1 renummererte kontokodene i februar 2026. Varegruppekodene paa
-- svinnarket fulgte ikke med, men porten er der for neste gang.
--
-- ---------------------------------------------------------------------
-- Idempotent: `create or replace`. Kolonner legges til PAA SLUTTEN, som
-- `create or replace view` krever. `security_invoker` settes eksplisitt
-- - uten klausulen nullstilles flagget i stillhet (0130).
-- =====================================================================

create or replace view public.v_kurs_maanedstall
with (security_invoker = true) as
with linjer as (
  select
    l.retailer_id,
    l.stasjon_id,
    date_trunc('month', l.periode)::date as maaned,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'bruttofortjeneste'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as brutto_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning' and l.kode like '12%'
    ) as matsalg_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr_budsjett,
    sum(l.regnskap) filter (where l.seksjon = 'resultat') as resultat_kr
  from public.regnskapslinjer l
  where l.stasjon_id is not null
    and l.slettet_tid is null
    and l.seksjon in (
      'omsetning', 'bruttofortjeneste', 'driftskostnader', 'resultat'
    )
  group by l.retailer_id, l.stasjon_id, date_trunc('month', l.periode)
),
svinn as (
  select
    s.retailer_id,
    s.stasjon_id,
    date_trunc('month', s.periode)::date as maaned,
    count(*)                                   as svinnrader,
    max(s.datastatus)                          as datastatus,
    count(*) filter (where s.kode like '12%')  as mat_rader,
    count(*) filter (where s.avviksstatus = 'avvik') as avvik_antall,
    coalesce(sum(s.kast) filter (where s.kode like '12%'), 0) as matkast_kr,
    -- USYNLIG MATSVINN. Samme filter som `matkast_kr`, fordi det er
    -- samme gruppe. Fortegnet beholdes.
    coalesce(sum(s.usynlig_kr) filter (where s.kode like '12%'), 0) as usynlig_mat_kr,
    coalesce(sum(s.usynlig_kr) filter (
      where s.kode is null
         or (s.kode not like '12%' and s.kode not like '21%' and s.kode not like '250%')
    ), 0)                                      as usynlig_rest_kr
  from public.v_svinn_grunnlag s
  where s.stasjon_id is not null
    and s.slettet_tid is null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.periode)
)
select
  l.retailer_id,
  l.stasjon_id,
  l.maaned,
  coalesce(l.omsetning_kr, 0)                 as omsetning_kr,
  coalesce(l.omsetning_budsjett_kr, 0)        as omsetning_budsjett_kr,
  coalesce(l.brutto_kr, 0)                    as brutto_kr,
  coalesce(l.matsalg_kr, 0)                   as matsalg_kr,
  coalesce(l.personal_kr, 0)                  as personal_kr,
  coalesce(l.personal_budsjett_kr, 0)         as personal_budsjett_kr,
  coalesce(l.paavirkbar_drift_kr, 0)          as paavirkbar_drift_kr,
  coalesce(l.paavirkbar_drift_kr_budsjett, 0) as paavirkbar_drift_budsjett_kr,
  coalesce(l.resultat_kr, 0)                  as resultat_kr,
  s.matkast_kr,
  s.usynlig_rest_kr,
  (s.svinnrader is not null and s.svinnrader > 0) as har_svinndata,
  s.datastatus,
  -- NYE I 0214, lagt til paa slutten.
  s.usynlig_mat_kr,
  s.avvik_antall,
  s.mat_rader
from linjer l
left join svinn s
  on  s.retailer_id = l.retailer_id
  and s.stasjon_id  = l.stasjon_id
  and s.maaned      = l.maaned;

grant select on public.v_kurs_maanedstall to authenticated;
revoke all on public.v_kurs_maanedstall from anon;

comment on view public.v_kurs_maanedstall is
  'Maanedstall per stasjon. matkast_kr, usynlig_mat_kr og usynlig_rest_kr '
  'er NULL naar stasjonsmaaneden ikke har svinnrader - se har_svinndata. '
  'usynlig_mat_kr er MATgruppens identitet (teoretisk - faktisk - kast); '
  'usynlig_rest_kr er alt UTENOM mat, vask og pant. De summeres aldri.';

-- ---------------------------------------------------------------------
-- KVITTERING. Rent lesende select, ikke raise notice.
-- ---------------------------------------------------------------------
select
  case
    when (select count(*) from public.v_kurs_maanedstall) = 0
      then 'INGEN DATA - MIGRASJONEN KAN IKKE KONTROLLERES'
    when (select count(*) from public.v_kurs_maanedstall
           where har_svinndata and usynlig_mat_kr is null) > 0
      then 'FEIL: svinngrunnlag uten usynlig_mat_kr'
    when (select count(*) from public.v_kurs_maanedstall
           where not har_svinndata and usynlig_mat_kr is not null) > 0
      then 'FEIL: usynlig_mat_kr uten svinngrunnlag'
    when (select count(*) from public.v_kurs_maanedstall
           where har_svinndata and mat_rader = 0) > 0
      then 'ADVARSEL: svinngrunnlag uten matrader - sjekk kodemappingen'
    else 'OK'
  end                                                          as dom,
  (select count(*) from public.v_kurs_maanedstall)             as rader,
  (select round(sum(usynlig_mat_kr)) from public.v_kurs_maanedstall
    where maaned between date '2026-01-01' and date '2026-07-01')
                                                               as usynlig_mat_jan_jul,
  (select round(usynlig_mat_kr) from public.v_kurs_maanedstall v
     join public.stasjoner st on st.id = v.stasjon_id
    where st.butikknummer = '4185' and v.maaned = date '2026-07-01')
                                                               as dale_juli_usynlig_mat,
  (select count(*) from public.v_kurs_maanedstall where avvik_antall > 0)
                                                               as maaneder_med_avvik,
  (select min(mat_rader) from public.v_kurs_maanedstall where har_svinndata)
                                                               as minste_mat_rader,
  (select round(sum(matkast_kr)) from public.v_kurs_maanedstall
    where maaned between date '2026-01-01' and date '2026-07-01')
                                                               as matkast_jan_jul;
