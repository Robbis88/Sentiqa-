-- =====================================================================
-- Én linje kan eie en hel maaned
--
-- FUNNET 2026-08-25, i produksjonsdata:
--
--   Lone, mai 2026. Én svinnlinje - 7041011086600 STRØSSEL
--   KARAMELLFUDGE, 193 stk, 36 015,73 kr - utgjorde 52 % av hele
--   maanedens svinn paa stasjonen. Enhetsprisen blir 186,61 kr for
--   stroessel.
--
--   Robert: «det er nok en feilfoering som av og til skjer.»
--
-- Uten den linja laa Lone midt i flokken: 7 262 kr utenfor mat, mot
-- Dale 10 263, Varden 8 318, Boenes 6 613. MED den saa stasjonen ut til
-- aa ha et problem den ikke hadde.
--
-- ---------------------------------------------------------------------
-- INGEN TERSKEL, INGEN FILTRERING
--
-- Linja slettes ikke og skjules ikke. En feilfoering er ikke noe
-- systemet kan kjenne igjen - 193 stk av noe kan vaere en ekte
-- bulkavskriving, og et filter ville fjernet begge deler i stillhet.
--
-- I stedet staar tallet ved siden av maanedstallet som et faktum:
-- «stoerste enkeltlinje: X kr, Y % av maaneden». Er andelen 3 %, er den
-- beroligende. Er den 52 %, skriver advarselen seg selv - og leseren
-- avgjoer, ikke en grense noen fant paa.
--
-- Derfor er kolonnene her ALLTID fylt, ikke bare naar noe er stort.
-- Et felt som bare dukker opp naar systemet mener det er verdt det, er
-- en skjult terskel med en annen frakk.
--
-- ---------------------------------------------------------------------
-- HVORFOR I DEKNINGSVIEWET
--
-- `v_svinn_dekning` svarer paa «hvor mye kan dette tallet stoles paa».
-- Foeringsdager er det ene svaret paa det spoersmaalet; hvor mye av
-- summen som ligger paa én linje er det andre. To rader per stasjon og
-- maaned i to views ville vaert to spoerringer for det samme.
--
-- Kjor `supabase/tests/rls_vakthund.sql` etterpaa - viewet er
-- `security_invoker`, og punkt 9 sjekker at det fortsatt er det.
-- =====================================================================

create or replace view public.v_svinn_dekning
with (security_invoker = true) as
with per_maaned as (
  select s.retailer_id,
         s.stasjon_id,
         date_trunc('month', s.dato)::date as maned,
         count(distinct s.dato)            as dager_registrert,
         max(s.dato)                       as siste_registrering,
         min(s.dato)                       as forste_registrering,
         -- SNITTAVSTANDEN MELLOM FOERINGENE. Maten kastes hver dag ved
         -- stengetid; det som varierer er naar det blir foert. De fleste
         -- foerer foer de gaar hjem, noen skriver det ned og
         -- butikksjefen foerer det dagen etter eller samler opp flere
         -- dager. `dato` er transaksjonsdatoen fra rapport 0452 - naar
         -- det ble slaatt inn, ikke naar maten ble kastet.
         case when count(distinct s.dato) > 1
              then round((max(s.dato) - min(s.dato))::numeric
                         / (count(distinct s.dato) - 1), 1)
         end                               as snitt_intervall_dager,

         sum(s.nettopris_total)            as sum_kr,

         -- STOERSTE ENKELTLINJE. Én rad i `synlig_svinn` er én foering,
         -- og en feilfoering er alltid én rad. `array_agg` i stedet for
         -- `max` fordi vi trenger HVILKEN linje, ikke bare beloepet.
         max(s.nettopris_total)            as storste_linje_kr,
         (array_agg(s.varenavn order by s.nettopris_total desc nulls last))[1]
                                           as storste_linje_varenavn,
         (array_agg(s.ean order by s.nettopris_total desc nulls last))[1]
                                           as storste_linje_ean,
         (array_agg(s.dato order by s.nettopris_total desc nulls last))[1]
                                           as storste_linje_dato,
         (array_agg(s.antall order by s.nettopris_total desc nulls last))[1]
                                           as storste_linje_antall
  from public.synlig_svinn s
  where s.slettet_tid is null
    and s.dato is not null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.dato)::date
)
select p.retailer_id,
       p.stasjon_id,
       p.maned,
       p.dager_registrert,
       extract(day from (p.maned + interval '1 month - 1 day'))::int
                                          as dager_i_maaned,
       -- Hvor mange dager av maaneden som har PASSERT. For en avsluttet
       -- maaned er det hele maaneden; for den inneveaerende er det i dag.
       case when p.maned = date_trunc('month', current_date)::date
            then least(
                   extract(day from (p.maned + interval '1 month - 1 day'))::int,
                   extract(day from current_date)::int)
            else extract(day from (p.maned + interval '1 month - 1 day'))::int
       end                                as dager_hittil,
       p.siste_registrering,
       p.forste_registrering,
       p.snitt_intervall_dager,

       p.storste_linje_kr,
       p.storste_linje_varenavn,
       p.storste_linje_ean,
       p.storste_linje_dato,
       p.storste_linje_antall,
       -- NULL, IKKE 0, naar maaneden ikke har kroner aa dele paa. En
       -- andel av ingenting er ikke null prosent.
       case when p.sum_kr > 0
            then round(p.storste_linje_kr / p.sum_kr, 4)
       end                                as storste_linje_andel
from per_maaned p;

comment on view public.v_svinn_dekning is
  'Hvor mye kan maanedens svinntall stoles paa? To signaler: hvor mange '
  'av dagene det faktisk ble foert, og hvor mye av summen som ligger '
  'paa én enkelt linje. Lone mai 2026 hadde 52 % av maaneden i én '
  'feilfoert linje. Kolonnene er alltid fylt - et felt som bare dukker '
  'opp naar systemet mener det er verdt det, er en skjult terskel.';

grant select on public.v_svinn_dekning to authenticated;
revoke all on public.v_svinn_dekning from anon;
