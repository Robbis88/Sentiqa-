-- ---------------------------------------------------------------------
-- 0180: loennsarter summert per maaned
-- ---------------------------------------------------------------------
-- AGGREGERINGEN HOERER HJEMME HER, IKKE I KLIENTEN.
--
-- Tretten maaneder raa linjer er over fem tusen rader for en stasjon.
-- PostgREST kutter et for stort svar UTEN aa feile - `.limit(20000)` blir
-- til rundt tusen rader, og en avkortet spoerring ser ut som en liten
-- stasjon, ikke som en feil. Den fella har kostet tre ganger allerede:
-- 0090 (bemanning), 0166 (kunder) og 0175 (svinnets nevner, som viste
-- 778,6 % fordi telleren var hel og nevneren avkortet).
--
-- Viewet gjoer det samme svaret til en drøy handfull rader per maaned.
--
-- GRUPPERT PAA HELE ETIKETTEN, ikke bare paa koden. Loennsart 97 finnes i
-- fire varianter, og hvilken variant det er avgjor om det er dagovertid
-- eller sondagsovertid. Grupperte vi paa koden, ville forskjellen
-- forsvunnet her i stedet for i lagringen - samme tap, ett lag senere.
create or replace view public.v_lonnsart_maaned
with (security_invoker = true) as
select
  l.stasjon_id,
  to_char(date_trunc('month', l.dato), 'YYYY-MM') as maaned,
  l.lonnsart,
  l.lonnsart_tekst,
  sum(l.timer)::numeric(12,2)    as timer,
  sum(l.belop_kr)::numeric(14,2) as belop_kr,
  count(*)                       as linjer
from public.lonnsart_linje l
group by l.stasjon_id, date_trunc('month', l.dato), l.lonnsart, l.lonnsart_tekst;

comment on view public.v_lonnsart_maaned is
  'Loennsarter summert per stasjon og maaned. Finnes for aa unngaa at PostgREST avkorter de raa linjene.';

-- SECURITY_INVOKER ER IKKE NOK ALENE. Supabase-standarden «alter default
-- privileges ... grant all on tables to anon» treffer ogsaa hvert nytt
-- view, og anon er rollen bak den offentlige noekkelen i hver sidelast.
-- Begge linjene, hver gang (0130, 0134).
grant select on public.v_lonnsart_maaned to authenticated;
revoke all on public.v_lonnsart_maaned from anon;

-- Kvittering.
select
  (select count(*) from pg_views
    where schemaname = 'public' and viewname = 'v_lonnsart_maaned')          as viewet_finnes,
  (select count(*) from pg_class c
    where c.relname = 'v_lonnsart_maaned'
      and c.reloptions::text like '%security_invoker=true%')                 as invoker,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'v_lonnsart_maaned'
      and grantee = 'anon')                                                  as anon;
