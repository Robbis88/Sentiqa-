// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, createElement } from 'react'
import { createRoot, type Root } from 'react-dom/client'
const mock = vi.hoisted(() => ({ refresh: vi.fn() }))
vi.mock('next/navigation', () => ({ useRouter: () => mock }))
import { AutoRefresh } from '@/app/(beskyttet)/auto-refresh'

Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
let root: Root
afterEach(() => { act(() => root?.unmount()); vi.useRealTimers(); vi.restoreAllMocks(); mock.refresh.mockReset(); document.body.replaceChildren() })

describe('tabletens bakgrunnsoppdatering', () => {
  it('henter bare naar skjermen er synlig og enheten er paa nett', () => {
    vi.useFakeTimers()
    const synlighet = vi.spyOn(document, 'visibilityState', 'get').mockReturnValue('visible')
    const online = vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(true)
    const vert = document.createElement('div'); document.body.append(vert)
    root = createRoot(vert)
    act(() => root.render(createElement(AutoRefresh, { sekunder: 30 })))
    act(() => vi.advanceTimersByTime(30000))
    expect(mock.refresh).toHaveBeenCalledTimes(1)
    synlighet.mockReturnValue('hidden')
    act(() => vi.advanceTimersByTime(90000))
    expect(mock.refresh).toHaveBeenCalledTimes(1)
    synlighet.mockReturnValue('visible'); online.mockReturnValue(false)
    act(() => { vi.advanceTimersByTime(30000); document.dispatchEvent(new Event('visibilitychange')) })
    expect(mock.refresh).toHaveBeenCalledTimes(1)
    online.mockReturnValue(true)
    act(() => document.dispatchEvent(new Event('visibilitychange')))
    expect(mock.refresh).toHaveBeenCalledTimes(2)
  })
})
