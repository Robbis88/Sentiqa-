-- =====================================================================
-- Sentiqa - VALGFRI opprydding av dodt skjema (ingen kode bruker dette).
-- DESTRUKTIV: dropper gamle tabeller/kolonner. Kjor kun om du vil rydde.
--   * opplaring v1 (erstattet av opplaering_* i 0042)
--   * puls_svar.humor/dato (erstattet av runde_id/skala i 0038)
-- Puls-policyene (puls_les/insert/update) er FORTSATT I BRUK og rores ikke.
-- =====================================================================

-- Gammel opplaering v1 (cascade rydder FKs + policyer).
drop table if exists public.opplaring_fullfort cascade;
drop table if exists public.opplaring_personer cascade;
drop table if exists public.opplaring_punkter  cascade;

-- Doede puls v1-kolonner (dropper ogsa indeksen puls_svar_ansatt_dag som bruker dato).
alter table public.puls_svar drop column if exists humor;
alter table public.puls_svar drop column if exists dato;
