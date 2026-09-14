// SERVEREN AVGJOER MAANEDEN. FELTET KAN BARE GI ET NEI.
//
// =====================================================================
// HVORFOR DENNE FINNES, OG HVA DEN ERSTATTER
// =====================================================================
//
// `e2e/maanedsplan.spec.ts` steg D beviste dette ved aa sette verdien
// paa et React-kontrollert `<input type="hidden" value={maaned}>` fra
// nettleseren og saa klikke. Det er et KAPPLOEP, ikke en kontrakt: React
// skriver verdien tilbake ved neste commit, og 2026-09-14 tapte testen
// det kapploepet - handlingen kjoerte med juli, lyktes, og testen felte
// paa at feilmeldingen uteble.
//
// Den saa da ut som «avvisningen virker ikke». Den virkelige beskjeden
// var «feltet ble nullstilt foer innsendingen», og det er noe helt
// annet.
//
// Avvisningen maales derfor DIREKTE her: konstruert `FormData`, ingen
// nettleser, ingen React. Da kan den ikke tape et kappleop, og den kan
// ikke feile av feil grunn.
//
// Nettlesertesten beholdes som TILLEGGSKONTROLL, med bevis paa at
// POST-kroppen faktisk bar 2026-05-01. Den er ikke lenger eneste bevis.
// =====================================================================

import { beforeEach, describe, expect, it, vi } from 'vitest'

const tilstand = {
  rolle: 'retailer_admin' as string,
  retailerId: 'r1' as string | null,
  stasjoner: [{ id: 's1' }, { id: 's2' }] as { id: string }[],
  dekning: [] as { maaned: string; stasjon_id: string; linjer_lest: number | null }[],
}

vi.mock('@/lib/auth/dal', () => ({
  hentInnloggetBruker: async () => ({
    rolle: tilstand.rolle, retailerId: tilstand.retailerId, id: 'u1',
  }),
}))

vi.mock('@/lib/supabase/server', () => ({
  lagSupabaseServerKlient: async () => ({
    from(tabell: string) {
      const b: Record<string, unknown> = {}
      for (const ledd of ['select', 'eq', 'in', 'is', 'lte', 'order', 'limit', 'overrideTypes']) {
        b[ledd] = () => b
      }
      b.then = (ok: (v: unknown) => void) => ok({
        data: tabell === 'stasjoner' ? tilstand.stasjoner : tilstand.dekning,
        error: null,
      })
      return b
    },
  }),
}))

const { byggPlanerPaaNytt } = await import('./handlinger')

/** Alle stasjonene har lest regnskap for maaneden. */
const dekning = (maaned: string) =>
  tilstand.stasjoner.map(({ id }) => ({ maaned, stasjon_id: id, linjer_lest: 2 }))

const fd = (maaned: string) => {
  const f = new FormData()
  f.set('maaned', maaned)
  return f
}

beforeEach(() => {
  tilstand.rolle = 'retailer_admin'
  tilstand.retailerId = 'r1'
  tilstand.stasjoner = [{ id: 's1' }, { id: 's2' }]
  // Nyeste KOMPLETTE datamaaned er juli.
  tilstand.dekning = dekning('2026-07-01')
})

describe('feltet kan bare gi et nei', () => {
  it('2026-05-01 avvises naar serveren finner juli', async () => {
    const svar = await byggPlanerPaaNytt(undefined, fd('2026-05-01'))

    expect(svar?.ok, 'en avvist maaned skal ikke gi kvittering').toBeUndefined()
    expect(svar?.feil).toMatch(/Last sida på nytt/)
    // Begge maanedene skal staa i beskjeden: den som ble bedt om, og den
    // som faktisk gjelder. Uten begge vet ikke den som leser hva som er
    // galt.
    expect(svar?.feil).toContain('2026-05')
    expect(svar?.feil).toContain('2026-07')
  })

  it('KANARIFUGL: juli avvises IKKE av samme port', async () => {
    // Uten denne ville testen over bestaatt ogsaa hvis handlingen avviste
    // ALT - og da maaler den ingenting om maaneden.
    const svar = await byggPlanerPaaNytt(undefined, fd('2026-07-01'))
    expect(svar?.feil ?? '').not.toMatch(/Last sida på nytt/)
  })

  it('en ugyldig maanedsverdi stoppes foer oppslaget', async () => {
    expect((await byggPlanerPaaNytt(undefined, fd('2026-05-17')))?.feil)
      .toMatch(/Ugyldig måned/)
    expect((await byggPlanerPaaNytt(undefined, fd('tull')))?.feil)
      .toMatch(/Ugyldig måned/)
  })

  it('rollen er porten foer maaneden i det hele tatt leses', async () => {
    tilstand.rolle = 'butikksjef'
    const svar = await byggPlanerPaaNytt(undefined, fd('2026-05-01'))
    expect(svar?.feil).toMatch(/Bare eier/)
  })
})
