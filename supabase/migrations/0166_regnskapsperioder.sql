-- =====================================================================
-- Sentiqa 0166 - periodelista skal ikke telles i klienten
--
-- ELDRE MAANEDER FORSVANT UTEN ET ORD
--
-- `/regnskap` bygget maanedsvelgeren slik:
--
--   supabase.from('regnskapslinjer').select('periode')
--     .is('stasjon_id', null).order('periode', desc)
--
-- Ingen grense. PostgREST stopper paa 1000 rader, og hver maaned har
-- mange regnskapslinjer - saa svaret var de nyeste tusen LINJENE, ikke
-- alle maanedene. De eldste maanedene fantes rett og slett ikke i
-- velgeren, og «hent opp en gammel maaned» kunne derfor ikke virke.
--
-- `/analyse` hadde samme spoerring med `limit(2000)`. Det flytter taket,
-- det fjerner det ikke.
--
-- DETTE ER SAMME FEIL SOM `0090` BLE SKREVET FOR AA RETTE et annet sted,
-- med samme ordlyd i kommentaren: «PostgREST kutter paa 1000 rader, saa
-- svaret blir loegn ... Tellingen hoerer hjemme der radene er.»
--
-- En kjede med tre aars regnskap har 36 rader her. Klienten henter dem
-- alle, hver gang, uten aa naa noe tak.
--
-- `stasjon_id is null` er cluster-linjene, altsaa selskapets egen P&L.
-- Det er de som avgjoer hvilke maaneder som FINNES; per-stasjon-linjer
-- hoerer til samme maaned og legger ikke til noen.
-- =====================================================================

create or replace view public.v_regnskapsperioder
with (security_invoker = true) as
select
  retailer_id,
  periode,
  count(*)::bigint as linjer
from public.regnskapslinjer
where stasjon_id is null
  and periode is not null
  and slettet_tid is null
group by retailer_id, periode;

comment on view public.v_regnskapsperioder is
  'Hvilke regnskapsmaaneder en kjede har, en rad per maaned. Mater '
  'maanedsvelgerne paa /regnskap og /analyse. Aggregert i basen: '
  'klienten skal aldri hente linjene for aa telle maanedene - se '
  'migrasjon 0166.';

grant select on public.v_regnskapsperioder to authenticated;
revoke all on public.v_regnskapsperioder from anon;
