import { describe, expect, test } from 'vitest'
import { stasjonsnavn, velgStasjon, visVelger } from './stasjonsvalg'

const ALLE = [
  { id: 'a', navn: 'Lone', butikknummer: '4177' },
  { id: 'b', navn: 'Bønes', butikknummer: '9467' },
]

describe('velgStasjon', () => {
  test('URL-en vinner over det man valgte sist', () => {
    // En delt lenke skal vise det den lovet. Snur man dette, blir
    // dyplenker upaalitelige - og det oppdages forst naar noen sender en
    // lenke til feil tall.
    expect(velgStasjon(ALLE, { fraUrl: 'b', fraHukommelse: 'a' })).toBe('b')
  })

  test('uten URL brukes det man valgte sist', () => {
    expect(velgStasjon(ALLE, { fraHukommelse: 'b' })).toBe('b')
  })

  test('uten noe som helst velges den første', () => {
    expect(velgStasjon(ALLE, {})).toBe('a')
  })

  test('en husket stasjon som ikke finnes lenger, faller tilbake', () => {
    // Slettet stasjon, eller en bruker som byttet kjede. Skal ikke gi
    // tom side.
    expect(velgStasjon(ALLE, { fraHukommelse: 'borte' })).toBe('a')
  })

  test('en ugyldig stasjon i URL-en faller tilbake, den også', () => {
    expect(velgStasjon(ALLE, { fraUrl: 'tull' })).toBe('a')
  })

  test('«alle» er et valg, ikke fravær av et valg', () => {
    expect(velgStasjon(ALLE, { fraUrl: 'alle', tillatAlle: true })).toBeNull()
    expect(velgStasjon(ALLE, { fraHukommelse: 'alle', tillatAlle: true })).toBeNull()
  })

  test('sider som ikke tåler «alle», får likevel en stasjon', () => {
    // Lonnsfila lages per stasjon. «Alle samlet» gir ingen mening der,
    // og skal ikke gi en tom side heller.
    expect(velgStasjon(ALLE, { fraUrl: 'alle', tillatAlle: false })).toBe('a')
    expect(velgStasjon(ALLE, { fraHukommelse: 'alle' })).toBe('a')
  })

  test('eieren lander på porteføljen der siden tåler det', () => {
    expect(velgStasjon(ALLE, { tillatAlle: true })).toBeNull()
  })

  test('ingen stasjoner gir null, ikke krasj', () => {
    expect(velgStasjon([], { fraUrl: 'a' })).toBeNull()
  })
})

describe('visVelger', () => {
  test('én stasjon og ingen porteføljevisning er ikke et valg', () => {
    expect(visVelger([ALLE[0]], false)).toBe(false)
  })

  test('én stasjon, men «alle» finnes — da er det to alternativer', () => {
    expect(visVelger([ALLE[0]], true)).toBe(true)
  })

  test('flere stasjoner vises alltid', () => {
    expect(visVelger(ALLE, false)).toBe(true)
  })

  test('ingen stasjoner gir ingen velger', () => {
    expect(visVelger([], true)).toBe(false)
  })
})

describe('stasjonsnavn', () => {
  test('nummer foran navn', () => {
    expect(stasjonsnavn(ALLE[1])).toBe('9467 Bønes')
  })

  test('uten nummer bare navnet', () => {
    expect(stasjonsnavn({ id: 'x', navn: 'Ny stasjon' })).toBe('Ny stasjon')
  })
})
