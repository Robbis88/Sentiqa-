import { describe, expect, test } from 'vitest'
import { motNormalen, ukedagFor, verdtEtBlikk, type Dagsrad } from './normalen'

// 2026-08-18 er en tirsdag. Tirsdagene før: 11., 4., 28.7., 21.7., 14.7.
const TIRSDAG = '2026-08-18'
const tirsdager = ['2026-08-11', '2026-08-04', '2026-07-28', '2026-07-21', '2026-07-14']
const onsdager = ['2026-08-12', '2026-08-05', '2026-07-29', '2026-07-22', '2026-07-15']

const rader = (datoer: string[], verdi: number | number[]): Dagsrad[] =>
  datoer.map((dato, i) => ({
    dato,
    omsetning: Array.isArray(verdi) ? verdi[i] : verdi,
  }))

describe('ukedagFor', () => {
  test('tolker datoen i UTC, så tidssoner ikke flytter ukedagen', () => {
    expect(ukedagFor('2026-08-18')).toBe(2) // tirsdag
    expect(ukedagFor('2026-08-16')).toBe(0) // søndag
  })
})

describe('motNormalen', () => {
  test('sammenligner med SAMME ukedag', () => {
    // Onsdagene ligger dobbelt så høyt. Tas de med, blir svaret feil.
    const m = motNormalen(TIRSDAG, 10_000, [
      ...rader(tirsdager, 10_000),
      ...rader(onsdager, 20_000),
    ])
    expect(m.normal).toBe(10_000)
    expect(m.avvikProsent).toBe(0)
  })

  test('bruker median, ikke snitt', () => {
    // Én 17. mai på 100 000 ville dratt snittet til 28 000. Medianen står
    // imot, og «normalen» blir noe som faktisk har skjedd.
    const m = motNormalen(TIRSDAG, 10_000, rader(tirsdager, [10_000, 10_000, 10_000, 10_000, 100_000]))
    expect(m.normal).toBe(10_000)
  })

  test('sier hvor mye over eller under, på norsk', () => {
    const m = motNormalen(TIRSDAG, 10_780, rader(tirsdager, 10_000))
    expect(m.tekst).toBe('+7,8 % mot en vanlig tirsdag')
  })

  test('under normalen får minustegn, ikke bindestrek', () => {
    const m = motNormalen(TIRSDAG, 9_000, rader(tirsdager, 10_000))
    expect(m.tekst).toBe('−10,0 % mot en vanlig tirsdag')
  })

  test('dagen selv teller ikke i sitt eget grunnlag', () => {
    const m = motNormalen(TIRSDAG, 50_000, [
      { dato: TIRSDAG, omsetning: 50_000 },
      ...rader(tirsdager, 10_000),
    ])
    expect(m.normal).toBe(10_000)
    expect(m.grunnlag).toBe(5)
  })

  test('for tynt grunnlag gir ingen påstand', () => {
    // Tre like ukedager er ikke en normal. Da sier vi heller ingenting.
    const m = motNormalen(TIRSDAG, 10_000, rader(tirsdager.slice(0, 3), 10_000))
    expect(m.grunnlag).toBe(3)
    expect(m.tekst).toBeNull()
  })

  test('fire er nok', () => {
    const m = motNormalen(TIRSDAG, 10_000, rader(tirsdager.slice(0, 4), 10_000))
    expect(m.tekst).not.toBeNull()
  })

  test('stengte dager teller ikke som normale', () => {
    // En dag med null omsetning er stengt, ikke en daarlig dag.
    const m = motNormalen(TIRSDAG, 10_000, rader(tirsdager, [10_000, 10_000, 0, 10_000, 10_000]))
    expect(m.grunnlag).toBe(4)
    expect(m.normal).toBe(10_000)
  })

  test('ingen historikk krasjer ikke', () => {
    const m = motNormalen(TIRSDAG, 10_000, [])
    expect(m.normal).toBe(0)
    expect(m.avvikProsent).toBe(0)
    expect(m.tekst).toBeNull()
  })

  test('ukedagen navngis på norsk', () => {
    expect(motNormalen('2026-08-16', 1, []).ukedag).toBe('søndag')
    expect(motNormalen('2026-08-15', 1, []).ukedag).toBe('lørdag')
  })
})

describe('verdtEtBlikk', () => {
  const med = (verdi: number) => motNormalen(TIRSDAG, verdi, rader(tirsdager, 10_000))

  test('under ti prosent er dagsvariasjon', () => {
    expect(verdtEtBlikk(med(10_500))).toBe(false)
    expect(verdtEtBlikk(med(9_500))).toBe(false)
  })

  test('over ti prosent har som regel en årsak', () => {
    expect(verdtEtBlikk(med(11_500))).toBe(true)
    expect(verdtEtBlikk(med(8_500))).toBe(true)
  })

  test('uten grunnlag er ingenting verdt et blikk', () => {
    expect(verdtEtBlikk(motNormalen(TIRSDAG, 99_999, []))).toBe(false)
  })
})
