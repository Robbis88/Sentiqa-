-- =====================================================================
-- Traff `bp_brutto_fast` de riktige linjene?
--
-- SVARET, kjort 2026-08-23: 15 linjer, alle genuint flate.
--
--   Varm drikke  x5   20,0 (Bones) / 32,7 / 34,0 / 46,1 / 70,4 (Dale)
--   Bilvask      x4   84,1-85,3 %
--   Selvvask     x4   78,4 % paa alle, til én desimal
--   Dale         x2   Kald drikke 51,4 og Tobakk 28,8
--
-- `40 CR` er IKKE med. Den har seks maaneder og varierer, saa
-- seksmaanederterskelen slipper ikke gjennom kort historikk som «fast».
-- Det var den ene maaten den kunne vaert for slapp paa.
--
-- PANT SKAL IKKE VAERE HER. `250` er ekskludert fra viewet sammen med
-- `10` og `40`. Foerste utgave av denne fila ventet 19 rader, utledet
-- fra `bp_brutto_flat.sql` - som leser `regnskapslinjer` direkte og ikke
-- har den ekskluderingen. De fire Pant-radene kunne aldri kommet med.
--
-- GRUPPER PAA KODE, IKKE PAA NAVN. Viewet setter
-- `gruppe_navn = coalesce(s.navn, b.post)`: salgets avdelingsnavn naar
-- salg finnes, ellers regnskapsposten. Uten et maanedsfilter fikk hver
-- linje derfor to navn - «130 Varm drikke» for maanedene uten salg og
-- «VARM DRIKKE» for dem med - og 15 linjer ble til 26 rader.
--
-- Selvvask har bare den ene formen paa alle fire: den har ingen
-- salgsrader i det hele tatt. Det er `plan_uten_kobling` fra for.
--
-- LESER KUN. Trygg i produksjon.
-- =====================================================================

select s.navn                              as stasjon,
       v.gruppe_kode,
       -- Begge navnene, saa det synes naar de er ulike.
       string_agg(distinct v.gruppe_navn, ' / ' order by v.gruppe_navn)
                                           as navn_i_viewet,
       max(v.bp_brutto_ytd_pst)            as budsjettmargin_pst,
       count(distinct v.maned)             as maaneder
from public.v_bp_status_avdeling v
join public.stasjoner s on s.id = v.stasjon_id
where v.bp_brutto_fast
group by s.navn, v.gruppe_kode
order by v.gruppe_kode, s.navn;
