-- =====================================================================
-- 0208  SVINNARKET LAGRES HELT: BEGGE NIVAA, ALLE FELTENE
-- =====================================================================
-- `regnskap_usynlig_svinn` lagret fem tall per produktrad, og dermed
-- kunne matanalysen ikke etterproeves. Malt paa Kelsars sju maanedsfiler:
--
--   LAGRET I DAG      salg (k8), brf_pst (k12), kast (k20),
--                     usynlig_kr (k23), usynlig_pst (k24)
--
--   IKKE LAGRET       faktisk BF i kroner (k11)
--                     TEORETISK BF i kroner og prosent (k15, k16)
--                     kastprosent (k21)
--
-- Uten teoretisk BF kan identiteten ikke avstemmes:
--
--   teoretisk BF  −  faktisk BF  −  synlig kast  =  usynlig svinn
--
-- Identiteten holder til OERET i arkets egne tall - `diff = 0` i alle 35
-- stasjonsmaaneder. Den skal derfor kontrolleres, ikke utledes: BEGGE
-- verdier bevares, St1s egen og vaar. Erstatter vi den ene med den
-- andre, mister vi sporet tilbake til rapporten.
--
-- ---------------------------------------------------------------------
-- TO NIVAA, OG DE SKAL ALDRI SUMMERES SAMMEN
--
-- Arket har 13 `ProdGr3`-grupper per stasjon og produktradene under dem:
--
--    546  gruppe    ← SANNHETSRADEN. Eier totalen.
--   2346  produkt   ← forklaring og drilldown
--
-- Parseren tok bare `type === 'Prod'`. Grupperaden - den som eier
-- totalen - ble aldri lagret. Summerer en analyse begge nivaaer, dobles
-- alt; `nivaa` er derfor ikke en merkelapp, det er en grense.
-- Regelen ligger ett sted: `src/lib/svinn/nivaa.ts`.
--
-- ---------------------------------------------------------------------
-- ANALYSEOMRAADET UTLEDES AV ARKET, IKKE AV ANTALL SIFFER
--
-- Robert 2026-09-12: «Firesifrede rader skal ikke fjernes bare fordi de
-- har fire sifre. De skal fjernes fordi de tilhoerer drivstoff/CR.»
--
-- De 13 gruppekodene paa arket definerer butikkens univers. En
-- produktrad er butikk naar de tre foerste sifrene er en gruppe som
-- finnes paa SAMME ark i SAMME maaned: `12010 → 120 Mat` ✓,
-- `1490 → 149` finnes ikke ✗.
--
-- Malt: 2346 butikk, 420 drivstoff/CR, 0 uten kode. Kodelengden lagres
-- som KONTROLLSIGNAL, aldri som regel - St1 kan innfoere en femsifret
-- drivstoffkode i morgen.
--
-- `ukjent` er en egen tilstand. Raden lagres, men blokkeres fra
-- analysen: «vi vet ikke hva dette er» er et annet svar enn «dette
-- finnes ikke».
--
-- ---------------------------------------------------------------------
-- `brf_pst` ER FAKTISK PROSENT
--
-- Kolonne 12. Ikke budsjettert (k14), ikke teoretisk (k16). Kolonnen
-- beholder navnet sitt fordi den er i bruk, men det staar skrevet her
-- hva den er - det var ikke dokumentert noe sted foer.
--
-- ---------------------------------------------------------------------
-- FORRETNINGSNOEKKELEN
--
--   (retailer_id, stasjon_id, periode, nivaa, kode)
--
-- Malt paa 2 892 butikkrader over 35 stasjonsmaaneder: 0 dubletter.
--
-- `kilde_jobb_id` og `kildefil` er PROVENIENS, ikke del av noekkelen. Er
-- de med, lagres samme oekonomiske rad paa nytt for hver import.
--
-- Indeksen er PARTIELL paa `analyseomraade = 'butikk'`. Drivstoffblokkene
-- har samme firesifrede kode tre ganger per ark, med ulik betydning i
-- hver blokk - de kan ikke deles én noekkel, og de skal ikke overskrive
-- hverandre. De lagres uten unikhet og summeres aldri.
--
-- ---------------------------------------------------------------------
-- GAMLE RADER FAAR IKKE ET PAAFUNNET OMRAADE
--
-- Eksisterende rader er alle produktrader - parseren tok bare `Prod`, og
-- det er bevist i koden. `nivaa` kan derfor etterfylles trygt.
--
-- `analyseomraade` kan IKKE etterfylles: det krever gruppekodene fra
-- arket, og de finnes ikke i basen. Kolonnen staar `null`, raden
-- blokkeres fra analysen, og reimporten setter den riktig. Et hull skal
-- ikke fylles med en gjetning.
--
-- Idempotent: `add column if not exists`, `create index if not exists`,
-- vaktet etterfylling.
-- =====================================================================

alter table public.regnskap_usynlig_svinn
  add column if not exists nivaa               text,
  add column if not exists analyseomraade      text,
  add column if not exists kode_gruppe         text,
  add column if not exists kodelengde          integer,
  add column if not exists bf_kr               numeric,
  add column if not exists teoretisk_kr        numeric,
  add column if not exists teoretisk_pst       numeric,
  add column if not exists kast_pst            numeric,
  add column if not exists kontroll_usynlig_kr numeric,
  add column if not exists avviksstatus        text,
  add column if not exists kildefil            text,
  add column if not exists kilde_rad           integer;

comment on column public.regnskap_usynlig_svinn.nivaa is
  '«gruppe» (ProdGr3, eier totalen) eller «produkt» (Prod, forklaring). '
  'Ingen analyse skal summere begge. Se src/lib/svinn/nivaa.ts.';
comment on column public.regnskap_usynlig_svinn.analyseomraade is
  '«butikk», «drivstoff» eller «ukjent». Utledet av arkets egne '
  'gruppekoder, ikke av kodelengde. Bare «butikk» inngaar i '
  'svinn- og bruttofortjenesteanalysen. Null = gammel rad, blokkert.';
comment on column public.regnskap_usynlig_svinn.brf_pst is
  'FAKTISK bruttofortjenesteprosent, kolonne 12. Ikke budsjettert (k14) '
  'og ikke teoretisk (k16).';
comment on column public.regnskap_usynlig_svinn.bf_kr is
  'Faktisk bruttofortjeneste i kroner, kolonne 11.';
comment on column public.regnskap_usynlig_svinn.teoretisk_kr is
  'TEORETISK bruttofortjeneste i kroner, kolonne 15. Grunnlaget for '
  'identiteten teoretisk − faktisk − kast = usynlig.';
comment on column public.regnskap_usynlig_svinn.kontroll_usynlig_kr is
  'Vaar egen beregning av identiteten. St1s tall staar i usynlig_kr, og '
  'BEGGE bevares - ellers finnes ikke sporet tilbake til rapporten.';
comment on column public.regnskap_usynlig_svinn.avviksstatus is
  '«ok» naar importert og kontrollberegnet usynlig svinn stemmer innen '
  '0,50 kr, ellers «avvik». En rad med avvik skal ikke brukes til en '
  'konklusjon.';
comment on column public.regnskap_usynlig_svinn.kodelengde is
  'Kontrollsignal for dagens rapportformat, ALDRI en forretningsregel. '
  'Butikkoder er femsifrede og drivstoff firesifret i 2026-formatet - '
  'men det kan endres, og da skal analyseomraade fange det.';

-- ---------------------------------------------------------------------
-- Etterfylling: bare `nivaa`, og bare det som er bevist.
-- ---------------------------------------------------------------------
update public.regnskap_usynlig_svinn
   set nivaa = 'produkt',
       kodelengde = length(coalesce(kode, ''))
 where nivaa is null;

-- ---------------------------------------------------------------------
-- Skranker. Skrives med `if not exists`-vakt fordi hele settet kjoeres
-- om igjen fra bunn av og til.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'rus_nivaa_gyldig') then
    alter table public.regnskap_usynlig_svinn
      add constraint rus_nivaa_gyldig
      check (nivaa is null or nivaa in ('gruppe', 'produkt'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'rus_omraade_gyldig') then
    alter table public.regnskap_usynlig_svinn
      add constraint rus_omraade_gyldig
      check (analyseomraade is null or analyseomraade in ('butikk', 'drivstoff', 'ukjent'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'rus_avvik_gyldig') then
    alter table public.regnskap_usynlig_svinn
      add constraint rus_avvik_gyldig
      check (avviksstatus is null or avviksstatus in ('ok', 'avvik'));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- FORRETNINGSNOEKKELEN. Partiell: bare butikkrader.
--
-- Drivstoffblokkene har samme kode flere ganger per ark og kan ikke
-- deles én noekkel. De er proveniens, aldri en sum.
-- ---------------------------------------------------------------------
create unique index if not exists rus_butikk_unik
  on public.regnskap_usynlig_svinn (retailer_id, stasjon_id, periode, nivaa, kode)
  where analyseomraade = 'butikk' and slettet_tid is null;

create index if not exists rus_omraade_idx
  on public.regnskap_usynlig_svinn (retailer_id, periode, analyseomraade, nivaa);

-- ---------------------------------------------------------------------
-- Kvittering SOM SELECT. `raise notice` gaar til serverloggen og vises
-- ikke i Supabase SQL Editor - kvitteringene i 0201-0206 var derfor
-- usynlige for den som kjoerte dem.
-- ---------------------------------------------------------------------
select
  count(*)                                                as rader,
  count(*) filter (where nivaa = 'gruppe')                as gruppe,
  count(*) filter (where nivaa = 'produkt')               as produkt,
  count(*) filter (where analyseomraade is null)          as omraade_ukjent,
  count(*) filter (where teoretisk_kr is not null)        as med_teoretisk,
  count(*) filter (where avviksstatus = 'avvik')          as med_avvik,
  min(periode)                                            as eldste,
  max(periode)                                            as nyeste
from public.regnskap_usynlig_svinn
where slettet_tid is null;
