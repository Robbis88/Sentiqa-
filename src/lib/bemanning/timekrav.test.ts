import { describe, expect, test } from 'vitest'
import { bruttoKrav, kravtekst } from './timekrav'

const kr = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`

describe('brutto som kreves for timene', () => {
  test('Dale i januar, tall for tall', () => {
    // DE EKTE TALLENE fra produksjon 2026-08-22, etter at Sissel ble
    // satt til timelønn og rammen justert med årsverket/12:
    //
    //   ramme 986, brukt 1215, BP-brutto 664 446, realisert 534 218
    //
    //   664 446 × (1215 / 986) = 818 765 kreves
    //   818 765 − 534 218       = 284 547 mangler
    const k = bruttoKrav({
      rammeTimer: 986,
      brukteTimer: 1215,
      bpBruttoKr: 664446,
      realisertBruttoKr: 534218,
      realisertMarginPst: 50,
    })
    expect(k).not.toBeNull()
    expect(k!.bruttoKreves).toBe(818765)
    expect(k!.bruttoMangler).toBe(284547)
    // Til 50 % margin: dobbelt så mye omsetning som brutto.
    expect(k!.omsetningMangler).toBe(569093)
  })

  test('timene kan være dekket, og da er det ikke en oppgave', () => {
    const k = bruttoKrav({
      rammeTimer: 1000,
      brukteTimer: 800,
      bpBruttoKr: 100000,
      realisertBruttoKr: 95000,
      realisertMarginPst: 50,
    })
    // 100 000 × 0,8 = 80 000 kreves, 95 000 finnes → 15 000 til overs.
    expect(k!.bruttoMangler).toBe(-15000)
    expect(kravtekst(k!, kr)).toMatch(/Timene er dekket/)
    expect(kravtekst(k!, kr)).not.toMatch(/for å ha råd/)
  })

  test('uten realisert margin gjettes ingen omsetning', () => {
    // EN OPPGAVE I KRONER OMSETNING SKAL IKKE GJETTES. Margen kommer
    // fra regnskapet; finnes den ikke, står brutto-tallet alene.
    const k = bruttoKrav({
      rammeTimer: 1000, brukteTimer: 1200,
      bpBruttoKr: 100000, realisertBruttoKr: 90000,
      realisertMarginPst: null,
    })
    expect(k!.bruttoMangler).toBe(30000)
    expect(k!.omsetningMangler).toBeNull()
    expect(kravtekst(k!, kr)).not.toMatch(/omsetning/)
  })

  test('margin på null eller under gir ingen omsetning som hjelper', () => {
    for (const m of [0, -12.5]) {
      const k = bruttoKrav({
        rammeTimer: 1000, brukteTimer: 1200,
        bpBruttoKr: 100000, realisertBruttoKr: 90000,
        realisertMarginPst: m,
      })
      expect(k!.omsetningMangler, `margin ${m}`).toBeNull()
    }
  })

  test('mangler et ledd, finnes ikke svaret', () => {
    // Ingen ramme, ingen BP, ingen stemplinger — hver av dem gjør
    // regnestykket umulig, og da skal det være null og ikke null kroner.
    const grunn = {
      rammeTimer: 1000, brukteTimer: 1200,
      bpBruttoKr: 100000, realisertBruttoKr: 90000, realisertMarginPst: 50,
    }
    expect(bruttoKrav({ ...grunn, rammeTimer: null })).toBeNull()
    expect(bruttoKrav({ ...grunn, rammeTimer: 0 })).toBeNull()
    expect(bruttoKrav({ ...grunn, brukteTimer: null })).toBeNull()
    expect(bruttoKrav({ ...grunn, bpBruttoKr: null })).toBeNull()
    expect(bruttoKrav({ ...grunn, bpBruttoKr: 0 })).toBeNull()
    expect(bruttoKrav({ ...grunn, realisertBruttoKr: null })).toBeNull()
  })

  test('setningen sier hva som skal gjøres, ikke hva som gikk galt', () => {
    // «1 745 timer over» er en dom over noe som har skjedd. Dette er en
    // oppgave, og midt i måneden er den fortsatt mulig å påvirke.
    const k = bruttoKrav({
      rammeTimer: 986, brukteTimer: 1215,
      bpBruttoKr: 664446, realisertBruttoKr: 534218, realisertMarginPst: 50,
    })!
    const t = kravtekst(k, kr)
    // SAMME FORMATTERER I ASSERTEN. `toLocaleString('nb-NO')` skiller
    // tusener med et IKKE-BRYTENDE mellomrom (U+00A0), ikke et vanlig.
    // Skrevet for hånd ser strengene identiske ut og er det ikke.
    expect(t).toContain(kr(284547))
    expect(t).toContain(kr(569093))
    expect(t).toMatch(/for å ha råd til timene/)
    expect(t, 'skal ikke snakke om timer over').not.toMatch(/timer over/)
  })
})
