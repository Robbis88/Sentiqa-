import { describe, expect, it } from 'vitest'
import { tilA1Kort } from './a1-kort'
import { a1ForStasjonsmaaned } from './a1'
import type { Arbeidsrad, Arbeidstidsmaaned } from './arbeidstid'
import type { Kilder, Registerrad } from './kilder'
import type { Avtaleoppslag } from './prisbarhet'

const BONES = 'sss-bones'
const LONE = 'sss-lone'
const INGEN: Avtaleoppslag = () => null

const rad = (o: Partial<Arbeidsrad> = {}): Arbeidsrad => ({
  stasjonId: BONES, kildeMaaned: '2026-08', lokasjon: 'St1 - Bønes',
  ansattNr: '1009', ansattNavn: 'Ola', dato: '2026-08-03', fraDato: '2026-08-03',
  fraTid: '07:00', tilTid: '15:00', minutter: 480, lengdeTimer: 8,
  betalt: true, avvikGrunn: null, importJobbId: null, ...o,
})
const reg = (o: Partial<Registerrad> = {}): Registerrad => ({
  stasjonId: BONES, ansattNr: '1009', navn: 'Ola',
  timesats: 210, betalingsfrekvens: 'time', ...o,
})
const arbeidstid = (rader: Arbeidsrad[]): Arbeidstidsmaaned => {
  const b = rader.filter((r) => r.betalt)
  return {
    maaned: '2026-08', rader,
    prisbareMinutter: b.filter((r) => !r.avvikGrunn).reduce((s, r) => s + r.minutter, 0),
    avvisteMinutter: b.filter((r) => r.avvikGrunn).reduce((s, r) => s + r.minutter, 0),
    betalteMinutter: b.reduce((s, r) => s + r.minutter, 0),
    personer: [...new Set(b.map((r) => r.ansattNr))].sort(),
  }
}
const begge = (rader: Arbeidsrad[], egne: Registerrad[], kryss: Registerrad[] = []): Kilder => ({
  status: 'begge', stasjonId: BONES, maaned: '2026-08',
  arbeidstid: arbeidstid(rader),
  register: { maaned: '2026-08', egne, kryss, uslaatteNumre: [] },
})
const kort = (k: Kilder, a: Avtaleoppslag = INGEN) =>
  tilA1Kort(a1ForStasjonsmaaned(k, a))

describe('kildemangel har bokstavelig talt ikke et kronefelt', () => {
  it('mangler_register bærer timer og personer, men ingen kroner', () => {
    const k = kort({
      status: 'mangler_register', stasjonId: BONES, maaned: '2026-08',
      arbeidstid: arbeidstid([rad()]), timer: 698.8, personer: 13, kryss: [],
    })
    expect(k.status).toBe('kildemangel')
    if (k.status !== 'kildemangel') return
    expect(k.mangler).toBe('register')
    expect(k.timer).toBe(698.8)
    expect(k.personer).toBe(13)
    expect(Object.keys(k)).not.toContain('kroner')
  })

  it('mangler_arbeidstid', () => {
    const k = kort({
      status: 'mangler_arbeidstid', stasjonId: BONES, maaned: '2026-08',
      register: { maaned: '2026-08', egne: [reg()], kryss: [], uslaatteNumre: [] },
    })
    expect(k.status === 'kildemangel' && k.mangler).toBe('arbeidstid')
  })

  it('mangler_begge', () => {
    const k = kort({ status: 'mangler_begge', stasjonId: BONES, maaned: '2026-08' })
    expect(k.status === 'kildemangel' && k.mangler).toBe('begge')
  })

  it('INGEN kildemangel serialiseres med et tall som kan leses som kroner', () => {
    for (const k of [
      kort({ status: 'mangler_begge', stasjonId: BONES, maaned: '2026-08' }),
      kort({
        status: 'mangler_arbeidstid', stasjonId: BONES, maaned: '2026-08',
        register: { maaned: '2026-08', egne: [reg()], kryss: [], uslaatteNumre: [] },
      }),
    ]) {
      expect(JSON.stringify(k)).not.toContain('kroner')
      expect(JSON.stringify(k)).not.toContain('503')
    }
  })
})

describe('timer regnes av minutter, aldri motsatt', () => {
  it('runder til to desimaler fra minutter', () => {
    const k = kort(begge([rad({ minutter: 41926 })], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    // 41 926 / 60 = 698,7666... -> 698,77
    expect(k.betalteTimer).toBe(698.77)
  })

  it('andelPriset er null når det ikke finnes betalt tid', () => {
    const k = kort(begge([rad({ betalt: false, minutter: 30 })], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.andelPriset).toBeNull()
  })

  it('andelPriset regnes av minutter', () => {
    const k = kort(begge([
      rad({ minutter: 37846 }),
      rad({ ansattNr: '9999', ansattNavn: 'Ukjent', minutter: 4080 }),
    ], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.betalteTimer).toBe(698.77)
    expect(k.andelPriset).toBe(90.3)
  })

  it('andelPriset regnes av minutter OGSÅ der de to veiene skiller lag', () => {
    // Boenes-tallene over skiller ikke: 37 846 / 41 926 gir 90,3 % enten
    // man deler minutter eller toDesimalers timer. Injeksjonen
    // «andelPriset regnes av timer» kom derfor groenn tilbake, og jeg
    // kalte den foerst uobserverbar. Det var feil: talt over 59 003
    // realistiske stasjonsmaaneder skiller de to veiene lag i 103 av dem.
    // Dette er en av dem - maalt, ikke konstruert bakover:
    //
    //   26 422 / 30 008          = 88,0 %   (riktig)
    //   440,37 t / 500,13 t      = 88,1 %   (avrundet grunnlag)
    //
    // Et halvt prosentpoeng er ikke mye. Poenget er at tallet da ikke
    // lenger er utledet av beregningsgrunnlaget, og den regelen er den
    // samme her som i motoren.
    const k = kort(begge([
      rad({ minutter: 26422 }),
      rad({ ansattNr: '9999', ansattNavn: 'Ukjent', minutter: 3586 }),
    ], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.andelPriset).toBe(88)
  })
})

describe('de to aksene holdes adskilt', () => {
  it('en UBETALT dublett står som dataavvik uten å bli upriset', () => {
    const u = rad({ betalt: false, minutter: 30, fraTid: '11:00', tilTid: '11:30' })
    const k = kort(begge([rad(), u, { ...u }], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.status).toBe('komplett')
    expect(k.dataavvik.dubletter).toBe(1)
    expect(k.upriseteTimer).toBe(0)
  })

  it('en BETALT dublett treffer begge aksene', () => {
    const d = rad({ minutter: 480 })
    const k = kort(begge([d, { ...d }], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.status).toBe('minimum')
    expect(k.dataavvik.dubletter).toBe(1)
    expect(k.upriseteTimer).toBe(8)
  })

  it('avviste vakter telles for seg', () => {
    const k = kort(begge([rad(), rad({ avvikGrunn: 'lengde', fraTid: '09:10', tilTid: '11:00', minutter: 110 })], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.dataavvik.avvisteVakter).toBe(1)
  })
})

describe('kortet er en mapper — tallene slippes gjennom uendret', () => {
  it('kroner, innlaantKr og numrene er motorens egne', () => {
    // Funnet av injeksjonen «innlaant telles som et tillegg», som kom
    // grønn tilbake: `innlaantKr < kroner` holdt fortsatt etter en
    // dobling. En mapper skal sammenlignes med kilden sin, ikke med en
    // ulikhet.
    const k = begge(
      [rad(), rad({ ansattNr: '1104265', ansattNavn: 'Carmen Toro', minutter: 360 })],
      [reg()],
      [reg({ stasjonId: LONE, ansattNr: '1104265', navn: 'Carmen Toro', timesats: 138 })],
    )
    const motor = a1ForStasjonsmaaned(k, INGEN)
    const kort = tilA1Kort(motor)
    if (motor.status === 'kildemangel' || kort.status === 'kildemangel') throw new Error('feil')

    expect(kort.kroner).toBe(
      motor.status === 'minimum' ? motor.minimum503Kr : motor.konto503Kr,
    )
    expect(kort.innlaantKr).toBe(motor.innlaantKr)
    expect(kort.innlaanteNr).toEqual(motor.innlaanteNr)
    expect(kort.dataavvik.dubletter).toBe(motor.dubletter)
    expect(kort.helligdagstimer).toBe(motor.perArt['1410']?.timer ?? 0)
    expect(kort.forbehold).toEqual(motor.forbehold)
  })
})

describe('kortet bærer det blokka trenger', () => {
  it('uprisete personer med årsak', () => {
    const k = kort(begge([
      rad(), rad({ ansattNr: '1004', ansattNavn: 'Stig', minutter: 4080 }),
    ], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.uprisetePersoner).toEqual([
      { ansattNr: '1004', navn: 'Stig', timer: 68, grunn: 'ukjent_nummer' },
    ])
  })

  it('innlånt er en delmengde, og numrene følger med', () => {
    const k = kort(begge(
      [rad(), rad({ ansattNr: '1104265', ansattNavn: 'Carmen Toro', minutter: 360 })],
      [reg()],
      [reg({ stasjonId: LONE, ansattNr: '1104265', navn: 'Carmen Toro', timesats: 138 })],
    ))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.innlaanteNr).toEqual(['1104265'])
    expect(k.innlaantKr).toBeGreaterThan(0)
    expect(k.innlaantKr).toBeLessThan(k.kroner)
  })

  it('helligdagstimer er 0 når 1410 ikke er utløst', () => {
    const k = kort(begge([rad()], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.helligdagstimer).toBe(0)
  })

  it('forbeholdene følger med, også ved komplett', () => {
    const k = kort(begge([rad()], [reg()]))
    if (k.status === 'kildemangel') throw new Error('feil')
    expect(k.status).toBe('komplett')
    expect(k.forbehold).toHaveLength(2)
  })
})
