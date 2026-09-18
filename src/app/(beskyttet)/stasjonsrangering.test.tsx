// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, expect, it } from 'vitest'
import { Stasjonsrangering, type RangRad } from './stasjonsrangering'
const rad = (navn: string, oms: number | null): RangRad => ({ navn,
  oms: { total: { regnskap: oms, budsjett: 1000 } }, brf: {},
  kost: { '501': { regnskap: 100, budsjett: 100 } }, kast: 0, usynlig: 0, usynligUtenVask: 0 })
const container = document.createElement('div')
const root = createRoot(container)
afterEach(() => { act(() => root.render(null)) })
function render(rader: RangRad[], fane?: string) {
  act(() => root.render(<Stasjonsrangering rader={rader} avdelinger={[]} />))
  if (fane) act(() => Array.from(container.querySelectorAll('button')).find(b => b.textContent === fane)!.click())
}
it('viser ukjent omsetning som mangel uten rangnummer eller grønt tall', () => {
  render([rad('Ukjent', null), rad('Kjent', 1000)])
  expect(container.querySelector('ol')!.textContent).not.toContain('Ukjent')
  expect(container.textContent).toContain('Ikke rangert — mangler gyldig grunnlag: Ukjent')
  expect(container.querySelector('ol')!.textContent).toContain('Kjent')
})
it('ukjent, null, negativ og ikke-endelig omsetning blir aldri grønn nullprosent', () => {
  render([rad('Ukjent', null), rad('Null', 0), rad('Negativ', -1), rad('NaN', NaN), rad('Gyldig', 1000)], 'Lønn %')
  expect(container.querySelectorAll('ol li')).toHaveLength(1)
  expect(container.querySelector('ol')!.textContent).toContain('Gyldig')
  expect(container.querySelector('ol')!.textContent).toContain('10.0 %')
  for (const navn of ['Ukjent', 'Null', 'Negativ', 'NaN']) expect(container.querySelector('ol')!.textContent).not.toContain(navn)
})
it('ekte nullomsetning er fortsatt et kjent beløp i omsetningsfanen', () => {
  render([rad('Null', 0)])
  expect(container.querySelector('ol')!.textContent).toContain('Null')
  expect(container.textContent).not.toContain('Ikke rangert')
})
