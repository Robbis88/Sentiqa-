// EN KNAPP SOM IKKE VET HVILKEN MÅNED DEN GJELDER, SKAL IKKE STÅ DER.
//
// =====================================================================
// DE TO TILSTANDENE
// =====================================================================
//
//   A  komplett datamåned  → knappen finnes, og navngir måneden
//   B  ingen komplett      → knappen finnes IKKE
//
// Tilstand A måles i nettleseren (`e2e/maanedsplan.spec.ts`), der hele
// kjeden kjøres: knappen → bekreftelse → serverhandling → utkast →
// snapshot.
//
// Tilstand B måles HER og ikke i nettleseren, og det er verdt å skrive
// hvorfor: Playwright-økta er eierens, og eieren står i den ENE kjeden
// som har regnskapsdata. Å lage en kjede uten data med en egen eier
// ville krevd en ny `auth.users`, egen TOTP-innrullering og en fjerde
// øktfil — altså mer testinfrastruktur enn selve påstanden er verdt.
//
// Server-komponenten er en async funksjon som returnerer JSX. Den kan
// kalles direkte, og her sammenlignes elementets `type` med komponenten
// selv — ikke med en tekst som kan omformuleres.
// =====================================================================

import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ReactElement } from 'react'
import { Byggknapp } from './byggknapp'

const tilstand = {
  rolle: 'retailer_admin' as string,
  /** Radene `nyesteKompletteMaaned` og sida leser. */
  stasjoner: [{ id: 's1' }, { id: 's2' }, { id: 's3' }] as { id: string }[],
  dekning: [] as { maaned: string; stasjon_id: string; linjer_lest: number | null }[],
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

function finn(node: unknown, type: unknown): ReactElement | null {
  if (node === null || node === undefined || typeof node !== 'object') return null
  if (Array.isArray(node)) {
    for (const n of node) { const t = finn(n, type); if (t) return t }
    return null
  }
  const el = node as ReactElement & { props?: { children?: unknown } }
  if (el.type === type) return el
  return finn(el.props?.children, type)
}

const dekning = (maaned: string, stasjoner: string[]) =>
  stasjoner.map((stasjon_id) => ({ maaned, stasjon_id, linjer_lest: 2 }))

async function side() {
  const modul = await import('./page')
  return (await modul.default()) as ReactElement
}

beforeEach(() => {
  tilstand.rolle = 'retailer_admin'
  tilstand.stasjoner = [{ id: 's1' }, { id: 's2' }, { id: 's3' }]
  tilstand.dekning = []
  tilstand.planer = []
})

// =====================================================================
describe('A  komplett datamåned', () => {
  it('knappen finnes, og navngir måneden fra DATAGRUNNLAGET', async () => {
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
    const k = finn(await side(), Byggknapp)
    expect(k).not.toBeNull()
    expect(k!.props).toMatchObject({ maaned: '2026-07-01', forventet: 3 })
  })

  it('velger den NYESTE komplette, ikke den nyeste som finnes', async () => {
    tilstand.dekning = [
      ...dekning('2026-06-01', ['s1', 's2', 's3']),
      // Juli finnes i data, men mangler én stasjon.
      ...dekning('2026-07-01', ['s1', 's2']),
    ]
    const k = finn(await side(), Byggknapp)
    expect(k!.props).toMatchObject({ maaned: '2026-06-01' })
  })

  it('teller planer og forventning HVER FOR SEG', async () => {
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
    tilstand.planer = [{
      id: 'p1', maaned: '2026-07-01', dom: 'flat', ingress: 'x',
      punkter: [], merknad: null, status: 'utkast',
      matkast: null, usynlig: null, rangering: null, stasjoner: { navn: 'A' },
    }]
    const k = finn(await side(), Byggknapp)
    // Tre forventede, én plan. Er de like, skjules det at noe mangler.
    expect(k!.props).toMatchObject({ forventet: 3, eksisterende: 1 })
  })
})

// =====================================================================
describe('B  ingen komplett datamåned', () => {
  const ingenKnapp = async (navn: string) => {
    const k = finn(await side(), Byggknapp)
    expect(k, `knappen sto der uten ${navn}`).toBeNull()
  }

  it('ingen regnskapsdata i det hele tatt', async () => {
    tilstand.dekning = []
    await ingenKnapp('datadekning')
  })

  it('én stasjon mangler måneden', async () => {
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2'])
    await ingenKnapp('full dekning')
  })

  it('linjer_lest er 0 — raden finnes, men ingenting er lest', async () => {
    // ET BELØP ER IKKE EN DATASTATUS, og en rad er ikke dekning.
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
      .map((r) => ({ ...r, linjer_lest: 0 }))
    await ingenKnapp('leste linjer')
  })

  it('linjer_lest er null', async () => {
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
      .map((r) => ({ ...r, linjer_lest: null }))
    await ingenKnapp('leste linjer')
  })

  it('kjeden har ingen aktive stasjoner', async () => {
    tilstand.stasjoner = []
    tilstand.dekning = []
    await ingenKnapp('aktive stasjoner')
  })
})

// =====================================================================
describe('KANARIFUGL', () => {
  it('finn() ville sett knappen hvis den sto der', async () => {
    // Uten denne består hele blokk B i en test som ikke kan finne
    // komponenten i det hele tatt.
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
    expect(finn(await side(), Byggknapp)).not.toBeNull()
  })

  it('og butikksjefen kommer ikke inn på sida overhodet', async () => {
    tilstand.rolle = 'butikksjef'
    tilstand.dekning = dekning('2026-07-01', ['s1', 's2', 's3'])
    expect(finn(await side(), Byggknapp)).toBeNull()
  })
})
