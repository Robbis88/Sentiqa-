import { describe, it, expect } from 'vitest'
import { lagPeriode, manederIPeriode, hittilIAar, leggTilDager, idagOslo } from './periode'

const IDAG = '2026-08-24'

describe('lagPeriode', () => {
  it('utvider en måned til hele måneden', () => {
    const p = lagPeriode({ maaned: '2026-02' }, IDAG)
    expect(p).toMatchObject({ fra: '2026-02-01', til: '2026-02-28', opplosning: 'maaned' })
  })

  it('treffer skuddår', () => {
    const p = lagPeriode({ maaned: '2024-02' }, IDAG)
    expect(p).toMatchObject({ til: '2024-02-29' })
  })

  it('utvider et år til hele året', () => {
    const p = lagPeriode({ aar: 2025 }, IDAG)
    expect(p).toMatchObject({ fra: '2025-01-01', til: '2025-12-31', opplosning: 'aar' })
  })

  it('godtar fra/til', () => {
    const p = lagPeriode({ fra: '2026-08-01', til: '2026-08-15' }, IDAG)
    expect(p).toMatchObject({ fra: '2026-08-01', til: '2026-08-15', opplosning: 'dag' })
  })

  it('faller til standard når ingenting er oppgitt', () => {
    const p = lagPeriode({}, IDAG, { maaned: '2026-07' })
    expect(p).toMatchObject({ fra: '2026-07-01', til: '2026-07-31' })
  })

  it('lar eksplisitt inndata slå standarden', () => {
    const p = lagPeriode({ maaned: '2026-03' }, IDAG, { maaned: '2026-07' })
    expect(p).toMatchObject({ fra: '2026-03-01' })
  })

  // T11 — kjernen i «ufullstendig periode merkes».
  describe('komplett', () => {
    it('er sann for en avsluttet måned', () => {
      const p = lagPeriode({ maaned: '2026-07' }, IDAG)
      expect(p).toMatchObject({ komplett: true })
    })

    it('er USANN for inneværende måned', () => {
      const p = lagPeriode({ maaned: '2026-08' }, IDAG)
      expect(p).toMatchObject({ komplett: false })
    })

    it('er usann når perioden slutter i dag — dagens tall er ikke inne ennå', () => {
      const p = lagPeriode({ fra: '2026-08-01', til: IDAG }, IDAG)
      expect(p).toMatchObject({ komplett: false })
    })

    it('er sann når perioden slutter i går', () => {
      const p = lagPeriode({ fra: '2026-08-01', til: '2026-08-23' }, IDAG)
      expect(p).toMatchObject({ komplett: true })
    })

    it('er usann for inneværende år', () => {
      const p = lagPeriode({ aar: 2026 }, IDAG)
      expect(p).toMatchObject({ komplett: false })
    })
  })

  describe('avviser ubrukelig inndata framfor å gjette', () => {
    it('avviser fra etter til', () => {
      expect(lagPeriode({ fra: '2026-08-20', til: '2026-08-01' }, IDAG)).toHaveProperty('feil')
    })
    it('avviser feilformatert måned', () => {
      expect(lagPeriode({ maaned: 'august' }, IDAG)).toHaveProperty('feil')
    })
    it('avviser måned 13', () => {
      expect(lagPeriode({ maaned: '2026-13' }, IDAG)).toHaveProperty('feil')
    })
    it('avviser feilformatert dato', () => {
      expect(lagPeriode({ fra: '20.08.2026' }, IDAG)).toHaveProperty('feil')
    })
    it('avviser urimelig årstall', () => {
      expect(lagPeriode({ aar: 12 }, IDAG)).toHaveProperty('feil')
    })
  })
})

describe('manederIPeriode', () => {
  it('gir én måned for en måned', () => {
    const p = lagPeriode({ maaned: '2026-08' }, IDAG)
    expect(manederIPeriode(p as never)).toEqual(['2026-08-01'])
  })

  it('gir alle månedene hittil i år', () => {
    const p = lagPeriode({ fra: '2026-01-01', til: '2026-08-24' }, IDAG)
    expect(manederIPeriode(p as never)).toHaveLength(8)
  })

  it('krysser årsskiftet', () => {
    const p = lagPeriode({ fra: '2025-11-01', til: '2026-02-28' }, IDAG)
    expect(manederIPeriode(p as never)).toEqual([
      '2025-11-01', '2025-12-01', '2026-01-01', '2026-02-01',
    ])
  })
})

describe('hittilIAar', () => {
  it('går fra 1. januar til i går', () => {
    expect(hittilIAar(IDAG)).toMatchObject({
      fra: '2026-01-01',
      til: '2026-08-23',
      komplett: false,
    })
  })

  it('kollapser ikke på nyttårsdag', () => {
    expect(hittilIAar('2026-01-01').fra).toBe('2026-01-01')
  })
})

describe('leggTilDager', () => {
  it('krysser månedsskifte', () => {
    expect(leggTilDager('2026-08-31', 1)).toBe('2026-09-01')
  })
  it('krysser årsskifte bakover', () => {
    expect(leggTilDager('2026-01-01', -1)).toBe('2025-12-31')
  })
})

describe('idagOslo', () => {
  it('gir YYYY-MM-DD', () => {
    expect(idagOslo()).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  // KANARIFUGL: sommertid. En UTC-basert implementasjon gir feil dag
  // rett etter midnatt norsk tid om sommeren, og det ville sett ut som
  // en helt vanlig av-med-én-dag.
  it('bruker Europe/Oslo, ikke UTC', () => {
    expect(idagOslo(new Date('2026-06-15T22:30:00Z'))).toBe('2026-06-16')
  })
})
