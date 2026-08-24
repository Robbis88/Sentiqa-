-- =====================================================================
-- Hva beviser produksjonsdata? Svinn, kasse og historikk.
--
-- KUN LESING. Ingen create, alter, insert, update, delete, ingen temp-
-- tabeller og ingen funksjoner. Trygg i produksjon.
--
-- EN SETNING. Supabase SQL Editor viser resultatet av den siste
-- setningen; delt opp ville de fire delene blitt til en synlig og tre
-- usynlige. Alt samles derfor i ett `select` med `del`-kolonnen som
-- skille. Samme grunn som `rls_vakthund.sql` maa vaere en setning.
--
-- KJORES SOM DEG. RLS gjelder: du ser din egen retailer, ikke andres.
--
-- FIRE SPOERSMAAL, og et femte som viste seg aa vaere en forutsetning
-- for det foerste:
--
--   1  EAN-dekning: hvor mye av svinnet kan kobles til en varegruppe
--   1b HVA ER `nettopris_total`? Kostpris eller utsalgspris? Uten svar
--      kan nevneren i svinnprosenten ikke bygges korrekt.
--   2  Kodeverket: hvilke arsakskoder og transaksjonstyper finnes
--   3  Identitet: operatornr mot kasserer_nr mot ansatt_nr
--   4  Historikk: hvor langt tilbake hver kilde faktisk gaar
--
-- INGEN TOLKNING. Spoerringen viser hva som staar der. Den kaller ikke
-- en kode "kast" eller "internt forbruk", og den paastaar ikke at to
-- like nummerserier er samme person.
--
-- VINDU: 13 maaneder. Nok til aar-mot-aar, og lite nok til at
-- `daglig_salg` ikke leses i sin helhet. Del 4 er unntatt - den skal
-- nettopp finne ut hvor langt tilbake det gaar.
-- =====================================================================

with

-- --------------------------------------------------------------------
-- Grunnlag
-- --------------------------------------------------------------------
stasj as (
  select id, butikknummer || ' ' || navn as stasjon
  from public.stasjoner
  where slettet_tid is null
),

vindu as (
  select (current_date - interval '13 months')::date as fra,
         current_date                                as til
),

svinn as (
  select s.stasjon_id, s.ean, s.varenavn, s.varenummer, s.operatornr,
         s.arsakskode, s.transaksjonstype, s.dato,
         s.nettopris, s.antall, s.nettopris_total
  from public.synlig_svinn s, vindu v
  where s.slettet_tid is null
    and s.dato between v.fra and v.til
),

-- EN RAD PER EAN. `v_varer` er distinct paa (ean, varenavn,
-- varegruppe), saa samme EAN kan staa flere ganger. Teller vi mot den
-- raa, blir en vare med to skrivemaater talt som to treff.
varer as (
  select ean,
         count(distinct varegruppe_kode) as antall_grupper,
         min(varegruppe_kode)            as gruppe_kode,
         min(varegruppe_navn)            as gruppe_navn
  from public.v_varer
  where ean is not null
  group by ean
),

svinn_merket as (
  select s.*,
         (va.ean is not null) as matcher,
         va.gruppe_navn
  from svinn s
  left join varer va on va.ean = s.ean
),

-- De ti stoerste uten treff per stasjon. En full liste kunne vaert
-- tusenvis av rader og ville druknet resten av svaret.
uten_treff as (
  select sm.stasjon_id, sm.ean, sm.varenavn, sm.varenummer,
         count(*)                       as linjer,
         sum(sm.nettopris_total)        as kr,
         row_number() over (
           partition by sm.stasjon_id
           order by sum(sm.nettopris_total) desc nulls last) as rn
  from svinn_merket sm
  where not sm.matcher
  group by sm.stasjon_id, sm.ean, sm.varenavn, sm.varenummer
),

-- Kostpris paa solgte varer, per EAN og stasjon.
-- omsetning - bruttofortjeneste = varekost. Er den utledbar, kan
-- nevneren "kostpris paa solgt" bygges; er den ikke, kan den ikke.
salg_ean as (
  select d.stasjon_id,
         d.ean,
         sum(d.antall)                                   as solgt_antall,
         sum(d.omsetning_eks_mva)                        as oms_kr,
         sum(d.bto_fortjeneste_kr)                       as brutto_kr,
         sum(d.omsetning_eks_mva - d.bto_fortjeneste_kr) as varekost_kr,
         count(*) filter (where d.omsetning_eks_mva is null
                             or d.bto_fortjeneste_kr is null) as mangler_ledd
  from public.v_butikksalg d, vindu v
  where d.dato between v.fra and v.til
  group by d.stasjon_id, d.ean
),

-- Svinnets enhetspris mot salgets enhetskost og enhetspris, for de
-- samme EAN-ene. Ligner den kosten, er `nettopris_total` kostpris.
pris_sammenlikning as (
  select s.stasjon_id,
         s.ean,
         sum(s.nettopris_total)                              as svinn_kr,
         sum(s.antall)                                       as svinn_antall,
         sum(s.nettopris_total) / nullif(sum(s.antall), 0)   as svinn_per_enhet,
         se.varekost_kr / nullif(se.solgt_antall, 0)         as kost_per_enhet,
         se.oms_kr      / nullif(se.solgt_antall, 0)         as pris_per_enhet
  from svinn s
  join salg_ean se on se.stasjon_id = s.stasjon_id and se.ean = s.ean
  where s.antall is not null and s.antall <> 0
    and s.nettopris_total is not null
  group by s.stasjon_id, s.ean, se.varekost_kr, se.oms_kr, se.solgt_antall
),

-- --------------------------------------------------------------------
-- Identitet: tre nummerserier
-- --------------------------------------------------------------------
op as (
  select distinct stasjon_id, nullif(btrim(operatornr), '') as nr
  from svinn
  where nullif(btrim(operatornr), '') is not null
),

kass as (
  select k.stasjon_id,
         nullif(btrim(k.kasserer_nr), '') as nr,
         count(distinct nullif(btrim(k.kasserer_navn), '')) as antall_navn
  from public.kassererstatistikk k, vindu v
  where k.slettet_tid is null
    and k.dato between v.fra and v.til
    and nullif(btrim(k.kasserer_nr), '') is not null
  group by k.stasjon_id, nullif(btrim(k.kasserer_nr), '')
),

ans as (
  select stasjon_id,
         nullif(btrim(ansatt_nr), '') as nr,
         count(distinct nullif(btrim(navn), '')) as antall_navn
  from public.ansatte
  where slettet_tid is null
    and nullif(btrim(ansatt_nr), '') is not null
  group by stasjon_id, nullif(btrim(ansatt_nr), '')
),

stemp as (
  select distinct s.stasjon_id, nullif(btrim(s.ansatt_nr), '') as nr
  from public.stempling s, vindu v
  where s.dato between v.fra and v.til
    and nullif(btrim(s.ansatt_nr), '') is not null
)

-- =====================================================================
-- DEL 1 - EAN-dekning
-- =====================================================================
select 1 as del,
       'EAN-DEKNING'                                                as hva,
       st.stasjon                                                   as stasjon,
       'alle svinnlinjer'                                           as nokkel,
       'matcher = EAN finnes i v_varer'                             as detalj,
       count(*)::numeric                                            as antall,
       round(coalesce(sum(sm.nettopris_total), 0))::numeric         as kroner,
       null::numeric                                                as pst
from svinn_merket sm join stasj st on st.id = sm.stasjon_id
group by st.stasjon

union all
select 1, 'EAN-DEKNING', st.stasjon,
       case when sm.matcher then 'MATCHER' else 'matcher IKKE' end,
       'antall linjer og kroner',
       count(*)::numeric,
       round(coalesce(sum(sm.nettopris_total), 0))::numeric,
       round(100.0 * count(*) / nullif(sum(count(*)) over (partition by st.stasjon), 0), 1)
from svinn_merket sm join stasj st on st.id = sm.stasjon_id
group by st.stasjon, sm.matcher

-- Eksempler paa det som IKKE matcher. Ikke skjult, ikke aggregert bort.
union all
select 1, 'EAN UTEN TREFF', st.stasjon,
       coalesce(u.ean, '(ingen ean)'),
       coalesce(nullif(btrim(u.varenavn), ''), '(uten varenavn)')
         || ' | varenr ' || coalesce(nullif(btrim(u.varenummer), ''), '(tom)'),
       u.linjer::numeric,
       round(coalesce(u.kr, 0))::numeric,
       null::numeric
from uten_treff u join stasj st on st.id = u.stasjon_id
where u.rn <= 10

-- EN EAN I FLERE VAREGRUPPER er en trussel mot topplista: da kan samme
-- vare telles i to grupper avhengig av hvem som spoer.
union all
select 1, 'EAN I FLERE GRUPPER', '(alle stasjoner)',
       'ean-er med mer enn en varegruppe',
       'hoeyt tall her betyr at gruppering paa EAN ikke er entydig',
       count(*)::numeric, null::numeric, null::numeric
from varer where antall_grupper > 1

-- =====================================================================
-- DEL 1b - HVA ER `nettopris_total`?
--
-- Uten dette svaret kan nevneren ikke bygges. Ligger svinnets
-- enhetspris naer salgets enhetsKOST, er den kostpris. Ligger den naer
-- enhetsPRIS, er den utsalgspris - og da maaler "svinn/varekost" to
-- forskjellige stoerrelser.
-- =====================================================================
union all
select 1, 'NETTOPRIS ER?', st.stasjon,
       'ean-er med baade svinn og salg',
       'andel der svinnpris ligger innenfor 15 % av kost / av pris',
       count(*)::numeric,
       null::numeric,
       null::numeric
from pris_sammenlikning p join stasj st on st.id = p.stasjon_id
group by st.stasjon

union all
select 1, 'NETTOPRIS ER?', st.stasjon, 'ligner KOSTPRIS',
       'abs(svinn_per_enhet / kost_per_enhet - 1) < 0.15',
       count(*) filter (
         where p.kost_per_enhet is not null and p.kost_per_enhet <> 0
           and abs(p.svinn_per_enhet / p.kost_per_enhet - 1) < 0.15)::numeric,
       null::numeric,
       round(100.0 * count(*) filter (
         where p.kost_per_enhet is not null and p.kost_per_enhet <> 0
           and abs(p.svinn_per_enhet / p.kost_per_enhet - 1) < 0.15)
         / nullif(count(*), 0), 1)
from pris_sammenlikning p join stasj st on st.id = p.stasjon_id
group by st.stasjon

union all
select 1, 'NETTOPRIS ER?', st.stasjon, 'ligner UTSALGSPRIS',
       'abs(svinn_per_enhet / pris_per_enhet - 1) < 0.15',
       count(*) filter (
         where p.pris_per_enhet is not null and p.pris_per_enhet <> 0
           and abs(p.svinn_per_enhet / p.pris_per_enhet - 1) < 0.15)::numeric,
       null::numeric,
       round(100.0 * count(*) filter (
         where p.pris_per_enhet is not null and p.pris_per_enhet <> 0
           and abs(p.svinn_per_enhet / p.pris_per_enhet - 1) < 0.15)
         / nullif(count(*), 0), 1)
from pris_sammenlikning p join stasj st on st.id = p.stasjon_id
group by st.stasjon

-- KAN NEVNEREN I DET HELE TATT BYGGES? Varekost = omsetning - brutto.
-- Mangler ett av leddene, finnes ikke kostpris paa solgt vare.
union all
select 1, 'VAREKOST UTLEDBAR', st.stasjon,
       'salgslinjer i vinduet',
       'mangler_ledd = linjer uten omsetning eller uten bruttofortjeneste',
       sum(se.solgt_antall)::numeric,
       round(coalesce(sum(se.varekost_kr), 0))::numeric,
       round(100.0 * sum(se.mangler_ledd) / nullif(count(*), 0), 2)
from salg_ean se join stasj st on st.id = se.stasjon_id
group by st.stasjon

-- =====================================================================
-- DEL 2 - Kodeverket, uten tolkning
-- =====================================================================
union all
select 2, 'ARSAKSKODE', st.stasjon,
       coalesce(nullif(btrim(sm.arsakskode), ''), '(tom)'),
       'antall linjer og kroner',
       count(*)::numeric,
       round(coalesce(sum(sm.nettopris_total), 0))::numeric,
       round(100.0 * count(*) / nullif(sum(count(*)) over (partition by st.stasjon), 0), 1)
from svinn_merket sm join stasj st on st.id = sm.stasjon_id
group by st.stasjon, nullif(btrim(sm.arsakskode), '')

union all
select 2, 'TRANSAKSJONSTYPE', st.stasjon,
       coalesce(nullif(btrim(sm.transaksjonstype), ''), '(tom)'),
       'antall linjer og kroner',
       count(*)::numeric,
       round(coalesce(sum(sm.nettopris_total), 0))::numeric,
       round(100.0 * count(*) / nullif(sum(count(*)) over (partition by st.stasjon), 0), 1)
from svinn_merket sm join stasj st on st.id = sm.stasjon_id
group by st.stasjon, nullif(btrim(sm.transaksjonstype), '')

-- =====================================================================
-- DEL 3 - Identitet. Maaler overlapp, paastaar ingenting.
-- =====================================================================
union all
select 3, 'NUMMERSERIER', st.stasjon, 'operatornr (svinn)',
       'distinkte nummer i vinduet',
       count(*)::numeric, null::numeric, null::numeric
from op join stasj st on st.id = op.stasjon_id
group by st.stasjon

union all
select 3, 'NUMMERSERIER', st.stasjon, 'kasserer_nr (kasse)',
       'distinkte nummer i vinduet',
       count(*)::numeric, null::numeric, null::numeric
from kass join stasj st on st.id = kass.stasjon_id
group by st.stasjon

union all
select 3, 'NUMMERSERIER', st.stasjon, 'ansatt_nr (ansatte)',
       'distinkte nummer, ikke slettede',
       count(*)::numeric, null::numeric, null::numeric
from ans join stasj st on st.id = ans.stasjon_id
group by st.stasjon

union all
select 3, 'NUMMERSERIER', st.stasjon, 'ansatt_nr (stempling)',
       'distinkte nummer i vinduet',
       count(*)::numeric, null::numeric, null::numeric
from stemp join stasj st on st.id = stemp.stasjon_id
group by st.stasjon

-- HOLDER operatornr = kasserer_nr?
union all
select 3, 'OVERLAPP', st.stasjon, 'operatornr som finnes i kasserer_nr',
       'eksakt streng-match, samme stasjon',
       count(*) filter (where k.nr is not null)::numeric,
       null::numeric,
       round(100.0 * count(*) filter (where k.nr is not null) / nullif(count(*), 0), 1)
from op left join kass k on k.stasjon_id = op.stasjon_id and k.nr = op.nr
join stasj st on st.id = op.stasjon_id
group by st.stasjon

union all
select 3, 'OVERLAPP', st.stasjon, 'kasserer_nr som finnes i ansatt_nr',
       'eksakt streng-match, samme stasjon',
       count(*) filter (where a.nr is not null)::numeric,
       null::numeric,
       round(100.0 * count(*) filter (where a.nr is not null) / nullif(count(*), 0), 1)
from kass left join ans a on a.stasjon_id = kass.stasjon_id and a.nr = kass.nr
join stasj st on st.id = kass.stasjon_id
group by st.stasjon

union all
select 3, 'OVERLAPP', st.stasjon, 'kasserer_nr som finnes i stempling',
       'eksakt streng-match, samme stasjon',
       count(*) filter (where s.nr is not null)::numeric,
       null::numeric,
       round(100.0 * count(*) filter (where s.nr is not null) / nullif(count(*), 0), 1)
from kass left join stemp s on s.stasjon_id = kass.stasjon_id and s.nr = kass.nr
join stasj st on st.id = kass.stasjon_id
group by st.stasjon

-- KASSERERNUMMER SOM IKKE FINNES BLANT ANSATTE. Disse er grunnen til at
-- en kobling ikke kan gjoeres blindt.
union all
select 3, 'UTEN TREFF', st.stasjon, k.nr,
       'kasserer_nr uten ansatt_nr paa samme stasjon',
       1::numeric, null::numeric, null::numeric
from kass k
join stasj st on st.id = k.stasjon_id
where not exists (
  select 1 from ans a where a.stasjon_id = k.stasjon_id and a.nr = k.nr)

-- PEKER ETT NUMMER PAA FLERE NAVN? Da er nummeret ikke en person.
union all
select 3, 'FLERE NAVN', st.stasjon, k.nr,
       'kasserer_nr med mer enn ett navn i vinduet',
       k.antall_navn::numeric, null::numeric, null::numeric
from kass k join stasj st on st.id = k.stasjon_id
where k.antall_navn > 1

union all
select 3, 'FLERE NAVN', st.stasjon, a.nr,
       'ansatt_nr med mer enn ett navn',
       a.antall_navn::numeric, null::numeric, null::numeric
from ans a join stasj st on st.id = a.stasjon_id
where a.antall_navn > 1

-- =====================================================================
-- DEL 4 - Historikk. UTEN vindu: det er nettopp dybden vi maaler.
--
-- `dekning` er distinkte datoer delt paa kalenderdager i spennet. 100 %
-- betyr data hver dag; 70 % betyr hull, og hull avgjoer hvilke
-- periodevalg som er aerlige aa tilby.
-- =====================================================================
union all
select 4, 'HISTORIKK', st.stasjon, 'salg (v_butikksalg)',
       min(d.dato)::text || ' -> ' || max(d.dato)::text,
       count(distinct d.dato)::numeric,
       null::numeric,
       round(100.0 * count(distinct d.dato)
             / nullif((max(d.dato) - min(d.dato)) + 1, 0), 1)
from public.v_butikksalg d join stasj st on st.id = d.stasjon_id
group by st.stasjon

union all
select 4, 'HISTORIKK', st.stasjon, 'svinn (synlig_svinn)',
       min(s.dato)::text || ' -> ' || max(s.dato)::text,
       count(distinct s.dato)::numeric,
       round(coalesce(sum(s.nettopris_total), 0))::numeric,
       round(100.0 * count(distinct s.dato)
             / nullif((max(s.dato) - min(s.dato)) + 1, 0), 1)
from public.synlig_svinn s join stasj st on st.id = s.stasjon_id
where s.slettet_tid is null and s.dato is not null
group by st.stasjon

union all
select 4, 'HISTORIKK', st.stasjon, 'kassererstatistikk',
       min(k.dato)::text || ' -> ' || max(k.dato)::text,
       count(distinct k.dato)::numeric,
       round(coalesce(sum(k.bonger), 0))::numeric,
       round(100.0 * count(distinct k.dato)
             / nullif((max(k.dato) - min(k.dato)) + 1, 0), 1)
from public.kassererstatistikk k join stasj st on st.id = k.stasjon_id
where k.slettet_tid is null and k.dato is not null
group by st.stasjon

union all
select 4, 'HISTORIKK', st.stasjon, 'businessplan (v_bp_status_avdeling)',
       min(b.maned)::text || ' -> ' || max(b.maned)::text,
       count(distinct b.maned)::numeric,
       null::numeric,
       null::numeric
from public.v_bp_status_avdeling b join stasj st on st.id = b.stasjon_id
group by st.stasjon

-- Hvor mange av BP-maanedene er AVLAGT? Det er dem en periodevelger
-- faktisk kan tilby uten forbehold.
union all
select 4, 'HISTORIKK', st.stasjon, 'businessplan - avlagte maaneder',
       coalesce(min(b.maned) filter (where b.periode_status = 'avlagt')::text, '(ingen)')
         || ' -> '
         || coalesce(max(b.maned) filter (where b.periode_status = 'avlagt')::text, '(ingen)'),
       count(distinct b.maned) filter (where b.periode_status = 'avlagt')::numeric,
       null::numeric, null::numeric
from public.v_bp_status_avdeling b join stasj st on st.id = b.stasjon_id
group by st.stasjon

union all
select 4, 'HISTORIKK', st.stasjon, 'regnskap (per stasjon)',
       min(r.periode)::text || ' -> ' || max(r.periode)::text,
       count(distinct r.periode)::numeric,
       null::numeric, null::numeric
from public.regnskapslinjer r join stasj st on st.id = r.stasjon_id
where r.slettet_tid is null and r.periode is not null
group by st.stasjon

union all
select 4, 'HISTORIKK', '(kjedetotal)', 'regnskap (stasjon_id null)',
       min(r.periode)::text || ' -> ' || max(r.periode)::text,
       count(distinct r.periode)::numeric,
       null::numeric, null::numeric
from public.regnskapslinjer r
where r.slettet_tid is null and r.stasjon_id is null and r.periode is not null

order by del, hva, stasjon, antall desc nulls last, nokkel;
