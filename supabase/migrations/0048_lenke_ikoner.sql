-- =====================================================================
-- Sentiqa - Distinkte ikoner paa kundehjelp-lenkene (idempotent).
-- Ikoner via Postgres unicode-escape (ren ASCII -> taaler innliming):
--   \+01F6E2\FE0F = oljefat-emoji, \+01F327\FE0F = sky-med-regn-emoji.
-- =====================================================================
update public.lenker set ikon = U&'\+01F6E2\FE0F'
  where url like 'https://widik.com/champion%' and slettet_tid is null;

update public.lenker set ikon = U&'\+01F327\FE0F'
  where url like 'https://www.boschwiperblades.com%' and slettet_tid is null;
