-- =====================================================================
-- Sentiqa - er partisjonene faktisk naabare?
--
-- daglig_salg er partisjonert. Partisjonene har relrowsecurity = false,
-- og det SER alvorlig ut. Men i Postgres gjelder forelderens RLS naar man
-- spor gjennom forelderen; partisjonens egen RLS gjelder bare ved DIREKTE
-- oppslag paa partisjonen.
--
-- Direkte oppslag krever at rollen har rettighet paa selve partisjonen.
-- Rettigheter arves IKKE automatisk fra den partisjonerte tabellen.
--
-- Denne sporringen avgjor saken: har `authenticated` SELECT paa
-- partisjonen, er hullet ekte og PostgREST kan naa den som egen ressurs.
-- Har den ikke det, er relrowsecurity = false uten praktisk betydning.
--
-- Leser kun katalogen. Trygt i produksjon.
-- =====================================================================

select
  c.relname                                            as partisjon,
  par.relname                                          as forelder,
  c.relrowsecurity                                     as rls_paa_partisjon,
  par.relrowsecurity                                   as rls_paa_forelder,
  has_table_privilege('authenticated', c.oid, 'SELECT') as auth_kan_lese,
  has_table_privilege('anon', c.oid, 'SELECT')          as anon_kan_lese,
  case
    when has_table_privilege('anon', c.oid, 'SELECT')
      then 'KRITISK: anon kan lese partisjonen direkte, uten RLS'
    when has_table_privilege('authenticated', c.oid, 'SELECT') and not c.relrowsecurity
      then 'ALVORLIG: enhver innlogget kan lese partisjonen direkte, uten RLS'
    when not c.relrowsecurity
      then 'ok - ingen rettighet paa partisjonen, kun naabar via forelder'
    else 'ok'
  end                                                  as dom
from pg_class c
join pg_inherits i on i.inhrelid = c.oid
join pg_class par on par.oid = i.inhparent
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  -- Kun tabeller. Partisjonerte INDEKSER arver ogsaa via pg_inherits, og
  -- foerste utgave listet dem som «partisjoner» - hundre rader stoy over
  -- de femti som betydde noe.
  and c.relkind = 'r'
  and c.relispartition
order by
  case
    when has_table_privilege('anon', c.oid, 'SELECT') then 0
    when has_table_privilege('authenticated', c.oid, 'SELECT') and not c.relrowsecurity then 1
    else 2
  end,
  c.relname;
