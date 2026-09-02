-- =====================================================================
-- Sentiqa 0162 - datadekningen skal kjenne alle kildene systemet tar imot
--
-- TO HAANDHOLDTE LISTER SOM MAATTE VAERE ENIGE, OG INGEN SOM SJEKKET
--
-- `v_datadekning` (0090) telte fem kilder. `KILDER` i
-- `src/lib/onboarding.ts` beskrev de samme fem. De var enige, saa det saa
-- riktig ut.
--
-- Men systemet tar imot AATTE rapporttyper. `Rapporttype` i
-- `src/lib/parsere/typer.ts` og lagringsarmene i `import/kjerne.ts` er
-- fasiten, og tre av dem sto ingen av stedene:
--
--   st1_cashierstats     0018  ->  kassererstatistikk   /kasserer
--   salgsgrid_varetrans  0452  ->  synlig_svinn         /svinn
--   st1_delingsfil             ->  timene i BP-aargangen
--
-- `onboardingsteg()` gaar over KILDER. En maaling uten oppfoering der
-- blir kastet i stillhet - saa selv om visningen hadde talt dem, ville
-- lista ikke vist dem. Begge sider maatte utvides.
--
-- FOELGEN: en ny retailer kunne se en komplett onboardingliste, laste opp
-- alt den ba om, og sitte igjen med to tomme moduler uten at noe sa fra.
-- Det er samme form som en vakt som slutter aa se: lista saa like ferdig
-- ut dagen den ble feil.
--
-- Delingsfila faar ingen egen arm. Den skriver timer inn i aargangen
-- BP-fila oppretter - samme krav, to filer - og har ingen dekning aa
-- telle per dag.
--
-- SVINN ER IKKE ET DAGLIG DATASETT (se 0159). Her telles det likevel som
-- dager, men det er et annet spoersmaal enn i `v_datohull`: der var
-- spoersmaalet «mangler det en dag», og en dag uten kast er en normal
-- dag. Her er spoersmaalet «har vi foeringer i det hele tatt», og til det
-- er antall dager med foering riktig maal. Terskelen i KILDER er satt
-- lavt (30) av samme grunn.
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

  -- NYE I 0162
  union all
  select 'kassererstatistikk', stasjon_id, count(distinct dato), max(dato)::text
  from public.kassererstatistikk
  where slettet_tid is null and dato is not null
  group by stasjon_id

  union all
  select 'svinn', stasjon_id, count(distinct dato), max(dato)::text
  from public.synlig_svinn
  where slettet_tid is null and dato is not null
  group by stasjon_id;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Skal kjenne hver rapporttype systemet tar imot - se '
  'TYPE_TIL_KILDE i src/lib/onboarding.ts og migrasjon 0162. Aggregert i '
  'basen: klienten skal aldri hente radene for aa telle dem.';

grant select on public.v_datadekning to authenticated;
revoke all on public.v_datadekning from anon;
