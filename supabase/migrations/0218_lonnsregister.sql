-- ---------------------------------------------------------------------
-- 0218: det periodiserte loennsregisteret
-- ---------------------------------------------------------------------
-- Registeret svarer paa ETT spoersmaal:
--
--   Hva oppga easy@work om denne personen, paa denne stasjonen, i denne
--   maanedens loennsgrunnlag?
--
-- Det er en KILDEOBSERVASJON, ikke HR-masterdata. Den avgrensningen er
-- hele poenget: registeret vet hva fila sa, ikke hva som er sant om
-- ansettelsesforholdet.
--
-- ---------------------------------------------------------------------
-- HVORFOR DEN MAA FINNES
--
-- `beregnArbeidssted` priser en time ved aa slaa ansattnummeret opp mot
-- en timesats. Satsen leses av loennsgrunnlaget - og KASTES ved import.
-- `lesLonnsgrunnlag` bruker den til aa regne `belop_kr` og skriver den
-- aldri. `hovedlokasjon` kastes paa samme maate.
--
-- MAALT paa Lones julifil 2026: 18 ansatte i registeret, 15 i
-- `lonnsart_linje`. Tre forsvinner - blant dem Carmen Valentina Toro,
-- som staar med 0 timer paa Lone og sats 138,00, og som jobbet 79,82
-- timer paa Boenes samme maaned.
--
-- Det er nettopp den raden motoren trenger. Parseren hopper over den
-- fordi den ikke har dato, og det er riktig for det `lesLonnsgrunnlag`
-- svarer paa: hvilke timer ble jobbet her.
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE `lonnsart_linje`
--
-- Den kan ikke vaere registerkilden, og i ett tilfelle er den FARLIG:
--
--   ansatt med vanlige timer    sats = art 2 belop/timer       virker
--   nulltimersansatt            ingen rader i det hele tatt     feiler
--   fastloennet                 holdes bevisst ute av importen  feiler
--   bare kryssarbeid            rader finnes, men paa LAANE-
--                               stasjonen, ikke hjemstasjonen   feiler
--   kolliderende nummer         gir en PLAUSIBEL, men feil sats FARLIG
--
-- Den siste feiler ikke - den svarer feil.
--
-- ---------------------------------------------------------------------
-- NOEKKELEN ER FILAS KORNSTOERRELSE, IKKE PERSONEN
--
-- Ansattnummeret er en KILDEREFERANSE, ikke en personidentitet. MAALT i
-- produksjon juli 2026: nummer 1018 peker paa Andre Fjoerstad paa Varden
-- OG Marietta Iacovou paa Boenes, begge aktive samtidig.
--
-- Derfor er noekkelen (stasjon, kildemaaned, ansatt_nr) - én fil er én
-- stasjon i én maaned, og det er den kornstoerrelsen kilden faktisk har.
-- En noekkel paa (retailer, nummer, maaned) kunne ikke lagret begge, og
-- en modell som ikke kan uttrykke en feil vi VET finnes, er feil modell.
--
-- MERK: skjemaet gjoer kollisjonen REPRESENTERBAR. Det gjoer den ikke
-- ufarlig. Andre finnes ikke i noe loennsgrunnlag, saa oppslag paa 1018
-- gir fortsatt bare Mariettas rad. Identitetsvetoet hoerer til neste
-- port.
--
-- ---------------------------------------------------------------------
-- PERIODE BETYR KILDEMAANED, IKKE GYLDIGHET
--
-- Fila sier «i juli-grunnlaget oppga easy@work 138,00 for 1104265». Den
-- sier IKKE at satsen gjaldt fra 1. til 31. juli.
--
-- MAALT: ansatt 1104304 sto med 143,34 i april og mai, 185,58 fra juni.
-- Vi vet at satsen endret seg, ikke naar. `kilde_maaned` bevarer det vi
-- observerte; `gjelder_fra`/`gjelder_til` ville paastaatt noe mer.
-- ---------------------------------------------------------------------

create table if not exists public.lonnsregister (
  id             uuid primary key default gen_random_uuid(),
  -- INGEN `retailer_id`. Samme moenster som `lonnsart_linje` (0179) og
  -- `stempling` (0088): tenantisolasjon gaar via `mine_stasjoner()`, og
  -- stasjonen baerer kjeden. En kolonne til her ville vaert en andre
  -- sannhet om hvem raden tilhoerer.
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  -- Hvilken maaneds fil observasjonen kom fra. Tekst, ikke date: det er
  -- en maaned, ikke en dag, og `yyyy-mm` er formen hele huset bruker.
  kilde_maaned   text not null check (kilde_maaned ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  ansatt_nr      text not null,
  -- Navnet SLIK KILDEN SKRIVER DET. Ikke normalisert, ikke slaatt sammen.
  -- Identitetsvetoet i neste port trenger den raa formen: «Trond
  -- Eskeland» og «Trond Ivar Eskeland» er samme person, «Andre
  -- Fjoerstad» og «Marietta Iacovou» er det ikke.
  navn           text not null,
  -- NULL BETYR AT FILA IKKE OPPGA NOEN SATS. Det er noe helt annet enn
  -- null kroner, og noe helt annet enn at personen ikke finnes.
  -- `check (> 0)` hindrer at de tre tilstandene blandes.
  timesats       numeric check (timesats is null or timesats > 0),
  -- Hvilken import som leverte gjeldende snapshot. `set null` og ikke
  -- `cascade`: forsvinner jobben, mister vi sporet - ikke registeret.
  import_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid  timestamptz not null default now(),
  -- LAGRINGSINVARIANT ETTER VALIDERING, ikke en antakelse om at raafila
  -- er konsistent. Importen skal avvise motstridende rader FOER den
  -- skriver; se `lonnsregister_snapshot`.
  unique (stasjon_id, kilde_maaned, ansatt_nr)
);

-- Oppslaget motoren gjoer: gi meg registeret for én stasjon og maaned.
-- Unique-indeksen daekker (stasjon, maaned, nr) og brukes av den, saa
-- ingen egen indeks trengs for det. Denne er for oppslag paa NUMMER paa
-- tvers av stasjoner - det identitetsvetoet skal gjoere i neste port.
create index if not exists lonnsregister_nr_maaned_idx
  on public.lonnsregister (ansatt_nr, kilde_maaned);

comment on table public.lonnsregister is
  'Hva easy@work oppga om en person paa en stasjon i en maaneds loennsgrunnlag. '
  'Kildeobservasjon, ikke HR-masterdata.';
comment on column public.lonnsregister.kilde_maaned is
  'Maaneden FILA gjelder. Ikke satsens gyldighetsperiode - den kjenner vi ikke.';
comment on column public.lonnsregister.ansatt_nr is
  'easy@works referanse. IKKE en personidentitet: 1018 pekte paa to mennesker i juli 2026.';
comment on column public.lonnsregister.timesats is
  'NULL = fila oppga ingen sats. Ikke null kroner, og ikke at personen mangler.';
comment on column public.lonnsregister.navn is
  'Raa form fra kilden. Identitetsvetoet trenger den uendret.';


-- ---------------------------------------------------------------------
-- RLS - samme moenster som 0179
-- ---------------------------------------------------------------------
alter table public.lonnsregister enable row level security;

drop policy if exists lonnsregister_les on public.lonnsregister;
drop policy if exists lonnsregister_ins on public.lonnsregister;
drop policy if exists lonnsregister_upd on public.lonnsregister;
drop policy if exists lonnsregister_del on public.lonnsregister;

-- LEDERFLATE, IKKE NETTBRETT. Navn og timesats per person er
-- loennsopplysninger. Den delte nettbrettkontoen er ikke en person.
--
-- Aldri `for all`: `using` i en slik policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen - da trekkes skrivepolicyen inn i
-- hver leseplan. Funksjonskallene er pakket i `(select ...)` saa de blir
-- initplan og ikke evalueres per rad.
create policy lonnsregister_les on public.lonnsregister
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsregister_ins on public.lonnsregister
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsregister_upd on public.lonnsregister
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy lonnsregister_del on public.lonnsregister
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.lonnsregister to authenticated;
-- Standardrettighetene i schema public treffer hver ny tabell, og anon er
-- rollen bak den offentlige noekkelen i hver sidelast (0134).
revoke all on public.lonnsregister from anon;


-- ---------------------------------------------------------------------
-- SNAPSHOT: erstatt hele stasjonsmaaneden, atomisk
-- ---------------------------------------------------------------------
-- HVORFOR RPC OG IKKE DELETE + INSERT FRA KLIENTEN
--
-- To rundturer er to transaksjoner. Feiler den andre, staar registeret
-- TOMT for den stasjonsmaaneden - og et tomt register ser ut som «ingen
-- ansatte», ikke som «importen feilet». Her er begge setningene i én
-- funksjonskropp, altsaa én transaksjon: feiler innsettingen, rulles
-- slettingen tilbake og forrige snapshot staar uroert.
--
-- HVORFOR SNAPSHOT OG IKKE UPSERT
--
-- `lagreLonnsart` bruker upsert, og kommentaren der sier selv hvorfor det
-- er svakt: «En upsert fjerner ikke rader som ikke lenger produseres, saa
-- uten dette ville Sandras 57 957 blitt liggende for alltid.»
--
-- For registeret er det verre enn en gammel sum: en sluttet ansatts sats
-- som blir liggende kan prise en ANNENS timer, for evig. Snapshot er den
-- eneste semantikken der en som forsvinner fra fila ogsaa forsvinner fra
-- registeret.
--
-- ---------------------------------------------------------------------
-- `security definer` GAAR FORBI RLS. DERFOR VALIDERER DEN SELV.
--
-- Fire kontroller, og ingen av dem stoler paa klienten:
--
--   1  stasjonen maa vaere kallerens        `mine_stasjoner()`
--   2  rollen maa kunne skrive loennsdata   samme som policyen
--   3  maaneden maa vaere gyldig            regex, ikke fritekst
--   4  importjobben maa hoere til samme kjede som stasjonen
--
-- Og radene faar `stasjon_id` fra PARAMETEREN, aldri fra nyttelasten.
-- En rad som forsoeker aa skrive en annen stasjon kan ikke gjoere det -
-- feltet leses ikke.
-- ---------------------------------------------------------------------
create or replace function public.lonnsregister_snapshot(
  p_stasjon_id uuid,
  p_maaned     text,
  p_jobb_id    uuid,
  p_rader      jsonb
)
returns integer
language plpgsql
security definer
-- Tom search_path: en security definer-funksjon skal ikke kunne loeses
-- opp mot et skjema kalleren kontrollerer. Alt er derfor fullt kvalifisert.
set search_path = ''
as $$
declare
  n integer;
begin
  -- 1. TENANTPREDIKATET STAAR HER, ikke i en policy noen kan glemme.
  --    `mine_stasjoner()` er `returns setof uuid`, ikke en array -
  --    derfor `exists` mot funksjonen og ikke `unnest`.
  if p_stasjon_id is null or not exists (
    select 1 from public.mine_stasjoner() m where m = p_stasjon_id
  ) then
    raise exception 'Stasjonen finnes ikke, eller du har ikke tilgang til den.';
  end if;

  -- 2. Samme rollekrav som skrivepolicyen. Uten dette ville funksjonen
  --    vaert en vei rundt den.
  if (select public.gjeldende_rolle()) not in ('retailer_admin', 'butikksjef') then
    raise exception 'Rollen din kan ikke skrive loennsdata.';
  end if;

  -- 3. Maaneden er en noekkeldel. En ugyldig verdi ville laget et
  --    snapshot ingen leser finner igjen.
  if p_maaned is null or p_maaned !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Ugyldig maaned «%». Forventet yyyy-mm.', p_maaned;
  end if;

  -- 4. Importjobben er proveniens, og proveniens som peker paa en annen
  --    kjede er verre enn ingen. Null godtas - da er sporet bare ukjent.
  if p_jobb_id is not null and not exists (
    select 1
      from public.import_jobber j
      join public.stasjoner s on s.id = p_stasjon_id
     where j.id = p_jobb_id
       and j.retailer_id = s.retailer_id
  ) then
    raise exception 'Importjobben hoerer ikke til samme kjede som stasjonen.';
  end if;

  -- RYDD FOERST, SKRIV ETTERPAA - i samme transaksjon.
  delete from public.lonnsregister
   where stasjon_id  = p_stasjon_id
     and kilde_maaned = p_maaned;

  -- STASJON OG MAANED KOMMER FRA PARAMETRENE, IKKE FRA NYTTELASTEN.
  -- Det er det som gjoer at en rad ikke kan skrive seg til en annen
  -- stasjon enn scopet, uansett hva klienten sender.
  insert into public.lonnsregister
    (stasjon_id, kilde_maaned, ansatt_nr, navn, timesats, import_jobb_id)
  select
    p_stasjon_id,
    p_maaned,
    r.ansatt_nr,
    r.navn,
    r.timesats,
    p_jobb_id
  from jsonb_to_recordset(coalesce(p_rader, '[]'::jsonb))
    as r(ansatt_nr text, navn text, timesats numeric);

  get diagnostics n = row_count;
  return n;
end;
$$;

comment on function public.lonnsregister_snapshot(uuid, text, uuid, jsonb) is
  'Erstatter registersnapshotet for én stasjon og maaned, atomisk. '
  'Validerer tenant, rolle, maaned og importjobb selv - security definer '
  'gaar forbi RLS. Radenes stasjon og maaned tas fra parametrene, aldri '
  'fra nyttelasten.';

revoke all on function public.lonnsregister_snapshot(uuid, text, uuid, jsonb) from public;
revoke all on function public.lonnsregister_snapshot(uuid, text, uuid, jsonb) from anon;
grant execute on function public.lonnsregister_snapshot(uuid, text, uuid, jsonb) to authenticated;


-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- En migrasjon som lykkes uten aa si fra, ser ut som en som feilet.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'lonnsregister')             as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'lonnsregister'
      and grantee = 'anon')                                                  as anon_grants,
  (select count(*) from pg_indexes
    where schemaname = 'public' and tablename = 'lonnsregister')             as indekser,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'lonnsregister_snapshot')    as rpc,
  (select c.relrowsecurity from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relname = 'lonnsregister')             as rls_paa;
