import { describe, expect, it } from 'vitest'
import {
  gruppeFor, kjedesum, kjedesumtekst, sorterKjede, velgKjedeMaaned,
  type Kjederad, type Kjedesum,
} from './a1-kjede'
import type { A1Kort } from './a1-kort'

// =====================================================================
// KJEDEKONTRAKTEN — MÅNED, DEKNING OG SIKKERHET ER TRE SANNHETER
// =====================================================================

const beregnet = (kroner: number, o: Partial<A1Kort> = {}): A1Kort => ({
  status: 'komplett', maaned: '2026-08', kroner,
  betalteTimer: 698.77, prisedeTimer: 698.77, forklarteTimer: 0, upriseteTimer: 0,
  andelPriset: 100, uprisetePersoner: [], innlaantKr: 0, innlaanteNr: [],
  dataavvik: { dubletter: 0, avvisteVakter: 0 }, helligdagstimer: 0, forbehold: [],
  ...o,
} as A1Kort)

const minimum = (kroner: number, upriseteTimer = 68): A1Kort =>
  beregnet(kroner, { status: 'minimum', upriseteTimer, prisedeTimer: 630.77 })

const mangel = (mangler: 'register' | 'arbeidstid' | 'begge' = 'begge'): A1Kort =>
  ({ status: 'kildemangel', maaned: '2026-08', mangler })

const rad = (butikknummer: string, navn: string, kort: A1Kort): Kjederad =>
  ({ id: `id-${butikknummer}`, butikknummer, navn, kort })

// Hardt mellomrom fra Intl gjoeres om, slik B2e.1-testene gjoer det.
const tekst = (s: Kjedesum, m = '2026-08') => {
  const t = kjedesumtekst(s, m)
  return { hoved: t.hoved.replace(/ /g, ' '), tillegg: t.tillegg?.replace(/ /g, ' ') ?? null }
}

// =====================================================================
// MÅNEDSKONTRAKTEN — ALGORITME A
// =====================================================================

describe('månedsvalget er A, og A kan ikke skjule den nyeste måneden', () => {
  it('seneste måned minst ÉN stasjon har', () => {
    expect(velgKjedeMaaned([['2026-08'], ['2026-07'], []])).toBe('2026-08')
  })

  it('DEN LÅSTE FORSKJELLEN: august 5/5, september 1/5 → september', () => {
    // A, B og C gir alle 2026-08 i dagens produksjonsdata, saa dataene
    // skiller dem ikke. DETTE datasettet gjoer det:
    //
    //   B («flest med kilde»)  -> august   (5 mot 1)
    //   C («flest med begge»)  -> august
    //   A («seneste noen har») -> september
    //
    // Velger vi august, ser ikke eieren at september har begynt aa komme
    // inn. Manglende dekning skal eksponeres av stripa, ikke skjules av
    // maanedsvalget.
    const august5 = ['2026-08']
    expect(velgKjedeMaaned([
      [...august5, '2026-09'], august5, august5, august5, august5,
    ])).toBe('2026-09')
  })

  it('tom når ingen stasjon har en eneste kilde', () => {
    expect(velgKjedeMaaned([[], [], []])).toBeNull()
  })

  it('ugyldig månedsform slipper ikke gjennom', () => {
    expect(velgKjedeMaaned([['2026-13', 'august', '2026-08']])).toBe('2026-08')
  })
})

// =====================================================================
// DE FEM SPRÅKKOMBINASJONENE
// =====================================================================

describe('økonomisk språk — fem kombinasjoner, fem setninger', () => {
  it('hele_kjeden / beregnet', () => {
    const t = tekst({ slag: 'hele_kjeden', sikkerhet: 'beregnet', kroner: 241000, stasjoner: 5 })
    expect(t.hoved).toBe('Beregnet 241 000 kr for 5 stasjoner')
    expect(t.tillegg).toBeNull()
  })

  it('hele_kjeden / minst', () => {
    const t = tekst({ slag: 'hele_kjeden', sikkerhet: 'minst', kroner: 241000, stasjoner: 5 })
    expect(t.hoved).toBe('Minst 241 000 kr for 5 stasjoner')
    expect(t.tillegg).toContain('kunne ikke prises')
  })

  it('delvis / beregnet — dekningen står FØRST i setningen', () => {
    const t = tekst({
      slag: 'delvis', sikkerhet: 'beregnet', kroner: 143889.14,
      dekkede: 1, totalt: 5, utenGrunnlag: ['9038 Laguneparken'],
    })
    expect(t.hoved).toBe('For 1 av 5 stasjoner: beregnet 143 889 kr')
    expect(t.tillegg).toBe('4 stasjoner mangler grunnlag for august 2026.')
  })

  it('delvis / minst — sier BÅDE at noen mangler og at noe ikke kunne prises', () => {
    const t = tekst({
      slag: 'delvis', sikkerhet: 'minst', kroner: 143889.14,
      dekkede: 3, totalt: 5, utenGrunnlag: ['9038 Laguneparken', '4185 Dale'],
    })
    expect(t.hoved).toBe('For 3 av 5 stasjoner: minst 143 889 kr')
    expect(t.tillegg).toBe(
      '2 stasjoner mangler grunnlag for august 2026.'
      + ' Noe arbeid på de dekkede stasjonene kunne ikke prises.',
    )
  })

  it('ingen_grunnlag — ingen kroner i teksten i det hele tatt', () => {
    const t = tekst({ slag: 'ingen_grunnlag', totalt: 5 })
    expect(t.hoved).toBe('Ingen beregnet konto 503 for august 2026')
    expect(t.tillegg).toBe('5 stasjoner mangler grunnlag.')
    expect(t.hoved + t.tillegg).not.toMatch(/\d+ kr/)
  })

  it('entall når nøyaktig én stasjon mangler', () => {
    const t = tekst({
      slag: 'delvis', sikkerhet: 'beregnet', kroner: 100,
      dekkede: 4, totalt: 5, utenGrunnlag: ['4185 Dale'],
    })
    expect(t.tillegg).toContain('1 stasjon mangler grunnlag')
  })

  it('ordet «total lønnskost» forekommer ALDRI', () => {
    const alle: Kjedesum[] = [
      { slag: 'hele_kjeden', sikkerhet: 'beregnet', kroner: 1, stasjoner: 5 },
      { slag: 'hele_kjeden', sikkerhet: 'minst', kroner: 1, stasjoner: 5 },
      { slag: 'delvis', sikkerhet: 'beregnet', kroner: 1, dekkede: 1, totalt: 5, utenGrunnlag: [] },
      { slag: 'delvis', sikkerhet: 'minst', kroner: 1, dekkede: 1, totalt: 5, utenGrunnlag: [] },
      { slag: 'ingen_grunnlag', totalt: 5 },
    ]
    for (const s of alle) {
      const t = tekst(s)
      expect(`${t.hoved} ${t.tillegg ?? ''}`.toLowerCase()).not.toContain('total lønnskost')
    }
  })
})

// =====================================================================
// SUMMEN
// =====================================================================

describe('kjedesum — dekning og sikkerhet er uavhengige akser', () => {
  it('alle komplette → hele_kjeden / beregnet', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', beregnet(143889.14)),
      rad('4177', 'Lone', beregnet(97000)),
    ])
    expect(s).toEqual({
      slag: 'hele_kjeden', sikkerhet: 'beregnet', kroner: 240889.14, stasjoner: 2,
    })
  })

  it('ETT minimum-ledd gjør HELE summen til minst', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', beregnet(143889.14)),
      rad('4177', 'Lone', minimum(97000)),
    ])
    expect(s.slag).toBe('hele_kjeden')
    expect(s.slag === 'hele_kjeden' && s.sikkerhet).toBe('minst')
  })

  it('en manglende stasjon bidrar ALDRI med 0 kr', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', beregnet(143889.14)),
      rad('9038', 'Laguneparken', mangel('register')),
    ])
    if (s.slag !== 'delvis') throw new Error('feil slag')
    // Summen er de DEKKEDE, ikke et gjennomsnitt eller en kjedegrense.
    expect(s.kroner).toBe(143889.14)
    expect(s.dekkede).toBe(1)
    expect(s.totalt).toBe(2)
    expect(s.utenGrunnlag).toEqual(['9038 Laguneparken'])
  })

  it('delvis kan være BEREGNET for det den dekker', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', beregnet(143889.14)),
      rad('9038', 'Laguneparken', mangel()),
    ])
    expect(s.slag === 'delvis' && s.sikkerhet).toBe('beregnet')
  })

  it('delvis blir MINST når en dekket stasjon er minimum', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', minimum(143889.14)),
      rad('9038', 'Laguneparken', mangel()),
    ])
    expect(s.slag === 'delvis' && s.sikkerhet).toBe('minst')
  })

  it('ingen dekning → ingen_grunnlag UTEN kronefelt', () => {
    const s = kjedesum([
      rad('9467', 'Bønes', mangel()),
      rad('4185', 'Dale', mangel()),
    ])
    expect(s).toEqual({ slag: 'ingen_grunnlag', totalt: 2 })
    expect(Object.keys(s)).not.toContain('kroner')
    expect(JSON.stringify(s)).not.toContain('kroner')
  })

  it('summen avrundes til to desimaler, ikke flyttallsdrift', () => {
    const s = kjedesum([
      rad('1', 'A', beregnet(0.1)), rad('2', 'B', beregnet(0.2)),
    ])
    expect(s.slag === 'hele_kjeden' && s.kroner).toBe(0.3)
  })
})

// =====================================================================
// REKKEFØLGE
// =====================================================================

describe('rekkefølge — handlingsbehov først, aldri kroner', () => {
  it('mangler → upriset → ferdige', () => {
    const rader = [
      rad('9467', 'Bønes', beregnet(143889.14)),
      rad('9145', 'Varden', minimum(97000)),
      rad('4185', 'Dale', mangel()),
    ]
    expect(sorterKjede(rader).map((r) => r.navn)).toEqual(['Dale', 'Varden', 'Bønes'])
  })

  it('stabilt på butikknummer innen gruppa', () => {
    const rader = [
      rad('9145', 'Varden', mangel()),
      rad('4185', 'Dale', mangel()),
      rad('9038', 'Laguneparken', mangel()),
    ]
    expect(sorterKjede(rader).map((r) => r.butikknummer)).toEqual(['4185', '9038', '9145'])
  })

  it('ALDRI etter kroner — den største står ikke øverst', () => {
    const rader = [
      rad('4177', 'Lone', beregnet(10)),
      rad('9467', 'Bønes', beregnet(999999)),
    ]
    expect(sorterKjede(rader).map((r) => r.navn)).toEqual(['Lone', 'Bønes'])
  })

  it('FORKLARTE TIMER flytter ingenting', () => {
    // Boenes har 68 forklarte timer og null upriset. Den er FERDIG, og
    // skal staa nederst - ikke blant dem som trenger handling.
    const medForklart = beregnet(143889.14, { forklarteTimer: 68, prisedeTimer: 630.77 })
    const rader = [
      rad('9467', 'Bønes', medForklart),
      rad('4185', 'Dale', mangel()),
    ]
    expect(gruppeFor(medForklart)).toBe(3)
    expect(sorterKjede(rader).map((r) => r.navn)).toEqual(['Dale', 'Bønes'])
  })

  it('gruppene er 1 mangel, 2 upriset, 3 ferdig', () => {
    expect(gruppeFor(mangel())).toBe(1)
    expect(gruppeFor(minimum(1))).toBe(2)
    expect(gruppeFor(beregnet(1))).toBe(3)
  })
})
