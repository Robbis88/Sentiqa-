-- =====================================================================
-- 0205  KURSEN SUMMERES I BASEN, IKKE I APPEN
-- =====================================================================
-- Maanedsplanene sto med 0 kroner paa hver stasjon 2026-09-12, mens
-- parseren leste Dale til resultat -10 201 og omsetning 2 027 058 for
-- juli. Tallene var i basen. De kom ikke FRAM.
--
--   select count(*) ... 12 maaneder x 5 stasjoner  ->  1 563 rader
--
-- `byggPlanerForRetailer` hentet raa `regnskapslinjer` med `.limit(7200)`.
-- **PostgREST kutter paa sitt eget tak UTEN aa feile.** Svaret ble 1 000
-- rader, og juli - som nettopp var skrevet og derfor ligger fysisk
-- bakerst - falt utenfor. Siste maaned ble tom, og «siste maaned» er
-- nettopp den planen handler om.
--
-- Matkast hadde ekte tall hele tiden, fordi `regnskap_usynlig_svinn` er
-- en mye mindre tabell. Det gjorde feilen vanskeligere aa se: noen tall
-- stemte.
--
-- FJERDE GANG. `0090`, `0166`, `0175` - og naa Kursen. Et avkortet svar
-- ser ut som en stasjon uten tall, aldri som en feil.
--
-- ---------------------------------------------------------------------
-- LOESNINGEN ER IKKE EN HOEYERE GRENSE
--
-- Taket er serverens, ikke appens. Et `.limit()` som er hoeyere enn
-- taket er en loegn om hva vi faar.
--
-- Derfor summeres maaneden HER: én rad per stasjon per maaned. Fem
-- stasjoner og tolv maaneder er 60 rader i stedet for 1 563, og det kan
-- ikke avkortes. Samme loesning `v_lonnsart_maaned` fikk i `0180`, av
-- samme grunn.
--
-- ---------------------------------------------------------------------
-- BEGREP, IKKE KODE
--
-- Driftskostnadene filtreres paa `begrep`. `hent.ts` hadde en TREDJE
-- hardkodet kodeliste - og den manglet `634`, uten at noe sted sa
-- hvorfor. Etter `0203` er en kodeliste dessuten feil for januar 2026 og
-- eldre, der `634` betyr «Pengehaandtering».
--
-- `rep_vedlikehold` ER med naa. At den paa vaskestasjonene stort sett er
-- WashTec - altsaa en FOELGE, ikke en spak - avgjoeres per leverandoer i
-- `bilagssum`, og det er et annet spoersmaal enn om kostnaden er
-- butikksjefens. Paa Dale, som ikke har vask, er den kjoel og bygg.
--
-- `renhold_og_renovasjon` er ogsaa med: paa en maaned fra foer februar
-- 2026 ER det renholdskostnaden, og uten den ville januar sett ut som en
-- maaned uten renhold.
--
-- Lista skal stemme med `BUTIKKSJEF_DRIFT_BEGREP` og
-- `BUTIKKSJEF_PERSONAL_BEGREP` i `src/lib/regnskap-tilgang.ts`.
-- `src/lib/kurs/viewliste.test.ts` binder dem sammen.
--
-- ---------------------------------------------------------------------
-- BRUTTO LESES NAA
--
-- `byggHistorikk` satte `bruttoKr = 0` med kommentaren «brutto kan ikke
-- leses her». Det var feil: stasjonsarket HAR en
-- bruttofortjeneste-seksjon, 92 rader i maaneden paa Kelsar.
--
-- Konsekvensen var ikke kosmetisk. `kronerIAret` verdsetter
-- omsetningsvekst med bruttomarginen, og falt tilbake paa 50 % naar
-- brutto var 0. Med royalty paa OMSETNING er marginen nettopp det som
-- avgjoer om vekst er verdt noe - se `royalty.ts`.
--
-- ---------------------------------------------------------------------
-- RETTIGHETER OG RLS
--
-- `security_invoker = true`: viewet leser som den som spoer, saa
-- `regnskapslinjer_les` (0204) og `regnskap_usynlig_svinn` sine policyer
-- gjelder. Uten klausulen leser viewet som EIEREN, forbi RLS - og
-- `create or replace view` uten den nullstiller flagget i stillhet.
--
-- `revoke all from anon` ved siden av granten, alltid: `anon` er rollen
-- bak den offentlige noekkelen i hver sidelast. Se AGENTS.md.
--
-- Idempotent: `create or replace view`.
-- =====================================================================

create or replace view public.v_kurs_maanedstall
with (security_invoker = true) as
with linjer as (
  select
    l.retailer_id,
    l.stasjon_id,
    date_trunc('month', l.periode)::date as maaned,

    -- OMSETNING: avdelingsrollupene, uten drivstoff, pant og «40 CR».
    -- Drivstoff er ~68 % av omsetningen og betjener seg selv paa pumpa;
    -- «40 CR» er St1s egen total og dobbelteller mot avdelingene. Se
    -- SKJUL_OMS_KODER i src/lib/avdelinger.ts.
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

    -- RESULTATET, fra arkets egen RESULTAT-linje. Ikke utledet: et
    -- utledet tall kan drive fra regnskapsfoererens eget, og «medvind»
    -- skal ikke hvile paa en egen mening.
    sum(l.regnskap) filter (where l.seksjon = 'resultat') as resultat_kr
  from public.regnskapslinjer l
  where l.stasjon_id is not null
    and l.slettet_tid is null
  group by l.retailer_id, l.stasjon_id, date_trunc('month', l.periode)
),
svinn as (
  select
    s.retailer_id,
    s.stasjon_id,
    date_trunc('month', s.periode)::date as maaned,
    -- MATKAST i kroner. Varegruppe 12xxx.
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
select
  coalesce(l.retailer_id, s.retailer_id) as retailer_id,
  coalesce(l.stasjon_id, s.stasjon_id)   as stasjon_id,
  coalesce(l.maaned, s.maaned)           as maaned,
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
full outer join svinn s
  on  s.retailer_id = l.retailer_id
  and s.stasjon_id  = l.stasjon_id
  and s.maaned      = l.maaned;

grant select on public.v_kurs_maanedstall to authenticated;
revoke all on public.v_kurs_maanedstall from anon;

comment on view public.v_kurs_maanedstall is
  'Én rad per stasjon per maaned: grunnlaget Kursen maaler retning paa. '
  'Summeres HER fordi app-laget hentet 1 563 raa rader med et tak paa '
  '7 200, og PostgREST kutter paa sitt eget tak UTEN aa feile - siste '
  'maaned falt utenfor og maanedsplanene sto med 0 kroner (0205). '
  'Driftskostnadene filtreres paa `begrep`, ikke kode: 628 betydde «Leie '
  'driftsmidler» foer februar 2026 (0203). Listene speiler '
  'BUTIKKSJEF_DRIFT_BEGREP og BUTIKKSJEF_PERSONAL_BEGREP.';

-- ---------------------------------------------------------------------
-- Kvittering: hvor mange rader viewet gir, og at siste maaned har tall.
-- ---------------------------------------------------------------------
do $$
declare
  rader    bigint;
  maaneder bigint;
  siste    date;
  tomme    bigint;
begin
  select count(*), count(distinct maaned), max(maaned)
    into rader, maaneder, siste
    from public.v_kurs_maanedstall;

  select count(*) into tomme
    from public.v_kurs_maanedstall
   where maaned = siste and omsetning_kr = 0;

  raise notice '0205: % rader over % maaneder, siste %', rader, maaneder, siste;
  raise notice '0205: stasjoner uten omsetning i siste maaned: % (skal vaere 0)', tomme;
end $$;
