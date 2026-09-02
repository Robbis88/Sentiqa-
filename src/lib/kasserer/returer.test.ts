import { describe, expect, test } from 'vitest'
import { returerPerKasserer, type Dagsrad } from './returer'
import { MIN_BONGER } from './rate'

// =====================================================================
// TALLET LAA DER HELE TIDEN
//
// Assistenten svarte 2026-09-02 at kassererstatistikken «ikke bryter ned
// paa enkeltansatt/kasserer i dette oppslaget», og ba Robert gaa inn i
// kassesystemet. Verktoeyet HENTET `kasserer_nr` og `kasserer_navn` og
// kastet dem i `form()`.
//
// Denne fila vokter formen paa svaret. Grensene er ikke valgt her - de
// kommer fra `kasserer_fordeling.sql` mot produksjon 2026-08-24, via
// `rate.ts`.
// =====================================================================

const NAVN = new Map([['s1', '9038 Laguneparken'], ['s2', '4177 Lone']])

/** n dager med like tall, fra 2026-08-12. */
const dager = (
  stasjon: string, nr: string, navn: string | null,
  n: number, bonger: number, returer: number, kr: number, fra = 12,
): Dagsrad[] =>
  Array.from({ length: n }, (_, i) => ({
    stasjon_id: stasjon, kasserer_nr: nr, kasserer_navn: navn,
    dato: `2026-08-${String(fra + i).padStart(2, '0')}`,
    bonger, retur_antall: returer, retur_belop: kr,
  }))

describe('returer per kasserer', () => {
  test('KANARIFUGL: bryter faktisk ned per kasserer', () => {
    // Selve saken. Foer dette kom det EN rad per stasjon.
    const ut = returerPerKasserer([
      ...dager('s1', '15', 'NORHEIM, OLAV', 10, 100, 2, 40),
      ...dager('s1', '16', 'SKAGE, OLE', 10, 100, 2, 40),
    ], NAVN)
    expect(ut).toHaveLength(2)
    expect(ut.map((r) => r.kasserer_nr).sort()).toEqual(['15', '16'])
    expect(ut[0].stasjon).toBe('9038 Laguneparken')
    expect(ut.find((r) => r.kasserer_nr === '15')!.navn).toBe('NORHEIM, OLAV')
  })

  test('samme nummer paa to stasjoner er to mennesker', () => {
    // Numrene starter paa nytt per stasjon. Noekkelen maa vaere begge.
    const ut = returerPerKasserer([
      ...dager('s1', '5', 'A', 10, 100, 1, 20),
      ...dager('s2', '5', 'B', 10, 100, 1, 20),
    ], NAVN)
    expect(ut).toHaveLength(2)
    expect(new Set(ut.map((r) => r.stasjon)).size).toBe(2)
  })

  test('raten er per 100 bonger, ikke kroner', () => {
    // Den som ekspederer tre ganger saa mye har tre ganger saa mye
    // retur uten at noe er galt. 30 returer paa 1000 bonger = 3,0.
    const ut = returerPerKasserer(dager('s1', '15', 'A', 10, 100, 3, 60), NAVN)
    expect(ut[0].bonger).toBe(1000)
    expect(ut[0].returer).toBe(30)
    expect(ut[0].retur_per_100).toBe(3)
  })

  test('KANARIFUGL: tynt grunnlag gir INGEN rate, og sier hvorfor', () => {
    // En kasse med 40 bonger og tre returer er 7,5 per 100 - og betyr
    // ingenting. Uten dette ville den ligget oeverst paa lista.
    const ut = returerPerKasserer(dager('s1', '15', 'A', 2, 20, 2, 40), NAVN)
    expect(ut[0].bonger).toBeLessThan(MIN_BONGER)
    expect(ut[0].retur_per_100).toBeNull()
    expect(ut[0].merknad).toMatch(/stoey|støy/i)
  })

  test('kassa selv merkes og legges sist', () => {
    const ut = returerPerKasserer([
      ...dager('s1', '999999', null, 10, 500, 10, 200),
      ...dager('s1', '15', 'A', 10, 100, 1, 20),
    ], NAVN)
    expect(ut[ut.length - 1].kasserer_nr).toBe('999999')
    expect(ut[ut.length - 1].er_kassa).toBe(true)
    expect(ut[ut.length - 1].merknad).toMatch(/kassa selv/i)
  })

  test('KANARIFUGL: kassa rangeres ikke opp selv med hoeyest rate', () => {
    // 999999 baerer 18-35 % av alle bonger. Blandes den inn, er den
    // oeverst halve tiden - og lista peker paa en maskin.
    const ut = returerPerKasserer([
      ...dager('s1', '999999', null, 10, 100, 20, 400),
      ...dager('s1', '15', 'A', 10, 100, 1, 20),
    ], NAVN)
    expect(ut[0].kasserer_nr).toBe('15')
  })

  test('et nummer som bar flere navn merkes, og navnet er ikke en identitet', () => {
    // Varden nr. 9 var en delt paalogging. Baerer nummeret to navn i
    // perioden, kan ingen av dem brukes til aa peke paa en person.
    const ut = returerPerKasserer([
      ...dager('s1', '9', 'Fonnes, Denis', 5, 100, 1, 20),
      ...dager('s1', '9', 'Hansen, Kari', 5, 100, 1, 20, 20),
    ], NAVN)
    expect(ut[0].navn_tvetydig).toBe(true)
    expect(ut[0].navn).toContain('/')
    expect(ut[0].merknad).toMatch(/flere navn/i)
  })

  test('snittbeloepet skiller faa og store fra mange og smaa', () => {
    // En feilvare eller én reklamasjon gir faa og store returer. Mange og
    // smaa passer ingen av de uskyldige forklaringene.
    const smaa = returerPerKasserer(dager('s1', '15', 'A', 10, 200, 10, 250), NAVN)
    const store = returerPerKasserer(dager('s1', '16', 'B', 10, 200, 1, 900), NAVN)
    expect(smaa[0].snitt_kr_per_retur).toBe(25)
    expect(store[0].snitt_kr_per_retur).toBe(900)
  })

  test('ingen returer gir null snitt, ikke deling paa null', () => {
    expect(returerPerKasserer(dager('s1', '15', 'A', 10, 100, 0, 0), NAVN)[0]
      .snitt_kr_per_retur).toBeNull()
  })

  test('KANARIFUGL: et trinn midt i perioden sees i de to halvdelene', () => {
    // Et NIVAA kan ikke skille personer - svingningen inni én kasserer er
    // stoerre enn spennet mellom dem. Et TRINN kan si at noe forandret
    // seg, og det er datoen man leter etter.
    const ut = returerPerKasserer([
      ...dager('s1', '15', 'A', 6, 200, 4, 80, 12),    // 2,0 per 100
      ...dager('s1', '15', 'A', 6, 200, 40, 800, 18),  // 20,0 per 100
    ], NAVN)
    expect(ut[0].forst_per_100).toBeLessThan(5)
    expect(ut[0].sist_per_100).toBeGreaterThan(15)
  })

  test('et flatt forloep gir to like halvdeler', () => {
    // Ellers ville testen over bestaatt paa hva som helst.
    const ut = returerPerKasserer(dager('s1', '15', 'A', 12, 200, 4, 80), NAVN)
    expect(ut[0].forst_per_100).toBe(ut[0].sist_per_100)
  })

  test('toppdagene peker paa hvor kvitteringene skal hentes', () => {
    const ut = returerPerKasserer([
      ...dager('s1', '15', 'A', 5, 200, 1, 20, 12),
      { stasjon_id: 's1', kasserer_nr: '15', kasserer_navn: 'A',
        dato: '2026-08-25', bonger: 200, retur_antall: 30, retur_belop: 600 },
    ], NAVN)
    expect(ut[0].toppdager[0].dato).toBe('2026-08-25')
    expect(ut[0].toppdager[0].returer).toBe(30)
    expect(ut[0].toppdager.length).toBeLessThanOrEqual(6)
  })

  test('dager uten returer staar ikke som toppdager', () => {
    expect(returerPerKasserer(dager('s1', '15', 'A', 10, 100, 0, 0), NAVN)[0].toppdager)
      .toEqual([])
  })

  test('KANARIFUGL: makulert og slettet er ikke med i det hele tatt', () => {
    // Makulert er 71-83 % av avvikskronene. Kom de med, ville tallet
    // maalt makulering og hett returer.
    const felt = Object.keys(returerPerKasserer(dager('s1', '15', 'A', 10, 100, 1, 20), NAVN)[0])
    expect(felt.join(' ')).not.toMatch(/makul|slett/i)
  })
})
