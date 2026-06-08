-- =====================================================================
-- Sentiqa — Pengepremier på konkurranser (PROSJEKT.md §9/§11)
-- premie_kr finnes alt. Legger til premie-beskrivelse + utbetalingssporing.
-- =====================================================================
alter table public.konkurranser add column if not exists premie_tekst text;
alter table public.konkurranser add column if not exists premie_utbetalt boolean not null default false;
alter table public.konkurranser add column if not exists utbetalt_tid timestamptz;
