import { describe, expect, test } from 'vitest'
import { finnTidsproblemer, samletTap, type Svinnrad, type Utsolgtrad } from './tidsproblem'

const svinn = (ean: string, dato: string, antall = 3, kr = 90): Svinnrad =>
  ({ ean, varenavn: `Vare ${ean}`, dato, antall, kr })

const hull = (ean: string, dager = 2, tapt = 400): Utsolgtrad =>
  ({ ean, varenavn: `Vare ${ean}`, fra: '2026-08-01', til: '2026-08-02', dager, tapt_kr: tapt })

describe('finnTidsproblemer', () => {
  test('bare svinn er ikke et tidsproblem — det er /svinn sin sak', () => {
    expect(finnTidsproblemer(
      [svinn('a', '2026-08-01'), svinn('a', '2026-08-02'), svinn('a', '2026-08-03')],
      [],
    )).toEqual([])
  })

  test('bare hull er heller ikke det — det er /utsolgt sin sak', () => {
    expect(finnTidsproblemer([], [hull('a')])).toEqual([])
  })

  test('begge deler på samme vare er funnet', () => {
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01'), svinn('a', '2026-08-05')],
      [hull('a')],
    )
    expect(ut).toHaveLength(1)
    expect(ut[0].ean).toBe('a')
    expect(ut[0].svinnDager).toBe(2)
    expect(ut[0].utsolgtDager).toBe(2)
  })

  test('én kastedag er uflaks, ikke et mønster', () => {
    // En levering som kom sent, en buss med tredve ungdommer.
    expect(finnTidsproblemer([svinn('a', '2026-08-01')], [hull('a')])).toEqual([])
  })

  test('samme dag telles én gang selv med flere rader', () => {
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01'), svinn('a', '2026-08-01'), svinn('a', '2026-08-02')],
      [hull('a')],
    )
    expect(ut[0].svinnDager).toBe(2)
    expect(ut[0].svinnAntall).toBe(9)
  })

  test('negativt antall er en mengde, ikke et fortegn', () => {
    // Kastet antall foeres negativt i eksporten fra St1.
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01', -4, -120), svinn('a', '2026-08-02', -2, -60)],
      [hull('a')],
    )
    expect(ut[0].svinnAntall).toBe(6)
    expect(ut[0].svinnKr).toBe(180)
  })

  test('kostnaden er begge deler lagt sammen', () => {
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01', 3, 100), svinn('a', '2026-08-02', 3, 100)],
      [hull('a', 3, 500)],
    )
    expect(ut[0].svinnKr).toBe(200)
    expect(ut[0].tapteKr).toBe(500)
    expect(ut[0].samletKr).toBe(700)
  })

  test('flere hull på samme vare summeres', () => {
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01'), svinn('a', '2026-08-02')],
      [hull('a', 2, 300), hull('a', 3, 200)],
    )
    expect(ut[0].utsolgtHendelser).toBe(2)
    expect(ut[0].utsolgtDager).toBe(5)
    expect(ut[0].tapteKr).toBe(500)
  })

  test('dyrest først — det er der en endring betyr mest', () => {
    const ut = finnTidsproblemer(
      [
        svinn('billig', '2026-08-01', 1, 20), svinn('billig', '2026-08-02', 1, 20),
        svinn('dyr', '2026-08-01', 1, 900), svinn('dyr', '2026-08-02', 1, 900),
      ],
      [hull('billig', 2, 50), hull('dyr', 2, 50)],
    )
    expect(ut.map((r) => r.ean)).toEqual(['dyr', 'billig'])
  })

  test('meldingen sier hva man skal gjøre, ikke bare hva som er galt', () => {
    const ut = finnTidsproblemer(
      [svinn('a', '2026-08-01'), svinn('a', '2026-08-02')], [hull('a')],
    )
    expect(ut[0].melding).toContain('flytte produksjonen')
    expect(ut[0].melding).toContain('Mengden er ikke feil')
  })

  test('varenavn hentes der det finnes', () => {
    const ut = finnTidsproblemer(
      [
        { ean: 'a', varenavn: null, dato: '2026-08-01', antall: 1, kr: 10 },
        { ean: 'a', varenavn: 'Baguette', dato: '2026-08-02', antall: 1, kr: 10 },
      ],
      [hull('a')],
    )
    expect(ut[0].varenavn).toBe('Baguette')
  })

  test('rader uten ean hoppes over framfor å lage en tom vare', () => {
    expect(finnTidsproblemer(
      [{ ean: '', varenavn: 'X', dato: '2026-08-01', antall: 1, kr: 10 }],
      [hull('')],
    )).toEqual([])
  })
})

describe('samletTap', () => {
  test('summerer det hele funnet koster', () => {
    const rader = finnTidsproblemer(
      [
        svinn('a', '2026-08-01', 1, 100), svinn('a', '2026-08-02', 1, 100),
        svinn('b', '2026-08-01', 1, 50), svinn('b', '2026-08-02', 1, 50),
      ],
      [hull('a', 2, 300), hull('b', 2, 200)],
    )
    expect(samletTap(rader)).toBe(800)
  })

  test('ingenting funnet koster ingenting', () => {
    expect(samletTap([])).toBe(0)
  })
})
