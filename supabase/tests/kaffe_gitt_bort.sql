-- =====================================================================
-- Slaar de ansatte inn koppene de gir bort?
--
-- MEKANISMEN, fra Robert 2026-08-23: en kaffeavtale koster 300 kr, og
-- saa henter kunden saa mye han vil. Bystasjonene - Varden, Bones,
-- Laguneparken - har kunder innom flere ganger om dagen.
--
--   Slaar den ansatte inn koppen som gitt bort, gaar lageret ned og
--   alle vet hvorfor marginen faller.
--
--   Gjoer han det ikke, forsvinner kaffen likevel - men uten spor. Det
--   er USYNLIG SVINN, og det er forskjellen mellom en lav margin man
--   kan forklare og en man bare maa leve med.
--
-- Derfor 20,0 % paa Bones og 70,4 % paa Dale for samme produkt: Dale
-- selger mye kaffe over disk og gir bort lite. Begge tallene er ekte.
--
-- DETTE ER DISKUSJONEN, IKKE SVARET. Vi vet ikke om en registrert
-- utdeling i det hele tatt naar `daglig_salg`, eller hva den heter naar
-- den gjoer det. Spoerringen viser HVER varelinje i avdeling 130 med
-- antall og omsetning, saa vi kan se etter:
--
--   * linjer med antall > 0 og omsetning ~ 0   -> utdeling som ER slaatt inn
--   * en varelinje som heter noe med avtale    -> de 300 kronene
--   * ulik andel slike linjer mellom stasjoner -> ulik disiplin
--
-- Finnes de linjene, kan «har dere slaatt inn koppene?» bli et tall
-- butikksjefen ser, i stedet for en mistanke. Finnes de ikke, er
-- usynlig svinn faktisk usynlig, og da maa det maales et annet sted.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

select s.navn                                   as stasjon,
       v.varenavn,
       count(*)                                 as dager,
       round(sum(v.antall))                     as antall,
       round(sum(v.omsetning_eks_mva))          as omsetning_kr,
       round(sum(v.bto_fortjeneste_kr))         as brutto_kr,
       -- Null eller negativ pris per enhet er kjennetegnet paa noe som
       -- er gitt bort og registrert.
       case when sum(v.antall) > 0
            then round(sum(v.omsetning_eks_mva) / sum(v.antall), 2)
       end                                      as snittpris
from public.v_butikksalg v
join public.stasjoner s on s.id = v.stasjon_id
where v.avdeling_kode = '130'
  and v.dato >= date '2026-01-01'
group by s.navn, v.varenavn
order by s.navn, sum(v.antall) desc nulls last;
