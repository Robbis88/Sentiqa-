-- =====================================================================
-- 0198  ROYALTYSATSENE FRA BP
-- =====================================================================
-- Sentiqa kjenner ikke royaltysatsene. Derfor rangerer systemet
-- varegrupper paa BRUTTOMARGIN, og det er feil vei rundt: St1 tar
-- royalty av OMSETNING, ikke av margin.
--
-- Konsekvensen var ikke akademisk. Handlingsplanen for Kelsar sa foerst
-- at "en krone bilvask er verdt 1,8 kroner mat", regnet paa brutto. Etter
-- royalty er det motsatt: maskinvask over kassa gir 23,5 oere netto per
-- krone, mat gir 38,9. Rekkefoelgen avgjoer hvor butikksjefene faar
-- beskjed om aa bruke tiden sin.
--
-- ---------------------------------------------------------------------
-- GRUNNLAGET ER OMSETNING. DET ER HELE POENGET.
--
-- En gevinst som kommer av MINDRE SVINN gir mer margin paa SAMME
-- omsetning - og da oeker ikke royaltyen. Hele svinngevinsten blir
-- vaerende. Bare VEKST betaler royalty, fordi bare vekst gir mer
-- omsetning aa regne den av.
--
-- Et system som trekker en flat royaltyprosent fra enhver forbedring
-- undervurderer svinnarbeid og overvurderer volumarbeid. Begge deler
-- sender folk feil vei.
--
-- ---------------------------------------------------------------------
-- TRE SATSER, IKKE EN
--
-- BP-arket `Cluster data` oppgir dem rett ut:
--
--   Royalty lav sats (aarlig)                  0,10  av omsetning
--   Royalty hoey sats (bilvask og selvvask)    0,60  av omsetning
--   Royalty pant                               0
--
-- Den hoeye satsen treffer bare vask solgt OVER KASSA. Vask kjoert paa
-- abonnement er royaltyfri - BP baerer den digitale andelen per stasjon i
-- arket `Andel dig vask Grunnlagsfil`, og trekker den fra grunnlaget.
--
-- ---------------------------------------------------------------------
-- KONTROLLTALLENE LAGRES MED SATSENE
--
-- `bp_*`-kolonnene er BP-ens egne summer. De er ikke pynt: de gjoer at
-- satsene kan ETTERPROEVES der de staar, ikke bare i en test som kjoerte
-- en gang. For Kelsar 2026 gaar det opp paa oeret:
--
--   0,10 * (68 249 457 - 8 553 540 vask - 349 342 pant) =  5 934 658
--                              royalty vask (fra BP)    =  4 158 800
--                                                   sum = 10 093 458
--                              `Sum Royalty` i BP       = 10 093 458
--
-- Og modellen er etterregnet mot regnskapet for alle fem stasjonene
-- januar-juli 2026: 6 481 888 mot faktisk 6 488 659, avvik 0,10 %.
--
-- ---------------------------------------------------------------------
-- INGEN SKRIVEPOLICY
--
-- Radene kommer fra BP-importen gjennom tjenestenoekkelen. En sats som
-- kan redigeres i en visning er en sats ingen lenger vet opphavet til, og
-- den ville gjort hver kroneberegning i systemet til et skjoenn. Er
-- satsen feil, er BP-en feil, og da importeres den paa nytt.
-- =====================================================================

create table if not exists public.royaltysats (
  id                 uuid primary key default gen_random_uuid(),
  retailer_id        uuid not null references public.retailers(id) on delete cascade,
  aar                integer not null,

  -- Satsene. Andel av OMSETNING, ikke av margin.
  lav_sats           numeric(6,5) not null,
  hoy_sats_vask      numeric(6,5) not null,
  pant_sats          numeric(6,5) not null default 0,

  -- BP-ens egne kontrolltall, saa satsene kan etterproeves der de staar.
  bp_sum_royalty     numeric(14,2),
  bp_sum_cr_salg     numeric(14,2),
  bp_omsetning_vask  numeric(14,2),
  bp_omsetning_pant  numeric(14,2),
  bp_royalty_vask    numeric(14,2),

  kilde              text not null default 'bp',
  opprettet_tid      timestamptz not null default now(),

  -- EN SATS PER AAR. To rader for samme aar er to sannheter, og da er
  -- hver kroneberegning i systemet avhengig av hvilken som ble lest.
  constraint royaltysats_unik unique (retailer_id, aar),

  -- Satser utenfor [0,1] er ikke en sats. En BP med 60 i stedet for 0,60
  -- skal stoppe her, ikke seks uker senere i et tall ingen forstaar.
  constraint royaltysats_lav_gyldig   check (lav_sats      >= 0 and lav_sats      <= 1),
  constraint royaltysats_hoy_gyldig   check (hoy_sats_vask >= 0 and hoy_sats_vask <= 1),
  constraint royaltysats_pant_gyldig  check (pant_sats     >= 0 and pant_sats     <= 1),
  constraint royaltysats_aar_gyldig   check (aar between 2020 and 2100)
);

create index if not exists royaltysats_retailer_aar_idx
  on public.royaltysats (retailer_id, aar desc);

alter table public.royaltysats enable row level security;

-- ---------------------------------------------------------------------
-- Policy.
--
-- SELECT for hele kjeden. Satsene er ikke hemmelige innad - de trengs
-- overalt der systemet sier hva noe er verdt, ogsaa paa flater en
-- butikksjef ser. Det er kroneverdien de skal se, ikke satsen, men
-- funksjonen som regner den maa kunne lese den.
--
-- Hjelpefunksjonen er pakket i `(select ...)` saa den blir initplan og
-- ikke evalueres per rad. Ingen `for all`: `USING` i en slik policy
-- gjelder ogsaa SELECT og drar skrivepolicyen inn i hver leseplan.
-- Se AGENTS.md.
--
-- Ingen insert/update/delete-policy. Radene skrives av importen gjennom
-- tjenestenoekkelen. Tabellen staar derfor med `ingen_skrivepolicy` i
-- tenant-kontrakten.
-- ---------------------------------------------------------------------
drop policy if exists royaltysats_les on public.royaltysats;
create policy royaltysats_les on public.royaltysats for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()));

-- ---------------------------------------------------------------------
-- Rettigheter.
--
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
-- Supabase-standarden `alter default privileges ... grant all on tables
-- to anon` treffer hver ny tabell. Derfor staar revoke ved siden av
-- granten, alltid.
-- ---------------------------------------------------------------------
grant select on public.royaltysats to authenticated;
revoke all on public.royaltysats from anon;

comment on table public.royaltysats is
  'Royaltysatser per retailer og aar, lest fra BP-arket "Cluster data". '
  'Grunnlaget er OMSETNING, ikke margin: en svinngevinst betaler ingen '
  'royalty, bare vekst gjoer det.';
comment on column public.royaltysats.hoy_sats_vask is
  'Gjelder bare vask solgt over kassa. Vask paa abonnement er royaltyfri.';
