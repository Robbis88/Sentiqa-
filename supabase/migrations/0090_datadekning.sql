-- ---------------------------------------------------------------------
-- 0090: datadekning per kilde og stasjon
-- ---------------------------------------------------------------------
-- Importsiden skal si hva som mangler. Forste forsok hentet hver eneste
-- rad i salgstabellen til klienten for aa telle distinkte datoer. Det er
-- feil paa to maater: PostgREST kutter paa 1000 rader, saa svaret blir
-- loegn, og paa en tabell som vokser med drift er spoerringen dyr nok
-- til aa velte siden.
--
-- Tellingen hoerer hjemme der radene er. Visningen aggregerer i basen og
-- returnerer en haandfull rader.
--
-- security_invoker: RLS gjelder som for kalleren, saa en butikksjef ser
-- bare sine egne stasjoner. Uten den ville visningen kjort som eier.
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
  group by stasjon_id;

comment on view public.v_datadekning is
  'Hvor mye data hver kilde har, per stasjon. Mater "hva mangler"-listen '
  'paa importsiden. Aggregert i basen: klienten skal aldri hente radene '
  'for aa telle dem.';

grant select on public.v_datadekning to authenticated;
