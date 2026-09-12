import { describe, expect, it } from 'vitest'
import { tilEpost } from './epost'
import type { Maanedsplan } from './plan'

const flat = (t: string) => t.replace(/\s+/g, ' ')

function plan(over: Partial<Maanedsplan> = {}): Maanedsplan {
  return {
    stasjonNavn: 'Dale',
    maaned: '2026-07-01',
    dom: 'medvind',
    ingress: 'Resultatet i juli er 63 246 kroner. I januar var det −162 491.',
    punkter: [
      {
        slag: 'bekreftelse', loftestang: 'matkast', tittel: 'Matkast',
        tekst: 'Riktig vei 4 måneder på rad.', kronerIAret: 208_416,
      },
      {
        slag: 'tiltak', loftestang: 'paavirkbar_drift',
        tittel: 'Påvirkbare driftskostnader',
        tekst: 'Størst: ASKO VEST AS, 29 825 kroner på 12 bilag.',
        kronerIAret: 93_431, leverandor: 'ASKO VEST AS',
      },
    ],
    merknad: null,
    ...over,
  }
}

describe('tilEpost', () => {
  it('emnet sier RETNINGEN, ikke «Maanedsplan»', () => {
    // Et emne som er likt hver maaned blir et emne ingen leser.
    expect(tilEpost(plan(), 'https://x').emne).toBe('Dale går riktig vei — juli')
    expect(tilEpost(plan({ dom: 'motvind' }), 'https://x').emne)
      .toBe('Dale, én ting i juli')
    expect(tilEpost(plan({ dom: 'flat' }), 'https://x').emne).toBe('Dale — juli')
  })

  it('baerer ingressen og punktene', () => {
    const t = flat(tilEpost(plan(), 'https://x').html)
    expect(t).toContain('MEDVIND')
    expect(t).toContain('Matkast')
    expect(t).toContain('ASKO VEST AS')
    expect(t).toContain('208 416'.replace(/\s/g, ' '))
  })

  it('merker tiltaket NESTE i medvind og DETTE i motvind', () => {
    // «Neste loeftestang» og «denne ene tingen» er to ulike beskjeder,
    // og forskjellen maa vaere synlig for den som leser paa telefonen.
    expect(tilEpost(plan(), 'https://x').tekst).toContain('NESTE:')
    const m = plan({ dom: 'motvind', punkter: [plan().punkter[1]] })
    expect(tilEpost(m, 'https://x').tekst).toContain('DETTE:')
  })

  it('KANARI: en tom plan sier noe, i stedet for aa vaere tom', () => {
    // Uten dette ville brevet vaert en overskrift og ingenting - og en
    // butikksjef som faar det, tror noe er i stykker.
    const p = tilEpost(plan({ punkter: [] }), 'https://x')
    expect(p.tekst).toContain('Hold kursen')
    expect(flat(p.html)).toContain('Hold kursen')
  })

  it('KANARI: skjuler ikke at kroneverdier mangler', () => {
    const p = tilEpost(plan({
      merknad: 'Kroneverdier vises ikke: kjeden mangler royaltysatser fra BP.',
      punkter: plan().punkter.map((x) => ({ ...x, kronerIAret: null })),
    }), 'https://x')
    expect(p.tekst).toContain('royaltysatser')
    expect(p.tekst).not.toContain('kroner i året')
  })

  it('rømmer HTML i stasjonsnavn og tekst', () => {
    const p = tilEpost(plan({
      stasjonNavn: '<script>alert(1)</script>',
      ingress: 'Resultatet & marginen',
    }), 'https://x')
    expect(p.html).not.toContain('<script>alert')
    expect(p.html).toContain('&lt;script&gt;')
    expect(p.html).toContain('Resultatet &amp; marginen')
  })

  it('er en ren funksjon: samme plan gir samme e-post', () => {
    const a = tilEpost(plan(), 'https://x')
    const b = tilEpost(plan(), 'https://x')
    expect(a).toEqual(b)
  })

  it('tekstversjonen baerer det samme som HTML-en', () => {
    // En klient som bare viser ren tekst skal ikke faa et tomt brev.
    const p = tilEpost(plan(), 'https://x')
    expect(p.tekst).toContain('Matkast')
    expect(p.tekst).toContain('ASKO VEST AS')
    expect(p.tekst).toContain('https://x/regnskap')
  })
})
