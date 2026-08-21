-- =====================================================================
-- Sentiqa - pin_hash lukkes for klientrollen
-- =====================================================================
--
-- FUNNET: `grant select, insert, update, delete on public.ansatte to
-- authenticated` (0025:38) er paa TABELLNIVAA. Det dekker alle kolonner,
-- ogsaa framtidige - `ansatt_nr` ble lesbar i 0110 uten at noen tok
-- stilling til det.
--
-- RLS gjorde jobben sin: `ansatte_les` (0078) gir nettbrettet radene paa
-- egen stasjon. Men RLS avgjor RADER. Grants avgjor KOLONNER. Radgjerdet
-- var riktig og kolonnegjerdet fantes ikke.
--
-- Foelgen: en nettbrettsesjon kunne be PostgREST om
--
--     GET /rest/v1/ansatte?select=navn,pin_hash
--
-- og faa hashen til alle aktive ansatte paa egen stasjon - noeyaktig de
-- menneskene som deler nettbrettet. `hashPin` er sha256 med FELLES
-- kjedesalt, retailer-id-en staar i brukerens egen profil, og fire til
-- seks siffer er ~1,1 millioner kandidater. Altsaa sekunder offline.
--
-- Etter korrekthetstrinnet er PIN-en bare en hemmelighet. En gjenopprettet
-- PIN gir vakt som den personen - og sammen med ansattnummeret, som staar
-- paa loennsslippen, ogsaa stempling. Altsaa loenn.
--
-- ---------------------------------------------------------------------
-- DETTE ER IKKE BARE ET GRANT-BYTTE.
--
-- Aa flytte verifiseringen inn i en funksjon fjerner offline-angrepet og
-- etterlater et ONLINE-angrep: kjenn nummeret, regn ut kandidathasher
-- lokalt, kall funksjonen ti tusen ganger. Derfor er verifisering og
-- forsoekshaandtering bygget SAMMEN her. En funksjon som svarer ja/nei
-- uten aa telle er et orakel.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Forsoekene: rate limiting og revisjon i samme tabell
-- ---------------------------------------------------------------------
--
-- Den maatte finnes uansett for aa kunne telle, og da lukker den samtidig
-- funnet om at vaktinnlogging ikke etterlot spor i det hele tatt.
--
-- INGEN HEMMELIGHETER HER. Ikke PIN, ikke pin_hash, ikke signaturnokler.
-- `ansatt_nr` er den FORSOEKTE identiteten - den staar paa loennsslippen
-- og er ingen hemmelighet, men den er det eneste som gjor det mulig aa se
-- at noen proevde seg paa en bestemt person.
--
-- Kolonnen heter `opprettet_tid` med vilje: retensjons-cronen
-- (/api/cron/opprydding) rydder paa akkurat det navnet.
create table if not exists public.pin_forsok (
  id            bigserial primary key,
  retailer_id   uuid not null references public.retailers(id) on delete cascade,
  -- Kjent foerst naar ansatten faktisk ble funnet. Null ved ukjent nummer.
  stasjon_id    uuid references public.stasjoner(id) on delete set null,
  ansatt_nr     text,
  -- Hvilken innlogget enhet som proevde. Det er denne som skiller «en
  -- ansatt fomlet» fra «noen sitter og roterer numre paa ett nettbrett».
  bruker_id     uuid,
  kilde         text not null check (kilde in ('vakt', 'stempling')),
  ok            boolean not null,
  -- Ble forsoeket avvist av pausen, ikke av PIN-en? Da er det et signal
  -- om at noen holder paa, ikke om at noen har glemt koden sin.
  blokkert      boolean not null default false,
  opprettet_tid timestamptz not null default clock_timestamp()
);

-- Indeksene ER rate limitingen. Uten dem gjor hver innlogging en
-- fulltabellskanning av en tabell som vokser med hver eneste vakt.
create index if not exists pin_forsok_identitet_idx
  on public.pin_forsok (retailer_id, ansatt_nr, opprettet_tid desc);
create index if not exists pin_forsok_bruker_idx
  on public.pin_forsok (retailer_id, bruker_id, opprettet_tid desc);
-- Retensjonsryddingen sletter paa alder alene.
create index if not exists pin_forsok_alder_idx
  on public.pin_forsok (opprettet_tid);

comment on table public.pin_forsok is
  'Innloggingsforsoek for vakt og stempling. Baerer ALDRI PIN eller '
  'pin_hash. Brukes til rate limiting (5 per ansattnummer / 20 per enhet '
  'per 15 min) og som revisjonsspor. Retensjon 90 dager, ryddes av '
  '/api/cron/opprydding.';

-- Klokka, ikke transaksjonens starttid. `now()` staar stille gjennom en
-- hel transaksjon, og en revisjonslogg der flere forsoek deler
-- tidsstempel lyver om takten de kom i. Egen setning fordi
-- `create table if not exists` ikke roerer en tabell som finnes.
alter table public.pin_forsok
  alter column opprettet_tid set default clock_timestamp();

alter table public.pin_forsok enable row level security;

-- LEDERE LESER, INGEN SKRIVER.
--
-- Radene settes inn av `verifiser_ansatt_pin`, som er security definer og
-- dermed gaar forbi RLS. Derfor finnes det ingen insert-policy og ingen
-- insert-rettighet: den ENESTE veien inn i denne tabellen er gjennom
-- funksjonen som ogsaa teller. Kunne en klient skrive her selv, kunne den
-- skrive seg ut av sin egen pause.
drop policy if exists pin_forsok_les on public.pin_forsok;
create policy pin_forsok_les on public.pin_forsok for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );

revoke all on public.pin_forsok from anon, authenticated;
grant select on public.pin_forsok to authenticated;


-- ---------------------------------------------------------------------
-- 2) Kolonnegjerdet paa ansatte
-- ---------------------------------------------------------------------
--
-- Ni av ti kolonner. `pin_hash` er den tiende.
--
-- EN BONUS SOM ER VERDT AA VITE OM: med kolonnegrant blir en NY kolonne
-- ikke automatisk lesbar. Det var nettopp det som skjedde med `ansatt_nr`
-- i 0110. Legger noen til en kolonne etter dette, maa de ta stilling til
-- om den skal leses - og vakthunden sier fra hvis de lar vaere.
revoke all on public.ansatte from anon;
revoke select on public.ansatte from authenticated;
grant select (
  id, retailer_id, stasjon_id, navn, ansatt_nr,
  aktiv, opprettet_av, opprettet_tid, slettet_tid
) on public.ansatte to authenticated;

-- UPDATE PAA pin_hash TAS BORT HELT.
--
-- Ingen kode oppdaterer den: PIN settes kun ved opprettelse
-- (ansatte/handlinger.ts). `settAnsattnummer` roerer `ansatt_nr`,
-- `deaktiverAnsatt` roerer `aktiv`/`slettet_tid`. Retten koster altsaa
-- ingen capability - men den lot en butikksjef PATCHe en kollegas
-- pin_hash til noe hun selv kjente, utenom produktet og uten spor.
--
-- SAMME FELLE SOM FOR SELECT, og jeg gikk i den. Et `revoke update
-- (pin_hash)` gjor INGENTING saa lenge tabellnivaa-granten fra 0025
-- staar: en tabellrett dekker alle kolonner, og kan ikke trekkes tilbake
-- kolonne for kolonne. Man maa fjerne tabellretten og dele ut kolonnene.
-- Vakthunden fanget det paa foerste kjoering.
--
-- Skal PIN-endring bygges senere, er det en egen kontrollert
-- serverhandling med revisjon, rolle- og tenantkontroll og uskillelige
-- feilmeldinger. Ikke ved aa gi denne retten tilbake.
revoke update on public.ansatte from authenticated;
grant update (navn, stasjon_id, ansatt_nr, aktiv, slettet_tid)
  on public.ansatte to authenticated;

-- INSERT blir staaende paa tabellnivaa: `pin_hash` er `not null`, og
-- lederen som oppretter en ansatt SKAL sette den foerste PIN-en. Det er
-- den godkjente arbeidsflyten.


-- ---------------------------------------------------------------------
-- 3) Verifisering + forsoekshaandtering, uloeselig sammen
-- ---------------------------------------------------------------------
--
-- Returnerer id-en ved treff. ALDRI hashen.
--
-- TO VINDUER, OG BEGGE MAA TIL:
--
--   5 feil per (retailer, ansatt_nr) / 15 min
--       hindrer aa gjette EN persons PIN.
--
--   20 feil per (retailer, bruker_id) / 15 min
--       hindrer aa rotere ansattnummer fra samme enhet. Uten denne er den
--       foerste virkningsloes: ti tusen forsoek fordelt paa femti numre
--       moeter aldri identitetsgrensen.
--
-- INGEN PERMANENT UTESTENGING. Vinduet gaar ut av seg selv, og ingen leder
-- maa laase opp. Prisen er at en ondsinnet kollega kan holde ett nummer i
-- pause ved aa taste feil hvert kvarter - det er en bevisst avveining mot
-- en laas som krever et menneske for aa aapnes.
--
-- ET VELLYKKET FORSOEK NULLSTILLER identitetstelleren. Det er gjort ved aa
-- telle feil SIDEN SISTE TREFF, ikke ved aa slette rader: revisjonssporet
-- skal ikke kunne viskes ut av at noen logger inn riktig.
create or replace function public.verifiser_ansatt_pin(
  p_ansatt_nr text,
  p_pin_hash  text,
  p_kilde     text
)
returns table (ansatt_id uuid, status text, vent_sekunder int)
language plpgsql
volatile                                  -- den SKRIVER forsoeket
security definer
set search_path = public, pg_temp
as $$
declare
  v_retailer   uuid;
  v_bruker     uuid := auth.uid();
  v_vindu      interval := interval '15 minutes';
  v_maks_id    int := 5;
  v_maks_enhet int := 20;
  v_feil_id    int;
  v_feil_enhet int;
  v_eldste     timestamptz;
  v_ansatt     record;
  v_vent       int;
begin
  if p_kilde not in ('vakt', 'stempling') then
    raise exception 'ukjent kilde';
  end if;

  -- TENANTEN KOMMER FRA DATABASEKONTEKSTEN, aldri fra en parameter.
  -- Funksjonen er security definer og gaar forbi RLS; det er her inne
  -- gjerdet maa staa.
  v_retailer := (select public.gjeldende_retailer_id());
  if v_retailer is null then
    return query select null::uuid, 'avvist'::text, 0;
    return;
  end if;

  -- Feil paa denne identiteten SIDEN SISTE TREFF, innenfor vinduet.
  --
  -- SAMMENLIGNINGEN GAAR PAA `id`, IKKE PAA TID, og det er ikke
  -- pedanteri. `now()` er TRANSAKSJONENS starttid, ikke klokka: skjer
  -- flere forsoek i samme transaksjon, faar de identisk tidsstempel, og
  -- «senere enn siste treff» blir da usant for alle sammen. Telleren sto
  -- paa null uansett hvor mange ganger noen proevde.
  --
  -- I drift er hvert kall sin egen transaksjon, saa feilen var usynlig
  -- der - og den ville blitt oppdaget den dagen noen faktisk gjettet
  -- PIN-er. Beviset fant den paa foerste kjoering fordi det kjorer alt i
  -- en transaksjon.
  --
  -- `id` er bigserial: alltid stigende, alltid forskjellig, ogsaa inne i
  -- en transaksjon. Den er derfor det eneste som svarer riktig paa
  -- «kom dette forsoeket etter forrige treff».
  select count(*) into v_feil_id
  from public.pin_forsok f
  where f.retailer_id = v_retailer
    and f.ansatt_nr is not distinct from p_ansatt_nr
    and not f.ok
    -- ET BLOKKERT FORSOEK ER IKKE ET GJETT. Talte vi dem med, ville
    -- pausen forlenge seg selv saa lenge noen hamret, og aldri gaa ut.
    -- Da hadde vi bygget en permanent utestenging med en annen ordlyd.
    and not f.blokkert
    and f.opprettet_tid > now() - v_vindu
    and f.id > coalesce((
      select max(g.id) from public.pin_forsok g
      where g.retailer_id = v_retailer
        and g.ansatt_nr is not distinct from p_ansatt_nr
        and g.ok
    ), 0);

  select count(*) into v_feil_enhet
  from public.pin_forsok f
  where f.retailer_id = v_retailer
    and f.bruker_id is not distinct from v_bruker
    and not f.ok
    and not f.blokkert
    and f.opprettet_tid > now() - v_vindu;

  if v_feil_id >= v_maks_id or v_feil_enhet >= v_maks_enhet then
    -- Hvor lenge til det eldste relevante forsoeket faller ut av vinduet.
    select min(f.opprettet_tid) into v_eldste
    from public.pin_forsok f
    where f.retailer_id = v_retailer
      and not f.ok
      and not f.blokkert
      and f.opprettet_tid > now() - v_vindu
      and (f.ansatt_nr is not distinct from p_ansatt_nr
           or f.bruker_id is not distinct from v_bruker);
    v_vent := greatest(1, ceil(extract(epoch from (v_eldste + v_vindu - now())))::int);

    -- Ogsaa et blokkert forsoek skal staa i sporet. Det er nettopp de
    -- radene som viser at noen holdt paa.
    insert into public.pin_forsok
      (retailer_id, ansatt_nr, bruker_id, kilde, ok, blokkert)
    values (v_retailer, p_ansatt_nr, v_bruker, p_kilde, false, true);

    return query select null::uuid, 'sperret'::text, v_vent;
    return;
  end if;

  -- Oppslag paa NUMMER. Hashen sammenlignes etterpaa, og aldri i en
  -- `where pin_hash = ...` som ville gjort hemmeligheten til identitet.
  select a.id, a.stasjon_id, a.pin_hash into v_ansatt
  from public.ansatte a
  where a.retailer_id = v_retailer
    and a.ansatt_nr = p_ansatt_nr
    and a.aktiv
    and a.slettet_tid is null
  limit 1;

  if v_ansatt.id is null or v_ansatt.pin_hash is distinct from p_pin_hash then
    insert into public.pin_forsok
      (retailer_id, stasjon_id, ansatt_nr, bruker_id, kilde, ok)
    values (v_retailer, v_ansatt.stasjon_id, p_ansatt_nr, v_bruker, p_kilde, false);
    -- SAMME SVAR for ukjent nummer og feil PIN. To ulike svar ville latt
    -- hvem som helst kartlegge hvilke ansattnumre som finnes.
    return query select null::uuid, 'avvist'::text, 0;
    return;
  end if;

  insert into public.pin_forsok
    (retailer_id, stasjon_id, ansatt_nr, bruker_id, kilde, ok)
  values (v_retailer, v_ansatt.stasjon_id, p_ansatt_nr, v_bruker, p_kilde, true);

  return query select v_ansatt.id, 'ok'::text, 0;
end;
$$;

-- EXECUTE er eksplisitt og smal.
--
-- `revoke from public` ALENE ER IKKE NOK, og det var den andre fella.
-- Supabase deler ut EXECUTE paa nye funksjoner til anon, authenticated
-- og service_role gjennom `alter default privileges` - navngitt, ikke
-- gjennom PUBLIC. En revoke fra PUBLIC roerer dem derfor ikke i det
-- hele tatt, og funksjonen sto aapen for anon. Vakthunden fanget ogsaa
-- denne paa foerste kjoering.
revoke all on function public.verifiser_ansatt_pin(text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.verifiser_ansatt_pin(text, text, text) to authenticated;

comment on function public.verifiser_ansatt_pin(text, text, text) is
  'Verifiserer ansattnummer + PIN-hash med innebygd forsoekshaandtering. '
  'Returnerer ansatt-id ved treff, aldri pin_hash. Tenant hentes fra '
  'gjeldende_retailer_id(), aldri fra parameter.';
