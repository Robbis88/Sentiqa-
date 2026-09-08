-- =====================================================================
-- Sentiqa 0187 - onboardingen skal kjenne bilvaskabonnementene
--
-- 0184 la til `bilvask_abonnement`. Uten en arm her ville
-- `onboardingsteg()` gaatt over en kilde ingen maaler, og steget staatt
-- roedt for alltid. `onboarding.dekning.test.ts` nekter det.
--
-- ARMEN TELLER UKER, ikke rader. En rad ER en uke, saa de er det samme -
-- men `count(distinct ...)` gjoer det tydelig hva som maales, og taaler
-- at noen en dag legger inn to rader for samme uke.
--
-- IKKE FOR ALLE STASJONER. En stasjon uten vask skal ikke ha steget i
-- det hele tatt; Dale har ikke bilvask. Den avgrensningen gjoeres i
-- `gjelderBilvask()` i onboarding.ts, ikke her - viewet maaler hva som
-- FINNES, ikke hvem som burde hatt det.
--
-- ---------------------------------------------------------------------
-- HELE VIEWET GJENSKAPES, MED 0181 SOM UTGANGSPUNKT.
--
-- Forrige gang bygde jeg paa 0163 og ville droppet `kastbudsjett`-armen
-- fra 0172. `create or replace view` erstatter HELE definisjonen, saa en
-- arm som ikke staar i den nye teksten forsvinner uten at diffen ser
-- farlig ut. `with (security_invoker = true)` av samme grunn: uten
-- klausulen nullstilles flagget i stillhet.
--
-- Taaler aa kjoeres om igjen.
-- =====================================================================

create or replace view public.v_datadekning
with (security_invoker = true) as
  select 'st1_salgsstatistikk'::text as kilde,
         stasjon_id,
         count(distinct dato)        as dager,
         max(dato)::text             as siste_dato
  from public.v_butikksalg
  where dato is not null
  group by stasjon_id

  union all
  select 'timesalg', stasjon_id, count(distinct dato), max(dato)::text
  from public.timesalg
  where slettet_tid is null and dato is not null
  group by stasjon_id

  union all
  select 'stempling', stasjon_id, count(distinct dato), max(dato)::text
  from public.stempling
  where dato is not null
  group by stasjon_id

  union all
  select 'bemanning_maned', stasjon_id, count(*), max(ar)::text
  from public.bemanning_maned
  group by stasjon_id

  union all
  select 'regnskapslinjer', stasjon_id, count(distinct periode), max(periode)::text
  from public.regnskapslinjer
  where stasjon_id is not null and periode is not null
  group by stasjon_id

  union all
  select 'kassererstatistikk', stasjon_id, count(distinct dato), max(dato)::text
  from public.kassererstatistikk
  where slettet_tid is null and dato is not null
  group by stasjon_id

  union all
  select 'svinn', stasjon_id, count(distinct dato), max(dato)::text
  from public.synlig_svinn
  where slettet_tid is null and dato is not null
  group by stasjon_id

  -- NY I 0163: baerer aargangen timer, uansett hvilken fil de kom med.
  union all
  select 'bp_timer',
         stasjon_id,
         count(*) filter (where timer_aar is not null),
         max(ar) filter (where timer_aar is not null)::text
  from public.bp_aar
  group by stasjon_id
  having count(*) filter (where timer_aar is not null) > 0

  -- NY I 0172: kastbudsjettet fra delingsfila.
  union all
  select 'kastbudsjett',
         stasjon_id,
         count(*),
         max(ar)::text
  from public.kastbudsjett
  group by stasjon_id

  -- NY I 0181: loennsartene fra easy@work (0179).
  union all
  select 'lonnsart', stasjon_id, count(distinct dato), max(dato)::text
  from public.lonnsart_linje
  where dato is not null
  group by stasjon_id

  -- NY I 0187: bilvaskabonnementene (0184).
  union all
  select 'bilvask',
         stasjon_id,
         count(distinct (ar, uke)),
         max(ar || '-' || lpad(uke::text, 2, '0'))
  from public.bilvask_abonnement
  where slettet_tid is null
  group by stasjon_id;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Skal kjenne hver kilde i KILDER - se src/lib/onboarding.ts '
  'og migrasjonene 0162/0163/0172/0181/0187. '
  'Aggregert i basen: klienten skal aldri hente radene for aa telle dem.';

grant select on public.v_datadekning to authenticated;
revoke all on public.v_datadekning from anon;

-- Kvittering. `armer` skal vaere 11 - ti fra foer, pluss bilvask.
select
  (select count(*) from pg_class c
    where c.relname = 'v_datadekning'
      and c.reloptions::text like '%security_invoker=true%')  as invoker,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'v_datadekning'
      and grantee = 'anon')                                   as anon,
  (select count(*) from (
     select distinct kilde from public.v_datadekning) k)      as kilder_med_data;
