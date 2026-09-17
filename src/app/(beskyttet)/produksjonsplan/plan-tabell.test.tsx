// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { act, createElement as h } from 'react'
import { createRoot, type Root } from 'react-dom/client'
const mock = vi.hoisted(() => ({ publiser: vi.fn(), setLinje: vi.fn(), setNotat: vi.fn(), setProsent: vi.fn() }))
vi.mock('./handlinger', () => mock)
import { PlanTabell } from './plan-tabell'
Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
let host: HTMLDivElement
const produkter = ['Bolle', 'Baguett'].map((varenavn) => ({ varenavn, baseline: 5, faktor: 1, foreslatt: 5, planlagt: 5, start_antall: 2, ekskludert: false }))
beforeEach(() => {
  Object.values(mock).forEach((f) => f.mockReset())
  mock.publiser.mockResolvedValue({ ok: true })
  mock.setLinje.mockResolvedValue(undefined)
  mock.setNotat.mockResolvedValue(undefined)
  mock.setProsent.mockResolvedValue(undefined)
})
afterEach(() => { act(() => root?.unmount()); document.body.replaceChildren() })
function monter(publisertTid: string | null = null) {
  host = document.createElement('div'); document.body.append(host); root = createRoot(host)
  act(() => root.render(h(PlanTabell, { grupper: [{ kode: '1201', navn: 'Bakevarer', produkter }], stasjonId: 'station-a', dato: '2026-09-19', notat: null, publisertTid, prosent: { start: 40, margin: 0 }, gruppeAvvik: {} })))
}
function knapp(tekst: string) { return [...host.querySelectorAll('button')].find((b) => b.textContent === tekst)! }
describe('publisert betyr et bekreftet komplett plansnapshot', () => {
  test('første publisering sender begge urørte produkter', async () => {
    monter()
    await act(async () => knapp('Publiser til nettbrettet').click())
    expect(mock.publiser.mock.calls[0][2]).toHaveLength(2)
    expect(mock.publiser.mock.calls[0][2].map((l: { varenavn: string }) => l.varenavn)).toEqual(['Bolle', 'Baguett'])
    expect(host.textContent).toContain('Synlig på nettbrettet')
  })
  test('delvis redigering beholder den urørte linjen ved gjenpublisering', async () => {
    monter('2026-09-18T12:00:00Z')
    await act(async () => host.querySelector<HTMLButtonElement>('input[aria-label="Planlagt Bolle"] + button')!.click())
    await act(async () => knapp('Publiser på nytt').click())
    expect(mock.publiser.mock.calls[0][2].map((l: { planlagt: number }) => l.planlagt)).toEqual([6, 5])
  })
  test('feilet publisering viser feil og beholder utkaststatus', async () => {
    mock.publiser.mockResolvedValue({ ok: false, feil: 'Transaksjonen feilet' })
    monter()
    await act(async () => knapp('Publiser til nettbrettet').click())
    expect(host.querySelector('[role="alert"]')?.textContent).toBe('Transaksjonen feilet')
    expect(host.textContent).toContain('Ikke publisert ennå')
    expect(host.textContent).not.toContain('Publisert ✓')
  })
  test('linjefeil flytter ikke bekreftet antall og venting sperrer dobbelttrykk', async () => {
    let avvis!: () => void
    mock.setLinje.mockImplementation(() => new Promise<void>((_, reject) => { avvis = () => reject(new Error('write failed')) }))
    monter()
    const mer = host.querySelector<HTMLButtonElement>('input[aria-label="Planlagt Bolle"] + button')!
    act(() => { mer.click(); mer.click() })
    expect(mock.setLinje).toHaveBeenCalledTimes(1)
    expect(knapp('Publiser til nettbrettet').disabled).toBe(true)
    await act(async () => avvis())
    expect(host.querySelector<HTMLInputElement>('input[aria-label="Planlagt Bolle"]')?.value).toBe('5')
    expect(host.querySelector('[role="alert"]')?.textContent).toContain('ikke lagret')
  })
  test('massefeil gir ikke en vellykket kvittering', async () => {
    mock.setLinje.mockRejectedValue(new Error('write failed'))
    monter()
    await act(async () => knapp('Skriv over dagens tall').click())
    expect(host.querySelector('[role="alert"]')).not.toBeNull()
    expect(host.textContent).not.toContain('produkter satt fra prosentene')
  })
  test('flersifret tall lagres samlet på blur, ugyldig start lagres ikke', async () => {
    monter()
    const input = host.querySelector<HTMLInputElement>('input[aria-label="Planlagt Bolle"]')!
    act(() => { input.focus(); input.value = '125'; input.dispatchEvent(new Event('input', { bubbles: true })) })
    expect(mock.setLinje).not.toHaveBeenCalled()
    await act(async () => input.blur())
    expect(mock.setLinje).toHaveBeenCalledWith(expect.objectContaining({ varenavn: 'Bolle', planlagt: 125 }))
    const start = host.querySelector<HTMLInputElement>('input[aria-label="Start Baguett"]')!
    act(() => { start.focus(); start.value = '6' })
    await act(async () => start.blur())
    expect(mock.setLinje).toHaveBeenCalledTimes(1)
    expect(host.querySelector('[role="alert"]')?.textContent).toContain('Startpartiet')
    expect(host.querySelector<HTMLInputElement>('input[aria-label="Start Baguett"]')?.value).toBe('2')
  })
})
