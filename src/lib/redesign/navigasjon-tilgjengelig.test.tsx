// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { act, createElement as h } from 'react'
import { createRoot, type Root } from 'react-dom/client'
const mock = vi.hoisted(() => ({ sti: '/oversikt', push: vi.fn(), mobil: true }))
vi.mock('next/navigation', () => ({ usePathname: () => mock.sti, useRouter: () => ({ push: mock.push }) }))
vi.mock('next/link', () => ({ default: ({ children, ...props }: React.AnchorHTMLAttributes<HTMLAnchorElement>) => h('a', props, children) }))
vi.mock('@/app/(beskyttet)/assistent/handlinger', () => ({ spørAssistent: vi.fn() }))
vi.mock('@/app/(beskyttet)/oversett-kontekst', () => ({ useT: () => (tekst: string) => tekst }))
import { Sidemeny } from '@/app/(beskyttet)/sidemeny'
import { Kommandopalett } from '@/app/(beskyttet)/kommandopalett'
import { TabletNav } from '@/app/(beskyttet)/tablet-nav'
Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
let vert: HTMLDivElement
beforeEach(() => {
  mock.sti = '/oversikt'; mock.mobil = true; mock.push.mockReset()
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: () => ({ matches: mock.mobil, addEventListener: vi.fn(), removeEventListener: vi.fn() }) })
  Object.defineProperty(HTMLDialogElement.prototype, 'showModal', { configurable: true, value() { this.setAttribute('open', '') } })
  Object.defineProperty(HTMLDialogElement.prototype, 'close', { configurable: true, value() { this.removeAttribute('open') } })
})
afterEach(() => { act(() => root?.unmount()); document.body.replaceChildren() })
function monter(element: React.ReactNode) {
  vert = document.createElement('div'); document.body.append(vert); root = createRoot(vert)
  act(() => root.render(element))
  return vert
}
const seksjoner = [{ tittel: '', punkter: [{ sti: '/oversikt', tekst: 'Hjem' }] }, { tittel: 'Drift', punkter: [{ sti: '/produksjonsplan', tekst: 'Produksjon' }] }]
describe('mobilmeny er en tilgjengelig skuff', () => {
  test('lukket meny er inert, åpning flytter fokus og gjør bakgrunnen inert', () => {
    monter(h('div', null, h(Sidemeny, { seksjoner }), h('main', null, h('button', null, 'Bakgrunn'))))
    const panel = vert.querySelector('aside')!
    expect(panel.hasAttribute('inert')).toBe(true)
    const utloser = vert.querySelector<HTMLButtonElement>('.meny-hamburger')!
    act(() => { utloser.focus(); utloser.click() })
    expect(panel.hasAttribute('inert')).toBe(false)
    expect(panel.getAttribute('role')).toBe('dialog')
    expect(panel.contains(document.activeElement)).toBe(true)
    expect(vert.querySelector('main')!.inert).toBe(true)
    act(() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })))
    expect(panel.hasAttribute('inert')).toBe(true)
    expect(vert.querySelector('main')!.inert).not.toBe(true)
    expect(document.activeElement).toBe(utloser)
  })
  test('Tab og Shift+Tab holder fokus i skuffen, og synlig lukkeknapp virker', () => {
    monter(h(Sidemeny, { seksjoner }))
    act(() => vert.querySelector<HTMLButtonElement>('.meny-hamburger')!.click())
    const panel = vert.querySelector('aside')!
    const elementer = [...panel.querySelectorAll<HTMLElement>('a[href], button')]
    act(() => { elementer.at(-1)!.focus(); elementer.at(-1)!.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true })) })
    expect(document.activeElement).toBe(elementer[0])
    act(() => elementer[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true, cancelable: true })))
    expect(document.activeElement).toBe(elementer.at(-1))
    act(() => elementer[0].click())
    expect(panel.hasAttribute('inert')).toBe(true)
  })
  test('desktopmenyen forblir vanlig synlig navigasjon', () => {
    mock.mobil = false
    monter(h(Sidemeny, { seksjoner }))
    expect(vert.querySelector('aside')!.hasAttribute('inert')).toBe(false)
    expect(vert.querySelector('aside')!.hasAttribute('role')).toBe(false)
  })
})
describe('paletten bruker native modal og fokusbare resultater', () => {
  test('åpner ekte dialog, navngir mobilknappen og gjenoppretter fokus', () => {
    monter(h(Kommandopalett, { punkter: [{ sti: '/salg', tekst: 'Salg', gruppe: 'Innsikt' }] }))
    const utloser = vert.querySelector<HTMLButtonElement>('.sq-sokknapp')!
    expect(utloser.getAttribute('aria-label')).toBe('Spør Sentiqa eller finn noe')
    act(() => { utloser.focus(); utloser.click() })
    const dialog = vert.querySelector('dialog')!
    expect(dialog.open).toBe(true)
    expect(document.activeElement).toBe(dialog.querySelector('input'))
    expect(dialog.querySelector('input')?.getAttribute('aria-label')).toBe('Spørsmål eller sidenavn')
    act(() => dialog.querySelector<HTMLButtonElement>('.sq-palett-resultat')!.click())
    expect(mock.push).toHaveBeenCalledWith('/salg')
    expect(vert.querySelector('dialog')).toBeNull()
    expect(document.activeElement).toBe(utloser)
  })
  test('native cancel lukker dialogen og returnerer fokus', () => {
    monter(h(Kommandopalett, { punkter: [] }))
    const utloser = vert.querySelector<HTMLButtonElement>('.sq-sokknapp')!
    act(() => { utloser.focus(); utloser.click() })
    act(() => vert.querySelector('dialog')!.dispatchEvent(new Event('cancel')))
    expect(vert.querySelector('dialog')).toBeNull()
    expect(document.activeElement).toBe(utloser)
  })
})
test('tabletnavigasjon annonserer valgt fane også på hjelpunderside', () => {
  mock.sti = '/lenker'
  monter(h(TabletNav))
  expect(vert.querySelector('nav')?.getAttribute('aria-label')).toBe('Hovedmeny')
  const valgt = vert.querySelectorAll('a[aria-current="page"]')
  expect(valgt).toHaveLength(1)
  expect(valgt[0].getAttribute('href')).toBe('/anvisninger')
})
