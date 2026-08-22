import { describe, expect, test } from 'vitest'
import { alleMaaLykkes, maaLykkes, traffEnRad } from './skriv-svar'

describe('maaLykkes', () => {
  test('slipper et vellykket svar rett gjennom', () => {
    const svar = { error: null, count: 1 }
    expect(maaLykkes(svar, 'slette lenke')).toBe(svar)
  })

  test('kaster med det brukeren forsøkte, ikke med tabellnavnet', () => {
    // Teksten havner foran øynene på den som trykket. «delete on
    // lenker» sier ingenting til den som trykket «Slett».
    expect(() => maaLykkes(
      { error: { message: 'permission denied', code: '42501' } },
      'slette lenke',
    )).toThrow(/Klarte ikke slette lenke \[42501\]: permission denied/)
  })

  test('koden er med når den finnes, og utelates når den ikke er det', () => {
    // 42501 er RLS, 23503 er fremmednøkkel, 23505 er dublett. Uten koden
    // må den som feilsøker gjette hvilken av de tre det var.
    expect(() => maaLykkes({ error: { message: 'nei' } }, 'lagre'))
      .toThrow('Klarte ikke lagre: nei')
  })
})

describe('traffEnRad', () => {
  test('null rader er ikke en feil for PostgREST, men er det for oss', () => {
    // DEN STILLE FORMEN. `update ... where id = x` som ikke treffer noe
    // gir error: null. Er raden filtrert bort av RLS, ser det identisk
    // ut med å ha lykkes.
    expect(() => traffEnRad({ error: null, count: 0 }, 'slette lenke'))
      .toThrow(/Ingen rader ble endret/)
  })

  test('en truffet rad går gjennom', () => {
    expect(traffEnRad({ error: null, count: 1 }, 'slette lenke').count).toBe(1)
  })

  test('KANARIFUGL: uten count blir kontrollen pynt, og da sier den fra', () => {
    // Glemmer man `{ count: 'exact' }`, er count null. Gikk det stille
    // gjennom, ville denne vakten vært grønn uten å måle noe — og det
    // ser nøyaktig ut som en vakt som ikke finner noe.
    expect(() => traffEnRad({ error: null }, 'slette lenke'))
      .toThrow(/mangler \{ count: 'exact' \}/)
  })

  test('feilen slår ut før tellingen', () => {
    expect(() => traffEnRad({ error: { message: 'nei' }, count: 0 }, 'lagre'))
      .toThrow('Klarte ikke lagre: nei')
  })
})

describe('alleMaaLykkes', () => {
  test('en feil midt i bunken stopper hele', () => {
    // Tolv update-kall via Promise.all. Promise-en loeser seg selv om
    // hvert eneste svar inneholder en feil.
    expect(() => alleMaaLykkes(
      [{ error: null }, { error: { message: 'nei' } }, { error: null }],
      'oppdatere rekkefølge',
    )).toThrow('Klarte ikke oppdatere rekkefølge: nei')
  })

  test('en tom bunke er ikke en feil', () => {
    // Ingen rader å sortere er en gyldig tilstand, ikke en stille feil.
    expect(alleMaaLykkes([], 'oppdatere rekkefølge')).toEqual([])
  })

  test('alle vellykkede går gjennom', () => {
    expect(alleMaaLykkes([{ error: null }, { error: null }], 'lagre')).toHaveLength(2)
  })
})
