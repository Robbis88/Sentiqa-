import type { Page, Request } from '@playwright/test'

// Samme URL kan ha flere samtidige kall. Hendelser kobles paa Request-identitet.
export type Kall = {
  url: string
  sendt: number
  /** Responsheaderne mottatt. */
  svar: number | null
  status: number | null
  /** Kroppen mottatt. */
  ferdig: number | null
  feilet: number | null
}

export function lytt(side: Page, t0: () => number) {
  const handling: Kall[] = []
  const rsc: Kall[] = []
  const revalidert: (string | null)[] = []
  const perForespoersel = new Map<Request, Kall>()

  const erHandling = (r: Request) =>
    r.method() === 'POST' && !!r.headers()['next-action']
  const listeFor = (r: Request) =>
    erHandling(r) ? handling : r.url().includes('_rsc=') ? rsc : null
  side.on('request', (r) => {
    const liste = listeFor(r)
    if (!liste) return
    const k: Kall = {
      url: r.url(),
      sendt: Date.now() - t0(),
      svar: null,
      status: null,
      ferdig: null,
      feilet: null,
    }
    liste.push(k)
    perForespoersel.set(r, k)
  })
  side.on('response', (r) => {
    const req = r.request()
    const liste = listeFor(req)
    if (!liste) return
    if (erHandling(req)) revalidert.push(r.headers()['x-action-revalidated'] ?? null)
    const k = perForespoersel.get(req)
    if (!k) return
    k.svar = Date.now() - t0()
    k.status = r.status()
  })
  side.on('requestfinished', (r) => {
    const k = perForespoersel.get(r)
    if (k) k.ferdig = Date.now() - t0()
  })
  side.on('requestfailed', (r) => {
    const k = perForespoersel.get(r)
    if (k) k.feilet = Date.now() - t0()
  })

  return { handling, rsc, revalidert }
}

