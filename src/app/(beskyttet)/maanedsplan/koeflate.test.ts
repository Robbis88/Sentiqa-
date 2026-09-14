// =====================================================================
// PRODUKSJONSFORMEN, TEGNET
// =====================================================================
//
// Sonden `supabase/tests/koe_etter_deploy.sql` beviser hva sida SKAL
// vise. Den kan ikke bevise at flaten tegner det.
//
// Denne kjører hele serverkomponenten med produksjonsformen slik den ble
// målt 2026-09-14 mot `0ea4a72`:
//
//   januar–juni   5 utkast hver    = 30
//   juli          5 sluppet, 0 utkast
//
// og krever de faktiske setningene. Da er avstanden mellom «dataene sier
// juli» og «skjermen sier juli» lukket for alt annet enn hydrering, CSS
// og selve dialogen — som fortsatt må ses av et menneske.
//
// HARNESSEN ER `byggtilstand.test.ts` SIN. Samme mock, samme direkte
// kall på serverkomponenten. To filer fordi de måler to ting: den
// byggknappen, denne køen.
// =====================================================================

import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ReactElement } from 'react'
import { Plankort } from './plankort'

const tilstand = {
  rolle: 'retailer_admin' as string,
  stasjoner: [] as { id: string }[],
  dekning: [] as unknown[],
  planer: [] as Record<string, unknown>[],
}

vi.mock('@/lib/auth/dal', () => ({
  hentInnloggetBruker: async () => ({ rolle: tilstand.rolle, retailerId: 'r1' }),
}))

vi.mock('@/lib/supabase/server', () => ({
  lagSupabaseServerKlient: async () => ({
    from(tabell: string) {
      const b: Record<string, unknown> = {}
      for (const ledd of ['select', 'eq', 'in', 'is', 'lte', 'order', 'limit', 'overrideTypes']) {
        b[ledd] = () => b
      }
      b.then = (ok: (v: unknown) => void) => ok({
        data: tabell === 'stasjoner' ? tilstand.stasjoner
          : tabell === 'v_kurs_maanedstall' ? tilstand.dekning
            : tilstand.planer,
        error: null,
      })
      return b
    },
  }),
}))

const STASJONER = ['Dale', 'Boenes', 'Laguneparken', 'Varden', 'Lone']

/** Fem planer i én maaned, én per stasjon. */
function maaned(m: string, status: string): Record<string, unknown>[] {
  return STASJONER.map((navn, i) => ({
    id: `${m}-${i}`,
    maaned: m,
    dom: 'flat',
    ingress: `Ingress for ${navn}`,
    punkter: [],
    merknad: null,
    status,
    stasjoner: { navn },
    matkast: null,
    usynlig: null,
    rangering: null,
  }))
}

/**
 * Produksjonsformen slik den ble maalt 2026-09-14.
 *
 * SEKS MAANEDER MED UTKAST, OG EN FERDIGBEHANDLET JULI OEVERST. Det er
 * nettopp den formen som avslorte at den gamle regelen var feil.
 */
const PRODUKSJONSFORM = [
  ...maaned('2026-07-01', 'sluppet'),
  ...maaned('2026-06-01', 'utkast'),
  ...maaned('2026-05-01', 'utkast'),
  ...maaned('2026-04-01', 'utkast'),
  ...maaned('2026-03-01', 'utkast'),
  ...maaned('2026-02-01', 'utkast'),
  ...maaned('2026-01-01', 'utkast'),
]

async function side(sok: { maned?: string; ar?: string } = {}) {
  const modul = await import('./page')
  return (await modul.default({ searchParams: Promise.resolve(sok) })) as ReactElement
}

/**
 * All tekst i treet, ogsaa den som ligger i props.
 *
 * `Tomtilstand` og `Forklaring` tar tittel og forklaring som PROPS, ikke
 * som children. En samler som bare leste children ville funnet ingenting
 * og gjort hver `toContain` under til en paastand om tomhet.
 */
function tekst(node: unknown): string {
  if (node === null || node === undefined || typeof node === 'boolean') return ''
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  // BARN SETTES SAMMEN UTEN SKILLETEGN, slik React gjor det. Med `' '`
  // ble «Koeen viser {maaned}.» til «Koeen viser  juni 2026 .», og da
  // maalte fila sin egen sammensetning i stedet for sidas tekst.
  if (Array.isArray(node)) return node.map(tekst).join('')
  const el = node as ReactElement & { props?: Record<string, unknown> }
  if (!el.props) return ''
  // PROPS skilles derimot med mellomrom: `tittel` og `forklaring` er to
  // ulike setninger og skal ikke loepe sammen.
  return Object.values(el.props).map(tekst).join(' ')
}

/** Alle `Plankort` i treet, med propsene sine. */
function plankort(node: unknown, ut: Record<string, unknown>[] = []): Record<string, unknown>[] {
  if (node === null || node === undefined || typeof node !== 'object') return ut
  if (Array.isArray(node)) { for (const n of node) plankort(n, ut); return ut }
  const el = node as ReactElement & { props?: Record<string, unknown> }
  if (el.type === Plankort && el.props) ut.push(el.props)
  if (el.props) for (const v of Object.values(el.props)) plankort(v, ut)
  return ut
}

beforeEach(() => {
  tilstand.rolle = 'retailer_admin'
  tilstand.stasjoner = []
  tilstand.dekning = []
  tilstand.planer = PRODUKSJONSFORM
})

describe('produksjonsformen: juli ferdig, seks maaneder med utkast bak', () => {
  it('KANARIFUGL: formen er den som ble maalt', () => {
    // Endres fikstyret, maaler ikke resten av fila produksjon lenger.
    expect(PRODUKSJONSFORM).toHaveLength(35)
    expect(PRODUKSJONSFORM.filter((p) => p.status === 'utkast')).toHaveLength(30)
    expect(PRODUKSJONSFORM.filter((p) => p.status === 'sluppet')).toHaveLength(5)
    expect(new Set(PRODUKSJONSFORM.map((p) => p.maaned)).size).toBe(7)
  })

  it('aapner paa juli, og sier at ingenting venter der', async () => {
    const t = tekst(await side())
    expect(t).toContain('Ingenting venter i juli 2026')
  })

  it('teller de tretti eldre utkastene, og de seks maanedene', async () => {
    const t = tekst(await side())
    expect(t).toContain('30 eldre utkast venter')
    expect(t).toContain('6 andre måneder')
  })

  it('ingen kort staar i koen, og de fem juliplanene staar som avgjort', async () => {
    const kort = plankort(await side())
    expect(kort).toHaveLength(5)
    expect(kort.every((k) => k.status === 'sluppet')).toBe(true)
    expect(kort.every((k) => k.maanedstekst === 'juli 2026')).toBe(true)
    expect(kort.map((k) => k.stasjon).sort()).toEqual([...STASJONER].sort())
  })

  it('velgeren faar alle sju maanedene', async () => {
    const t = tekst(await side())
    // `Maanedsvelger` faar dem som prop-array; `tekst` finner dem der.
    for (const m of ['2026-01-01', '2026-04-01', '2026-07-01']) expect(t).toContain(m)
  })

  // =================================================================
  // JUNI VALGT — DET ANDRE HALVE BILDET
  // =================================================================
  it('velger man juni, staar fem utkast og telleren snur', async () => {
    const tre = await side({ maned: '2026-06-01' })
    const kort = plankort(tre)
    expect(kort).toHaveLength(5)
    expect(kort.every((k) => k.status === 'utkast')).toBe(true)
    expect(kort.every((k) => k.maanedstekst === 'juni 2026')).toBe(true)

    const t = tekst(tre)
    expect(t).toContain('Køen viser juni 2026')
    expect(t).toContain('25 eldre utkast venter')
    expect(t).toContain('5 andre måneder')
    // Og da skal tomtilstanden IKKE staa - noe venter jo.
    expect(t).not.toContain('Ingenting venter i juni')
  })

  it('kortene i juni baerer maaneden sin, saa bekreftelsen kan navngi den', async () => {
    const kort = plankort(await side({ maned: '2026-06-01' }))
    // Uten denne propen faller `sporsmaal` tilbake til bare stasjonen -
    // og det var nettopp den formen som ikke stoppet feilslippet.
    expect(kort.every((k) => typeof k.maanedstekst === 'string' && k.maanedstekst !== '')).toBe(true)
  })

  // =================================================================
  // KANARIFUGL FOR TEKSTSAMLEREN
  // =================================================================
  it('KANARIFUGL: samleren finner tekst som ligger i props', async () => {
    // Leste den bare children, ville hver `toContain` over vaert en
    // paastand om en tom streng - og fila hadde vaert groenn uansett.
    const t = tekst(await side())
    expect(t.length).toBeGreaterThan(200)
    expect(t).toContain('Månedsplaner')
    expect(t).not.toContain('Ingenting venter i juni 2026')
  })

  it('en maaned uten planer velges ikke, og URL-en kan ikke tvinge den', async () => {
    // `lesMaaned` godtar enhver gyldig ISO-maaned. Ber noen om desember,
    // finnes ingen rader - og da skal koeen vaere tom uten aa kraesje.
    const tre = await side({ maned: '2026-12-01' })
    expect(plankort(tre)).toHaveLength(0)
    const t = tekst(tre)
    expect(t).toContain('Ingenting venter i desember 2026')
    expect(t).toContain('30 eldre utkast venter')
  })
})
