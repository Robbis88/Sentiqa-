-- =====================================================================
-- Sentiqa — Daglig salg (PROSJEKT.md §16 steg 2/3, §7)
-- Parsede salgslinjer fra St1 Salgsstatistikk. Månedspartisjonert (§3/§14).
-- Idempotent: PK (retailer_id, stasjon_id, dato, ean) → re-opplasting
-- overskriver i stedet for å duplisere (§6). retailer_id + slettet_tid.
-- =====================================================================

create table if not exists public.daglig_salg (
  id                  uuid not null default gen_random_uuid(),
  retailer_id         uuid not null references public.retailers(id) on delete restrict,
  stasjon_id          uuid not null references public.stasjoner(id) on delete restrict,
  dato                date not null,
  ean                 text not null,
  varenr              text,
  varenavn            text,
  avdeling_kode       text,
  avdeling_navn       text,
  vareomrade_kode     text,
  vareomrade_navn     text,
  varegruppe_kode     text,
  varegruppe_navn     text,
  antall              numeric,
  antall_tilbud       numeric,
  omsetning_eks_mva   numeric,
  bto_fortjeneste_kr  numeric,
  bto_fortjeneste_pct numeric,
  kilde_jobb_id       uuid references public.import_jobber(id) on delete set null,
  opprettet_tid       timestamptz not null default now(),
  slettet_tid         timestamptz,
  -- Partisjonsnøkkel (dato) må inngå i PK. PK er også upsert-nøkkel (§6).
  primary key (retailer_id, stasjon_id, dato, ean)
) partition by range (dato);

create index if not exists daglig_salg_stasjon_dato_idx
  on public.daglig_salg (stasjon_id, dato);
create index if not exists daglig_salg_varegruppe_idx
  on public.daglig_salg (retailer_id, varegruppe_kode);

-- Månedspartisjoner 2024–2027 + default for alt utenfor (utvides ved behov).
--
-- HVER partisjon må stenges eksplisitt. Supabase har som standard
-- `alter default privileges in schema public grant all on tables to
-- anon, authenticated`, så en nyopprettet partisjon får rettigheter av
-- seg selv — og partisjonens EGEN RLS (ikke forelderens) gjelder ved
-- direkte oppslag. Uten linjene under kan anon lese
-- `/rest/v1/daglig_salg_202601` og få alle kjeders tall.
--
-- Det var tilstanden i produksjon fram til 0105 (2026-08-18).
do $$
declare
  d date := date '2024-01-01';
  navn text;
begin
  while d < date '2028-01-01' loop
    navn := 'daglig_salg_' || to_char(d, 'YYYYMM');
    execute format(
      'create table if not exists public.%I partition of public.daglig_salg for values from (%L) to (%L)',
      navn, d, (d + interval '1 month')::date);
    execute format('revoke all on public.%I from anon, authenticated', navn);
    execute format('alter table public.%I enable row level security', navn);
    d := (d + interval '1 month')::date;
  end loop;
end $$;
create table if not exists public.daglig_salg_default partition of public.daglig_salg default;
revoke all on public.daglig_salg_default from anon, authenticated;
alter table public.daglig_salg_default enable row level security;

-- Sporing av hvor mange rader en jobb produserte (synlig i import-status).
alter table public.import_jobber add column if not exists antall_rader integer;

-- ---------------------------------------------------------------------
-- RLS — admin ser/skriver alt eget; butikksjef leser tildelte stasjoner.
--
-- Policyene under gjelder oppslag GJENNOM foreldretabellen. Det er den
-- veien appen går (v_butikksalg og importen), så de er nok for driften.
--
-- De gjelder IKKE et direkte oppslag på en partisjon — der er det
-- partisjonens egen RLS som avgjør. Derfor stenges hver partisjon i
-- løkken over. En tidligere versjon av denne kommentaren sa bare det
-- første, og da leste den som en garanti den ikke ga.
-- ---------------------------------------------------------------------
alter table public.daglig_salg enable row level security;

drop policy if exists daglig_salg_les on public.daglig_salg;
create policy daglig_salg_les on public.daglig_salg for select to authenticated
  using (
    slettet_tid is null
    and (
      (public.gjeldende_rolle() = 'retailer_admin'
       and retailer_id = public.gjeldende_retailer_id())
      or public.har_stasjonstilgang(stasjon_id)
    )
  );

drop policy if exists daglig_salg_admin_skriv on public.daglig_salg;
create policy daglig_salg_admin_skriv on public.daglig_salg for all to authenticated
  using (public.gjeldende_rolle() = 'retailer_admin'
         and retailer_id = public.gjeldende_retailer_id())
  with check (public.gjeldende_rolle() = 'retailer_admin'
              and retailer_id = public.gjeldende_retailer_id());

grant select, insert, update, delete on public.daglig_salg to authenticated;
