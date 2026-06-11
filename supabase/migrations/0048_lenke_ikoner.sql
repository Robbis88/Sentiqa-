-- =====================================================================
-- Sentiqa - Distinkte ikoner paa kundehjelp-lenkene (idempotent).
-- =====================================================================
update public.lenker set ikon = '🛢️'
  where url like 'https://widik.com/champion%' and slettet_tid is null;

update public.lenker set ikon = '🌧️'
  where url like 'https://www.boschwiperblades.com%' and slettet_tid is null;
