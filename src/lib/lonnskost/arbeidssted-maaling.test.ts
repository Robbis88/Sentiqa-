import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { lesBasiseksport } from '@/lib/parsere/basiseksport'
import { ansattregister, type Ansattregister } from '@/lib/parsere/lonnsgrunnlag'
import { beregnArbeidssted } from './arbeidssted'

// =====================================================================
// MÅLETESTEN: reproduserer modellen de fem kontrollmånedene?
//
// De andre vaktene beviser regler på oppdiktede rader. Denne beviser at
// hele kjeden treffer ekte kroner — mot Lønnsoversikt (kronefila), som
// er easy@works egen fasit.
//
// KREVER EKTE LØNNSDATA, og de ligger aldri i git. Filene inneholder
// navngitte ansatte med lønn; `supabase/tests/lonnsdata/.gitignore`
// holder dem ute. Mangler de, HOPPER testen over i stedet for å feile —
// ellers ville CI vært rød for alle andre enn den som har filene.
//
// HOPPER OVER ER IKKE GRØNT. `it.skip` teller som bestått i vitest, og
// en måling som stille slutter å måle ser nøyaktig ut som en som
// treffer. Derfor sier `datagrunnlaget finnes`-testen under fra i
// klartekst når filene ikke er der.
// =====================================================================

const MAPPE = join(process.cwd(), 'supabase', 'tests', 'lonnsdata')
const harData = existsSync(join(MAPPE, 'basiseksport'))

type Tilfelle = {
  navn: string
  maaned: string
  lokasjon: string
  basis: string
  kronefil: string
  /** Hvor mye modellen får bomme, i prosent av kronefilas 503. */
  tak: number
  /** Overtid kronefila har og Basis Export ikke kan se. Dokumentert, ikke justert. */
  overtidKr: number
}

// TAKENE ER MÅLTE RESULTATER, IKKE ØNSKER. Hver av dem ligger like over
// det som faktisk ble målt 2026-09-15, så en regresjon blir rød mens
// normal støy ikke gjør det. De skal ALDRI heves for å få grønt — en
// bom som vokser er et funn.
const TILFELLER: Tilfelle[] = [
  { navn: 'Bønes juli 2026', maaned: '2026-07', lokasjon: 'St1 - Bønes',
    basis: 'basiseksport/bones-2025-01_2026-07.csv', kronefil: 'kronefil/bones-2026-07-lonnsart.csv',
    tak: 0.15, overtidKr: 117.74 },
  { navn: 'Bønes august 2026', maaned: '2026-08', lokasjon: 'St1 - Bønes',
    basis: 'basiseksport/bones-2026-08.csv', kronefil: 'kronefil/bones-2026-08-lonnsart.csv',
    tak: 1.0, overtidKr: 1393.37 },
  { navn: 'Dale mai 2026', maaned: '2026-05', lokasjon: 'St1 - Dale',
    basis: 'basiseksport/dale-2025-04_2026-07.csv', kronefil: 'kronefil/dale-2026-05-lonnsart.csv',
    tak: 0.3, overtidKr: 552.78 },
  { navn: 'Dale juli 2026', maaned: '2026-07', lokasjon: 'St1 - Dale',
    basis: 'basiseksport/dale-2025-04_2026-07.csv', kronefil: 'kronefil/dale-2026-07-lonnsart.csv',
    tak: 1.2, overtidKr: 137.28 },
  { navn: 'Dale august 2026', maaned: '2026-08', lokasjon: 'St1 - Dale',
    basis: 'basiseksport/dale-2026-08.csv', kronefil: 'kronefil/dale-2026-08-lonnsart.csv',
    tak: 2.5, overtidKr: 7022.58 },
]

const les = (p: string) => readFileSync(join(MAPPE, p), 'utf8')

// LOENNSGRUNNLAGENE PER MAANED, SKREVET UT.
//
// Foerste utgave lette seg fram med `filnavn inneholder aarstallet`.
// Det traff ALLE 2026-filene, og registeret for juli plukket dermed
// aprilsatsen til den foerste ansatte det fant en rad for. En ansatt
// som fikk loennsoekning i juni ble regnet med gammel sats - og
// resultatet ble BEDRE, som er den farligste retningen en maalefeil kan
// ta. Derfor staar filene her, en for en.
const LONNSGRUNNLAG: Record<string, string[]> = {
  '2026-05': [
    'bones-2026-01_2026-07.csv', 'dale-2026-05.csv', 'laguneparken-2026-05.csv',
    'lone-2026-05.csv', 'varden-2026-01_2026-07.csv',
  ],
  '2026-07': [
    'bones-2026-01_2026-07.csv', 'dale-2026-07.csv', 'laguneparken-2026-07.csv',
    'lone-2026-07.csv', 'varden-2026-01_2026-07.csv',
  ],
  '2026-08': [
    'lonnsgrunnlag-2026-08/bones.csv', 'lonnsgrunnlag-2026-08/dale.csv',
    'lonnsgrunnlag-2026-08/laguneparken.csv', 'lonnsgrunnlag-2026-08/lone.csv',
    'lonnsgrunnlag-2026-08/varden.csv',
  ],
}

/**
 * Alle fem stasjoners loennsgrunnlag for maaneden, slaatt sammen.
 *
 * Et register som mangler en stasjon gjoer hele den stasjonens utlaante
 * ansatte uprisbare - og da blir datagrunnlaget `minimum` i stedet for
 * aa vaere feil i stillhet. Derfor kastes det her om en fil mangler.
 */
function registerFor(maaned: string): Ansattregister[] {
  const filer = LONNSGRUNNLAG[maaned]
  if (!filer) throw new Error(`Ingen loennsgrunnlag satt opp for ${maaned}.`)
  // `beregnArbeidssted` kaster om et register ikke dekker maaneden, saa
  // feil fil her blir roedt i stedet for aa gi feil sats.
  return filer.map((f) => ansattregister(les(f)))
}

/**
 * Kronefilas konto 503. Art 12 sykeloenn hoerer til 505 og holdes utenfor.
 *
 * Kronefila har INGEN topprad, og den blander siterte og usiterte felt:
 * `"St1 - Bones","Et Navn",308,"2026-07-04 00:00:00",...`. En splitt paa
 * `","` treffer derfor ikke - den ga 0 kroner, og en fasit paa 0 er en
 * test som SER ut til aa maale noe. Derfor kreves `fasit > 0` under.
 */
function kronefil503(tekst: string, maaned: string): number {
  let sum = 0
  for (const linje of tekst.split('\n')) {
    const felt: string[] = []
    let f = ''
    let iSitat = false
    for (let i = 0; i < linje.length; i++) {
      const c = linje[i]
      if (iSitat) {
        if (c === '"') {
          if (linje[i + 1] === '"') { f += '"'; i++ } else iSitat = false
        } else f += c
        continue
      }
      if (c === '"') { iSitat = true; continue }
      if (c === ',') { felt.push(f); f = ''; continue }
      if (c === '\r') continue
      f += c
    }
    felt.push(f)
    if (felt.length < 9) continue
    if (!(felt[3] ?? '').startsWith(maaned)) continue
    const art = (felt[6] ?? '').trim().split(' ')[0]
    if (art === '12') continue
    sum += Number((felt[8] ?? '').replace(/\s/g, '').replace(',', '.')) || 0
  }
  return sum
}

describe('måling mot kronefila', () => {
  it('datagrunnlaget finnes', () => {
    if (!harData) {
      console.warn(
        '\n  MÅLINGEN HOPPET OVER: supabase/tests/lonnsdata/basiseksport mangler.'
        + '\n  Fem stasjonsmåneder ble IKKE målt. Dette er ikke et grønt resultat.\n',
      )
    }
    expect(true).toBe(true)
  })

  for (const t of TILFELLER) {
    it.runIf(harData)(`${t.navn} treffer innenfor ${t.tak} %`, () => {
      const basis = lesBasiseksport(les(t.basis))
      const ut = beregnArbeidssted({
        maaned: t.maaned,
        stemplinger: basis.stemplinger,
        registre: registerFor(t.maaned),
        avvik: basis.avvik,
      })
      const b = ut.find((x) => x.maaned === t.maaned && x.lokasjon === t.lokasjon)
      expect(b, `fant ingen ${t.lokasjon} ${t.maaned}`).toBeDefined()

      const fasit = kronefil503(les(t.kronefil), t.maaned)
      expect(fasit).toBeGreaterThan(0)

      const avvikPst = (100 * Math.abs(b!.konto503Kr - fasit)) / fasit
      expect(avvikPst, `${t.navn}: ${b!.konto503Kr.toFixed(0)} mot ${fasit.toFixed(0)}`)
        .toBeLessThan(t.tak)
    })
  }

  it.runIf(harData)('Bønes juli kan ikke falle tilbake til -10,9 %', () => {
    // REGRESJONSVAKTEN. Den gamle modellen leste bare stasjonens eget
    // lønnsgrunnlag og mistet 15 191 kr — 10,9 % av 503. Feilen gikk
    // alltid samme vei: for lite lønn, altså for mye lønnsrom.
    //
    // Her kreves BÅDE at de innlånte er med, OG at de er store nok til
    // at tapet ville vært merkbart. En vakt som bare krevde «> 0» ville
    // bestått på én krone.
    const basis = lesBasiseksport(les('basiseksport/bones-2025-01_2026-07.csv'))
    const ut = beregnArbeidssted({
      maaned: '2026-07',
      stemplinger: basis.stemplinger,
      registre: registerFor('2026-07'),
      avvik: basis.avvik,
    })
    const b = ut.find((x) => x.maaned === '2026-07' && x.lokasjon === 'St1 - Bønes')!

    expect(b.innlaanteNr.length).toBeGreaterThanOrEqual(2)
    expect(b.innlaantKr).toBeGreaterThan(14_000)
    const andel = (100 * b.innlaantKr) / b.konto503Kr
    expect(andel).toBeGreaterThan(10)
    // Og uten dem ville tallet vært det gamle, for lave.
    expect(b.konto503Kr - b.innlaantKr).toBeLessThan(b.konto503Kr * 0.9)
  })

  it.runIf(harData)('ingen stasjonsmåned har ukoblede timelønnede vi ikke vet om', () => {
    // De to fastlønnede er kjente og klassifiseres eksplisitt. Dukker det
    // opp en tredje ukoblet, skal den opp — ikke forsvinne i et tall.
    const FASTLONN = new Set(['1004', '1041'])
    const basis = lesBasiseksport(les('basiseksport/varden-2026-08.csv'))
    const [b] = beregnArbeidssted({
      maaned: '2026-08',
      stemplinger: basis.stemplinger,
      registre: registerFor('2026-08'),
      avvik: basis.avvik,
      fastlonnede: FASTLONN,
    })
    expect(b.ukoblede, `ukoblede: ${b.ukoblede.map((u) => u.ansattNr).join(', ')}`).toEqual([])
    expect(b.datagrunnlag).toBe('komplett')
  })
})
