-- =====================================================================
-- 0219: basisvakt - Easy@Works arbeidstidsobservasjon, periodisert
-- =====================================================================
--
-- SOESTEREN TIL 0218. `lonnsregister` bevarer hva Easy@Work sa om en
-- PERSON i en stasjonsmaaned; denne bevarer hva Easy@Work sa om ARBEID
-- i den samme stasjonsmaaneden. Samme form, samme snapshotsemantikk,
-- samme husmoenster.
--
-- ---------------------------------------------------------------------
-- HVORFOR IKKE `stempling`
--
-- `stempling` er Sentiqas egen arbeidstidsmodell, med parallellkjoering
-- mot nettbrettet og `v_stempling_aktiv` som velger kilde per stasjon.
-- Den svarer paa «hvem sto i butikken». Denne svarer paa «hva sa
-- Easy@Work om loennsgrunnlaget for arbeidstid».
--
-- De faar lov til aa vaere uenige, og forskjellen skal MAALES, ikke
-- antas bort. `stempling` mangler dessuten to ting loennsmotoren
-- trenger og som ikke kan legges til uten aa endre en modell vi ikke
-- skal roere:
--
--   fra_dato   datoen arbeidet BEGYNTE. Maalt: 28 doegnkryssende vakter
--              i 8 069 rader, herav 13 av 193 paa Laguneparken august
--              (6,7 %). Uten den faar vakten feil ukedag, altsaa feil
--              loerdagstillegg.
--   Lengde     Easy@Works eget timetall. `stempling.minutter` ER den,
--              ganget opp og stolt blindt paa: Boenes 2025-12-13 ligger
--              inne med 25,82 timer for en vakt 09:10-11:00.
--
-- ---------------------------------------------------------------------
-- NOEKKELEN ER `fra_dato`, IKKE FORRETNINGSDATOEN
--
-- Dette er den dyreste feilen i denne modellen, og den er gjort én gang
-- allerede. Med forretningsdatoen som radnoekkel forsvant 0,93 ekte
-- timer paa Dale 31. juli - to vakter som begge starter 00:00 paa hver
-- sin faktiske dato - og avviket gikk fra 1,045 % til 0,980 %. Tallet
-- ble BEDRE fordi data ble slettet.
--
-- Maalt over alle aatte kontrollfilene: forretningsdatoen som noekkel
-- ville kollidert paa 10 rader. `fra_dato` kolliderer paa 2, og begge
-- er ekte dobbeltstemplinger som skal bevares (se under).
--
-- MERK at `stempling`s unike indeks (0088) har noeyaktig den gale
-- formen. Den lagrer nettbrettdata, som ikke har denne fasongen.
--
-- ---------------------------------------------------------------------
-- DOBBELTSTEMPLINGER BEVARES, DE SLAAS IKKE SAMMEN
--
-- Maalt: to kollisjoner i 8 069 rader, begge samme moenster - en
-- stempling paa NULL minutter rett foran den ekte vakten:
--
--   Boenes        1009  2025-04-03 05:00  ->  05:00 (0 min) og 13:00 (480 min)
--   Laguneparken  1104272 2026-08-28 23:19 -> 23:19 (0 min) og 07:00 (461 min)
--
-- `utenDubletter` i `stempling.ts` beholder den lengste. Det er riktig
-- for den modellen, men denne tabellen skal bevare det Easy@Work
-- FAKTISK sa. Derfor baerer den unike noekkelen ogsaa `til_tid` og
-- `betalt`, saa begge radene faar plass. Motoren dedupliserer ved
-- lesing og TELLER det den slaar sammen - `Arbeidsstedskost.dubletter`.
--
-- Byte-identiske rader finnes ikke i noen av filene (maalt: 0). Skulle
-- de dukke opp, slaas de sammen av importoeren FOER innsending, og
-- antallet sies i notatet - ellers ville hele maanedens snapshot feilet
-- paa den unike noekkelen.
--
-- ---------------------------------------------------------------------
-- EN AVVIST RAD FORSVINNER IKKE
--
-- `avvik_grunn` er null for en brukbar vakt. De to andre verdiene er
-- Easy-data vi ikke kan bruke, og som maa vaere SYNLIGE for at
-- datagrunnlaget senere skal kunne si `minimum`:
--
--   `lengde`     «Lengde» og klokkeslettene kan ikke forenes. Maalt: 1
--                rad av 8 069 - Boenes 2025-12-13, nr 1009, 09:10-11:00
--                med Lengde 25,82. Den skal IKKE «rettes» til 1,83 og
--                kalles sannhet. Den skal fram til et menneske.
--   `lokasjon`   raden mangler arbeidssted. Maalt: 0 av 8 069.
--
-- En rad med `avvik_grunn` skal aldri prises. Den lagres under filas
-- stasjon fordi den maa ligge et sted for aa bli sett - det er et
-- rapporteringsvalg, ikke en kostnadsattribusjon, og et flagget avvik
-- kan ikke bli til kroner noe sted.
-- =====================================================================

create table if not exists public.basisvakt (
  id             uuid primary key default gen_random_uuid(),
  stasjon_id     uuid not null references public.stasjoner(id) on delete cascade,
  -- Maaneden FORRETNINGSDATOEN faller i. Det er slik kronefila
  -- grupperer, og de to maa vaere enige for at maalingen skal bety noe.
  kilde_maaned   text not null check (kilde_maaned ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  ansatt_nr      text not null,
  ansatt_navn    text not null,
  -- Forretningsdatoen: den Easy@Work foerer vakten paa.
  dato           date not null,
  -- Datoen arbeidet faktisk begynte. Lik `dato` for alt annet enn
  -- doegnkryssende vakter.
  fra_dato       date not null,
  fra_tid        time not null,
  til_tid        time not null,
  -- INTERVALLET, regnet av fra_dato + klokkeslettene. Det er dette
  -- motoren priser i dag.
  minutter       integer not null check (minutter >= 0),
  -- EASYS EGET TIMETALL, ubehandlet. Den er den mer presise av de to -
  -- klokkeslettene er kuttet til hele minutt - og det er den kronefila
  -- stemmer med. Lagres ved siden av, ikke i stedet for.
  lengde_timer   numeric,
  -- Raa `Type`: «Betalt tid», «Ubetalt tid», «Pause». `betalt` er
  -- utledet av den; begge bevares saa utledningen kan etterproeves.
  type           text not null,
  betalt         boolean not null,
  -- Arbeidsstedet SLIK RADEN OPPGIR DET. Hele grunnen til at fila
  -- finnes: den kan vaere en annen stasjon enn hvis fil det er.
  lokasjon       text not null,
  -- null = brukbar vakt. Se hodet.
  avvik_grunn    text check (avvik_grunn is null or avvik_grunn in ('lengde', 'lokasjon')),
  import_jobb_id uuid references public.import_jobber(id) on delete set null,
  opprettet_tid  timestamptz not null default now(),
  -- BRED MED VILJE. Motorens dedupnoekkel er
  -- (lokasjon, nr, fra_dato, fra_tid); den smalere formen ville avvist
  -- den ekte dobbeltstemplingen paa Boenes 1009. `til_tid` og `betalt`
  -- gjoer at begge radene faar plass, og motoren teller sammenslaaingen
  -- ved lesing i stedet for at basen skjuler den.
  unique (stasjon_id, kilde_maaned, ansatt_nr, fra_dato, fra_tid, til_tid, betalt)
);

-- Oppslaget motoren gjoer: gi meg arbeidstiden for én stasjon og maaned.
-- Den unike indeksen daekker (stasjon, maaned, ...) og brukes av den, saa
-- ingen egen indeks trengs for det.
--
-- INGEN INDEKS PAA ansatt_nr. `lonnsregister` har en fordi satsoppslaget
-- gaar paa tvers av stasjoner - Carmens sats kommer fra Lones fil og
-- brukes paa Boenes. Arbeidstiden gaar aldri paa tvers: en vakt hoerer
-- til stasjonen den ble jobbet paa. En spekulativ indeks her ville vaert
-- vedlikehold uten en leser.

comment on table public.basisvakt is
  'Hva easy@work Basis Export sa om arbeid paa en stasjon i en maaned. '
  'Kildeobservasjon, ikke Sentiqas egen stempling - se public.stempling.';
comment on column public.basisvakt.kilde_maaned is
  'Maaneden FORRETNINGSDATOEN faller i. Snapshotnoekkel.';
comment on column public.basisvakt.fra_dato is
  'Datoen arbeidet begynte. Ulik dato paa doegnkryssende vakter, og det '
  'er DEN tilleggsfordelingen maa bruke - ellers faar vakten feil ukedag.';
comment on column public.basisvakt.minutter is
  'Intervallet fra klokkeslettene. Sammenlign med lengde_timer.';
comment on column public.basisvakt.lengde_timer is
  'Easy@Works eget timetall, ubehandlet. Avviker den fra minutter, er '
  'avvik_grunn satt til lengde og raden skal aldri prises.';
comment on column public.basisvakt.lokasjon is
  'Arbeidsstedet raden oppgir. Kan vaere en annen stasjon enn filas.';
comment on column public.basisvakt.avvik_grunn is
  'null = brukbar. lengde/lokasjon = Easy-data vi ikke kan bruke, '
  'bevart for at datagrunnlaget skal kunne si minimum.';


-- ---------------------------------------------------------------------
-- RLS - samme moenster som 0218
-- ---------------------------------------------------------------------
alter table public.basisvakt enable row level security;

drop policy if exists basisvakt_les on public.basisvakt;
drop policy if exists basisvakt_ins on public.basisvakt;
drop policy if exists basisvakt_upd on public.basisvakt;
drop policy if exists basisvakt_del on public.basisvakt;

-- TILGANGSMODELLEN, SKREVET UT
--
--   Retailer ser kjeden. Butikken ser seg selv. Nettbrettet ser bare
--   sin stasjon - og bare data den faktisk trenger.
--
-- STASJONSTILGANG OG DATATILGANG ER TO FORSKJELLIGE TING. At nettbrettet
-- har tilgang til stasjon X betyr ikke at det skal lese raa `basisvakt`
-- med navngitte ansatte og arbeidstid. Derfor staar det TO vilkaar i
-- hver policy, og det andre er ikke pynt:
--
--   stasjon_id in (select mine_stasjoner())   HVILKE stasjoner
--   gjeldende_rolle() in (...)                HVILKE DATA
--
-- `mine_stasjoner()` (0077) baerer allerede hele stasjonsmodellen, og
-- den skal ikke gjenoppfinnes her:
--
--   retailer_admin        alle ikke-slettede stasjoner i EGEN retailer
--   butikksjef            radene i butikksjef_stasjoner for auth.uid(),
--                         altsaa bare tildelte - flere er stoettet
--   butikkbruker_tablet   samme tildelingstabell, altsaa egen stasjon
--   plattform_redaktor    ingenting; den leser aldri forretningsdata
--
-- Rollekravet er det som stenger NETTBRETTET ute, ikke stasjonslista:
-- `mine_stasjoner()` ville gitt nettbrettet sin egen stasjon. Uten det
-- andre vilkaaret hadde den delte stasjonskontoen kunnet lese hvem som
-- jobbet naar, med navn - og senere hva de koster.
--
-- `stempling` har med vilje en bredere lesepolicy (enhver `authenticated`
-- med stasjonstilgang). Den er nettbrettets EGEN tabell og maa vaere det.
-- Denne er en loennskontrollkilde. Smalt er reversibelt; bredt er det
-- ikke. Trenger nettbrettet dette en gang, skal det vaere et skrevet
-- produktbehov og en smal funksjon - ikke en utvidet policy.
--
-- Tenantgrensen haandheves HER, i basen, ikke i UI-et. En kjede kan
-- aldri se en annens rader: retailer_admin er bundet av
-- gjeldende_retailer_id(), og butikksjef/nettbrett av tildelingsraden.
--
-- Aldri `for all`: `using` i en slik policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen - da trekkes skrivepolicyen inn i
-- hver leseplan. Funksjonskallene er pakket i `(select ...)` saa de blir
-- initplan og ikke evalueres per rad.
create policy basisvakt_les on public.basisvakt
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy basisvakt_ins on public.basisvakt
  for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy basisvakt_upd on public.basisvakt
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

create policy basisvakt_del on public.basisvakt
  for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.basisvakt to authenticated;
-- Standardrettighetene i schema public treffer hver ny tabell, og anon er
-- rollen bak den offentlige noekkelen i hver sidelast (0134).
revoke all on public.basisvakt from anon;


-- ---------------------------------------------------------------------
-- SNAPSHOT: erstatt hele stasjonsmaaneden, atomisk
-- ---------------------------------------------------------------------
-- Samme begrunnelse som `lonnsregister_snapshot`: to rundturer er to
-- transaksjoner, og feiler den andre staar maaneden TOM - og en tom
-- maaned ser ut som «ingen jobbet», ikke som «importen feilet».
--
-- ÉN MAANED KAN IKKE SLETTE EN ANNEN. Port 5 avviser enhver rad hvis
-- forretningsdato faller utenfor `p_maaned`. En fil paa nitten maaneder
-- kalles nitten ganger, og hver av dem kan bare roere sin egen maaned.
-- Uten den porten ville en feil i grupperingen paa klientsiden kunne
-- toemme en maaned ved aa skrive den med en annen maaneds rader.
--
-- MAANEDER FILA IKKE NEVNER ROERES IKKE. Importoeren kaller bare for de
-- maanedene som faktisk har rader. Maalt: ingen av de aatte filene har
-- hull i spennet sitt - men en fil eksportert med et filter KAN ha det,
-- og da ville «slett hele spennet» tatt en maaned fila ikke uttaler seg
-- om. Aa toemme en maaned skal vaere en handling, ikke en bivirkning.
create or replace function public.basisvakt_snapshot(
  p_stasjon_id uuid,
  p_maaned     text,
  p_jobb_id    uuid,
  p_rader      jsonb
)
returns integer
language plpgsql
security definer
-- Tom search_path: en security definer-funksjon skal ikke kunne loeses
-- opp mot et skjema kalleren kontrollerer. Alt er fullt kvalifisert.
set search_path = ''
as $$
declare
  n          integer;
  v_fra      date;
  v_til      date;
  v_utenfor  integer;
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
    raise exception 'Rollen din kan ikke skrive arbeidstidsdata.';
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

  v_fra := to_date(p_maaned || '-01', 'YYYY-MM-DD');
  v_til := (v_fra + interval '1 month')::date;

  -- 5. INGEN RAD UTENFOR MAANEDEN. Dette er porten som gjoer at en
  --    flermaanedsfil ikke kan la én maaned skrive inn i en annens
  --    snapshot. Den teller foerst og kaster - en delvis innsetting
  --    ville vaert verre enn ingen.
  select count(*) into v_utenfor
    from jsonb_to_recordset(coalesce(p_rader, '[]'::jsonb))
      as r(dato date)
   where r.dato is null or r.dato < v_fra or r.dato >= v_til;

  if v_utenfor > 0 then
    raise exception
      '% rad(er) har forretningsdato utenfor %. Snapshotet skrives per maaned.',
      v_utenfor, p_maaned;
  end if;

  -- RYDD FOERST, SKRIV ETTERPAA - i samme transaksjon.
  delete from public.basisvakt
   where stasjon_id   = p_stasjon_id
     and kilde_maaned = p_maaned;

  -- STASJON OG MAANED KOMMER FRA PARAMETRENE, IKKE FRA NYTTELASTEN.
  -- Det er det som gjoer at en rad ikke kan skrive seg til en annen
  -- stasjon enn scopet, uansett hva klienten sender. `lokasjon` er
  -- derimot radens egen - den er hele poenget med kilden.
  insert into public.basisvakt
    (stasjon_id, kilde_maaned, ansatt_nr, ansatt_navn, dato, fra_dato,
     fra_tid, til_tid, minutter, lengde_timer, type, betalt, lokasjon,
     avvik_grunn, import_jobb_id)
  select
    p_stasjon_id,
    p_maaned,
    r.ansatt_nr,
    r.ansatt_navn,
    r.dato,
    r.fra_dato,
    r.fra_tid,
    r.til_tid,
    r.minutter,
    r.lengde_timer,
    r.type,
    r.betalt,
    r.lokasjon,
    r.avvik_grunn,
    p_jobb_id
  from jsonb_to_recordset(coalesce(p_rader, '[]'::jsonb))
    as r(ansatt_nr text, ansatt_navn text, dato date, fra_dato date,
         fra_tid time, til_tid time, minutter integer, lengde_timer numeric,
         type text, betalt boolean, lokasjon text, avvik_grunn text);

  get diagnostics n = row_count;
  return n;
end;
$$;

comment on function public.basisvakt_snapshot(uuid, text, uuid, jsonb) is
  'Erstatter arbeidstidssnapshotet for én stasjon og maaned, atomisk. '
  'Validerer tenant, rolle, maaned, importjobb OG at hver rad hoerer til '
  'maaneden - security definer gaar forbi RLS. Radenes stasjon og maaned '
  'tas fra parametrene, aldri fra nyttelasten.';

revoke all on function public.basisvakt_snapshot(uuid, text, uuid, jsonb) from public;
revoke all on function public.basisvakt_snapshot(uuid, text, uuid, jsonb) from anon;
grant execute on function public.basisvakt_snapshot(uuid, text, uuid, jsonb) to authenticated;


-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- En migrasjon som lykkes uten aa si fra, ser ut som en som feilet.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'basisvakt')            as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'basisvakt'
      and grantee = 'anon')                                             as anon_grants,
  (select count(*) from pg_indexes
    where schemaname = 'public' and tablename = 'basisvakt')            as indekser,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'basisvakt_snapshot')   as rpc,
  (select c.relrowsecurity from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relname = 'basisvakt')            as rls_paa;
