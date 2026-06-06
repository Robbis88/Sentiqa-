-- =====================================================================
-- Sentiqa — Seed for å teste innlogging (midlertidig, til onboarding er bygd)
--
-- Steg:
-- 1. Supabase Dashboard → Authentication → Users → "Add user"
--    Opprett f.eks. eier@test.no med et passord. Kopier brukerens UUID.
-- 2. Lim UUID-en inn under (erstatt <AUTH_UUID>) og kjør i SQL Editor.
--
-- Oppretter én retailer + én stasjon + admin-profil knyttet til auth-brukeren.
-- =====================================================================

with ny_retailer as (
  insert into public.retailers (navn, slug)
  values ('Testkjeden AS', 'test')
  returning id
)
insert into public.profiler (id, retailer_id, rolle, fullt_navn)
select '<AUTH_UUID>'::uuid, id, 'retailer_admin', 'Test Eier'
from ny_retailer;

-- Én stasjon på samme tenant (bruk retailer-id-en fra profilen)
insert into public.stasjoner (retailer_id, butikknummer, navn, stasjonstype)
select retailer_id, '0001', 'Test Bønes', 'pendler'
from public.profiler where id = '<AUTH_UUID>'::uuid;
