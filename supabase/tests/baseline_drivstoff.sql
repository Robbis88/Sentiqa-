-- =====================================================================
-- BASELINE FOER SEMANTISK KODEMAPPING
--
-- Kjoeres FOER `v_butikksalg` og `PRODUKSJON_KODER` bytter kilde fra
-- hardkodede St1-litteraler til en mapping per retailer. Kjoeres igjen
-- ETTER. **Utdata skal vaere tegn for tegn identisk, bortsett fra
-- seksjonen SONDE, som beskriver hva som FINNES og ikke hva vi gjoer.**
--
-- Trygg i produksjon: leser kun. Ingen skriving, ingen DDL, ingen
-- transaksjon. Kan kjoeres naar som helst, ogsaa midt i en arbeidsdag.
--
-- ---------------------------------------------------------------------
-- HVORFOR DATOENE ER LITTERALER
--
-- En baseline med `current_date` er verdiloes: "etter"-kjoeringen faar
-- et annet vindu enn "foer", og to ulike tall beviser ingenting.
--
-- ---------------------------------------------------------------------
-- HVORFOR INTERVALLENE LIGGER ETTER APRIL 2026
--
-- Drivstoff kom inn i salgsstatistikken i loepet av april 2026. Foer det
-- er `v_butikksalg` og `daglig_salg` samme datasett, og et filter som
-- slutter aa virke ville sett helt likt ut.
--
-- **Februar er tatt med KUN som kontroll, aldri som bevis** - nettopp
-- fordi delta der skal vaere null. Den skiller "filteret fjerner
-- ingenting" fra "filteret har ingenting aa fjerne". Trekk ingen
-- konklusjon om filteret fra februarraden.
--
-- ---------------------------------------------------------------------
-- SEKSJONENE
--
--   BUTIKKSALG         per stasjon, per intervall. Hovedtallene.
--   BUTIKKSALG KJEDE   ett tall per kjede per intervall.
--   DRIVSTOFFILTER     hva filteret fjerner, PER STASJON.
--   DRIVSTOFFGRUNNLAG  hva som faktisk ligger i avdeling 10 / ENERGI.
--   PRODUKSJON         per stasjon, per varegruppe. Motorens inndata.
--   VERN               security_invoker, grants, RLS - foer viewet roeres.
--   SONDE              avdelinger som LIGNER drivstoff, men ikke filtreres.
--   KANARIFUGL         maaler denne fila noe i det hele tatt?
--   OMFANG             datospenn og stasjoner, saa vi ser at vinduene
--                      faktisk har data.
--
-- ---------------------------------------------------------------------
-- BRUK
--
-- Kjoer, og lagre HELE resultatet i en fil. Formatet er langt
-- (seksjon / noekkel / verdi) med vilje: det diffes linje for linje uten
-- aa vaere avhengig av kolonnerekkefoelge eller kolonnebredde.
--
-- **Les KANARIFUGL-radene foerst.** Sier den foerste NEI, er resten av
-- tallene en tom seier: da ville "identisk foer og etter" ogsaa vaert
-- sant om filteret var fjernet helt.
-- =====================================================================

with intervall(kode, fra, til) as (
  values
    ('2026-02', date '2026-02-01', date '2026-02-28'),  -- KONTROLL, ikke bevis
    ('2026-05', date '2026-05-01', date '2026-05-31'),
    ('2026-06', date '2026-06-01', date '2026-06-30'),
    ('2026-07', date '2026-07-01', date '2026-07-31')
),

stasjon as (
  select s.id, s.retailer_id,
         s.butikknummer || ' ' || s.navn as navn,
         r.navn as kjede
  from public.stasjoner s
  join public.retailers r on r.id = s.retailer_id
  where s.slettet_tid is null
),

-- Butikksalget slik hver flate i appen ser det.
butikk as (
  select i.kode as intervall, v.stasjon_id,
         count(*)                                        as rader,
         round(coalesce(sum(v.omsetning_eks_mva),0), 2)  as oms,
         round(coalesce(sum(v.antall),0), 2)             as antall,
         round(coalesce(sum(v.bto_fortjeneste_kr),0), 2) as btofort
  from intervall i
  join public.v_butikksalg v on v.dato between i.fra and i.til
  group by i.kode, v.stasjon_id
),

-- ALT salg, drivstoff inkludert. Differansen er det filteret gjoer.
alt as (
  select i.kode as intervall, d.stasjon_id,
         count(*)                                        as rader,
         round(coalesce(sum(d.omsetning_eks_mva),0), 2)  as oms
  from intervall i
  join public.daglig_salg d
    on d.dato between i.fra and i.til and d.slettet_tid is null
  group by i.kode, d.stasjon_id
),

-- ---- 1. Per stasjon ------------------------------------------------
per_stasjon as (
  select 'BUTIKKSALG'::text as seksjon,
         (b.intervall || ' | ' || st.kjede || ' | ' || st.navn)::text as noekkel,
         ('rader=' || b.rader
           || ' oms=' || b.oms
           || ' antall=' || b.antall
           || ' btofort=' || b.btofort)::text as verdi,
         1::int as sort, b.intervall::text as s2, st.navn::text as s3
  from butikk b join stasjon st on st.id = b.stasjon_id
),

-- ---- 2. Kjedetall --------------------------------------------------
per_kjede as (
  select 'BUTIKKSALG KJEDE'::text,
         (b.intervall || ' | ' || st.kjede)::text,
         ('stasjoner=' || count(*)
           || ' rader=' || sum(b.rader)
           || ' oms=' || round(sum(b.oms), 2)
           || ' antall=' || round(sum(b.antall), 2)
           || ' btofort=' || round(sum(b.btofort), 2))::text,
         2::int, b.intervall::text, st.kjede::text
  from butikk b join stasjon st on st.id = b.stasjon_id
  group by b.intervall, st.kjede
),

-- ---- 3. Hva filteret fjerner, PER STASJON ---------------------------
-- Per stasjon og ikke bare per kjede: en regresjon som rammer en stasjon
-- ville druknet i et kjedetall.
filterdelta as (
  select 'DRIVSTOFFILTER'::text,
         (a.intervall || ' | ' || st.kjede || ' | ' || st.navn)::text,
         ('rader_alt=' || a.rader
           || ' rader_butikk=' || coalesce(b.rader, 0)
           || ' fjernet_rader=' || (a.rader - coalesce(b.rader, 0))
           || ' fjernet_kr=' || round(a.oms - coalesce(b.oms, 0), 2)
           || ' fjernet_pct=' || case when a.oms > 0
                then round(100 * (a.oms - coalesce(b.oms, 0)) / a.oms, 1)
                else 0 end)::text,
         3::int, a.intervall::text, st.navn::text
  from alt a
  join stasjon st on st.id = a.stasjon_id
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
),

-- ---- 4. Hva drivstoffgrunnlaget FAKTISK er --------------------------
-- "Ekskluderer riktig grunnlag" krever at vi ser grunnlaget, ikke bare
-- differansen. Her staar radene filteret treffer, med sin egen avdeling.
drivstoffgrunnlag as (
  select 'DRIVSTOFFGRUNNLAG'::text,
         (i.kode || ' | ' || coalesce(d.avdeling_kode,'(null)')
           || ' / ' || coalesce(d.avdeling_navn,'(null)'))::text,
         ('rader=' || count(*)
           || ' oms=' || round(coalesce(sum(d.omsetning_eks_mva),0), 2)
           || ' stasjoner=' || count(distinct d.stasjon_id)
           || ' varer=' || count(distinct d.ean))::text,
         4::int, i.kode::text, coalesce(d.avdeling_kode,'(null)')::text
  from intervall i
  join public.daglig_salg d
    on d.dato between i.fra and i.til and d.slettet_tid is null
  where coalesce(d.avdeling_kode,'') = '10'
     or upper(coalesce(d.avdeling_navn,'')) = 'ENERGI'
  group by i.kode, d.avdeling_kode, d.avdeling_navn
),

-- ---- 5. Produksjonsvarene, per stasjon og varegruppe ----------------
-- Motoren (`lagProduksjonsplan`) er REN og ser aldri kodene: begge
-- kallstedene filtrerer i SPOERRINGEN. Er radene motoren faar inn
-- identiske, er planen identisk.
--
-- Denne seksjonen fester den halvdelen basen kan bevise. Motorens egen
-- renhet bevises av `src/lib/produksjonsplan.baseline.test.ts`, som
-- kjoerer uten database.
produksjon as (
  select 'PRODUKSJON'::text,
         (i.kode || ' | ' || st.navn || ' | ' || coalesce(v.varegruppe_kode,'(null)')
           || ' ' || coalesce(v.varegruppe_navn,''))::text,
         ('rader=' || count(*)
           || ' antall=' || round(coalesce(sum(v.antall),0), 2)
           || ' varer=' || count(distinct v.ean))::text,
         5::int, i.kode::text, (st.navn || coalesce(v.varegruppe_kode,''))::text
  from intervall i
  join public.v_butikksalg v on v.dato between i.fra and i.til
  join stasjon st on st.id = v.stasjon_id
  where v.varegruppe_kode in
        ('1201','1202','1203','1216','1217','1218','1219','1221')
    and i.kode <> '2026-02'
  group by i.kode, st.navn, v.varegruppe_kode, v.varegruppe_navn
),

-- ---- 6. RLS og security_invoker, FOER viewet roeres -----------------
-- `create or replace view` uten klausulen nullstiller flagget i
-- stillhet. Da leser viewet som eier, forbi RLS, og diffen ser ufarlig
-- ut. Disse radene er fasiten aa sammenligne mot etterpaa.
vern as (
  select 'VERN'::text, 'v_butikksalg | security_invoker'::text,
         coalesce((
           select case when c.reloptions::text like '%security_invoker=true%'
                       then 'true'
                       else 'MANGLER: ' || coalesce(c.reloptions::text, '(ingen)') end
           from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relname = 'v_butikksalg'
         ), 'VIEWET FINNES IKKE')::text,
         6::int, 'a'::text, 'a'::text
  union all
  select 'VERN'::text, 'v_butikksalg | grants'::text,
         coalesce((
           select string_agg(grantee || '=' || privilege_type, ', ')
           from information_schema.role_table_grants
           where table_schema = 'public' and table_name = 'v_butikksalg'
             and grantee in ('anon','authenticated','service_role')
         ), '(ingen)')::text,
         6::int, 'a'::text, 'b'::text
  union all
  select 'VERN'::text, 'daglig_salg | rls aktivert'::text,
         (select case when c.relrowsecurity then 'true' else 'FALSE - RLS ER AV' end
          from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname = 'daglig_salg')::text,
         6::int, 'a'::text, 'c'::text
  union all
  select 'VERN'::text, 'daglig_salg | partisjoner uten rls'::text,
         coalesce((
           select string_agg(c.relname, ', ')
           from pg_inherits inh
           join pg_class c on c.oid = inh.inhrelid
           join pg_class p on p.oid = inh.inhparent
           join pg_namespace n on n.oid = p.relnamespace
           where n.nspname = 'public' and p.relname = 'daglig_salg'
             and not c.relrowsecurity
         ), 'ingen - alle partisjoner har rls')::text,
         6::int, 'a'::text, 'd'::text
  union all
  select 'VERN'::text, 'daglig_salg | partisjoner med anon-grant'::text,
         coalesce((
           select string_agg(distinct g.table_name::text, ', ')
           from information_schema.role_table_grants g
           where g.table_schema = 'public' and g.grantee = 'anon'
             and g.table_name like 'daglig\_salg%'
         ), 'ingen - anon er utestengt')::text,
         6::int, 'a'::text, 'e'::text
),

-- ---- 7. SONDE: avdelinger som LIGNER drivstoff ----------------------
-- Den eneste seksjonen som kan endre seg mellom foer og etter uten at
-- noe er galt - den beskriver hva som FINNES, ikke hva vi gjoer.
--
-- Finner den noe, er dagens filter allerede ufullstendig, og det maa
-- avklares FOER mappingen bygges. Da ville "Kelsar foer = Kelsar etter"
-- bevart en feil i stedet for en sannhet.
sonde as (
  select 'SONDE'::text, 'avdelinger som ligner drivstoff, men IKKE filtreres'::text,
         coalesce((
           select string_agg(distinct coalesce(d.avdeling_kode,'(null)')
                    || '/' || coalesce(d.avdeling_navn,'(null)'), ', ')
           from public.daglig_salg d
           where d.slettet_tid is null
             and d.dato between date '2026-05-01' and date '2026-07-31'
             and coalesce(d.avdeling_kode,'') <> '10'
             and upper(coalesce(d.avdeling_navn,'')) <> 'ENERGI'
             and (upper(coalesce(d.avdeling_navn,'')) like '%DRIVSTOFF%'
               or upper(coalesce(d.avdeling_navn,'')) like '%BENSIN%'
               or upper(coalesce(d.avdeling_navn,'')) like '%DIESEL%'
               or upper(coalesce(d.avdeling_navn,'')) like '%FUEL%'
               or upper(coalesce(d.avdeling_navn,'')) like '%ENERGI%')
         ), 'ingen - filteret ser komplett ut')::text,
         7::int, 'a'::text, 'a'::text
  union all
  select 'SONDE'::text, 'alle avdelinger i v_butikksalg mai-juli'::text,
         coalesce((
           select string_agg(distinct coalesce(v.avdeling_kode,'(null)')
                    || '/' || coalesce(v.avdeling_navn,'(null)'), ', ')
           from public.v_butikksalg v
           where v.dato between date '2026-05-01' and date '2026-07-31'
         ), '(tomt)')::text,
         7::int, 'a'::text, 'b'::text
),

-- ---- 8. Kanarifugl --------------------------------------------------
kanari as (
  select 'KANARIFUGL'::text, '1. filteret fjerner noe i mai-juli'::text,
         (case when coalesce(sum(a.oms) - coalesce(sum(b.oms), 0), 0) > 0
              then 'JA - ' || round(sum(a.oms) - coalesce(sum(b.oms), 0), 2)
                   || ' kr filtrert bort. Baselinen maaler noe.'
              else 'NEI - FILTERET FJERNER 0 KR. Baselinen er en tom seier: '
                   || '"identisk foer og etter" ville ogsaa vaert sant om '
                   || 'filteret var fjernet helt. Fiks intervallene foer du '
                   || 'stoler paa noen av tallene over.' end)::text,
         8::int, 'a'::text, 'a'::text
  from alt a
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
  where a.intervall <> '2026-02'
  union all
  select 'KANARIFUGL'::text, '2. februarkontrollen er null'::text,
         (case when coalesce(sum(a.oms) - coalesce(sum(b.oms), 0), 0) = 0
              then 'JA - som ventet. Foer april fantes ikke drivstoff.'
              else 'NEI - ' || round(sum(a.oms) - coalesce(sum(b.oms), 0), 2)
                   || ' kr filtrert i februar. Da kom drivstoff inn tidligere '
                   || 'enn antatt, og premisset for intervallvalget maa sjekkes.' end)::text,
         8::int, 'a'::text, 'b'::text
  from alt a
  left join butikk b on b.intervall = a.intervall and b.stasjon_id = a.stasjon_id
  where a.intervall = '2026-02'
  union all
  select 'KANARIFUGL'::text, '3. intervallene har data'::text,
         (case when count(*) > 0
               then 'JA - ' || count(*) || ' stasjon-intervaller med rader'
               else 'NEI - INGEN DATA. Fila maaler ingenting.' end)::text,
         8::int, 'a'::text, 'c'::text
  from butikk
  union all
  select 'KANARIFUGL'::text, '4. produksjonskodene finnes i data'::text,
         (case when count(*) > 0
               then 'JA - ' || count(*) || ' rader paa de aatte kodene'
               else 'NEI - INGEN PRODUKSJONSVARER. Produksjonsbaselinen er tom, '
                    || 'og "identisk foer og etter" beviser ingenting om planen.' end)::text,
         8::int, 'a'::text, 'd'::text
  from public.v_butikksalg v
  where v.dato between date '2026-05-01' and date '2026-07-31'
    and v.varegruppe_kode in
        ('1201','1202','1203','1216','1217','1218','1219','1221')
),

-- ---- 9. Omfang ------------------------------------------------------
omfang as (
  select 'OMFANG'::text, 'datospenn i daglig_salg'::text,
         coalesce(min(dato)::text || ' .. ' || max(dato)::text, '(tomt)')::text,
         9::int, 'a'::text, 'a'::text
  from public.daglig_salg where slettet_tid is null
  union all
  select 'OMFANG'::text, 'stasjoner med salg i mai-juli'::text,
         coalesce((
           select string_agg(distinct st.kjede || ' / ' || st.navn, ', ')
           from public.v_butikksalg v join stasjon st on st.id = v.stasjon_id
           where v.dato between date '2026-05-01' and date '2026-07-31'
         ), '(ingen)')::text,
         9::int, 'a'::text, 'b'::text
  union all
  select 'OMFANG'::text, 'foerste dato med drivstoff'::text,
         coalesce((
           select min(d.dato)::text
           from public.daglig_salg d
           where d.slettet_tid is null
             and (coalesce(d.avdeling_kode,'') = '10'
               or upper(coalesce(d.avdeling_navn,'')) = 'ENERGI')
         ), '(finnes ikke)')::text,
         9::int, 'a'::text, 'c'::text
)

select seksjon, noekkel, verdi from (
  select * from per_stasjon
  union all select * from per_kjede
  union all select * from filterdelta
  union all select * from drivstoffgrunnlag
  union all select * from produksjon
  union all select * from vern
  union all select * from sonde
  union all select * from kanari
  union all select * from omfang
) x
order by sort, s2, s3, noekkel;
