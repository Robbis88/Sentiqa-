// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { act, createElement as h } from 'react'
import { createRoot, type Root } from 'react-dom/client'

// =====================================================================
// TRE TILSTANDER, OG DE MAA VAERE TRE
// =====================================================================
//
//   sender      handlingen er underveis
//   resultat    serveren har svart, og svaret skal staa
//   oppfrisker  visningen hentes paa nytt
//
// Den tredje skal ALDRI holde den foerste aapen eller skjule den andre.
// Maalt paa `main` 2026-09-14: POST svarte 200 paa 0,5 s, nettverket var
// stille fra 2,14 s, og likevel sto knappen «Bygger …» uten kvittering
// da timeouten slo inn paa 20,99 s. Se `oppfriskvakt.test.ts` for
// rotaarsaken.
//
// ---------------------------------------------------------------------
// HVORFOR IKKE @testing-library/react
//
// Repoet har den ikke, og resten av jsdom-testene bruker
// `renderToStaticMarkup`. Den kan ikke drive hooks. `react-dom/client`
// + `act` gjoer jobben uten aa dra inn en ny avhengighet for en fil.
// =====================================================================

vi.mock('next/navigation', () => ({
  useRouter: () => ({ refresh: (globalThis as Record<string, unknown>)
    .__oppfrisk as () => void }),
}))

const { HandlingKnapp } = await import('./handling-knapp')

let vert: HTMLDivElement
let rot: Root

beforeEach(() => {
  ;(globalThis as Record<string, unknown>).IS_REACT_ACT_ENVIRONMENT = true
  vert = document.createElement('div')
  document.body.appendChild(vert)
  rot = createRoot(vert)
})

afterEach(() => {
  act(() => rot.unmount())
  vert.remove()
  vi.restoreAllMocks()
})

const knapp = () => vert.querySelector('button') as HTMLButtonElement
const skjema = () => vert.querySelector('form') as HTMLFormElement
const kvittering = () => vert.querySelector('.sq-slett-ok')?.textContent ?? null
const feil = () => vert.querySelector('.sq-slett-feil')?.textContent ?? null

/** En handling vi styrer selv: den svarer foerst naar vi sier fra. */
function styrtHandling() {
  const kall: string[] = []
  let slipp: (k: { ok?: string; feil?: string }) => void = () => {}
  const handling = async () => {
    kall.push('kall')
    return new Promise<{ ok?: string; feil?: string }>((r) => { slipp = r })
  }
  return { kall, handling, svar: (k: { ok?: string; feil?: string }) => slipp(k) }
}

async function tegn(props: Record<string, unknown>) {
  await act(async () => {
    rot.render(h(HandlingKnapp as never, { merke: 'Bygg', ...props }))
  })
}

describe('kvitteringen er uavhengig av oppfriskningen', () => {
  test('svaret staar med én gang, selv om oppfriskningen aldri fullfoerer', async () => {
    // En `router.refresh()` som ALDRI gjoer noe. Henger kvitteringen paa
    // den, ser vi det her - og det var nettopp det som skjedde i prod.
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => {}

    const { handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true, arbeider: 'Bygger …' })

    await act(async () => { skjema().requestSubmit() })
    expect(knapp().disabled, 'knappen skal vaere laast mens den sender').toBe(true)
    expect(knapp().textContent).toContain('Bygger')

    await act(async () => { svar({ ok: 'Bygget 5 utkast for 2026-07.' }) })

    expect(kvittering()).toBe('Bygget 5 utkast for 2026-07.')
    expect(knapp().disabled, 'knappen skal vaere aapen naar svaret er kommet').toBe(false)
    expect(knapp().textContent).toContain('Bygg')
  })

  test('en oppfriskning som kaster feller ikke kvitteringen', async () => {
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => {
      throw new Error('RSC nede')
    }

    const { handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true })

    await act(async () => { skjema().requestSubmit() })
    await act(async () => { svar({ ok: 'Sluppet.' }) })

    expect(kvittering()).toBe('Sluppet.')
    expect(knapp().disabled).toBe(false)
  })

  test('en feilet handling friskes ikke opp', async () => {
    let frisket = 0
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => { frisket++ }

    const { handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true })

    await act(async () => { skjema().requestSubmit() })
    await act(async () => { svar({ feil: 'Gikk ikke.' }) })

    expect(feil()).toBe('Gikk ikke.')
    expect(kvittering()).toBeNull()
    expect(frisket, 'en feil skal ikke se ut som suksess').toBe(0)
  })

  test('oppfrisk er av som standard', async () => {
    let frisket = 0
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => { frisket++ }

    const { handling, svar } = styrtHandling()
    await tegn({ handling })

    await act(async () => { skjema().requestSubmit() })
    await act(async () => { svar({ ok: 'Slettet.' }) })

    expect(kvittering()).toBe('Slettet.')
    expect(frisket, 'de 25 andre kallstedene skal vaere uendret').toBe(0)
  })

  test('oppfriskes én gang per resultat, ikke per render', async () => {
    let frisket = 0
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => { frisket++ }

    const { handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true })

    await act(async () => { skjema().requestSubmit() })
    await act(async () => { svar({ ok: 'Bygget.' }) })
    // En ny render med samme resultat skal ikke utloese en ny runde.
    await tegn({ handling, oppfrisk: true })

    expect(frisket).toBe(1)
  })
})

describe('to raske innsendinger gir én kjoering', () => {
  test('den andre innsendingen naar aldri handlingen', async () => {
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => {}

    const { kall, handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true })

    // BEGGE I SAMME TIKK. Det er hele poenget: React setter `disabled`
    // ved neste render, og et dobbeltklikk rekker aa komme foer den.
    // Laasen maa derfor vaere synkron, ikke en render-egenskap.
    await act(async () => {
      skjema().requestSubmit()
      skjema().requestSubmit()
    })

    expect(kall.length, 'handlingen skal ha kjoert nøyaktig én gang').toBe(1)

    await act(async () => { svar({ ok: 'Bygget.' }) })
    expect(kvittering()).toBe('Bygget.')
  })

  test('laasen aapnes igjen etter at svaret er kommet', async () => {
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => {}

    const { kall, handling, svar } = styrtHandling()
    await tegn({ handling, oppfrisk: true })

    await act(async () => { skjema().requestSubmit() })
    await act(async () => { svar({ ok: 'Bygget.' }) })
    await act(async () => { skjema().requestSubmit() })

    expect(kall.length, 'en ny, bevisst kjoering skal gaa gjennom').toBe(2)
  })

  test('et avbrutt spoersmaal laaser ikke knappen for godt', async () => {
    ;(globalThis as Record<string, unknown>).__oppfrisk = () => {}
    const bekreft = vi.spyOn(window, 'confirm')

    const { kall, handling } = styrtHandling()
    await tegn({ handling, oppfrisk: true, sporsmaal: 'Sikker?' })

    bekreft.mockReturnValue(false)
    await act(async () => { skjema().requestSubmit() })
    expect(kall.length, 'avbrutt betyr ikke kjoert').toBe(0)

    bekreft.mockReturnValue(true)
    await act(async () => { skjema().requestSubmit() })
    expect(kall.length, 'et nei skal ikke sperre for et senere ja').toBe(1)
  })
})
