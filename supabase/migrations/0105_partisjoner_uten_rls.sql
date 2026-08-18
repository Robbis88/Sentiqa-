-- =====================================================================
-- 0105 - partisjonene arvet aldri vernet
--
-- FUNNET (2026-08-18, av dekningssjekken i rls_vakthund.sql):
--
--   daglig_salg har RLS og riktige policyer. De 49 partisjonene har
--   relrowsecurity = false, OG bade anon og authenticated har SELECT paa
--   dem. Da er
--
--       GET /rest/v1/daglig_salg_202601?select=*
--
--   nok til aa hente alle kjeders salgstall, forbi forelderens RLS.
--   anon er rollen bak den offentlige noekkelen som ligger i hver
--   sidelast av appen.
--
-- HVORFOR DET SKJEDDE:
--
--   0003 lager partisjonene i en loekke og setter RLS paa FORELDEREN.
--   Det er riktig for oppslag GJENNOM forelderen - Postgres bruker da
--   forelderens policyer paa alle rader. Men et direkte oppslag paa en
--   partisjon bruker partisjonens EGEN RLS, og rettigheter arves ikke.
--
--   Supabase har som standard
--       alter default privileges in schema public
--         grant all on tables to anon, authenticated, service_role
--   saa hver nyopprettet tabell i public - ogsaa en partisjon - faar
--   rettigheter automatisk. Ingen skrev `grant`; den kom av seg selv.
--
-- HVORFOR INGEN SAA DET:
--
--   Vakthunden lette etter TREGE policyer og forutsatte at det fantes
--   policyer aa vurdere. En tabell uten RLS har ingen rader i
--   pg_policies og var derfor usynlig for alle sjekkene - den saa ut
--   som en tabell uten problemer. Treg RLS feiler LUKKET (null rader);
--   manglende RLS feiler AAPENT. Vakten var bygget for den milde av de
--   to feilene.
--
-- Ingen appkode roerer partisjonene direkte: importen skriver til
-- daglig_salg, og lesingen gaar via v_butikksalg. Aa ta rettighetene
-- fra dem er derfor uten funksjonell virkning.
-- =====================================================================

do $$
declare
  r record;
  antall int := 0;
begin
  -- Alle partisjoner av alle partisjonerte tabeller i public. Generisk
  -- med vilje: kommer det en partisjonert tabell til, er den dekket.
  for r in
    select c.oid, c.relname, par.relname as forelder
    from pg_class c
    join pg_inherits i on i.inhrelid = c.oid
    join pg_class par on par.oid = i.inhparent
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'          -- kun tabeller; partisjonerte indekser arver ogsaa
      and c.relispartition
  loop
    -- 1) Ta bort tilgangen. Dette er selve hullet.
    execute format('revoke all on public.%I from anon, authenticated', r.relname);

    -- 2) Slaa paa RLS ogsaa. Belte og seler: skulle en rettighet komme
    --    tilbake - via default privileges eller en uforsiktig grant -
    --    gir partisjonen null rader i stedet for alle. En feil som
    --    feiler lukket er en annen slags feil enn en som feiler aapent.
    --
    --    Trygt for oppslag gjennom forelderen: Postgres bruker
    --    forelderens policyer da, ikke partisjonens.
    execute format('alter table public.%I enable row level security', r.relname);

    antall := antall + 1;
  end loop;

  raise notice '0105: sikret % partisjoner (revoke fra anon+authenticated, RLS paa)', antall;
end $$;

-- Framtidige partisjoner: 0003 lager dem i en loekke, og den er rettet i
-- samme slengen saa en full gjenkjoring fra 0001 ikke gjeninnfoerer
-- hullet. Denne migrasjonen rydder det som allerede staar i basen.
--
-- Kontroll etter kjoring: supabase/tests/rls_partisjoner.sql skal gi
-- «ok» paa hver rad.
