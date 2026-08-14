import { describe, expect, test } from 'vitest'
import { kapasitet, stillingsanslag, TIMER_PER_MND_100 } from './bemanningsanalyse'

// Én rad per person per måned holder — funksjonen summerer selv.
const mnd = (nr: string, navn: string, fra: string, til: string, timer: number) => {
  const ut = []
  for (let m = Number(fra.slice(5)); m <= Number(til.slice(5)); m++) {
    ut.push({ ansattNr: nr, navn, dato: `${fra.slice(0, 4)}-${String(m).padStart(2, '0')}-15`, timer })
  }
  return ut
}

describe('stillingsanslag', () => {
  test('anslår prosent fra medianmåneden', () => {
    // 81,25 t/mnd = 50 %.
    const r = stillingsanslag(mnd('1', 'Halv Stilling', '2026-01', '2026-06', 81.25), '2026-08-14')
    expect(r[0].anslagProsent).toBe(50)
    expect(r[0].maaneder).toBe(6)
    expect(r[0].aktiv).toBe(true)
  })

  test('ferie og sykdom drukner ikke anslaget — derfor median', () => {
    // Fem vanlige måneder på 81 t, én ferie-måned på 10. Snittet ville
    // gitt 43 %; medianen gir 50, som er det hun faktisk går i.
    const r = stillingsanslag([
      ...mnd('1', 'A', '2026-01', '2026-05', 81.25),
      { ansattNr: '1', navn: 'A', dato: '2026-06-15', timer: 10 },
    ], '2026-08-14')
    expect(r[0].anslagProsent).toBe(50)
  })

  test('inneværende måned teller ikke — den er ikke ferdig', () => {
    const r = stillingsanslag([
      ...mnd('1', 'A', '2026-01', '2026-07', 162.5),
      { ansattNr: '1', navn: 'A', dato: '2026-08-03', timer: 12 },
    ], '2026-08-14')
    expect(r[0].anslagProsent).toBe(100)
    expect(r[0].maaneder).toBe(7)
  })

  test('den som ikke har stemplet på tre måneder er ikke aktiv', () => {
    const r = stillingsanslag(mnd('1', 'Sluttet', '2026-01', '2026-03', 81.25), '2026-08-14')
    expect(r[0].aktiv).toBe(false)
    expect(r[0].sisteMnd).toBe('2026-03')
  })

  test('rundes til nærmeste fem — et anslag skal se ut som et anslag', () => {
    const r = stillingsanslag(mnd('1', 'A', '2026-01', '2026-06', 60), '2026-08-14')
    expect(r[0].anslagProsent % 5).toBe(0)
    expect(r[0].anslagProsent).toBe(35) // 60/162,5 = 36,9 %
  })

  test('nyeste navn vinner — folk gifter seg', () => {
    const r = stillingsanslag([
      { ansattNr: '1', navn: 'Kari Hansen', dato: '2026-01-15', timer: 80 },
      { ansattNr: '1', navn: 'Kari Nilsen', dato: '2026-06-15', timer: 80 },
    ], '2026-08-14')
    expect(r[0].navn).toBe('Kari Nilsen')
  })

  test('sorteres etter hvor mye de går i', () => {
    const r = stillingsanslag([
      ...mnd('1', 'Liten', '2026-01', '2026-06', 20),
      ...mnd('2', 'Stor', '2026-01', '2026-06', 150),
    ], '2026-08-14')
    expect(r.map((x) => x.navn)).toEqual(['Stor', 'Liten'])
  })
})

describe('kapasitet', () => {
  test('sier om folkene rekker til planen', () => {
    // Fire hele stillinger = 650 t. Planen krever 589.
    const k = kapasitet(Array.from({ length: 4 }, () => ({ anslagProsent: 100, aktiv: true })), 589)
    expect(k.tilgjengelig).toBeCloseTo(4 * TIMER_PER_MND_100, 6)
    expect(k.dekning).toBeGreaterThan(1)
  })

  test('de som har sluttet teller ikke med', () => {
    const k = kapasitet([
      { anslagProsent: 100, aktiv: true },
      { anslagProsent: 100, aktiv: false },
    ], 162.5)
    expect(k.dekning).toBeCloseTo(1, 6)
  })

  test('for få folk gir dekning under 1 — da hjelper ingen plan', () => {
    const k = kapasitet([{ anslagProsent: 50, aktiv: true }], 589)
    expect(k.dekning).toBeLessThan(0.2)
  })
})

describe('merknad', () => {
  test('over full stilling forklares — det finnes ingen 130 %-kontrakt', () => {
    // Sissel på Dale: median 211 t/mnd = 130 %.
    const r = stillingsanslag(mnd('1', 'Sissel', '2026-01', '2026-06', 211), '2026-08-14')
    expect(r[0].anslagProsent).toBe(130)
    expect(r[0].merknad).toMatch(/arbeidede timer/)
    expect(r[0].merknad).toMatch(/ekstravakter/)
  })

  test('en vanlig stilling får ingen merknad', () => {
    const r = stillingsanslag(mnd('1', 'A', '2026-01', '2026-06', 81.25), '2026-08-14')
    expect(r[0].merknad).toBeNull()
  })

  test('for få måneder sier fra', () => {
    const r = stillingsanslag(mnd('1', 'Ny', '2026-05', '2026-06', 81.25), '2026-08-14')
    expect(r[0].merknad).toMatch(/For få måneder/)
  })

  test('nøyaktig 100 % er ikke over', () => {
    const r = stillingsanslag(mnd('1', 'A', '2026-01', '2026-06', 162.5), '2026-08-14')
    expect(r[0].anslagProsent).toBe(100)
    expect(r[0].merknad).toBeNull()
  })
})
