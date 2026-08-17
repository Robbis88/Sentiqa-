import { describe, expect, test } from 'vitest'
import {
  KONTROLLTILTAK_VERSJON, maaBekrefte, RETTIGHETER, TILTAK,
} from './kontrolltiltak'

describe('kontrolltiltak', () => {
  test('hvert tiltak svarer på alle fire spørsmålene aml. § 9-2 stiller', () => {
    for (const t of TILTAK) {
      expect(t.hva.length, t.hva).toBeGreaterThan(3)
      expect(t.hvorfor.length, `hvorfor: ${t.hva}`).toBeGreaterThan(20)
      expect(t.hvemSer.length, `hvemSer: ${t.hva}`).toBeGreaterThan(5)
      expect(t.hvorLenge.length, `hvorLenge: ${t.hva}`).toBeGreaterThan(3)
    }
  })

  test('dekker det systemet faktisk registrerer', () => {
    const alt = TILTAK.map((t) => t.hva.toLowerCase()).join(' | ')
    for (const emne of ['stempler', 'arbeidsavtale', 'rutiner', 'fravær', 'puls']) {
      expect(alt, emne).toContain(emne)
    }
  })

  test('puls lover ikke anonymitet — og sier hvorfor', () => {
    // Nettbrettet lovet «anonym» mens ansatt_id ble lagret. Loftet er
    // trukket (0104): med ti pa jobb er en kommentar gjenkjennelig
    // uansett hva basen gjor.
    const puls = TILTAK.find((t) => t.hva.toLowerCase().includes('puls'))!
    expect(puls.merk).toBeDefined()
    expect(puls.merk).toContain('ikke anonymt')
    expect(puls.hvemSer).toContain('ikke')
  })

  test('sykefravær omtales som helseopplysning', () => {
    const fravaer = TILTAK.find((t) => t.hva.toLowerCase().includes('fravær'))!
    expect(fravaer.merk).toContain('helseopplysning')
  })

  test('rettighetene nevner både retting, sletting og Datatilsynet', () => {
    const alt = RETTIGHETER.map((r) => `${r.tittel} ${r.tekst}`).join(' ')
    expect(alt).toContain('rettet')
    expect(alt).toContain('slettet')
    expect(alt).toContain('Datatilsynet')
  })

  test('versjonen er en dato, så det går an å se hvor gammel teksten er', () => {
    expect(KONTROLLTILTAK_VERSJON).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  test('ny versjon krever ny bekreftelse', () => {
    expect(maaBekrefte(KONTROLLTILTAK_VERSJON)).toBe(false)
    expect(maaBekrefte('2020-01-01')).toBe(true)
    expect(maaBekrefte(null)).toBe(true)
  })
})
