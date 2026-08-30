-- =====================================================================
-- HVA HAR VI EGENTLIG AV BP I BASEN?
--
-- Leser kun. Svarer paa tre ting foer vi bygger noe:
--
--   1. Hvilke AAR finnes det budsjett for? Ligger 2025 der alt, trenger
--      vi ikke lese BP-filer - da er hele sammenligningen en spoerring.
--   2. Hvilke SEKSJONER brukes, og hvilke av dem baerer budsjettet?
--   3. Dekker hvert aar alle fem stasjonene, eller er det hull?
--
-- Hull er selve poenget her. Lone ble overtatt 01.02.25 og Dale 01.04.25,
-- saa et aar som mangler maaneder for dem er ikke en feil - men det maa
-- SEES foer noen sammenligner en delaars-BP med en helaars-BP og kaller
-- forskjellen en utvikling.
-- =====================================================================

with linjer as (
  select r.stasjon_id,
         s.butikknummer,
         s.navn                                   as stasjon,
         extract(year from r.periode)::int        as aar,
         r.seksjon,
         r.periode,
         r.budsjett,
         r.regnskap
  from public.regnskapslinjer r
  left join public.stasjoner s on s.id = r.stasjon_id
  where r.slettet_tid is null
    and r.kode is not null
)

-- ---- 1. Aar og seksjon: hva finnes, og har det tall? ---------------
select 'AAR OG SEKSJON'::text                     as del,
       (aar || ' ' || seksjon)::text              as noekkel,
       ('linjer=' || count(*)
         || '  m/budsjett=' || count(budsjett)
         || '  m/regnskap=' || count(regnskap)
         || '  maaneder=' || count(distinct periode))::text as verdi,
       1::int as sort
from linjer
group by aar, seksjon

union all

-- ---- 2. Dekker aaret alle stasjonene? ------------------------------
-- En stasjon som mangler helt, eller som bare har noen maaneder, er det
-- viktigste enkeltfunnet i denne spoerringen.
select 'STASJONSDEKNING',
       (aar || ' ' || coalesce(butikknummer, '(uten stasjon)')
         || ' ' || coalesce(stasjon, ''))::text,
       ('maaneder=' || count(distinct periode)
         || '  fra ' || min(periode)::text
         || ' til ' || max(periode)::text
         || '  budsjett=' || round(coalesce(sum(budsjett), 0))::text)::text,
       2
from linjer
where seksjon in ('bp_omsetning', 'omsetning')
group by aar, butikknummer, stasjon

union all

-- ---- 3. Er det budsjett aa sammenligne mellom aar? -----------------
select 'SAMMENLIGNBART',
       'aar med bp_omsetning',
       string_agg(distinct aar::text, ', ' order by aar::text),
       3
from linjer
where seksjon = 'bp_omsetning' and budsjett is not null

union all

select 'SAMMENLIGNBART',
       'aar med omsetning (avlagt)',
       coalesce(string_agg(distinct aar::text, ', ' order by aar::text), '(ingen)'),
       3
from linjer
where seksjon = 'omsetning' and budsjett is not null

order by sort, noekkel;
