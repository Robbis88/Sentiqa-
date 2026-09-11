-- =====================================================================
-- 0199  BILAGSSUMMENE FRA PIVOTBUFFEREN
-- =====================================================================
-- `Kostnader`-arket i regnskapsrapporten er en PIVOTTABELL, og en
-- pivottabell lagrer en kopi av kildedataene inne i selve fila. Kilden er
-- TOLV MAANEDERS BILAGSLINJER - ikke bare maaneden rapporten gjelder.
--
-- Arket viser bare en butikk fordi filteret staar paa `9900 Admin`. Hele
-- datasettet foelger med uansett. Kelsars sju maanedsfiler bar til sammen
-- 202502-202607, 11 737 unike bilagslinjer med leverandoernavn paa hver.
--
-- Ingen har lest dem.
--
-- ---------------------------------------------------------------------
-- HVORFOR DET BETYR NOE
--
-- Uten dette er "renhold er hoeyt" alt systemet kan si. Med det er det
-- "ASKO Vest, 29 825 paa Lone, mot Vardens 7 207" - og det er forskjellen
-- mellom en rapport og en plan.
--
-- Det var ogsaa bilagsteksten som avgjorde klassifiseringen av
-- kostnadslinjene: `634 Rep & vedlikehold` er 82 % WashTec paa stasjonene
-- med vask, altsaa maskinen og ikke butikksjefens valg - men paa Dale,
-- som ikke har vask, er den null WashTec. En KODE er ikke en spak eller
-- en foelge. En LEVERANDOER er det.
--
-- ---------------------------------------------------------------------
-- KORNET
--
-- butikk x periode x konto x tekst. Grovest mulige korn som fortsatt
-- svarer paa "hvem gikk pengene til". `antall` er med fordi det er et
-- eget signal: fire fakturaer fra samme leverandoer er en avtale, atten
-- er en vane.
--
-- =====================================================================
-- TILGANGEN KAN IKKE SKRIVES I KODER HER
-- =====================================================================
--
-- `BUTIKKSJEF_DRIFT_KODER` er rapportlinjekoder, og en kode er en
-- adresse - ikke en identitet. St1 renummererte i februar 2026: `628`
-- betydde "Leie driftsmidler" foer og "Renovasjon" naa.
--
-- For stasjonsarkene gaar det bra: importen AVVISER filer fra den gamle
-- epoken (0198-arbeidet, `parsere/kontoregister.ts`). Men BUFFEREN baerer
-- tolv maaneder bakover i HVER fil, saa de eldste radene er fra det gamle
-- skjemaet uansett hvor ny fila er. En grense skrevet i koder ville
-- sluppet leasingkostnaden gjennom til butikksjefen som "renovasjon".
--
-- Derfor baerer hver rad et KONTOBEGREP - det kanoniske, stabile navnet -
-- og policyen leser det. Et begrep vi ikke kjente igjen lagres som NULL,
-- og NULL er ikke med i lista: ukjent betyr skjult, ikke synlig.
--
-- Lista under maa stemme med `BUTIKKSJEF_BEGREP` i
-- `src/lib/regnskap-tilgang.ts`. `begrepliste.test.ts` binder dem sammen,
-- slik `lister.test.ts` gjoer for RLS-filene.
-- =====================================================================

create table if not exists public.bilagssum (
  id              uuid primary key default gen_random_uuid(),
  retailer_id     uuid not null references public.retailers(id) on delete cascade,

  -- NULL for kostnadssteder som ikke er en stasjon (9900 Admin). Da er
  -- raden usynlig for butikksjef av seg selv: policyen krever at
  -- stasjonen er en av deres.
  stasjon_id      uuid references public.stasjoner(id) on delete cascade,
  -- Butikknummeret slik fila skriver det. Baeres med fordi admin ikke har
  -- en stasjon, og fordi det er noekkelen naar samme fil lastes om igjen.
  butikknummer    text not null,

  periode         date not null,

  -- Rapportlinja slik fila skrev den. TIL REFERANSE, IKKE TIL TILGANG.
  rapportlinje    text not null,
  -- Kontonummeret med navn. Den durable identiteten - 75 av 80 konti
  -- peker paa samme begrep foer og etter omnummereringen.
  konto           text not null,
  -- Det kanoniske begrepet. NULL naar paret (kode, navn) ikke var kjent,
  -- typisk rader fra skjemaet foer februar 2026. NULL = skjult.
  begrep          text,

  tekst           text not null,
  belop_kr        numeric(14,2) not null,
  antall          integer not null default 1,

  kilde_jobb_id   uuid,
  oppdatert_tid   timestamptz not null default now(),

  -- SAMME FIL TO GANGER SKAL IKKE DOBLE NOE. Hver maanedsfil baerer tolv
  -- maaneder, saa de sju filene overlapper med elleve. Uten denne ville
  -- hver opplasting lagt hele fjoraaret oppaa seg selv.
  constraint bilagssum_unik unique (retailer_id, butikknummer, periode, konto, tekst),
  constraint bilagssum_antall_positivt check (antall >= 1)
);

create index if not exists bilagssum_stasjon_periode_idx
  on public.bilagssum (stasjon_id, periode desc);
create index if not exists bilagssum_retailer_begrep_idx
  on public.bilagssum (retailer_id, begrep, periode desc);

alter table public.bilagssum enable row level security;

-- ---------------------------------------------------------------------
-- Policyer.
--
-- To separate SELECT-policyer, ikke en med `or`: permissive policyer
-- OR-es sammen uansett, og to smale er lettere aa lese enn en bred.
--
-- Hjelpefunksjonene er pakket i `(select ...)` saa de blir initplan.
-- `har_stasjonstilgang(stasjon_id)` kan aldri bli initplan fordi den tar
-- en kolonne som argument - derfor `stasjon_id in (select
-- public.mine_stasjoner())`. Se AGENTS.md.
--
-- Ingen `for all`: `USING` i en slik policy gjelder ogsaa SELECT og drar
-- skrivepolicyen inn i hver leseplan.
--
-- Ingen insert/update/delete-policy. Radene kommer fra importen gjennom
-- tjenestenoekkelen. Tabellen staar med `ingen_skrivepolicy` i
-- tenant-kontrakten.
-- ---------------------------------------------------------------------
drop policy if exists bilagssum_les_eier on public.bilagssum;
create policy bilagssum_les_eier on public.bilagssum for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );

-- BUTIKKSJEF: bare egne stasjoner, og bare begreper de skal se.
--
-- `begrep` maa vaere NOT NULL og staa i lista. En rad vi ikke kjente
-- igjen er skjult, ikke synlig. Feiler lukket.
--
-- Admin-radene har stasjon_id = null og faller ut av `in (...)` av seg
-- selv - null er aldri med i en IN-liste.
drop policy if exists bilagssum_les_butikksjef on public.bilagssum;
create policy bilagssum_les_butikksjef on public.bilagssum for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'butikksjef'
    and stasjon_id in (select public.mine_stasjoner())
    and begrep is not null
    and begrep = any (array[
      'faste_lonninger','lonnstillegg','timelonn','sykelonn',
      'refundert_sykelonn','palopte_feriepenger','bonus',
      'arbeidsgiveravgift_lonn','arbeidsgiveravgift_feriepenger',
      'andre_personalkostnader',
      'renhold','renovasjon','broyting','utstyr_verktoy',
      'forbruksmateriell','rep_vedlikehold','pengehandtering',
      'kontorrekvisita','kassedifferanse'
    ])
  );

-- ---------------------------------------------------------------------
-- Rettigheter.
--
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
-- Supabase-standarden `alter default privileges ... grant all on tables
-- to anon` treffer hver ny tabell. Derfor staar revoke ved siden av
-- granten, alltid.
-- ---------------------------------------------------------------------
grant select on public.bilagssum to authenticated;
revoke all on public.bilagssum from anon;

comment on table public.bilagssum is
  'Bilagslinjer summert per butikk, maaned, konto og leverandoer, lest ut '
  'av pivotbufferen i regnskapsfila. Tilgangen gaar paa `begrep`, ikke paa '
  'rapportlinjekode: koden betyr ulike ting foer og etter februar 2026.';
comment on column public.bilagssum.begrep is
  'Kanonisk kontobegrep fra parsere/kontoregister.ts. NULL naar paret '
  '(kode, navn) ikke var kjent - typisk rader fra skjemaet foer feb 2026. '
  'NULL er skjult for butikksjef.';
