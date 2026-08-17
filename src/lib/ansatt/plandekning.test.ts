import { describe, expect, test } from 'vitest'
import { borteTimerPerMaaned, plandekning, TIMER_100, type Kontraktansatt } from './plandekning'

const a = (navn: string, prosent: number | null, ramme = false): Kontraktansatt =>
  ({ ansattNr: navn, navn, kontraktProsent: prosent, harRammeavtale: ramme })

/** Tolv måneder med samme behov, med unntak av det som overstyres. */
const behov = (grunn: number, over: Record<number, number> = {}) =>
  Array.from({ length: 12 }, (_, i) => ({ maned: i + 1, timer: over[i + 1] ?? grunn }))

// Fire hundre kontraktstimer i måneden: 100 + 60 + 50 + 36 %.
const stab = [a('Ida', 100), a('Ola', 60), a('Siri', 50), a('Kim', 36)]
const KAPASITET = stab.reduce((s, x) => s + (x.kontraktProsent! / 100) * TIMER_100, 0)

describe('plandekning', () => {
  test('kontraktene bærer planen', () => {
    const d = plandekning(stab, behov(KAPASITET - 50))
    expect(d.tiltak).toBe('dekket')
    expect(d.korte).toEqual([])
  })

  test('små avvik er støy, ikke et papirproblem', () => {
    // Ni timer over. Det er en vanlig uke, ikke en kontraktsendring.
    const d = plandekning(stab, behov(KAPASITET + 9))
    expect(d.tiltak).toBe('dekket')
  })

  test('én måned over er ekstravakter — rammeavtale', () => {
    const d = plandekning(stab, behov(KAPASITET - 50, { 12: KAPASITET + 80 }))
    expect(d.tiltak).toBe('ramme')
    expect(d.korte).toEqual([12])
    expect(d.melding).toContain('desember')
    expect(d.melding).toContain('rammeavtale')
  })

  test('juni–august på rad er sesong — midlertidige avtaler', () => {
    const d = plandekning(stab, behov(KAPASITET - 50, {
      6: KAPASITET + 60, 7: KAPASITET + 120, 8: KAPASITET + 70,
    }))
    expect(d.tiltak).toBe('midlertidig')
    expect(d.sesong).toEqual([6, 7, 8])
    expect(d.melding).toContain('juni, juli og august')
    expect(d.melding).toContain('midlertidige avtaler')
  })

  test('sesongen kan gå over nyttår', () => {
    const d = plandekning(stab, behov(KAPASITET - 50, {
      12: KAPASITET + 60, 1: KAPASITET + 60,
    }))
    expect(d.tiltak).toBe('midlertidig')
    expect(d.sesong).toEqual([12, 1])
  })

  test('spredte måneder er ikke sesong — da er stillingene for små', () => {
    const d = plandekning(stab, behov(KAPASITET - 50, {
      2: KAPASITET + 60, 7: KAPASITET + 60, 10: KAPASITET + 60,
    }))
    expect(d.tiltak).toBe('ny_stilling')
    expect(d.sesong).toBeNull()
    expect(d.melding).toContain('14-4 a')
  })

  test('ferie spiser kapasitet — ellers ser juli dekket ut', () => {
    // Samme behov hele året, men i juli er halve staben borte. Uten
    // fradraget ville juli sett like grei ut som mars.
    const uten = plandekning(stab, behov(KAPASITET - 20))
    expect(uten.tiltak).toBe('dekket')

    const med = plandekning(
      stab,
      behov(KAPASITET - 20).map((b) => (b.maned === 7 ? { ...b, borteTimer: 200 } : b)),
    )
    expect(med.tiltak).toBe('ramme')
    expect(med.korte).toEqual([7])
    expect(med.maaneder.find((m) => m.maned === 7)!.udekket).toBeCloseTo(180, 5)
  })

  test('uten bekreftede kontrakter gis det ingen råd — spørsmålet stilles', () => {
    const d = plandekning(
      [a('Ida', null), a('Ola', null), a('Siri', 50)],
      behov(1000),
    )
    expect(d.tiltak).toBe('ukjent_grunnlag')
    expect(d.utenKontrakt).toEqual(['Ida', 'Ola'])
    expect(d.melding).not.toContain('rammeavtale')
  })

  test('ingen ansatte gir ingen påstand', () => {
    const d = plandekning([], behov(500))
    expect(d.tiltak).toBe('ukjent_grunnlag')
    expect(d.melding).toContain('Ingen ansatte')
  })

  test('verste måned pekes ut — det er der man kjenner det', () => {
    const d = plandekning(stab, behov(KAPASITET - 50, {
      6: KAPASITET + 30, 7: KAPASITET + 150, 8: KAPASITET + 40,
    }))
    expect(d.verstMaaned).toBe(7)
  })

  test('kapasiteten blir aldri negativ', () => {
    const d = plandekning(stab, [{ maned: 1, timer: 100, borteTimer: 99999 }])
    expect(d.maaneder[0].kapasitet).toBe(0)
    expect(d.maaneder[0].udekket).toBe(100)
  })
})

describe('borteTimerPerMaaned', () => {
  test('hele juli borte er hele månedens kapasitet', () => {
    const b = borteTimerPerMaaned(
      [{ navn: 'Ida', fraDato: '2026-07-01', tilDato: '2026-07-31' }], stab, 2026)
    expect(b.get(7)).toBeCloseTo(TIMER_100, 5)
    expect(b.get(6)).toBeUndefined()
  })

  test('ferie som krysser månedsskiftet deles på begge', () => {
    // 25.06–08.07: seks dager i juni, åtte i juli.
    const b = borteTimerPerMaaned(
      [{ navn: 'Ida', fraDato: '2026-06-25', tilDato: '2026-07-08' }], stab, 2026)
    expect(b.get(6)).toBeCloseTo(TIMER_100 * (6 / 30), 5)
    expect(b.get(7)).toBeCloseTo(TIMER_100 * (8 / 31), 5)
  })

  test('fraværet veies av stillingen — en 36 %-stilling tar 36 % med seg', () => {
    const b = borteTimerPerMaaned(
      [{ navn: 'Kim', fraDato: '2026-07-01', tilDato: '2026-07-31' }], stab, 2026)
    expect(b.get(7)).toBeCloseTo(TIMER_100 * 0.36, 5)
  })

  test('butikksjefens ferie teller ikke her', () => {
    // Han står ikke i lista over timelønnede med kontrakt. Er han borte,
    // trenger planen FLERE timelønnstimer, ikke færre — og den effekten
    // ligger allerede i planen.
    const b = borteTimerPerMaaned(
      [{ navn: 'Butikksjefen', fraDato: '2026-07-01', tilDato: '2026-07-31' }], stab, 2026)
    expect(b.size).toBe(0)
  })

  test('navn matches uten hensyn til store bokstaver og mellomrom', () => {
    const b = borteTimerPerMaaned(
      [{ navn: '  ida  ', fraDato: '2026-03-01', tilDato: '2026-03-31' }], stab, 2026)
    expect(b.get(3)).toBeCloseTo(TIMER_100, 5)
  })

  test('bakvendte og ugyldige datoer hoppes over framfor å gi rare tall', () => {
    const b = borteTimerPerMaaned([
      { navn: 'Ida', fraDato: '2026-07-31', tilDato: '2026-07-01' },
      { navn: 'Ida', fraDato: 'tulletekst', tilDato: '2026-07-08' },
    ], stab, 2026)
    expect(b.size).toBe(0)
  })

  test('går ferien over nyttår, telles bare den delen som ligger i året', () => {
    const b = borteTimerPerMaaned(
      [{ navn: 'Ida', fraDato: '2025-12-20', tilDato: '2026-01-05' }], stab, 2026)
    expect(b.get(12)).toBeUndefined()
    expect(b.get(1)).toBeCloseTo(TIMER_100 * (5 / 31), 5)
  })
})
