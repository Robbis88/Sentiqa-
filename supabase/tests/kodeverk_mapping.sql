-- =====================================================================
-- BP <-> REGNSKAP <-> SALGSDATA: moeter kodene hverandre?
-- =====================================================================
--
-- KUN LESING. Ingen views, ingen writes, ingen migrasjon.
--
-- TO MAANEDER, IKKE EN - OG DET ER SELVE POENGET.
--
-- Foerste utgave sammenlignet BP og regnskap i SAMME maaned og fikk
-- null rader. Aarsaken er ikke en feil, men en beslutning i importen:
-- `bp_*`-linjene skrives BARE for maaneder som ennaa ikke er avlagt.
-- Er maaneden laast, baerer regnskapet sitt eget budsjett, og
-- BP-radene ville vaert en dublett (kjerne.ts:748).
--
--   BP        finnes for kommende maaneder      (juli-desember 2026)
--   REGNSKAP  finnes for avlagte maaneder       (des 2025 - juni 2026)
--
-- De moetes aldri i tid. Derfor sammenlignes KODEVERKENE her, ikke
-- maanedstallene: BP fra en aapen maaned mot regnskapet fra en avlagt.
-- Spoersmaalet er om «120» betyr det samme i de to filene - ikke om
-- august stemmer med juni.
--
-- Tre kodekilder, tre ulike filer:
--
--   BP        kolonnen `varekategori`, «120 [Mat]» -> kode 120
--             (src/lib/parsere/bp.ts:95)
--   REGNSKAP  per-stasjon-arket, radene med nivaa «Gr», kolonne 1
--             (src/lib/parsere/regnskap.ts:230)
--   SALGSDATA drilldown, TRE nivaaer, hver «<kode> <navn>»
--             (src/lib/parsere/salgsstatistikk.ts:77-85)
--
-- IKKE ANTA AT `varegruppe_kode` ER RIKTIG NIVAA fordi navnet sier
-- varegruppe. Alle tre nivaaene sjekkes, og spoerringen sier hvilke som
-- treffer. Antallslinjene tyder allerede paa at BP ligger paa det grove
-- nivaaet: 8-11 BP-linjer mot 86-95 varegrupper.
--
-- DEN FARLIGSTE UTGANGEN ER IKKE «ingen match». Den er TVETYDIG: samme
-- kode paa flere salgsnivaaer. Da SER koblingen riktig ut, ett av
-- navnene stemmer sannsynligvis, og feilen viser seg som tall som
-- nesten stemmer. TVETYDIG rangeres derfor over alt annet - ogsaa naar
-- ett navn ser riktig ut.
-- =====================================================================

with valg as (
  -- ▼▼▼ ENDRE DISSE ▼▼▼
  select '9467'::text      as butikknummer,  -- 4177 4185 9038 9145 9467
         date '2026-08-01' as bp_maned,      -- en maaned MED BP (jul-des)
         date '2026-06-01' as regn_maned     -- en maaned MED regnskap (des-jun)
  -- ▲▲▲ ENDRE DISSE ▲▲▲
),
st as (
  select s.id, s.butikknummer
  from public.stasjoner s, valg v
  where s.butikknummer = v.butikknummer and s.slettet_tid is null
  limit 1
),

bp as (
  select r.kode,
         min(r.post)                                                as post,
         sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')  as bp_omsetning,
         sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste') as bp_brutto
  from public.regnskapslinjer r, st, valg v
  where r.stasjon_id = st.id and r.periode = v.bp_maned
    and r.seksjon in ('bp_omsetning', 'bp_bruttofortjeneste')
    and r.kode is not null
  group by r.kode
),

-- Regnskapet baerer BAADE faktisk og budsjett paa samme rad. For en
-- avlagt maaned er det DER maanedsbudsjettet ligger.
regn as (
  select r.kode,
         min(r.post)                                              as post,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')   as regn_omsetning,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste') as regn_brutto,
         sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste') as regn_bruttobudsjett
  from public.regnskapslinjer r, st, valg v
  where r.stasjon_id = st.id and r.periode = v.regn_maned
    and r.seksjon in ('omsetning', 'bruttofortjeneste')
    and r.kode is not null
  group by r.kode
),

-- Salgsdata fra BP-maaneden: det er den vi faktisk skal maale mot BP.
salg as (
  select distinct 'avdeling'::text as nivaa,
         d.avdeling_kode as kode, d.avdeling_navn as navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.bp_maned and d.dato < (v.bp_maned + interval '1 month')
    and d.avdeling_kode is not null
  union
  select distinct 'vareomrade', d.vareomrade_kode, d.vareomrade_navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.bp_maned and d.dato < (v.bp_maned + interval '1 month')
    and d.vareomrade_kode is not null
  union
  select distinct 'varegruppe', d.varegruppe_kode, d.varegruppe_navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.bp_maned and d.dato < (v.bp_maned + interval '1 month')
    and d.varegruppe_kode is not null
),

koder as (
  select kode from bp
  union select kode from regn
  union select kode from salg
),

sammen as (
  select k.kode,
         b.post as bp_navn, b.bp_omsetning, b.bp_brutto,
         g.post as regnskap_navn, g.regn_omsetning, g.regn_brutto, g.regn_bruttobudsjett,
         (select string_agg(s.nivaa || ': ' || coalesce(s.navn, '(uten navn)'),
                            '  |  ' order by s.nivaa)
          from salg s where s.kode = k.kode)                 as salgstreff,
         (select count(*)  from salg s where s.kode = k.kode) as antall_nivaa,
         (select min(s.nivaa) from salg s where s.kode = k.kode) as eneste_nivaa,
         (select min(s.navn)  from salg s where s.kode = k.kode) as eneste_navn
  from koder k
  left join bp   b on b.kode = k.kode
  left join regn g on g.kode = k.kode
),
-- Navnesammenligningen staar for seg selv: den brukes tre steder, og en
-- kopiert regexp som gaar fra hverandre er nettopp slik en kontroll
-- slutter aa kontrollere.
dom as (
  select s.*,
         lower(regexp_replace(coalesce(bp_navn, ''),       '^\d+\s*', '')) as bp_rent,
         lower(regexp_replace(coalesce(regnskap_navn, ''), '^\d+\s*', '')) as regn_rent,
         lower(coalesce(eneste_navn, ''))                                  as salg_rent
  from sammen s
)
select
  kode,
  bp_navn,
  round(bp_omsetning)        as bp_omsetning,
  round(bp_brutto)           as bp_brutto,
  regnskap_navn,
  round(regn_omsetning)      as regn_omsetning,
  round(regn_brutto)         as regn_brutto,
  round(regn_bruttobudsjett) as regn_bruttobudsjett,
  salgstreff,
  eneste_nivaa               as salgsnivaa,
  case
    when antall_nivaa > 1                                        then 'TVETYDIG'
    when bp_navn is not null and regnskap_navn is not null
     and bp_rent <> regn_rent                                    then 'NAVNEKONFLIKT'
    when bp_navn is not null and antall_nivaa = 1
     and salg_rent <> '' and bp_rent <> salg_rent                then 'NAVNEKONFLIKT'
    when antall_nivaa = 0                                        then 'MANGLER_SALG'
    when bp_navn is null                                         then 'MANGLER_BP'
    when regnskap_navn is null                                   then 'MANGLER_REGNSKAP'
    else                                                              'SIKKER'
  end as klassifisering
from dom
order by
  case
    when antall_nivaa > 1                                        then 1
    when bp_navn is not null and regnskap_navn is not null
     and bp_rent <> regn_rent                                    then 2
    when bp_navn is not null and antall_nivaa = 1
     and salg_rent <> '' and bp_rent <> salg_rent                then 2
    when antall_nivaa = 0                                        then 3
    when bp_navn is null or regnskap_navn is null                then 4
    else                                                              5
  end,
  kode;
