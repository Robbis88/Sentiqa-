-- =====================================================================
-- STEG 2: FINNES KELSAR-BACKFILLEN?
--
-- Kjoeres RETT ETTER 0152. Leser kun.
--
-- Migrasjonens egen kvittering teller rader. Denne viser dem, fordi et
-- antall kan stemme mens innholdet er feil - og fordi den ene raden som
-- betyr noe er `laaste_kjeder_med_salg = 0`.
--
-- **STOPP hvis noen rad under sier annet enn OK.** En kjede med salg og
-- uten konfigurasjon ser null rader i hele produktet.
-- =====================================================================

with forventet_produksjon(kode) as (
  values ('1201'),('1202'),('1203'),('1216'),('1217'),('1218'),('1219'),('1221')
),
kjeder_med_salg as (
  select distinct d.retailer_id from public.daglig_salg d where d.slettet_tid is null
)

select 'ERKLAERING'::text as seksjon,
       (r.navn)::text     as noekkel,
       ('gjelder=' || e.gjelder
         || ' kontrollert=' || coalesce(e.kontrollert_tid::date::text, '(nei)')
         || ' oppgitt=' || e.oppgitt_tid::date)::text as verdi,
       1::int as sort
from public.retailer_kodeerklaering e
join public.retailers r on r.id = e.retailer_id

union all
select 'DRIVSTOFFREGLER', r.navn,
       coalesce(string_agg(coalesce(g.kode, '(null)') || '/' || coalesce(g.navn, '(null)'),
                           ', ' order by coalesce(g.kode, 'zz')), '(INGEN)'),
       2
from public.retailers r
join public.retailer_koderegel g on g.retailer_id = r.id and g.rolle = 'drivstoff'
group by r.navn

union all
select 'PRODUKSJONSKODER', r.navn,
       'antall=' || count(*) || ' koder=' || string_agg(g.kode, ',' order by g.kode),
       3
from public.retailers r
join public.retailer_koderegel g on g.retailer_id = r.id and g.rolle = 'produksjon'
group by r.navn

union all
select 'STATUS', r.navn || ' | ' || s.rolle, s.status, 4
from public.v_retailer_kodestatus s
join public.retailers r on r.id = s.retailer_id

union all
select 'TREFFER MAPPINGEN', r.navn,
       'treff_rader=' || t.treff_rader
         || ' treff_kr=' || round(t.treff_kr, 2)
         || ' rader_i_vindu=' || t.rader_i_vindu
         || ' periode=' || t.fra || '..' || t.til,
       5
from public.v_retailer_drivstofftreff t
join public.retailers r on r.id = t.retailer_id

-- ---- Kontrollene. Les disse foerst. --------------------------------

union all
select 'KONTROLL', '1. produksjonskodene er de aatte forventede',
       case when not exists (
         select 1 from kjeder_med_salg k
         where (select count(*) from public.retailer_koderegel g
                join forventet_produksjon f on f.kode = g.kode
                where g.retailer_id = k.retailer_id and g.rolle = 'produksjon') <> 8)
       then 'OK - hver kjede med salg har alle aatte'
       else 'STOPP - en kjede mangler koder eller har feil koder' end, 6

union all
select 'KONTROLL', '2. drivstoffreglene har bade kode 1000 og navn ENERGI',
       case when not exists (
         select 1 from kjeder_med_salg k
         where not exists (select 1 from public.retailer_koderegel g
                           where g.retailer_id = k.retailer_id and g.rolle = 'drivstoff'
                             and g.kode = '1000')
            or not exists (select 1 from public.retailer_koderegel g
                           where g.retailer_id = k.retailer_id and g.rolle = 'drivstoff'
                             and upper(g.navn) = 'ENERGI'))
       then 'OK - begge armene fra dagens filter er med'
       else 'STOPP - en kjede mangler kode- eller navnearmen' end, 6

union all
select 'KONTROLL', '3. INGEN kjede med salg er laast ute',
       case when (select count(*) from kjeder_med_salg k
                  where not exists (select 1 from public.v_retailer_kodestatus s
                                    where s.retailer_id = k.retailer_id
                                      and s.rolle = 'drivstoff'
                                      and s.status in ('mappet', 'ingen_kontrollert'))) = 0
       then 'OK - alle kjeder med salg ser radene sine'
       else 'STOPP - EN KJEDE MED SALG SER NULL RADER I HELE PRODUKTET' end, 6

union all
select 'KONTROLL', '4. viewet har fortsatt security_invoker',
       coalesce((select case when c.reloptions::text like '%security_invoker=true%'
                             then 'OK - true'
                             else 'STOPP - MANGLER: ' || coalesce(c.reloptions::text, '(ingen)') end
                 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'public' and c.relname = 'v_butikksalg'),
                'STOPP - VIEWET FINNES IKKE'), 6

union all
select 'KONTROLL', '5. anon naar ingen av de nye tabellene',
       case when not exists (
         select 1 from information_schema.role_table_grants
         where table_schema = 'public' and grantee = 'anon'
           and table_name in ('retailer_kodeerklaering', 'retailer_koderegel',
                              'v_retailer_kodestatus', 'v_retailer_drivstofftreff'))
       then 'OK - anon er utestengt fra alle fire'
       else 'STOPP - anon har grant paa en av dem' end, 6

union all
select 'KONTROLL', '6. ingen approlle kan sette kontrollert_tid',
       case when (select count(*) from pg_policies
                  where schemaname = 'public' and tablename = 'retailer_kodeerklaering'
                    and cmd in ('INSERT', 'UPDATE')
                    and with_check like '%kontrollert_tid IS NULL%') = 2
       then 'OK - begge skrivepolicyene krever at den er null'
       else 'STOPP - en skrivepolicy mangler vernet, og da kan en retailer '
            || 'bekrefte sin egen paastand og aapne alle radene sine' end, 6

order by sort, noekkel;
