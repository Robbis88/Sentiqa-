-- =====================================================================
-- 0110 - stempling som HENDELSER
--
-- Designet ligger i PROSJEKT_stempling.md. Dette er datamodellen under
-- det; grensesnittet kommer etter.
--
-- HVORFOR HENDELSER OG IKKE VAKTER: dagens `stempling` er vaktformet
-- (fra_tid, til_tid, minutter). Riktig for en FERDIG vakt, umulig som
-- kilde - sluttiden finnes ikke i det oyeblikket hun stempler inn.
--
-- `stempling` blir avledet av hendelsene. Alt som er bygget leser
-- fortsatt `stempling` og merker ingenting: lonnsfila, bemanningsplanen,
-- innsynsutskriften, plan-mot-faktisk.
--
-- HENDELSER ER APPEND-ONLY. En rettelse er en NY hendelse, og
-- originalen blir staaende annullert. Naar stemplingen blir kilden til
-- lonn, slaar bokforingslovens sporbarhetskrav inn: en rettet stempling
-- maa vise hva som sto der for, hvem som endret den, og naar. En tabell
-- man kan oppdatere fritt kan ikke svare paa det.
-- =====================================================================

-- --- Ansattnummeret: soemmen mellom nettbrett og lonn ----------------
--
-- `ansatte` har navn og PIN, men intet nummer - det er en av de tre
-- identitetene (se minnenotatet «tre identiteter»). Nummeret er det som
-- kobler den som staar paa nettbrettet til den som faar lonn.
--
-- Nummeret er LONNSBYRAAETS (Azets), ikke easy@works lokale
-- stemplingsnummer. Nettopp den forskjellen - 11058 mot 1058 - gjorde
-- mai-avstemmingen vanskelig.
--
-- Behandles som en ugjennomsiktig streng: ingen antakelse om lengde
-- eller siffer, fordi neste kunde bruker et annet byraa.
alter table public.ansatte add column if not exists ansatt_nr text;

comment on column public.ansatte.ansatt_nr is
  'Lonnsbyraaets ansattnummer. Ugjennomsiktig streng - ingen formatantakelse. '
  'Null til butikksjefen har fylt det inn; da kan personen stemple, men '
  'timene naar ikke lonnsfila.';

-- To personer i samme kjede kan ikke ha samme nummer. Delvis indeks, saa
-- de mange radene uten nummer ikke kolliderer med hverandre.
create unique index if not exists ansatte_nr_unik
  on public.ansatte (retailer_id, ansatt_nr)
  where ansatt_nr is not null and slettet_tid is null;

-- --- Hendelsene ------------------------------------------------------
create table if not exists public.stempling_hendelse (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete restrict,
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  -- Nummeret, ikke ansatte.id: det er dette som folger med til lonn.
  ansatt_nr     text not null,
  -- Navnet slik det var DA. En som bytter etternavn skal ikke endre
  -- historikken i et lonnsgrunnlag.
  ansatt_navn   text not null,
  tidspunkt     timestamptz not null,
  type          text not null check (type in ('inn', 'ut')),
  -- Hvor hendelsen kom fra. Gjor parallellkjoring mulig: en stasjon kan
  -- gaa over til nettbrettet mens de andre fortsatt importeres, uten at
  -- noe telles to ganger.
  kilde         text not null check (kilde in ('tablet', 'import', 'korreksjon')),

  -- Annullering framfor sletting. Originalen blir staaende.
  annullert_tid timestamptz,
  annullert_av  uuid references auth.users(id) on delete set null,
  -- Peker paa hendelsen denne retter, naar den er en korreksjon.
  retter_id     uuid references public.stempling_hendelse(id) on delete set null,
  begrunnelse   text,

  registrert_av uuid references auth.users(id) on delete set null,
  opprettet_tid timestamptz not null default now(),

  -- Samme person kan ikke stemple samme vei paa samme sekund. Fanger
  -- dobbelttrykk uten aa hindre en ekte inn-ut-inn.
  unique (stasjon_id, ansatt_nr, tidspunkt, type)
);

create index if not exists stempling_hendelse_oppslag
  on public.stempling_hendelse (stasjon_id, ansatt_nr, tidspunkt)
  where annullert_tid is null;

create index if not exists stempling_hendelse_retailer
  on public.stempling_hendelse (retailer_id, tidspunkt);

comment on table public.stempling_hendelse is
  'Raa inn/ut-hendelser. `stempling` avledes av disse. Append-only: en '
  'rettelse er en ny rad med retter_id, og originalen annulleres framfor '
  'aa slettes (bokforingslovens sporbarhetskrav).';

-- --- Kilde paa den avledede tabellen ---------------------------------
-- Lonnsfila skal kunne vise hvilken kilde hver time kom fra mens begge
-- kjorer parallelt. Eksisterende rader er importerte.
alter table public.stempling add column if not exists kilde text
  not null default 'import';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'stempling_kilde_gyldig'
  ) then
    alter table public.stempling add constraint stempling_kilde_gyldig
      check (kilde in ('import', 'tablet'));
  end if;
end $$;

-- --- Driftsregler som varierer mellom kjeder -------------------------
--
-- Skillet fra designet: det som varierer med drift og kultur blir
-- konfigurasjon; det som beskytter lonnsgrunnlaget eller de ansatte gjor
-- det ikke. PIN-krav, sporbare korreksjoner og at aapne vakter blokkerer
-- lonnsfila er derfor IKKE innstillinger.
alter table public.retailers
  add column if not exists stempling_pause_betalt boolean not null default true;
alter table public.retailers
  add column if not exists stempling_vis_innstemplede boolean not null default true;

comment on column public.retailers.stempling_pause_betalt is
  'Standard paa. Med en til to paa jobb kan folk sjelden forlate stasjonen, '
  'og da er pausen arbeidstid etter aml. § 10-9. Storre enheter har andre '
  'ordninger.';
comment on column public.retailers.stempling_vis_innstemplede is
  'Kulturvalg. Gir sosial kontroll, men noen kjeder vil ikke ha det.';

-- --- RLS -------------------------------------------------------------
alter table public.stempling_hendelse enable row level security;

drop policy if exists stempling_hendelse_les on public.stempling_hendelse;
drop policy if exists stempling_hendelse_ins on public.stempling_hendelse;
drop policy if exists stempling_hendelse_upd on public.stempling_hendelse;

-- Formen folger reglene i AGENTS.md: funksjonskall pakket i (select ...),
-- mine_stasjoner() i stedet for har_stasjonstilgang(kolonne), og ingen
-- `for all`. Tabellen vokser med drift - en hendelse per inn og ut, per
-- ansatt, per dag - saa den er varm fra dag en.
create policy stempling_hendelse_les on public.stempling_hendelse
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

create policy stempling_hendelse_ins on public.stempling_hendelse
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner()));

-- Kun annullering. Ingen delete-policy: hendelser slettes ikke.
create policy stempling_hendelse_upd on public.stempling_hendelse
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

grant select, insert, update on public.stempling_hendelse to authenticated;

-- HUSK: stempling_hendelse er lagt inn i `varme`-arrayet i
-- supabase/tests/rls_vakthund.sql i samme commit. Uten det ville den
-- ligget med policyer og uten tilsyn - akkurat som
-- kontrolltiltak_bekreftelse gjorde fra 0103 til 2026-08-18.
