-- =====================================================================
-- Sentiqa 0161 - `svinn_sum` gir varegruppekoden
--
-- HVORFOR
--
-- Noen varegrupper MOTPOSTERER hverandre, og da lyver medlemmet alene.
-- Roberts regel, foerst skrevet ned 2026-08-23: kaffen forsvinner fra
-- lageret og gir manko paa 13010; slaas utdelingen inn, gir den et
-- tilsvarende OVERSKUDD paa 13011. Te hoerer med i samme familie - folk
-- tar te gratis ogsaa. Samme form paa vask: 21014 MASKINVASK APP selger
-- vasken, 21010 MASKINVASK forbruker den.
--
-- Maalt paa Boenes, juli 2026:
--
--   13010 KAFFE          + 8 783      13011 KAFFELOJALITET  - 5 328
--   21010 MASKINVASK     + 7 964      21014 MASKINVASK APP  -22 592
--
-- Varsellista viste bare de positive: maskinvask sto som roedt varsel paa
-- 7 964 kr mens gruppa faktisk hadde 14 628 kr i OVERSKUDD.
--
-- FOR AA NETTE DEM TRENGS AVDELINGEN, OG DEN ER DE TRE FOERSTE SIFRENE
-- I KODEN
--
-- Funksjonen returnerte bare `navn`. Koden staar riktignok som prefiks i
-- navnet - «13010 KAFFE» - men aa lese en gruppering ut av en
-- VISNINGSSTRENG er skjoert: endrer St1 formatet, slutter nettingen aa
-- virke, og resultatet er at kaffe igjen ser ut som et funn. Feilen ville
-- vaert stille.
--
-- `kode` finnes allerede i tabellen. Den skal bare med ut.
--
-- Samme noekkel som `v_kaffe_svinn` (0126) bruker: `left(kode, 3)`.
--
-- MERK: returtypen endres, saa funksjonen maa DROPPES foerst -
-- `create or replace` kan ikke endre `returns table`. Begge setningene
-- taaler aa kjoeres om igjen.
-- =====================================================================

drop function if exists public.svinn_sum(date, date);

create function public.svinn_sum(p_fra date, p_til date)
returns table(
  stasjon_id  uuid,
  kode        text,
  navn        text,
  salg        numeric,
  usynlig_kr  numeric,
  kast        numeric
)
language sql
security invoker
set search_path = public
as $$
  select stasjon_id, kode, navn, sum(salg), sum(usynlig_kr), sum(kast)
  from public.regnskap_usynlig_svinn
  where periode between p_fra and p_til and slettet_tid is null
  group by stasjon_id, kode, navn
$$;

grant execute on function public.svinn_sum(date, date) to authenticated;
