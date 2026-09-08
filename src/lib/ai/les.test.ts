import { describe, expect, it } from 'vitest'
import { les, lesAlle, erLesefeil, TAK } from './les'

// =====================================================================
// ET AVKORTET SVAR SOM MELDES KOMPLETT
//
// `hent_salg` ba om hittil-i-år for fem stasjoner — over 400 000 rader
// på varenivå — med `.limit(50000)`. PostgREST gir tusen uansett hva
// `.limit()` sier, og `avkortet` ble regnet ETTER at radene var
// aggregert ned til åtte. Åtte er under grensen, så svaret ble merket
// komplett.
//
// Modellen fikk de første dagene av året presentert som årets
// omsetning. Det er den verste formen: tallet er troverdig, og
// ingenting i svaret sier noe annet.
// =====================================================================
describe('taket', () => {
  const svar = <T,>(data: T[]) => Promise.resolve({ data, error: null })

  it('melder fra når svaret fyller taket', async () => {
    const r = await les(svar(Array.from({ length: TAK }, (_, i) => ({ i }))), 'v_butikksalg')
    expect(erLesefeil(r)).toBe(false)
    expect((r as { taketTruffet?: boolean }).taketTruffet).toBe(true)
  })

  it('melder ikke fra like under taket', async () => {
    // KANARIFUGL: uten denne ville et flagg som ALLTID er sant bestått
    // testen over, og hvert eneste svar blitt merket avkortet.
    const r = await les(svar(Array.from({ length: TAK - 1 }, (_, i) => ({ i }))), 'v_butikksalg')
    expect((r as { taketTruffet?: boolean }).taketTruffet).toBe(false)
  })

  it('lar én avkortet kilde smitte på en kryssing', async () => {
    // Den som krysser to kilder regner ikke halvveis riktig naar den ene
    // er delvis - den regner feil, med et tall som ser komplett ut.
    const r = await lesAlle([
      [svar([{ a: 1 }]), 'liten'],
      [svar(Array.from({ length: TAK }, (_, i) => ({ b: i }))), 'stor'],
    ])
    expect((r as { taketTruffet?: boolean }).taketTruffet).toBe(true)
  })
})
