-- =====================================================================
-- v_kaffe_svinn: gaar kaffejusteringen i null?
--
-- REGELEN, fra Robert 2026-08-23:
--
--   «Kaffelojalitet er der vi nedjusteres. Hvis kaffelojalitet er
--    -2000 kr og kaffe/te er 2000, saa er det rett justert. Er kaffe/te
--    1000 kr, mangler det justering paa 1000 kr.»
--
-- En kaffeavtale koster 300 kr, og saa henter kunden saa mye han vil.
-- Kaffen forsvinner fysisk fra lageret og gir MANKO paa `13010 KAFFE`.
-- Slaar den ansatte inn utdelingen, gir den et tilsvarende OVERSKUDD paa
-- `13011 KAFFELOJALITET`. Balanserer de, er alt registrert. Det som
-- staar igjen, er justeringen som mangler.
--
-- HELE KJEDEN, 2026: 481 994 - 325 161 - 8 405 = +148 428 kr ujustert.
--
-- MAALT MOT PRODUKSJON 2026-08-23, januar til juli:
--
--   stasjon        kaffe   lojalitet   mangler   ujustert   kopper
--   Lone          98 973     -18 534    78 187      422 %   21 719
--   Dale          91 978     -38 962    49 687      128 %   10 161
--   Varden        66 491     -54 143    12 349       23 %    3 430
--   Bones         72 107     -62 020     8 550       14 %    1 110
--   Laguneparken 152 445    -151 502      -345        0 %        -
--
-- LAGUNEPARKEN ER BEVISET PAA AT REGELEN STEMMER. De deler ut mest av
-- alle - 151 502 kr - og lander paa -345 kr. Det er ikke flaks paa et
-- tall i den stoerrelsen; det er en stasjon som slaar inn hver kopp.
-- Uten den raden ville regelen vaert en teori.
--
-- Lone slaar inn under en femtedel av det de gir bort.
--
-- BILVASK FOELGER IKKE SAMME REGEL, og det maa staa her foer noen
-- generaliserer. `21014 MASKINVASK APP` sto paa -1 206 017 kr for
-- aaret. Det er ikke overskudd ved telling - Robert 2026-08-23: «det
-- er penger vi faar fra St1, de tar pengene fra appen sin og utbetaler
-- x kroner per vask kundene bruker.» En utbetaling, ikke en justering.
-- Dale har ikke bilvaskemaskin i det hele tatt.
--
-- «130xx skal gaa i null» gjelder KAFFE, fordi utdelingen har en egen
-- motpost. Andre avdelinger maa forstaas hver for seg.
--
-- DETTE ER EKSAKT, IKKE ET ANSLAG, og det er hele grunnen til at viewet
-- ble skrevet om. Foerste utgave utledet det samme av kassa minus
-- telling - tre mellomregninger som alle kunne baere en feil, og som
-- krevde en antakelse om varemiks for aa bli til et antall kopper. St1
-- har regnet det ut for oss i `regnskap_usynlig_svinn` (0049).
--
-- Utledningen ga 124 313 kr for desember-juni mot 148 428 for
-- januar-juli. Ulikt vindu, samme stoerrelsesorden - metoden var riktig,
-- men den var omveien.
--
-- MATCH PAA KODEPREFIKS, ALDRI PAA FRITEKSTNAVNET. Svinnrapporten er paa
-- VAREGRUPPE: femsifrede koder der avdelingen er de tre foerste.
-- `kode = '130'` ga null rader, og null ser ut som «ingen svinn».
-- `navn ilike (prosent)VARM(prosent)` traff `12014 OPPVARMET` - altsaa
-- oppvarmet MAT - og ga et TROVERDIG tall for feil avdeling. Det er den
-- verste sorten feil: et tall som er galt paa en plausibel maate blir
-- ikke oppdaget av noen.
--
-- `left(kode, 3)` er den samme noekkelen `regnskapslinjer` og
-- `daglig_salg` bruker.
--
-- KUN INNEVAERENDE AAR, gruppert paa `date_trunc('year', periode)` og
-- ikke et rullerende vindu. Robert: «vi maa kun justere paa aaret, saa
-- desember maa ikke vaere med. Neste aar kun 2027-tall.»
--
-- KOPPENE KOMMER FRA `daglig_salg`, og bare de. St1 gir kroner; varselet
-- skal si «slaa inn 2 100 PAAFYLL CAFFE LATTE», fordi et antall er en
-- handling og en sum er en opplysning. Lagerjusteringen per kopp finnes
-- ikke i regnskapet.
--
-- MOENSTERET `%FYLL%` HAR INGEN NORSKE TEGN med vilje. AGENTS.md ber om
-- at ikke-ASCII strippes for innliming; et moenster med ekte Aa i
-- PAAFYLL ble til `^PFYLL` og traff ingenting.
-- =====================================================================

-- DROP FOERST, og det er ikke slurv. `create or replace view` kan legge
-- til kolonner paa slutten, men ikke gi dem nye navn eller bytte
-- rekkefoelge:
--
--   ERROR: 42P16: cannot change name of view column
--          "kassa_omsetning_kr" to "kaffe_kr"
--
-- Foerste utgave av dette viewet leste kassa minus telling og hadde et
-- helt annet kolonnesett. Omskrivingen til St1s tall bytter dem ut.
--
-- UTEN `cascade`, med vilje. Er det noe som avhenger av viewet, skal
-- migrasjonen feile hoeyt her - ikke dra avhengigheten med seg i
-- stillhet. Ingenting gjoer det i dag.
drop view if exists public.v_kaffe_svinn;

create view public.v_kaffe_svinn
with (security_invoker = true) as

with svinn as (
  select u.retailer_id,
         u.stasjon_id,
         date_trunc('year', u.periode)::date                        as aar,
         count(distinct u.periode)                                  as maaneder,
         min(u.periode)                                             as fra,
         max(u.periode)                                             as til,
         sum(u.usynlig_kr) filter (where u.kode = '13010')          as kaffe_kr,
         sum(u.usynlig_kr) filter (where u.kode = '13011')          as lojalitet_kr,
         sum(u.usynlig_kr) filter (
           where u.kode not in ('13010', '13011'))                  as annet_kr,
         -- + manko, - overskudd. Se `0049`.
         sum(u.usynlig_kr)                                          as mangler_kr
  from public.regnskap_usynlig_svinn u
  where u.slettet_tid is null
    and u.stasjon_id is not null
    and left(u.kode, 3) = '130'
  group by u.retailer_id, u.stasjon_id, date_trunc('year', u.periode)
),

-- Den mest utdelte varen per stasjon og aar, med hva lageret justeres
-- med per kopp. `distinct on` + `order by antall desc` gir den varen som
-- faktisk deles ut oftest - varselet navngir den, saa det er DENS pris
-- som hoerer til antallet.
vanligste as (
  select distinct on (stasjon_id, aar)
         stasjon_id,
         aar,
         varenavn,
         kr_per_kopp
  from (
    select v.stasjon_id,
           date_trunc('year', v.dato)::date        as aar,
           v.varenavn,
           sum(v.antall)                           as antall,
           case when sum(v.antall) > 0
                then round(-sum(v.bto_fortjeneste_kr) / sum(v.antall), 2)
           end                                     as kr_per_kopp
    from public.v_butikksalg v
    where v.avdeling_kode = '130'
      and v.varenavn ilike '%FYLL%'
    group by v.stasjon_id, date_trunc('year', v.dato), v.varenavn
  ) t
  where antall > 0 and kr_per_kopp > 0
  order by stasjon_id, aar, antall desc
)

select s.retailer_id,
       s.stasjon_id,
       s.aar,
       s.maaneder,
       s.fra,
       s.til,
       round(s.kaffe_kr)                                 as kaffe_kr,
       round(s.lojalitet_kr)                             as lojalitet_kr,
       round(s.annet_kr)                                 as annet_kr,
       -- DOMMEN. Positiv = justering som mangler.
       round(s.mangler_kr)                               as mangler_kr,
       -- Hvor stor del av utdelingen som ikke er slaatt inn. Null naar
       -- det ikke er registrert utdeling i det hele tatt - da finnes
       -- ingen andel, og «100 %» ville vaert et paafunn.
       case when s.lojalitet_kr < 0
            then round(100 * s.mangler_kr / -s.lojalitet_kr, 1)
       end                                               as andel_ujustert_pst,
       v.varenavn                                        as vanligste_paafyll,
       v.kr_per_kopp,
       case when v.kr_per_kopp > 0 and s.mangler_kr > 0
            then round(s.mangler_kr / v.kr_per_kopp)
       end                                               as maa_slaas_inn
from svinn s
left join vanligste v
  on v.stasjon_id = s.stasjon_id
 and v.aar = s.aar;

comment on view public.v_kaffe_svinn is
  'Gaar kaffejusteringen i null? 13010 KAFFE gir manko naar kaffen '
  'forsvinner fra lageret, 13011 KAFFELOJALITET gir overskudd naar '
  'utdelingen slaas inn. Balanserer de, er alt registrert - `mangler_kr` '
  'er det som staar igjen. St1s eget tall, ikke utledet. `maa_slaas_inn` '
  'gjor det om til et antall kopper av den varen som deles ut oftest.';

grant select on public.v_kaffe_svinn to authenticated;
