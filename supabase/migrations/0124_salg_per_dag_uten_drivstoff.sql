-- =====================================================================
-- v_salg_per_stasjon_dag leste `daglig_salg` - altsaa MED drivstoff
--
-- AGENTS.md, siden april 2026: «alt som summerer kroner eller antall
-- skal lese `v_butikksalg`.» Dette viewet er fra 0004, ble sist roert i
-- 0046, og kom aldri med paa den ryddingen.
--
-- Drivstoff er ~68 % av omsetningen. Det betjener seg selv paa pumpa,
-- bidrar ikke til stasjonens P&L, og skal aldri maales mot bemanning,
-- kategorier eller konkurranser. Da det sist var ufiltrert et sted,
-- viste ukerapportens forside +216 % vekst som ikke fantes: aarets uke
-- MED drivstoff mot fjoraarets UTEN.
--
-- HVA SOM ENDRER SEG PAA SKJERMEN, og det er ikke smaatt:
--
--   `omsetning`  - naa butikksalg. Var salg + drivstoff.
--   `antall`     - naa butikkvarer. Var med pumpeslag.
--
--   `mat_omsetning` og `kald_drikke_omsetning` er UROERT: de filtrerer
--   allerede paa avdeling 120 og 140.
--
-- Lesere: /salg, nettbrettets vekstkort, butikksjef-dashbordet og
-- AI-verktoyet. Alle skal ha butikksalg - ingen av dem stiller et
-- spoersmaal der pumpa hoerer hjemme.
--
-- `bto_fortjeneste` folger med ut av samme grunn: drivstoffets
-- kommisjon er ikke butikkens margin.
-- =====================================================================

create or replace view public.v_salg_per_stasjon_dag
with (security_invoker = true) as
select
  retailer_id,
  stasjon_id,
  dato,
  sum(omsetning_eks_mva)                                          as omsetning,
  sum(antall)                                                     as antall,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '120')     as mat_omsetning,
  sum(bto_fortjeneste_kr)                                         as bto_fortjeneste,
  sum(omsetning_eks_mva) filter (where avdeling_kode = '140')     as kald_drikke_omsetning
-- ENESTE ENDRINGEN, OG DEN ER HELE POENGET: `v_butikksalg` har samme
-- kolonner som `daglig_salg`, minus drivstoff. `slettet_tid`-filteret
-- ligger allerede i viewet.
from public.v_butikksalg
group by retailer_id, stasjon_id, dato;

comment on view public.v_salg_per_stasjon_dag is
  'Butikksalg per stasjon og dag, UTEN drivstoff. Leser v_butikksalg - '
  'ikke daglig_salg, som er ~68 % pumpe og drukner alt annet.';

grant select on public.v_salg_per_stasjon_dag to authenticated;
