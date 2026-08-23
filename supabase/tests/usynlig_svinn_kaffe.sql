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
           where v.varenavn !~* '^PÅFYLL|GRATIS')              as bto_uten,
         sum(v.antall) filter (where v.varenavn ~* '^PÅFYLL')  as utdelte,
         sum(v.antall) filter (
           where v.varenavn !~* '^PÅFYLL|GRATIS|KAFFEAVTALE|PAPPKRUS')
                                                               as solgte
  from public.v_butikksalg v
  where v.avdeling_kode = '130'
  group by v.stasjon_id, date_trunc('month', v.dato)
)

select s.navn                                          as stasjon,
       count(*)                                        as maaneder,
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
       round(sum(k.bto_med) - sum(k.oms) * sum(r.bto) / nullif(sum(r.oms), 0))
                                                       as usynlig_kr
from regnskap r
join kasse k using (stasjon_id, periode)
join public.stasjoner s on s.id = r.stasjon_id
group by s.navn
order by 9 desc nulls last;
