-- =====================================================================
-- BASELINE FOER SEMANTISK KODEMAPPING
--
-- Kjoeres FOER `v_butikksalg` og `PRODUKSJON_KODER` bytter kilde fra
-- hardkodede St1-litteraler til en mapping per retailer. Kjoeres igjen
-- ETTER. **Utdata skal vaere tegn for tegn identisk.**
--
-- Trygg i produksjon: leser kun. Ingen skriving, ingen transaksjon aa
-- rulle tilbake.
--
-- ---------------------------------------------------------------------
-- HVORFOR DATOENE ER LITTERALER
--
-- En baseline med `current_date` er verdiloes: "etter"-kjoeringen faar
-- et annet vindu enn "foer", og to ulike tall beviser ingenting. Hvert
-- intervall under er skrevet ut.
--
-- ---------------------------------------------------------------------
-- HVORFOR INTERVALLENE LIGGER ETTER APRIL 2026
--
-- Drivstoff kom inn i salgsstatistikken i loepet av april 2026. Foer
-- det er `v_butikksalg` og `daglig_salg` samme datasett, og et filter
-- som slutter aa virke ville sett helt likt ut. **Februar er tatt med
-- som kontroll nettopp fordi delta der skal vaere null** - den viser at
-- maalingen skiller mellom "filteret fjerner ingenting" og "filteret
-- har ingenting aa fjerne".
--
-- ---------------------------------------------------------------------
-- KANARIFUGL
--
-- Seksjon KANARIFUGL svarer paa om denne fila maaler noe i det hele
-- tatt. Fjerner filteret 0 kr i mai-juli, er baselinen tom seier: da
-- ville "identisk foer og etter" ogsaa vaert sant om filteret var
-- fjernet helt. Den raden skal si JA foer noen av de andre tallene
-- betyr noe.
--
-- ---------------------------------------------------------------------
-- BRUK
--
-- Kjoer, og lagre HELE resultatet. Formatet er langt (seksjon/noekkel/
-- verdi) med vilje: det diffes linje for linje uten aa vaere avhengig
-- av kolonnerekkefoelge.
-- =====================================================================

with intervall(kode, fra, til, merknad) as (
  values
    ('2026-02', date '2026-02-01', date '2026-02-28', 'kontroll: foer drivstoff kom inn'),
    ('2026-05', date '2026-05-01', date '2026-05-31', 'med drivstoff'),
    ('2026-06', date '2026-06-01', date '2026-06-30', 'med drivstoff'),
    ('2026-07', date '2026-07-01', date '2026-07-31', 'med drivstoff')
),

-- Butikksalget slik alt i appen ser det.
butikk as (
  select i.kode as intervall, v.retailer_id, v.stasjon_id,
         count(*)                                        as rader,
         round(coalesce(sum(v.omsetning_eks_mva),0), 2)   as oms,
         round(coalesce(sum(v.antall),0), 2)              as antall,
         round(coalesce(sum(v.bto_fortjeneste_kr),0), 2)  as btofort
  from intervall i
  join public.v_butikksalg v on v.dato between i.fra and i.til
  group by i.kode, v.retailer_id, v.stasjon_id
),

-- ALT salg, drivstoff inkludert. Differansen er det filteret gjoer.
alt as (
  select i.kode as intervall, d.retailer_id, d.stasjon_id,
         count(*)                                        as rader,
         round(coalesce(sum(d.omsetning_eks_mva),0), 2)   as oms
  from intervall i
  join public.daglig_salg d
    on d.dato between i.fra and i.til and d.slettet_tid is null
  group by i.kode, d.retailer_id, d.stasjon_id
),

stasjon as (
  select s.id, s.retailer_id, s.butikknummer || ' ' || s.navn as navn, r.navn as kjede
  from public.stasjoner s join public.retailers r on r.id = s.retailer_id
),

-- -- 1. Per stasjon ------------------------------------------------
per_stasjon as (
  select 'BUTIKKSALG'::text as seksjon,
         b.intervall || ' | ' || st.kjede || ' | ' || st.navn as noekkel,
         'rader=' || b.rader
           || ' oms=' || b.oms
           || ' antall=' || b.antall
           || ' btofort=' || b.btofort as verdi,
         1 as sort, b.intervall as s2, st.navn as s3
  from butikk b join stasjon st on st.id = b.stasjon_id
),

-- -- 2. Kjedetall --------------------------------------------------
per_kjede as (
  select 'BUTIKKSALG KJEDE'::text,
         b.intervall || ' | ' || st.kjede,
         'stasjoner=' || count(*)
           || ' rader=' || sum(b.rader)
           || ' oms=' || round(sum(b.oms), 2)
           || ' antall=' || round(sum(b.antall), 2),
         2, b.intervall, st.kjede
  from butikk b join stasjon st on st.id = b.stasjon_id
  group by b.intervall, st.kjede
),

-- -- 3. Hva filteret faktisk fjerner -------------------------------
filterdelta as (
  select 'DRIVSTOFFILTER'::text,
         a.intervall || ' | ' || st.kjede,
         'rader_alt=' || sum(a.rader)
           || ' rader_butikk=' || coalesce(sum(b.rader), 0)
           || ' fjernet_rader=' || (sum(a.rader) - coalesce(sum(b.rader), 0))
           || ' fjernet_kr=' || round(sum(a.oms) - coalesce(sum(b.oms), 0), 2)
           || ' fjernet_pct=' || case when sum(a.oms) > 0
                then round(100 * (sum(a.oms) - coalesce(sum(b.oms),0)) / sum(a.oms), 1)
                else 0 end,
         3, a.intervall, st.kjede
  from alt a
  join stasjon st on st.id = a.stasjon_id
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
  group by a.intervall, st.kjede
),

-- -- 4. Produksjonsvarene, per varegruppe --------------------------
-- Motoren (`lagProduksjonsplan`) er ren og ser aldri kodene: begge
-- kallstedene filtrerer i SPOERRINGEN. Er radene motoren faar inn
-- identiske, er planen identisk. Dette er den halvdelen basen kan
-- bevise - motorens egen renhet bevises av en vitest.
produksjon as (
  select 'PRODUKSJON'::text,
         i.kode || ' | ' || st.kjede || ' | ' || coalesce(v.varegruppe_kode, '(null)'),
         'rader=' || count(*)
           || ' antall=' || round(coalesce(sum(v.antall),0), 2)
           || ' varer=' || count(distinct v.ean),
         4, i.kode, coalesce(v.varegruppe_kode, '(null)')
  from intervall i
  join public.v_butikksalg v on v.dato between i.fra and i.til
  join stasjon st on st.id = v.stasjon_id
  where v.varegruppe_kode in ('1201','1202','1203','1216','1217','1218','1219','1221')
    and i.kode <> '2026-02'
  group by i.kode, st.kjede, v.varegruppe_kode
),

-- -- 5. RLS og security_invoker, FOER viewet roeres ----------------
-- `create or replace view` uten klausulen nullstiller flagget i
-- stillhet. Da leser viewet som eier, forbi RLS, og diffen ser ufarlig
-- ut. Disse radene er fasiten aa sammenligne mot etterpaa.
vern as (
  select 'VERN'::text,
         'v_butikksalg | security_invoker',
         coalesce((
           select case when c.reloptions::text like '%security_invoker=true%'
                       then 'true' else 'MANGLER: ' || coalesce(c.reloptions::text, '(ingen)') end
           from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relname = 'v_butikksalg'
         ), 'VIEWET FINNES IKKE'),
         5, 'a', 'a'
  union all
  select 'VERN', 'v_butikksalg | grants',
         coalesce((
           select string_agg(grantee || '=' || privilege_type, ', ' order by grantee, privilege_type)
           from information_schema.role_table_grants
           where table_schema = 'public' and table_name = 'v_butikksalg'
             and grantee in ('anon','authenticated','service_role')
         ), '(ingen)'),
         5, 'a', 'b'
  union all
  select 'VERN', 'daglig_salg | rls aktivert',
         (select case when c.relrowsecurity then 'true' else 'FALSE - RLS ER AV' end
          from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname = 'daglig_salg'),
         5, 'a', 'c'
  union all
  select 'VERN', 'daglig_salg | partisjoner uten rls',
         coalesce((
           select string_agg(c.relname, ', ' order by c.relname)
           from pg_inherits inh
           join pg_class c on c.oid = inh.inhrelid
           join pg_class p on p.oid = inh.inhparent
           join pg_namespace n on n.oid = p.relnamespace
           where n.nspname = 'public' and p.relname = 'daglig_salg'
             and not c.relrowsecurity
         ), 'ingen - alle har rls'),
         5, 'a', 'd'
  union all
  select 'VERN', 'daglig_salg | partisjoner med anon-grant',
         coalesce((
           select string_agg(g.table_name, ', ' order by g.table_name)
           from information_schema.role_table_grants g
           where g.table_schema = 'public' and g.grantee = 'anon'
             and g.table_name like 'daglig\_salg%'
         ), 'ingen - anon er utestengt'),
         5, 'a', 'e'
),

-- -- 6. Kanarifugl -------------------------------------------------
kanari as (
  select 'KANARIFUGL'::text,
         'filteret fjerner noe i mai-juli',
         case when coalesce(sum(a.oms) - coalesce(sum(b.oms), 0), 0) > 0
              then 'JA - ' || round(sum(a.oms) - coalesce(sum(b.oms), 0), 2)
                   || ' kr filtrert bort. Baselinen maaler noe.'
              else 'NEI - FILTERET FJERNER 0 KR. Baselinen er en tom seier: '
                   || '"identisk foer og etter" ville ogsaa vaert sant om '
                   || 'filteret var fjernet helt. Fiks intervallene foer du '
                   || 'stoler paa tallene over.' end,
         6, 'a', 'a'
  from alt a
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
  where a.intervall <> '2026-02'
  union all
  select 'KANARIFUGL', 'kontrollen for februar er null',
         case when coalesce(sum(a.oms) - coalesce(sum(b.oms), 0), 0) = 0
              then 'JA - som ventet. Foer april fantes ikke drivstoff.'
              else 'NEI - ' || round(sum(a.oms) - coalesce(sum(b.oms), 0), 2)
                   || ' kr filtrert i februar. Da kom drivstoff inn tidligere '
                   || 'enn antatt, og premisset for intervallvalget maa sjekkes.' end,
         6, 'a', 'b'
  from alt a
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
  where a.intervall = '2026-02'
  union all
  select 'KANARIFUGL', 'intervallene har data',
         case when count(*) > 0 then 'JA - ' || count(*) || ' stasjon-intervaller med rader'
              else 'NEI - INGEN DATA. Fila maaler ingenting.' end,
         6, 'a', 'c'
  from butikk
),

-- -- 7. Hva som faktisk ligger i vinduene --------------------------
omfang as (
  select 'OMFANG'::text, 'datospenn i daglig_salg',
         coalesce(min(dato)::text || ' .. ' || max(dato)::text, '(tomt)'), 7, 'a', 'a'
  from public.daglig_salg where slettet_tid is null
  union all
  select 'OMFANG', 'avdelinger som filtreres bort',
         coalesce((
           select string_agg(distinct coalesce(avdeling_kode,'(null)') || '/' || coalesce(avdeling_navn,'(null)'), ', ')
           from public.daglig_salg
           where slettet_tid is null
             and dato between date '2026-05-01' and date '2026-07-31'
             and (coalesce(avdeling_kode,'') = '10' or upper(coalesce(avdeling_navn,'')) = 'ENERGI')
         ), '(ingen)'), 7, 'a', 'b'
)

select seksjon, noekkel, verdi from (
  select * from per_stasjon
  union all select * from per_kjede
  union all select * from filterdelta
  union all select * from produksjon
  union all select * from vern
  union all select * from kanari
  union all select * from omfang
) x
order by sort, s2, s3, noekkel;
