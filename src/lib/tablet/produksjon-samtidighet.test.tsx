// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest'
import { act, createElement } from 'react'
import { createRoot, type Root } from 'react-dom/client'

const mock = vi.hoisted(() => ({ logg: vi.fn() }))
vi.mock('@/app/(beskyttet)/produksjonsplan/handlinger', () => ({ loggLagd: mock.logg }))
vi.mock('@/app/(beskyttet)/oversett-kontekst', () => ({ useT: () => (s: string) => s }))
import { TabletPlan } from '@/app/(beskyttet)/produksjonsplan/tablet-plan'

Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
let vert: HTMLDivElement
afterEach(() => { act(() => root?.unmount()); mock.logg.mockReset(); document.body.replaceChildren() })

function utsatt() {
  let ok!: () => void
  let feil!: (e: Error) => void
  const promise = new Promise<void>((resolve, reject) => { ok = resolve; feil = reject })
  return { promise, ok, feil }
}
function vis() {
  vert = document.createElement('div'); document.body.append(vert)
  root = createRoot(vert)
  act(() => root.render(createElement(TabletPlan, {
    stasjonId: 'stasjon-a', dato: '2026-09-17', notat: null,
    grupper: [{ navn: 'Mat', produkter: ['Bolle', 'Pølse'].map((varenavn) => ({
      varenavn, planlagt: 10, start_antall: 3, lagd_hittil: 0,
    })) }],
  })))
}
function knapp(vare: number, etikett: string) {
  return vert.querySelectorAll('.pp-tab-rad')[vare].querySelector<HTMLButtonElement>(`button[aria-label="${etikett}"]`)!
}
function tall(vare = 0) { return vert.querySelectorAll<HTMLInputElement>('input')[vare].value }

it('beholder raske trykk før ny render og sender aldri overlappende kall for samme vare', async () => {
  const første = utsatt(), siste = utsatt()
  mock.logg.mockReturnValueOnce(første.promise).mockReturnValueOnce(siste.promise)
  vis()
  act(() => { knapp(0, '+').click(); knapp(0, '+').click(); knapp(0, '+').click() })
  expect(tall()).toBe('3')
  expect(mock.logg).toHaveBeenCalledTimes(1)
  expect(mock.logg).toHaveBeenNthCalledWith(1, 'stasjon-a', '2026-09-17', 'Bolle', 1)
  await act(async () => { første.ok(); await første.promise })
  expect(mock.logg).toHaveBeenCalledTimes(2)
  expect(mock.logg).toHaveBeenNthCalledWith(2, 'stasjon-a', '2026-09-17', 'Bolle', 3)
  await act(async () => { siste.ok(); await siste.promise })
  expect(tall()).toBe('3')
})

it('lar ikke en eldre feil angre nyere trykk og angre siste feil til bekreftet tall', async () => {
  const første = utsatt(), neste = utsatt(), siste = utsatt()
  mock.logg.mockReturnValueOnce(første.promise).mockReturnValueOnce(neste.promise).mockReturnValueOnce(siste.promise)
  vis()
  act(() => { knapp(0, '+').click(); knapp(0, '+').click() })
  await act(async () => { første.feil(new Error('eldre feil')); await første.promise.catch(() => {}) })
  expect(tall()).toBe('2')
  expect(vert.querySelector('[role="alert"]')).toBeNull()
  expect(mock.logg).toHaveBeenNthCalledWith(2, 'stasjon-a', '2026-09-17', 'Bolle', 2)
  await act(async () => { neste.ok(); await neste.promise })
  act(() => knapp(0, '+').click())
  expect(tall()).toBe('3')
  await act(async () => { siste.feil(new Error('siste feil')); await siste.promise.catch(() => {}) })
  expect(tall()).toBe('2')
  expect(vert.querySelector('[role="alert"]')?.textContent).toContain('Tallet ble ikke lagret')
})

it('lar to forskjellige varer lagres parallelt uten å blokkere hverandre', async () => {
  const bolle = utsatt(), pølse = utsatt()
  mock.logg.mockReturnValueOnce(bolle.promise).mockReturnValueOnce(pølse.promise)
  vis()
  act(() => { knapp(0, '+').click(); knapp(1, '+').click() })
  expect(mock.logg).toHaveBeenCalledTimes(2)
  expect(tall(0)).toBe('1'); expect(tall(1)).toBe('1')
  await act(async () => { pølse.ok(); await pølse.promise })
  await act(async () => { bolle.ok(); await bolle.promise })
})
