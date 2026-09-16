-- =====================================================================
-- PRODUKSJONSBEVIS FOR `a1_registeroppslag` - LEGITIM BRUK, EGEN KJEDE
--
-- Kjoerer i en transaksjon og ruller tilbake. Skriver ingenting.
--
-- Den beviser IKKE tenantisolasjon. Det er gjort i
-- `a1_registeroppslag.sql`, mot en fixture med to oppdiktede kjeder.
-- Her forsoeker vi aldri aa lese en ekte annen kunde.
--
-- ---------------------------------------------------------------------
-- HVA DEN BEVISER
--
-- At kryssoppslaget virker paa EKTE data: en person med arbeidstid paa
-- en stasjon og registerrad paa en annen blir funnet.
--
-- Produksjonstilstanden 2026-09-16:
--
--   basisvakt 2026-08     Boenes 107 rader, Laguneparken 193 rader
--   lonnsregister 2026-08 bare Lone, 20 rader
--
-- ---------------------------------------------------------------------
-- FORVENTNINGEN, SKREVET FOER KJOERING
--
-- Numrene utledes av `basisvakt` paa Boenes og Laguneparken. Registeret
-- finnes bare paa Lone. Treffet er derfor NOEYAKTIG de personene som
-- arbeidet paa Boenes/Laguneparken OG staar i Lones augustregister:
--
--   Carmen Valentina Toro  1104265  Lone  138  time
--   Julian Toro            1104270  Lone        time
--
-- Ingen Boenes-rader (Boenes har ikke noe eget register i august), og
-- ingen Sandra - hun arbeidet paa Lone, som ikke har basisvakt.
--
-- Avviker resultatet: RAPPORTER AVVIKET. Ikke utvid tilgangen.
--
-- ---------------------------------------------------------------------
-- HVORFOR `set local role`
--
-- SQL Editor kjoerer som `postgres`. `gjeldende_rolle()` leser
-- `auth.uid()`, som er null da, og funksjonen ville svart 42501 - riktig,
-- men ikke det vi vil maale. Vi later derfor som en ekte innlogget
-- retailer_admin i EGEN kjede, slik `rls_isolasjon.sql` gjoer.
-- =====================================================================

begin;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (
      select p.id
        from public.profiler p
       where p.rolle = 'retailer_admin'
         and p.slettet_tid is null
         and p.retailer_id = (
           select s.retailer_id
             from public.stasjoner s
             join public.basisvakt v on v.stasjon_id = s.id
            where v.kilde_maaned = '2026-08'
            limit 1
         )
       order by p.id
       limit 1
    ),
    'role', 'authenticated'
  )::text,
  true
);

set local role authenticated;

select
  (select p.fullt_navn from public.profiler p where p.id = auth.uid()) as kjoerer_som,
  s.navn                                                              as register_stasjon,
  r.ansatt_nr,
  r.navn,
  r.timesats,
  r.betalingsfrekvens
from public.a1_registeroppslag(
  '2026-08',
  -- Arbeidsstasjonene: de som faktisk HAR arbeidstid i maaneden.
  -- Leses som `authenticated`, saa RLS avgjoer hvilke som er synlige.
  array(
    select distinct v.stasjon_id
      from public.basisvakt v
     where v.kilde_maaned = '2026-08'
  )
) r
join public.stasjoner s on s.id = r.stasjon_id
order by s.navn, r.ansatt_nr;

rollback;
