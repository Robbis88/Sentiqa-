-- =====================================================================
-- Sentiqa — Inntaksadresse på apex (§6)
-- Bytter inntaksadressene fra subdomenet inn.sentiqa.ai til apex sentiqa.ai,
-- så Cloudflare Email Routing kan bruke én enkel catch-all-regel.
-- =====================================================================
update public.retailers
  set inntak_epost = replace(lower(inntak_epost), '@inn.sentiqa.ai', '@sentiqa.ai')
  where inntak_epost like '%@inn.sentiqa.ai';
