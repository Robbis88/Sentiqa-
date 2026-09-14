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
  it('aapner paa nyeste maaned som har en plan', () => {
    expect(standardmaaned(KOE)).toBe('2026-07-01')
  })

  // =================================================================
  // DEN REGELEN SOM BLE RETTET, OG HVORFOR
  // =================================================================
  //
  // Foerste utgave valgte nyeste maaned MED UTKAST. Maalt i produksjon
  // 2026-09-14 ga den feil svar: juli var ferdigbehandlet samme dag (5
  // sluppet, 0 utkast), og regelen valgte JUNI - fem seks maaneder
  // gamle utkast, presentert som «Venter paa deg», mens maaneden som
  // faktisk var gjort laa bak nedtrekkslista.
  //
  // Denne testen er den gamle regelen, snudd. Kommer den tilbake, blir
  // den roed.
  it('velger en FERDIGBEHANDLET nyere maaned framfor eldre utkast', () => {
    // August er nyest og helt avgjort. Juli har to utkast som venter.
    const medAugust = [K('2026-08-01', 'sluppet'), ...KOE]
    expect(
      standardmaaned(medAugust),
      '\nKoeen aapnet paa en eldre maaned fordi den hadde utkast.\n'
      + 'Det var regelen som gjorde juni til «aktuell maaned» i\n'
      + 'produksjon 2026-09-14, med juli ferdig og gjemt bak velgeren.\n',
    ).toBe('2026-08-01')
  })

  it('status paavirker ikke valget i det hele tatt', () => {
    // Samme maaneder, alle statuser byttet om: samme svar.
    const snudd = KOE.map((r) => K(r.maaned, r.status === 'utkast' ? 'sluppet' : 'utkast'))
    expect(standardmaaned(snudd)).toBe(standardmaaned(KOE))
  })

  it('gir null paa tom koe, saa sida kan vise en tomtilstand', () => {
    expect(standardmaaned([])).toBeNull()
  })

  // =================================================================
  // KANARIFUGL
  // =================================================================
  it('KANARIFUGL: den plukker faktisk den NYESTE, ikke den foerste', () => {
    // Uten denne ville «returner rader[0].maaned» bestaatt hver test
    // over, siden KOE tilfeldigvis er sortert nyest foerst.
    const usortert = [K('2026-03-01', 'utkast'), K('2026-09-01', 'avvist'), K('2026-05-01', 'sluppet')]
    expect(standardmaaned(usortert)).toBe('2026-09-01')
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
