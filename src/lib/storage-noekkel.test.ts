import { describe, expect, test } from 'vitest'
import { trygtFilnavn } from './storage-noekkel'

describe('trygtFilnavn', () => {
  test('fila som faktisk feilet i produksjon', () => {
    // Invalid key: ...-Avtale om midlertidig ansettelse av mindreårig i
    // tariffbundet virksomhet.docx
    expect(trygtFilnavn('Avtale om midlertidig ansettelse av mindreårig i tariffbundet virksomhet.docx'))
      .toBe('Avtale-om-midlertidig-ansettelse-av-mindrearig-i-tariffbundet-virksomhet.docx')
  })

  test('alle tre norske bokstavene', () => {
    expect(trygtFilnavn('smørbrød på Bønes.pdf')).toBe('smorbrod-pa-Bones.pdf')
    expect(trygtFilnavn('ÆØÅ.docx')).toBe('AEOA.docx')
  })

  test('endelsen beholdes — den avgjør hvordan fila åpnes', () => {
    expect(trygtFilnavn('rapport.xlsx').endsWith('.xlsx')).toBe(true)
    expect(trygtFilnavn('uten endelse')).toBe('uten-endelse')
  })

  test('flere punktum: bare det siste er endelsen', () => {
    expect(trygtFilnavn('Basis Export 2026.05.13.pdf')).toBe('Basis-Export-2026.05.13.pdf')
  })

  test('rene ASCII-navn står urørt bortsett fra mellomrom', () => {
    // De fem malene som gikk gjennom fra før skal fortsatt se seg selv like.
    expect(trygtFilnavn('Avtale om fast ansettelse i tariffbundet virksomhet.docx'))
      .toBe('Avtale-om-fast-ansettelse-i-tariffbundet-virksomhet.docx')
  })

  test('striper aldri ut i noe som starter eller slutter på bindestrek', () => {
    expect(trygtFilnavn('   rart   navn   .pdf')).toBe('rart-navn.pdf')
    expect(trygtFilnavn('---.pdf')).toBe('fil.pdf')
  })

  test('et navn uten et eneste ASCII-tegn blir ikke tomt', () => {
    expect(trygtFilnavn('文档.pdf')).toBe('fil.pdf')
    expect(trygtFilnavn('')).toBe('fil')
  })

  test('lange navn kappes, endelsen overlever', () => {
    const langt = `${'a'.repeat(300)}.docx`
    const ut = trygtFilnavn(langt)
    expect(ut.length).toBeLessThanOrEqual(86)
    expect(ut.endsWith('.docx')).toBe(true)
  })

  test('resultatet inneholder bare tegn Storage godtar', () => {
    for (const n of [
      'Avtale om fast ansettelse av mindreårig i tariffbundet bedrift.docx',
      'Rammeavtale ved tilkalling i tariffbundet virksomhet.docx',
      'Vedlegg – kvittering (1).pdf',
      'C:\\Users\\rob_l\\rapport.xlsx',
    ]) {
      expect(trygtFilnavn(n), n).toMatch(/^[A-Za-z0-9._-]+$/)
    }
  })
})
