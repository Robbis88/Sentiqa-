-- =====================================================================
-- 0221: a1_registeroppslag - kryss-stasjons registerkandidater, smalt
-- =====================================================================
--
-- ADDITIV. En funksjon. Ingen tabell, ingen policy, ingen grant paa noe
-- eksisterende, ingen rad roert. Angring er en linje, nederst.
--
-- ---------------------------------------------------------------------
-- HVA DEN LOESER
--
-- `lonnsregister_les` (0218) krever
-- `stasjon_id in (select public.mine_stasjoner())`. En butikksjef paa
-- Boenes kan derfor IKKE lese Lones registerrad - og Carmen arbeidet
-- 79,82 timer paa Boenes i juli 2026 med sin eneste registerrad paa
-- Lone.
--
-- Konsekvensen er maalt og alvorlig: butikksjefen ville sett Carmen som
-- uslaatt, timene hennes ville forblitt uprisede, og Boenes' 503 ville
-- vaert for lav - mens eieren saa det riktige tallet, av samme data.
-- For lite loenn er for stort groent loennsrom. To roller, ett datasett,
-- to svar, og det ene er farligere enn det andre.
--
-- ---------------------------------------------------------------------
-- DET AVGJOERENDE GREPET: `ansatt_nr` ER IKKE ET ARGUMENT
--
-- Numrene utledes INNE i funksjonen, fra `basisvakt` paa de autoriserte
-- arbeidsstasjonene i samme maaned.
--
-- Tok funksjonen imot numre, ville den vaert et orakel: "finnes 118 i
-- Lones register?" - besvart av hvem som helst med hvilken som helst
-- stasjon. Enumereringen ville vaert MULIG og maattet filtreres bort.
-- Slik den er, er den strukturelt umulig: du kan ikke spoerre om en
-- person som ikke har arbeidet hos deg.
--
-- Det er grunnen til at dette moensteret er trygt for loennsdata - ikke
-- at `0165` og `0167` finnes.
--
-- RESTRISIKOEN, SAGT RETT UT: den som kan skrive `basisvakt` paa sin
-- egen stasjon kan i prinsippet laste opp en oppdiktet Basis Export med
-- et nummer og slik naa navn og sats for den personen. Det krever en
-- forfalsket fil, og tenantpredikatet under begrenser det til EGEN
-- kjede. Det er en bevisst avveining, ikke en oversett flate.
--
-- ---------------------------------------------------------------------
-- TO UAVHENGIGE TENANTGRENSER
--
--   1  hver forespurt stasjon maa ligge i `mine_stasjoner()`
--   2  hver returnert registerrad maa tilhoere `gjeldende_retailer_id()`
--
-- Begge, ikke en. `mine_stasjoner()` binder bare ARBEIDSSTASJONENE.
-- Registerraden naas via `ansatt_nr`, og B2a beviste allerede at et
-- nummer kan peke paa to personer - 1018 er Marietta paa Boenes og
-- Andre Fjoerstad paa Varden. Uten (2) kunne et kolliderende nummer i en
-- annen kjede gi en rad. ET ANSATTNUMMER ER IKKE EN TENANTKOBLING.
--
-- ---------------------------------------------------------------------
-- ROLLEKRAVET MAA STAA EKSPLISITT
--
-- `mine_stasjoner()` (0077) har nettbrettet i unionen:
--
--   where (select public.gjeldende_rolle())
--         in ('butikksjef', 'butikkbruker_tablet')
--
-- Stasjonsmedlemskap alene ville derfor sluppet NETTBRETTET inn paa
-- loennsdata. Det er husregelen "stasjonstilgang gir ikke datatilgang",
-- og her er den ikke teoretisk. `butikkbruker_tablet` og
-- `plattform_redaktor` avvises eksplisitt.
--
-- ---------------------------------------------------------------------
-- 42501, IKKE ET TOMT SVAR
--
-- `0165` og `0167` svarer TOMT naar stasjonen ikke er autorisert. For
-- denne funksjonen er det galt: et tomt svar er ikke til aa skille fra
-- "personen har ingen registerrad", og den stillheten gir en for lav
-- loennskost. En exception kan ikke forveksles med data.
--
--   []      legitim foresporsel uten treff
--   42501   foresporselen var ikke autorisert
--
-- De to tilstandene blandes aldri. En BLANDET liste
-- [autorisert, uautorisert] feiler HELE kallet - delvis suksess er
-- nettopp formen der noen proever seg fram til hva som finnes.
--
-- `using errcode` er ikke pynt: et bart `raise exception` gir `P0001`,
-- og bare `42501` teller som en godkjent sikkerhetsavvisning.
--
-- ---------------------------------------------------------------------
-- DEN AVGJOER ALDRI IDENTITET
--
-- En rad per (stasjon_id, ansatt_nr). Ingen `distinct on`, ingen
-- `order by ... limit 1`, ingen navnesammenligning, ingen "beste"
-- kandidat. Finnes 1018 i to stasjoners register samme maaned, kommer
-- BEGGE radene ut, og `avgjorIdentitet` svarer `motstrid('kollisjon')`.
--
-- Det ville vaert lett aa "hjelpe" her ved aa velge den som ligner
-- navnet - og det ville gjort navnet til en positiv noekkel i et lag
-- uten tester og uten injeksjoner. Regelen "nummeret foreslaar, navnet
-- nekter" bor i TypeScript, med tretten injeksjoner rundt seg.
-- =====================================================================

create or replace function public.a1_registeroppslag(
  p_maaned       text,
  p_stasjon_ider uuid[]
)
returns table (
  stasjon_id        uuid,
  kilde_maaned      text,
  ansatt_nr         text,
  navn              text,
  timesats          numeric,
  betalingsfrekvens text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  n_uautorisert integer;
begin
  -- 1. MAANEDEN ER EN NOEKKELDEL. En sats hoerer til en maaned.
  if p_maaned is null or p_maaned !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Ugyldig maaned "%". Forventet yyyy-mm.', p_maaned
      using errcode = '22023';
  end if;

  -- 2. EN TOM LISTE ER EN FEIL, IKKE ET TOMT SVAR. En kaller som ber om
  -- null stasjoner har en feil, og et stille [] ville skjult den.
  if p_stasjon_ider is null or array_length(p_stasjon_ider, 1) is null then
    raise exception 'Ingen arbeidsstasjoner oppgitt.'
      using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_stasjon_ider) as s(id) where s.id is null) then
    raise exception 'null i stasjonslista.'
      using errcode = '22023';
  end if;

  -- 3. ROLLEN. Se hodet: stasjonsmedlemskap alene slipper nettbrettet
  -- inn, saa dette er ikke en dublett av steg 4.
  if (select public.gjeldende_rolle()) not in ('retailer_admin', 'butikksjef') then
    raise exception 'Rollen din kan ikke lese loennsregisteret.'
      using errcode = '42501';
  end if;

  -- 4. HVER ENESTE forespurte stasjon, ikke bare de som tilfeldigvis
  -- passerer. Alt-eller-ingenting: en blandet liste gir ingen data for
  -- den autoriserte halvparten heller.
  --
  -- `mine_stasjoner()` er `returns setof uuid`, ikke en array - derfor
  -- `exists` mot funksjonen og ikke `unnest` (samme som 0167).
  select count(*) into n_uautorisert
    from unnest(p_stasjon_ider) as s(id)
   where not exists (
     select 1 from public.mine_stasjoner() m where m = s.id
   );
  if n_uautorisert > 0 then
    raise exception 'Ikke tilgang til % av de forespurte stasjonene.', n_uautorisert
      using errcode = '42501';
  end if;

  -- 5. KANDIDATENE.
  --
  -- `distinct` paa stasjonene gjoer [Boenes, Boenes] identisk med
  -- [Boenes] - en array-input skal ikke kunne multiplisere en join.
  -- `distinct` paa numrene av samme grunn.
  --
  -- Ingen `betalt`-filtrering: ogsaa en pauserad er en observasjon av at
  -- personen var paa stasjonen. Aa kreve betalt tid ville utelatt en
  -- person hvis eneste rader var ubetalte, og det er en datamangel vi
  -- ikke oensker aa skjule bak en autorisasjonsregel.
  return query
  with autoriserte as (
    select distinct s.id as sid from unnest(p_stasjon_ider) as s(id)
  ),
  numre as (
    select distinct v.ansatt_nr as nr
      from public.basisvakt v
      join autoriserte a on a.sid = v.stasjon_id
     where v.kilde_maaned = p_maaned
  )
  select
    r.stasjon_id,
    r.kilde_maaned,
    r.ansatt_nr,
    r.navn,
    r.timesats,
    r.betalingsfrekvens
  from public.lonnsregister r
  join public.stasjoner st on st.id = r.stasjon_id
  where r.kilde_maaned = p_maaned
    -- TENANTPREDIKATET. Se hodet: et ansattnummer er ikke en
    -- tenantkobling, saa denne linja er ikke overfloedig ved siden av
    -- stasjonsautorisasjonen over.
    and st.retailer_id = (select public.gjeldende_retailer_id())
    and exists (select 1 from numre n where n.nr = r.ansatt_nr);
end;
$$;

comment on function public.a1_registeroppslag(text, uuid[]) is
  'Registerkandidatene A1 trenger for personer som FAKTISK arbeidet paa '
  'en autorisert stasjon i maaneden - ogsaa naar registerraden ligger paa '
  'en annen stasjon. Tar ingen ansatt_nr: numrene utledes inne i '
  'funksjonen, saa den kan ikke brukes til aa spoerre om en person som '
  'ikke har arbeidet hos kalleren. Returnerer KANDIDATER og avgjoer aldri '
  'identitet - flere rader paa samme nummer kommer ut som flere rader. '
  'Se migrasjon 0221.';

-- ANON SKAL IKKE HA EXECUTE. Postgres gir `execute` til PUBLIC som
-- standard, og `anon` er rollen bak den offentlige noekkelen i hver
-- sidelast (0134). Uten denne linja ville funksjonen vaert kallbar av en
-- utlogget klient - rollesjekken ville stoppet den, men vernet skal ikke
-- hvile paa at funksjonen husker aa sjekke.
revoke all on function public.a1_registeroppslag(text, uuid[]) from public, anon;
grant execute on function public.a1_registeroppslag(text, uuid[]) to authenticated;


-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- En migrasjon som lykkes uten aa si fra, ser ut som en som feilet.
select
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'a1_registeroppslag')   as funksjonen,
  (select p.prosecdef from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'a1_registeroppslag')   as security_definer,
  (select array_to_string(p.proconfig, ', ') from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'a1_registeroppslag')   as search_path,
  (select count(*) from information_schema.role_routine_grants
    where routine_schema = 'public' and routine_name = 'a1_registeroppslag'
      and grantee = 'authenticated')                                   as grant_authenticated,
  (select count(*) from information_schema.role_routine_grants
    where routine_schema = 'public' and routine_name = 'a1_registeroppslag'
      and grantee in ('anon', 'PUBLIC'))                               as grant_anon_skal_vaere_0,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'lonnsregister')       as policyer_uendret_4;


-- =====================================================================
-- ANGRE
-- =====================================================================
-- drop function if exists public.a1_registeroppslag(text, uuid[]);
