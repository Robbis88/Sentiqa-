// @vitest-environment jsdom
import { describe, expect, test } from 'vitest'
import { createElement as h } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MalekortTablet, formaterMalekort } from './maaling-tablet'
import { tabletKort, type TabletKort } from '@/lib/malekort'

const klar: TabletKort = { navn: 'Bakevarer', klar: true, etikett: 'Uke 37 · 7.–13. september 2026', enhet: 'antall', verdi: 0.25, topp: 0.5, rang: 2, antall: 3, perKunde: true }
function vis(kort: TabletKort[]) {
  const host = document.createElement('div')
  host.innerHTML = renderToStaticMarkup(h(MalekortTablet, { kort }))
  return host.textContent ?? ''
}
describe('nettbrettets målingsforklaring', () => {
  test('viser perioden og små mengder per kunde uten avrunding til null', () => {
    const tekst = vis([klar])
    expect(tekst).toContain(klar.etikett)
    expect(tekst).toContain('0,25 stk. per kunde')
    expect(tekst).toContain('nr 2 av 3')
  })
  test('lavest er best gir positiv avstand til lederen', () => {
    expect(vis([{ ...klar, verdi: 0.5, topp: 0.25 }])).toContain('0,25 stk. per kunde til 1. plass')
  })
  test('vekstforskjell vises som prosentpoeng uten fortegn', () => {
    expect(vis([{ ...klar, enhet: 'pst', verdi: 5.5, topp: 8, perKunde: false }])).toContain('2,5 prosentpoeng til 1. plass')
    expect(formaterMalekort(-1.25, 'pst')).toBe('−1,25 %')
    expect(formaterMalekort(7.5, 'kr', true)).toBe('7,5 kr per kunde')
    expect(vis([{ ...klar, metrikk: 'kunder', perKunde: false, verdi: 125 }])).toContain('125 kunder')
    expect(vis([{ ...klar, metrikk: 'snittbong', enhet: 'kr', perKunde: false, verdi: 25.5 }])).toContain('25,5 kr per bong')
  })
  test('skiller ikke delt, venting og feil og beholder klare kort ved delvis feil', () => {
    expect(vis([])).toContain('Ingen målekort er delt')
    const tekst = vis([klar, { navn: 'Drikke', klar: false, grunn: 'Venter på fullstendige tall for perioden.' }, { navn: 'Mat', klar: false, status: 'feil' }])
    expect(tekst).toContain('Venter på fullstendige tall')
    expect(tekst).toContain('Kunne ikke hente målingen')
    expect(tekst).toContain('0,25 stk. per kunde')
  })
  test('tabletuttrekket beholder bare egen rad og anonym toppverdi med enhetskontekst', () => {
    const kort = tabletKort('Bakevarer', { klar: true, enhet: 'antall', etikett: 'Uke 37', rader: [
      { stasjonId: 'annen', navn: 'Hemmelig butikknavn', verdi: 0.5, vekstPst: null },
      { stasjonId: 'egen', navn: 'Egen butikk', verdi: 0.25, vekstPst: null },
    ] }, 'egen', { normalisering: 'per_kunde', metrikk: 'antall' })
    expect(kort).toMatchObject({ rang: 2, topp: 0.5, perKunde: true })
    expect(JSON.stringify(kort)).not.toContain('Hemmelig butikknavn')
  })
})
