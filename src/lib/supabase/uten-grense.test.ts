import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { maaVaereHele, TAK } from './datobolker'

// =====================================================================
// EN SPØRRING UTEN GRENSE ER EN SPØRRING SOM KAN LYVE
//
// PostgREST returnerer tusen rader og sier ingenting. Rutinesida hadde
// ikke én `.limit()`, og utføringene for dagens vaktdatoer — over alle
// stasjoner — ligger rundt tusen. Da taket traff, falt Bønes sine
// avhukinger utenfor, og sida meldte **68 rutiner igjen** som folk
// nettopp hadde gjort ferdig.
//
// Det ser ikke ut som en feil. Det ser ut som at ingen har gjort jobben
// sin — og det er den verste formen: tallet er troverdig.
//
// Samme fella står i migrasjonshistorikken tre ganger (`0090`, `0166`,
// `0175`) og i `hentPerDato` sin egen kommentar. Fjerde gang er ikke
// uflaks; det er en regel som mangler en vakt.
//
// ---------------------------------------------------------------------
// HVA DENNE MÅLER, OG HVA DEN IKKE GJØR
//
// Den teller `.select(` i sidefiler som IKKE har en `.limit(`, en
// `.maybeSingle(`, en `.single(` eller går gjennom `hentPerDato`. Den
// beviser ikke at grensen er riktig satt — bare at noen har tatt
// stilling til at det finnes en.
//
// Feiler hvis tallet VOKSER. Det er mange fra før, og en storrengjøring
// nå ville vært en diff ingen kunne lese. Men ingen nye skal komme til.
// =====================================================================

const ROT = process.cwd()
const FASIT = join(ROT, 'src', 'lib', 'supabase', 'grensefasit.json')

function tsFiler(mappe: string): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...tsFiler(sti))
    else if (/\.tsx?$/.test(rad.name) && !/\.test\.tsx?$/.test(rad.name)) ut.push(sti)
  }
  return ut
}

/** `.from('x').select(...)`-kjeder uten en grense i samme kjede. */
export function utenGrense(kilde: string): string[] {
  const ut: string[] = []
  // En kjede slutter ved `,` eller `)` på toppnivå — her holder det å
  // lese fram til linjeslutt-mønsteret PostgREST-kall faktisk har:
  // `.overrideTypes<…>()`, `,` på slutten, eller `\n\n`.
  for (const m of kilde.matchAll(/\.from\((['"`])([^'"`]+)\1\)([\s\S]{0,900}?)(?=\n\s*(?:\]|\)|const |return |\/\/|$))/g)) {
    const kjede = m[3]
    if (!/\.select\(/.test(kjede)) continue
    if (/\.limit\(|\.range\(|\.maybeSingle\(|\.single\(|head:\s*true/.test(kjede)) continue
    ut.push(m[2])
  }
  return ut
}

const filer = tsFiler(join(ROT, 'src'))
  .map((f) => ({ f, kilde: readFileSync(f, 'utf8') }))
const naa = filer.reduce((s, { kilde }) => s + utenGrense(kilde).length, 0)

describe('målingen forstår det den teller', () => {
  it('teller en select uten grense', () => {
    expect(utenGrense("await sb.from('rutiner').select('id')\n")).toEqual(['rutiner'])
  })

  it('teller ikke en som har grense', () => {
    expect(utenGrense("await sb.from('rutiner').select('id').limit(500)\n")).toEqual([])
  })

  it('teller ikke en enkeltrad', () => {
    expect(utenGrense("await sb.from('rutiner').select('id').eq('id', x).maybeSingle()\n")).toEqual([])
    expect(utenGrense("await sb.from('rutiner').select('id').eq('id', x).single()\n")).toEqual([])
  })

  it('teller ikke en ren telling', () => {
    expect(utenGrense("await sb.from('x').select('*', { count: 'exact', head: true })\n")).toEqual([])
  })

  it('teller ikke et skriv', () => {
    expect(utenGrense("await sb.from('x').insert({ a: 1 })\n")).toEqual([])
  })
})

describe('grensevakten', () => {
  it('den ser fortsatt filene', () => {
    // Peker stien feil, blir lista tom og skrallen grønn uten å ha sett
    // en eneste spørring.
    expect(filer.length, 'fant ingen .ts-filer under src/').toBeGreaterThan(300)
  })

  it('antallet har ikke vokst', () => {
    if (process.env.OPPDATER_FASIT === '1') {
      writeFileSync(FASIT, `${JSON.stringify({ utenGrense: naa }, null, 2)}\n`)
      return
    }
    const fasit = JSON.parse(readFileSync(FASIT, 'utf8')) as { utenGrense: number }
    expect(
      naa,
      `Spørringer uten grense har gått fra ${fasit.utenGrense} til ${naa}.\n\n`
      + `PostgREST kutter på ${TAK} rader UTEN å feile, og et avkortet svar `
      + 'ser ut som ekte tall. Bønes meldte 68 rutiner igjen som folk nettopp '
      + 'hadde gjort ferdig.\n\n'
      + 'Sett en generøs `.limit()` og send svaret gjennom `maaVaereHele`, '
      + 'eller bruk `hentPerDato` for en datoserie.\n\n'
      + 'Er økningen med vilje: OPPDATER_FASIT=1 npx vitest run src/lib/supabase',
    ).toBeLessThanOrEqual(fasit.utenGrense)
  })
})

describe('maaVaereHele', () => {
  it('slipper gjennom et svar under grensen', () => {
    expect(maaVaereHele({ data: [1, 2, 3], error: null }, 'noe', 10)).toEqual([1, 2, 3])
  })

  it('kaster når svaret fyller grensen', () => {
    const data = Array.from({ length: 10 }, (_, i) => i)
    expect(() => maaVaereHele({ data, error: null }, 'utførte rutiner', 10))
      .toThrow(/avkortet/)
  })

  it('kaster på feil, i stedet for å gi tom liste', () => {
    // En lesefeil som blir til `[]` er den samme løgnen som avkorting:
    // null rader ser ut som «ingenting er gjort».
    expect(() => maaVaereHele({ data: null, error: { message: 'nei' } }, 'utførte rutiner'))
      .toThrow(/Kunne ikke lese utførte rutiner/)
  })

  it('tåler tomt svar uten feil', () => {
    expect(maaVaereHele({ data: null, error: null }, 'noe', 10)).toEqual([])
  })
})
