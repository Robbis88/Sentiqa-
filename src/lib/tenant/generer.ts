// =====================================================================
// Generatoren: kontrakt -> SQL.
//
// Rene funksjoner. Ingen filsystem, ingen base. Testen kaller dem og
// sammenligner med det som ligger i repoet.
// =====================================================================
import type { Kontrakt, Operasjon, Ressurs } from './kontrakt'
import { rekkevidde } from './kontrakt'

// --- Fasitverdenen ---------------------------------------------------
// Samme UUID-er som `rls_kanarifugl.sql` fra PORT 1. Kolliderende
// butikknummer og ansatt_nr med vilje — en test som består fordi
// radene tilfeldigvis er ulike, beviser ingenting.

const R = {
  A: 'aaaa0000-0000-4000-8000-000000000000',
  B: 'bbbb0000-0000-4000-8000-000000000000',
} as const

const S = {
  A1: 'a1110000-0000-4000-8000-000000000001',
  A2: 'a1110000-0000-4000-8000-000000000002',
  A3: 'a1110000-0000-4000-8000-000000000003',
  B1: 'b1110000-0000-4000-8000-000000000001',
  B2: 'b1110000-0000-4000-8000-000000000002',
} as const

type Stasjon = keyof typeof S
type Kjede = keyof typeof R

export type Identitet = {
  navn: string
  uid: string
  kjede: Kjede
  stasjoner: Stasjon[]
  rolle: 'owner' | 'manager' | 'tablet'
}

export const IDENTITETER: Identitet[] = [
  { navn: 'owner_A', uid: '00000000-0000-0000-0000-00000000a000', kjede: 'A', stasjoner: ['A1', 'A2', 'A3'], rolle: 'owner' },
  { navn: 'manager_A1', uid: '00000000-0000-0000-0000-00000000a001', kjede: 'A', stasjoner: ['A1'], rolle: 'manager' },
  { navn: 'manager_A12', uid: '00000000-0000-0000-0000-00000000a012', kjede: 'A', stasjoner: ['A1', 'A2'], rolle: 'manager' },
  { navn: 'tablet_A1', uid: '00000000-0000-0000-0000-00000000a101', kjede: 'A', stasjoner: ['A1'], rolle: 'tablet' },
  { navn: 'owner_B', uid: '00000000-0000-0000-0000-00000000b000', kjede: 'B', stasjoner: ['B1', 'B2'], rolle: 'owner' },
  { navn: 'manager_B1', uid: '00000000-0000-0000-0000-00000000b001', kjede: 'B', stasjoner: ['B1'], rolle: 'manager' },
  { navn: 'tablet_B1', uid: '00000000-0000-0000-0000-00000000b101', kjede: 'B', stasjoner: ['B1'], rolle: 'tablet' },
]

const KJEDENS_STASJONER: Record<Kjede, Stasjon[]> = {
  A: ['A1', 'A2', 'A3'],
  B: ['B1', 'B2'],
}

const ANNEN_KJEDE: Record<Kjede, Kjede> = { A: 'B', B: 'A' }

/**
 * Målene én identitet prøves mot.
 *
 * Hele egen kjede — det er der delmengden bor, og `manager_A12` mot A3
 * er hele grunnen til at dette ikke er «enda en 1-stasjonsbruker». Så
 * første stasjon i den andre kjeden, for kryss-retailer.
 */
export function maal(i: Identitet): Stasjon[] {
  return [...KJEDENS_STASJONER[i.kjede], KJEDENS_STASJONER[ANNEN_KJEDE[i.kjede]][0]]
}

/** Når identiteten denne stasjonen for denne operasjonen? */
export function tillatt(r: Ressurs, i: Identitet, op: Operasjon, s: Stasjon): boolean {
  const felt = i.rolle === 'owner' ? r.owner : i.rolle === 'manager' ? r.manager : r.tablet
  const rv = rekkevidde(felt, op, r.operasjoner)
  if (rv === 'none') return false
  if (rv === 'retailer') return KJEDENS_STASJONER[i.kjede].includes(s)
  // own_station / assigned_stations
  return i.stasjoner.includes(s)
}

// --- Små hjelpere for SQL-tekst --------------------------------------

const sitat = (s: string) => `'${s.replace(/'/g, "''")}'`

function fyll(mal: string, ctx: Record<string, string>): string {
  return mal.replace(/\{\{([a-z_:]+)\}\}/g, (_, n: string) => {
    if (!(n in ctx)) throw new Error(`Ukjent plassholder {{${n}}}`)
    return ctx[n]
  })
}

/** Kolonnen som identifiserer en rad. `id` naar ikke annet er sagt. */
function idKol(r: Ressurs): string {
  return r.id_kolonne ?? 'id'
}

/**
 * Den faste proberaden per stasjon, slik den faktisk ble skrevet.
 *
 * SAMMENSATTE NOEKLER MAA PEKES PAA MED VERDIENE SINE. `timesalg` har
 * ingen id-kolonne; raden identifiseres av (retailer_id, stasjon_id,
 * dato, time), og dato varierer per forsoek fordi noekkelen krever det.
 * Da kan ikke predikatet regnes ut fra kontrakten alene - det maa leses
 * av raden som ble seedet.
 */
const fastRad: Record<string, Partial<Record<Stasjon, Record<string, string>>>> = {}

/**
 * Predikatet som peker paa den faste proberaden.
 *
 * Med en id-kolonne er det `id = '<uuid>'` - noeyaktig som foer. Med
 * `id_kolonner` er det konjunksjonen av noekkelkolonnene, med verdiene
 * raden faktisk fikk.
 */
function radPredikat(r: Ressurs, s: Stasjon): string {
  if (!r.id_kolonner) return `${idKol(r)} = ${sitat(fastVerdi(r, s))}`
  const rad = fastRad[r.tabell]?.[s]
  if (!rad) throw new Error(`${r.tabell}: fast proberad for ${s} er ikke seedet enda`)
  return r.id_kolonner.map((k) => {
    const v = rad[k]
    if (v === undefined) {
      throw new Error(`${r.tabell}: id_kolonner nevner «${k}», men proberaden setter den ikke`)
    }
    return `"${k}" = ${v}`
  }).join(' and ')
}

/**
 * Uttrykket som peker paa den faste proberaden for en stasjon.
 *
 * Har tabellen en surrogatnokkel, er det den seedede uuid-en. Har den
 * ikke det - `bemanning_stasjon` har `stasjon_id` som primaernokkel og
 * INGEN `id` - peker vi paa stasjonen selv.
 */
function fastVerdi(r: Ressurs, s: Stasjon): string {
  return idKol(r) === 'id' ? seedId(`${r.tabell}:fast:${s}`) : S[s]
}

/** Deterministisk UUID for en seedet rad. Ingen Math.random. */
function seedId(nokkel: string): string {
  let h = 0
  for (const ch of nokkel) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  const hex = h.toString(16).padStart(8, '0')
  return `${hex}-0000-4000-8000-${h.toString(16).padStart(12, '0').slice(0, 12)}`
}

/** Kolonnene som bærer tenant, gitt scope. */
function tenantKolonner(r: Ressurs, kjede: Kjede, s: Stasjon): Record<string, string> {
  const ut: Record<string, string> = {}
  if (r.tenant_scope === 'retailer' || r.tenant_scope === 'retailer_and_station'
      || r.tenant_scope === 'retailer_or_station') {
    ut.retailer_id = sitat(R[kjede])
  }
  if (r.tenant_scope === 'station' || r.tenant_scope === 'retailer_and_station'
      || r.tenant_scope === 'retailer_or_station') {
    if (!r.tenant_kolonne) ut.stasjon_id = sitat(S[s])
  }
  return ut
}

/**
 * Forutsetninger som maa seedes, samlet mens matrisen genereres.
 *
 * TO PASS, og det er ikke elegant for elegansens skyld. `opplaering_utfort`
 * har `unique (periode_id, oppgave_id)` og `rutine_utforinger` har
 * `unique (rutine_id, dato)`. Seedes forutsetningene én gang per stasjon,
 * kolliderer hvert forsoek nummer to med det foerste - og en kollisjon er
 * 23505, ikke 42501. Den skjerpede `skriv_avvist` ville meldt det som
 * "avvist av FEIL grunn", altsaa roedt. Riktig, men unoedvendig.
 *
 * Derfor: hvert forsoek faar sine egne forutsetningsrader, og telleren
 * gjor dem unike. Foerst genereres kroppen, saa vet vi hva som maa seedes.
 */
let seedbehov: string[] = []
let teller = 0

function proberadSql(r: Ressurs, kjede: Kjede, s: Stasjon, unik: string): {
  kolonner: string[]; verdier: string[]
} {
  const n = teller++
  const ctx: Record<string, string> = {
    retailer: R[kjede], stasjon: S[s], unik,
    unik_dato: `date '2026-01-01' + ${n}`,
  }
  for (const linje of r.seed_ekstra ?? []) {
    const seedCtx: Record<string, string> = { retailer: R[kjede], stasjon: S[s], unik, n: String(n) }
    for (const m of linje.matchAll(/\{\{seed:([a-z_]+)\}\}/g)) {
      const id = seedId(`${r.tabell}:${m[1]}:${s}:${n}`)
      ctx[`seed:${m[1]}`] = id
      seedCtx[`seed:${m[1]}`] = id
    }
    seedbehov.push(`${fyll(linje, seedCtx)};`)
  }
  const felt = { ...tenantKolonner(r, kjede, s), ...r.proberad }
  const kolonner: string[] = []
  const verdier: string[] = []
  for (const [k, v] of Object.entries(felt)) {
    if (k.startsWith('$')) continue
    kolonner.push(k)
    verdier.push(fyll(v, ctx))
  }
  return { kolonner, verdier }
}

// --- Filhode ---------------------------------------------------------

const ADVARSEL = `-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.`

// =====================================================================
// 1) Dekningskontroll
// =====================================================================

export function genererDekning(k: Kontrakt): string {
  const rader = [
    ...k.ressurser.map((r) => [r.tabell, true, Boolean(r.ingen_policy)] as const),
    ...k.uklassifisert_tillatt.tabeller.map((t) => [t, false, false] as const),
  ].sort((a, b) => a[0].localeCompare(b[0]))
    .map(([t, kl, up]) => `    (${sitat(t)}, ${kl}, ${up})`).join(',\n')

  return `${ADVARSEL}
--
-- DEKNINGSKONTROLL. Hver tabell i public skal staa i kontrakten, enten
-- som klassifisert ressurs eller paa lista over uklassifiserte.
--
-- EN NY TABELL STAAR I INGEN AV DEM, og feller derfor denne. Det er
-- meningen: en tabell skal ikke kunne bli usynlig for sikkerhets-
-- systemet fordi ingen husket aa foere den opp.
--
-- Partisjoner er unntatt - de arver forelderens klassifisering, og
-- rettighetene deres vaktes av punkt 10 i rls_vakthund.sql.
do $$
declare
  r record;
  funn text[] := array[]::text[];
  antall_klassifisert int;
begin
  create temp table kontrakt_tabeller (
    tabell text primary key, klassifisert boolean, uten_policy_ok boolean
  ) on commit drop;

  insert into kontrakt_tabeller (tabell, klassifisert, uten_policy_ok) values
${rader};

  select count(*) into antall_klassifisert from kontrakt_tabeller where klassifisert;

  -- KANARIFUGL. En kontrakt uten klassifiserte rader ville gjort hele
  -- sjekken stille - og "ingen funn" ser da noeyaktig ut som en base
  -- uten problemer.
  if antall_klassifisert = 0 then
    raise exception 'TENANT-DEKNING: kontrakten har ingen klassifiserte ressurser - maaler denne sjekken noe?';
  end if;

  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (select 1 from kontrakt_tabeller kt where kt.tabell = c.relname)
    order by c.relname
  loop
    funn := funn || format('UKLASSIFISERT  public.%s  - foer den opp i supabase/tenant-kontrakt.json. Gjett aldri klassifiseringen; den skal settes av noen som har tatt stilling.', r.relname);
  end loop;

  -- TABELLER UTEN POLICY SKAL VAERE ET FUNN, IKKE USYNLIGE.
  --
  -- Vakthundens dekningssjekk (punkt 4) starter fra pg_policies og ser
  -- derfor bare tabeller SOM HAR policy. En tabell uten policy faller
  -- utenfor den - og ser da noeyaktig ut som en tabell uten problemer.
  -- Slik havnet oversettelse_cache utenfor hver liste i to aar.
  --
  -- Denne starter fra pg_class: alle faktiske databaseobjekter. Er
  -- fravaeret av policy bevisst, skal det staa som ingen_policy i
  -- kontrakten - da er den sett og begrunnet.
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = c.relname)
      and not exists (
        select 1 from kontrakt_tabeller kt
        where kt.tabell = c.relname and kt.uten_policy_ok)
    order by c.relname
  loop
    funn := funn || format('UTEN POLICY  public.%s  - har ingen policy i det hele tatt. Er det med vilje, sett ingen_policy med begrunnelse i kontrakten. RLS uten policy nekter alt, men det skal staa at noen har bestemt det.', r.relname);
  end loop;

  -- Motsatt vei: en kontraktrad uten tabell er en fasit som har raatnet.
  for r in
    select kt.tabell
    from kontrakt_tabeller kt
    where to_regclass('public.' || quote_ident(kt.tabell)) is null
    order by kt.tabell
  loop
    funn := funn || format('KONTRAKT UTEN TABELL  %s  - staar i kontrakten, men finnes ikke i basen.', r.tabell);
  end loop;

  if array_length(funn, 1) > 0 then
    raise exception '%', format('TENANT-DEKNING: %s funn%s%s',
      array_length(funn, 1), chr(10) || chr(10), array_to_string(funn, chr(10)));
  end if;

  raise notice '--- Tenant-dekning: ingen funn. % klassifisert, % uklassifiserte staar igjen ---',
    antall_klassifisert, (select count(*) from kontrakt_tabeller where not klassifisert);
end $$;
`
}

// =====================================================================
// 2) Atferdsmatrisen
// =====================================================================

export function genererMatrise(k: Kontrakt): string {
  return bygg(k.ressurser.filter((r) => r.data_class === 'warm'))
}

/**
 * Matrisen delt i biter som får plass i Supabase SQL Editor.
 *
 * DEN FULLE FILA SPRENGTE EDITOREN 2026-08-26, på 1,0 MB: «Query is too
 * large to be run via the SQL Editor». 874 KB gikk gjennom på andre
 * forsøk; 1,0 MB blir avvist før den prøver. Med 52 tabeller igjen å
 * klassifisere er den grensen passert for godt.
 *
 * Hver del er en HEL kjøring: fasitverden, hjelpere, egne
 * forutsetninger, egne ressurser, egen oppsummering — og sin egen
 * `rollback`. Delene deler ingen tilstand, så de kan limes inn i hvilken
 * som helst rekkefølge, og en del som feiler sier hva den fant uten å
 * gjøre de andre ugyldige.
 *
 * En ressurs deles ALDRI over to filer: den positive kontrollen og
 * avvisningene den gjør gyldige må ligge i samme kjøring.
 */
export function genererMatriseDeler(
  k: Kontrakt, maksTegn = 450_000,
): Array<{ fil: string; sql: string }> {
  const varme = k.ressurser.filter((r) => r.data_class === 'warm')

  // Størrelsen på en ressurs måles på ressursen selv, ikke på fila den
  // havner i: fellesdelen (fasitverden + hjelpere, ~25 KB) følger med i
  // hver del uansett, og skal ikke telle mot skillet.
  const grupper: Ressurs[][] = []
  let denne: Ressurs[] = []
  let brukt = 0
  for (const r of varme) {
    const vekt = bygg([r]).length
    if (denne.length > 0 && brukt + vekt > maksTegn) {
      grupper.push(denne)
      denne = []
      brukt = 0
    }
    denne.push(r)
    brukt += vekt
  }
  if (denne.length > 0) grupper.push(denne)

  return grupper.map((gruppe, i) => ({
    fil: `supabase/tests/deler/matrise_${String(i + 1).padStart(2, '0')}.sql`,
    sql: bygg(gruppe, { nr: i + 1, av: grupper.length }),
  }))
}

function bygg(varme: Ressurs[], del?: { nr: number; av: number }): string {
  const ut: string[] = []
  const merke = del ? ` DEL ${del.nr}/${del.av}` : ''

  ut.push(`${ADVARSEL}${del ? `
--
-- DEL ${del.nr} AV ${del.av}. Hele matrisen er for stor for Supabase SQL
-- Editor. Denne fila er en komplett kjoering av ${varme.length} ressurs(er):
-- egen fasitverden, egne forutsetninger, egen oppsummering, egen
-- rollback. Delene deler ingen tilstand og kan kjoeres i hvilken som
-- helst rekkefoelge. Rekkefoelgen i tallet er bare lesbarhet.
--
-- INGEN FUNN I EN DEL BETYR INGEN FUNN I DEN DELEN. Hele beviset er
-- alle delene, og hver av dem maa si "ingen funn".` : ''}
--
-- ATFERDSMATRISEN. For hver varm ressurs, hver identitet og hver
-- operasjon kontrakten beskriver: naar den, eller naar den ikke?
--
-- POSITIVE KONTROLLER ER OBLIGATORISKE. En suite som bare beviser
-- "avvist" kan vaere groenn fordi alt er oedelagt. Hver identitet som
-- SKAL naa noe, proever ogsaa det.
--
-- AVVIST MAA VAERE 42501. Et forbudt insert som feiler paa en
-- unique-skranke er ogsaa "avvist", men det beviser ingenting om RLS.
-- rutine_utforinger har unique (rutine_id, dato) og ville gitt akkurat
-- den falske groennheten. \`skriv_avvist\` krever derfor 42501 - eller
-- null rader, som er det \`using\` gir paa update og delete.
begin;
`)

  // PASS 1: generer kroppene. Underveis samler proberadSql opp hvilke
  // forutsetningsrader hvert enkelt forsoek trenger.
  seedbehov = []
  teller = 0
  const ressursSeed = varme.map((r) => genererRessursSeed(r))
  const kropper = varme.map((r) => genererRessurs(r))

  // PASS 2: skriv fila. Forutsetningene foerst - de er det proberadene
  // peker paa.
  ut.push(genererSeed())
  ut.push(HJELPERE)
  if (seedbehov.length > 0) {
    ut.push('-- --- Forutsetninger, en per forsoek ---')
    ut.push([...new Set(seedbehov)].join('\n'))
  }
  ut.push(...ressursSeed)
  ut.push(...kropper)

  ut.push(`
select pg_temp.som_eier();

-- =====================================================================
-- EN NEGATIV TENANT-TEST TELLER IKKE FOER DEN POSITIVE HAR LYKTES.
--
-- Fixturen er ressursens. Lykkes ingen tillatt operasjon paa en
-- ressurs, vet vi ikke om proberaden i det hele tatt er gyldig i
-- domenet - og da beviser ingen av avvisningene noe om tenantgrensen.
-- De kan like gjerne ha feilet paa en skranke, en fremmednokkel eller
-- en manglende forutsetning.
--
-- Uten denne blokka ville en suite der ALT er oedelagt sett ut som en
-- suite der alt er trygt.
-- =====================================================================
do $$
declare r record;
begin
  for r in
    select distinct f.gruppe
    from pg_temp.funn f
    where f.art = 'negativ'
      and not exists (
        select 1 from pg_temp.funn p
        where p.gruppe = f.gruppe and p.art = 'positiv' and p.status = 'ok')
    order by 1
  loop
    insert into pg_temp.funn (status, navn, detalj, gruppe, art)
    values ('FEIL', r.gruppe || ': ingen positiv kontroll lyktes',
            'Avvisningene i denne gruppa er derfor ikke gyldige tenant-bevis - fixturen kan vaere ugyldig i domenet.',
            r.gruppe, 'kontroll');
  end loop;
end $$;

select status, navn, detalj
from pg_temp.funn
order by (status = 'FEIL') desc, nr;

-- =====================================================================
-- EXIT-KODEN MAA FOELGE TABELLEN.
--
-- Paastandene er RADER, ikke unntak - det er hele grunnen til at
-- resultatet er lesbart. Men da gaar psql ut med 0 selv naar tabellen
-- er full av FEIL, og CI-jobben blir groenn.
--
-- Det skjedde 2026-08-25: elleve FEIL, groenn jobb. En roed suite som
-- rapporteres som groenn er verre enn ingen suite - det er slik man
-- laerer seg aa se bort fra roedt.
--
-- Selecten over kjorer FOERST, saa tabellen staar i loggen. Denne
-- kaster etterpaa.
-- =====================================================================
do $$
declare n int;
begin
  select count(*) into n from pg_temp.funn where status = 'FEIL';
  if n > 0 then
    raise exception 'TENANT-MATRISEN${merke}: % funn. Se tabellen over.', n;
  end if;
  raise notice '--- Tenant-matrisen${merke}: ingen funn. % paastander ---',
    (select count(*) from pg_temp.funn);
end $$;

rollback;
`)
  return ut.join('\n')
}

function genererSeed(): string {
  const brukere = IDENTITETER.map((i) => `  (${sitat(i.uid)}, ${sitat(`${i.navn}@kanari.local`)})`).join(',\n')
  const rolleNavn = { owner: 'retailer_admin', manager: 'butikksjef', tablet: 'butikkbruker_tablet' } as const
  const profiler = IDENTITETER.map((i) =>
    `  (${sitat(i.uid)}, ${sitat(R[i.kjede])}, ${sitat(rolleNavn[i.rolle])}, ${sitat(i.navn)})`).join(',\n')
  const tildelinger = IDENTITETER
    .filter((i) => i.rolle !== 'owner')
    .flatMap((i) => i.stasjoner.map((s) => `  (${sitat(i.uid)}, ${sitat(S[s])})`)).join(',\n')

  return `-- --- Fasitverdenen ---------------------------------------------------
-- Butikknummer 0001 finnes i BEGGE kjeder, og ansatt_nr 4501 likesaa.
insert into auth.users (id, email) values
${brukere}
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  (${sitat(R.A)}, 'Kanari A'),
  (${sitat(R.B)}, 'Kanari B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
${profiler};

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  (${sitat(S.A1)}, ${sitat(R.A)}, '0001', 'Sentrum', 'sentrum'),
  (${sitat(S.A2)}, ${sitat(R.A)}, '0002', 'Nord',    'pendler'),
  (${sitat(S.A3)}, ${sitat(R.A)}, '0003', 'Vest',    'utfart'),
  (${sitat(S.B1)}, ${sitat(R.B)}, '0001', 'Sentrum', 'sentrum'),
  (${sitat(S.B2)}, ${sitat(R.B)}, '0002', 'Nord',    'pendler');

insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
${tildelinger};
`
}

function genererRessursSeed(r: Ressurs): string {
  const linjer: string[] = [`-- --- ${r.tabell}: forutsetninger og proberader ---`]
  const alle: Array<[Kjede, Stasjon]> = [
    ['A', 'A1'], ['A', 'A2'], ['A', 'A3'], ['B', 'B1'], ['B', 'B2'],
  ]

  // NULL-STASJONSRADEN. `retailer_or_station` betyr at stasjon_id kan
  // vaere null - og at null da gjelder HELE den autentiserte kjeden.
  // Én slik rad per kjede, saa hver identitet kan proeves mot den.
  if (r.tenant_scope === 'retailer_or_station') {
    for (const kjede of ['A', 'B'] as Kjede[]) {
      const { kolonner, verdier } = proberadSql(r, kjede, KJEDENS_STASJONER[kjede][0], `null${kjede}`)
      const utenStasjon = kolonner
        .map((k, idx) => [k, verdier[idx]] as const)
        .map(([k, v]) => [k, k === 'stasjon_id' ? 'null' : v] as const)
      linjer.push(`insert into public.${r.tabell} (id, ${utenStasjon.map(([k]) => k).join(', ')}) `
        + `values (${sitat(seedId(`${r.tabell}:nullrad:${kjede}`))}, ${utenStasjon.map(([, v]) => v).join(', ')});`)
    }
  }

  // Én fast proberad per stasjon, til lese- og flyttetester.
  for (const [kjede, s] of alle) {
    const { kolonner, verdier } = proberadSql(r, kjede, s, `fast${s}`)
    // Verdiene tas vare paa: uten id-kolonne er DE identiteten.
    fastRad[r.tabell] ??= {}
    fastRad[r.tabell]![s] = Object.fromEntries(kolonner.map((k, i) => [k, verdier[i]]))
    linjer.push(idKol(r) === 'id' && !r.id_kolonner
      ? `insert into public.${r.tabell} (id, ${kolonner.join(', ')}) `
        + `values (${sitat(seedId(`${r.tabell}:fast:${s}`))}, ${verdier.join(', ')});`
      // Noekkelen staar allerede blant tenantkolonnene.
      : `insert into public.${r.tabell} (${kolonner.join(', ')}) values (${verdier.join(', ')});`)
  }

  // `nyrad_*` lager en fersk rad rett før en update/delete-test, saa en
  // tillatt sletting ikke river grunnlaget for neste paastand.
  //
  // DEN MAA LAGE SINE EGNE FORUTSETNINGER. Foerste utgave bakte inn ETT
  // sett - A1 sitt - og ble kalt ~60 ganger. `rutine_utforinger` har
  // unique (rutine_id, dato), saa kall nummer to kolliderte:
  //
  //   duplicate key value violates unique constraint
  //   "rutine_utforinger_rutine_id_dato_key"
  //
  // Her er `gen_random_uuid()` riktig, og det motsier ikke regelen om at
  // GENERATOREN skal vaere deterministisk: tilfeldigheten skjer i basen,
  // ved kjoretid, og fila som ligger i repoet er den samme hver gang.
  // TENANTNOEKKEL, IKKE STASJONSKOLONNE. `opplaering_utfort` er
  // stasjonsscopet, men BAERER ingen stasjon_id - nokkelen er indirekte
  // via periode_id. tenantKolonner() vet det; dette maa vite det samme.
  const tenantParam = Object.keys(tenantKolonner(r, 'A', 'A1'))
  const tenantVerdi = tenantParam.map((c) => c === 'retailer_id' ? 'p_retailer' : 'p_stasjon')

  // Forutsetningene lages INNE i funksjonen, med fersk uuid per kall.
  // Da er `business_unik` oppfylt uten at noe varieres på slump: en ny
  // rutine gjør (rutine_id, dato) unik, en ny periode og oppgave gjør
  // (periode_id, oppgave_id) unik.
  const seedNavn = [...new Set((r.seed_ekstra ?? [])
    .flatMap((l) => [...l.matchAll(/\{\{seed:([a-z_]+)\}\}/g)].map((m) => m[1])))]

  // I plpgsql er variablene identifikatorer, ikke tekst — derfor byttes
  // det SITERTE plassholderuttrykket mot det bare variabelnavnet.
  const somVariabel = (mal: string) => {
    let ut = mal
    for (const n of seedNavn) ut = ut.split(`'{{seed:${n}}}'`).join(`v_${n}`)
    return ut
      .split(`'{{retailer}}'`).join('p_retailer')
      .split(`'{{stasjon}}'`).join('p_stasjon')
      // Forretningsnoekkelen maa variere per KALL, ikke per call site.
      .split(`'sonde {{unik}}'`).join(`'sonde ' || p_merke || '-' || nextval('tenant_teller'::regclass)`)
      .split(`{{unik_dato}}`).join(`date '2030-01-01' + nextval('tenant_teller'::regclass)::int`)
      .split(`{{unik}}`).join(`' || p_merke || '-' || nextval('tenant_teller'::regclass) || '`)
      // `{{n}}` er generatorens teller og hoerer til seedingen. Naar den
      // samme linja bakes inn i nyrad_*, maa den bli en KJORETIDSverdi -
      // ellers faar hvert kall samme verdi, og en forretningsnokkel som
      // pin_hash kolliderer med 23505.
      // EGET VERDIROM, samme grunn som datoene fikk 2030. Generatorens
      // teller lager `pin-merke-5` ved seeding; uten prefikset ville
      // nextval laget `pin-merke-5` en gang til, og de to kolliderte med
      // hverandre i stedet for med seg selv.
      .split(`{{n}}`).join(`' || 'rt' || nextval('tenant_teller'::regclass) || '`)
  }

  const proberadFelt = Object.entries(r.proberad).filter(([k]) => !k.startsWith('$'))

  // Ingen nyrad_* naar skjemaet bare tillater en rad per stasjon.
  if (r.en_rad_per_stasjon) return linjer.join('\n')

  // FEMTE STEDET ID-ANTAKELSEN SATT. `returning id into ny` feiler med
  // 42703 paa en tabell uten id-kolonne - ikke ved generering, men naar
  // funksjonen KALLES, midt i en ellers gyldig kjoering. Uten en
  // id-kolonne er det heller ingenting fornuftig aa returnere: raden
  // pekes paa med predikatet sitt.
  const uidRad = !r.id_kolonner
  linjer.push(`
create or replace function pg_temp.nyrad_${r.tabell}(p_retailer uuid, p_stasjon uuid, p_merke text)
returns ${uidRad ? 'uuid' : 'void'} language plpgsql security definer as $fn$
declare${uidRad ? '\n  ny uuid;' : ''}${seedNavn.map((n) => `\n  v_${n} uuid := gen_random_uuid();`).join('')}
begin${(r.seed_ekstra ?? []).map((l) => `\n  ${somVariabel(l)};`).join('')}
  insert into public.${r.tabell} (${[...tenantParam, ...proberadFelt.map(([k]) => k)].join(', ')})
  values (${[...tenantVerdi, ...proberadFelt.map(([, v]) => somVariabel(v))].join(', ')})${
    uidRad ? '\n  returning id into ny;' : ';'}${uidRad ? '\n  return ny;' : ''}
end $fn$;`)

  return linjer.join('\n')
}

const HJELPERE = `
-- --- Hjelpere --------------------------------------------------------
--
-- EN TELLER SOM VIRKER I BASEN, ikke bare i generatoren.
--
-- nyrad_* kalles flere ganger for SAMME identitet og SAMME stasjon -
-- en gang foer update, en gang foer delete. Bakes forretningsnokkelen
-- inn med en fast verdi, kolliderer det andre kallet med 23505:
--
--   duplicate key value violates unique constraint
--   "produksjonsplan_hode_stasjon_id_dato_key"
--
-- Generatorens egen teller loeser det ikke - den teller ved
-- GENERERING, og funksjonskroppen skrives en gang. Denne teller ved
-- KJORING.
--
-- EGET DATOROM. Foerste forsoek lot begge tellerne lage datoer fra
-- 2026-01-01, og da kolliderte de med hverandre i stedet for med seg
-- selv. De seedede radene bruker 2026 + generatorens teller (0-700);
-- nyrad_* bruker 2030 + denne. To tellere som teller riktig hver for
-- seg, men i samme rom, er fortsatt en kollisjon.
create temp sequence tenant_teller;

create temp table funn (
  nr serial primary key, status text not null, navn text not null, detalj text,
  gruppe text, art text
) on commit drop;

-- Gruppa er ressurs + identitet. Arten er positiv, negativ eller lesing.
-- Sammen er de det som gjor regelen under maalbar: en negativ
-- tenant-test teller ikke foer den positive i samme gruppe har lykkes.
create temp table gjeldende (gruppe text, art text) on commit drop;
insert into gjeldende values (null, null);

create or replace function pg_temp.sett_gruppe(p_gruppe text) returns void
language plpgsql security definer as $$
begin
  update pg_temp.gjeldende set gruppe = p_gruppe;
end $$;

create or replace function pg_temp.logg(p_status text, p_navn text, p_detalj text default null,
  p_art text default null)
returns void language plpgsql security definer as $$
begin
  insert into pg_temp.funn (status, navn, detalj, gruppe, art)
  values (p_status, p_navn, p_detalj,
          (select gruppe from pg_temp.gjeldende limit 1), p_art);
end $$;

create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function pg_temp.som_eier() returns void
language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean, p_art text default 'lesing')
returns void language plpgsql security definer as $$
begin
  perform pg_temp.logg(case when p_ok is true then 'ok' else 'FEIL' end, p_navn, null, p_art);
end $$;

-- SECURITY INVOKER, og det er ikke valgfritt: den dynamiske setningen
-- MAA kjore som testbrukeren. Blir denne definer, gaar skrivingen som
-- eier - forbi RLS - og hele fila blir groenn uansett hva policyen sier.
--
-- 42501 ELLER NULL RADER, INGENTING ANNET. En unique-skranke (23505)
-- eller en fremmednokkel (23503) avviser ogsaa, men beviser ingenting
-- om tenantvernet. Slike svar er FEIL her, ikke ok.
-- KONTROLLKONTEKST. Definer, saa den ser forbi RLS og svarer paa om
-- raden i det hele tatt finnes. Uten den er "0 rader" tvetydig.
create or replace function pg_temp.finnes(p_tabell text, p_id uuid, p_kol text default 'id')
returns boolean language plpgsql security definer as $$
declare n int;
begin
  execute format('select count(*) from public.%I where %I = $1', p_tabell, p_kol) into n using p_id;
  return n > 0;
end $$;

-- SAMME KONTROLLKONTEKST, MEN FOR EN SAMMENSATT NOEKKEL.
--
-- \`timesalg\` og \`kassererstatistikk\` har ingen id-kolonne; raden er
-- (retailer_id, stasjon_id, dato, time). Da finnes det ingen enkelt
-- verdi aa slaa opp paa, og "0 rader" ville vaert like tvetydig som foer
-- - bare uten en maate aa oppklare det paa.
--
-- Predikatet kommer fra generatoren og gjelder den seedede raden.
create or replace function pg_temp.finnes_pred(p_tabell text, p_pred text)
returns boolean language plpgsql security definer as $$
declare n int;
begin
  execute format('select count(*) from public.%I where %s', p_tabell, p_pred) into n;
  return n > 0;
end $$;

create or replace function pg_temp.skriv_avvist(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_id uuid default null, p_maal_kol text default 'id'
) returns void
language plpgsql as $$
begin
  -- EN KROPP, to maater aa peke paa raden. Uten delegeringen ville
  -- regelen om at 0 rader krever en bekreftet maalrad staatt to steder,
  -- og den ene kopien ville sluttet aa gjelde uten at noe sa fra.
  perform pg_temp.skriv_avvist_pred(p_navn, p_sql, p_maal_tabell,
    case when p_maal_tabell is null then null
         else format('%I = %L', p_maal_kol, p_maal_id) end);
end $$;

create or replace function pg_temp.skriv_avvist_pred(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_pred text default null
) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    if sqlstate = '42501' then
      perform pg_temp.logg('ok', p_navn, 'avvist med 42501', 'negativ');
    else
      perform pg_temp.logg('FEIL', p_navn,
        'avvist av FEIL grunn: ' || sqlstate || ' - beviser ikke tenantvern', 'negativ');
    end if;
    return;
  end;
  if n > 0 then
    perform pg_temp.logg('FEIL', p_navn, 'skrivingen gikk gjennom, ' || n || ' rad(er)', 'negativ');
    return;
  end if;

  -- NULL RADER ER IKKE ET BEVIS I SEG SELV.
  --
  -- \`using\` som utelukker raden gir 0 rader. Men det gjor OGSAA en feil
  -- id, en fixture som aldri ble seedet, eller en tabell som er tom.
  -- Alle tre ser identiske ut herfra, og alle tre ville vaert groenne.
  --
  -- Derfor: raden maa bevises aa finnes i kontrollkonteksten foer 0
  -- rader godtas. Da - og bare da - er det RLS som stoppet skrivingen.
  if p_maal_tabell is null then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men ingen maalrad oppgitt - kan ikke skille RLS fra feil fixture', 'negativ');
  elsif not pg_temp.finnes_pred(p_maal_tabell, p_maal_pred) then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men maalraden (' || p_maal_pred || ') finnes ikke i ' || p_maal_tabell
      || ' - testen beviser ingenting', 'negativ');
  else
    perform pg_temp.logg('ok', p_navn, '0 rader, maalrad bekreftet', 'negativ');
  end if;
end $$;

create or replace function pg_temp.skriv_tillatt(p_navn text, p_sql text) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    perform pg_temp.logg('FEIL', p_navn, 'ble blokkert: ' || sqlstate, 'positiv');
    return;
  end;
  if n = 0 then
    perform pg_temp.logg('FEIL', p_navn, 'traff 0 rader - blokkert i stillhet', 'positiv');
  else
    perform pg_temp.logg('ok', p_navn, n || ' rad', 'positiv');
  end if;
end $$;
`

function genererRessurs(r: Ressurs): string {
  const linjer: string[] = ['', `-- =====================================================================`,
    `-- ${r.tabell}  (${r.tenant_scope}, ${r.data_class})`,
    `-- =====================================================================`,
    `select pg_temp.sett_gruppe(${sitat(r.tabell)});`]

  const stasjonsbasert = r.tenant_scope !== 'retailer'

  for (const i of IDENTITETER) {
    linjer.push(`\nselect pg_temp.logg_inn_som(${sitat(i.uid)});   -- ${i.navn}`)

    const mål = stasjonsbasert ? maal(i) : ([...new Set(maal(i).map((s) => kjedenFor(s)))] as Kjede[])
      .flatMap((kj) => [KJEDENS_STASJONER[kj][0]])

    for (const op of r.operasjoner) {
      for (const s of mål) {
        const ok = tillatt(r, i, op, s)
        const kjede = kjedenFor(s)
        const navn = `${r.tabell} ${i.navn} ${op.toUpperCase()} ${stasjonsbasert ? s : kjede}`
        const fastId = fastVerdi(r, s)
        const pred = radPredikat(r, s)

        if (op === 'select') {
          linjer.push(`select pg_temp.paastand(${sitat(`${navn} -> ${ok ? 'ser' : 'ser ikke'}`)}, ${
            ok ? '' : 'not '}exists (select 1 from public.${r.tabell} where ${pred}), ${
            sitat(ok ? 'positiv' : 'negativ')});`)
          continue
        }

        if (op === 'insert') {
          const { kolonner, verdier } = proberadSql(r, kjede, s, `${i.navn}${s}`)
          const sql = `insert into public.${r.tabell} (${kolonner.join(', ')}) values (${verdier.join(', ')})`

          // EN RAD PER STASJON: PLASSEN MAA VAERE LEDIG.
          //
          // Stasjonen har alt sin faste rad, saa et innslag nummer to
          // kolliderer med primaernokkelen. Den positive kontrollen ble
          // "ble blokkert: 23505" - en domenefeil, ikke en avvisning -
          // og den negative ville vaert "avvist av FEIL grunn".
          //
          // Raden fjernes som eier foer forsoeket, og tilstanden
          // normaliseres etterpaa uansett utfall.
          if (r.en_rad_per_stasjon) {
            linjer.push(`select pg_temp.som_eier();`)
            linjer.push(`delete from public.${r.tabell} where ${idKol(r)} = ${sitat(fastVerdi(r, s))};`)
            linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)
          }

          linjer.push(`select pg_temp.${ok ? 'skriv_tillatt' : 'skriv_avvist'}(${sitat(navn)}, ${sitat(sql)});`)

          if (r.en_rad_per_stasjon) {
            const gjen = proberadSql(r, kjede, s, `gjeninn${i.navn}${s}`)
            linjer.push(`select pg_temp.som_eier();`)
            linjer.push(`delete from public.${r.tabell} where ${idKol(r)} = ${sitat(fastVerdi(r, s))};`)
            linjer.push(`insert into public.${r.tabell} (${gjen.kolonner.join(', ')}) values (${gjen.verdier.join(', ')});`)
            linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)
          }
          continue
        }

        // update og delete far en fersk rad, saa en tillatt sletting
        // ikke river grunnlaget for neste paastand.
        //
        // MEN IKKE NAAR SKJEMAET HAANDHEVER EN RAD PER STASJON. Der ER
        // stasjon_id primaernokkelen, og et nytt innslag ville kollidert
        // med 23505 - altsaa en domenefeil, ikke en tenant-avvisning.
        // Da brukes den faste raden, og den gjeninnsettes etter en
        // tillatt sletting slik den gjor ellers.
        if (!r.en_rad_per_stasjon) {
          linjer.push(`select pg_temp.som_eier();`)
          linjer.push(`select pg_temp.nyrad_${r.tabell}(${sitat(R[kjede])}, ${sitat(S[s])}, ${sitat(`${i.navn}-${op}`)}) as _;`)
          linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)
        }

        const sql = op === 'update'
          ? `update public.${r.tabell} set ${settbartFelt(r)} where ${pred}`
          : `delete from public.${r.tabell} where ${pred}`
        // Maalraden foelger med paa avvisninger: "0 rader" godtas bare
        // naar kontrollkonteksten bekrefter at raden faktisk finnes.
        const maalrad = r.id_kolonner
          ? `, ${sitat(r.tabell)}, ${sitat(pred)}`
          : `, ${sitat(r.tabell)}, ${sitat(fastId)}, ${sitat(idKol(r))}`
        const avvist = r.id_kolonner ? 'skriv_avvist_pred' : 'skriv_avvist'
        linjer.push(ok
          ? `select pg_temp.skriv_tillatt(${sitat(navn)}, ${sitat(sql)});`
          : `select pg_temp.${avvist}(${sitat(navn)}, ${sitat(sql)}${maalrad});`)

        // Etter en tillatt sletting maa den faste raden tilbake.
        if (op === 'delete' && ok) {
          linjer.push(`select pg_temp.som_eier();`)
          if (r.id_kolonner) {
            // IDENTITETEN LIGGER I VERDIENE. En fersk rad ville faatt en
            // ny dato, og predikatet ville pekt paa ingenting etterpaa.
            const rad = fastRad[r.tabell]![s]!
            const kol = Object.keys(rad)
            linjer.push(`insert into public.${r.tabell} (${kol.join(', ')}) `
              + `values (${kol.map((k) => rad[k]).join(', ')});`)
          } else {
            const { kolonner, verdier } = proberadSql(r, kjede, s, `gjen${i.navn}${s}`)
            // Fjerde stedet id-antakelsen satt. Se `idKol`.
            linjer.push(idKol(r) === 'id'
              ? `insert into public.${r.tabell} (id, ${kolonner.join(', ')}) values (${sitat(fastId)}, ${verdier.join(', ')});`
              : `insert into public.${r.tabell} (${kolonner.join(', ')}) values (${verdier.join(', ')});`)
          }
          linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)
        }
      }
    }

    // --- NULL BETYR KJEDEN, ALDRI GLOBALT ----------------------------
    //
    // To tilstander, og begge maa bevises: raden med konkret stasjon
    // foelger stasjonstildelingen, raden med null foelger KJEDEN.
    //
    // Den negative er den viktigste. Uten retailer-predikatet ville en
    // null-rad vaert synlig for alle - og en policy som bare sier
    // `stasjon_id is null or stasjon_id in (...)` gjor nettopp det.
    if (r.tenant_scope === 'retailer_or_station' && r.operasjoner.includes('select')) {
      const egen = seedId(`${r.tabell}:nullrad:${i.kjede}`)
      const fremmed = seedId(`${r.tabell}:nullrad:${ANNEN_KJEDE[i.kjede]}`)

      // NULL BETYR IKKE DET SAMME OVERALT.
      //
      // `tablet_meldinger`: null = hele kjeden, og alle i kjeden ser
      // raden. `regnskapslinjer`: null = klyngelinje, og BARE eieren ser
      // den - stasjonsrollene faller ut fordi policyen krever
      // `stasjon_id is not null` i sin gren.
      //
      // Uten dette skillet ville generatoren paastaatt at butikksjefen
      // ser klyngelinjene, og en riktig base ville blitt roed.
      const serEgen = r.null_stasjon === 'kun_eier' ? i.rolle === 'owner' : true
      linjer.push(`select pg_temp.paastand(${sitat(
        `${r.tabell} ${i.navn} ${serEgen ? 'ser' : 'ser IKKE'} kjedens null-stasjonsrad`)}, `
        + `${serEgen ? '' : 'not '}exists (select 1 from public.${r.tabell} where id = ${sitat(egen)}), `
        + `${sitat(serEgen ? 'positiv' : 'negativ')});`)
      linjer.push(`select pg_temp.paastand(${sitat(`${r.tabell} ${i.navn} ser IKKE den andre kjedens null-rad`)}, `
        + `not exists (select 1 from public.${r.tabell} where id = ${sitat(fremmed)}), 'negativ');`)
    }

    // --- TENANT-FLYTTING ---------------------------------------------
    // `using` slipper raden inn fordi den ER hennes. Bare `with check`
    // kan stoppe at den flyttes ut. Dette er den ene testen som skiller
    // de to klausulene fra hverandre.
    if (r.operasjoner.includes('update')) {
      const egen = i.stasjoner.find((s) => tillatt(r, i, 'update', s))
      if (egen) {
        const fastId = fastVerdi(r, egen)
        const pred = radPredikat(r, egen)
        const forbudtISammeKjede = KJEDENS_STASJONER[i.kjede].find((s) => !tillatt(r, i, 'update', s))
        const annenKjede = ANNEN_KJEDE[i.kjede]
        const avvist = r.id_kolonner ? 'skriv_avvist_pred' : 'skriv_avvist'
        const maalrad = r.id_kolonner
          ? `, ${sitat(r.tabell)}, ${sitat(pred)}`
          : `, ${sitat(r.tabell)}, ${sitat(fastId)}, ${sitat(idKol(r))}`

        if (stasjonsbasert && forbudtISammeKjede && !r.tenant_kolonne) {
          linjer.push(`select pg_temp.${avvist}(${sitat(`${r.tabell} ${i.navn} FLYTTER egen rad ${egen} -> ${forbudtISammeKjede}`)}, ${
            sitat(`update public.${r.tabell} set stasjon_id = ${sitat(S[forbudtISammeKjede])} where ${pred}`)}${maalrad});`)
        }
        if (r.tenant_scope === 'retailer' || r.tenant_scope === 'retailer_and_station') {
          linjer.push(`select pg_temp.${avvist}(${sitat(`${r.tabell} ${i.navn} FLYTTER egen rad -> kjede ${annenKjede}`)}, ${
            sitat(`update public.${r.tabell} set retailer_id = ${sitat(R[annenKjede])} where ${pred}`)}${maalrad});`)
        }
      }
    }
  }
  return linjer.join('\n')
}

function kjedenFor(s: Stasjon): Kjede {
  return KJEDENS_STASJONER.A.includes(s) ? 'A' : 'B'
}

/** Et felt som trygt kan skrives i en update-test. */
function settbartFelt(r: Ressurs): string {
  if (r.oppdaterbart) return r.oppdaterbart
  const kandidat = Object.keys(r.proberad).find((k) => !k.endsWith('_id'))
  if (!kandidat) {
    throw new Error(`${r.tabell}: proberaden har bare fremmednokler - sett \`oppdaterbart\` i kontrakten`)
  }
  const verdi = r.proberad[kandidat]
  return `${kandidat} = ${verdi.includes('{{') ? fyll(verdi, { unik: 'endret', unik_dato: `date '2026-09-09'`, retailer: '', stasjon: '' }) : verdi}`
}
