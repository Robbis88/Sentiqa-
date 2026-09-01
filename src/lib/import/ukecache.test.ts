import { describe, it, expect } from 'vitest'
import { mandagenI, berorteUker } from './ukecache'

describe('mandagenI', () => {
  it('finner mandagen for hver ukedag i uka 25. august laa i', () => {
    // Den ekte uka: 25. august 2026 var en tirsdag, og uka gaar fra
    // mandag 24. til soendag 30.
    const uka = {
      '2026-08-24': 'mandag',
      '2026-08-25': 'tirsdag',
      '2026-08-26': 'onsdag',
      '2026-08-27': 'torsdag',
      '2026-08-28': 'fredag',
      '2026-08-29': 'loerdag',
      '2026-08-30': 'soendag',
    }
    for (const [dato] of Object.entries(uka)) {
      expect(mandagenI(dato), dato).toBe('2026-08-24')
    }
  })

  it('KANARIFUGL: soendag hopper ikke fram til neste uke', () => {
    // `getUTCDay()` gir 0 for soendag. Regner man `dag - 1`, blir
    // soendagen mandagen ETTER - og da slettes feil uke mens den gale
    // blir staaende. Feilen ville rammet en av sju dager, altsaa vaert
    // usynlig sju ganger av aatte.
    expect(mandagenI('2026-08-30')).toBe('2026-08-24')
    expect(mandagenI('2026-08-31')).toBe('2026-08-31')  // ny uke, mandag
  })

  it('taaler aarsskifte', () => {
    // 1. januar 2027 er en fredag; uka starter 28. desember 2026.
    expect(mandagenI('2027-01-01')).toBe('2026-12-28')
  })
})

describe('berorteUker', () => {
  it('KANARIFUGL: gir BEGGE ukene, ogsaa den 52 uker fram', () => {
    // Ukerapporten sammenligner mot `mandag - 364`. Endres en dag i
    // 2025, blir 2026-uka som bruker den som `omsetning_ifjor` like
    // feil - og den feilen viser seg et helt aar unna dagen man rettet.
    //
    // Tar denne bare den ene uka, ryddes halve problemet og resten blir
    // staaende usett.
    expect(berorteUker('2026-08-25')).toEqual(['2026-08-24', '2027-08-23'])
  })

  it('de to ukene ligger 364 dager fra hverandre', () => {
    const [a, b] = berorteUker('2025-12-24')
    const dager = (new Date(`${b}T12:00:00Z`).getTime()
      - new Date(`${a}T12:00:00Z`).getTime()) / 86400000
    expect(dager).toBe(364)
  })

  it('begge er mandager', () => {
    for (const dato of ['2026-01-15', '2026-06-07', '2026-11-30', '2027-02-28']) {
      for (const uke of berorteUker(dato)) {
        expect(new Date(`${uke}T12:00:00Z`).getUTCDay(), `${dato} -> ${uke}`).toBe(1)
      }
    }
  })
})
