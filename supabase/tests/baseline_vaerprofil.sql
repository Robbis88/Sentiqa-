-- =====================================================================
-- BASELINE FOER VAERPROFIL-BUGFIXEN
--
-- `beregn_vaerprofil` (0068) skal etter sin egen kommentar regne paa
-- "butikkomsetning (eks drivstoff/pant)". Den filtrerer paa
-- `avdeling_kode not in ('10','250')` - og baselinen 2026-08-28 viste at
-- drivstoff har kode **1000**. Filteret treffer ingenting.
--
-- Funksjonen summerer omsetning per stasjon per dag over ALLE avdelinger
-- og korrelerer mot vaer. Med drivstoff paa 43-84 % av omsetningen maaler
-- den drivstoffets vaerfoelsomhet, ikke butikkens.
--
-- Trygg i produksjon: leser kun. Ingen skriving, ingen DDL.
--
-- ---------------------------------------------------------------------
-- HVORFOR BEGGE BEREGNES I SAMME SPOERRING
--
-- Vinduet er `current_date - interval '400 days'` - RULLENDE. Kjoerer vi
-- "foer" i dag og "etter" i morgen, har vinduet flyttet seg en dag, og
-- differansen blander bugfixen med en datoforskyvning.
--
-- Derfor regnes bade dagens og den rettede varianten her, paa samme
-- `current_date`, i samme spoerring. **Kolonnen `ny_folsomhet` er en
-- prediksjon**: den skal stemme med det `stasjoner.vaerfolsomhet_laert`
-- faktisk blir naar fixen kjoeres samme dag.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ER MED
--
-- `beregn_kategori_vaerprofil` (0070) staar ikke her. Den grupperer per
-- (stasjon, niva, kode) og regner korrelasjonen PER KODE - bakerienes
-- koeffisienter er allerede beregnet fra sine egne rader. Drivstoff faar
-- bare en egen rad som ingen leser. Buggen er reell, men uten virkning.
-- =====================================================================

with vindu as (
  select (current_date - interval '400 days')::date as fra,
         current_date                               as til
),

stasjon as (
  select s.id, s.butikknummer || ' ' || s.navn as navn, r.navn as kjede
  from public.stasjoner s
  join public.retailers r on r.id = s.retailer_id
  where s.slettet_tid is null
),

-- ---- Dagens inndata: alle avdelinger (buggen) ----------------------
dag_naa as (
  select ds.stasjon_id, ds.dato,
         extract(dow from ds.dato)::int as ukedag,
         sum(ds.omsetning_eks_mva)      as oms
  from public.daglig_salg ds, vindu
  where ds.slettet_tid is null
    and (ds.avdeling_kode is null or ds.avdeling_kode not in ('10', '250'))
    and ds.dato >= vindu.fra
  group by ds.stasjon_id, ds.dato
),
wd_naa as (select stasjon_id, ukedag, avg(oms) as m from dag_naa group by stasjon_id, ukedag),
res_naa as (
  select d.stasjon_id, d.dato, d.oms - w.m as resid
  from dag_naa d join wd_naa w on w.stasjon_id = d.stasjon_id and w.ukedag = d.ukedag
),
korr_naa as (
  select r.stasjon_id,
         corr(r.resid, v.temp_maks) as temp_korr,
         corr(r.resid, v.nedbor_mm) as nedbor_korr,
         count(*)                   as n
  from res_naa r
  join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato
                    and v.temp_maks is not null
  group by r.stasjon_id
),

-- ---- Rettet inndata: v_butikksalg (uten drivstoff) -----------------
-- Samme kjede, eneste forskjell er kilden. Pant-filteret ('250') er
-- beholdt for aa vaere tro mot funksjonens uttrykte hensikt, selv om
-- baselinen viste at koden ikke finnes i data.
dag_ny as (
  select v.stasjon_id, v.dato,
         extract(dow from v.dato)::int as ukedag,
         sum(v.omsetning_eks_mva)      as oms
  from public.v_butikksalg v, vindu
  where (v.avdeling_kode is null or v.avdeling_kode not in ('250'))
    and v.dato >= vindu.fra
  group by v.stasjon_id, v.dato
),
wd_ny as (select stasjon_id, ukedag, avg(oms) as m from dag_ny group by stasjon_id, ukedag),
res_ny as (
  select d.stasjon_id, d.dato, d.oms - w.m as resid
  from dag_ny d join wd_ny w on w.stasjon_id = d.stasjon_id and w.ukedag = d.ukedag
),
korr_ny as (
  select r.stasjon_id,
         corr(r.resid, v.temp_maks) as temp_korr,
         corr(r.resid, v.nedbor_mm) as nedbor_korr,
         count(*)                   as n
  from res_ny r
  join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato
                    and v.temp_maks is not null
  group by r.stasjon_id
),

-- ---- Drivstoffandel i vinduet som FAKTISK brukes -------------------
andel as (
  select ds.stasjon_id,
         round(sum(ds.omsetning_eks_mva), 2) as total,
         round(sum(ds.omsetning_eks_mva) filter (
           where coalesce(ds.avdeling_kode,'') = '1000'
              or upper(coalesce(ds.avdeling_navn,'')) = 'ENERGI'), 2) as drivstoff,
         min(ds.dato) as fra_faktisk, max(ds.dato) as til_faktisk
  from public.daglig_salg ds, vindu
  where ds.slettet_tid is null and ds.dato >= vindu.fra
  group by ds.stasjon_id
),

-- `corr()` gir double precision, og `round(double precision, int)`
-- finnes ikke i Postgres - bare `round(numeric, int)`. Castes her, saa
-- alt nedstroems slipper aa tenke paa det.
folsomhet as (
  select k.stasjon_id, k.temp_korr::numeric as temp_korr,
         k.nedbor_korr::numeric as nedbor_korr, k.n,
         least(1.0, greatest(0.1,
           greatest(abs(coalesce(k.temp_korr,0)), abs(coalesce(k.nedbor_korr,0))) * 2.0
         ))::numeric as folsomhet, 'naa'::text as variant
  from korr_naa k
  union all
  select k.stasjon_id, k.temp_korr::numeric, k.nedbor_korr::numeric, k.n,
         least(1.0, greatest(0.1,
           greatest(abs(coalesce(k.temp_korr,0)), abs(coalesce(k.nedbor_korr,0))) * 2.0
         ))::numeric, 'ny'
  from korr_ny k
),

-- ---- 1. Vinduet ----------------------------------------------------
ut_vindu as (
  select 'VINDU'::text as seksjon, 'current_date - 400 dager'::text as noekkel,
         (vindu.fra::text || ' .. ' || vindu.til::text
          || ' (' || (vindu.til - vindu.fra) || ' dager)')::text as verdi,
         1::int as sort, 'a'::text as s2
  from vindu
),

-- ---- 2. Dagens lagrede profil --------------------------------------
ut_profil as (
  select 'PROFIL NAA'::text, (st.kjede || ' | ' || st.navn)::text,
         ('folsomhet=' || coalesce(round(s.vaerfolsomhet_laert, 4)::text, '(null)')
           || ' temp_korr=' || coalesce(round(s.vaer_temp_korr, 4)::text, '(null)')
           || ' nedbor_korr=' || coalesce(round(s.vaer_nedbor_korr, 4)::text, '(null)')
           || ' beregnet=' || coalesce(s.vaer_profil_tid::date::text, '(aldri)'))::text,
         2::int, st.navn::text
  from public.stasjoner s join stasjon st on st.id = s.id
  where s.slettet_tid is null
),

-- ---- 3. Drivstoffandel av inndata ----------------------------------
ut_andel as (
  select 'DRIVSTOFFANDEL I VINDUET'::text, (st.kjede || ' | ' || st.navn)::text,
         ('total=' || a.total
           || ' drivstoff=' || coalesce(a.drivstoff, 0)
           || ' andel_pct=' || case when a.total > 0
                then round(100 * coalesce(a.drivstoff,0) / a.total, 1) else 0 end
           || ' data=' || a.fra_faktisk || '..' || a.til_faktisk)::text,
         3::int, st.navn::text
  from andel a join stasjon st on st.id = a.stasjon_id
),

-- ---- 4. Foer og etter, samme dag -----------------------------------
ut_simulert as (
  select 'SIMULERT FOER/ETTER'::text, (st.kjede || ' | ' || st.navn)::text,
         ('naa: folsomhet=' || round(f1.folsomhet, 4)
           || ' temp=' || coalesce(round(f1.temp_korr, 4)::text, '(null)')
           || ' nedbor=' || coalesce(round(f1.nedbor_korr, 4)::text, '(null)')
           || ' n=' || f1.n
           || '  ->  ny: folsomhet=' || round(f2.folsomhet, 4)
           || ' temp=' || coalesce(round(f2.temp_korr, 4)::text, '(null)')
           || ' nedbor=' || coalesce(round(f2.nedbor_korr, 4)::text, '(null)')
           || ' n=' || f2.n
           || '  DELTA=' || round(f2.folsomhet - f1.folsomhet, 4)
           || case when f1.n >= 30 and f2.n >= 30 then '' else '  [n<30: OPPDATERES IKKE]' end)::text,
         4::int, st.navn::text
  from folsomhet f1
  join folsomhet f2 on f2.stasjon_id = f1.stasjon_id and f2.variant = 'ny'
  join stasjon st on st.id = f1.stasjon_id
  where f1.variant = 'naa'
),

-- ---- 5. Backtest slik den staar naa --------------------------------
-- `kjorBacktestAlle` skriver `prognose_treff` per stasjon og dato, og
-- leser `vaerfolsomhet_laert`. Naar profilen endres, endres disse.
--
-- MERK: backtesten kjoerer bare fra nattjobben. En ny kjoering av denne
-- fila rett etter migrasjonen viser derfor FORTSATt de gamle
-- treffradene - `beregnet_tid` avsloerer det. Avviket maales foerst
-- etter neste nattjobb.
ut_treff as (
  select 'BACKTEST NAA'::text, (st.kjede || ' | ' || st.navn || ' | ' || t.type)::text,
         ('rader=' || count(*)
           || ' snitt_treff=' || round(avg(t.treff), 2)
           -- Parentesene er ikke pynt: uten dem kan `::numeric` binde til
           -- `t.treff` inne i ORDER BY i staden for til aggregatet, og
           -- `percentile_cont` gir double precision uansett inndatatype.
           || ' median_treff=' || round(
                (percentile_cont(0.5) within group (order by t.treff))::numeric, 2)
           || ' dager=' || (max(t.dato) - min(t.dato) + 1)
           || ' periode=' || min(t.dato) || '..' || max(t.dato)
           || ' beregnet=' || max(t.beregnet_tid)::date)::text,
         5::int, (st.navn || t.type)::text
  from public.prognose_treff t
  join stasjon st on st.id = t.stasjon_id
  group by st.kjede, st.navn, t.type
),

-- ---- 6. Kategoriprofilen: stemte paastanden? ------------------------
-- `beregn_kategori_vaerprofil` gjoer `delete` foer `insert`, saa den
-- gamle tilstanden er borte naar 0151 er kjoert. Paastanden om at
-- koeffisientene per kode er UENDRET var derfor et strukturelt argument
-- fra aa lese SQL-en, ikke en maaling.
--
-- Beregningen er deterministisk fra data, saa den gamle varianten kan
-- regnes om igjen og sammenlignes mot det som faktisk staar lagret.
-- Foerst da er paastanden bevist.
kat_gammel_base as (
  select ds.stasjon_id, ds.varegruppe_kode as kode, ds.dato,
         extract(dow from ds.dato)::int as ukedag, sum(ds.antall) as val
  from public.daglig_salg ds, vindu
  where ds.slettet_tid is null and ds.varegruppe_kode is not null
    and ds.dato >= vindu.fra
  group by ds.stasjon_id, ds.varegruppe_kode, ds.dato
),
kat_gammel_wd as (
  select stasjon_id, kode, ukedag, avg(val) as m
  from kat_gammel_base group by stasjon_id, kode, ukedag
),
kat_gammel_res as (
  select b.stasjon_id, b.kode, b.dato, b.val - w.m as resid
  from kat_gammel_base b
  join kat_gammel_wd w on w.stasjon_id = b.stasjon_id and w.kode = b.kode
                      and w.ukedag = b.ukedag
),
kat_gammel as (
  select r.stasjon_id, r.kode,
         corr(r.resid, v.temp_maks)::numeric as temp_korr,
         corr(r.resid, v.nedbor_mm)::numeric as nedbor_korr,
         count(*) as n
  from kat_gammel_res r
  join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato
                    and v.temp_maks is not null
  group by r.stasjon_id, r.kode
),
ut_kategori as (
  select 'KATEGORI: GAMMEL MOT LAGRET'::text, (st.kjede || ' | ' || st.navn)::text,
         ('koder=' || count(*)
           || ' maks_diff_temp=' || coalesce(round(max(abs(k.temp_korr - g.temp_korr)), 6)::text, '(null)')
           || ' maks_diff_nedbor=' || coalesce(round(max(abs(k.nedbor_korr - g.nedbor_korr)), 6)::text, '(null)')
           || ' avvikende=' || count(*) filter (
                where abs(k.temp_korr - g.temp_korr) > 0.000001
                   or abs(k.nedbor_korr - g.nedbor_korr) > 0.000001))::text,
         6::int, st.navn::text
  from public.kategori_vaerprofil k
  join kat_gammel g on g.stasjon_id = k.stasjon_id and g.kode = k.kode
  join stasjon st on st.id = k.stasjon_id
  where k.niva = 'varegruppe'
    and k.kode in ('1201','1202','1203','1216','1217','1218','1219','1221')
  group by st.kjede, st.navn
),

-- ---- 7. Kanarifugl -------------------------------------------------
ut_kanari as (
  select 'KANARIFUGL'::text, '1. fixen endrer faktisk noe'::text,
         (case when count(*) filter (
                 where abs(f2.folsomhet - f1.folsomhet) > 0.0001) > 0
               then 'JA - ' || count(*) filter (
                 where abs(f2.folsomhet - f1.folsomhet) > 0.0001)
                 || ' av ' || count(*) || ' stasjoner faar ny folsomhet.'
               else 'NEI - INGEN ENDRING. Da maaler denne fila ingenting, '
                 || 'og premisset om at drivstoff paavirker profilen er galt.' end)::text,
         7::int, 'a'::text
  from folsomhet f1
  join folsomhet f2 on f2.stasjon_id = f1.stasjon_id and f2.variant = 'ny'
  where f1.variant = 'naa'
  union all
  select 'KANARIFUGL'::text, '2. drivstoff er faktisk i inndata'::text,
         (case when sum(coalesce(a.drivstoff,0)) > 0
               then 'JA - ' || round(100 * sum(coalesce(a.drivstoff,0)) / nullif(sum(a.total),0), 1)
                 || ' % av omsetningen i vinduet er drivstoff.'
               else 'NEI - INGEN DRIVSTOFF I VINDUET. Da er det ingen bug aa rette her.' end)::text,
         7::int, 'b'::text
  from andel a
  union all
  select 'KANARIFUGL'::text, '3. nok historikk til aa oppdatere'::text,
         (case when count(*) filter (where f2.n >= 30) > 0
               then 'JA - ' || count(*) filter (where f2.n >= 30)
                 || ' stasjoner har n>=30 og vil bli oppdatert.'
               else 'NEI - INGEN stasjon naar n>=30. Fixen ville ikke skrevet noe.' end)::text,
         7::int, 'c'::text
  from folsomhet f2 where f2.variant = 'ny'
)

select seksjon, noekkel, verdi from (
  select * from ut_vindu
  union all select * from ut_profil
  union all select * from ut_andel
  union all select * from ut_simulert
  union all select * from ut_treff
  union all select * from ut_kategori
  union all select * from ut_kanari
) x
order by sort, s2, noekkel;
