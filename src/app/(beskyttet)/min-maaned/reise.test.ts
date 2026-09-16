import { describe, expect, it } from 'vitest'
import { maanedsstatus, naavaerendeFase, reisen } from './reise'
import { byggOkonomibilde, type Bildeinput, type Dekning, type Felt } from '@/lib/okonomi/bilde'
import type { Lonnsrom } from '@/lib/lonnskost/rom'

// =====================================================================
// STRIPA SKAL SI DET SOM ER TILFELLET, IKKE DET SOM SER PENT UT
// =====================================================================
//
// Tre feller, og alle tre gir et bilde som ser riktig ut:
//
//   «PROGNOSE: mangler» paa en avlagt maaned paastaar at maaneden aldri
//   hadde et anslag. Den hadde det - fasiten har bare tatt over.
//
//   «PLAN: har» paa en maaned uten BP ville skjult at det ikke finnes
//   noen ramme aa maale mot. Et hakemerke er en paastand.
//
//   Feil naavaerende steg gir feil overskrift, og overskriften er det
//   eneste mange leser.
//
// Bildene bygges med `byggOkonomibilde`, ikke skrevet for haand: da maa
// kildene vaere de motoren faktisk setter.
// =====================================================================

const ANDEL = 383285 / 1201000

const ROM = (o: Partial<Lonnsrom> = {}): Lonnsrom => ({
  maaned: '2026-08',
  bruttoKr: 1201000,
  anslaatt: false,
  lonnsandel: ANDEL,
  romKr: 383285,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 4200000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
  ...o,
})

const DEKNING = (regnskap: boolean): Dekning => ({
  salgsdager: { har: 31, av: 31 },
  bilvaskUker: { har: 0, av: 0 },
  lonnsfil: true,
  regnskap,
  mangler: [],
  retningPaaFeil: 'ukjent',
})

const bilde = (o: Partial<Bildeinput> = {}) => byggOkonomibilde({
  stasjonId: 's1',
  maaned: '2026-08',
  rom: ROM(),
  regnskap: null,
  easyatworkLonnKr: 371000,
  easyatworkStyringskostKr: 360000,
  dagligOmsetningKr: 4150000,
  dekning: DEKNING(false),
  ...o,
})

/** Feltene siden viser. Samme utvalg som `page.tsx`. */
const felter = (b: ReturnType<typeof bilde>): Felt[] => [
  b.omsetning, b.brutto, b.lonnsrom, b.styringskost, b.lonn,
  b.bpLonn, b.paavirkbarDrift, b.royalty,
]

const tilstand = (b: ReturnType<typeof bilde>) =>
  Object.fromEntries(reisen(b, felter(b)).map((f) => [f.id, f.tilstand]))

describe('reisen leser tre felt og finner ikke paa noe', () => {
  it('aapen maaned med tidlige tall: plan og prognose, ingen fasit', () => {
    const b = bilde({ rom: ROM({ anslaatt: true }) })
    expect(tilstand(b)).toEqual({ plan: 'har', prognose: 'har', fasit: 'mangler' })
    expect(naavaerendeFase(reisen(b, felter(b)))?.id).toBe('prognose')
  })

  it('AVLAGT MAANED: prognosen er ERSTATTET, ikke manglende', () => {
    // Ingen felt staar som `prognose` naar regnskapet har tatt over.
    // Sto steget da som `mangler`, ville stripa paastaatt at maaneden
    // aldri hadde et anslag - en paastand om noe vi ikke vet.
    const b = bilde({
      dekning: DEKNING(true),
      regnskap: {
        omsetningKr: 4200000, bruttoKr: null, lonnKr: 390000,
        styringskostKr: 380000, royaltyKr: 420000, paavirkbarDriftKr: 96000,
      },
    })
    expect(felter(b).some((f) => f.kilde === 'prognose')).toBe(false)
    expect(tilstand(b)).toEqual({ plan: 'har', prognose: 'erstattet', fasit: 'har' })
    expect(naavaerendeFase(reisen(b, felter(b)))?.id).toBe('fasit')
  })

  it('UTEN BP staar planen som manglende - ogsaa naar regnskapet er avlagt', () => {
    // Et hakemerke er en paastand. En maaned uten BP HAR ingen ramme aa
    // maale loenna mot, og det er verdt aa vite - ikke noe aa skjule.
    const b = bilde({
      rom: ROM({ bpLonnKr: null, romKr: null, lonnsandel: null }),
      dekning: DEKNING(true),
      regnskap: {
        omsetningKr: 4200000, bruttoKr: null, lonnKr: 390000,
        styringskostKr: 380000, royaltyKr: null, paavirkbarDriftKr: null,
      },
    })
    expect(b.bpLonn.kilde).toBe('mangler')
    expect(tilstand(b)).toEqual({ plan: 'mangler', prognose: 'erstattet', fasit: 'har' })
  })

  it('bare BP, ingen tall inne: planen alene', () => {
    const b = bilde({
      rom: ROM({ bruttoKr: null, romKr: null, anslaatt: true }),
      easyatworkLonnKr: null,
      easyatworkStyringskostKr: null,
      dagligOmsetningKr: null,
    })
    expect(tilstand(b)).toEqual({ plan: 'har', prognose: 'mangler', fasit: 'mangler' })
    expect(naavaerendeFase(reisen(b, felter(b)))?.id).toBe('plan')
  })

  it('hvert steg har en forklaring, og de er ulike per tilstand', () => {
    const aapen = reisen(bilde({ rom: ROM({ anslaatt: true }) }), [])
    const avlagt = reisen(bilde({ dekning: DEKNING(true) }), [])
    for (const f of [...aapen, ...avlagt]) expect(f.forklaring.length).toBeGreaterThan(10)
    // `erstattet` og `mangler` skal ikke lese likt paa prognosesteget -
    // det er hele poenget med at de er to tilstander.
    expect(aapen[1].forklaring).not.toBe(avlagt[1].forklaring)
  })

  it('KANARIFUGL: stripa ser at et felt blir et anslag', () => {
    // Uten dette kunne `reisen` returnert faste tilstander og hver
    // paastand over ville staatt groenn paa et bilde som ikke ble lest.
    const uten = bilde({ easyatworkLonnKr: null, easyatworkStyringskostKr: null, dagligOmsetningKr: null,
      rom: ROM({ anslaatt: false }) })
    expect(tilstand(uten).prognose).toBe('mangler')
    const med = bilde({ rom: ROM({ anslaatt: true }) })
    expect(tilstand(med).prognose).toBe('har')
  })

  it('KANARIFUGL: naavaerendeFase gir null naar ingenting er naadd', () => {
    const b = bilde({
      rom: ROM({ bruttoKr: null, romKr: null, bpLonnKr: null, lonnsandel: null }),
      easyatworkLonnKr: null,
      easyatworkStyringskostKr: null,
      dagligOmsetningKr: null,
    })
    expect(naavaerendeFase(reisen(b, felter(b)))).toBeNull()
  })
})

// =====================================================================
// STATUSLINJA — ÉN SETNING I STEDET FOR EN STRIPE MED TRE
// =====================================================================
//
// Reisestripa svarer paa «kan jeg stole paa tallet». Det er ikke
// spoersmaalet den som aapner sida har, saa den flyttet under «Vis
// grunnlaget» og denne ene linja baerer det foerste skjerm trenger.
//
// TO AVLESNINGER, INGEN NY REGEL. `dekning.regnskap` og
// `dekning.salgsdager` — og nevneren der er `muligeSalgsdager` sin egen,
// ikke maanedens lengde.
// =====================================================================
describe('maanedsstatus', () => {
  it('avlagt maaned: ferdig, og INGEN dagsteller', () => {
    // `byggDekning` melder ingen mangler for en avlagt maaned - regnskapet
    // er fasit. Da ville en dagsteller vaert en opplysning om noe som
    // ikke lenger betyr noe.
    const s = maanedsstatus(bilde({ dekning: DEKNING(true) }))
    expect(s).toContain('ferdig')
    expect(s).not.toMatch(/\d+ av \d+/)
  })

  it('paagaaende maaned: teller dagene som KUNNE hatt tall', () => {
    const b = bilde({
      dekning: { ...DEKNING(false), salgsdager: { har: 15, av: 15 } },
    })
    expect(maanedsstatus(b)).toBe('Måneden pågår. 15 av 15 mulige dager har tall.')
  })

  it('en maaned fram i tid paastaar ikke at den paagaar', () => {
    // `muligeSalgsdager` gir 0 for en maaned som ikke har begynt. «0 av 0
    // mulige dager har tall» ville vaert sant og ubrukelig.
    const b = bilde({ dekning: { ...DEKNING(false), salgsdager: { har: 0, av: 0 } } })
    expect(maanedsstatus(b)).toBe('Måneden har ikke begynt.')
  })

  it('KANARIFUGL: statusen leser dekningen, ikke en fast tekst', () => {
    const a = maanedsstatus(bilde({ dekning: DEKNING(true) }))
    const b = maanedsstatus(bilde({
      dekning: { ...DEKNING(false), salgsdager: { har: 3, av: 15 } },
    }))
    expect(a).not.toBe(b)
    expect(b).toContain('3 av 15')
  })
})
