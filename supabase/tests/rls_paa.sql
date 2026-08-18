-- =====================================================================
-- Sentiqa - er RLS i det hele tatt PAA?
--
-- rls_vakthund.sql leter etter TREGE policyer. Den forutsetter at det
-- finnes policyer aa vurdere. En tabell uten RLS har ingen rader i
-- pg_policies, og var derfor usynlig for alle fire sjekkene - den saa ut
-- som en tabell uten problemer.
--
-- Det er den motsatte feilen av den vakthunden ble bygget for, og den
-- verre av de to: treg RLS gir null rader (feiler lukket), mens manglende
-- RLS gir ALLE rader til alle innloggede (feiler aapent).
--
-- Leser kun katalogen. Trygt i produksjon.
-- =====================================================================

-- Del 1: tabeller som REPOET lager, men som ikke finnes i basen.
-- Uten denne ser «ingen policy» likt ut enten tabellen mangler policy
-- eller mangler helt - to helt ulike saker med to ulike fikser.
select
  t                                                as tabell,
  null::boolean                                    as rls_paa,
  null::boolean                                    as rls_tvunget,
  0::bigint                                        as antall_policyer,
  null::boolean                                    as har_retailer_id,
  null::boolean                                    as har_stasjon_id,
  'TABELLEN FINNES IKKE - migrasjonen som lager den er ikke kjort'
                                                   as dom
from unnest(array[
  'fakturaer', 'opplaring_fullfort', 'opplaring_personer', 'opplaring_punkter'
]) as t
where not exists (
  select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = t and c.relkind = 'r')

union all

-- Del 2: tabeller som finnes, men mangler RLS eller policy.
select
  c.relname                                        as tabell,
  c.relrowsecurity                                 as rls_paa,
  c.relforcerowsecurity                            as rls_tvunget,
  count(p.policyname)                              as antall_policyer,
  bool_or(a.attname = 'retailer_id')               as har_retailer_id,
  bool_or(a.attname = 'stasjon_id')                as har_stasjon_id,
  case
    when not c.relrowsecurity and bool_or(a.attname in ('retailer_id', 'stasjon_id'))
      then 'ALVORLIG: tenantdata uten RLS - alle innloggede kan lese alt'
    when not c.relrowsecurity
      then 'RLS av (sjekk om tabellen skal vaere delt)'
    -- RLS paa + ingen policy + ingen rettighet til de innloggede rollene
    -- er ikke en feil: det er en tabell som med vilje bare naas av
    -- service_role, som gaar utenom RLS. oversettelse_cache (0037) er
    -- nettopp det. Uten dette leddet melder vakten den som hull hver
    -- gang, og en vakt man laerer seg aa overse er verre enn ingen.
    when count(p.policyname) = 0
      and not has_table_privilege('authenticated', c.oid, 'SELECT')
      and not has_table_privilege('anon', c.oid, 'SELECT')
      then 'ok - kun service_role, RLS stenger alle andre'
    when count(p.policyname) = 0
      then 'RLS paa, men INGEN policy - tabellen gir null rader til alle'
    else 'ok'
  end                                              as dom
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
left join pg_policies p on p.schemaname = n.nspname and p.tablename = c.relname
where n.nspname = 'public'
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity, c.relforcerowsecurity
having
  not c.relrowsecurity
  or (count(p.policyname) = 0
      and (has_table_privilege('authenticated', c.oid, 'SELECT')
           or has_table_privilege('anon', c.oid, 'SELECT')))

order by 7, 1;
