-- =====================================================================
-- 0200  MAANEDSPLANEN
-- =====================================================================
-- Ukebriefen forteller hva som skjedde forrige uke. Maanedsplanen sier
-- hva butikksjefen skal gjoere denne maaneden - og den bygges paa
-- RETNING, ikke paa nivaa.
--
-- En butikk med 8 % matkast som kom fra 12 % vinner. En med 6 % som kom
-- fra 4 % taper. Paa nivaa ser den andre best ut. Paa Kelsars sju
-- foerste maaneder i 2026 snur rangeringen helt: Dale er sist paa nivaa
-- og foerst paa retning.
--
-- =====================================================================
-- ROBERT GODKJENNER FOER DEN GAAR
-- =====================================================================
--
-- Valgt bevisst, 2026-09-11: systemet skriver utkastet, eieren slipper
-- det. Ukebriefen har samme flyt i `klar.ts`.
--
-- Det gir en grense som maa staa i RLS og ikke i en visning:
-- **butikksjefen skal ALDRI se et utkast.** Et brev som ikke er sluppet
-- er ikke et brev - det er et forslag til eieren, og halvparten av dem
-- kommer aldri til aa sendes. Ser butikksjefen dem, er godkjenningen
-- meningsloes.
--
-- Derfor har butikksjefens lesepolicy `status in ('sluppet','sendt')`.
-- Ingen ny rolle, ingen ny funksjon: bare en kolonne policyen leser.
--
-- ---------------------------------------------------------------------
-- HVORFOR PUNKTENE ER JSONB
--
-- En plan har null, ett eller to punkter - medvind gir en bekreftelse og
-- NESTE loeftestang, motvind gir EN ting. De er ikke rader noen
-- spoer paa tvers av; de leses alltid sammen med planen sin.
--
-- En egen tabell ville betydd en join for aa vise et brev, og en
-- fremmednoekkel aa holde ryddig, for noe som aldri skal endres etter at
-- det er skrevet. Planen er et DOKUMENT - den sier hva vi mente den
-- maaneden, og det skal staa.
--
-- ---------------------------------------------------------------------
-- EN PLAN PER STASJON PER MAANED
--
-- Regnskapet kan lastes opp paa nytt - en korrigert fil, eller samme fil
-- to ganger. Da skal planen skrives OM, ikke ved siden av. Men bare saa
-- lenge den er et utkast: en plan som er sluppet eller sendt er noe
-- butikksjefen har lest, og den skal ikke endre seg under henne.
-- Trigger under haandhever det.
-- =====================================================================

create table if not exists public.maanedsplan (
  id             uuid primary key default gen_random_uuid(),
  retailer_id    uuid not null references public.retailers(id) on delete cascade,
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  maaned         date not null,

  dom            text not null,
  ingress        text not null,
  -- Array av punkter: {slag, loftestang, tittel, tekst, kronerIAret, leverandor?}
  punkter        jsonb not null default '[]'::jsonb,
  -- Sagt rett ut naar planen ikke kunne regne kroner (manglende
  -- royaltysatser). En plan som tier om det ser komplett ut.
  merknad        text,

  status         text not null default 'utkast',
  sluppet_av     uuid references public.profiler(id) on delete set null,
  sluppet_tid    timestamptz,
  sendt_tid      timestamptz,

  kilde_jobb_id  uuid,
  opprettet_tid  timestamptz not null default now(),
  oppdatert_tid  timestamptz not null default now(),

  constraint maanedsplan_unik unique (stasjon_id, maaned),
  constraint maanedsplan_dom_gyldig
    check (dom in ('medvind', 'motvind', 'flat')),
  constraint maanedsplan_status_gyldig
    check (status in ('utkast', 'sluppet', 'sendt', 'avvist')),
  -- SLUPPET UTEN AT NOEN SLAPP DEN ER IKKE EN GODKJENNING. Hele poenget
  -- med flyten er at et menneske staar bak, og en status uten en person
  -- er en status ingen kan svare for.
  constraint maanedsplan_sluppet_har_person
    check (status not in ('sluppet', 'sendt') or (sluppet_av is not null and sluppet_tid is not null)),
  constraint maanedsplan_punkter_er_liste
    check (jsonb_typeof(punkter) = 'array')
);

create index if not exists maanedsplan_retailer_maaned_idx
  on public.maanedsplan (retailer_id, maaned desc, status);
create index if not exists maanedsplan_stasjon_maaned_idx
  on public.maanedsplan (stasjon_id, maaned desc);

-- ---------------------------------------------------------------------
-- EN SLUPPET PLAN SKRIVES IKKE OM
--
-- Importen skriver utkast med upsert. Uten denne ville en ny opplasting
-- av regnskapet endret et brev butikksjefen allerede har lest - og hun
-- ville hatt en annen plan enn den hun husker, uten at noe sa fra.
--
-- Trigger og ikke policy: policyen gjelder `authenticated`, og importen
-- kjoerer med tjenestenoekkelen. En regel som bare finnes i policyen
-- gjelder ikke den som faktisk skriver.
-- ---------------------------------------------------------------------
create or replace function public.maanedsplan_laas_sluppet()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('sluppet', 'sendt')
     and (new.punkter is distinct from old.punkter
          or new.ingress is distinct from old.ingress
          or new.dom is distinct from old.dom) then
    raise exception
      'Maanedsplanen for % % er allerede %, og innholdet kan ikke endres. '
      'Sett status tilbake til utkast foerst hvis den skal skrives om.',
      old.stasjon_id, to_char(old.maaned, 'YYYY-MM'), old.status
      using errcode = 'check_violation';
  end if;
  new.oppdatert_tid := now();
  return new;
end $$;

drop trigger if exists maanedsplan_laas_sluppet_trg on public.maanedsplan;
create trigger maanedsplan_laas_sluppet_trg
  before update on public.maanedsplan
  for each row execute function public.maanedsplan_laas_sluppet();

alter table public.maanedsplan enable row level security;

-- ---------------------------------------------------------------------
-- Policyer.
--
-- Hjelpefunksjonene er pakket i `(select ...)` saa de blir initplan.
-- `stasjon_id in (select public.mine_stasjoner())` og ikke
-- `har_stasjonstilgang(stasjon_id)`, som aldri kan bli initplan fordi
-- den tar en kolonne som argument. Ingen `for all`. Se AGENTS.md.
-- ---------------------------------------------------------------------

-- Eieren ser alt, ogsaa utkastene. Det er hennes godkjenningskoe.
drop policy if exists maanedsplan_les_eier on public.maanedsplan;
create policy maanedsplan_les_eier on public.maanedsplan for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );

-- BUTIKKSJEFEN SER ALDRI ET UTKAST. Se begrunnelsen oeverst.
drop policy if exists maanedsplan_les_butikksjef on public.maanedsplan;
create policy maanedsplan_les_butikksjef on public.maanedsplan for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'butikksjef'
    and stasjon_id in (select public.mine_stasjoner())
    and status in ('sluppet', 'sendt')
  );

-- Eieren slipper planen. Bare status og de tre feltene som hoerer til
-- slippet - innholdet laases av triggeren over uansett hvem som skriver.
drop policy if exists maanedsplan_slipp on public.maanedsplan;
create policy maanedsplan_slipp on public.maanedsplan for update to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  )
  with check (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );

-- Ingen insert-policy: utkastene skrives av importen gjennom
-- tjenestenoekkelen. Ingen delete-policy: en plan som er sendt er et
-- dokument over hva vi mente den maaneden.

-- ---------------------------------------------------------------------
-- Rettigheter.
--
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
-- Supabase-standarden `alter default privileges ... grant all on tables
-- to anon` treffer hver ny tabell. Derfor staar revoke ved siden av
-- granten, alltid.
-- ---------------------------------------------------------------------
grant select, update on public.maanedsplan to authenticated;
revoke all on public.maanedsplan from anon;

comment on table public.maanedsplan is
  'Manedsplanen til butikksjefen, bygget paa RETNING og ikke nivaa. '
  'Eieren godkjenner foer den gaar: butikksjefen ser aldri et utkast.';
comment on column public.maanedsplan.status is
  'utkast -> sluppet -> sendt. Butikksjefens lesepolicy krever sluppet '
  'eller sendt. avvist er en plan eieren ikke ville sende.';
