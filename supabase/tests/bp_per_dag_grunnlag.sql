-- =====================================================================
-- GRUNNLAGET FOR BP PER DAG - LESER KUN, ENDRER INGENTING
--
-- Henter de tre tallene demoen trenger for aa slutte aa vaere oppdiktet:
--
--   BP              budsjettet for maaneden, per avdeling
--   FJOR            motpartsvinduet, dag for dag
--   SALG            det som faktisk er omsatt denne maaneden
--
-- MOTPARTSVINDUET ER IKKE AUGUST I FJOR. Hver dag i august 2026 peker
-- 364 dager tilbake - 52 uker, saa ukedagen alltid stemmer. Det vinduet
-- er 2025-08-02 .. 2025-09-01, ikke august 2025. Spor man om august, faar
-- man et tall som er nesten riktig, og «nesten» er det verste et
-- budsjettall kan vaere.
--
-- Radene er per DAG for hele stasjonen, ikke per dag og avdeling - det
-- ville blitt seks hundre rader aa lime tilbake. BP staar per avdeling,
-- for det er der den finnes.
--
-- Bytt stasjon og maaned paa de to linjene under om du vil se en annen.
-- =====================================================================

with valg as (
  select '4185'::text          as butikknummer,
         date '2026-08-01'     as maaned
),

periode as (
  select v.butikknummer,
         v.maaned,
         (v.maaned + interval '1 month - 1 day')::date as maaned_slutt,
         (v.maaned - 364)                              as fjor_fra,
         ((v.maaned + interval '1 month - 1 day')::date - 364) as fjor_til
  from valg v
),

st as (
  select s.id, s.butikknummer, s.navn
  from public.stasjoner s
  join periode p on p.butikknummer = s.butikknummer
  where s.slettet_tid is null
)

-- ---- 1. BP for maaneden, per avdeling ------------------------------
-- Avlagt foerst, aapen som reserve - samme regel som
-- `v_bp_status_avdeling` bruker tre steder. Kodene 10 (drivstoff),
-- 250 (pant) og 40 (grand total) er ute, som avtalt.
select 'BP'::text                                    as type,
       r.kode                                        as kode,
       min(r.post)                                   as navn,
       null::date                                    as dato,
       round(coalesce(
         sum(r.budsjett) filter (where r.seksjon = 'omsetning'),
         sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')
       ), 0)                                         as kr
from public.regnskapslinjer r
join st on st.id = r.stasjon_id
join periode p on p.maaned = r.periode
where r.slettet_tid is null
  and r.kode is not null
  and r.kode not in ('10', '250', '40')
  and r.seksjon in ('omsetning', 'bp_omsetning')
group by r.kode
having coalesce(
         sum(r.budsjett) filter (where r.seksjon = 'omsetning'),
         sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')
       ) is not null

union all

-- ---- 2. Fjoraaret, dag for dag, i MOTPARTSVINDUET ------------------
select 'FJOR',
       null,
       to_char(v.dato, 'Dy'),
       v.dato,
       round(sum(v.omsetning), 0)
from public.v_salg_per_avdeling_dag v
join st on st.id = v.stasjon_id
join periode p on v.dato between p.fjor_fra and p.fjor_til
where v.avdeling_kode not in ('10', '250', '40')
group by v.dato

union all

-- ---- 3. Det som faktisk er omsatt denne maaneden -------------------
select 'SALG',
       null,
       to_char(v.dato, 'Dy'),
       v.dato,
       round(sum(v.omsetning), 0)
from public.v_salg_per_avdeling_dag v
join st on st.id = v.stasjon_id
join periode p on v.dato between p.maaned and p.maaned_slutt
where v.avdeling_kode not in ('10', '250', '40')
group by v.dato

order by 1, 4 nulls first, 5 desc nulls last;
