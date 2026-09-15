import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { BP_LONNSKODER, BP_TIL_REGNSKAP } from './bp'
import { STYRINGSKONTI } from './kostnadsniva'

// =====================================================================
// DEFINISJONEN AV LØNNSROMMET BOR TRE STEDER, OG DE MÅ VÆRE ENIGE
//
// Lønnsrommet er `BP-lønn / BP-brutto × brutto`. Hva BP-lønn DEKKER
// bestemmer derfor hvilke konti kostnaden må måles på — og det er
// nettopp den koblingen `kostnadsniva.ts` bygger på.
//
// Men BP-lønna regnes ikke i TypeScript. Den kommer fra SQL-funksjonen
// `bp_maaned_for_mine_stasjoner` (0183), der kodene står som en
// HÅNDKOPIERT literal:
//
//     and l.kode in ('5010', '5012', '5090', '5400', '5401')
//
// Kommentaren over den peker til `BP_LONNSKODER` — men en peker er ikke
// en kobling. Og migrasjonen kan ikke rettes: en kjørt migrasjon endres
// aldri (`AGENTS.md`), så en framtidig endring må komme som en NY
// migrasjon, og da er det enda lettere å glemme den ene av dem.
//
// ---------------------------------------------------------------------
// HVA SOM SKJER NÅR DE SKILLER LAG
//
// Legges 505 til i `BP_TIL_REGNSKAP` alene:
//   STYRINGSKONTI får 505  → kostnaden vokser med sykelønna
//   SQL-en er uendret      → rommet vokser IKKE
//   → ser ut som overforbruk som ikke finnes.
//
// Fjernes en kode fra `BP_TIL_REGNSKAP` alene:
//   STYRINGSKONTI krymper  → kostnaden måles for lavt
//   rommet er uendret
//   → KUNSTIG STORT GRØNT ROM. Den farlige retningen.
//
// Denne vakten gjør begge deler røde.
// =====================================================================

const MIGRASJONER = join(process.cwd(), 'supabase', 'migrations')

/** Kodene SQL-funksjonen faktisk filtrerer BP-lønn på, og hvor de sto. */
function kodeneISql(): { koder: string[]; fil: string } {
  const filer = readdirSync(MIGRASJONER).filter((f) => f.endsWith('.sql')).sort()
  // SISTE definisjon vinner. En ny migrasjon kan redefinere funksjonen,
  // og da er det den som gjelder — ikke 0183.
  let treff: string[] | null = null
  let fant = ''
  for (const f of filer) {
    const tekst = readFileSync(join(MIGRASJONER, f), 'utf8')
    if (!/create or replace function public\.bp_maaned_for_mine_stasjoner/i.test(tekst)) continue
    const m = tekst.match(/l\.kode\s+in\s*\(([^)]*)\)/i)
    if (!m) continue
    treff = [...m[1].matchAll(/'(\d+)'/g)].map((x) => x[1]).sort()
    fant = f
  }
  if (!treff) {
    throw new Error(
      'Fant ingen kodeliste for BP-lønn i migrasjonene. Enten er funksjonen '
      + 'omskrevet, eller så leter denne vakten etter feil mønster — og da '
      + 'måler den ingenting.',
    )
  }
  return { koder: treff, fil: fant }
}

describe('BP-lønnas definisjon', () => {
  it('SQL-en og BP_LONNSKODER filtrerer på de samme kodene', () => {
    // KANARIFUGL FOR HELE TRINN 2. Skiller disse lag, måles kostnaden på
    // et annet kontonivå enn rommet — akkurat feilen trinn 2 retter, men
    // ett lag lenger ned der ingen ser den.
    const sql = kodeneISql()
    expect(sql.koder, `kodelista ble lest av ${sql.fil}`)
      .toEqual([...BP_LONNSKODER].sort())
  })

  it('styringskontiene svarer til nøyaktig de SQL-kodene', () => {
    // Samme påstand, andre vei: hver BP-kode SQL-en teller skal ha en
    // regnskapskonto i styringsnivået, og ingen andre skal være der.
    const { koder } = kodeneISql()
    const konti = koder.map((k) => BP_TIL_REGNSKAP[k])
    expect(konti.every(Boolean), `ukjent BP-kode i SQL: ${koder.join(', ')}`).toBe(true)
    expect([...new Set(konti)].sort()).toEqual([...STYRINGSKONTI].sort())
  })

  it('KANARIFUGL: leseren finner faktisk en liste', () => {
    // En vakt som ikke finner noe, ser ut som en vakt som ikke finner
    // noe galt. `kodeneISql` kaster heller enn å returnere tomt — her
    // bevises det at den treffer på ekte.
    expect(kodeneISql().koder.length).toBeGreaterThan(0)
    expect(kodeneISql().koder).toContain('5012')
  })
})
