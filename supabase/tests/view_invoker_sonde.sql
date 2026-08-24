-- =====================================================================
-- Sonde: hvilke views leser FORBI RLS?
--
-- REN LESING AV KATALOGEN. Ingen tabeller, views, funksjoner, policyer
-- eller data roeres. Trygg i produksjon.
--
-- HVORFOR DENNE FINNES
--
-- En view uten `security_invoker = true` kjoerer med EIERENS rettigheter.
-- Er den grantet til `authenticated`, leser hver innlogget bruker hele
-- den underliggende tabellen - forbi RLS, forbi retailer_id, forbi
-- stasjonstildeling. Det er den samme feilen som partisjonene hadde
-- fram til 0105, bare gjennom en annen doer.
--
-- Og den ser ikke ut som noe. `create or replace view` UTEN
-- `with (security_invoker = true)` nullstiller flagget i stillhet:
-- en senere migrasjon som redefinerer en view kan slaa av vernet uten
-- at noe feiler, og uten at diffen ser farlig ut.
--
-- Vakthunden fanger ikke dette i dag. Den ser paa tabeller med
-- policyer; en view har ingen policyer aa se paa.
--
-- HVA DU GJOER MED SVARET
--
-- Kommer det null rader: gapet er lukket i praksis, og sjekken kan
-- flyttes inn i `rls_vakthund.sql` som en fast kontroll.
-- Kommer det rader: hver av dem er en view en innlogget bruker kan
-- lese hele tabellen gjennom. Sjekk hvilken den er bygd paa foer du
-- konkluderer - noen faa er ment aa vaere kjedeuavhengige.
-- =====================================================================
select
  c.relname                                   as view_navn,
  coalesce(
    (select option_value
     from pg_options_to_table(c.reloptions)
     where option_name = 'security_invoker'),
    'ikke satt')                              as security_invoker,
  case
    when has_table_privilege('authenticated', c.oid, 'select') then 'ja'
    else 'nei'
  end                                         as authenticated_kan_lese,
  case
    when has_table_privilege('anon', c.oid, 'select') then 'JA'
    else 'nei'
  end                                         as anon_kan_lese,
  pg_get_userbyid(c.relowner)                 as eier
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('v', 'm')
  and (
    -- Enten uten invoker-flagget...
    coalesce(
      (select option_value
       from pg_options_to_table(c.reloptions)
       where option_name = 'security_invoker'), 'off') not in ('on', 'true')
    -- ...eller lesbar for anon, som ingen forretningsview skal vaere.
    or has_table_privilege('anon', c.oid, 'select')
  )
order by
  case when has_table_privilege('anon', c.oid, 'select') then 0 else 1 end,
  c.relname;
