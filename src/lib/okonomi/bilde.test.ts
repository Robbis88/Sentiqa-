import { describe, expect, it } from 'vitest'
import {
  byggOkonomibilde, sikkerhetsgrad, skjermFor, svakeste,
  type Bildeinput, type Dekning, type Felt, type Kilde, type Regnskapstall,
} from './bilde'
import type { Lonnsrom } from '@/lib/lonnskost/rom'

// =====================================================================
// Dales BP: 1 201 000 i brutto, 383 285 i loenn. Samme tall som
// `rom.test.ts`, saa de to filene beskriver samme stasjon.
// =====================================================================
const ANDEL = 383285 / 1201000

const ROM = (o: Partial<Lonnsrom> = {}): Lonnsrom => ({
  maaned: '2026-08',
  bruttoKr: 1201000,
  anslaatt: false,
  lonnsandel: ANDEL,
  romKr: 383285,
  bpLonnKr: 383285,
  kalibrering: 1,
  ekstraSvinnKr: 0,
  omsetningKr: 4200000,
  svinnKr: 0,
  bilvaskBruttoKr: 0,
  ...o,
})

const DEKNING: Dekning = {
  salgsdager: { har: 31, av: 31 },
  bilvaskUker: { har: 4, av: 4 },
  lonnsfil: true,
  regnskap: true,
  mangler: [],
  retningPaaFeil: 'ukjent',
}

const REGNSKAP: Regnskapstall = {
  omsetningKr: 4200000,
  bruttoKr: 1201000,
  lonnKr: 390000,
  royaltyKr: 420000,
  paavirkbarDriftKr: 96000,
}

const INN = (o: Partial<Bildeinput> = {}): Bildeinput => ({
  stasjonId: 's1',
  maaned: '2026-08',
  rom: ROM(),
  regnskap: REGNSKAP,
  easyatworkLonnKr: 371000,
  dagligOmsetningKr: 4150000,
  dekning: DEKNING,
  ...o,
})

describe('svakeste — lov 2', () => {
  const alle: Kilde[] = ['mangler', 'plan', 'prognose', 'fasit']

  it('mangler slaar alt', () => {
    for (const k of alle) expect(svakeste('mangler', k)).toBe('mangler')
  })

  it('plan er svakere enn prognose, og prognose svakere enn fasit', () => {
    // En PLAN er ikke et anslag paa hva som skjer - den er hva noen
    // bestemte at skulle skje. Naar spoersmaalet er «hva ble det», er
    // den derfor svakere enn en prognose.
    expect(svakeste('plan', 'prognose')).toBe('plan')
    expect(svakeste('prognose', 'fasit')).toBe('prognose')
  })

  it('er symmetrisk', () => {
    for (const a of alle) for (const b of alle) expect(svakeste(a, b)).toBe(svakeste(b, a))
  })

  it('KANARIFUGL: den returnerer faktisk BEGGE verdier, ikke bare én', () => {
    // Uten denne ville `() => 'mangler'` bestaatt den foerste testen, og
    // `(a) => a` den siste.
    expect(svakeste('fasit', 'fasit')).toBe('fasit')
    expect(svakeste('plan', 'plan')).toBe('plan')
  })
})

// =====================================================================
// LOV 1: FASIT OVERSTYRER ALLTID
// =====================================================================
describe('fasit slaar prognose', () => {
  it('omsetningen fra regnskapet vinner over den daglige', () => {
    const b = byggOkonomibilde(INN())
    expect(b.omsetning.verdi).toBe(REGNSKAP.omsetningKr)
    expect(b.omsetning.kilde).toBe('fasit')
  })

  it('loennen fra regnskapet vinner over easy@work', () => {
    const b = byggOkonomibilde(INN())
    expect(b.lonn.verdi).toBe(REGNSKAP.lonnKr)
    expect(b.lonn.kilde).toBe('fasit')
    expect(b.lonn.verdi).not.toBe(371000)
  })

  it('uten regnskap faller begge tilbake paa den tidlige kilden', () => {
    const b = byggOkonomibilde(INN({ regnskap: null }))
    expect(b.omsetning.verdi).toBe(4150000)
    expect(b.omsetning.kilde).toBe('prognose')
    expect(b.lonn.verdi).toBe(371000)
    expect(b.lonn.kilde).toBe('prognose')
  })

  it('KANARIFUGL: de to kildene baerer ULIKE tall', () => {
    // Uten denne kunne «fasit vinner» bestaatt fordi begge var like.
    expect(REGNSKAP.omsetningKr).not.toBe(4150000)
    expect(REGNSKAP.lonnKr).not.toBe(371000)
  })

  it('uten noen av delene staar feltet som mangler, ikke som null kroner', () => {
    const b = byggOkonomibilde(INN({ regnskap: null, easyatworkLonnKr: null, dagligOmsetningKr: null }))
    expect(b.lonn.kilde).toBe('mangler')
    expect(b.lonn.verdi).toBeNull()
    expect(b.lonn.verdi).not.toBe(0)
    expect(b.lonn.grunn).toMatch(/ikke kommet/)
  })
})

describe('bruttoen og rommet arver hverandre', () => {
  it('avlagt maaned gir fasit paa begge', () => {
    const b = byggOkonomibilde(INN({ rom: ROM({ anslaatt: false }) }))
    expect(b.brutto.kilde).toBe('fasit')
    expect(b.lonnsrom.kilde).toBe('fasit')
  })

  it('anslaatt brutto gjoer ogsaa rommet til en prognose', () => {
    const b = byggOkonomibilde(INN({ rom: ROM({ anslaatt: true }) }))
    expect(b.brutto.kilde).toBe('prognose')
    expect(b.lonnsrom.kilde).toBe('prognose')
    expect(b.lonnsrom.grunn).toMatch(/Lønnsandel fra BP/)
  })

  it('BP-loenna er ALLTID plan, ogsaa naar maaneden er avlagt', () => {
    // Den skrives aldri om. Det er hele poenget med den.
    for (const anslaatt of [true, false]) {
      expect(byggOkonomibilde(INN({ rom: ROM({ anslaatt }) })).bpLonn.kilde).toBe('plan')
    }
  })
})

// =====================================================================
// LOV 2: ET AVLEDET TALL ARVER DEN SVAKESTE KILDEN
// =====================================================================
describe('styringsavviket arver svakeste kilde', () => {
  it('anslaatt rom + fasit loenn gir en PROGNOSE, ikke en fasit', () => {
    const b = byggOkonomibilde(INN({ rom: ROM({ anslaatt: true }) }))
    expect(b.lonn.kilde).toBe('fasit')
    expect(b.lonnsrom.kilde).toBe('prognose')
    expect(
      b.styringsavvik.kilde,
      '\nAvviket sto som fasit fordi loennstallet var det.\n'
      + 'Rommet var anslaatt, og da er avviket et anslag.\n',
    ).toBe('prognose')
  })

  it('fasit rom + prognose loenn gir ogsaa prognose', () => {
    const b = byggOkonomibilde(INN({ regnskap: { ...REGNSKAP, lonnKr: null } }))
    expect(b.lonnsrom.kilde).toBe('fasit')
    expect(b.lonn.kilde).toBe('prognose')
    expect(b.styringsavvik.kilde).toBe('prognose')
  })

  it('begge fasit gir fasit', () => {
    expect(byggOkonomibilde(INN()).styringsavvik.kilde).toBe('fasit')
  })

  it('manglende rom gjoer avviket til mangler', () => {
    const b = byggOkonomibilde(INN({ rom: ROM({ romKr: null }) }))
    expect(b.styringsavvik.kilde).toBe('mangler')
    expect(b.styringsavvik.avvik.kroner).toBeNull()
  })

  it('kaller E2 sin funksjon og regner ikke selv', () => {
    // Loenn 390 000 mot rom 383 285: 1,75 % over, altsaa normalt.
    const b = byggOkonomibilde(INN())
    expect(b.styringsavvik.avvik.kroner).toBeCloseTo(6715, 0)
    expect(b.styringsavvik.avvik.alvor).toBe('normal')
  })
})

describe('royalty og drift har ingen tidlig kilde', () => {
  it('royalty er fasit naar regnskapet er inne', () => {
    expect(byggOkonomibilde(INN()).royalty.kilde).toBe('fasit')
  })

  it('royalty mangler HELT uten regnskap — den anslaas ikke', () => {
    // Aa anslaa den ville krevd `omsetning x sats`. Den regningen bor i
    // `royalty.ts`, og sammenstilleren kan ikke multiplisere.
    const b = byggOkonomibilde(INN({ regnskap: null }))
    expect(b.royalty.kilde).toBe('mangler')
    expect(b.royalty.grunn).toMatch(/Ingen tidlig kilde/)
  })

  it('paavirkbar drift likesaa — ingen faktura foer regnskapet', () => {
    const b = byggOkonomibilde(INN({ regnskap: null }))
    expect(b.paavirkbarDrift.kilde).toBe('mangler')
  })
})

describe('sikkerhetsgrad', () => {
  const F = (kilde: Kilde): Felt => ({ verdi: 1, kilde })

  it('alt fasit er hoy', () => {
    expect(sikkerhetsgrad([F('fasit'), F('fasit')])).toBe('hoy')
  })

  it('ingenting fasit er lav', () => {
    expect(sikkerhetsgrad([F('prognose'), F('plan'), F('mangler')])).toBe('lav')
  })

  it('blandet er middels', () => {
    expect(sikkerhetsgrad([F('fasit'), F('prognose')])).toBe('middels')
  })

  it('bildet med regnskap er hoy, uten er lav', () => {
    expect(byggOkonomibilde(INN()).sikkerhet).toBe('hoy')
    // UTEN REGNSKAP ER ROMMET OGSAA ANSLAATT. `byggLonnsrom` setter
    // `anslaatt = faktisk === null`, saa de to inngangene henger sammen
    // naar de hentes for samme maaned. En fikstur som fjerner
    // regnskapet men beholder et ikke-anslaatt rom beskriver en
    // tilstand som ikke kan oppstaa - og maalte derfor ingenting.
    const utenFasit = INN({ regnskap: null, rom: ROM({ anslaatt: true }) })
    expect(byggOkonomibilde(utenFasit).sikkerhet).toBe('lav')
  })
})

// =====================================================================
// ROLLEGRENSEN
// =====================================================================
describe('skjermFor', () => {
  it('butikksjefen ser ikke royalty', () => {
    // Kjedeavtale hun verken forhandler eller paavirker - et tall uten
    // en handling.
    const b = skjermFor('butikksjef', byggOkonomibilde(INN()))
    expect(b.royalty.verdi).toBeNull()
    expect(b.royalty.kilde).toBe('mangler')
    expect(b.royalty.grunn).toMatch(/eierens linje/)
  })

  it('men hun ser alt hun kan paavirke', () => {
    const b = skjermFor('butikksjef', byggOkonomibilde(INN()))
    expect(b.omsetning.verdi).toBe(REGNSKAP.omsetningKr)
    expect(b.brutto.verdi).toBe(1201000)
    expect(b.lonn.verdi).toBe(REGNSKAP.lonnKr)
    expect(b.paavirkbarDrift.verdi).toBe(REGNSKAP.paavirkbarDriftKr)
    expect(b.lonnsrom.verdi).toBeCloseTo(383285, 0)
  })

  it('eieren ser royalty', () => {
    expect(skjermFor('retailer_admin', byggOkonomibilde(INN())).royalty.verdi)
      .toBe(REGNSKAP.royaltyKr)
  })

  it('skjermingen trekker sikkerheten ned, fordi et felt faktisk mangler', () => {
    // Bildet er ikke lenger komplett for henne, og det skal vises.
    expect(byggOkonomibilde(INN()).sikkerhet).toBe('hoy')
    expect(skjermFor('butikksjef', byggOkonomibilde(INN())).sikkerhet).toBe('middels')
  })

  it('KANARIFUGL: nettbrettet gaar ikke gjennom denne i det hele tatt', () => {
    // `skjermFor` er ERGONOMI, ikke sikkerhet. RLS avgjoer hva som
    // kommer ut av basen; denne fjerner bare et tall fra et bilde som
    // alt er hentet. Nettbrettet naar ingen oekonomiflate, saa en
    // «skjerming» her ville gitt falsk trygghet.
    const b = skjermFor('butikkbruker_tablet', byggOkonomibilde(INN()))
    expect(b.royalty.verdi).toBe(REGNSKAP.royaltyKr)
  })
})

describe('dekningen foelger med ut, uendret', () => {
  it('bildet baerer det som faktisk var kommet inn', () => {
    const d: Dekning = {
      salgsdager: { har: 19, av: 31 },
      bilvaskUker: { har: 2, av: 4 },
      lonnsfil: false,
      regnskap: false,
      mangler: ['bilvask uke 41', 'bilvask uke 42'],
      retningPaaFeil: 'for_lavt',
    }
    expect(byggOkonomibilde(INN({ dekning: d })).dekning).toEqual(d)
  })

  it('retningPaaFeil er med, saa et varsel kan vente naar anslaget er for stramt', () => {
    // En manglende bilvaskuke gjoer bruttoanslaget for LAVT og dermed
    // rommet for stramt. Det er en annen beskjed enn «usikkert».
    const d = { ...DEKNING, retningPaaFeil: 'for_lavt' as const }
    expect(byggOkonomibilde(INN({ dekning: d })).dekning.retningPaaFeil).toBe('for_lavt')
  })
})
