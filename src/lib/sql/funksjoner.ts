// =====================================================================
// Hvilke funksjoner SKAL finnes i basen?
//
// `0075_malekort_stasjoner.sql` var aldri kjørt mot produksjon. Trolig i
// månedsvis. Ingenting sa fra: `malekort_stasjoner()` fantes bare ikke,
// og `/maaling` viste «Ingen stasjoner.» — en setning som er sann, men
// som beskriver noe helt annet enn det som skjedde.
//
// ---------------------------------------------------------------------
// HVORFOR DETTE FALT MELLOM STOLENE
//
// `tenant_dekning.sql` starter fra `pg_class` og krever at hver tabell
// står i kontrakten. `rls_vakthund.sql` går gjennom policyene. Begge
// spør om ting som FINNES i basen.
//
// En manglende funksjon finnes ikke, og blir derfor ikke sett av noen av
// dem. Den oppdages først når en flate kaller den — og der svelges
// feilen ofte, fordi `const { data } = await supabase.rpc(...)` er
// billigere å skrive enn å sjekke `error`.
//
// **Denne vakten går motsatt vei: fra migrasjonene til basen.** Den
// spør ikke «er alt i basen forklart», men «er alt som er lovet
// levert».
//
// ---------------------------------------------------------------------
// HVA DEN IKKE SER
//
// En funksjon som opprettes DYNAMISK — `execute format('create function
// …')` — står ikke som tekst i migrasjonen og telles ikke. Det finnes
// ingen slike i dag, og en ny ville uansett vært verdt en kommentar.
//
// Den skiller heller ikke overlaster: to funksjoner med samme navn og
// ulike argumenter er ett navn her. Det er med vilje — vakten er der for
// å fange en funksjon som mangler HELT, ikke for å granske signaturer.
// En navnekollisjon gir falsk trygghet i teorien, og en falsk positiv
// lærer folk å se bort fra rødt.
// =====================================================================
import { readdirSync, readFileSync } from 'node:fs'

/** `create [or replace] function public.navn(` */
const OPPRETTET = /create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-z0-9_]+)\s*\(/gi

/**
 * `drop function [if exists] public.navn`
 *
 * Uten denne ville en funksjon som med vilje ble fjernet stått som et
 * evig funn. `0104` dropper og erstatter; rekkefølgen avgjør.
 */
const DROPPET = /drop\s+function\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi

/**
 * En kommentar er ikke en setning.
 *
 * Migrasjonene siterer hverandre i kommentarer — `0138` siterer `0112`,
 * `0150` nevner `0110`. Uten strippingen ville en omtalt funksjon blitt
 * krevd som om den var opprettet. Samme felle som `fratattAuthenticated`
 * gikk i.
 */
function utenKommentarer(sql: string): string {
  return sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*/g, '')
}

/**
 * Funksjonsnavnene migrasjonene lover, i filrekkefølge.
 *
 * Sortert og uten duplikater, så fasitfila blir stabil mellom kjøringer.
 */
export function lesFil(sql: string, levende: Set<string>): void {
  const ren = utenKommentarer(sql)
  // DROP FØRST, så en fil som dropper og gjenoppretter i samme slengen
  // ender med funksjonen levende — det er den vanlige formen.
  for (const m of ren.matchAll(DROPPET)) levende.delete(m[1].toLowerCase())
  for (const m of ren.matchAll(OPPRETTET)) levende.add(m[1].toLowerCase())
}

export function lovedeFunksjoner(mappe: string): string[] {
  const levende = new Set<string>()
  for (const fil of readdirSync(mappe).filter((f) => f.endsWith('.sql')).sort()) {
    lesFil(readFileSync(`${mappe}/${fil}`, 'utf8'), levende)
  }
  return [...levende].sort()
}

const ADVARSEL = `-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/migrations/*.sql
-- Regenerer: OPPDATER_FUNKSJONER=1 npx vitest run src/lib/sql
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet.`

/** Katalogsjekken, som SQL. Trygg i produksjon — leser kun `pg_proc`. */
export function genererFunksjonssjekk(navn: string[]): string {
  const liste = navn.map((n) => `    '${n}'`).join(',\n')

  return `${ADVARSEL}
--
-- ER ALT SOM ER LOVET LEVERT?
--
-- Migrasjonene kjoeres for haand, og det finnes ingen historikk-tabell.
-- \`0075_malekort_stasjoner.sql\` var aldri kjoert mot produksjon -
-- trolig i maanedsvis - og ingenting sa fra. Funksjonen fantes bare
-- ikke, og flata som kalte den svelget feilen og viste «Ingen
-- stasjoner.»
--
-- De andre vaktene gaar fra basen til kontrakten: de spoer om alt som
-- FINNES er forklart. Denne gaar motsatt vei, og det er hele poenget -
-- en funksjon som mangler finnes ikke, og blir derfor ikke sett av dem.
--
-- Kjoeres trygt naar som helst. Leser bare katalogen.

do $$
declare
  forventet text[] := array[
${liste}
  ];
  mangler text[];
  funnet  int;
begin
  select count(*) into funnet
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = any(forventet);

  -- KANARIFUGL. Finner den ingen av dem, maaler den ingenting - og
  -- «ingen mangler» ville sett noeyaktig ut som «alt er paa plass».
  -- Det skjer hvis noen bytter skjema, eller hvis lista blir tom.
  if funnet = 0 then
    raise exception
      'VAKTEN MAALER INGENTING: fant ingen av de % forventede funksjonene i public. Feil skjema, eller tom liste?',
      coalesce(array_length(forventet, 1), 0);
  end if;

  select array_agg(f order by f) into mangler
  from unnest(forventet) as f
  where not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = f
  );

  if mangler is not null then
    raise exception
      'MANGLER % av % funksjoner - en migrasjon er ikke kjoert: %',
      array_length(mangler, 1),
      array_length(forventet, 1),
      array_to_string(mangler, ', ');
  end if;
end $$;

-- Kvittering. SQL Editor viser ikke \`raise notice\`, saa svaret maa
-- komme som en rad.
select 'OK'                                    as status,
       count(*)                                as funksjoner_i_public,
       ${navn.length}                          as forventet_av_migrasjonene
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';
`
}
