-- =====================================================================
-- 0215  EN MAANED MED SVINNRADER, MEN UTEN MATRADER, ER IKKE 0 KRONER
-- =====================================================================
-- `0213` loeste det store tilfellet: en stasjonsmaaned UTEN svinnrader
-- ga `matkast_kr = null` i stedet for 0.
--
-- Det gjenstaar et mindre, og verre: en maaned MED svinnrader, men uten
-- rader i matgruppen. Da er `har_svinndata = true`, og
--
--     coalesce(sum(s.kast) filter (where s.kode like '12%'), 0)
--
-- gir 0. Ikke fordi det ble kastet null kroner mat, men fordi filteret
-- ikke traff noe. `sum()` over null rader er NULL, og `coalesce` gjorde
-- den til et tall.
--
-- Samme sak for `usynlig_mat_kr`, og der er den farligst: `0214` la til
-- port 6 (`mat_rader > 0`) i matkastanalysen, men usynliganalysen leser
-- `usynlig_mat_kr` direkte. En falsk 0 der ville sagt «ingen manko paa
-- mat» om en maaned der matgruppen ikke ble funnet i det hele tatt.
--
-- REGELEN: traff filteret ingen rader, er svaret NULL.
--
--     mat_rader = 0  ->  matkast_kr og usynlig_mat_kr er NULL
--     mat_rader > 0  ->  begge er tall, og 0 betyr NULL KRONER
--
-- `usynlig_rest_kr` beholder sin `coalesce`. Den er definert som «alt
-- utenom mat, vask og pant», og null slike rader betyr faktisk at det
-- ikke er noe der - filteret er en avgrensning, ikke et oppslag.
--
-- ---------------------------------------------------------------------
-- MAALT: ingen av dagens 40 stasjonsmaaneder har `mat_rader = 0` med
-- svinngrunnlag. Kvitteringen i `0214` sier `minste_mat_rader`, og
-- kontroll 4 viste 8-9 matrader paa hver av de 35. Denne migrasjonen er
-- derfor bevist inert i dag; den staar for at fellen ikke skal slaa til
-- naar en fil en gang mangler matgruppen.
--
-- Idempotent: `create or replace`. Ingen nye kolonner - bare uttrykket
-- bak to av dem. `security_invoker` settes eksplisitt.
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
    -- INGEN COALESCE NAAR FILTERET IKKE TRAFF. `sum()` over null rader
    -- er NULL, og det er riktig svar: matgruppen ble ikke funnet.
    case when count(*) filter (where s.kode like '12%') = 0 then null
         else coalesce(sum(s.kast) filter (where s.kode like '12%'), 0)
    end                                        as matkast_kr,
    case when count(*) filter (where s.kode like '12%') = 0 then null
         else coalesce(sum(s.usynlig_kr) filter (where s.kode like '12%'), 0)
    end                                        as usynlig_mat_kr,
    -- `rest` beholder sin coalesce: filteret er en AVGRENSNING, og null
    -- rader betyr at det ikke er noe utenfor mat, vask og pant.
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
  'Maanedstall per stasjon. matkast_kr og usynlig_mat_kr er NULL naar '
  'stasjonsmaaneden mangler svinnrader (har_svinndata) ELLER mangler '
  'rader i matgruppen (mat_rader = 0). 0 betyr alltid null kroner. '
  'usynlig_mat_kr er MATgruppens identitet; usynlig_rest_kr er alt '
  'UTENOM mat, vask og pant. De summeres aldri.';

-- ---------------------------------------------------------------------
-- KVITTERING. Rent lesende.
-- ---------------------------------------------------------------------
select
  case
    when (select count(*) from public.v_kurs_maanedstall) = 0
      then 'INGEN DATA - MIGRASJONEN KAN IKKE KONTROLLERES'
    when (select count(*) from public.v_kurs_maanedstall
           where coalesce(mat_rader, 0) = 0
             and (matkast_kr is not null or usynlig_mat_kr is not null)) > 0
      then 'FEIL: mattall uten matrader'
    when (select count(*) from public.v_kurs_maanedstall
           where mat_rader > 0 and (matkast_kr is null or usynlig_mat_kr is null)) > 0
      then 'FEIL: matrader uten mattall'
    else 'OK'
  end                                                          as dom,
  (select count(*) from public.v_kurs_maanedstall)             as rader,
  (select count(*) from public.v_kurs_maanedstall where har_svinndata) as med_svinndata,
  (select count(*) from public.v_kurs_maanedstall
    where har_svinndata and coalesce(mat_rader, 0) = 0)        as svinn_uten_matrader,
  (select count(*) from public.v_kurs_maanedstall where matkast_kr is null) as matkast_null,
  (select count(*) from public.v_kurs_maanedstall where usynlig_mat_kr is null) as usynlig_mat_null,
  (select min(mat_rader) from public.v_kurs_maanedstall where har_svinndata) as minste_mat_rader,
  (select round(sum(matkast_kr)) from public.v_kurs_maanedstall
    where maaned between date '2026-01-01' and date '2026-07-01') as matkast_jan_jul,
  (select round(sum(usynlig_mat_kr)) from public.v_kurs_maanedstall
    where maaned between date '2026-01-01' and date '2026-07-01') as usynlig_mat_jan_jul,
  (select round(usynlig_mat_kr) from public.v_kurs_maanedstall v
     join public.stasjoner st on st.id = v.stasjon_id
    where st.butikknummer = '4185' and v.maaned = date '2026-07-01')
                                                               as dale_juli_usynlig_mat;
