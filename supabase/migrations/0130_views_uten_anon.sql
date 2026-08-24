-- =====================================================================
-- 0130 - views skal ikke vaere lesbare for anon
--
-- FUNNET (2026-08-24, av supabase/tests/view_invoker_sonde.sql):
-- alle 21 views i `public` hadde SELECT for `anon`. Ingen skrev det;
-- det kom av seg selv, fra Supabase-standarden
--
--     alter default privileges in schema public
--       grant all on tables to anon, authenticated, service_role
--
-- - den samme mekanismen som ga de 49 partisjonene rettigheter i 0105.
-- `anon` er rollen bak den offentlige noekkelen som ligger i hver
-- sidelast av appen.
--
-- ---------------------------------------------------------------------
-- DETTE VAR IKKE EN AAPEN DOER, OG DET ER POENGET
--
-- Alle 21 er `security_invoker = true`. En invoker-view kan ikke
-- returnere mer enn kalleren kunne lest direkte fra tabellene under, og
-- `anon` har ikke SELECT paa `daglig_salg` eller `synlig_svinn` (0003,
-- 0105). Et anon-kall stopper med «permission denied», ikke med data.
--
-- Vernet hviler altsaa i sin helhet paa at revoke-en i det ANDRE laget
-- staar. Det er nøyaktig formen paa partisjonsfeilen: ett lag som holder
-- alene, og et grant som allerede ligger klart den dagen det laget
-- glipper. Da er det billigere aa ta grantet enn aa stole paa at det
-- aldri blir farlig.
--
-- ---------------------------------------------------------------------
-- FRAMTIDIGE VIEWS
--
-- Denne rydder det som staar i basen naar den kjoeres. En view som
-- lages i en SENERE migrasjon faar grantet paa nytt, av samme
-- standardregel. Derfor:
--
--   * nye views skal `revoke all ... from anon` ved siden av sitt
--     `grant select ... to authenticated` (se AGENTS.md), og
--   * `rls_vakthund.sql` punkt 9 kaster hvis en view mangler
--     `security_invoker` eller er lesbar for anon.
--
-- Regelen alene er ikke nok - den ble glemt for partisjonene i to aar.
-- Vakten er det som gjoer den til noe annet enn en god intensjon.
--
-- Ingen appkode leser som `anon`: hver forespoersel i appen har en
-- innlogget bruker, og rollen er da `authenticated`. Aa ta rettigheten
-- fra anon er derfor uten funksjonell virkning.
-- =====================================================================

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
      and c.relkind in ('v', 'm')      -- views og materialiserte views
      and has_table_privilege('anon', c.oid, 'select')
    order by c.relname
  loop
    execute format('revoke all on public.%I from anon', r.relname);
    antall := antall + 1;
  end loop;

  raise notice '0130: tok SELECT fra anon paa % views', antall;
end $$;
