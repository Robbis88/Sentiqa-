// =====================================================================
// Sentiqa - PostgREST-sonde
//
// rls_isolasjon.sql og rls_kanarifugl.sql setter `request.jwt.claims` og
// `set role authenticated` i databasen. Det er en tro kopi av det
// PostgREST gjor - men det ER en kopi. Denne fila gar den faktiske veien:
// HTTPS mot rest-endepunktet, med apikey-header, slik nettleseren gjor.
//
// TRINN 1 (denne, kjorer uten innlogging): hva nar `anon`?
//
//   Det er ikke et teoretisk sporsmal her. `anon` er rollen bak den
//   offentlige nokkelen i hver eneste sidelast, og to ganger har den
//   hatt mer enn den skulle:
//
//     0105  49 partisjoner av daglig_salg - partisjoner arver ikke
//           rettigheter, saa anon kunne lese alt forbi forelderens RLS
//     0130  alle 21 views - Supabase' default privileges traff hver ny
//           view automatisk
//
//   Begge kom av seg selv. Ingen skrev grantet.
//
// TRINN 2 (krever testbrukere): autorisert mot forbudt ressurs per
//   rolle. Legg SONDE_*_EPOST/PASSORD i .env.local, saa logger sonden
//   inn og gjentar matrisen fra kanarifuglen over HTTP.
//
// ---------------------------------------------------------------------
// TRE UTFALL, OG DE ER IKKE LIKE GODE
//
//   403 / 401     ingen grant. Sperret for rollen naas i det hele tatt.
//   200 med []    grant finnes, RLS returnerer null rader. Ett lag.
//   200 med rader LEKKASJE.
//
// «200 med []» er ikke en feil, men det er heller ikke to lag. Det er
// verdt aa se hvilke tabeller som staar der, for da er RLS det eneste
// som staar mellom anon og innholdet.
// =====================================================================
import { readFileSync } from 'node:fs'

function lesEnv(sti = '.env.local') {
  const ut = {}
  for (const linje of readFileSync(sti, 'utf8').split('\n')) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(linje.trim())
    if (m) ut[m[1]] = m[2].trim()
  }
  return ut
}

const env = lesEnv()
const URL_BASE = env.NEXT_PUBLIC_SUPABASE_URL
const ANON = env.NEXT_PUBLIC_SUPABASE_ANON_KEY
if (!URL_BASE || !ANON) {
  console.error('Mangler NEXT_PUBLIC_SUPABASE_URL eller _ANON_KEY i .env.local')
  process.exit(2)
}

const TABELLER = JSON.parse(readFileSync(new URL('./sonde_maal.json', import.meta.url), 'utf8'))

async function probe(navn, token) {
  const r = await fetch(`${URL_BASE}/rest/v1/${navn}?select=*&limit=1`, {
    headers: { apikey: ANON, Authorization: `Bearer ${token}` },
  })
  if (r.status !== 200) {
    let kode = ''
    try { kode = (await r.json()).code ?? '' } catch { /* tom kropp */ }
    return { utfall: 'sperret', status: r.status, kode }
  }
  const rader = await r.json()
  return {
    utfall: Array.isArray(rader) && rader.length > 0 ? 'LEKKASJE' : 'tomt',
    status: 200,
    antall: Array.isArray(rader) ? rader.length : 0,
  }
}

// Kjorer i puljer. Alt paa en gang gir 429 fra Supabase, og en 429
// teller som «sperret» - da ville sonden vaert gronn av feil grunn.
async function iPuljer(liste, storrelse, fn) {
  const ut = []
  for (let i = 0; i < liste.length; i += storrelse) {
    ut.push(...await Promise.all(liste.slice(i, i + storrelse).map(fn)))
  }
  return ut
}

const maal = [
  ...TABELLER.tabeller.map((n) => ({ navn: n, slag: 'tabell' })),
  ...TABELLER.views.map((n) => ({ navn: n, slag: 'view' })),
]

console.log(`Sonderer ${maal.length} ressurser som anon mot ${URL_BASE}\n`)

const svar = await iPuljer(maal, 8, async (m) => ({ ...m, ...await probe(m.navn, ANON) }))

const lekk = svar.filter((s) => s.utfall === 'LEKKASJE')
const tomt = svar.filter((s) => s.utfall === 'tomt')
const sperret = svar.filter((s) => s.utfall === 'sperret')

// 429 er ikke et vern. Skilles ut, ellers ser en ratebegrenset kjoring
// ut som en vellykket en.
const rate = sperret.filter((s) => s.status === 429)

if (lekk.length) {
  console.log('LEKKASJE - anon leser rader:')
  for (const s of lekk) console.log(`  ${s.slag.padEnd(7)} ${s.navn}`)
  console.log()
}
if (sperret.length) {
  console.log('Sperret for anon (ingen grant - to lag):')
  for (const s of sperret.filter((x) => x.status !== 429)) {
    console.log(`  ${s.slag.padEnd(7)} ${s.navn.padEnd(34)} ${s.status} ${s.kode}`)
  }
  console.log()
}
if (tomt.length) {
  console.log('Grant finnes, RLS tom (ett lag):')
  for (const s of tomt) console.log(`  ${s.slag.padEnd(7)} ${s.navn}`)
  console.log()
}
if (rate.length) {
  console.log(`ADVARSEL: ${rate.length} svar var 429 - ratebegrenset, ikke sperret.`)
  console.log()
}

console.log(`sperret ${sperret.length - rate.length}  |  tomt ${tomt.length}`
  + `  |  LEKKASJE ${lekk.length}  |  ratebegrenset ${rate.length}`)

// KANARIFUGL: sonden skal ha naadd noe i det hele tatt. Feil URL eller
// dodt nett gir null svar, og «ingen lekkasjer funnet» ser da noyaktig
// ut som en gronn kjoring.
if (svar.length === 0) {
  console.error('\nFEIL: ingen ressurser ble sondert.')
  process.exit(2)
}
if (sperret.length === svar.length && rate.length === 0) {
  console.log('\nMerk: ALT var sperret. Det er det beste utfallet, men sjekk at'
    + ' URL-en stemmer - en feil host gir samme bilde.')
}
process.exit(lekk.length ? 1 : 0)
