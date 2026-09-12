-- =====================================================================
-- 0210  LESERNE SKAL LESE ETT NIVAA, OG SI HVILKET
-- =====================================================================
-- `0208` ga `regnskap_usynlig_svinn` to nivaaer. Ingen av leserne kjenner
-- forskjellen, og det er riktig I DAG: tabellen har 588 rader, alle
-- produktrader. Foerste reimport endrer forutsetningen.
--
-- Da ligger grupperaden `120 Mat` i samme tabell som `12010`, `12020` …
-- og en `sum(usynlig_kr)` tar begge. Maalt paa en stasjonsmaaned i
-- fikstur: 140 kroner kast blir 280. Ingenting feiler, tallet blir bare
-- omtrent det dobbelte - og i tillegg kommer 19 drivstoffrader i
-- maaneden inn i `usynlig_rest_kr`, som filtrerer paa kode og ikke paa
-- omraade.
--
-- ---------------------------------------------------------------------
-- REGELEN LIGGER ETT STED, OGSAA I SQL
--
-- `v_svinn_grunnlag` velger grunnlag per **stasjonsmaaned** og slipper
-- gjennom rader fra det ene nivaaet valget landet paa:
--
--   finnes grupperad   -> bare grupperadene, `datastatus = 'gruppe'`
--   ellers             -> produktradene, `datastatus = 'eldre_grunnlag'`
--
-- Aldri begge. Valget er per stasjonsmaaned fordi to stasjoner kan ligge
-- i ulik fase midt i en reimport; ett felles valg ville regnet den ene
-- paa feil nivaa.
--
-- Samme regel staar i `src/lib/svinn/grunnlag.ts` for kodeleserne, med
-- `grunnlag.test.ts` som bevis. To implementasjoner av én regel er en
-- gjeld; de er skrevet fra samme tekst og skal rettes sammen.
--
-- ---------------------------------------------------------------------
-- OMRAADET: `butikk` ELLER `null`
--
-- `null` er de 588 eksisterende radene. `0208` etterfylte `nivaa`, men
-- IKKE `analyseomraade` - det krever gruppekodene fra arket. De skal
-- fortsatt regnes med, ellers ville dette viewet endret tall i dag, og
-- hele poenget er at det ikke gjoer det.
--
-- `drivstoff` og `ukjent` faller ut. De lagres navngitt og blokkeres.
--
-- ---------------------------------------------------------------------
-- FALLBACKEN ER MIDLERTIDIG
--
-- `eldre_grunnlag` er sant i dag og skal bli usant. Naar alle perioder er
-- reimportert, er en manglende grupperad et FUNN og ikke en fase. Da
-- strammes `case`-en til aa returnere `utilgjengelig`. Fallbacken skal
-- ikke faa skjule en ufullstendig import permanent.
--
-- ---------------------------------------------------------------------
-- IKKE KJOERT. Skrevet, testet lokalt, venter paa godkjenning.
--
-- Idempotent: `create or replace view` overalt, og `security_invoker`
-- staar eksplisitt paa hvert view - uten den leser viewet som eier,
-- forbi RLS, og `create or replace` nullstiller flagget i stillhet.
-- =====================================================================

-- ---------------------------------------------------------------------
-- GRUNNLAGET. Ett nivaa per stasjonsmaaned, med status.
-- ---------------------------------------------------------------------
create or replace view public.v_svinn_grunnlag
with (security_invoker = true) as
with i_spill as (
  select *
    from public.regnskap_usynlig_svinn
   where slettet_tid is null
     -- `null` = gammel rad. Se hodet: den skal med i fase 1.
     and (analyseomraade = 'butikk' or analyseomraade is null)
),
valg as (
  select retailer_id,
         stasjon_id,
         periode,
         bool_or(nivaa = 'gruppe') as har_gruppe
    from i_spill
   group by retailer_id, stasjon_id, periode
)
select u.*,
       case when v.har_gruppe then 'gruppe' else 'eldre_grunnlag' end as datastatus
  from i_spill u
  join valg v
    on v.retailer_id = u.retailer_id
   -- `is not distinct from`: kjederader har `stasjon_id = null`, og `=`
   -- ville gjort hele joinen usann for dem.
   and v.stasjon_id is not distinct from u.stasjon_id
   and v.periode = u.periode
 where (v.har_gruppe and u.nivaa = 'gruppe')
    or (not v.har_gruppe and (u.nivaa = 'produkt' or u.nivaa is null));

grant select on public.v_svinn_grunnlag to authenticated;
revoke all on public.v_svinn_grunnlag from anon;

comment on view public.v_svinn_grunnlag is
  'Svinnrader fra ETT nivaa per stasjonsmaaned: grupperadene naar de '
  'finnes, ellers produktradene. `datastatus` sier hvilket. Ingen '
  'analyse skal lese `regnskap_usynlig_svinn` direkte for en SUM - da '
  'dobbeltelles gruppe og produkt. Samme regel i src/lib/svinn/grunnlag.ts.';

-- ---------------------------------------------------------------------
-- 1) `svinn_sum` - konsumert av regnskapsanalyse.ts og regnskap-varsler.ts
--
-- `drop` foerst: `create or replace` kan ikke endre `returns table`, og
-- signaturen utvides med `datastatus` slik at kalleren kan se grunnlaget.
-- ---------------------------------------------------------------------
drop function if exists public.svinn_sum(date, date);

create function public.svinn_sum(p_fra date, p_til date)
returns table(
  stasjon_id  uuid,
  kode        text,
  navn        text,
  salg        numeric,
  usynlig_kr  numeric,
  kast        numeric,
  datastatus  text
)
language sql
security invoker
set search_path = public
as $$
  select stasjon_id, kode, navn,
         sum(salg), sum(usynlig_kr), sum(kast),
         -- DEN SVAKESTE STATUSEN VINNER over intervallet: er én maaned
         -- paa eldre grunnlag, er summen det. Skrevet som `bool_or` og
         -- ikke `min(datastatus)` - sistnevnte ville virket bare fordi
         -- «eldre_grunnlag» tilfeldigvis sorterer foer «gruppe», og en
         -- ny statusverdi ville stille endret hvem som vinner.
         case when bool_or(datastatus = 'eldre_grunnlag')
              then 'eldre_grunnlag' else 'gruppe' end as datastatus
    from public.v_svinn_grunnlag
   where periode between p_fra and p_til
   group by stasjon_id, kode, navn
$$;

grant execute on function public.svinn_sum(date, date) to authenticated;

comment on function public.svinn_sum(date, date) is
  'Summerer svinn per stasjon og kode over et intervall, fra '
  'v_svinn_grunnlag - altsaa ETT nivaa per stasjonsmaaned. `datastatus` '
  'er den svakeste i intervallet: «eldre_grunnlag» betyr at minst én '
  'maaned ikke er reimportert ennaa.';

-- ---------------------------------------------------------------------
-- 2) `v_kurs_maanedstall` - maanedsplanene og Kursen
--
-- HENTET UORDRET FRA `0206`, med ÉN endring: kilden i `svinn`-CTE-en er
-- `v_svinn_grunnlag` i stedet for tabellen. `matkast_kr` filtrerer paa
-- `kode like '12%'`, som treffer BAADE `120` og `12010` - det er her
-- dobbeltellingen ville slaatt inn.
-- ---------------------------------------------------------------------
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
  from public.v_svinn_grunnlag s
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

-- ---------------------------------------------------------------------
-- 3) `v_kaffe_svinn`
--
-- HENTET UORDRET FRA `0126`, samme ene endring. Her filtrerer den paa
-- `left(kode, 3) = '130'`, som treffer grupperaden `130` i tillegg til
-- `13010` og `13011` - og grupperaden ville havnet i `annet_kr`, altsaa
-- «alt annet enn kaffe og lojalitet», som er hele gruppen om igjen.
--
-- `create view` er byttet til `create or replace view`: kolonnesettet er
-- uendret, og da trengs ingen `drop`. Advarselen i `0126` gjelder
-- navnebytte, og det er ikke det som skjer her.
-- ---------------------------------------------------------------------
create or replace view public.v_kaffe_svinn
with (security_invoker = true) as

with svinn as (
  select u.retailer_id,
         u.stasjon_id,
         date_trunc('year', u.periode)::date                        as aar,
         count(distinct u.periode)                                  as maaneder,
         min(u.periode)                                             as fra,
         max(u.periode)                                             as til,
         sum(u.usynlig_kr) filter (where u.kode = '13010')          as kaffe_kr,
         sum(u.usynlig_kr) filter (where u.kode = '13011')          as lojalitet_kr,
         sum(u.usynlig_kr) filter (
           where u.kode not in ('13010', '13011'))                  as annet_kr,
         -- + manko, - overskudd. Se `0049`.
         sum(u.usynlig_kr)                                          as mangler_kr
  from public.v_svinn_grunnlag u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and left(u.kode, 3) = '130'
  group by u.retailer_id, u.stasjon_id, date_trunc('year', u.periode)
),

-- Den mest utdelte varen per stasjon og aar, med hva lageret justeres
-- med per kopp. `distinct on` + `order by antall desc` gir den varen som
-- faktisk deles ut oftest - varselet navngir den, saa det er DENS pris
-- som hoerer til antallet.
vanligste as (
  select distinct on (stasjon_id, aar)
         stasjon_id,
         aar,
         varenavn,
         kr_per_kopp
  from (
    select v.stasjon_id,
           date_trunc('year', v.dato)::date        as aar,
           v.varenavn,
           sum(v.antall)                           as antall,
           case when sum(v.antall) > 0
                then round(-sum(v.bto_fortjeneste_kr) / sum(v.antall), 2)
           end                                     as kr_per_kopp
    from public.v_butikksalg v
    where v.avdeling_kode = '130'
      and v.varenavn ilike '%FYLL%'
    group by v.stasjon_id, date_trunc('year', v.dato), v.varenavn
  ) t
  where antall > 0 and kr_per_kopp > 0
  order by stasjon_id, aar, antall desc
)

select s.retailer_id,
       s.stasjon_id,
       s.aar,
       s.maaneder,
       s.fra,
       s.til,
       round(s.kaffe_kr)                                 as kaffe_kr,
       round(s.lojalitet_kr)                             as lojalitet_kr,
       round(s.annet_kr)                                 as annet_kr,
       -- DOMMEN. Positiv = justering som mangler.
       round(s.mangler_kr)                               as mangler_kr,
       -- Hvor stor del av utdelingen som ikke er slaatt inn. Null naar
       -- det ikke er registrert utdeling i det hele tatt - da finnes
       -- ingen andel, og «100 %» ville vaert et paafunn.
       case when s.lojalitet_kr < 0
            then round(100 * s.mangler_kr / -s.lojalitet_kr, 1)
       end                                               as andel_ujustert_pst,
       v.varenavn                                        as vanligste_paafyll,
       v.kr_per_kopp,
       case when v.kr_per_kopp > 0 and s.mangler_kr > 0
            then round(s.mangler_kr / v.kr_per_kopp)
       end                                               as maa_slaas_inn
from svinn s
left join vanligste v
  on v.stasjon_id = s.stasjon_id
 and v.aar = s.aar;

grant select on public.v_kaffe_svinn to authenticated;
revoke all on public.v_kaffe_svinn from anon;

-- ---------------------------------------------------------------------
-- Kvittering SOM SELECT. `raise notice` vises ikke i SQL Editor.
--
-- Forventet paa dagens data: `gruppe` = 0, `eldre_grunnlag` = 588,
-- og radantallet i viewet skal vaere IDENTISK med tabellen, fordi
-- ingen periode har grupperader ennaa.
-- ---------------------------------------------------------------------
select
  (select count(*) from public.regnskap_usynlig_svinn where slettet_tid is null) as i_tabellen,
  (select count(*) from public.v_svinn_grunnlag)                                 as i_grunnlaget,
  (select count(*) from public.v_svinn_grunnlag where datastatus = 'gruppe')      as paa_gruppe,
  (select count(*) from public.v_svinn_grunnlag where datastatus = 'eldre_grunnlag') as paa_eldre,
  (select count(distinct (stasjon_id, periode)) from public.v_svinn_grunnlag)     as stasjonsmaaneder;
