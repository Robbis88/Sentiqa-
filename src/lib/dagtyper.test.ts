import { describe, expect, test } from 'vitest'
import { datoerIMaaned, dagsprofiler, rodtPaaslagTimer, timekostnad, RODT_PAASLAG } from './dagtyper'
import { erHelligdag } from './helligdager'
import { aftenNavn } from './dagtyper'

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
    expect(p[0]).toMatchObject({ type: 'vanlig', faktor: 1, rodFraTime: null, navn: null })
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
      .filter((x) => x.dato === '2025-04-18' || (!erHelligdag(x.dato) && !aftenNavn(x.dato)))
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

  test('røde dager koster dobbelt hele dagen', () => {
    const p = dagsprofiler(['2026-05-01', '2026-05-04'], historikk(() => 100))
    expect(timekostnad(p[0], 8)).toBe(RODT_PAASLAG)
    expect(timekostnad(p[0], 20)).toBe(RODT_PAASLAG)
    expect(timekostnad(p[1], 8)).toBe(1)
  })

  test('aftener er røde fra 15, ikke før', () => {
    // Julaften, nyttårsaften, påskeaften (2026: 4. april), pinseaften (23. mai).
    for (const [dato, navn] of [
      ['2026-12-24', 'Julaften'], ['2026-12-31', 'Nyttårsaften'],
      ['2026-04-04', 'Påskeaften'], ['2026-05-23', 'Pinseaften'],
    ] as const) {
      const p = dagsprofiler([dato], historikk(() => 100))[0]
      expect(p.navn, dato).toBe(navn)
      expect(p.type, dato).toBe('aften')
      expect(timekostnad(p, 14), `${dato} kl 14`).toBe(1)
      expect(timekostnad(p, 15), `${dato} kl 15`).toBe(2)
      expect(timekostnad(p, 22), `${dato} kl 22`).toBe(2)
    }
  })

  test('dagen før 1. mai og 17. mai er IKKE aften', () => {
    for (const d of ['2026-04-30', '2026-05-16']) {
      expect(dagsprofiler([d], historikk(() => 100))[0].type, d).toBe('vanlig')
    }
  })

  test('aftener måles hver for seg, ikke som en vanlig torsdag', () => {
    // Julaften 2025 (onsdag) med halve trykket. Vanlige onsdager skal ikke
    // dras ned, og julaften 2026 skal arve nivået.
    const h = historikk((d) => (d === '2025-12-24' ? 50 : 100))
    const p = dagsprofiler(['2026-12-24'], h)[0]
    expect(p.faktor).toBeCloseTo(0.5, 2)
    expect(p.grunnlag).toBe(1)
  })
})

describe('rodtPaaslagTimer', () => {
  const apent = Array.from({ length: 19 }, (_, i) => i + 5) // 05–23

  test('setter et tall på hva de røde dagene tar ekstra', () => {
    // Mai 2026: 1. mai, Kristi himmelfart 14., Grunnlovsdagen 17.,
    // pinse 24.–25., og pinseaften 23. (rød fra 15).
    const p = dagsprofiler(datoerIMaaned(2026, 5), historikk(() => 100))
    const rode = p.filter((x) => x.type === 'rod').length
    // Fem hele dager x 19 timer, pluss ni timer (15–23) på pinseaften.
    expect(rodtPaaslagTimer(p, () => apent)).toBe(rode * 19 + 9)
  })

  test('en aften koster bare timene etter 15', () => {
    const p = dagsprofiler(['2026-12-24'], historikk(() => 100))
    expect(rodtPaaslagTimer(p, () => apent)).toBe(9) // 15,16,…,23
  })

  test('null røde dager koster ingenting ekstra', () => {
    const p = dagsprofiler(datoerIMaaned(2026, 9), historikk(() => 100))
    expect(rodtPaaslagTimer(p, () => apent)).toBe(0)
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
