// EN FEILET SPØRRING ER IKKE EN TOM LISTE.
//
// =====================================================================
// TRE TILSTANDER SOM SÅ HELT LIKE UT
// =====================================================================
//
// Begge planflatene sto med `const rader = data ?? []`. Da falt tre
// forskjellige ting sammen til én visning:
//
//   • det finnes ingen plan          → «Ingen månedsplan ennå»
//   • spørringen feilet              → «Ingen månedsplan ennå»
//   • svaret traff taket, avkortet   → en kortere liste som ser hel ut
//
// Den midterste er den farligste: butikksjefen leser en rolig,
// riktig-utseende beskjed mens kolonnen mangler eller RLS avviste
// henne. Den siste er den stilleste: `.limit(60)` var nøyaktig fem
// stasjoner ganger tolv måneder, så en kjede i vekst ville mistet den
// eldste måneden uten at noe sa fra.
//
// ---------------------------------------------------------------------
// HVORFOR DENNE TESTEN SER PÅ ELEMENTTREET OG IKKE PÅ HTML
//
// Sidene er server-komponenter — async funksjoner som returnerer JSX.
// De kan kalles direkte. Å rendre dem ville dratt inn `Sideramme` og
// `next/navigation`, og da hadde testen målt rammeverket i stedet for
// beslutningen. Her sammenlignes elementets `type` med komponenten
// selv: `Feiltilstand` eller `Tomtilstand`, ikke en tekst som kan
// omformuleres.
// =====================================================================

import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ReactElement } from 'react'
import { Feiltilstand, Tomtilstand } from '@/components/ui/side'

// Tilstanden testene skrur på. Må ligge utenfor `vi.mock`, som heises.
const tilstand = {
  rolle: 'butikksjef' as string,
  svar: { data: null as unknown, error: null as unknown },
}

vi.mock('@/lib/auth/dal', () => ({
  hentInnloggetBruker: async () => ({ rolle: tilstand.rolle }),
}))

vi.mock('@/lib/supabase/server', () => ({
  lagSupabaseServerKlient: async () => ({ from: () => bygger() }),
}))

/**
 * En PostgREST-builder som svarer det testen har satt.
 *
 * Hvert ledd returnerer seg selv, og objektet er `thenable` — det er
 * slik den ekte builderen oppfører seg når den ventes på.
 */
function bygger() {
  const b: Record<string, unknown> = {}
  for (const ledd of ['select', 'in', 'eq', 'order', 'limit', 'overrideTypes']) {
    b[ledd] = () => b
  }
  b.then = (ok: (v: unknown) => void) => ok(tilstand.svar)
  return b
}

/** Første element i treet med denne typen. `null` om den ikke finnes. */
function finn(node: unknown, type: unknown): ReactElement | null {
  if (node === null || node === undefined || typeof node !== 'object') return null
  if (Array.isArray(node)) {
    for (const n of node) {
      const t = finn(n, type)
      if (t) return t
    }
    return null
  }
  const el = node as ReactElement & { props?: { children?: unknown } }
  if (el.type === type) return el
  return finn(el.props?.children, type)
}

/** All tekst i treet, flatet ut — for påstander om hva som STÅR der. */
function tekst(node: unknown): string {
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  if (node === null || node === undefined || typeof node !== 'object') return ''
  if (Array.isArray(node)) return node.map(tekst).join(' ')
  const props = (node as { props?: Record<string, unknown> }).props ?? {}
  return Object.values(props).map(tekst).join(' ')
}

const plan = (i: number) => ({
  id: `p${i}`,
  maaned: '2026-05-01',
  dom: 'motvind',
  ingress: 'Resultatet i mai …',
  punkter: [],
  merknad: null,
  status: 'sluppet',
  matkast: null,
  usynlig: null,
  rangering: null,
  stasjoner: { navn: `Stasjon ${i}` },
})

async function side() {
  const modul = await import('./page')
  return (await modul.default()) as ReactElement
}

beforeEach(() => {
  tilstand.rolle = 'butikksjef'
  tilstand.svar = { data: null, error: null }
})

// =====================================================================
describe('databasefeil', () => {
  it('gir feiltilstand, ikke tomtilstand', async () => {
    tilstand.svar = { data: null, error: { message: 'column "rangering" does not exist' } }
    const el = await side()

    expect(finn(el, Feiltilstand), 'feiltilstanden mangler').not.toBeNull()
    expect(finn(el, Tomtilstand), 'tomtilstanden ble vist ved en FEIL').toBeNull()
  })

  it('sier hva som gikk galt, og hva det IKKE betyr', async () => {
    tilstand.svar = { data: null, error: { message: 'permission denied' } }
    const t = tekst(await side())

    // Årsaken svelges ikke.
    expect(t).toContain('permission denied')
    // Og den som leser får vite at dette ikke er en tom plan.
    expect(t).toContain('ikke det samme som at du ikke har en plan')
    expect(t).not.toContain('Ingen månedsplan ennå')
  })
})

// =====================================================================
describe('null rader', () => {
  it('er en EKTE tomtilstand', async () => {
    tilstand.svar = { data: [], error: null }
    const el = await side()

    expect(finn(el, Tomtilstand)).not.toBeNull()
    expect(finn(el, Feiltilstand)).toBeNull()
    expect(tekst(el)).toContain('Ingen månedsplan ennå')
  })
})

// =====================================================================
describe('svaret treffer taket', () => {
  // 240 rader ut av en `.limit(240)`. Det er ikke bevist avkortet — det
  // er UBEVIST helt, og det er nøyaktig like ille. En liste som mangler
  // sin eldste måned ser ut som en kortere historikk.
  it('presenteres IKKE som komplett', async () => {
    tilstand.svar = { data: Array.from({ length: 240 }, (_, i) => plan(i)), error: null }
    const el = await side()

    expect(finn(el, Feiltilstand), 'et mulig avkortet svar ble tegnet som en liste')
      .not.toBeNull()
    expect(tekst(el)).toContain('taket')
  })

  it('KANARIFUGL: én rad under taket er et helt svar', async () => {
    // Uten denne ville testen over bestått i en side som alltid feiler.
    tilstand.svar = { data: Array.from({ length: 239 }, (_, i) => plan(i)), error: null }
    const el = await side()

    expect(finn(el, Feiltilstand)).toBeNull()
    expect(finn(el, Tomtilstand)).toBeNull()
    expect(tekst(el)).toContain('Stasjon 0')
  })
})

// =====================================================================
describe('porten', () => {
  it('avviser andre roller', async () => {
    tilstand.rolle = 'butikkbruker_tablet'
    expect(tekst(await side())).toContain('Du har ikke tilgang')
  })

  it('slipper inn eieren, som skal kunne se det butikksjefen ser', async () => {
    tilstand.rolle = 'retailer_admin'
    tilstand.svar = { data: [plan(1)], error: null }
    expect(tekst(await side())).toContain('Stasjon 1')
  })
})
