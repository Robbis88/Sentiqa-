import { describe, it, expect } from 'vitest'
import { tilEpost } from './epost'
import { byggUkebrief } from './bygg'
import type { Ukedata } from './type'
import { skjemabilde } from './skjema'

// =====================================================================
// Vakt over e-posten.
//
// Denne teksten forlater systemet. Den kan ikke rettes etterpå, den kan
// videresendes, og den leses av noen som ikke kan spørre hva den mente.
// =====================================================================

const URL = 'https://sentiqa.ai'

function ukedata(over: Partial<Ukedata> = {}): Ukedata {
  return {
    stasjonNavn: '0603 Teststasjon',
    ukeMandag: '2026-08-24',
    omsetning: 500000,
    omsetningIfjor: 400000,
    bpUke: null,
    avdelinger: [],
    utsolgt: [],
    treff: { antall: 10, snittTreffPst: 90 },
    timer: { brukt: 200, ukesramme: 200 },
    tilbakemeldinger: { antall: 0, ulest: 0, harAlvorlig: false },
    skjema: [],
    kritiskeNei: 0,
    hull: [],
    ...over,
  }
}

const lag = (over: Partial<Ukedata> = {}) => tilEpost(byggUkebrief(ukedata(over)), URL)

describe('ukebriefen som e-post', () => {
  it('setter uke og overskrift i emnet', () => {
    expect(lag().emne).toMatch(/^Uke 35 — /)
  })

  // KANARIFUGL. Varenavn kommer fra kjedens egne filer og HAR inneholdt
  // `&`. Uten escaping brekker markupen — og i verste fall gjør navnet
  // noe verre enn å se rart ut. Uten dette navnet ville testen bestått
  // med escapingen fjernet, fordi ingen andre fikstur har et slikt tegn.
  it('escaper navn som inneholder markup', () => {
    const { html } = lag({
      utsolgt: [{ navn: '<b>Pepsi & Max</b> "stor"', taptKr: 12000, dager: 4 }],
    })
    expect(html).toContain('&lt;b&gt;Pepsi &amp; Max&lt;/b&gt;')
    expect(html).not.toContain('<b>Pepsi')
  })

  it('har en tekstversjon med det samme innholdet', () => {
    const { tekst } = lag({ utsolgt: [{ navn: 'Kaffe', taptKr: 12000, dager: 4 }] })
    expect(tekst).toContain('Uke 35')
    expect(tekst).toContain('Kaffe')
    expect(tekst).toContain('DETTE VILLE JEG TATT TAK I')
    expect(tekst).not.toMatch(/<[a-z]/i)
  })

  it('lenker til produksjon, ikke til en relativ sti', () => {
    const { html } = lag({ utsolgt: [{ navn: 'Kaffe', taptKr: 12000, dager: 4 }] })
    expect(html).toContain(`${URL}/utsolgt`)
    expect(html).toContain(`${URL}/oversikt`)
  })

  // Meldingene fra de ansatte kan gjelde uhell eller krenkelse. Brevet
  // ligger i en innboks og kan videresendes; det skal telle, aldri gjengi.
  it('gjengir aldri innholdet i meldinger fra ansatte', () => {
    const { html, tekst } = lag({ tilbakemeldinger: { antall: 2, ulest: 1, harAlvorlig: true } })
    for (const t of [html, tekst]) {
      expect(t).toContain('Innholdet står i Sentiqa')
      expect(t).toMatch(/2 meldinger/)
    }
  })

  it('viser hva vi ikke vet, ogsaa i e-posten', () => {
    const { html } = lag({ treff: null, hull: [{ kilde: 'Timesalg', dagerMangler: 2 }] })
    expect(html).toContain('Dette vet vi ikke')
    expect(html).toContain('Timesalg')
  })

  it('tar med ukedagsraden i baade html og tekst', () => {
    const dager = ['2026-08-24', '2026-08-25', '2026-08-26', '2026-08-27', '2026-08-28', '2026-08-29', '2026-08-30']
    const b = skjemabilde({
      navn: 'Rutiner',
      poster: [{ opprettet: '2026-01-01T09:00:00Z', slettet: null }],
      utfortPerDato: new Map(dager.map((d, i) => [d, i === 6 ? 0 : 1])),
      ukeMandag: '2026-08-24',
    })
    const { html, tekst } = lag({ skjema: [b] })
    expect(html).toContain('Utført per dag')
    for (const dag of ['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn']) {
      expect(html).toContain(dag)
      expect(tekst).toContain(dag)
    }
    // Sondagen er den som mangler, og det skal kunne leses uten farge.
    expect(tekst).toContain('Søn 0%')
  })

  it('gir samme e-post for samme uke', () => {
    const d = ukedata({ utsolgt: [{ navn: 'Kaffe', taptKr: 8000, dager: 3 }] })
    expect(tilEpost(byggUkebrief(d), URL)).toEqual(tilEpost(byggUkebrief(d), URL))
  })
})
