-- =====================================================================
-- Kandidater: UPDATE-policyer som slipper en rad ut av kjeden
--
-- TIDLIG ALARM, IKKE FASIT. Denne leser katalogen og finner tabeller med
-- FORMEN som har lekket seks ganger:
--
--   avvik, stempling_hendelse          0135
--   skills_score, pengepremie_bruk     0138
--   rutiner, oppgaver                  funnet 2026-08-26
--
-- Formen er alltid den samme:
--
--   using      (stasjon_id in (select public.mine_stasjoner()) ...)
--   with check (stasjon_id in (select public.mine_stasjoner()) ...)
--
-- `using` slipper inn en rad brukeren HAR. `with check` ser paa den nye
-- radtilstanden, men bare paa stasjonen. Endres kun retailer_id, staar
-- stasjon_id uroert og innenfor mine_stasjoner() - og raden flyttes til
-- en annen kjede.
--
-- ---------------------------------------------------------------------
-- DEN MAA ALDRI FAA VAERE SISTE ORD
--
-- `ansatte` har NOEYAKTIG samme policytekst og lekker IKKE. `0112` gjorde
--
--   revoke update on public.ansatte from authenticated;
--   grant  update (navn, stasjon_id, ansatt_nr, aktiv, slettet_tid) ...
--
-- for aa lukke pin_hash. `retailer_id` havnet ikke paa lista, og
-- kolonnegjerdet stoppet flyttingen som en bivirkning - fra en migrasjon
-- skrevet av en helt annen grunn.
--
--   Tenant-sikkerhet er den effektive summen av RLS + grants +
--   RPC/view-grenser. Policytekst alene beskriver ikke den faktiske
--   capabilityen.
--
-- Derfor er kolonneretten med i utskriften, og derfor SKAL hver kandidat
-- bekreftes med atferdsmatrisen foer noen policy roeres. Denne sier hvor
-- man skal se, ikke hva man skal gjore.
--
-- ---------------------------------------------------------------------
-- KASTER IKKE. En rapport som feller CI paa falske positive laerer folk
-- aa se bort fra roedt, og det er den vanen hele dette arbeidet handler
-- om aa unngaa. Les lista.
-- =====================================================================
select
  p.tablename                                          as tabell,
  p.policyname                                         as policy,
  case
    when not has_column_privilege('authenticated', ('public.' || p.tablename)::regclass,
                                  'retailer_id', 'UPDATE')
      then 'TRYGG VIA GRANT - authenticated kan ikke skrive retailer_id (som ansatte)'
    else 'KANDIDAT - bekreft med atferdsmatrisen foer policyen roeres'
  end                                                  as vurdering
from pg_policies p
where p.schemaname = 'public'
  and p.cmd = 'UPDATE'
  -- Tabellen maa ha BEGGE tenantkolonnene. Uten retailer_id finnes ikke
  -- flyttingen som handling.
  and exists (select 1 from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = p.tablename
                and c.column_name = 'retailer_id')
  and exists (select 1 from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = p.tablename
                and c.column_name = 'stasjon_id')
  -- Policyen slipper via stasjonen ...
  and coalesce(p.with_check, '') like '%mine_stasjoner%'
  -- ... men binder ikke den nye raden til kjeden.
  and coalesce(p.with_check, '') not like '%gjeldende_retailer_id%'
order by
  -- Ekte kandidater foerst; grant-vernede nederst.
  has_column_privilege('authenticated', ('public.' || p.tablename)::regclass,
                       'retailer_id', 'UPDATE') desc,
  p.tablename;
