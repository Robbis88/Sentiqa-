-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/migrations/*.sql
-- Regenerer: OPPDATER_FUNKSJONER=1 npx vitest run src/lib/sql
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet.
--
-- ER ALT SOM ER LOVET LEVERT?
--
-- Migrasjonene kjoeres for haand, og det finnes ingen historikk-tabell.
-- `0075_malekort_stasjoner.sql` var aldri kjoert mot produksjon -
-- trolig i maanedsvis - og ingenting sa fra. Funksjonen fantes bare
-- ikke, og flata som kalte den svelget feilen og viste «Ingen
-- stasjoner.»
--
-- De andre vaktene gaar fra basen til kontrakten: de spoer om alt som
-- FINNES er forklart. Denne gaar motsatt vei, og det er hele poenget -
-- en funksjon som mangler finnes ikke, og blir derfor ikke sett av dem.
--
-- Kjoeres trygt naar som helst. Leser bare katalogen.

do $$
declare
  forventet text[] := array[
    'beregn_kategori_vaerprofil',
    'beregn_malekort_salg',
    'beregn_stasjon_kunder',
    'beregn_vaerprofil',
    'gjeldende_retailer_id',
    'gjeldende_rolle',
    'har_stasjonstilgang',
    'kampanje_analyse',
    'kvitter_tablet_melding',
    'lagre_puls_svar',
    'malekort_salgsdatoer',
    'malekort_stasjoner',
    'matsalg_vindu_sum',
    'mine_stasjoner',
    'regnskap_sum',
    'sett_avvik_lopenr',
    'sett_oppdatert_tid',
    'slett_person',
    'slett_retailer_permanent',
    'som_uuid',
    'svinn_sum',
    'svinn_vindu_sum',
    'uke_avdeling_aggregat',
    'utsolgt_kandidater',
    'verifiser_ansatt_pin'
  ];
  mangler text[];
  funnet  int;
begin
  select count(*) into funnet
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = any(forventet);

  -- KANARIFUGL. Finner den ingen av dem, maaler den ingenting - og
  -- «ingen mangler» ville sett noeyaktig ut som «alt er paa plass».
  -- Det skjer hvis noen bytter skjema, eller hvis lista blir tom.
  if funnet = 0 then
    raise exception
      'VAKTEN MAALER INGENTING: fant ingen av de % forventede funksjonene i public. Feil skjema, eller tom liste?',
      coalesce(array_length(forventet, 1), 0);
  end if;

  select array_agg(f order by f) into mangler
  from unnest(forventet) as f
  where not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = f
  );

  if mangler is not null then
    raise exception
      'MANGLER % av % funksjoner - en migrasjon er ikke kjoert: %',
      array_length(mangler, 1),
      array_length(forventet, 1),
      array_to_string(mangler, ', ');
  end if;
end $$;

-- Kvittering. SQL Editor viser ikke `raise notice`, saa svaret maa
-- komme som en rad.
select 'OK'                                    as status,
       count(*)                                as funksjoner_i_public,
       25                          as forventet_av_migrasjonene
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';
