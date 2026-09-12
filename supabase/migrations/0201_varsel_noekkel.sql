-- =====================================================================
-- 0201  ET VARSEL SKAL IKKE KOMME TO GANGER
-- =====================================================================
-- `opprettVarsel` er en rett `insert` uten duplikatsperre. Hver
-- regnskapsimport lager derfor bemanningsvarslene og kaffevarslene paa
-- nytt - OG sender web-push om igjen.
--
-- Det er ikke et hypotetisk problem. Robert skulle laste opp januar til
-- juli paa nytt (resultatlinja ble aldri lest foer 2026-09-12), og aatte
-- opplastinger x fem stasjoner ville gitt femti-hundre varsler han ikke
-- hadde bedt om, pluss push paa telefonen for hvert enkelt.
--
-- OG DET VERSTE ER IKKE BRAAKET. Det er at de ekte varslene drukner. Et
-- varselsystem man laerer seg aa avfeie, er et varselsystem som ikke
-- finnes - samme mekanisme som da den lesbare RLS-rapporten loey om
-- tabeller som var i orden, og folk sluttet aa tro paa den.
--
-- Enhver re-import gjoer dette, ogsaa den dagen en korrigert fil kommer
-- fra regnskapsfoereren.
--
-- ---------------------------------------------------------------------
-- NOEKKELEN, IKKE INNHOLDET
--
-- Sperren kan ikke gaa paa tittel og tekst: de er skrevet ut av tallene,
-- og et tall som endrer seg litt mellom to importer ville gitt en ny
-- tittel og dermed et nytt varsel. Da var vi like langt.
--
-- `noekkel` er derfor det varselet HANDLER OM, ikke hva det sier:
-- «bemanning:<stasjon>:<maaned>:<slag>». Samme sak gir samme noekkel selv
-- om formuleringen skifter.
--
-- ---------------------------------------------------------------------
-- ET AVVIST VARSEL KOMMER IKKE TILBAKE
--
-- Indeksen er partiell paa `noekkel is not null`, men IKKE paa
-- `slettet_tid is null`. Det er med vilje: har du lest og lukket varselet,
-- har du tatt stilling, og en ny import skal ikke hente det fram igjen.
-- En sperre som slipper gjennom etter sletting er ingen sperre for den
-- som nettopp ryddet.
--
-- Neste maaned har en annen noekkel, saa en ny situasjon varsles alltid.
--
-- ---------------------------------------------------------------------
-- GAMLE VARSLER BEROERES IKKE
--
-- `noekkel` er nullbar, og indeksen hopper over null. Alt som ligger der
-- fra foer staar urort, og varsler uten et naturlig identitetsbegrep -
-- en fritekstmelding til en bruker - kan fortsatt opprettes uten noekkel.
-- =====================================================================

alter table public.varsler
  add column if not exists noekkel text;

-- EN RAD PER NOEKKEL PER KJEDE. `on conflict do nothing` i koden gjoer at
-- den andre importen ikke feiler - den skriver bare ingenting.
create unique index if not exists varsler_noekkel_unik
  on public.varsler (retailer_id, noekkel)
  where noekkel is not null;

comment on column public.varsler.noekkel is
  'Hva varselet HANDLER OM, ikke hva det sier: '
  '«bemanning:<stasjon>:<maaned>:<slag>». Gjoer at en re-import ikke '
  'lager varselet paa nytt. Null for varsler uten naturlig identitet.';
