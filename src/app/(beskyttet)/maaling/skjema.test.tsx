// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { act, createElement as h } from 'react'
import { createRoot, type Root } from 'react-dom/client'
const mock = vi.hoisted(() => ({ opprettMalekort: vi.fn(), sokVarerAksjon: vi.fn() }))
const router = vi.hoisted(() => ({ refresh: vi.fn() }))
vi.mock('next/navigation', () => ({ useRouter: () => router }))
vi.mock('./handlinger', () => mock)
import { MalekortSkjema } from './skjema'
Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
let host: HTMLDivElement
beforeEach(() => {
  Object.values(mock).forEach((f) => f.mockReset())
  host = document.createElement('div'); document.body.append(host); root = createRoot(host)
  act(() => root.render(h(MalekortSkjema, { tre: [] })))
})
afterEach(() => { act(() => root.unmount()); document.body.replaceChildren() })
function send() { host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })) }
describe('målekortskjemaets bekreftelse', () => {
  test('navngir varegruppen og søkefeltet tilgjengelig', () => {
    expect(host.querySelector('fieldset legend')?.textContent).toContain('På hvilke varer?')
    const label = [...host.querySelectorAll('label')].find((l) => l.textContent === 'Søk etter enkeltvare')!
    expect(host.querySelector(`[id="${label.htmlFor}"]`)).not.toBeNull()
  })
  test('avvist transport beholder felt og åpner for nytt forsøk uten suksess', async () => {
    mock.opprettMalekort.mockRejectedValue(new Error('network'))
    const navn = host.querySelector<HTMLInputElement>('input[name="navn"]')!
    navn.value = 'Bakevarer'
    await act(async () => send())
    expect(navn.value).toBe('Bakevarer')
    expect(host.querySelector('[role="alert"]')?.textContent).toContain('Kunne ikke bekrefte lagringen')
    expect(host.textContent).not.toContain('Målekort lagret.')
    expect(host.querySelector<HTMLButtonElement>('button[type="submit"]')!.disabled).toBe(false)
    mock.opprettMalekort.mockResolvedValue({ ok: true })
    await act(async () => send())
    expect(host.querySelector('[role="status"]')?.textContent).toContain('Målekort lagret.')
    expect(navn.value).toBe('')
  })
  test('venting sperrer samtidige innsendinger og serverfeil vises', async () => {
    let ferdig!: (res: { feil: string }) => void
    mock.opprettMalekort.mockImplementation(() => new Promise((resolve) => { ferdig = resolve }))
    await act(async () => { send(); send() })
    expect(mock.opprettMalekort).toHaveBeenCalledTimes(1)
    expect(host.querySelector('form')?.getAttribute('aria-busy')).toBe('true')
    await act(async () => ferdig({ feil: 'Kunne ikke lagre vareutvalg.' }))
    expect(host.querySelector('[role="alert"]')?.textContent).toBe('Kunne ikke lagre vareutvalg.')
    expect(host.querySelector('form')?.getAttribute('aria-busy')).toBe('false')
  })
  test('søkeavbrudd viser feil og lar brukeren prøve igjen', async () => {
    mock.sokVarerAksjon.mockRejectedValue(new Error('network'))
    const input = host.querySelector<HTMLInputElement>('.scope-sok input')!
    act(() => {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, 'bolle')
      input.dispatchEvent(new Event('input', { bubbles: true }))
    })
    const knapp = host.querySelector<HTMLButtonElement>('.scope-sok button')!
    await act(async () => knapp.click())
    expect(mock.sokVarerAksjon).toHaveBeenCalledWith('bolle')
    expect(host.querySelector('[role="alert"]')?.textContent).toContain('Kunne ikke søke')
    expect(knapp.disabled).toBe(false)
  })
})
