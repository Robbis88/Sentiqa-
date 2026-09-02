import { describe, expect, test } from 'vitest'
import { manglendeStasjoner, dekningsnotat, DAGLIGE, erDaglig, type Stasjon } from './stasjonsdekning'

// =====================================================================
// FIRE AV FEM STASJONER SER HELT FRISK UT
//
// 26. og 27. august 2026 manglet Laguneparken i St1s eksporter av 0018 og
// 0603. Rapportene var bestilt for alle fem butikknumrene, svaret hadde
// fire, og importen hadde ingenting aa reagere paa: fila var gyldig,
// radene ble lagret, jobben meldte «parset».
//
// Kontrollen som beviste det: 25.08, 28.08 og 01.09 har alle fem i samme
// filtype. Sonden fant altsaa Laguneparken naar den var der.
// =====================================================================

const KELSAR: Stasjon[] = [
  { id: 'a', navn: 'St1 Lone', butikknummer: '4177' },
  { id: 'b', navn: 'St1 Dale', butikknummer: '4185' },
  { id: 'c', navn: 'St1 Laguneparken', butikknummer: '9038' },
  { id: 'd', navn: 'St1 Varden', butikknummer: '9145' },
  { id: 'e', navn: 'St1 Bønes', butikknummer: '9467' },
]

describe('manglendeStasjoner', () => {
  test('KANARIFUGL: 26. august - Laguneparken er den ene som mangler', () => {
    // Selve saken. Fire stasjoner traff, den femte fikk ingen rad.
    const mangler = manglendeStasjoner(['a', 'b', 'd', 'e'], KELSAR)
    expect(mangler.map((s) => s.butikknummer)).toEqual(['9038'])
  })

  test('en komplett fil gir ingenting', () => {
    // 25.08, 28.08 og 01.09. Ellers ville hver eneste import faatt en
    // merknad, og da leses den ikke naar den betyr noe.
    expect(manglendeStasjoner(['a', 'b', 'c', 'd', 'e'], KELSAR)).toEqual([])
    expect(dekningsnotat([])).toBeNull()
  })

  test('samme stasjon flere ganger teller som en', () => {
    // Lagringen kaller med en id per RAD, ikke per stasjon.
    const mangler = manglendeStasjoner(['a', 'a', 'a', 'b', 'b'], KELSAR)
    expect(mangler).toHaveLength(3)
  })

  test('ingen traff i det hele tatt gir alle', () => {
    expect(manglendeStasjoner([], KELSAR)).toHaveLength(5)
  })

  test('en kjede med en stasjon kan ikke mangle noen naar den traff', () => {
    expect(manglendeStasjoner(['a'], [KELSAR[0]])).toEqual([])
  })
})

describe('dekningsnotat', () => {
  test('navngir stasjonen, teller den ikke bare', () => {
    // «1 stasjon mangler» tvinger den som leser til aa gjette hvilken, og
    // da blir merknaden noe man ser bort fra.
    const notat = dekningsnotat(manglendeStasjoner(['a', 'b', 'd', 'e'], KELSAR))!
    expect(notat).toContain('Laguneparken')
    expect(notat).toContain('9038')
  })

  test('flere sorteres paa butikknummer, saa to kjoeringer gir samme tekst', () => {
    const notat = dekningsnotat(manglendeStasjoner(['a'], KELSAR))!
    expect(notat.indexOf('4185')).toBeLessThan(notat.indexOf('9038'))
    expect(notat.indexOf('9038')).toBeLessThan(notat.indexOf('9467'))
  })

  test('entall og flertall', () => {
    expect(dekningsnotat(manglendeStasjoner(['a', 'b', 'd', 'e'], KELSAR))).toMatch(/^1 stasjon /)
    expect(dekningsnotat(manglendeStasjoner(['a'], KELSAR))).toMatch(/^4 stasjoner /)
  })
})

describe('bare datasett som kommer en fil per dag', () => {
  test('de tre daglige, og ingen andre', () => {
    // Speiler `datasett`-lista i migrasjon 0159. Regnskapet er maanedlig,
    // BP-en aarlig, og svinn foeres naar noe kastes - for dem er en
    // stasjon uten rader helt normalt, og en merknad ville vaert stoey.
    expect([...DAGLIGE].sort()).toEqual([
      'st1_cashierstats', 'st1_salesperhour_inneute', 'st1_salgsstatistikk',
    ])
    expect(erDaglig('regnskap_resultat')).toBe(false)
    expect(erDaglig('salgsgrid_varetrans')).toBe(false)
    expect(erDaglig('st1_bp')).toBe(false)
  })

  test('KANARIFUGL: lista er ikke tom', () => {
    // Toemmes den, maaler vakten ingenting - og hver fil ser komplett ut
    // igjen, akkurat som foer.
    expect(DAGLIGE.length).toBeGreaterThanOrEqual(3)
    expect(erDaglig('st1_cashierstats')).toBe(true)
  })
})
