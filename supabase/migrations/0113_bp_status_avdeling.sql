-- =====================================================================
-- 0113: BP avgjor om stasjonen er i rute. Fjoraaret forklarer utviklingen.
-- =====================================================================
--
-- PRODUKTREGELEN, SKREVET NED FORDI DEN ER LETT AA MISTE:
--
-- En stasjon kan ligge +8 % mot fjoraaret og samtidig vaere 70 000 bak
-- businessplanen. Timebudsjettet stasjonen faar er bygget paa BP-en, ikke
-- paa fjoraaret. Viser vi «vekst mot i fjor» som hoveddom, forteller vi
-- butikksjefen at det gaar bra mens forventningen hun maales mot ikke er
-- naadd.
--
--   BP        avgjor om vi er i rute      -> mot_bp_kr / mot_bp_pst
--   FJORAARET forklarer utviklingen       -> mot_ifjor_pst
--
-- ---------------------------------------------------------------------
-- NIVAAET ER AVDELING, OG DET ER BEVIST - IKKE ANTATT.
--
-- Mappingen mot produksjonsdata (supabase/tests/kodeverk_mapping.sql,
-- kjort paa 9467 Boenes) ga ni SIKKER-treff, alle paa `avdeling_kode`:
-- 120 Mat, 130 Varm drikke, 140 Kald drikke, 160 Kioskvarer, 170 Butikk,
-- 180 Tobakk, 190 Fritidsartikler, 200 Bil, 210 Bilvask.
--
-- Vareomraade er TVETYDIG: kodene 10-14 gaar igjen i hver avdeling, saa
-- «10» er ti forskjellige ting (AVISER, BAKERI, BILPLEIE, BRUS ...).
-- Hadde vi joinet der, ville tallene sett nesten riktige ut.
--
-- Varegruppe (86-95 koder) har INTET budsjett - hverken i BP eller i
-- regnskapet. Derfor heter viewet `avdeling` og ikke `varegruppe`: et
-- navn skal ikke love et finere nivaa enn dataene har.
--
-- ---------------------------------------------------------------------
-- BUDSJETTET KOMMER FRA TO KILDER, OG DE MOETES ALDRI I TID.
--
--   AAPEN maaned    `bp_omsetning` / `bp_bruttofortjeneste`
--   AVLAGT maaned   de ordinaere seksjonene sin `budsjett`-kolonne
--
-- BP-importen hopper over laaste maaneder med vilje - da baerer
-- regnskapet allerede budsjettet (kjerne.ts:748). Union, ikke join.
--
-- ---------------------------------------------------------------------
-- OMSETNING MOT OMSETNING, BRUTTO MOT BRUTTO. ALDRI PAA KRYSS.
--
-- Foerste utkast satte `bp_bruttofortjeneste` mot faktisk OMSETNING. To
-- ulike stoerrelser paa hver sin side av samme sammenligning, og et
-- avvik som ville sett ut som et funn. Derfor to atskilte budsjettmaal
-- her, og en test som feller enhver kryssing.
-- =====================================================================

create or replace view public.v_bp_status_avdeling
with (security_invoker = true) as

with naa as (
  -- Salgstall er alltid gaarsdagens. Vi maaler mot den datoen vi HAR,
  -- ikke mot dagens dato - ellers ser hver morgen ut som et fall.
  select max(dato)                                as siste_dato,
         date_trunc('month', max(dato))::date     as denne_mnd,
         extract(day from max(dato))::int         as dagnr
  from public.v_butikksalg
),

budsjett as (
  -- Begge kildene i en. `filter` skiller dem, saa en avlagt og en aapen
  -- maaned aldri kan blande budsjettene sine.
  --
  -- UTELATTE KODER: drivstoff (10), pant (250) og grand total (40).
  -- Dette er den SAMME domeneregelen som `SKJUL_OMS_KODER` i
  -- src/lib/avdelinger.ts, og ikke en ny beslutning:
  --
  --   10   Drivstoff - kommisjon/volum utenfor butikkdriften. Sier
  --        ingenting om hvordan butikken drives.
  --   250  Pant - gjennomgang uten margin. En rad med 0 % brutto midt i
  --        en analyse som handler om margin er stoy, ikke informasjon.
  --   40   CR - regnskapets grand total, summen av alle de andre. Tas
  --        den med, dobbelttelles hele stasjonen mot avdelingene.
  --        Beviset i bp_status.sql summerer viewet og krever at det
  --        stemmer med 40 CR; da er utelatelsen kontrollert.
  --
  -- SQL kan ikke importere fra TypeScript, saa lista staar to steder.
  -- `utelatte-koder.test.ts` leser BEGGE og feller hvis de gaar fra
  -- hverandre - samme grep som `lister.test.ts` bruker paa de to
  -- RLS-filene, etter at de faktisk gjorde det.
  -- utelatte_koder := array['10', '250', '40']
  select r.stasjon_id,
         r.periode                                    as maned,
         r.kode                                       as gruppe_kode,
         min(r.post)                                  as post,
         sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')          as bp_oms_aapen,
         sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste')  as bp_brt_aapen,
         sum(r.budsjett) filter (where r.seksjon = 'omsetning')             as bp_oms_avlagt,
         sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste')     as bp_brt_avlagt,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')             as regn_oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste')     as regn_brt,
         count(*) filter (where r.seksjon in ('omsetning', 'bruttofortjeneste')) > 0
                                                      as er_avlagt
  from public.regnskapslinjer r
  where r.kode is not null
    and r.kode not in ('10', '250', '40')
    and r.seksjon in ('omsetning', 'bruttofortjeneste',
                      'bp_omsetning', 'bp_bruttofortjeneste')
  group by r.stasjon_id, r.periode, r.kode
),

salg as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date     as maned,
         v.avdeling_kode                       as gruppe_kode,
         min(v.avdeling_navn)                  as navn,
         sum(v.omsetning_eks_mva)              as omsetning,
         sum(v.bto_fortjeneste_kr)             as brutto
  from public.v_butikksalg v
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato), v.avdeling_kode
),

-- Samme periode i fjor. For en avsluttet maaned: hele maaneden. For
-- inneveaerende: dag 1 til samme dagnummer - ellers sammenligner vi en
-- halv maaned med en hel og kaller fallet en utvikling.
ifjor as (
  select v.stasjon_id,
         (date_trunc('month', v.dato) + interval '1 year')::date as maned,
         v.avdeling_kode                                          as gruppe_kode,
         sum(v.omsetning_eks_mva)                                 as oms_hel,
         sum(v.omsetning_eks_mva) filter (
           where extract(day from v.dato) <= (select dagnr from naa)
         )                                                        as oms_hittil,
         -- Andelen av maaneden som laa paa dag 1..dagnr i fjor. Det er
         -- denne kurven «burde_naa» pro-rateres etter.
         sum(v.omsetning_eks_mva) filter (
           where extract(day from v.dato) <= (select dagnr from naa)
         ) / nullif(sum(v.omsetning_eks_mva), 0)                  as andel
  from public.v_butikksalg v
  where v.avdeling_kode is not null
  group by v.stasjon_id, date_trunc('month', v.dato), v.avdeling_kode
),

-- Faktisk brutto hittil i aar, per avdeling, fra AVLAGTE maaneder.
-- Tellingene ligger allerede i regnskapets brutto.
--
-- VEKTET, IKKE SNITT AV MAANEDSPROSENTER: sum(brutto)/sum(omsetning).
-- En stor maaned skal veie mer enn en liten. Ingen eksisterende regel i
-- kodebasen sa noe annet - ingenting beregnet bruttoprosent over
-- maaneder i det hele tatt - saa dette er ikke en endring av en
-- forretningsregel, men den foerste.
ytd as (
  select b.stasjon_id, b.gruppe_kode,
         date_trunc('year', b.maned)::date as aar,
         sum(b.regn_brt)                   as brutto_kr,
         sum(b.regn_oms)                   as oms_kr
  from budsjett b
  where b.er_avlagt
  group by b.stasjon_id, b.gruppe_kode, date_trunc('year', b.maned)
),

grunn as (
  select coalesce(b.stasjon_id, s.stasjon_id)   as stasjon_id,
         coalesce(b.maned, s.maned)             as maned,
         coalesce(b.gruppe_kode, s.gruppe_kode) as gruppe_kode,
         coalesce(s.navn, b.post)               as gruppe_navn,
         b.er_avlagt,
         coalesce(b.bp_oms_avlagt, b.bp_oms_aapen) as bp_omsetning_kr,
         coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) as bp_brutto_kr,
         b.regn_oms, b.regn_brt,
         s.omsetning as salg_oms,
         s.brutto    as salg_brt,
         f.oms_hel   as ifjor_hel,
         f.oms_hittil as ifjor_hittil,
         f.andel     as ifjor_andel
  from budsjett b
  full join salg s
    on s.stasjon_id = b.stasjon_id and s.maned = b.maned
   and s.gruppe_kode = b.gruppe_kode
  left join ifjor f
    on f.stasjon_id = coalesce(b.stasjon_id, s.stasjon_id)
   and f.maned      = coalesce(b.maned, s.maned)
   and f.gruppe_kode = coalesce(b.gruppe_kode, s.gruppe_kode)
),

med_status as (
  select g.*,
         n.denne_mnd, n.dagnr,
         extract(days from (g.maned + interval '1 month' - interval '1 day'))::int as dager_i_mnd,
         case
           when g.er_avlagt              then 'avlagt'
           when g.maned = n.denne_mnd    then 'innevaerende'
           when g.maned > n.denne_mnd    then 'kommende'
           -- FIRE VERDIER, IKKE TRE. Juli 2026 er over, har fullt salg og
           -- BP - men regnskapet er ikke avlagt ennaa. Kaller vi den
           -- «avlagt», lover vi en regnskapsbrutto som ikke finnes;
           -- kaller vi den «kommende», skjuler vi en maaned som ER
           -- ferdig. Tilstanden finnes i dataene og fortjener sitt navn.
           else                               'venter_regnskap'
         end as periode_status
  from grunn g cross join naa n
)

select
  m.stasjon_id,
  maned,
  periode_status,
  m.gruppe_kode,
  gruppe_navn,

  round(bp_omsetning_kr)                            as bp_omsetning_kr,
  round(bp_brutto_kr)                               as bp_brutto_kr,

  -- BURDE VAERT NAA. Bare meningsfullt inneveaerende maaned: en avlagt
  -- maaned maales mot HELE budsjettet, og en kommende maaned mot
  -- ingenting.
  case when periode_status = 'innevaerende' and bp_omsetning_kr is not null
       then round(bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
  end                                               as burde_naa_omsetning,

  -- FAKTISK. Kassa, ikke regnskapet - saa kolonnen betyr det samme i
  -- alle periodetyper. Regnskapets egne tall staar for seg selv under.
  case when periode_status = 'kommende' then null
       else round(salg_oms) end                     as faktisk_omsetning,

  -- HOVEDDOMMEN. Avlagt: mot hele budsjettet. Inneveaerende: mot det vi
  -- burde vaert. Kommende: ingen dom - det finnes ingenting aa dommme.
  case
    when periode_status = 'kommende' then null
    when periode_status = 'innevaerende' and bp_omsetning_kr is not null
      then round(salg_oms - bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
    when bp_omsetning_kr is not null then round(salg_oms - bp_omsetning_kr)
  end                                               as mot_bp_kr,

  case
    when periode_status = 'kommende' or coalesce(bp_omsetning_kr, 0) = 0 then null
    when periode_status = 'innevaerende'
      then round(((salg_oms - bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
                  / nullif(bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd), 0)) * 100, 1)
    else round(((salg_oms - bp_omsetning_kr) / nullif(bp_omsetning_kr, 0)) * 100, 1)
  end                                               as mot_bp_pst,

  -- KONTEKST, IKKE DOM. Null for kommende maaneder: en vekstprosent for
  -- en maaned uten salg er ikke planleggingskontekst, den er stoy.
  case
    when periode_status = 'kommende' then null
    when periode_status = 'innevaerende'
      then round(((salg_oms - ifjor_hittil) / nullif(ifjor_hittil, 0)) * 100, 1)
    else round(((salg_oms - ifjor_hel) / nullif(ifjor_hel, 0)) * 100, 1)
  end                                               as mot_ifjor_pst,

  -- TEORETISK BRUTTO: hva kassa sier margen var, uten svinn.
  case when periode_status = 'kommende' then null
       else round(salg_brt) end                     as teoretisk_brutto_kr,
  case when periode_status = 'kommende' or coalesce(salg_oms, 0) = 0 then null
       else round((salg_brt / nullif(salg_oms, 0)) * 100, 1) end
                                                    as teoretisk_brutto_pst,

  -- FAKTISK BRUTTO HITTIL I AAR: regnskapet, med tellingene i seg.
  round(y.brutto_kr)                                as faktisk_brutto_ytd_kr,
  case when coalesce(y.oms_kr, 0) = 0 then null
       else round((y.brutto_kr / nullif(y.oms_kr, 0)) * 100, 1) end
                                                    as faktisk_brutto_ytd_pst,

  -- GAPET. Positivt = kassa tror margen er bedre enn regnskapet viser.
  -- Der lekkasjen er, selv naar salgstallene ser riktige ut.
  case
    when periode_status = 'kommende' or coalesce(salg_oms, 0) = 0
      or coalesce(y.oms_kr, 0) = 0 then null
    else round(((salg_brt / nullif(salg_oms, 0)) - (y.brutto_kr / nullif(y.oms_kr, 0))) * 100, 1)
  end                                               as brutto_gap_pst,

  -- Sier om «burde_naa» er regnet fra fjoraarets EGEN kurve eller falt
  -- tilbake paa lineaert. Uten den leses et anslag som en maaling.
  case when ifjor_andel is not null then 'ifjor' else 'lineaert' end
                                                    as grunnlag,

  -- Regnskapets egne tall, for de maanedene som har dem.
  round(regn_oms)                                   as regnskap_omsetning_kr,
  round(regn_brt)                                   as regnskap_brutto_kr

from med_status m
left join ytd y
  on y.stasjon_id = m.stasjon_id
 and y.gruppe_kode = m.gruppe_kode
 and y.aar = date_trunc('year', m.maned)::date;

comment on view public.v_bp_status_avdeling is
  'BP mot faktisk per avdeling og maaned. BP avgjor om stasjonen er i '
  'rute (mot_bp_*), fjoraaret forklarer utviklingen (mot_ifjor_pst). '
  'Nivaaet er avdeling fordi mappingen mot produksjonsdata viste at det '
  'er det eneste nivaaet BP, regnskap og salgsdata deler - vareomraade '
  'er tvetydig, og varegruppe har intet budsjett. Omsetning maales mot '
  'omsetningsbudsjett og brutto mot bruttobudsjett, aldri paa kryss.';

grant select on public.v_bp_status_avdeling to authenticated;
