-- =====================================================================
-- Sentiqa 0163 - onboardingen skal se om BP-en faktisk baerer timer
--
-- BP-STEGET LOVET FOR MYE
--
-- `v_datadekning` maalte BP ved aa telle rader i `bemanning_maned`. Er
-- de der, sto steget «Paa plass». Men aarsrammen har TO halvdeler, og
-- den ene ble ikke maalt:
--
--   bemanning_maned   maanedsfordelingen planleggeren leser
--   bp_aar.timer_aar  aarets timebudsjett - kroner per time maales mot det
--
-- `timer_aar` er `null` naar FORMATET ikke baerer timebudsjett: St1-malen
-- til og med BP25 har det ikke. Da kommer timene i en egen fil,
-- delingsfila (`st1_delingsfil`), som skriver dem inn i aargangen BP-fila
-- alt har opprettet.
--
-- HVORFOR IKKE MAALE «KOM DELINGSFILA»
--
-- Fordi det ville vaert aa be om arbeid som for mange ikke finnes.
-- BP26-malen baerer timene selv - en kjede paa nytt format skal aldri
-- laste opp en delingsfil, og et onboardingsteg som ber om den ville
-- vaert et steg ingen kan fullfoere og ingen trenger.
--
-- AGENTS.md: «Automatiserer vi inntaksadressen, skal det manuelle
-- kontrollpunktet UT av onboarding - ellers vokser lista med arbeid som
-- ikke finnes lenger, og da slutter folk aa tro paa den.»
--
-- Spoersmaalet er derfor ikke hvilken fil timene kom med, men OM de kom.
-- `v_bp_aarganger` (0155) stiller allerede det spoersmaalet per kjede
-- (`stasjoner_med_timer` < `stasjoner`); denne armen stiller det per
-- stasjon, som er kornet onboardinglista maaler paa.
--
-- HAVING-EN ER IKKE PYNT. `maalKilder` i src/app/(beskyttet)/import/page.tsx
-- teller en stasjon som «har data» saa snart den har en RAD. En stasjon
-- med en BP uten timer ville altsaa telt som dekket mens tallet manglet -
-- nøyaktig feilen denne migrasjonen retter. Raden skal ikke finnes naar
-- det ikke er noen timer aa vise til.
--
-- DE TO ER LIKEVEL IKKE SAMME SPOERSMAAL. `bp_timer` er aarsrammen,
-- `bemanning_maned` er fordelingen paa maaneder. Da denne migrasjonen
-- ble skrevet kunne den foerste finnes uten den andre - delingsfila
-- skrev bare `timer_aar`. Det er lukket: `fordelFraDokument` i
-- `import/kjerne.ts` fordeler naa fra `bp_linje`. Armene staar begge
-- fordi de fortsatt kan svare ulikt: en BP uten timer gir maaneder uten
-- aarsramme.
--
-- Taaler aa kjoeres om igjen: `create or replace view`.
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
  having count(*) filter (where timer_aar is not null) > 0;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Skal kjenne hver rapporttype systemet tar imot - se '
  'TYPE_TIL_KILDE i src/lib/onboarding.ts og migrasjonene 0162/0163. '
  'Aggregert i basen: klienten skal aldri hente radene for aa telle dem.';

grant select on public.v_datadekning to authenticated;
revoke all on public.v_datadekning from anon;
