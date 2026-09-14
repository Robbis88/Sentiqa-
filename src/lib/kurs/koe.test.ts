import { describe, expect, it } from 'vitest'
import { delKoe, maanederIKoe, standardmaaned, type Koerad } from './koe'

// =====================================================================
// Køen som forårsaket feilslippet 2026-09-14, i miniatyr.
//
// Produksjonstilstanden var 30 utkast over sju måneder. Her er formen
// den samme med færre rader: flere måneder, utkast i to av dem, og en
// avgjort plan i en tredje.
// =====================================================================

const K = (maaned: string, status: string): Koerad => ({ maaned, status })

/** Formen produksjonen hadde: utkast i juli OG juni, historikk i mai. */
const KOE: Koerad[] = [
  K('2026-07-01', 'utkast'),
  K('2026-07-01', 'utkast'),
  K('2026-07-01', 'avvist'),
  K('2026-06-01', 'utkast'),
  K('2026-05-01', 'sluppet'),
]

describe('maanederIKoe', () => {
  it('gir hver maaned én gang, nyeste foerst', () => {
    expect(maanederIKoe(KOE)).toEqual(['2026-07-01', '2026-06-01', '2026-05-01'])
  })

  it('taaler en ISO-timestamp fra basen', () => {
    // `date` kommer som streng, men en annen kallssti kan gi tidsdel.
    expect(maanederIKoe([K('2026-07-01T00:00:00.000Z', 'utkast')]))
      .toEqual(['2026-07-01'])
  })

  it('er tom naar koeen er tom', () => {
    expect(maanederIKoe([])).toEqual([])
  })
})

describe('standardmaaned', () => {
  it('aapner paa nyeste maaned som har et UTKAST', () => {
    expect(standardmaaned(KOE)).toBe('2026-07-01')
  })

  it('hopper over nyere maaneder der alt er avgjort', () => {
    // August er nyest, men der venter ingenting. Koeen er en
    // arbeidsflate: aapner den paa august, maa eieren lete etter juli.
    const medAugust = [K('2026-08-01', 'sluppet'), ...KOE]
    expect(standardmaaned(medAugust)).toBe('2026-07-01')
  })

  it('faller tilbake til nyeste maaned naar ingenting er utkast', () => {
    // Uten utkast finnes ingen arbeidsflate, og da er historikkens
    // nyeste maaned riktig dor. Her er det juli: den AVVISTE raden
    // ligger der, selv om de to utkastene er filtrert bort.
    const ingenUtkast = KOE.filter((r) => r.status !== 'utkast')
    expect(standardmaaned(ingenUtkast)).toBe('2026-07-01')

    // Og uten juli i det hele tatt faller den videre ned.
    expect(standardmaaned([K('2026-05-01', 'sluppet')])).toBe('2026-05-01')
  })

  it('gir null paa tom koe, saa sida kan vise en tomtilstand', () => {
    expect(standardmaaned([])).toBeNull()
  })
})

describe('delKoe', () => {
  it('viser bare den valgte maanedens rader', () => {
    const d = delKoe(KOE, '2026-07-01')
    expect(d.utkast).toHaveLength(2)
    expect(d.avgjort).toHaveLength(1)
    expect(d.utkast.every((r) => r.maaned === '2026-07-01')).toBe(true)
  })

  // =================================================================
  // DEN VIKTIGSTE PAASTANDEN I FILA
  // =================================================================
  //
  // Et filter som bare skjuler juni har byttet én feil mot en verre.
  // Sida sier selv at «et utkast ingen ser er en stasjon uten en plan».
  // Tallet er derfor ikke pynt — det er hele grunnen til at filteret
  // kan forsvares.
  it('TELLER utkastene det holder utenfor, i stedet for aa utelate dem', () => {
    const d = delKoe(KOE, '2026-07-01')
    expect(d.skjulteUtkast).toBe(1)
    expect(d.skjulteMaaneder).toBe(1)
  })

  it('teller ikke AVGJORTE planer i andre maaneder som skjulte', () => {
    // Mai er sluppet. Den venter ikke paa noen, og skal ikke roepe.
    const d = delKoe(KOE, '2026-07-01')
    expect(d.skjulteUtkast).toBe(1) // bare juni, ikke mai
  })

  it('teller flere maaneder hver for seg', () => {
    const bredere = [...KOE, K('2026-04-01', 'utkast'), K('2026-03-01', 'utkast')]
    const d = delKoe(bredere, '2026-07-01')
    expect(d.skjulteUtkast).toBe(3)
    expect(d.skjulteMaaneder).toBe(3)
  })

  it('velger man juni, er det juli som blir skjult', () => {
    const d = delKoe(KOE, '2026-06-01')
    expect(d.utkast).toHaveLength(1)
    expect(d.avgjort).toHaveLength(0)
    expect(d.skjulteUtkast).toBe(2)
  })

  it('null valgt maaned gir tomt, ikke «alt er skjult»', () => {
    const d = delKoe(KOE, null)
    expect(d).toEqual({ utkast: [], avgjort: [], skjulteUtkast: 0, skjulteMaaneder: 0 })
  })

  // =================================================================
  // KANARIFUGL
  // =================================================================
  //
  // Feller testen over fordi den ikke maaler noe? Uten denne ville
  // `skjulteUtkast: 0` i enhver implementasjon bestaatt «teller ikke
  // avgjorte», og `delKoe` kunne returnert null uten at noe ble roedt.
  it('KANARIFUGL: en koe UTEN andre maaneder gir null skjulte', () => {
    const baareJuli = KOE.filter((r) => r.maaned === '2026-07-01')
    const d = delKoe(baareJuli, '2026-07-01')
    expect(d.skjulteUtkast).toBe(0)
    expect(d.skjulteMaaneder).toBe(0)
    // Og da er det bevist at 1-ene over kom fra juni, ikke fra en
    // konstant.
    expect(delKoe(KOE, '2026-07-01').skjulteUtkast).toBeGreaterThan(0)
  })

  it('ingen rad forsvinner: vist + skjult + avgjort utenfor = alt', () => {
    const valgt = '2026-07-01'
    const d = delKoe(KOE, valgt)
    const avgjortUtenfor = KOE.filter(
      (r) => String(r.maaned).slice(0, 10) !== valgt && r.status !== 'utkast',
    ).length
    expect(d.utkast.length + d.avgjort.length + d.skjulteUtkast + avgjortUtenfor)
      .toBe(KOE.length)
  })
})
