-- =====================================================================
-- Svinn per maaned og varegruppe, med varekost som nevner
--
-- DEN GAMLE PROSENTEN VAR FAGLIG UGYLDIG, og produksjonsdata beviste
-- det 2026-08-24:
--
--   teller = sum(nettopris_total) fra HELE synlig_svinn
--   nevner = sum(mat_omsetning), avdeling 120 alene
--
-- To feil i samme brook. OMFANGET matchet ikke - kiosk, tobakk og
-- bilvask svinner, men talte ikke i nevneren. Og ENHETEN matchet ikke:
-- `nettopris_total` er kostpris, `omsetning_eks_mva` er omsetning. En
-- kostnad delt paa en inntekt er ikke en andel av noe.
--
-- SONDEN BEVISTE AT `nettopris_total` ER KOSTPRIS. For EAN-er med baade
-- svinn og salg laa svinnets enhetspris innenfor 15 % av enhetsKOSTen i
-- 97-99 % av tilfellene, mot 0-1,5 % for utsalgsprisen. Og varekost paa
-- salgssiden er alltid utledbar: `mangler_ledd` var 0,00 % paa alle fem
-- stasjoner.
--
-- Derfor: kost mot kost, samme stasjon, samme varegruppe, samme maaned.
--
-- ---------------------------------------------------------------------
-- IKKE KOBLET SVINN KASTES IKKE UT
--
-- 76-94 % av svinnlinjene lar seg koble til en varegruppe via EAN.
-- Resten er systematisk, ikke stoy: varmmat laget i huset og registrert
-- paa firesifret produksjonskode (SIGNATURPOELSE, OSTEGRILL,
-- CHORIZOPOELSE), pluss ingredienser og bulk som kjoepes inn men aldri
-- selges som enhet.
--
-- De kronene er ekte svinn. De faar `gruppe_kode = null`, `koblet =
-- false` og `varekost_kr = null` - altsaa INGEN prosent, ikke null
-- prosent. En manglende nevner er ikke en nevner paa null.
--
-- ---------------------------------------------------------------------
-- FULL OUTER, IKKE LEFT
--
-- En varegruppe som SELGER men ikke svinner maa vaere med, ellers blir
-- stasjonens nevner summen av bare de gruppene som svinner - og da er
-- prosenten for hoey. Det er den samme feilen som den gamle
-- beregningen gjorde, bare et hakk finere.
--
-- ---------------------------------------------------------------------
-- Kjor `supabase/tests/rls_vakthund.sql` etterpaa. Viewene er
-- `security_invoker`, saa RLS paa synlig_svinn og daglig_salg gjelder
-- som foer: butikksjefen ser sine stasjoner, eieren sin kjede.
-- =====================================================================

-- ---------------------------------------------------------------------
-- EAN -> varegruppe, en rad per EAN.
--
-- `v_varer` er distinct paa (ean, varenavn, varegruppe), saa samme EAN
-- kan staa flere ganger med ulik skrivemaate. Uten denne innsnevringen
-- ville en vare med to navn blitt talt to ganger i koblingen.
--
-- Sonden maalte 0 EAN-er med mer enn en varegruppe, saa `min()` er et
-- trygt valg her - og hadde det ikke vaert det, ville tallet vist det.
-- ---------------------------------------------------------------------
create or replace view public.v_vare_gruppe
with (security_invoker = true) as
select ean,
       min(varegruppe_kode) as gruppe_kode,
       min(varegruppe_navn) as gruppe_navn,
       count(distinct varegruppe_kode) as antall_grupper
from public.v_varer
where ean is not null
group by ean;

comment on view public.v_vare_gruppe is
  'EAN til varegruppe, en rad per EAN. antall_grupper > 1 betyr at '
  'koblingen ikke er entydig for den varen - sjekk foer du stoler paa den.';

grant select on public.v_vare_gruppe to authenticated;


-- ---------------------------------------------------------------------
-- Svinn og varekost side om side, per stasjon, maaned og varegruppe.
-- ---------------------------------------------------------------------
create or replace view public.v_svinn_maaned
with (security_invoker = true) as
with svinn as (
  select s.retailer_id,
         s.stasjon_id,
         date_trunc('month', s.dato)::date as maned,
         vg.gruppe_kode,
         vg.gruppe_navn,
         sum(s.nettopris_total)            as svinn_kr,
         sum(s.antall)                     as svinn_antall,
         count(*)                          as svinn_linjer
  from public.synlig_svinn s
  left join public.v_vare_gruppe vg on vg.ean = s.ean
  where s.slettet_tid is null
    and s.dato is not null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.dato)::date,
           vg.gruppe_kode, vg.gruppe_navn
),
salg as (
  -- `v_butikksalg`, ikke `daglig_salg`: drivstoff hoerer ikke hjemme i
  -- butikkens varekost. Se AGENTS.md.
  select d.retailer_id,
         d.stasjon_id,
         date_trunc('month', d.dato)::date                as maned,
         d.varegruppe_kode                                as gruppe_kode,
         min(d.varegruppe_navn)                           as gruppe_navn,
         sum(d.omsetning_eks_mva - d.bto_fortjeneste_kr)  as varekost_kr,
         sum(d.omsetning_eks_mva)                         as omsetning_kr,
         sum(d.antall)                                    as solgt_antall
  from public.v_butikksalg d
  where d.dato is not null
    and d.varegruppe_kode is not null
  group by d.retailer_id, d.stasjon_id, date_trunc('month', d.dato)::date,
           d.varegruppe_kode
)
select
  coalesce(sv.retailer_id, sa.retailer_id)  as retailer_id,
  coalesce(sv.stasjon_id, sa.stasjon_id)    as stasjon_id,
  coalesce(sv.maned, sa.maned)              as maned,
  coalesce(sv.gruppe_kode, sa.gruppe_kode)  as gruppe_kode,
  coalesce(sv.gruppe_navn, sa.gruppe_navn)  as gruppe_navn,

  -- SANT bare naar svinnet lot seg koble til en varegruppe. Er det
  -- usant, finnes det ingen salgsmotpart aa dele paa - og da skal det
  -- ikke finnes en prosent heller.
  (sv.gruppe_kode is not null or sa.gruppe_kode is not null) as koblet,

  coalesce(sv.svinn_kr, 0)      as svinn_kr,
  coalesce(sv.svinn_antall, 0)  as svinn_antall,
  coalesce(sv.svinn_linjer, 0)  as svinn_linjer,

  -- NULL, IKKE NULL KRONER. Uten salg i gruppa finnes ingen nevner, og
  -- "ingen nevner" er noe annet enn "nevner lik null".
  sa.varekost_kr,
  sa.omsetning_kr,
  sa.solgt_antall
from svinn sv
full outer join salg sa
  on  sa.retailer_id = sv.retailer_id
 and  sa.stasjon_id  = sv.stasjon_id
 and  sa.maned       = sv.maned
 and  sa.gruppe_kode = sv.gruppe_kode;

comment on view public.v_svinn_maaned is
  'Svinn til kostpris mot varekost paa solgte varer, per stasjon, '
  'maaned og varegruppe. koblet = false betyr svinn uten salgsmotpart '
  '(varmmat paa produksjonskode, ingredienser, bulk) - kronene er ekte, '
  'men det finnes ingen gyldig nevner. varekost_kr null betyr ikke '
  'maalbart, ikke null.';

grant select on public.v_svinn_maaned to authenticated;


-- ---------------------------------------------------------------------
-- Registreringsdekning
--
-- MANGLENDE REGISTRERING ER IKKE NULL SVINN, og forskjellen mellom
-- stasjonene er stor nok til aa endre konklusjonen. Sonden maalte
-- dekning fra 34 % (Laguneparken) til 93 % (Lone) av dagene.
--
-- Laguneparken har MEST svinn i kroner og FAERREST registreringsdager.
-- Det er batch-telling, ikke daglig foering - og en daglig eller
-- ukentlig trend ville derfor vaert pigger, ikke utvikling. Derfor er
-- maaned minste normale analyseperiode for svinn.
--
-- `dager_hittil` skiller inneveaerende maaned fra en avsluttet: en
-- maaned som ikke er ferdig skal aldri se ut som en som er det.
-- ---------------------------------------------------------------------
-- GRUPPER FOERST, UTLED ETTERPAA. Foerste utgave regnet dager_i_maaned
-- rett i select-lista med `s.dato` inni, mens bare
-- `date_trunc('month', s.dato)` sto i group by. Postgres kan ikke se at
-- de to er den samme verdien, og avviste hele viewet med «column s.dato
-- must appear in the GROUP BY clause». Naa gjoer CTE-en grupperingen, og
-- maaneden er en vanlig kolonne aa regne paa.
create or replace view public.v_svinn_dekning
with (security_invoker = true) as
with per_maaned as (
  select s.retailer_id,
         s.stasjon_id,
         date_trunc('month', s.dato)::date as maned,
         count(distinct s.dato)            as dager_registrert,
         max(s.dato)                       as siste_registrering,
         min(s.dato)                       as forste_registrering,
         -- SNITTAVSTANDEN MELLOM TELLINGER. Ikke alle stasjoner teller
         -- hver dag - noen teller hver tredje, noen sjeldnere. Uten
         -- dette tallet ser en fast rytme ut som et hull, og en rutine
         -- blir lest som en forsoemmelse.
         case when count(distinct s.dato) > 1
              then round((max(s.dato) - min(s.dato))::numeric
                         / (count(distinct s.dato) - 1), 1)
         end                               as snitt_intervall_dager
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
       p.snitt_intervall_dager
from per_maaned p;

comment on view public.v_svinn_dekning is
  'Hvor mange av maanedens dager svinn faktisk ble registrert, og hvor '
  'tett tellingene ligger. Manglende registrering er ikke null svinn. '
  'snitt_intervall_dager skiller en TELLERYTME fra et hull: en stasjon '
  'som teller hver tredje dag har 33 % av dagene og ingen mangel.';

grant select on public.v_svinn_dekning to authenticated;


-- ---------------------------------------------------------------------
-- Svinn per vare og maaned
--
-- "Innen en kategori: hvilke varer staar oeverst." Bare de sikkert
-- koblede - en vare uten varegruppe kan ikke ligge under en kategori,
-- og skal ikke dukke opp under en tilfeldig en.
--
-- Ukoblede varer er FORTSATT med, med `gruppe_kode = null`, saa de kan
-- listes for seg. De forsvinner ikke; de faar bare ikke en kategori de
-- ikke hoerer til.
-- ---------------------------------------------------------------------
create or replace view public.v_svinn_vare_maaned
with (security_invoker = true) as
select s.retailer_id,
       s.stasjon_id,
       date_trunc('month', s.dato)::date as maned,
       vg.gruppe_kode,
       vg.gruppe_navn,
       s.ean,
       min(s.varenavn)             as varenavn,
       sum(s.nettopris_total)      as svinn_kr,
       sum(s.antall)               as svinn_antall,
       count(*)                    as linjer,
       count(distinct s.dato)      as dager
from public.synlig_svinn s
left join public.v_vare_gruppe vg on vg.ean = s.ean
where s.slettet_tid is null
  and s.dato is not null
group by s.retailer_id, s.stasjon_id, date_trunc('month', s.dato)::date,
         vg.gruppe_kode, vg.gruppe_navn, s.ean;

comment on view public.v_svinn_vare_maaned is
  'Svinn per vare og maaned. gruppe_kode null = ikke koblet til '
  'varegruppe (varmmat paa produksjonskode, ingredienser, bulk). '
  'Kronene er ekte uansett.';

grant select on public.v_svinn_vare_maaned to authenticated;
