-- =====================================================================
-- 0207  LEVERANDOERENE SUMMERES I BASEN OGSAA
-- =====================================================================
-- Regnskapsrommet krasjet paa foerste sidelast 2026-09-12, med
-- «Noe gikk galt paa denne siden. Feilkode: 2691817940».
--
-- Aarsaken var min egen, og den var den SAMME som `0205` nettopp fikset:
-- sida hentet raa `bilagssum` med et tak paa 900 rader.
--
--   8 029 bilagslinjer  ->  én rad per butikk, periode, konto, tekst
--                       ->  langt over 900
--
-- `maaVaereHele` kastet, helt riktig - et avkortet svar ser ut som en
-- billig stasjon. Men jeg hadde satt grensen etter magefoelelse igjen,
-- én time etter aa ha skrevet ned at det ikke gaar.
--
-- ---------------------------------------------------------------------
-- SAMME SVAR SOM SIST: SUMMÉR HER
--
-- Rommet trenger ikke bilagene per maaned. Det trenger én rad per
-- stasjon per leverandoer per begrep - hva stasjonen har brukt hos
-- WashTec paa rep, i hele perioden. Fra ~1 200 rader til ~150.
--
-- `maaneder`, `eldste` og `nyeste` foelger med, fordi aarseffekten maa
-- skaleres fra det grunnlaget FAKTISK dekker. Uten dem ville et funn fra
-- syv maaneder blitt regnet som et aar.
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE FILTRERE BEGREP HER
--
-- Hvilke begreper som kan SAMMENLIGNES mellom stasjoner er en
-- produktregel - `DRIFT_BEGREP` i `kurs/loftestenger.ts` - og den bor
-- ett sted. Viewet gir alle driftsbegrepene, og app-laget velger.
--
-- Radtallet tillater det: begrepene er faa, og leverandoerene per begrep
-- er faerre.
--
-- ---------------------------------------------------------------------
-- RETTIGHETER
--
-- `security_invoker = true`, saa `bilagssum` sine to policyer gjelder -
-- inkludert butikksjefens begrepsgrense fra `0203`. Rommet er eierens,
-- men viewet skal ikke vaere en omvei rundt RLS for noen andre.
--
-- `revoke all from anon` ved siden av granten, alltid.
-- =====================================================================

create or replace view public.v_rommet_leverandor
with (security_invoker = true) as
select
  b.retailer_id,
  b.stasjon_id,
  b.begrep,
  b.tekst,
  sum(b.belop_kr)               as belop_kr,
  sum(b.antall)                 as antall,
  count(distinct b.periode)     as maaneder,
  min(b.periode)                as eldste,
  max(b.periode)                as nyeste
from public.bilagssum b
where b.stasjon_id is not null
  and b.begrep is not null
group by b.retailer_id, b.stasjon_id, b.begrep, b.tekst;

grant select on public.v_rommet_leverandor to authenticated;
revoke all on public.v_rommet_leverandor from anon;

comment on view public.v_rommet_leverandor is
  'Én rad per stasjon per leverandoer per begrep, summert over hele '
  'perioden. Grunnlaget for Regnskapsrommet. Summeres HER fordi sida '
  'hentet raa bilagssum med et tak paa 900 rader og krasjet paa foerste '
  'sidelast (0207) - 8 029 bilagslinjer blir langt mer enn det per '
  'maaned. `maaneder` foelger med fordi aarseffekten maa skaleres fra '
  'det grunnlaget faktisk dekker.';

-- ---------------------------------------------------------------------
-- Kvittering. SOM SELECT, ikke `raise notice`: notices gaar til
-- serverloggen og vises ikke i Supabase SQL Editor. Kvitteringene i
-- 0201-0206 var derfor usynlige for den som kjoerte dem.
-- ---------------------------------------------------------------------
select
  count(*)                              as rader,
  count(distinct stasjon_id)            as stasjoner,
  count(distinct tekst)                 as leverandorer,
  max(maaneder)                         as flest_maaneder,
  min(eldste)                           as eldste,
  max(nyeste)                           as nyeste,
  round(sum(belop_kr))                  as sum_kroner
from public.v_rommet_leverandor;
