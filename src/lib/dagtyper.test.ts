import { describe, expect, test } from 'vitest'
import { datoerIMaaned, dagsprofiler, rodtPaaslagTimer, RODT_PAASLAG } from './dagtyper'
import { erHelligdag } from './helligdager'

// Påsken 2025: skjærtorsdag 17. april, langfredag 18., 2. påskedag 21.
// Påsken 2026: skjærtorsdag 2. april, langfredag 3., 2. påskedag 6.
const historikk = (kunder: (dato: string) => number, fra = '2025-01-01', til = '2025-12-31') => {
  const ut: { dato: string; kunder: number }[] = []
  for (let d = new Date(`${fra}T12:00:00Z`); d <= new Date(`${til}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + 1)) {
    const iso = d.toISOString().slice(0, 10)
    ut.push({ dato: iso, kunder: kunder(iso) })
  }
  return ut
}

describe('dagsprofiler', () => {
  test('vanlige dager har faktor 1 — ukedagsformen ligger i kundeprofilen', () => {
    const p = dagsprofiler(['2026-04-01'], historikk(() => 100))
    expect(p[0]).toMatchObject({ type: 'vanlig', faktor: 1, kostnad: 1, navn: null })
  })

  test('skjærtorsdag måles mot skjærtorsdag i fjor, ikke mot en formel', () => {
    // Utfartsstasjon: 80 % MER folk skjærtorsdag.
    const h = historikk((d) => (d === '2025-04-17' ? 180 : 100))
    const p = dagsprofiler(['2026-04-02'], h)
    expect(p[0].navn).toBe('Skjærtorsdag')
    expect(p[0].type).toBe('rod')
    expect(p[0].faktor).toBeCloseTo(1.8, 2)
    expect(p[0].grunnlag).toBe(1)
  })

  test('samme dag kan trekke ned på en annen stasjon', () => {
    // Bystasjon ved stengt kjøpesenter: halvparten så mange.
    const h = historikk((d) => (d === '2025-04-17' ? 50 : 100))
    expect(dagsprofiler(['2026-04-02'], h)[0].faktor).toBeCloseTo(0.5, 2)
  })

  test('en rød dag vi ikke har sett før låner fra de andre røde', () => {
    // Bare langfredag av de røde er med i historikken. 2. juledag arver
    // nivået derfra i stedet for å bli behandlet som en vanlig dag.
    const h = historikk((d) => (d === '2025-04-18' ? 40 : 100))
      .filter((x) => x.dato === '2025-04-18' || !erHelligdag(x.dato))
    const p = dagsprofiler(['2026-12-26'], h)
    expect(p[0].navn).toBe('2. juledag')
    expect(p[0].faktor).toBeCloseTo(0.4, 2)
    expect(p[0].grunnlag).toBe(0) // lånt, ikke målt — UI-et skal kunne si det
  })

  test('uten historikk gjettes det ikke — faktor 1', () => {
    const p = dagsprofiler(['2026-04-02'], [])
    expect(p[0]).toMatchObject({ faktor: 1, grunnlag: 0, type: 'rod' })
  })

  test('en enkelt vill dag kappes', () => {
    const h = historikk((d) => (d === '2025-04-17' ? 5000 : 100))
    expect(dagsprofiler(['2026-04-02'], h)[0].faktor).toBe(2.5)
  })

  test('røde dager forurenser ikke ukedagsnormalen', () => {
    // 17. mai 2025 er en lørdag med femdobbelt trykk. Vanlige lørdager
    // skal ikke bli «normalt høye» av det.
    const h = historikk((d) => (d === '2025-05-17' ? 500 : 100))
    const p = dagsprofiler(['2026-05-17'], h) // søndag i 2026
    expect(p[0].faktor).toBeCloseTo(2.5, 2) // kappet fra 5
  })

  test('røde dager koster dobbelt mot rammen', () => {
    const p = dagsprofiler(['2026-05-01', '2026-05-04'], historikk(() => 100))
    expect(p[0].kostnad).toBe(RODT_PAASLAG)
    expect(p[1].kostnad).toBe(1)
  })
})

describe('rodtPaaslagTimer', () => {
  test('setter et tall på hva de røde dagene tar ekstra', () => {
    // Mai 2026: 1. mai, 14. mai (Kristi himmelfart), 17. mai, 25. mai (2. pinsedag).
    const p = dagsprofiler(datoerIMaaned(2026, 5), historikk(() => 100))
    const rode = p.filter((x) => x.type === 'rod')
    expect(rode.length).toBeGreaterThanOrEqual(3)
    // 19 timer bemanning på en rød dag koster 19 timer EKSTRA.
    expect(rodtPaaslagTimer(p, () => 19)).toBe(rode.length * 19)
  })

  test('null røde dager koster ingenting ekstra', () => {
    const p = dagsprofiler(datoerIMaaned(2026, 9), historikk(() => 100))
    expect(rodtPaaslagTimer(p, () => 19)).toBe(0)
  })
})

describe('datoerIMaaned', () => {
  test('februar 2026 har 28 dager', () => {
    expect(datoerIMaaned(2026, 2)).toHaveLength(28)
    expect(datoerIMaaned(2026, 2)[27]).toBe('2026-02-28')
  })
  test('desember slutter på 31', () => {
    expect(datoerIMaaned(2026, 12).at(-1)).toBe('2026-12-31')
  })
})
