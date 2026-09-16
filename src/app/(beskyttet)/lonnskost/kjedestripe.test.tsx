import { describe, expect, it } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { Kjedestripe } from './kjedestripe'
import { kjedesum, sorterKjede, type Kjede, type Kjederad } from '@/lib/lonnskost/a1-kjede'
import type { A1Kort } from '@/lib/lonnskost/a1-kort'

const beregnet = (kroner: number, o: Partial<A1Kort> = {}): A1Kort => ({
  status: 'komplett', maaned: '2026-08', kroner,
  betalteTimer: 698.77, prisedeTimer: 698.77, forklarteTimer: 0, upriseteTimer: 0,
  andelPriset: 100, uprisetePersoner: [], innlaantKr: 0, innlaanteNr: [],
  dataavvik: { dubletter: 0, avvisteVakter: 0 }, helligdagstimer: 0, forbehold: [],
  ...o,
} as A1Kort)

const minimum = (kroner: number, upriseteTimer = 68): A1Kort =>
  beregnet(kroner, { status: 'minimum', upriseteTimer, prisedeTimer: 630.77 })

const mangel = (
  mangler: 'register' | 'arbeidstid' | 'begge', o: Partial<A1Kort> = {},
): A1Kort => ({ status: 'kildemangel', maaned: '2026-08', mangler, ...o } as A1Kort)

const rad = (butikknummer: string, navn: string, kort: A1Kort): Kjederad =>
  ({ id: `id-${butikknummer}`, butikknummer, navn, kort })

const lagKjede = (rader: Kjederad[], maaned: string | null = '2026-08'): Kjede => {
  const sortert = sorterKjede(rader)
  return {
    maaned,
    rader: sortert,
    sum: kjedesum(sortert),
    maaling: { stasjoner: rader.length, rundturer: 0, motorMs: 0, totaltMs: 0 },
  }
}

// `Intl` skiller tusener med HARDT mellomrom (U+00A0), og taggene
// byttes mot U+0001 foer de blir til « | ». BEGGE staar som escape
// med vilje: et literalt usynlig tegn i kilden er umulig aa se, og en
// regex ingen kan lese er en regex ingen kan vedlikeholde.
/** Markup til lesbar tekst. */
const marker = (k: Kjede) =>
  renderToStaticMarkup(<Kjedestripe kjede={k} />).replace(/\u00a0/g, ' ')

const tekstFra = (k: Kjede) =>
  marker(k).replace(/<[^>]+>/g, '\u0001').replace(/\u0001+/g, ' | ').trim()

/** Bønes august 2026, slik produksjonen faktisk er etter Stig-rettingen. */
const PRODUKSJON = (): Kjederad[] => [
  rad('9467', 'Bønes', beregnet(143889.14, { forklarteTimer: 68, prisedeTimer: 630.77 })),
  // 77 430 uslaatte minutter = 1 290,5 t. Maalt i produksjon 2026-09-16;
  // skissen min i preflighten sa 129,1 og var feil med faktor 10.
  rad('9038', 'Laguneparken', mangel('register', { timer: 1290.5, personer: 15 })),
  rad('4177', 'Lone', mangel('arbeidstid')),
  rad('9145', 'Varden', mangel('begge')),
  rad('4185', 'Dale', mangel('begge')),
]

describe('dagens produksjonsbilde', () => {
  it('sier hva kjeden faktisk kan si om august', () => {
    const t = tekstFra(lagKjede(PRODUKSJON()))
    expect(t).toContain('Arbeidet på stasjonene — konto 503 · august 2026')
    expect(t).toContain('For 1 av 5 stasjoner: beregnet 143 889 kr')
    expect(t).toContain('4 stasjoner mangler grunnlag for august 2026.')
  })

  it('rekkefølgen er handlingsbehov først, butikknummer innen gruppa', () => {
    const k = lagKjede(PRODUKSJON())
    expect(k.rader.map((r) => r.navn))
      // Butikknummer: 4177 Lone, 4185 Dale, 9038 Laguneparken, 9145 Varden.
      // Alle fire mangler kilder og staar derfor i gruppe 1, sortert paa
      // nummer. Boenes er ferdig og staar sist - forklarte timer flytter
      // den ikke opp.
      .toEqual(['Lone', 'Dale', 'Laguneparken', 'Varden', 'Bønes'])
  })

  it('Bønes viser forklarte timer diskret, uten å bli et handlingsbehov', () => {
    const t = tekstFra(lagKjede(PRODUKSJON()))
    expect(t).toContain('Beregnet 143 889 kr')
    expect(t).toContain('68,0 t forklart')
    expect(t).not.toContain('68,0 timer mangler satsgrunnlag')
  })

  it('Laguneparken sier hvor mye arbeid som står uten grunnlag', () => {
    const t = tekstFra(lagKjede(PRODUKSJON()))
    expect(t).toContain('Lønnsgrunnlaget fra easy@work mangler')
    expect(t).toContain('15 personer, 1 290,5 t')
  })
})

describe('negative vakter', () => {
  it('2 · en manglende stasjon vises ALDRI som 0 kr', () => {
    const t = tekstFra(lagKjede(PRODUKSJON()))
    expect(t).not.toMatch(/\b0 kr\b/)
  })

  it('5 · ordet «total lønnskost» forekommer ikke', () => {
    expect(marker(lagKjede(PRODUKSJON())).toLowerCase()).not.toContain('total lønnskost')
  })

  it('6 · ingen intern enum lekker', () => {
    const m = marker(lagKjede([
      ...PRODUKSJON(), rad('1000', 'X', minimum(97000)),
    ]))
    for (const v of [
      'komplett', 'minimum', 'kildemangel', 'hele_kjeden', 'delvis',
      'ingen_grunnlag', 'Vurdertrad', 'Uprisetgrunn', 'ukjent_nummer',
      'fastlonn_uten_register', 'a1_registeroppslag', 'mangler_register',
    ]) expect(m.toLowerCase(), v).not.toContain(v.toLowerCase())
  })

  it('9 · ingen fastlønnslogikk — ordet forekommer ikke i stripa', () => {
    expect(marker(lagKjede(PRODUKSJON())).toLowerCase()).not.toContain('fastlønn')
  })

  it('11 · stasjoner uten kilder vises, aldri utelatt', () => {
    const k = lagKjede(PRODUKSJON())
    const t = tekstFra(k)
    expect(k.rader).toHaveLength(5)
    for (const navn of ['Dale', 'Varden', 'Lone', 'Laguneparken', 'Bønes']) {
      expect(t, navn).toContain(navn)
    }
  })

  it('12 · aldri sortert etter kroner', () => {
    const k = lagKjede([
      rad('4177', 'Liten', beregnet(10)),
      rad('9467', 'Stor', beregnet(999999)),
    ])
    expect(k.rader.map((r) => r.navn)).toEqual(['Liten', 'Stor'])
  })

  it('13 · forklarte timer gir ingen Status-markering', () => {
    const bare = lagKjede([
      rad('9467', 'Bønes', beregnet(143889.14, { forklarteTimer: 68 })),
    ])
    // `Status` rendres med en egen klasse. Forklart arbeid skal ikke ha en.
    const m = marker(bare)
    expect(m).toContain('68,0 t forklart')
    expect(m).not.toMatch(/class="[^"]*status[^"]*"/i)
  })

  it('ingen drilldownlenke når alt er ordinært priset', () => {
    const m = marker(lagKjede([rad('9467', 'Bønes', beregnet(143889.14))]))
    expect(m).not.toContain('/lonnskost/arbeidssted')
  })

  it('drilldownlenka bærer stasjon og den FELLES måneden', () => {
    const m = marker(lagKjede(PRODUKSJON()))
    expect(m).toContain('/lonnskost/arbeidssted?stasjon=id-9467&amp;maned=2026-08')
  })

  it('stasjonsraden lenker tilbake til B2e.1 uten å røre måneden', () => {
    const m = marker(lagKjede(PRODUKSJON()))
    expect(m).toContain('/lonnskost?stasjon=id-9467')
    expect(m).not.toContain('stasjon=alle')
  })

  it('manglende stasjon peker på importflaten', () => {
    expect(marker(lagKjede(PRODUKSJON()))).toContain('/import')
  })
})

describe('de fem kjedetilstandene i faktisk markup', () => {
  it('hele_kjeden / beregnet', () => {
    const t = tekstFra(lagKjede([
      rad('1', 'A', beregnet(100000)), rad('2', 'B', beregnet(141000)),
    ]))
    expect(t).toContain('Beregnet 241 000 kr for 2 stasjoner')
  })

  it('hele_kjeden / minst', () => {
    const t = tekstFra(lagKjede([
      rad('1', 'A', beregnet(100000)), rad('2', 'B', minimum(141000)),
    ]))
    expect(t).toContain('Minst 241 000 kr for 2 stasjoner')
  })

  it('delvis / beregnet', () => {
    const t = tekstFra(lagKjede([
      rad('1', 'A', beregnet(100000)), rad('2', 'B', mangel('begge')),
    ]))
    expect(t).toContain('For 1 av 2 stasjoner: beregnet 100 000 kr')
  })

  it('delvis / minst', () => {
    const t = tekstFra(lagKjede([
      rad('1', 'A', minimum(100000)), rad('2', 'B', mangel('begge')),
    ]))
    expect(t).toContain('For 1 av 2 stasjoner: minst 100 000 kr')
    expect(t).toContain('kunne ikke prises')
  })

  it('ingen_grunnlag — ingen kroner i det hele tatt', () => {
    const t = tekstFra(lagKjede([
      rad('1', 'A', mangel('begge')), rad('2', 'B', mangel('register')),
    ]))
    expect(t).toContain('Ingen beregnet konto 503 for august 2026')
    expect(t).toContain('2 stasjoner mangler grunnlag.')
    expect(t).not.toMatch(/\d+ kr/)
  })
})

describe('tom stripe', () => {
  it('rendrer ingenting når ingen stasjon har en eneste kilde', () => {
    expect(marker(lagKjede([], null))).toBe('')
  })
})
