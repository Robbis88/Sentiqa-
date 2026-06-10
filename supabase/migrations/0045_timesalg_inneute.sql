-- =====================================================================
-- Sentiqa - Timesalg med inne-/utekunder (St1 0603-rapport).
-- Erstatter den eldre 0758-timesalgsrapporten. Splitter kundetallet i
-- innekunder (butikk) og utekunder (forgard/pumpe) pr time.
-- =====================================================================
alter table public.timesalg add column if not exists inne_kunder numeric;
alter table public.timesalg add column if not exists ute_kunder numeric;
