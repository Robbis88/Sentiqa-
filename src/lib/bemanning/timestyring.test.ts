import { describe, expect, test } from 'vitest'
import { styring, styringstekst } from './timestyring'

// Dale i august, med rammen etter Sissel-justeringen. Tallene er valgt
// slik at hvert ledd kan regnes for hånd:
//
//   ramme 1000, BP-brutto 800 000, fjorårets andel 0,60
//   brutto hittil 420 000  →  framskrevet 700 000  (12,5 % under plan)
//   opptjent hel måned = 1000 × 700/800 = 875
const GRUNN = {
  rammeTimer: 1000,
  brukteTimer: 700,
  bpBruttoKr: 800000,
  bruttoHittilKr: 420000,
  ifjorAndel: 0.6,
  dagerMedSalg: 20,
  dagerIMaaned: 31,
}

describe('timestyring midt i måneden', () => {
  test('framskriver på fjorårets kurve, ikke på dager', () => {
    const s = styring(GRUNN)!
    expect(s.framskrevetBrutto).toBe(700000)
    expect(s.motBpPst).toBe(-12.5)
    // 875 opptjent − 700 brukt = 175 igjen på 11 dager.
    expect(s.timerIgjen).toBe(175)
    expect(s.dagerIgjen).toBe(11)
    expect(s.perDag).toBe(15.9)
  })

  test('DAGER DELT PÅ DAGER GIR ET ANNET SVAR', () => {
    // 20/31 = 0,645 mot fjorårets 0,60. Samme brutto hittil, men
    // framskrivingen blir 651 000 i stedet for 700 000 — og timene
    // igjen faller fra 175 til 114.
    //
    // Det er hele grunnen til at andelen kommer fra fjoråret: helger og
    // lønningsdager ligger ikke jevnt, og en stasjon med travel første
    // halvdel ville sett ut til å ligge foran.
    const lineaert = styring({ ...GRUNN, ifjorAndel: 20 / 31 })!
    expect(lineaert.timerIgjen).not.toBe(175)
    expect(lineaert.timerIgjen).toBe(114)
  })

  test('timene kan være brukt opp, og da sies det rett ut', () => {
    const s = styring({ ...GRUNN, brukteTimer: 950 })!
    expect(s.timerIgjen).toBe(-75)
    const t = styringstekst(s)
    expect(t).toMatch(/brukt opp/)
    expect(t).toContain('75')
    expect(t).toContain('11 dager')
    // Ikke pakket inn: «ligger noe over» faar ingen til aa justere noe.
    expect(t).not.toMatch(/noe over|litt over/)
  })

  test('en avsluttet måned er et oppgjør, ikke en styring', () => {
    // «Timer igjen» av en måned som er slutt er ikke et tall noen kan
    // bruke — og det ville stått side om side med totalen og sett ut
    // som en motsigelse.
    expect(styring({ ...GRUNN, dagerMedSalg: 31 })).toBeNull()
    expect(styring({ ...GRUNN, dagerMedSalg: 31, dagerIMaaned: 31 })).toBeNull()
  })

  test('uten fjorårets kurve finnes ingen framskriving', () => {
    // Lineært som reserve ville gitt en ny stasjon et anslag som ser ut
    // som en måling, og den feilen peker mot å bemanne etter et tall
    // ingen har stått for.
    expect(styring({ ...GRUNN, ifjorAndel: null })).toBeNull()
    expect(styring({ ...GRUNN, ifjorAndel: 0 })).toBeNull()
  })

  test('mangler et ledd, finnes ikke svaret', () => {
    expect(styring({ ...GRUNN, rammeTimer: null })).toBeNull()
    expect(styring({ ...GRUNN, rammeTimer: 0 })).toBeNull()
    expect(styring({ ...GRUNN, brukteTimer: null })).toBeNull()
    expect(styring({ ...GRUNN, bpBruttoKr: 0 })).toBeNull()
    expect(styring({ ...GRUNN, bruttoHittilKr: null })).toBeNull()
    expect(styring({ ...GRUNN, dagerMedSalg: null })).toBeNull()
  })

  test('trenden står først, fordi den forklarer tallet etter', () => {
    const s = styring(GRUNN)!
    const t = styringstekst(s)
    expect(t.indexOf('under plan')).toBeLessThan(t.indexOf('timer igjen'))
    expect(t).toContain('12,5 %')
    expect(t).toContain('15,9 timer per dag')
  })

  test('er bruttoen på plan, nevnes ikke trenden', () => {
    // En setning som alltid sier noe om trenden, sier ingenting naar
    // den faktisk betyr noe.
    const s = styring({ ...GRUNN, bruttoHittilKr: 480000 })!
    expect(s.motBpPst).toBe(0)
    expect(styringstekst(s)).not.toMatch(/plan/)
  })
})
