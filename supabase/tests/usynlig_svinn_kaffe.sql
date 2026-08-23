-- =====================================================================
-- Det usynlige svinnet paa varm drikke, per stasjon
--
-- METODEN BLE REN DA `PÅFYLL`-LINJENE DUKKET OPP. En registrert
-- utdeling ligger i `daglig_salg` med antall > 0, omsetning 0 og
-- NEGATIV bruttofortjeneste - altsaa kaffens kost. Kassatallet
-- inneholder dermed allerede alt som er slaatt inn som gitt bort.
--
-- Da er det som staar igjen mellom kassa og regnskapet nettopp det som
-- forsvant UTEN aa bli slaatt inn. Robert 2026-08-23: «noen er ikke
-- like flink, og da faar vi usynlig svinn paa kaffen.»
--
-- DETTE ENDRER EN PAASTAND I `0116`, som sier at differansen mellom
-- kassa og tellingen ER kaffeavtalene og derfor ikke skal farges. Den
-- registrerte delen av avtalene ligger allerede i kassa. Stemmer
-- tallene under, er den differansen ikke avtalene - den er
-- underregistrering, og da er den det mest handlingsbare tallet paa
-- hele sida.
--
-- SAMME VINDU PAA BEGGE SIDER. Kassa loeper til i gaar, regnskapet
-- stopper ved siste avlagte maaned. Uten `join ... using (periode)`
-- ville kassa faatt to maaneder ekstra og gapet blitt overdrevet.
--
-- INGEN NORSKE TEGN I MOENSTRENE, og det er ikke pynt. AGENTS.md ber om
-- at ikke-ASCII strippes foer innliming, fordi innlimingskjeden ellers
-- legger paa et stray-tegn foran linje 1. Foerste utgave brukte
-- `~* '^PAAFYLL'` med ekte Aa - strippingen gjorde det til `^PFYLL`,
-- som ikke traff noe. Kolonnene `utdelte_kopper` og
-- `kassa_uten_utdeling_pst` kom tomme tilbake, og saa ut som om
-- utdelingene ikke fantes.
--
-- `ilike '%FYLL%'` treffer PAAFYLL uansett hva som skjer med Aa-en.
-- Et moenster som maa overleve en teksttransformasjon skal ikke
-- inneholde tegnet transformasjonen fjerner.
--
-- `usynlig_pp` var ALDRI beroert - den leser `sum(bto_fortjeneste_kr)`
-- over alle rader og bruker ikke moensteret. Tallene under er ekte:
--
--   Lone          25,4 pp    72 824 kr
--   Varden        11,3 pp    14 249 kr
--   Bones         11,0 pp    11 998 kr
--   Dale           6,4 pp    41 484 kr
--   Laguneparken  -4,6 pp   -16 242 kr
--
-- LONE ER IKKE DEN NOEN VILLE GJETTET. Den gir bort minst kaffe av
-- bystasjonene og har hoey kassamargin, men tellingen ligger 25 pp
-- under. Laguneparken er NEGATIV - tellingen fant mer margin enn kassa
-- ventet, og det maa forklares foer resten kan stoles paa.
--
-- SVARET PAA «HVOR MANGE KOPPER», kjort 2026-08-23:
--
--   Lone           7 257 slaas inn   +19 200   ca. 90 per dag
--   Dale          10 305             +8 500        40
--   Varden        11 792             +2 900        14
--   Bones         11 795             +2 100        10
--   Laguneparken  29 398             -3 100    (fant penger igjen)
--
-- BEVISET LIGGER I HVA JUSTERINGEN GJOER MED MOENSTERET. Slaas de inn,
-- havner alle bystasjonene paa 75-85 % utdelingsandel, og Lone lander
-- paa 279 kopper per kaffeavtale mot Laguneparkens 280 - de to selger
-- 95 og 94 avtaler. Foer justering sto Lone paa 76 og Laguneparken paa
-- 313. Tilfeldig svinn ville ikke landet Lone noeyaktig paa naboens
-- forhold.
--
-- PERIODEN ER DESEMBER 2025 T.O.M. JUNI 2026 - sju maaneder, ikke
-- kalenderaaret. Regnskapet starter i desember, og `fra`/`til` staar i
-- svaret saa det ikke maa utledes av «maaneder = 7». Begge sider bruker
-- de samme maanedene, saa desember skjevfordeler ingenting her - men
-- den maaneden er avvikende og skal ikke leses bort.
--
-- LAGERJUSTERINGEN PER KOPP er 3,79 til 5,64 kr, utledet av dataene.
-- Lone lavest fordi de gir bort vanlig kaffe; Bones hoeyest fordi latte
-- og cappuccino har melk i seg.
--
-- DEN AVGJOERENDE KONTROLLEN er kopper per avtalekunde per dag:
--
--                 i dag   etter justering
--   Lone           0,36        1,31
--   Dale           0,59        1,07
--   Bones          1,23        1,45
--   Laguneparken   1,47        1,32
--   Varden         1,73        2,16
--
-- En kunde som betaler 300 kr og henter 0,36 kopper om dagen kjoeper
-- ikke noe fornuftig. Etter justering lander Lone mellom Dale og
-- Laguneparken. 90 kopper om dagen paa 95 abonnenter er én kopp hver.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

with regnskap as (
  select r.stasjon_id,
         r.periode,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')         as oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste') as bto
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode = '130'
    and r.stasjon_id is not null
    and r.seksjon in ('omsetning', 'bruttofortjeneste')
  group by r.stasjon_id, r.periode
  -- Bare avlagte maaneder: en maaned uten telling har ingen fasit.
  having sum(r.regnskap) filter (where r.seksjon = 'omsetning') is not null
),
kasse as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date                     as periode,
         sum(v.omsetning_eks_mva)                              as oms,
         -- MED utdelingene: de ligger her som negativ brutto.
         sum(v.bto_fortjeneste_kr)                             as bto_med,
         -- UTEN dem, saa andelen som gis bort kan leses for seg.
         sum(v.bto_fortjeneste_kr) filter (
           where v.varenavn not ilike '%FYLL%'
           and v.varenavn not ilike '%GRATIS%')              as bto_uten,
         sum(v.antall) filter (where v.varenavn ilike '%FYLL%')  as utdelte,
         sum(v.antall) filter (
           where v.varenavn not ilike '%FYLL%'
             and v.varenavn not ilike '%GRATIS%'
             and v.varenavn not ilike '%AVTALE%'
             and v.varenavn not ilike '%PAPPKRUS%')
                                                               as solgte
  from public.v_butikksalg v
  where v.avdeling_kode = '130'
  group by v.stasjon_id, date_trunc('month', v.dato)
)

select s.navn                                          as stasjon,
       count(*)                                        as maaneder,
       min(r.periode)                                  as fra,
       max(r.periode)                                  as til,
       round(sum(k.solgte))                            as solgte_kopper,
       round(sum(k.utdelte))                           as utdelte_kopper,
       round(100 * sum(k.utdelte)
             / nullif(sum(k.utdelte) + sum(k.solgte), 0))
                                                       as utdelt_andel_pst,
       round(100 * sum(k.bto_uten) / nullif(sum(k.oms), 0), 1)
                                                       as kassa_uten_utdeling_pst,
       round(100 * sum(k.bto_med) / nullif(sum(k.oms), 0), 1)
                                                       as kassa_med_utdeling_pst,
       round(100 * sum(r.bto) / nullif(sum(r.oms), 0), 1)
                                                       as regnskap_pst,
       -- DOMMEN: det som forsvant uten aa bli slaatt inn.
       round(100 * sum(k.bto_med) / nullif(sum(k.oms), 0)
             - 100 * sum(r.bto) / nullif(sum(r.oms), 0), 1)
                                                       as usynlig_pp,
       round(sum(r.oms) * (sum(k.bto_med) / nullif(sum(k.oms), 0)
                           - sum(r.bto) / nullif(sum(r.oms), 0)))
                                                       as usynlig_kr,

       -- HVOR MANGE KOPPER MAA SLAAS INN for at gapet skal lukkes.
       --
       -- Utdelt kost og det usynlige er begge prosentpoeng av SAMME
       -- omsetning, saa forholdet mellom dem ER forholdet mellom antall
       -- kopper. Ingen antakelse om kaffepris trengs.
       --
       -- OEVRE GRENSE. Gapet inneholder ogsaa vanlig svinn - soel,
       -- kanner som toemmes ved stengetid, feilslag. Tallet sier hvor
       -- mange kopper som MAKSIMALT kan mangle registrering.
       round(sum(k.utdelte) * (
         (sum(k.bto_med) / nullif(sum(k.oms), 0)
          - sum(r.bto) / nullif(sum(r.oms), 0))
         / nullif(sum(k.bto_uten) / nullif(sum(k.oms), 0)
                  - sum(k.bto_med) / nullif(sum(k.oms), 0), 0)))
                                                       as maa_slaas_inn,
       -- Lagerjusteringen per utdelt kopp, utledet av dataene og ikke
       -- antatt. Lav der det gis bort vanlig kaffe, hoey der det er
       -- latte og cappuccino - melk koster.
       --
       -- KOPPETALLET OVER FORUTSETTER SAMME MIKS i det uregistrerte som
       -- i det registrerte. Er det latte som ikke slaas inn, koster hver
       -- kopp mer og antallet faller. Kronene staar uansett.
       round((sum(k.bto_uten) - sum(k.bto_med)) / nullif(sum(k.utdelte), 0), 2)
                                                       as kr_per_kopp,
       -- Per dag, saa tallet kan sies til en vakt uten omregning.
       round(sum(k.utdelte) * (
         (sum(k.bto_med) / nullif(sum(k.oms), 0)
          - sum(r.bto) / nullif(sum(r.oms), 0))
         / nullif(sum(k.bto_uten) / nullif(sum(k.oms), 0)
                  - sum(k.bto_med) / nullif(sum(k.oms), 0), 0))
         / (count(*) * 30.4))                          as per_dag
from regnskap r
join kasse k using (stasjon_id, periode)
join public.stasjoner s on s.id = r.stasjon_id
group by s.navn
order by 9 desc nulls last;
