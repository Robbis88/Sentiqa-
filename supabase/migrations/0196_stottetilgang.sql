-- =====================================================================
-- 0196  STOETTETILGANG MED SPOR
-- =====================================================================
-- I dag er plattformens tilgang til en kunde alt eller ingenting:
-- `plattform_redaktor` har retailer_id = null og ser NULL rader gjennom
-- RLS, mens tjenestenoekkelen ser absolutt alt. Det finnes ikke noe
-- imellom, og ingen logg over at den ble brukt.
--
-- Det gaar fint paa en kunde. Paa aatti er "hva saa du, og naar?" et
-- spoersmaal man blir stilt, og "det staar i en commit-melding" er ikke
-- et svar.
--
-- ---------------------------------------------------------------------
-- HVORFOR DETTE IKKE ROERER RLS
--
-- Den elegante loesningen ville vaert aa la `gjeldende_retailer_id()`
-- svare "din egen kjede, ELLER den du har stoettetilgang til". Den
-- funksjonen er det hver eneste policy i systemet hviler paa, og den slo
-- ut `daglig_salg` i produksjon 2026-06-16. En feil der er ikke en feil i
-- en visning - den er hele basen.
--
-- Derfor er dette en PORT FORAN TJENESTENOEKKELEN, ikke en utvidelse av
-- radnivaasikkerheten. Isolasjonen staar noeyaktig som foer. Det som er
-- nytt er at plattformhandlinger som roerer en levende kunde nekter aa
-- kjoere uten en aktiv rad her - og at hvert oppslag skriver en linje.
--
-- FEILER LUKKET. Ingen rad, ingen tilgang. Er tabellen utilgjengelig,
-- kjoerer ikke handlingen.
--
-- ---------------------------------------------------------------------
-- KUNDEN SER SIN EGEN LOGG
--
-- Det er hele poenget med at den er etterproevbar. `retailer_admin` kan
-- lese baade tildelingene og oppslagene for SIN kjede. Ingen skrivepolicy
-- finnes for `authenticated` - radene kommer fra tjenestenoekkelen, og en
-- logg som lar seg redigere dokumenterer ingenting.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tildelingen: hvem, hvilken kjede, hvorfor, og hvor lenge.
-- ---------------------------------------------------------------------
create table if not exists public.stotte_tilgang (
  id            uuid primary key default gen_random_uuid(),
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  -- Plattform-redaktoeren som ga seg selv tilgangen. Ikke en rolle - en
  -- person. "Plattformen saa paa det" er ikke et svar til en kunde.
  gitt_til      uuid not null references public.profiler(id) on delete restrict,
  -- Fritekst, og den er paakrevd med vilje. En begrunnelse man maa skrive
  -- er en begrunnelse man maa ha.
  begrunnelse   text not null,
  fra_tid       timestamptz not null default now(),
  til_tid       timestamptz not null,
  -- Satt naar redaktoeren avslutter selv, foer vinduet loep ut.
  avsluttet_tid timestamptz,
  opprettet_tid timestamptz not null default now(),
  constraint stotte_tilgang_begrunnelse_ekte
    check (length(btrim(begrunnelse)) >= 10),
  -- TIDSBEGRENSNINGEN LIGGER I SKJEMAET, IKKE I EN KOMMENTAR. Et vindu
  -- man kan sette til ti aar er ikke et vindu.
  constraint stotte_tilgang_vindu
    check (til_tid > fra_tid and til_tid <= fra_tid + interval '24 hours')
);

create index if not exists stotte_tilgang_aktiv_idx
  on public.stotte_tilgang (retailer_id, til_tid desc);

-- ---------------------------------------------------------------------
-- Oppslaget: hva som faktisk ble gjort under tildelingen.
--
-- En tildeling dokumenterer at noen FIKK LOV. Bare denne dokumenterer
-- hva som ble gjort. De to er ikke det samme, og det er den andre en
-- kunde spoer om.
-- ---------------------------------------------------------------------
create table if not exists public.stotte_oppslag (
  id          bigint generated always as identity primary key,
  tilgang_id  uuid not null references public.stotte_tilgang(id) on delete cascade,
  retailer_id uuid not null references public.retailers(id) on delete cascade,
  handling    text not null,
  detaljer    jsonb not null default '{}'::jsonb,
  tid         timestamptz not null default now()
);

create index if not exists stotte_oppslag_retailer_idx
  on public.stotte_oppslag (retailer_id, tid desc);

alter table public.stotte_tilgang enable row level security;
alter table public.stotte_oppslag enable row level security;

-- ---------------------------------------------------------------------
-- Policyer.
--
-- Kun SELECT, kun eieren, kun egen kjede. Hjelpefunksjonene er pakket i
-- `(select ...)` saa de blir initplan og ikke evalueres per rad - se
-- AGENTS.md. Ingen `for all`: `USING` i en slik policy gjelder ogsaa
-- SELECT, og drar en skrivepolicy inn i hver leseplan.
--
-- Ingen insert/update/delete-policy i det hele tatt. Det er ikke en
-- forglemmelse: radene skrives av tjenestenoekkelen, og ingen skal kunne
-- endre sin egen revisjonslogg. Tabellene staar derfor med
-- `ingen_skrivepolicy` i tenant-kontrakten.
-- ---------------------------------------------------------------------
drop policy if exists stotte_tilgang_les on public.stotte_tilgang;
create policy stotte_tilgang_les on public.stotte_tilgang for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );

drop policy if exists stotte_oppslag_les on public.stotte_oppslag;
create policy stotte_oppslag_les on public.stotte_oppslag for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'retailer_admin'
  );

-- ---------------------------------------------------------------------
-- Rettigheter.
--
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast, og
-- Supabase-standarden `alter default privileges ... grant all on tables
-- to anon` treffer hver ny tabell. 2026-08-25 svarte 77 tabeller
-- `200 []` for anon - ingen lekkasje, men granten laa der. Derfor staar
-- revoke ved siden av granten, alltid.
-- ---------------------------------------------------------------------
grant select on public.stotte_tilgang to authenticated;
grant select on public.stotte_oppslag to authenticated;
revoke all on public.stotte_tilgang from anon;
revoke all on public.stotte_oppslag from anon;

-- ---------------------------------------------------------------------
-- Er det aapent akkurat naa?
--
-- Security definer fordi den maa kunne svare for en retailer kalleren
-- ikke tilhoerer - det er nettopp poenget. Den leser bare katalogen over
-- tildelinger, og returnerer en boolsk verdi: ingen rad lekker ut.
--
-- `stable`, ikke `immutable`: den avhenger av now().
-- ---------------------------------------------------------------------
create or replace function public.stotte_er_aapen(p_retailer uuid, p_profil uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.stotte_tilgang t
    where t.retailer_id = p_retailer
      and t.gitt_til = p_profil
      and t.avsluttet_tid is null
      and now() between t.fra_tid and t.til_tid
  )
$$;

revoke all on function public.stotte_er_aapen(uuid, uuid) from public, anon, authenticated;
grant execute on function public.stotte_er_aapen(uuid, uuid) to service_role;
