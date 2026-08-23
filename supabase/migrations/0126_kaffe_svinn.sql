-- =====================================================================
-- v_kaffe_svinn: paafyll som ikke er slaatt inn, per stasjon og aar
--
-- MEKANISMEN. En kaffeavtale koster 300 kr, og saa henter kunden saa mye
-- han vil. Slaar den ansatte inn koppen som gitt bort, havner den i
-- kassa som en PAAFYLL-linje med antall > 0, omsetning 0 og NEGATIV
-- brutto - altsaa kaffens kost. Kassatallet inneholder dermed alt som ER
-- slaatt inn.
--
-- Da er differansen mot regnskapet nettopp det som forsvant UTEN aa bli
-- slaatt inn. Robert 2026-08-23: «noen er ikke like flink, og da faar vi
-- usynlig svinn paa kaffen.»
--
-- BEVISET FOR AT METODEN HOLDER: uten utdelingene ligger kaffemarginen
-- paa 82,2-83,7 % paa ALLE fem stasjonene. Samme produkt, samme pris,
-- samme margin. Hele spennet i budsjettet - 20,0 % paa Bones mot 70,4 %
-- paa Dale - er utdeling og ingenting annet.
--
-- KUN INNEVAERENDE AAR. Robert: «vi maa kun justere paa aaret, saa
-- desember maa ikke vaere med. Neste aar kun 2027-tall.» Foerste maaling
-- gikk desember 2025 til juni 2026 og blandet dermed to budsjettaar.
-- Derfor `aar` som egen kolonne og gruppering paa den - ikke et
-- rullerende vindu, som ville dratt fjoraaret med seg inn i januar.
--
-- SAMME MAANEDER PAA BEGGE SIDER. Kassa loeper til i gaar, regnskapet
-- stopper ved siste avlagte maaned. Uten `join ... using (periode)`
-- ville kassa faatt et par maaneder ekstra og gapet blitt overdrevet.
--
-- MOENSTRE UTEN NORSKE TEGN. AGENTS.md ber om at ikke-ASCII strippes for
-- innliming. Et moenster med ekte Aa i PAAFYLL ble til `^PFYLL` og traff
-- ingenting - kolonnene kom tomme tilbake og saa ut som om utdelingene
-- ikke fantes. `ilike '%FYLL%'` overlever transformasjonen.
-- =====================================================================

create or replace view public.v_kaffe_svinn
with (security_invoker = true) as

with regnskap as (
  select r.retailer_id,
         r.stasjon_id,
         r.periode,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')         as oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste') as bto
  from public.regnskapslinjer r
  where r.slettet_tid is null
    and r.kode = '130'
    and r.stasjon_id is not null
    and r.seksjon in ('omsetning', 'bruttofortjeneste')
  group by r.retailer_id, r.stasjon_id, r.periode
  -- En maaned uten telling har ingen fasit aa maale mot.
  having sum(r.regnskap) filter (where r.seksjon = 'omsetning') is not null
),

kasse as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date                     as periode,
         sum(v.omsetning_eks_mva)                              as oms,
         -- MED utdelingene: de ligger her som negativ brutto.
         sum(v.bto_fortjeneste_kr)                             as bto_med,
         -- UTEN dem. Differansen er kosten ved det som ble slaatt inn.
         sum(v.bto_fortjeneste_kr) filter (
           where v.varenavn not ilike '%FYLL%'
             and v.varenavn not ilike '%GRATIS%')              as bto_uten,
         sum(v.antall) filter (where v.varenavn ilike '%FYLL%') as utdelte
  from public.v_butikksalg v
  where v.avdeling_kode = '130'
  group by v.stasjon_id, date_trunc('month', v.dato)
),

-- Den mest utdelte varen per stasjon og aar, med hva lageret justeres
-- med per kopp. Varselet skal si «slaa inn 2 100 PAAFYLL CAFFE LATTE» og
-- ikke «11 % av marginen mangler» - et antall er en handling, en prosent
-- er en opplysning.
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

select r.retailer_id,
       r.stasjon_id,
       date_trunc('year', r.periode)::date               as aar,
       count(*)                                          as maaneder,
       min(r.periode)                                    as fra,
       max(r.periode)                                    as til,
       round(sum(k.oms))                                 as kassa_omsetning_kr,
       round(sum(k.bto_med))                             as kassa_brutto_kr,
       round(sum(k.bto_uten))                            as kassa_brutto_uten_utdeling_kr,
       round(sum(k.utdelte))                             as utdelte_kopper,
       round(sum(r.oms))                                 as regnskap_omsetning_kr,
       round(sum(r.bto))                                 as regnskap_brutto_kr,
       v.varenavn                                        as vanligste_paafyll,
       v.kr_per_kopp
from regnskap r
join kasse k using (stasjon_id, periode)
left join vanligste v
  on v.stasjon_id = r.stasjon_id
 and v.aar = date_trunc('year', r.periode)::date
group by r.retailer_id, r.stasjon_id, date_trunc('year', r.periode),
         v.varenavn, v.kr_per_kopp;

comment on view public.v_kaffe_svinn is
  'Paafyll som ikke er slaatt inn, per stasjon og AAR. Utdelte kopper '
  'ligger i kassatallet som PAAFYLL-linjer med negativ brutto, saa '
  'differansen mot regnskapet er det som forsvant uten spor. Kun '
  'avlagte maaneder, og aldri paa tvers av budsjettaar. `kr_per_kopp` '
  'er lagerjusteringen for den mest utdelte varen - regningen bor her, '
  'ikke i UI-et.';

grant select on public.v_kaffe_svinn to authenticated;
