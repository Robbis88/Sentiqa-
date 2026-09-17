// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, createElement as h } from 'react'
import { createRoot, type Root } from 'react-dom/client'

const mock = vi.hoisted(() => ({ svar: vi.fn() }))
vi.mock('@/app/(beskyttet)/sjekkpunkt/handlinger', () => ({ svarSjekkpunktTablet: mock.svar }))
import { TabletSjekk } from '@/app/(beskyttet)/sjekkpunkt/tablet-sjekk'
import { RutineTrykk } from '@/app/(beskyttet)/rutiner/rutinetrykk'

Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
function monter(element: Parameters<Root['render']>[0]) {
  const vert = document.createElement('div')
  document.body.append(vert)
  root = createRoot(vert)
  act(() => root.render(element))
  return vert
}
afterEach(() => { act(() => root?.unmount()); document.body.replaceChildren(); mock.svar.mockReset() })

const punkter = [
  { id: 'a', stasjonId: 'dale', sporsmaal: 'Sjekk kjølerommet', kritisk: true, klokkeslett: null, svar: null },
  { id: 'b', stasjonId: 'dale', sporsmaal: 'Sjekk neste punkt', kritisk: false, klokkeslett: null, svar: null },
]

describe('tablet: se → gjør → svar → neste krever bekreftet lagring', () => {
  it('gir feedback med én gang, sperrer dobbelttrykk og går videre først etter lagring', async () => {
    let ferdig!: (r: { ok: boolean }) => void
    mock.svar.mockReturnValue(new Promise((r) => { ferdig = r }))
    const vert = monter(h(TabletSjekk, { punkter }))
    const ja = vert.querySelector<HTMLButtonElement>('.tsjekk-ja')!
    act(() => { ja.click(); ja.click() })
    expect(mock.svar).toHaveBeenCalledTimes(1)
    expect(vert.querySelector('[role="status"]')?.textContent).toContain('Lagrer')
    expect(ja.disabled).toBe(true)
    expect(vert.querySelector('.tsjekk-sporsmaal')?.textContent).toBe('Sjekk kjølerommet')
    expect(vert.querySelector('.rutine-liste')).toBeNull()
    await act(async () => { ferdig({ ok: true }) })
    expect(vert.querySelector('.tsjekk-sporsmaal')?.textContent).toBe('Sjekk neste punkt')
    expect(vert.querySelector('.rutine-liste')?.textContent).toContain('Sjekk kjølerommet')
  })
  it('feil blir stående på samme spørsmål og kan prøves på nytt', async () => {
    mock.svar.mockResolvedValueOnce({ ok: false }).mockResolvedValueOnce({ ok: true })
    const vert = monter(h(TabletSjekk, { punkter }))
    await act(async () => { vert.querySelector<HTMLButtonElement>('.tsjekk-ja')!.click() })
    expect(vert.querySelector('[role="alert"]')).not.toBeNull()
    expect(vert.querySelector('.tsjekk-sporsmaal')?.textContent).toBe('Sjekk kjølerommet')
    await act(async () => { vert.querySelector<HTMLButtonElement>('.tsjekk-ja')!.click() })
    expect(vert.querySelector('[role="alert"]')).toBeNull()
    expect(vert.querySelector('.tsjekk-sporsmaal')?.textContent).toBe('Sjekk neste punkt')
  })
  it('rutinen viser venting og feil, og to raske innsendinger skriver bare én gang', async () => {
    let avvis!: (e: Error) => void
    const handling = vi.fn(() => new Promise<void>((_, reject) => { avvis = reject }))
    const vert = monter(h(RutineTrykk, {
      handling, felt: null, kropp: 'Rydd bakrommet', gjort: false,
      lagrerOrd: 'Lagrer …', feilOrd: 'Kunne ikke lagre. Prøv igjen.',
    }))
    const skjema = vert.querySelector('form')!
    act(() => { skjema.requestSubmit(); skjema.requestSubmit() })
    expect(handling).toHaveBeenCalledTimes(1)
    expect(vert.querySelector('[role="status"]')).not.toBeNull()
    expect(vert.querySelector<HTMLButtonElement>('button')!.disabled).toBe(true)
    await act(async () => { avvis(new Error('timeout')) })
    expect(vert.querySelector('[role="alert"]')?.textContent).toContain('Prøv igjen')
    expect(vert.querySelector<HTMLButtonElement>('button')!.disabled).toBe(false)
  })
})
