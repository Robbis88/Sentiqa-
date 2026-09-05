import { describe, it, expect } from 'vitest'
import { lagVareprognose, utsolgtDatoer, MIN_DAGER } from './vareprognose'
import { leggTilDager, type SalgsPunkt } from '@/lib/produksjonsplan'
import type { UtsolgtHendelse } from '@/lib/utsolgt'

// =====================================================================
// Vakt over vareprognosen.
//
// Tallet her ender i en bestilling. Bommer det ned, staar hylla tom og
// prognosen bekrefter seg selv ved neste runde — det er den eneste
// feilmaaten som forsterker seg, og derfor den som maa voktes hardest.
// =====================================================================

const VARE = 'MONSTER WHITE 0,5L'
const START = '2026-09-07' // mandag

/** `antall` per dag bakover fra `sisteDato`, i `dager` dager. */
function salg(antall: number, dager: number, sisteDato = '2026-09-06'): SalgsPunkt[] {
  const ut: SalgsPunkt[] = []
  for (let i = 0; i < dager; i++) {
    ut.push({
      dato: leggTilDager(sisteDato, -i),
      varenavn: VARE,
      varegruppeKode: '140',
      varegruppeNavn: 'Kald drikke',
      antall,
    })
  }
  return ut
}

/**
 * Fjoraarsvinduet motoren maaler mot: 364 dager tilbake, ±3 uker rundt.
 *
 * UTEN DETTE FLAGGER MOTOREN `ny`, og den har rett i det — en vare uten
 * fjoraarsdager ER ny for den. Foerste utgave av testene hadde bare
 * ferske dager og forventet ingen forbehold; da maalte de fiksturen, ikke
 * regelen.
 */
function medFjor(antall: number, dager: number): SalgsPunkt[] {
  return [...salg(antall, dager), ...salg(antall, 45, leggTilDager('2026-09-14', -364))]
}

const lag = (over: Partial<Parameters<typeof lagVareprognose>[0]> = {}) =>
  lagVareprognose({
    varenavn: VARE,
    salg: medFjor(10, 40),
    utsolgt: new Set<string>(),
    sisteSalgsdato: '2026-09-06',
    fraDato: START,
    ...over,
  })

describe('utsolgtDatoer', () => {
  const h = (fra: string, til: string): UtsolgtHendelse =>
    ({ ean: '1', varenavn: VARE, fra, til, dager: 3, snitt: 10, tapt_kr: 900 })

  it('flater en hendelse ut til enkeltdatoer', () => {
    expect([...utsolgtDatoer([h('2026-08-10', '2026-08-12')])])
      .toEqual(['2026-08-10', '2026-08-11', '2026-08-12'])
  })

  it('slaar sammen hendelser som overlapper', () => {
    const d = utsolgtDatoer([h('2026-08-10', '2026-08-12'), h('2026-08-11', '2026-08-13')])
    expect(d.size).toBe(4)
  })

  it('gir tomt sett uten hendelser', () => {
    expect(utsolgtDatoer([]).size).toBe(0)
  })
})

describe('sju dager, ikke ett tall ganget med sju', () => {
  it('gir én rad per dag, med ukedag', () => {
    const p = lag()
    expect(p.dager).toHaveLength(7)
    expect(p.dager[0].dato).toBe(START)
    expect(p.dager[0].ukedag).toBe(1) // mandag
    expect(p.dager[6].ukedag).toBe(0) // søndag
  })

  it('summerer dagene', () => {
    const p = lag()
    expect(p.sum).toBe(p.dager.reduce((a, d) => a + d.forventet, 0))
  })

  it('kan spå kortere enn en uke', () => {
    expect(lag({ antallDager: 3 }).dager).toHaveLength(3)
  })
})

describe('tomme hyller trekker ikke prognosen ned', () => {
  // SELVE SAKEN. Var varen utsolgt, staar det null salg i basen, og
  // motoren leser det som «ingen ville ha den».
  it('holder utsolgte dager utenfor grunnlaget', () => {
    // 30 dager med 10 stk, saa 8 dager med 0 fordi hylla var tom.
    const normalt = [...salg(10, 30, '2026-08-29'), ...salg(10, 45, leggTilDager('2026-09-14', -364))]
    const tomme = salg(0, 8, '2026-09-06')
    const alle = [...normalt, ...tomme]
    const tommeDatoer = new Set(tomme.map((s) => s.dato))

    const uten = lagVareprognose({
      varenavn: VARE, salg: alle, utsolgt: new Set<string>(),
      sisteSalgsdato: '2026-09-06', fraDato: START,
    })
    const med = lagVareprognose({
      varenavn: VARE, salg: alle, utsolgt: tommeDatoer,
      sisteSalgsdato: '2026-09-06', fraDato: START,
    })

    expect(med.utelatteDager).toBe(8)
    expect(med.sum, 'utsolgtdagene skal ikke dra prognosen ned').toBeGreaterThan(uten.sum)
  })

  it('sier fra at dager ble holdt utenfor', () => {
    const s = salg(10, 30)
    const p = lagVareprognose({
      varenavn: VARE, salg: s, utsolgt: new Set([s[0].dato, s[1].dato]),
      sisteSalgsdato: '2026-09-06', fraDato: START,
    })
    expect(p.forbehold.join(' ')).toMatch(/utsolgt/i)
  })

  it('nevner ingenting naar ingen dager ble utelatt', () => {
    expect(lag().forbehold.join(' ')).not.toMatch(/utsolgt/i)
  })
})

describe('den sier fra naar den ikke vet', () => {
  // Et tall uten forbehold blir lest som et tall man kan stole paa.
  it('tar forbehold naar grunnlaget er for tynt', () => {
    const p = lag({ salg: salg(10, 4) })
    expect(p.forbehold.join(' ')).toMatch(new RegExp(`Under ${MIN_DAGER}`))
  })

  it('tar ingen forbehold naar grunnlaget holder', () => {
    expect(lag({ salg: medFjor(10, 40) }).forbehold).toEqual([])
  })

  // KANARIFUGL paa motorens egen aerlighet: uten fjoraarsdager SKAL den
  // flagge `ny`, og det skal naa fram som et forbehold.
  it('sier at varen er ny naar det ikke finnes fjoraarsdager', () => {
    expect(lag({ salg: salg(10, 40) }).forbehold.join(' ')).toMatch(/ny/i)
  })

  // KANARIFUGL: uten salg i det hele tatt skal den ikke svare 0 stille.
  it('svarer ikke null i stillhet paa en vare uten historikk', () => {
    const p = lag({ salg: [] })
    expect(p.forbehold.length).toBeGreaterThan(0)
    expect(p.sum).toBe(0)
  })
})

describe('determinisme', () => {
  it('gir samme prognose for samme grunnlag', () => {
    expect(JSON.stringify(lag())).toBe(JSON.stringify(lag()))
  })
})
