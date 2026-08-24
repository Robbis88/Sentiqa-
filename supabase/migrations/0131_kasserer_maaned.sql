-- =====================================================================
-- Kassererstatistikk per maaned
--
-- /kasserer leste ÉN DAG, i kroner, sortert paa omsetning. Tre valg som
-- alle drar i samme retning: en kasserer med én vakt og én retur ser lik
-- ut som et halvaars moenster, den som selger mest faar mest avvik uten
-- at noe er galt, og rangeringen svarer paa «hvem selger mest».
--
-- Dette viewet gir maaned, saa raten kan maales mot kassererens EGEN
-- historikk i stedet for mot kollegaene.
--
-- ---------------------------------------------------------------------
-- HVA SONDEN MAALTE (kasserer_fordeling.sql, 2026-08-24, fem stasjoner,
-- 775 kasserermaaneder, juli 2025 til august 2026)
--
--   makulert er 71-83 % av alle avvikskronene. Retur og slettet er
--   resten. Summeres de tre til ett tall, skjuler det store det eneste
--   som kunne vaert smaatt - derfor er de tre kolonner her, ikke én.
--
--   999999 baerer 18-35 % av ALLE bonger. Det er ikke stoy, det er en
--   egen kanal. Den skal vises for seg, ikke slettes og ikke blandes
--   inn i en medarbeiders tall.
--
--   Belopene er positive. Én negativ makulert-maaned finnes paa tre av
--   fem stasjoner, ellers ingen. Ingen `abs()` her - et negativt tall
--   skal faa lov til aa se negativt ut.
--
--   Ingen hull: ingen maaned har bonger uten omsetning, omsetning uten
--   bonger, eller avvik i antall uten belop.
--
-- ---------------------------------------------------------------------
-- NAVNET ER EN OPPLYSNING, IKKE EN NOEKKEL
--
-- `kasserer_nr` er en FJERDE identitet, ved siden av `ansatt_nr` fra
-- easy@work, `ansatte.id` fra PIN, og fritekst navn. Viewet kobler den
-- ikke til noen av dem.
--
-- `ulike_navn` finnes fordi sonden fant «Sundling, Hanna» paa TO numre
-- paa Varden. Navnet er altsaa ikke entydig i noen av retningene, og
-- sida maa kunne si fra naar den viser et navn den ikke kan staa inne
-- for.
-- =====================================================================

create or replace view public.v_kasserer_maaned
with (security_invoker = true) as
select
  k.retailer_id,
  k.stasjon_id,
  nullif(btrim(k.kasserer_nr), '')     as kasserer_nr,
  date_trunc('month', k.dato)::date    as maned,

  count(distinct k.dato)               as dager,
  sum(coalesce(k.bonger, 0))           as bonger,
  sum(coalesce(k.omsetning_ink_mva, 0)) as omsetning_kr,

  sum(coalesce(k.retur_belop, 0))      as retur_kr,
  sum(coalesce(k.retur_antall, 0))     as retur_antall,
  sum(coalesce(k.makulerte_belop, 0))  as makulert_kr,
  sum(coalesce(k.makulerte_antall, 0)) as makulert_antall,
  sum(coalesce(k.slettede_belop, 0))   as slettet_kr,
  sum(coalesce(k.slettede_antall, 0))  as slettet_antall,

  -- SISTE NAVN, ikke et vilkaarlig. Skifter et nummer haand, er det
  -- navnet som staar naa som er det mest sannsynlige - og `ulike_navn`
  -- forteller at det har vaert flere.
  (array_agg(nullif(btrim(k.kasserer_navn), '')
             order by k.dato desc nulls last))[1]        as navn,
  count(distinct nullif(btrim(k.kasserer_navn), ''))     as ulike_navn

from public.kassererstatistikk k
where k.slettet_tid is null
  and k.dato is not null
  and nullif(btrim(k.kasserer_nr), '') is not null
group by k.retailer_id, k.stasjon_id,
         nullif(btrim(k.kasserer_nr), ''),
         date_trunc('month', k.dato)::date;

comment on view public.v_kasserer_maaned is
  'Kassererstatistikk per stasjon, kassanummer og maaned. De tre '
  'avvikstypene holdes fra hverandre - makulert er 71-83 % av kronene, '
  'og en sum ville skjult de to andre. kasserer_nr er en egen identitet '
  'og er ikke koblet til ansatt_nr eller ansatte.id. ulike_navn > 1 '
  'betyr at navnet ikke kan staas inne for.';

-- BEGGE LINJENE, HVER GANG. Se 0130 og AGENTS.md: Supabase-standarden
-- gir hver ny view et anon-grant av seg selv.
grant select on public.v_kasserer_maaned to authenticated;
revoke all on public.v_kasserer_maaned from anon;
