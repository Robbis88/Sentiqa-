-- =====================================================================
-- Moeter kodene hverandre? BP <-> regnskap <-> salgsdata
-- =====================================================================
--
-- Kun lesing. Trygg i produksjon.
--
-- SPOERSMAALET: kan vi stille BP-budsjett, faktisk salg og de to
-- brutto-perspektivene side om side PER VAREGRUPPE - eller sammenligner
-- vi epler med paerer fordi kodeverkene er ulike?
--
-- Tre kodekilder, tre ulike filer:
--
--   BP            kolonnen `varekategori`, formen «120 [Mat]» -> kode 120
--                 (src/lib/parsere/bp.ts:95)
--   REGNSKAP      per-stasjon-arket, radene med nivaa «Gr», kolonne 1
--                 (src/lib/parsere/regnskap.ts:230)
--   SALGSDATA     drilldown-rapporten, tre nivaaer, hver «<kode> <navn>»
--                 (src/lib/parsere/salgsstatistikk.ts:77-85)
--
-- BP-parseren PAASTAAR at den deler kodeverk med regnskapet: «Formen
-- matcher den regnskapslinjer allerede bruker, saa BP og regnskap kan
-- stilles side om side.» Paastanden er aldri etterproevd - ingenting har
-- noen gang lest `bp_bruttofortjeneste`.
--
-- DEN FARLIGSTE UTGANGEN ER IKKE «ingen match». Den er TVETYDIG match:
-- numeriske koder kan kollidere paa tvers av nivaaer, saa «10» kan vaere
-- baade en avdeling og et vareomraade. Da ser en kobling riktig ut og er
-- det ikke, og feilen viser seg som tall som nesten stemmer.
-- =====================================================================
with bp as (
  select kode, min(post) as post
  from public.regnskapslinjer
  where seksjon = 'bp_omsetning' and kode is not null
  group by kode
),
regn as (
  select kode, min(post) as post
  from public.regnskapslinjer
  where seksjon = 'bruttofortjeneste' and kode is not null
  group by kode
),
-- Salgsdata begrenses til siste 90 dager: tabellen er partisjonert og
-- stor, og kodeverket endrer seg ikke bakover i tid.
salg as (
  select distinct
         'varegruppe'::text as nivaa, varegruppe_kode as kode, varegruppe_navn as navn
  from public.daglig_salg
  where slettet_tid is null and dato >= current_date - 90 and varegruppe_kode is not null
  union
  select distinct 'vareomrade', vareomrade_kode, vareomrade_navn
  from public.daglig_salg
  where slettet_tid is null and dato >= current_date - 90 and vareomrade_kode is not null
  union
  select distinct 'avdeling', avdeling_kode, avdeling_navn
  from public.daglig_salg
  where slettet_tid is null and dato >= current_date - 90 and avdeling_kode is not null
),
koder as (
  select kode from bp
  union select kode from regn
  union select kode from salg
),
sammen as (
  select k.kode,
         b.post as bp_post,
         r.post as regnskap_post,
         (select string_agg(distinct s.nivaa || ': ' || coalesce(s.navn, '?'), ' | ' order by s.nivaa || ': ' || coalesce(s.navn, '?'))
          from salg s where s.kode = k.kode) as salg_treff,
         (select count(distinct s.nivaa) from salg s where s.kode = k.kode) as antall_nivaa
  from koder k
  left join bp   b on b.kode = k.kode
  left join regn r on r.kode = k.kode
)
select
  kode,
  bp_post,
  regnskap_post,
  salg_treff,
  case
    -- TVETYDIG foerst: den er verre enn en manglende match, fordi den
    -- ser ut som en treffer.
    when antall_nivaa > 1                                   then 'TVETYDIG - koden finnes paa flere salgsnivaaer'
    when bp_post is not null and regnskap_post is not null
     and antall_nivaa = 1                                   then 'SIKKER - BP + regnskap + ett salgsnivaa'
    when bp_post is not null and regnskap_post is not null
     and antall_nivaa = 0                                   then 'MANGLER SALG - finnes i BP og regnskap, ikke i salgsdata'
    when bp_post is not null and regnskap_post is null      then 'MANGLER REGNSKAP - kun BP'
    when bp_post is null and regnskap_post is not null      then 'MANGLER BP - kun regnskap'
    else                                                         'KUN SALGSDATA - hverken BP eller regnskap'
  end as status,
  -- Navnene skal ligne. Gjor de ikke det, er koden gjenbrukt til noe
  -- annet i en av filene, og da hjelper det ikke at tallet stemmer.
  case
    when bp_post is null or regnskap_post is null then null
    when lower(regexp_replace(bp_post, '^\d+\s*', '')) =
         lower(regexp_replace(regnskap_post, '^\d+\s*', '')) then 'navn like'
    else 'NAVN ULIKE - sjekk om koden betyr det samme'
  end as navnekontroll
from sammen
order by
  case
    when antall_nivaa > 1 then 1
    when bp_post is not null and regnskap_post is not null and antall_nivaa = 1 then 4
    else 2
  end,
  kode;
