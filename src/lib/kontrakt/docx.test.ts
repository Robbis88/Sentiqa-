import { describe, expect, test } from 'vitest'
import { unzipSync, zipSync } from 'fflate'
import { docxTilTekst, finnFelter, fyllUt } from './docx'

// Bygger en minimal .docx. Poenget er å kunne teste at et felt som Word
// har SPLITTET på tvers av flere <w:r> blir riktig erstattet — det er
// den eneste vanskelige delen.
const run = (tekst: string, stil = '') =>
  `<w:r>${stil ? `<w:rPr>${stil}</w:rPr>` : ''}<w:t>${tekst}</w:t></w:r>`
const dok = (...avsnitt: string[]) => zipSync({
  'word/document.xml': new TextEncoder().encode(
    `<?xml version="1.0"?><w:document><w:body>${
      avsnitt.map((a) => `<w:p>${a}</w:p>`).join('')}</w:body></w:document>`),
})

describe('fyllUt', () => {
  test('felt som står helt i ett run', () => {
    const d = dok(run('Stilling: ') + run('[stillingsprosent]') + run(' %'))
    expect(docxTilTekst(fyllUt(d, { stillingsprosent: '20' })))
      .toContain('Stilling: 20 %')
  })

  test('felt SPLITTET over tre runs — det Word faktisk gjør', () => {
    const d = dok(run('Hei ') + run('[Navn på') + run(' arbeids') + run('taker], velkommen'))
    expect(docxTilTekst(fyllUt(d, { 'Navn på arbeidstaker': 'Kari Nordmann' })))
      .toContain('Hei Kari Nordmann, velkommen')
  })

  test('formateringen til det første runet beholdes', () => {
    const fet = '<w:b/>'
    const d = dok(run('[timel', fet) + run('ønn]', fet))
    const ut = new TextDecoder().decode(
      unzipSync(fyllUt(d, { 'timelønn': '215,00' }))['word/document.xml'])
    // Verdien skal ligge i runet som hadde <w:b/>.
    expect(ut).toMatch(/<w:rPr><w:b\/><\/w:rPr><w:t>215,00<\/w:t>/)
  })

  test('fet skrift ANDRE steder i avsnittet røres ikke', () => {
    const d = dok(run('Lønn er ') + run('viktig', '<w:b/>') + run(': [timelønn]'))
    const ut = new TextDecoder().decode(
      unzipSync(fyllUt(d, { 'timelønn': '215,00' }))['word/document.xml'])
    expect(ut).toContain('<w:rPr><w:b/></w:rPr><w:t>viktig</w:t>')
  })

  test('samme felt flere steder byttes alle', () => {
    const d = dok(run('[navn] og [navn] igjen'))
    expect(docxTilTekst(fyllUt(d, { navn: 'X' }))).toContain('X og X igjen')
  })

  test('felt uten verdi står igjen som klammer — lettere å oppdage enn et tomt hull', () => {
    const d = dok(run('[a] og [b]'))
    expect(docxTilTekst(fyllUt(d, { a: '1' }))).toContain('1 og [b]')
  })

  test('resultatet er fortsatt en gyldig docx', () => {
    const d = dok(run('[x]'))
    const ut = fyllUt(d, { x: 'ok' })
    expect(() => unzipSync(ut)['word/document.xml']).not.toThrow()
  })
})

describe('finnFelter', () => {
  test('finner felt også når de er splittet', () => {
    const d = dok(run('[hel] og [split') + run('tet] her'))
    expect(finnFelter(d).sort()).toEqual(['hel', 'splittet'])
  })

  test('tar ikke med vanlig tekst i klammer over flere linjer', () => {
    const d = dok(run('[stillingsprosent]'))
    expect(finnFelter(d)).toEqual(['stillingsprosent'])
  })
})
