-- =====================================================================
-- 0206  EN MAANED UTEN TALL ER IKKE EN NULL
-- =====================================================================
-- `0205` koblet regnskapslinjene og svinnet med `full outer join`. Det
-- betyr at en maaned som har SVINN men ingen stasjonsregnskap kommer med
-- - med omsetning 0, resultat 0 og ekte matkast.
--
-- Desember 2025 er noeyaktig det. Malt 2026-09-12:
--
--   desember 2025:  9 kostnadslinjer, ALLE paa klyngenivaa, 0 per stasjon
--
-- Og `regnskap_usynlig_svinn` HAR desember per stasjon. Serien startet
-- derfor med et punkt der alt utenom matkast var null - ikke fordi
-- tallene var null, men fordi de ikke fantes.
--
-- **En null i en trendserie er et datapunkt. Det trekker linja.** Et hull
-- som later som det er en null er verre enn et hull som mangler: det
-- foerste blir regnet med.
--
-- Det var dette Robert saa: «Resultatet i juli er 0 kroner. I desember
-- var det 0. Det er +0 paa 8 maaneder.» Desember var aldri en maaned med
-- tall.
--
-- ---------------------------------------------------------------------
-- REGELEN: REGNSKAPET AVGJOER OM MAANEDEN FINNES
--
-- `left join` fra regnskapslinjene. Har stasjonen tall i regnskapet, er
-- maaneden med - og svinnet legges paa om det finnes. Har den ikke,
-- finnes maaneden ikke, og Kursen ser en kortere serie i stedet for en
-- feil verdi.
--
-- Motsatt vei - svinn uten regnskap - er ikke en maaned vi kan maale
-- retning i: hverken omsetning, personal eller resultat finnes.
--
-- ---------------------------------------------------------------------
-- SAMME LISTER, SAMME RETTIGHETER
--
-- Resten er uendret fra `0205`. `create or replace view` er idempotent,
-- og `security_invoker` maa staa med paa NYTT: klausulen nullstilles i
-- stillhet av en redefinering uten den.
-- =====================================================================

create or replace view public.v_kurs_maanedstall
with (security_invoker = true) as
with linjer as (
  select
    l.retailer_id,
    l.stasjon_id,
    date_trunc('month', l.periode)::date as maaned,

    -- OMSETNING: avdelingsrollupene, uten drivstoff, pant og «40 CR».
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

    -- BRUTTO, samme utvalg. Brukes til aa verdsette omsetningsvekst.
    sum(l.regnskap) filter (
      where l.seksjon = 'bruttofortjeneste'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as brutto_kr,

    -- MATSALG: varegruppe 12xxx.
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning' and l.kode like '12%'
    ) as matsalg_kr,

    -- PERSONAL. Begrep, ikke kode.
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

    -- PAAVIRKBAR DRIFT. Begrep, ikke kode.
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
    ) as paavirkbar_drift_budsjett_kr,

    -- RESULTATET, fra arkets egen RESULTAT-linje.
    sum(l.regnskap) filter (where l.seksjon = 'resultat') as resultat_kr,

    -- HAR MAANEDEN TALL I DET HELE TATT? En stasjon som staar i fila med
    -- bare nuller er en ekte maaned; en som ikke staar der er ikke.
    count(*) as linjer_lest
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
    sum(s.kast) filter (where s.kode like '12%') as matkast_kr,
    -- USYNLIG PAA «RESTEN»: alt utenom mat, vask (21xxx) og pant
    -- (250xx). Bilvask er strukturelt negativ og ville dratt hele
    -- tallet i pluss. Pluss er manko, minus er overskudd.
    sum(s.usynlig_kr) filter (
      where s.kode is null
         or (s.kode not like '12%' and s.kode not like '21%' and s.kode not like '250%')
    ) as usynlig_rest_kr
  from public.regnskap_usynlig_svinn s
  where s.stasjon_id is not null
    and s.slettet_tid is null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.periode)
)
-- LEFT JOIN, ikke full outer. Regnskapet avgjoer om maaneden finnes.
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
  coalesce(l.paavirkbar_drift_budsjett_kr, 0) as paavirkbar_drift_budsjett_kr,
  coalesce(l.resultat_kr, 0)                  as resultat_kr,
  coalesce(s.matkast_kr, 0)                   as matkast_kr,
  coalesce(s.usynlig_rest_kr, 0)              as usynlig_rest_kr
from linjer l
left join svinn s
  on  s.retailer_id = l.retailer_id
  and s.stasjon_id  = l.stasjon_id
  and s.maaned      = l.maaned;

grant select on public.v_kurs_maanedstall to authenticated;
revoke all on public.v_kurs_maanedstall from anon;

comment on view public.v_kurs_maanedstall is
  'Én rad per stasjon per maaned: grunnlaget Kursen maaler retning paa. '
  'Summeres HER fordi app-laget hentet 1 563 raa rader med et tak paa '
  '7 200, og PostgREST kutter paa sitt eget tak UTEN aa feile (0205). '
  'REGNSKAPET AVGJOER OM MAANEDEN FINNES (0206): en maaned med svinn men '
  'uten stasjonsregnskap - desember 2025 - kom foer med omsetning 0 og '
  'resultat 0, og et hull som later som det er en null blir regnet med i '
  'trenden. Driftskostnadene filtreres paa `begrep`, ikke kode (0203).';

-- ---------------------------------------------------------------------
-- Kvittering.
-- ---------------------------------------------------------------------
do $$
declare
  rader    bigint;
  eldste   date;
  siste    date;
  tomme    bigint;
begin
  select count(*), min(maaned), max(maaned)
    into rader, eldste, siste
    from public.v_kurs_maanedstall;
  select count(*) into tomme
    from public.v_kurs_maanedstall
   where omsetning_kr = 0 and resultat_kr = 0;

  raise notice '0206: % rader, % til %', rader, eldste, siste;
  raise notice '0206: rader uten omsetning OG uten resultat: % (skal vaere 0)', tomme;
end $$;
