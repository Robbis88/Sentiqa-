-- =====================================================================
-- Sentiqa - Arrangementer: en kalender-kilde (eller manuelt arrangement) kan
-- paavirke FLERE stasjoner. Vi lagrer hvilke paa kilden (stasjon_ider), og
-- nattjobben lager ett forslag pr (hendelse x stasjon). Tomt array = alle
-- stasjoner i kjeden. Dedup maa derfor inkludere stasjon_id.
-- =====================================================================

alter table public.kalender_kilder
  add column if not exists stasjon_ider uuid[];

-- Dedup pr (kilde, ekstern hendelse, stasjon) i stedet for bare (kilde, hendelse).
drop index if exists public.arrangementer_kilde_uid_idx;
create unique index if not exists arrangementer_kilde_uid_stasjon_idx
  on public.arrangementer (kilde_id, ekstern_uid, stasjon_id);
