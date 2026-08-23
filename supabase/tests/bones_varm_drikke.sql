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
-- REGNSKAPSLINJER ER LANGFORMAT: én rad per post, ikke kolonner for
-- omsetning og brutto. Marginen finnes ved aa dele `bruttofortjeneste`
-- paa `omsetning` for samme kode og periode - samme grep som `0113`.
-- Foerste utgave av denne fila gjettet paa `r.aar`/`r.omsetning_kr` og
-- feilet i SQL Editor.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with linjer as (
  select r.stasjon_id,
         r.periode,
         r.kode,
         min(r.post)                                                    as post,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')         as oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste') as bto,
         -- Budsjettet ligger i to seksjonspar: `bp_*` mens maaneden er
         -- aapen, uten prefiks naar den er avlagt. Begge maa med, ellers
         -- ser en avlagt maaned budsjettloes ut.
         coalesce(
           sum(r.budsjett) filter (where r.seksjon = 'omsetning'),
           sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')
         )                                                              as bud_oms,
         coalesce(
           sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste'),
           sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste')
         )                                                              as bud_bto
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode is not null
    and r.seksjon in ('omsetning', 'bruttofortjeneste',
                      'bp_omsetning', 'bp_bruttofortjeneste')
    -- «Varm drikke» kan hete litt av hvert i posten. Fang bredt her og
    -- se paa `post`-kolonnen i svaret hva som faktisk kom med.
    and (r.post ilike '%varm%' or r.kode = '130')
  group by r.stasjon_id, r.periode, r.kode
)

select s.navn                                              as stasjon,
       l.post,
       l.periode,
       round(l.oms)                                        as omsetning_kr,
       round(l.bto)                                        as brutto_kr,
       case when l.oms > 0
            then round(100 * l.bto / l.oms, 1) end         as brutto_pst,
       case when l.bud_oms > 0
            then round(100 * l.bud_bto / l.bud_oms, 1) end as budsjett_pst,
       -- Avviket i prosentpoeng. Er dette omtrent likt i fjor og i aar,
       -- er det budsjettet som er feil - ikke driften.
       case when l.oms > 0 and l.bud_oms > 0
            then round(100 * l.bto / l.oms - 100 * l.bud_bto / l.bud_oms, 1)
       end                                                 as avvik_pp
from linjer l
join public.stasjoner s on s.id = l.stasjon_id
where s.navn ilike '%nes%'
order by s.navn, l.post, l.periode;
