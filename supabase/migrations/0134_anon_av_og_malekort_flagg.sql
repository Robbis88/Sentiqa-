-- =====================================================================
-- 0134 - to lag paa tabellene, og malekortet leser sitt eget flagg
--
-- PORT 1 fant ingen lekkasje. Denne migrasjonen retter det som likevel
-- kom fram: en rettighet som ligger klar uten aa vaere i bruk, og ett
-- flagg som lover noe RLS aldri leser.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) SELECT fra anon paa alle tabeller i public
--
-- `0130` gjorde dette for views. Dette er tvillingtilfellet, og det
-- kommer av samme kilde: Supabase-standarden
--
--     alter default privileges in schema public
--       grant all on tables to anon, authenticated, service_role
--
-- traff hver tabell da den ble laget. `anon` er rollen bak den
-- offentlige noekkelen i hver eneste sidelast.
--
-- MAALT, IKKE ANTATT. postgrest_sonde.mjs sonderte 103 ressurser som
-- anon over ekte HTTPS 2026-08-25:
--
--     sperret 26  |  tomt 77  |  LEKKASJE 0
--
-- De 26 var alle 24 views (0130) pluss ansatte og pin_forsok (0112). De
-- 77 andre svarte `200 []`: granten fantes, RLS returnerte ingenting.
--
-- DERFOR ER DETTE UTEN FUNKSJONELL VIRKNING, og det er ikke et
-- resonnement - det er en maaling. Fikk anon null rader fra alle 77 i
-- dag, kan ingen funksjon vaere avhengig av at den leser dem. Hver
-- forespoersel i appen har en innlogget bruker, og rollen er da
-- `authenticated`.
--
-- Vernet hviler i dag PAA RLS ALENE paa de 77. Det er ett lag, og
-- prosjektet har to ganger sett det andre laget forsvinne av seg selv:
-- 49 partisjoner i `0105`, 21 views i `0130`. Ingen skrev de grantene.
--
-- PARTISJONER ER MED, og det er med vilje. `relkind` 'r' fanger dem,
-- 'p' fanger foreldrene. Partisjoner arver ikke rettigheter, saa en ny
-- partisjon av daglig_salg faar sitt eget grant fra default privileges
-- - nettopp det som skjedde i 0105.
-- ---------------------------------------------------------------------
do $$
declare
  r record;
  antall int := 0;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')      -- tabeller og partisjonerte tabeller
      and has_table_privilege('anon', c.oid, 'select')
    order by c.relname
  loop
    execute format('revoke all on public.%I from anon', r.relname);
    antall := antall + 1;
  end loop;

  raise notice '0134: tok rettigheter fra anon paa % tabeller', antall;
end $$;


-- ---------------------------------------------------------------------
-- 2) malekort_les skal lese `vis_tablet` og `vis_butikksjef`
--
-- Kolonnene har staatt i tabellen siden `0073`. Produktbeslutningen er
-- altsaa tatt for lenge siden - policyen har bare aldri konsultert den:
--
--     using (retailer_id = (select public.gjeldende_retailer_id())
--            and slettet_tid is null)
--
-- Retailer-scopet, ingen rolle, ingen flagg. Kanarifuglen beviste
-- foelgen 2026-08-25: nettbrettet leste et malekort merket
-- `vis_tablet = false`.
--
--     ok | DAGENS TILSTAND: nettbrett A1 leser malekort med vis_tablet = false
--
-- Ikke en lekkasje mellom kjeder - raden var stasjonens egen retailer.
-- Men et flagg som bare gjelder i grensesnittet er ikke en grense.
--
-- ATFERDSBEVARENDE FOR APPEN, og det er derfor denne kan gjoeres uten
-- en produktavklaring: begge lesestedene filtrerer allerede paa
-- noeyaktig de samme kolonnene.
--
--     vaar-stasjon/page.tsx:61   .eq('vis_tablet', true)
--     maaling/page.tsx:71        .eq('vis_butikksjef', true)   (butikksjef)
--
-- Policyen gjentar altsaa det appen alt gjoer. Forskjellen er at den
-- ogsaa gjelder for en forespoersel som ikke gaar gjennom appen.
--
-- `retailer_admin` er uendret og ser alle kortene - det er der de
-- settes opp, og `maaling/page.tsx:154` viser flaggene som merkelapper.
--
-- Funksjonskallet er pakket i `(select ...)` saa det blir initplan.
-- malekort er en VARM tabell.
-- ---------------------------------------------------------------------
drop policy if exists malekort_les on public.malekort;
create policy malekort_les on public.malekort for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and slettet_tid is null
    and case (select public.gjeldende_rolle())
          when 'butikkbruker_tablet' then vis_tablet
          when 'butikksjef'          then vis_butikksjef
          else true
        end
  );

comment on policy malekort_les on public.malekort is
  'Leser vis_tablet og vis_butikksjef. Flaggene har vaert visningsvilkaar '
  'i appen siden 0073; her er de en grense. retailer_admin ser alle.';


-- ---------------------------------------------------------------------
-- ETTER DENNE: kjor supabase/tests/rls_vakthund.sql.
--
-- Den har faatt et nytt punkt 10 som holder tabellene lukket. Uten en
-- vakt er punkt 1 over bare en opprydding som varer til neste tabell -
-- akkurat som regelen om partisjoner var i to aar foer `0105`.
-- ---------------------------------------------------------------------
