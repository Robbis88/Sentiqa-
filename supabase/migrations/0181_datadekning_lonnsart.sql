-- =====================================================================
-- Sentiqa 0181 - onboardingen skal kjenne loennsarteksporten
--
-- 0179 la til `easyatwork_lonnsart` som rapporttype. Uten en arm her
-- ville `onboardingsteg()` gaatt over en kilde ingen maaler, og steget
-- ville staatt roedt for alltid.
--
-- IKKE KRITISK. Mangler fila, virker /lonnskost som foer: den leser
-- regnskapet, som er fasiten. Loennsarteksporten gir det samme tallet
-- TIDLIGERE - dagen etter maaneden i stedet for midt i den neste. Et
-- kritisk steg her ville stoppet en kjede som ikke har fila, for en
-- gevinst som er dager og ikke data.
--
-- ARMEN TELLER DAGER, IKKE LINJER. En stasjon har ~400 linjer i maaneden
-- fordelt paa ~30 dager. Talte vi linjer, ville terskelen i `maalKilder`
-- vaert meningsloes paa tvers av kilder.
--
-- ---------------------------------------------------------------------
-- HELE VIEWET GJENSKAPES, OG UTGANGSPUNKTET ER 0172 - IKKE 0163.
--
-- Foerste utgave av denne migrasjonen bygde paa kroppen fra 0163 og la
-- til én arm. Den ville droppet `kastbudsjett`-armen som 0172 la til:
-- `create or replace view` erstatter HELE definisjonen, saa en arm som
-- ikke staar i den nye teksten forsvinner uten at diffen ser farlig ut.
-- `onboarding.dekning.test.ts` felte den - den leser armene ut av siste
-- definisjon og krever at hver KILDE har en.
--
-- Samme grunn til at `with (security_invoker = true)` staar her: uten
-- klausulen nullstilles flagget i stillhet, og viewet leser som eieren,
-- forbi RLS.
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
  group by stasjon_id;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Skal kjenne hver rapporttype systemet tar imot - se '
  'TYPE_TIL_KILDE i src/lib/onboarding.ts og migrasjonene 0162/0163/0172/0181. '
  'Aggregert i basen: klienten skal aldri hente radene for aa telle dem.';

grant select on public.v_datadekning to authenticated;
revoke all on public.v_datadekning from anon;

-- Kvittering. `armer` skal vaere 10 - ni fra foer, pluss loennsartene.
select
  (select count(*) from pg_class c
    where c.relname = 'v_datadekning'
      and c.reloptions::text like '%security_invoker=true%')  as invoker,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'v_datadekning'
      and grantee = 'anon')                                   as anon,
  (select count(*) from (
     select distinct kilde from public.v_datadekning) k)      as kilder_med_data;
