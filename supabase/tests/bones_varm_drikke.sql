-- =====================================================================
-- Er 11,7 % slik det har vaert, eller slik det er blitt?
--
-- Bones har varm drikke budsjettert paa 23,1 % brutto og realisert
-- 11,7 %. Robert 2026-08-22: «varm drikke er nok dessverre slik.»
--
-- DEN ANTAKELSEN ER VERDT AA ETTERPROEVE, fordi BP-bruttoen ikke er en
-- ambisjon - den er fjoraarets oppnaadde margin. Sier BP 23,1 %, skal
-- varm drikke ha ligget paa 23,1 % i fjor. Da er 11,7 % ikke «slik det
-- er», men et fall paa 11,4 prosentpoeng i loepet av ett aar.
--
-- Tre utfall, tre helt ulike svar:
--
--   Fjoraaret laa ogsaa rundt 12 %  -> BP-tallet er feil, ikke driften.
--                                      Linja vil staa roed hver maaned
--                                      for alltid, og en permanent roed
--                                      linje laerer folk aa se forbi
--                                      hele sida.
--   Fjoraaret laa rundt 23 %        -> noe har endret seg i aar. Da er
--                                      det verdt aa lete: svinn, gratis
--                                      kaffe, eller varer som har byttet
--                                      avdeling.
--   Fjoraaret mangler              -> ingen dom kan felles.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with linjer as (
  select r.stasjon_id, r.aar, r.maned, r.gruppe_navn,
         sum(r.omsetning_kr)        as oms,
         sum(r.bto_fortjeneste_kr)  as bto
  from public.regnskapslinjer r
  join public.stasjoner s on s.id = r.stasjon_id
  where s.navn ilike '%nes%'
    and r.gruppe_navn ilike '%varm%'
  group by 1, 2, 3, 4
)
select s.navn                                    as stasjon,
       l.gruppe_navn,
       l.aar,
       l.maned,
       round(l.oms)                              as omsetning_kr,
       round(l.bto)                              as brutto_kr,
       case when l.oms > 0
            then round(100 * l.bto / l.oms, 1)
       end                                       as brutto_pst
from linjer l
join public.stasjoner s on s.id = l.stasjon_id
order by s.navn, l.gruppe_navn, l.aar, l.maned;
