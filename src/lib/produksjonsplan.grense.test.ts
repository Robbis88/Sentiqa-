import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// Produksjonsplanen justerer seg mot SALG. Aldri mot svinn.
//
// Robert, 2026-08-24: «produksjonsplanen må ikke bruke svinn rapport til
// å justere seg, den må ta utgangspunkt i det du har anbefalt og måles
// mot salget. Svinn kan bare brukes til kontroll og sjekke om det
// faktisk går ned etter de har brukt produksjonsplan.»
//
// ---------------------------------------------------------------------
// HVORFOR DETTE ER EN VAKT OG IKKE BARE EN KOMMENTAR
//
// Kobles svinn inn i motoren, lukker sløyfa seg om seg selv: planen
// foreslår mindre, det svinner mindre fordi det ble laget mindre, og
// systemet leser sin egen forsiktighet som en bekreftelse. Neste runde
// foreslår enda mindre. Utsolgt koster ingenting i den regnestykket —
// det finnes ikke i svinntallet — så modellen glir mot å produsere for
// lite uten at noe måler prisen.
//
// Salg er det eneste signalet som har begge fortegn i seg: for lite
// laget viser seg som tapt salg, for mye som overskudd. Svinn har bare
// det ene.
//
// SVINN ER KONTROLLEN, UTENFOR SLØYFA. Går svinnet ned etter at en
// stasjon tok planen i bruk, virket den. Det er en måling PÅ systemet,
// ikke en inngang TIL det — og forskjellen forsvinner i det øyeblikket
// noen importerer `synlig_svinn` i en av filene under.
//
// Denne testen leser kilden, ikke oppførselen. Den kan ikke se at noen
// sender svinntall inn som et argument utenfra — men den ser det
// vanlige tilfellet: at noen henter dem her.
// =====================================================================

const ROT = process.cwd()

const MOTOREN = [
  'src/lib/produksjonsplan.ts',
  'src/lib/backtest.ts',
  'src/app/(beskyttet)/produksjonsplan/page.tsx',
  // Lederflaten setter margin- og startprosenten (0149). Den er den
  // NYE doera inn: marginen er et tall et menneske velger, og blir den
  // en dag satt automatisk fra maalt svinn, lukker sloeyfa seg her i
  // stedet for i motoren — mindre margin, mindre svinn, «marginen kan
  // settes ned». Samme feil, ett lag lenger ut.
  'src/app/(beskyttet)/produksjonsplan/plan-tabell.tsx',
  'src/app/(beskyttet)/produksjonsplan/handlinger.ts',
]

/** Kilder som betyr svinn. `svinnterskel` paa stasjoner hoerer ikke med. */
const SVINNKILDER = [
  'synlig_svinn',
  'v_svinn_maaned',
  'v_svinn_dekning',
  'v_svinn_vare_maaned',
  'v_kaffe_svinn',
  'regnskap_usynlig_svinn',
  'nettopris_total',
]

function les(sti: string): string {
  return readFileSync(join(ROT, sti), 'utf8')
}

describe('produksjonsplanen maaler seg mot salg', () => {
  for (const sti of MOTOREN) {
    it(`${sti} henter ikke svinn`, () => {
      const kilde = les(sti)
      const funn = SVINNKILDER.filter((k) => kilde.includes(k))
      expect(funn,
        `${sti} leser ${funn.join(', ')}. Kobles svinn inn i motoren, `
        + 'lukker sloeyfa seg om seg selv: planen foreslaar mindre, det '
        + 'svinner mindre fordi det ble laget mindre, og systemet leser '
        + 'sin egen forsiktighet som en bekreftelse. Utsolgt koster '
        + 'ingenting i det regnestykket. Svinn er kontrollen, utenfor '
        + 'sloeyfa - ikke en inngang til den.',
      ).toEqual([])
    })
  }

  // KANARIFUGL. Uten denne ville testen over vaert groenn ogsaa hvis
  // fila ble flyttet, tømt eller omdoept - og «ingen svinn funnet» ser
  // noeyaktig likt ut enten fila er ren eller fraveerende.
  it('KANARIFUGL: filene finnes, og det er de riktige', () => {
    const merker: Record<string, string> = {
      'src/lib/produksjonsplan.ts': 'lagProduksjonsplan',
      'src/lib/backtest.ts': 'prognose_treff',
      'src/app/(beskyttet)/produksjonsplan/page.tsx': 'produksjonsplan_linjer',
      'src/app/(beskyttet)/produksjonsplan/plan-tabell.tsx': 'medMargin',
      'src/app/(beskyttet)/produksjonsplan/handlinger.ts': 'setProsent',
    }
    for (const [sti, merke] of Object.entries(merker)) {
      const kilde = les(sti)
      expect(kilde.length, `${sti} er tom`).toBeGreaterThan(500)
      expect(kilde, `${sti} inneholder ikke «${merke}» - maaler vakten riktig fil?`)
        .toContain(merke)
    }
  })

  // OG MOTSATT VEI: den maa faktisk maale seg mot salg. En motor som
  // sluttet aa lese salgstall ville ogsaa bestaatt sjekken over.
  it('backtesten maaler forventet mot FAKTISK SALG', () => {
    const kilde = les('src/lib/backtest.ts')
    expect(kilde).toContain('v_butikksalg')
    expect(kilde).toContain('faktisk')
  })

  // MARGINEN ER ET TALL ET MENNESKE SETTER. Den kommer fra
  // `stasjon_produksjon_innstilling`, som ingen automatikk skriver til.
  // Ser vakten en annen kilde skrive den, er sloeyfa i ferd med aa lukke
  // seg gjennom den doeren.
  it('marginen leses fra innstillingstabellen, ikke beregnes', () => {
    const kilde = les('src/app/(beskyttet)/produksjonsplan/page.tsx')
    expect(kilde).toContain('stasjon_produksjon_innstilling')
    // Legges den paa foreslatt i stedet for planlagt, ser backtesten det
    // som at modellen overvurderer salget - og kalibreringen «retter» en
    // feil som ikke finnes ved aa foreslaa mindre.
    expect(kilde).not.toMatch(/foreslatt:\s*medMargin/)
  })

  it('motoren bygger basis paa solgt antall', () => {
    const kilde = les('src/lib/produksjonsplan.ts')
    expect(kilde).toContain('basis')
    // Vaer, trend og arrangement er de tre faktorene. Forsvinner alle
    // tre, er det ikke lenger den motoren denne vakten ble skrevet for.
    expect(kilde).toContain('vaerfaktor')
    expect(kilde).toContain('trendfaktor')
  })
})
