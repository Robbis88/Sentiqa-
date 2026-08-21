-- =====================================================================
-- BP <-> REGNSKAP <-> SALGSDATA: moeter kodene hverandre?
-- =====================================================================
--
-- KUN LESING. Ingen views, ingen writes, ingen migrasjon.
--
-- SPOERSMAALET: kan vi stille BP-budsjett, faktisk salg og de to
-- brutto-perspektivene side om side PER GRUPPE - eller sammenligner vi
-- epler med paerer fordi kodeverkene er ulike?
--
-- Tre kodekilder, tre ulike filer:
--
--   BP         kolonnen `varekategori`, «120 [Mat]» -> kode 120
--              (src/lib/parsere/bp.ts:95)
--   REGNSKAP   per-stasjon-arket, radene med nivaa «Gr», kolonne 1
--              (src/lib/parsere/regnskap.ts:230)
--   SALGSDATA  drilldown, TRE nivaaer, hver «<kode> <navn>»
--              (src/lib/parsere/salgsstatistikk.ts:77-85)
--
-- BP-parseren PAASTAAR at den deler kodeverk med regnskapet: «Formen
-- matcher den regnskapslinjer allerede bruker, saa BP og regnskap kan
-- stilles side om side.» Paastanden er aldri etterproevd - ingenting har
-- noen gang lest `bp_bruttofortjeneste`.
--
-- IKKE ANTA AT `varegruppe_kode` ER RIKTIG NIVAA fordi navnet sier
-- varegruppe. Spoerringen sjekker ALLE TRE nivaaene og sier hvilke som
-- treffer.
--
-- DEN FARLIGSTE UTGANGEN ER IKKE «ingen match». Den er TVETYDIG: samme
-- kode paa flere salgsnivaaer. Da SER koblingen riktig ut, ett av
-- navnene stemmer sannsynligvis, og feilen viser seg som tall som
-- nesten stemmer. Derfor rangeres TVETYDIG over alt annet - ogsaa naar
-- ett navn ser riktig ut.
-- =====================================================================

with valg as (
  -- ▼▼▼ ENDRE DISSE TO ▼▼▼
  select '5101'::text        as butikknummer,   -- stasjonen du vil se
         date '2026-08-01'   as maned           -- foerste dag i maaneden
  -- ▲▲▲ ENDRE DISSE TO ▲▲▲
),
st as (
  select s.id, s.butikknummer, s.retailer_id
  from public.stasjoner s, valg v
  where s.butikknummer = v.butikknummer and s.slettet_tid is null
  limit 1
),

-- --- BP: budsjett per gruppe for maaneden ---------------------------
bp as (
  select r.kode,
         min(r.post)                                      as post,
         sum(case when r.seksjon = 'bp_omsetning'
                  then r.budsjett end)                    as bp_omsetning,
         sum(case when r.seksjon = 'bp_bruttofortjeneste'
                  then r.budsjett end)                    as bp_brutto
  from public.regnskapslinjer r, st, valg v
  where r.stasjon_id = st.id
    and r.periode = v.maned
    and r.seksjon in ('bp_omsetning', 'bp_bruttofortjeneste')
    and r.kode is not null
  group by r.kode
),

-- --- REGNSKAP: faktisk per gruppe for maaneden ----------------------
-- Merk at BEGGE seksjonene skrives fra samme rad i per-stasjon-arket,
-- med samme kode - saa omsetning og brutto her hoerer sammen.
regn as (
  select r.kode,
         min(r.post)                                      as post,
         sum(case when r.seksjon = 'omsetning'
                  then r.regnskap end)                    as regn_omsetning,
         sum(case when r.seksjon = 'bruttofortjeneste'
                  then r.regnskap end)                    as regn_brutto
  from public.regnskapslinjer r, st, valg v
  where r.stasjon_id = st.id
    and r.periode = v.maned
    and r.seksjon in ('omsetning', 'bruttofortjeneste')
    and r.kode is not null
  group by r.kode
),

-- --- SALGSDATA: alle tre nivaaer, samme maaned ----------------------
salg as (
  select distinct 'avdeling'::text as nivaa,
         d.avdeling_kode as kode, d.avdeling_navn as navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.maned and d.dato < (v.maned + interval '1 month')
    and d.avdeling_kode is not null
  union
  select distinct 'vareomrade', d.vareomrade_kode, d.vareomrade_navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.maned and d.dato < (v.maned + interval '1 month')
    and d.vareomrade_kode is not null
  union
  select distinct 'varegruppe', d.varegruppe_kode, d.varegruppe_navn
  from public.daglig_salg d, st, valg v
  where d.stasjon_id = st.id and d.slettet_tid is null
    and d.dato >= v.maned and d.dato < (v.maned + interval '1 month')
    and d.varegruppe_kode is not null
),

koder as (
  select kode from bp
  union select kode from regn
  union select kode from salg
),

sammen as (
  select k.kode,
         b.post           as bp_navn,
         b.bp_omsetning,
         b.bp_brutto,
         g.post           as regnskap_navn,
         g.regn_omsetning,
         g.regn_brutto,
         (select string_agg(s.nivaa || ': ' || coalesce(s.navn, '(uten navn)'),
                            '  |  ' order by s.nivaa)
          from salg s where s.kode = k.kode)                as salgstreff,
         (select count(*) from salg s where s.kode = k.kode) as antall_nivaa,
         (select min(s.nivaa) from salg s where s.kode = k.kode) as eneste_nivaa,
         (select min(s.navn) from salg s where s.kode = k.kode) as eneste_navn
  from koder k
  left join bp   b on b.kode = k.kode
  left join regn g on g.kode = k.kode
)
select
  kode,
  bp_navn,
  round(bp_omsetning)   as bp_omsetning,
  round(bp_brutto)      as bp_brutto,
  regnskap_navn,
  round(regn_omsetning) as regn_omsetning,
  round(regn_brutto)    as regn_brutto,
  salgstreff,
  eneste_nivaa          as salgsnivaa,
  case
    -- TVETYDIG FOERST. Verre enn ingen match, fordi den ser ut som en.
    when antall_nivaa > 1 then 'TVETYDIG'
    -- NAVNEKONFLIKT foer SIKKER: stemmer tallet men ikke navnet, er
    -- koden gjenbrukt til noe annet i en av filene.
    when bp_navn is not null and regnskap_navn is not null
     and lower(regexp_replace(bp_navn,       '^\d+\s*', '')) <>
         lower(regexp_replace(regnskap_navn, '^\d+\s*', ''))
      then 'NAVNEKONFLIKT'
    when bp_navn is not null and regnskap_navn is not null
     and antall_nivaa = 1
     and eneste_navn is not null
     and lower(regexp_replace(bp_navn, '^\d+\s*', '')) <> lower(eneste_navn)
      then 'NAVNEKONFLIKT'
    when antall_nivaa = 0                             then 'MANGLER_SALG'
    when bp_navn is null                              then 'MANGLER_BP'
    when regnskap_navn is null                        then 'MANGLER_REGNSKAP'
    else                                                   'SIKKER'
  end as klassifisering
from sammen
order by
  case
    when antall_nivaa > 1                                       then 1
    when bp_navn is not null and regnskap_navn is not null
     and lower(regexp_replace(bp_navn,       '^\d+\s*', '')) <>
         lower(regexp_replace(regnskap_navn, '^\d+\s*', ''))    then 2
    when antall_nivaa = 0                                       then 3
    when bp_navn is null or regnskap_navn is null               then 4
    else                                                             5
  end,
  kode;
