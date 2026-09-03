import { describe, it, expect } from 'vitest'
import { skjemabilde, kravFraPoster, andel, type Skjemapost } from './skjema'

// Uke 35: mandag 2026-08-24 til søndag 2026-08-30.
const UKE = '2026-08-24'
const DAGER = ['2026-08-24', '2026-08-25', '2026-08-26', '2026-08-27', '2026-08-28', '2026-08-29', '2026-08-30']
const gammel: Skjemapost = { opprettet: '2026-01-01T09:00:00Z', slettet: null }

const bilde = (poster: Skjemapost[], utfort: Record<string, number> = {}, sisteDag?: string) =>
  skjemabilde({ navn: 'Sjekkpunkt', kravPerDato: kravFraPoster(poster, UKE, sisteDag),
    utfortPerDato: new Map(Object.entries(utfort)), ukeMandag: UKE, sisteDag })

const alle = (n: number) => Object.fromEntries(DAGER.map((d) => [d, n]))

describe('kravet per dag', () => {
  it('krever hvert skjema hver dag når det fantes hele uken', () => {
    const b = bilde([gammel, gammel, gammel])
    expect(b.dager).toHaveLength(7)
    expect(b.dager.map((d) => d.krevd)).toEqual([3, 3, 3, 3, 3, 3, 3])
    expect(b.krevd).toBe(21)
  })

  it('merker dagene med norsk kortnavn i riktig rekkefølge', () => {
    expect(bilde([gammel]).dager.map((d) => d.ukedag))
      .toEqual(['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'])
  })

  // KANARIFUGL. Uten aktive-dager-regelen ville kravet vært 7, og brevet
  // ville sagt at stasjonen bommet mandag til torsdag på en rutine som
  // ikke fantes. Det er feilen hele fila er skrevet for.
  it('krever ingenting av dagene før skjemaet ble laget', () => {
    // Opprettet fredag → først lørdag og søndag. Fredag selv faller ut:
    // skjemaet fantes ikke ved døgnets start.
    const b = bilde([{ opprettet: '2026-08-28T08:00:00Z', slettet: null }])
    expect(b.dager.map((d) => d.krevd)).toEqual([0, 0, 0, 0, 0, 1, 1])
    expect(b.krevd).toBe(2)
  })

  // Opprettelsesdagen faller ut HELT — både kravet og en eventuell
  // kvittering. Det er dét som gjør regelen rettferdig: en rutine som
  // ble laget og gjort samme dag drar ikke prosenten ned, og en som ble
  // laget kl. 23.00 og ikke rukket gjør det heller ikke.
  it('lar opprettelsesdagen falle ut av både teller og nevner', () => {
    const post = [{ opprettet: '2026-08-28T08:00:00Z', slettet: null }]
    const utenArbeid = bilde(post)
    const medArbeid = bilde(post, { '2026-08-28': 1 })
    expect(medArbeid.prosent).toBe(utenArbeid.prosent)
    expect(medArbeid.dager[4]).toEqual(utenArbeid.dager[4])
  })

  it('slutter å kreve fra dagen skjemaet ble slettet', () => {
    // Slettet onsdag kl. 10.00 → mandag og tirsdag.
    expect(bilde([{ opprettet: '2026-01-01T09:00:00Z', slettet: '2026-08-26T10:00:00Z' }]).krevd).toBe(2)
  })

  it('klipper uken som fortsatt løper', () => {
    const b = bilde([gammel], {}, '2026-08-26')
    expect(b.dager).toHaveLength(3)
    expect(b.krevd).toBe(3)
  })

  it('lar aldri en dag bli mer enn hundre prosent', () => {
    // Seks kvitteringer på to rutiner er en datafeil, ikke 300 %.
    const b = bilde([gammel, gammel], { '2026-08-24': 6 })
    expect(b.dager[0].prosent).toBe(100)
    expect(b.dager[0].utfort).toBe(2)
  })

  it('gir null - ikke 0 - for en dag uten krav', () => {
    const b = bilde([{ opprettet: '2026-08-28T08:00:00Z', slettet: null }])
    expect(b.dager[0].prosent).toBeNull()  // mandag: skjemaet fantes ikke
    expect(b.dager[5].prosent).toBe(0)     // lørdag: krevd, ikke gjort
  })
})

describe('den svakeste dagen', () => {
  it('peker ut dagen som skiller seg ut', () => {
    // Alt gjort unntatt søndag.
    const u = { ...alle(2), '2026-08-30': 0 }
    const b = bilde([gammel, gammel], u)
    expect(b.svakesteDag?.ukedag).toBe('Søn')
    expect(b.prosent).toBe(86)
  })

  // Ligger alle dagene likt lavt, er det ikke EN dag som er saken - da er
  // det rutinene. Et brev som utpeker en vilkaarlig dag der, sender noen
  // til feil samtale.
  it('peker ikke ut noen dag når alle ligger likt', () => {
    const b = bilde([gammel, gammel], alle(1))
    expect(b.prosent).toBe(50)
    expect(b.svakesteDag).toBeNull()
  })

  it('peker ikke ut noen dag når alt er gjort', () => {
    expect(bilde([gammel], alle(1)).svakesteDag).toBeNull()
  })
})

describe('andel', () => {
  it('regner prosent', () => {
    expect(andel(30, 35)).toBe(86)
    expect(andel(35, 35)).toBe(100)
  })

  // 0 % og «ingenting å gjøre» er to helt ulike setninger i et brev.
  it('gir null - ikke 0 - når ingenting var krevd', () => {
    expect(andel(0, 0)).toBeNull()
  })
})
