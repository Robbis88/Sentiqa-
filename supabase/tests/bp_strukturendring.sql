-- =====================================================================
-- HVA ENDRET SEG I STRUKTUREN FRA 2025 TIL 2026?
--
-- Leser kun.
--
-- «det kan vaere de endrer paa ting fra aar til aar, fjerner
--  drivstoff kommisjon, legger til noe annet osv.» - Robert 2026-08-29
--
-- Det er nettopp derfor denne spoerringen ikke joiner aarene og viser
-- differansen. En INNER JOIN ville droppet hver linje som forsvant, og
-- hver linje som kom til - i stillhet. Det som forsvinner er ofte det
-- viktigste.
--
-- FULL OUTER JOIN, og hver rad faar en STATUS: staar den i begge aar, er
-- den ny, eller er den borte.
--
-- ---------------------------------------------------------------------
-- SEKSJONSNAVNENE ER ULIKE MELLOM AARENE
--
-- 2025 har `omsetning`, `bruttofortjeneste`, `driftskostnader`.
-- 2026 har de samme PLUSS `bp_omsetning`, `bp_bruttofortjeneste` og
-- `bp_kostnad` - den siste finnes ikke i 2025 i det hele tatt.
--
-- Sammenlignes seksjonsnavnene raatt, ser hele 2026 ut som nytt. De
-- normaliseres derfor til tre grupper, og BUDSJETTET tas fra den
-- seksjonen som baerer det: `bp_*` naar den finnes, ellers den avlagte.
-- Det er samme regel som `v_bp_status_avdeling` bruker.
--
-- KLYNGERADENE ER MED, merket «(uten stasjon)». De baerer 85 mill i 2026
-- og maa ikke stilltiende summeres inn i stasjonene - men de maa heller
-- ikke forsvinne.
-- =====================================================================

with normalisert as (
  select case
           when r.seksjon in ('omsetning', 'bp_omsetning')                 then 'omsetning'
           when r.seksjon in ('bruttofortjeneste', 'bp_bruttofortjeneste') then 'brutto'
           when r.seksjon in ('driftskostnader', 'bp_kostnad')             then 'kostnad'
           else r.seksjon
         end                                        as gruppe,
         r.seksjon,
         r.kode,
         min(r.post)                                as post,
         extract(year from r.periode)::int          as aar,
         -- Aapen BP foerst, avlagt som reserve - samme rekkefolge som
         -- v_bp_status_avdeling. Summeres begge, dobbelttelles aaret.
         sum(r.budsjett) filter (where r.seksjon like 'bp\_%')  as bp_aapen,
         sum(r.budsjett) filter (where r.seksjon not like 'bp\_%') as bp_avlagt
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode is not null
    and extract(year from r.periode) in (2025, 2026)
  group by 1, 2, 3, 5
),

per_aar as (
  select gruppe, kode, min(post) as post, aar,
         sum(coalesce(bp_aapen, bp_avlagt)) as budsjett,
         string_agg(distinct seksjon, '+' order by seksjon) as seksjoner
  from normalisert
  group by gruppe, kode, aar
),

f as (select * from per_aar where aar = 2025),
t as (select * from per_aar where aar = 2026)

select case
         when f.kode is null then 'NY I 2026'
         when t.kode is null then 'BORTE I 2026'
         else 'BEGGE AAR'
       end::text                                            as status,
       coalesce(f.gruppe, t.gruppe)::text                   as gruppe,
       (coalesce(f.kode, t.kode) || ' '
         || coalesce(f.post, t.post, ''))::text             as konto,
       round(coalesce(f.budsjett, 0))::text                 as bp_2025,
       round(coalesce(t.budsjett, 0))::text                 as bp_2026,
       case
         when f.budsjett is null or f.budsjett = 0 then '—'
         when t.budsjett is null then '−100 %'
         else round((t.budsjett / f.budsjett - 1) * 100, 1)::text || ' %'
       end::text                                            as endring,
       (coalesce(f.seksjoner, '-') || ' → '
         || coalesce(t.seksjoner, '-'))::text               as seksjoner
from f
full outer join t on t.gruppe = f.gruppe and t.kode = f.kode
order by
  case
    when f.kode is null then 1      -- nye foerst, de er lettest aa overse
    when t.kode is null then 2
    else 3
  end,
  coalesce(f.gruppe, t.gruppe),
  abs(coalesce(t.budsjett, 0) - coalesce(f.budsjett, 0)) desc;
