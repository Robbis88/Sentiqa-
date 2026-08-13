-- =====================================================================
-- Sentiqa - 0081_bemanning_oppsett.sql
-- Oppsett for bemanningsplanleggeren. Ren struktur, ingen beregning -
-- motoren kommer i en senere migrasjon naar januar-formen er lest.
--
-- Modellen: kjeden gir hver stasjon et time- og lonnsbudsjett per maaned
-- pluss en brutto-forventning. Timene fordeles i tre lag:
--   1) BUNDET  - bemannet vindu x minimumsbemanning, krav-vinduer
--                (varemottak o.l.) og faste vakter. Trekkes fra forst.
--   2) FRI     - resten fordeles etter timesalg.inne_kunder per
--                ukedag x klokketime.
--   3) RESERVE - holdes tilbake til sykefravaer/ferie.
--
-- Klokkeslett lagres som hele timer (0-24), samme opplosning som
-- timesalg-bottene ("0-1" ... "23-24"). til_time = 24 betyr midnatt.
-- Dognaapent = fra_time 0, til_time 24.
--
-- Ukedag foelger isodow: 1 = mandag ... 7 = soendag. Samme som
-- extract(isodow from dato), saa profilene kan joines rett mot timesalg.
--
-- Ingen retailer_id: tabellene henger paa stasjon_id med cascade, slik
-- som public.vaer (0015). Sletting av kjede gaar via stasjoner.
-- =====================================================================


-- ---------------------------------------------------------------------
-- bemannet vindu - naar er det folk paa stasjonen, per ukedag
-- ---------------------------------------------------------------------
-- Merk: dette er BEMANNET tid, ikke aapningstid. Aapner stasjonen 06 men
-- noen starter 05, er fra_time 5. Minimumsbemanningen legges som gulv
-- over hele vinduet, saa et for bredt vindu spiser timer fra
-- ettermiddagen der kundene faktisk er.
create table if not exists public.bemanning_vindu (
  id             uuid primary key default gen_random_uuid(),
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  ukedag         int  not null check (ukedag between 1 and 7),
  fra_time       int  not null check (fra_time between 0 and 23),
  til_time       int  not null check (til_time between 1 and 24),
  min_bemanning  int  not null default 1 check (min_bemanning >= 0),
  oppdatert_tid  timestamptz not null default now(),
  unique (stasjon_id, ukedag),
  check (til_time > fra_time)
);
create index if not exists bemanning_vindu_stasjon_idx
  on public.bemanning_vindu (stasjon_id);

comment on table public.bemanning_vindu is
  'Bemannet vindu per stasjon og ukedag (isodow). Ikke aapningstid - naar det faktisk staar folk der.';
comment on column public.bemanning_vindu.min_bemanning is
  'Gulv over hele vinduet. 1 = en kan staa alene. Krav-vinduer legger seg oppaa.';


-- ---------------------------------------------------------------------
-- krav-vinduer - timer som krever flere enn gulvet
-- ---------------------------------------------------------------------
-- Varemottak, sikkerhet, opplaering. Overstyrer min_bemanning i sitt
-- eget intervall. Flere rader kan overlappe; hoyeste antall vinner.
create table if not exists public.bemanning_krav (
  id            uuid primary key default gen_random_uuid(),
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  ukedag        int  not null check (ukedag between 1 and 7),
  fra_time      int  not null check (fra_time between 0 and 23),
  til_time      int  not null check (til_time between 1 and 24),
  antall        int  not null check (antall >= 1),
  begrunnelse   text,
  oppdatert_tid timestamptz not null default now(),
  check (til_time > fra_time)
);
create index if not exists bemanning_krav_stasjon_idx
  on public.bemanning_krav (stasjon_id, ukedag);

comment on table public.bemanning_krav is
  'Timer som krever flere enn min_bemanning (varemottak o.l.). Overlapp: hoyeste antall vinner.';


-- ---------------------------------------------------------------------
-- faste vakter - bindinger som alltid ligger i grunn
-- ---------------------------------------------------------------------
-- Butikksjef 07-15 mandag-fredag gir fem rader. Disse trekkes fra
-- budsjettet for fordelingen, og teller med i dekningen for timen.
create table if not exists public.bemanning_fast_vakt (
  id            uuid primary key default gen_random_uuid(),
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  navn          text not null,
  ukedag        int  not null check (ukedag between 1 and 7),
  fra_time      int  not null check (fra_time between 0 and 23),
  til_time      int  not null check (til_time between 1 and 24),
  oppdatert_tid timestamptz not null default now(),
  unique (stasjon_id, navn, ukedag),
  check (til_time > fra_time)
);
create index if not exists bemanning_fast_vakt_stasjon_idx
  on public.bemanning_fast_vakt (stasjon_id);

comment on table public.bemanning_fast_vakt is
  'Faste bindinger, f.eks. butikksjef 07-15 man-fre. En rad per ukedag.';


-- ---------------------------------------------------------------------
-- maanedsbudsjett fra kjeden
-- ---------------------------------------------------------------------
-- lonn_kr er ALL-IN (arbeidsgiveravgift, feriepenger, tillegg), saa
-- lonn_kr / timer gir snittsatsen direkte. brutto_bp_kr er forventet
-- bruttofortjeneste. Noekkeltallene faller ut av disse tre:
--   brutto pr bemanningstime = brutto_bp_kr / timer
--   lonnsandel               = lonn_kr / brutto_bp_kr
-- Naar faktisk brutto svikter, er tillatte timer
--   faktisk_brutto / (brutto_bp_kr / timer).
create table if not exists public.bemanning_budsjett (
  id             uuid primary key default gen_random_uuid(),
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  ar             int  not null check (ar between 2020 and 2100),
  maned          int  not null check (maned between 1 and 12),
  timer          numeric not null check (timer >= 0),
  lonn_kr        numeric check (lonn_kr >= 0),
  brutto_bp_kr   numeric check (brutto_bp_kr >= 0),
  reserve_pst    numeric not null default 0 check (reserve_pst >= 0 and reserve_pst < 100),
  notat          text,
  oppdatert_tid  timestamptz not null default now(),
  unique (stasjon_id, ar, maned)
);
create index if not exists bemanning_budsjett_stasjon_idx
  on public.bemanning_budsjett (stasjon_id, ar, maned);

comment on table public.bemanning_budsjett is
  'Time- og lonnsbudsjett per stasjon og maaned, gitt av kjeden. lonn_kr er all-in.';
comment on column public.bemanning_budsjett.reserve_pst is
  'Andel av timene som holdes tilbake til sykefravaer/ferie for fordelingen.';


-- =====================================================================
-- RLS
-- Lesing: alle med stasjonstilgang. Skriving: retailer_admin og
-- butikksjef. Splittet i insert/update/delete - aldri "for all", og
-- gjeldende_rolle() pakket i (select ...) saa den blir initplan.
-- Se AGENTS.md og supabase/tests/rls_vakthund.sql.
-- =====================================================================

alter table public.bemanning_vindu     enable row level security;
alter table public.bemanning_krav      enable row level security;
alter table public.bemanning_fast_vakt enable row level security;
alter table public.bemanning_budsjett  enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'bemanning_vindu', 'bemanning_krav', 'bemanning_fast_vakt', 'bemanning_budsjett'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t || '_les',   t);
    execute format('drop policy if exists %I on public.%I', t || '_skriv', t);
    execute format('drop policy if exists %I on public.%I', t || '_ins',   t);
    execute format('drop policy if exists %I on public.%I', t || '_upd',   t);
    execute format('drop policy if exists %I on public.%I', t || '_del',   t);

    execute format($f$
      create policy %I on public.%I for select to authenticated
        using (stasjon_id in (select public.mine_stasjoner()))
    $f$, t || '_les', t);

    execute format($f$
      create policy %I on public.%I for insert to authenticated
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_ins', t);

    execute format($f$
      create policy %I on public.%I for update to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_upd', t);

    execute format($f$
      create policy %I on public.%I for delete to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_del', t);

    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;
