import { describe, expect, it, vi } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { Fastlonnskandidater, kandidater } from './fastlonnskandidater'
import type { A1Kort } from '@/lib/lonnskost/a1-kort'

// MILJØ SETTES HER, IKKE I vitest.config.ts — den sier det selv:
// «miljo per fil settes i testfila der det trengs, saa oppsettet ikke
// blir et sted feil kan gjemme seg.»
//
// `vi.hoisted` kjører FØR importene over. Uten den rekkefølgen har
// `src/lib/env.ts` allerede kastet når `LonnsformVelger` drar inn
// serverhandlingen.
//
// VI MOCKER IKKE HANDLINGEN. Poenget med denne flaten er at den bruker
// den SAMME `settLonnsform` som `/lonn` og Lønnsform-blokka — én rad
// nådd fra tre steder, ikke tre sannheter. En mock ville vært grønn
// også om noen byttet den ut med en egen kopi.
vi.hoisted(() => {
  process.env.NEXT_PUBLIC_SUPABASE_URL ??= 'https://testet-skjer-aldri-nettverk.invalid'
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??= 'anon-attrapp-for-testen'
})

// KUN RAMMEVERKSGRENSA. `useKvittering` kaller `useRouter()`, som krever
// en ruterkontekst Next bare gir i en ekte forespørsel. Dette er en
// attrapp for NAVIGASJON, ikke for forretningslogikken: handlingen,
// velgeren og skjemafeltene er fortsatt de ekte.
vi.mock('next/navigation', () => ({
  useRouter: () => ({ refresh: () => {}, push: () => {}, replace: () => {} }),
  usePathname: () => '/lonnskost',
  useSearchParams: () => new URLSearchParams(),
}))

const BONES = 'sss-bones'

// `Extract<A1Kort, { status: 'minimum' }>` gir `never`: varianten baerer
// `status: 'minimum' | 'komplett'`, ikke 'minimum' alene. Vi plukker den
// derfor paa et felt bare den har.
type Beregnet = Extract<A1Kort, { kroner: number }>

const kort = (o: Partial<Beregnet> = {}): A1Kort => ({
  status: 'minimum', maaned: '2026-08', kroner: 143889.14,
  betalteTimer: 698.77, prisedeTimer: 630.77, forklarteTimer: 0, upriseteTimer: 68,
  andelPriset: 90.3,
  uprisetePersoner: [
    { ansattNr: '1004', navn: 'Stig E.E Litlehamar', timer: 68, grunn: 'ukjent_nummer' },
  ],
  innlaantKr: 4758.33, innlaanteNr: ['1104265', '1104270'],
  dataavvik: { dubletter: 0, avvisteVakter: 0 },
  helligdagstimer: 0, forbehold: ['Overtid er ikke med.'],
  ...o,
})

const marker = (k: A1Kort[]) =>
  renderToStaticMarkup(<Fastlonnskandidater kort={k} stasjonId={BONES} />)
    .replace(/ /g, ' ')

describe('kandidatlista er motorens uslaatteNumre, ikke en SQL ved siden av', () => {
  it('Bønes august gir NØYAKTIG 1004', () => {
    expect(kandidater([kort()])).toEqual([
      { ansattNr: '1004', navn: 'Stig E.E Litlehamar', timer: 68, maaneder: ['2026-08'] },
    ])
  })

  it('INNLÅNTE tilbys aldri — Carmen og Julian er priset, ikke uslåtte', () => {
    // De staar i `innlaanteNr`, men aldri i `uprisetePersoner`. Ville
    // kandidatlista vaert bygget av «mangler i eget register», hadde de
    // kommet med - og en fastlonnsmerking ville skjult ekte loennskost.
    const liste = kandidater([kort()])
    expect(liste.map((k) => k.ansattNr)).not.toContain('1104265')
    expect(liste.map((k) => k.ansattNr)).not.toContain('1104270')
    const html = marker([kort()])
    expect(html).not.toContain('1104265')
    expect(html).not.toContain('1104270')
  })

  it('MOTSTRID tilbys aldri — en avtale skal ikke kjøpe fri et navneveto', () => {
    const k = kort({
      uprisetePersoner: [
        { ansattNr: '1018', navn: 'Andre Fjørstad', timer: 8, grunn: 'motstrid_navn' },
        { ansattNr: '1004', navn: 'Stig E.E Litlehamar', timer: 68, grunn: 'ukjent_nummer' },
      ],
    })
    expect(kandidater([k]).map((x) => x.ansattNr)).toEqual(['1004'])
  })

  it('de øvrige upriset-grunnene tilbys heller ikke', () => {
    for (const grunn of ['avvist_rad', 'dublett', 'flere_lokasjoner',
      'motstrid_kollisjon', 'motstrid_bro'] as const) {
      const k = kort({
        uprisetePersoner: [{ ansattNr: '7777', navn: 'X', timer: 4, grunn }],
      })
      expect(kandidater([k]), grunn).toEqual([])
    }
  })

  it('samme person over flere måneder blir ÉN rad med timene summert', () => {
    const juli = kort({ maaned: '2026-07' })
    expect(kandidater([kort(), juli])).toEqual([
      {
        ansattNr: '1004', navn: 'Stig E.E Litlehamar', timer: 136,
        maaneder: ['2026-08', '2026-07'],
      },
    ])
  })

  it('kildemangel bidrar med ingenting', () => {
    expect(kandidater([
      { status: 'kildemangel', maaned: '2026-08', mangler: 'register', timer: 698.8, personer: 13 },
    ])).toEqual([])
  })

  it('flest timer først', () => {
    const k = kort({
      uprisetePersoner: [
        { ansattNr: 'A', navn: 'Liten', timer: 4, grunn: 'ukjent_nummer' },
        { ansattNr: 'B', navn: 'Stor', timer: 40, grunn: 'ukjent_nummer' },
      ],
    })
    expect(kandidater([k]).map((x) => x.ansattNr)).toEqual(['B', 'A'])
  })
})

describe('flaten', () => {
  it('rendrer ingenting når det ikke finnes kandidater', () => {
    expect(marker([kort({ uprisetePersoner: [] })])).toBe('')
  })

  it('viser nummer, navn, måned og timer', () => {
    const html = marker([kort()])
    expect(html).toContain('1004 · Stig E.E Litlehamar')
    expect(html).toContain('2026-08')
    expect(html).toContain('68,0')
  })

  it('skjemaet bærer stasjon, nummer og navn til den DELTE handlingen', () => {
    const html = marker([kort()])
    expect(html).toContain('name="stasjon_id" value="sss-bones"')
    expect(html).toContain('name="ansatt_nr" value="1004"')
    expect(html).toContain('name="navn" value="Stig E.E Litlehamar"')
  })

  it('velgeren starter UAVKLART — ingen forhåndsvalgt fastlønn', () => {
    const html = marker([kort()])
    // `defaultValue=""` gir ingen `selected` paa fastlonn-alternativet.
    expect(html).not.toMatch(/<option[^>]*value="fastlonn"[^>]*selected/)
  })

  it('sier eksplisitt at uavklart IKKE er fastlønn', () => {
    expect(marker([kort()])).toContain('uavklart er ikke det samme som fastlønn')
  })

  it('ingen intern enum lekker til skjermen', () => {
    const html = marker([kort()])
    for (const v of ['ukjent_nummer', 'uslaatteNumre', 'fastlonn_uten_register',
      'Uprisetgrunn', 'a1_registeroppslag']) {
      expect(html, v).not.toContain(v)
    }
  })
})
