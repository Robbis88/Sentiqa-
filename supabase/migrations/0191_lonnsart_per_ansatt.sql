-- ---------------------------------------------------------------------
-- 0191: loennsartene summert PER ANSATT per maaned
-- ---------------------------------------------------------------------
-- Sandra paa Lone sto i easy@work-eksporten med 193,50 timer og en
-- timesats paa 285 - 57 957 kroner ingen har faatt utbetalt. Hun har
-- fastloenn, og stemplingene hennes er arbeidstid, ikke loennsgrunnlag.
--
-- `ansatt_avtale.lonnsform` er regelen som holder henne utenfor, og den
-- fantes fra `0099`. Problemet var HVOR den kunne settes: bare paa
-- `/lonn`, som regnes fra STEMPLINGENE. Lone hadde ingen stemplinger
-- for august, saa sida var tom, og Sandra kunne ikke markeres i det
-- hele tatt.
--
-- Et ansettelsesforhold skal ikke vaere avhengig av at en helt annen
-- fil er lastet opp. Dette viewet gjoer at /lonnskost kan vise hvem
-- loennsdataene faktisk kjenner - og der er hun.
--
-- TIMER TELLES BARE PAA LOENNSART 2. Tilleggene baerer de samme timene
-- en gang til; et kveldstillegg er ikke en ekstra time, det er en
-- dyrere. Summert over alle artene ga Dale 1 907,81 mot 1 264,73
-- arbeidede.
--
-- EGET VIEW, IKKE ET RAATT UTTREKK. Samme grunn som `0180`: PostgREST
-- avkorter paa tusen rader UTEN aa feile, og en avkortet sum ser ut som
-- en liten stasjon. Laguneparken alene har 365 linjer i august.
create or replace view public.v_lonnsart_ansatt_maaned
with (security_invoker = true) as
select
  l.stasjon_id,
  to_char(date_trunc('month', l.dato), 'YYYY-MM')                as maaned,
  l.ansatt_nr,
  -- Navnet kan skrives ulikt mellom to filer; det nyeste vinner.
  (array_agg(l.ansatt_navn order by l.dato desc))[1]             as ansatt_navn,
  sum(l.timer) filter (where l.lonnsart = '2')::numeric(12,2)    as timer,
  sum(l.belop_kr)::numeric(14,2)                                 as belop_kr,
  -- Er kronene REGNET av satstabellen eller LEST av kronefila (0188)?
  -- Et beregnet tall og et lest tall er ikke det samme tallet.
  bool_or(l.belop_beregnet)                                      as beregnet
from public.lonnsart_linje l
group by l.stasjon_id, to_char(date_trunc('month', l.dato), 'YYYY-MM'), l.ansatt_nr;

comment on view public.v_lonnsart_ansatt_maaned is
  'Loennsarter summert per ansatt, stasjon og maaned. Timer er loennsart 2 alene.';

-- SECURITY_INVOKER ER IKKE NOK ALENE. Supabase-standarden «alter default
-- privileges ... grant all on tables to anon» treffer ogsaa hvert nytt
-- view, og anon er rollen bak den offentlige noekkelen i hver sidelast.
grant select on public.v_lonnsart_ansatt_maaned to authenticated;
revoke all on public.v_lonnsart_ansatt_maaned from anon;

-- Kvittering. Viewet skal finnes, vaere invoker, og anon skal ikke naa det.
select
  (select count(*) from pg_views where viewname = 'v_lonnsart_ansatt_maaned') as viewet_finnes,
  (select count(*) from pg_class c
    where c.relname = 'v_lonnsart_ansatt_maaned'
      and 'security_invoker=true' = any(c.reloptions))                        as invoker,
  (select count(*) from information_schema.role_table_grants
    where table_name = 'v_lonnsart_ansatt_maaned' and grantee = 'anon')       as anon;
