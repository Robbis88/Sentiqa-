import { describe, it, expect } from 'vitest'
import {
  prosent, prosentAvrundet, byggMaaned, byggDekning, sammenlignbare, maanederI,
  type Svinnrad, type Dekningsrad,
} from './maaned'

// =====================================================================
// Kontrakten, ikke tallene.
//
// Den gamle svinnprosenten var alt svinn delt paa matsalget - to feil i
// samme brook. Den nye er kost mot kost. Men den viktigste forskjellen
// er ikke regnestykket: det er at et manglende tall ikke lenger kan se
// ut som en maaling.
// =====================================================================

const rad = (o: Partial<Svinnrad>): Svinnrad => ({
  stasjon_id: 'st-1',
  maned: '2026-08-01',
  gruppe_kode: '120',
  gruppe_navn: 'Mat',
  koblet: true,
  svinn_kr: 0,
  svinn_antall: 0,
  // ÉN LINJE SOM STANDARD: raden finnes fordi noe ble talt. Skal en
  // test uttrykke «salg, men ingen telling», maa den si `svinn_linjer: 0`
  // uttrykkelig - det er den tilstanden `registrert` skiller ut.
  svinn_linjer: 1,
  varekost_kr: null,
  omsetning_kr: null,
  solgt_antall: null,
  ...o,
})

const dekning = (o: Partial<Dekningsrad>): Dekningsrad => ({
  stasjon_id: 'st-1',
  maned: '2026-08-01',
  dager_registrert: 20,
  dager_i_maaned: 31,
  dager_hittil: 24,
  siste_registrering: '2026-08-23',
  snitt_intervall_dager: 1,
  ...o,
})

// =====================================================================
// MANGLENDE DATA ER IKKE NULL
// =====================================================================

describe('prosent', () => {
  it('regner kost mot kost', () => {
    expect(prosent(500, 10_000)).toBeCloseTo(5, 6)
  })

  it('0 svinn mot en ekte nevner ER 0 % - det er et svar', () => {
    expect(prosent(0, 10_000)).toBe(0)
  })

  it('mangler nevneren, finnes ingen prosent', () => {
    expect(prosent(500, null)).toBeNull()
  })

  // Divisjon paa null gir Infinity, og «∞ %» er en paastand systemet
  // ikke har dekning for.
  it('nevner lik null gir ikke maalbart, ikke uendelig', () => {
    expect(prosent(500, 0)).toBeNull()
    expect(Number.isFinite(prosent(500, 0) as number)).toBe(false)
  })

  it('negativ nevner er ikke en nevner', () => {
    expect(prosent(500, -100)).toBeNull()
  })

  it('taaler soppel uten aa gi NaN videre', () => {
    expect(prosent(NaN, 1000)).toBeNull()
    expect(prosent(500, NaN)).toBeNull()
    expect(prosent(500, Infinity)).toBeNull()
  })

  it('avrunder til én desimal, og beholder null som null', () => {
    expect(prosentAvrundet(1234, 10_000)).toBe(12.3)
    expect(prosentAvrundet(1234, null)).toBeNull()
  })
})

// =====================================================================
// IKKE KOBLET SVINN BLIR I TOTALEN
// =====================================================================

describe('byggMaaned', () => {
  const rader = [
    rad({ gruppe_kode: '120', gruppe_navn: 'Mat', svinn_kr: 6000, svinn_antall: 300, varekost_kr: 100_000 }),
    rad({ gruppe_kode: '140', gruppe_navn: 'Kald drikke', svinn_kr: 2000, svinn_antall: 90, varekost_kr: 50_000 }),
    // Selger, men svinner ikke. Maa vaere med i NEVNEREN.
    rad({ gruppe_kode: '180', gruppe_navn: 'Tobakk', svinn_kr: 0, svinn_antall: 0, svinn_linjer: 0, varekost_kr: 200_000 }),
    // Varmmat paa produksjonskode: ekte kroner, ingen salgsmotpart.
    rad({ gruppe_kode: null, gruppe_navn: null, koblet: false, svinn_kr: 4000, svinn_antall: 150 }),
  ]

  it('beholder ukoblet svinn i totalen', () => {
    const b = byggMaaned('2026-08-01', rader)
    expect(b.kobletKr).toBe(8000)
    expect(b.ikkeKobletKr).toBe(4000)
    expect(b.totalKr).toBe(12_000)
  })

  it('sier hvor stor andel som lot seg kategorisere', () => {
    const b = byggMaaned('2026-08-01', rader)
    expect(b.kobletAndel).toBeCloseTo(8000 / 12_000, 6)
  })

  // Uten dette blir nevneren summen av bare gruppene som svinner, og
  // prosenten for hoey - samme feil som den gamle beregningen.
  it('nevneren inkluderer grupper som selger uten aa svinne', () => {
    const b = byggMaaned('2026-08-01', rader)
    expect(b.varekostKr).toBe(350_000)
    expect(b.prosent).toBe(3.4) // 12000 / 350000
  })

  it('gir «ikke koblet» sin egen linje, uten prosent', () => {
    const b = byggMaaned('2026-08-01', rader)
    const u = b.kategorier.find((k) => k.kode === null)!
    expect(u.navn).toBe('Ikke koblet')
    expect(u.svinnKr).toBe(4000)
    expect(u.prosent).toBeNull()
    expect(u.varekostKr).toBeNull()
  })

  it('sorterer kategoriene paa kroner, stoerst foerst', () => {
    const b = byggMaaned('2026-08-01', rader)
    const koblet = b.kategorier.filter((k) => k.kode !== null)
    expect(koblet.map((k) => k.kode)).toEqual(['120', '140'])
  })

  it('utelater grupper uten svinn fra topplista, men ikke fra nevneren', () => {
    const b = byggMaaned('2026-08-01', rader)
    expect(b.kategorier.some((k) => k.kode === '180')).toBe(false)
    expect(b.varekostKr).toBe(350_000)
  })

  it('regner prosent per kategori mot GRUPPAS egen varekost', () => {
    const b = byggMaaned('2026-08-01', rader)
    expect(b.kategorier.find((k) => k.kode === '120')!.prosent).toBe(6) // 6000/100000
    expect(b.kategorier.find((k) => k.kode === '140')!.prosent).toBe(4) // 2000/50000
  })

  it('en kategori uten salg faar ingen prosent', () => {
    const b = byggMaaned('2026-08-01', [
      rad({ gruppe_kode: '190', gruppe_navn: 'Fritid', svinn_kr: 900, varekost_kr: null }),
    ])
    expect(b.kategorier[0].prosent).toBeNull()
    expect(b.prosent).toBeNull()
  })

  it('ser bort fra andre maaneder', () => {
    const b = byggMaaned('2026-08-01', [
      ...rader,
      rad({ maned: '2026-07-01', svinn_kr: 99_999, varekost_kr: 1 }),
    ])
    expect(b.totalKr).toBe(12_000)
  })

  it('en maaned uten data gir null kroner og ingen prosent', () => {
    const b = byggMaaned('2026-08-01', [])
    expect(b.totalKr).toBe(0)
    expect(b.prosent).toBeNull()
    expect(b.kategorier).toEqual([])
    expect(b.registrert).toBe(false)
  })

  // FIXTUREN AVSLOERTE DENNE. Februar 2026 har salg med varegruppe og
  // ikke en eneste svinnrad. `full outer join` gir da en rad med
  // `svinn_kr = 0` og en ekte nevner - og uten `registrert` ville
  // maaneden staatt som «0 kr · 0,0 %» ved siden av ekte maalinger.
  it('salg uten en eneste svinnlinje er IKKE null prosent svinn', () => {
    const b = byggMaaned('2026-02-01', [
      rad({ maned: '2026-02-01', gruppe_kode: '1201', svinn_kr: 0, svinn_antall: 0,
            svinn_linjer: 0, varekost_kr: 20_000 }),
    ])
    expect(b.registrert).toBe(false)
    expect(b.varekostKr).toBe(20_000)   // nevneren finnes
    expect(b.prosent).toBeNull()        // ...men det er ingenting aa dele paa den
  })
})

// =====================================================================
// DEKNING - manglende registrering er ikke null svinn
// =====================================================================

describe('byggDekning', () => {
  it('maaler mot dager som har PASSERT, ikke hele maaneden', () => {
    const d = byggDekning(dekning({ dager_registrert: 20, dager_hittil: 24, dager_i_maaned: 31 }))!
    expect(d.mulige).toBe(24)
    expect(d.andel).toBeCloseTo(20 / 24, 6)
  })

  // En paagaaende maaned med full foering skal ikke se ut som en med hull.
  it('inneveaerende maaned med full foering har full dekning', () => {
    const d = byggDekning(dekning({ dager_registrert: 8, dager_hittil: 8, dager_i_maaned: 31 }))!
    expect(d.andel).toBe(1)
    expect(d.komplett).toBe(false)
  })

  it('en avsluttet maaned er komplett', () => {
    const d = byggDekning(dekning({ dager_hittil: 31, dager_i_maaned: 31 }))!
    expect(d.komplett).toBe(true)
  })

  it('ingen dekningsrad betyr ingen registrering - ikke full dekning', () => {
    expect(byggDekning(undefined)).toBeNull()
  })

  // ROBERT, 2026-08-24: maten kastes hver dag ved stengetid. Det som
  // varierer er naar det foeres - de fleste foer de gaar hjem, noen
  // skriver det ned og butikksjefen foerer det dagen etter eller
  // samler opp flere dager. Faa foeringsdager er derfor et signal om
  // FOERINGEN, ikke om svinnet.
  it('ti foeringer med tre dagers mellomrom er spredt foering', () => {
    const d = byggDekning(dekning({
      dager_registrert: 10, dager_hittil: 31, dager_i_maaned: 31,
      snitt_intervall_dager: 3,
    }))!
    expect(d.spredt).toBe(true)
    expect(d.intervall).toBe(3)
    // Andelen er fortsatt 32 % - tallet er riktig, tolkningen er det
    // som endrer seg.
    expect(d.andel).toBeCloseTo(10 / 31, 6)
  })

  it('daglig foering er ingenting aa nevne', () => {
    const d = byggDekning(dekning({
      dager_registrert: 28, dager_hittil: 31, dager_i_maaned: 31,
      snitt_intervall_dager: 1.1,
    }))!
    expect(d.spredt).toBe(false)
  })

  // TO PUNKTER ER EN AVSTAND, IKKE ET MOENSTER. Uten denne kunne to
  // foeringer med fjorten dagers mellomrom blitt presentert som et
  // moenster - en rutine lest inn i to tall.
  it('to foeringer gir ingen spredning, uansett avstand', () => {
    const d = byggDekning(dekning({
      dager_registrert: 2, dager_hittil: 31, dager_i_maaned: 31,
      snitt_intervall_dager: 14,
    }))!
    expect(d.spredt).toBe(false)
  })
})

describe('sammenlignbare', () => {
  const d = (registrert: number, hittil: number): Dekningsrad =>
    dekning({ dager_registrert: registrert, dager_hittil: hittil, dager_i_maaned: hittil })

  it('to nesten fulle maaneder er sammenlignbare', () => {
    expect(sammenlignbare(byggDekning(d(30, 31)), byggDekning(d(29, 30)))).toBe(true)
  })

  // Laguneparken hadde 34 % dekning, Lone 93. En «utvikling» mellom dem
  // ville vaert registreringsvane, ikke svinn.
  it('34 % mot 93 % er ikke samme grunnlag', () => {
    expect(sammenlignbare(byggDekning(d(10, 30)), byggDekning(d(28, 30)))).toBe(false)
  })

  it('mangler den ene, kan de ikke sammenlignes', () => {
    expect(sammenlignbare(byggDekning(d(30, 31)), null)).toBe(false)
  })
})

describe('maanederI', () => {
  it('gir distinkte maaneder, nyeste foerst', () => {
    expect(maanederI([
      rad({ maned: '2026-06-01' }), rad({ maned: '2026-08-01' }), rad({ maned: '2026-06-01' }),
    ])).toEqual(['2026-08-01', '2026-06-01'])
  })
})

// =====================================================================
// KANARIFUGLER
// =====================================================================

describe('kanarifugl', () => {
  // Uten denne kunne `prosent` begynt aa returnere 0 for manglende
  // nevner, og hver eneste test over ville fortsatt vaert groenn -
  // fordi de sjekker verdier, ikke fravaeret av en verdi.
  it('null og null er forskjellige verdier gjennom hele kjeden', () => {
    const utenSalg = byggMaaned('2026-08-01', [rad({ svinn_kr: 500, varekost_kr: null })])
    const utenSvinn = byggMaaned('2026-08-01', [
      // TALT, OG DET SVANT INGENTING: linja finnes, belopet er null.
      rad({ svinn_kr: 0, svinn_linjer: 3, varekost_kr: 10_000 }),
    ])
    const utenTelling = byggMaaned('2026-08-01', [
      rad({ svinn_kr: 0, svinn_linjer: 0, varekost_kr: 10_000 }),
    ])

    expect(utenSalg.prosent).toBeNull()
    expect(utenSvinn.prosent).toBe(0)
    expect(utenSalg.prosent).not.toBe(utenSvinn.prosent)

    // Tre tilstander, tre svar. «Talt til null» og «ikke talt» gir
    // samme kroner og skal likevel ikke gi samme prosent.
    expect(utenTelling.totalKr).toBe(utenSvinn.totalKr)
    expect(utenTelling.prosent).toBeNull()
    expect(utenTelling.prosent).not.toBe(utenSvinn.prosent)
  })

  // En total som mister de ukoblede kronene ser ut som en total.
  it('totalen er stoerre enn det kategoriserte naar noe ikke er koblet', () => {
    const b = byggMaaned('2026-08-01', [
      rad({ svinn_kr: 100, varekost_kr: 1000 }),
      rad({ gruppe_kode: null, koblet: false, svinn_kr: 900 }),
    ])
    expect(b.totalKr).toBeGreaterThan(b.kobletKr)
    expect(b.totalKr).toBe(1000)
  })
})

// =====================================================================
// EIEREN SER FLERE STASJONER
// =====================================================================
describe('flere stasjoner i samme bilde', () => {
  const to = [
    rad({ stasjon_id: 'a', gruppe_kode: '120', gruppe_navn: 'Mat', svinn_kr: 3000, svinn_antall: 100, varekost_kr: 60_000 }),
    rad({ stasjon_id: 'b', gruppe_kode: '120', gruppe_navn: 'Mat', svinn_kr: 1000, svinn_antall: 40, varekost_kr: 40_000 }),
    rad({ stasjon_id: 'a', gruppe_kode: null, koblet: false, svinn_kr: 500 }),
    rad({ stasjon_id: 'b', gruppe_kode: null, koblet: false, svinn_kr: 300 }),
  ]

  it('samler samme varegruppe til én linje', () => {
    const b = byggMaaned('2026-08-01', to)
    const mat = b.kategorier.filter((k) => k.kode === '120')
    expect(mat).toHaveLength(1)
    expect(mat[0].svinnKr).toBe(4000)
    expect(mat[0].varekostKr).toBe(100_000)
  })

  // Snittet av 5 % og 2,5 % er 3,75 %. Prosenten av summen er 4 %.
  // Den siste er riktig, og forskjellen vokser med stasjonsstoerrelsen.
  it('regner prosent av summen, ikke snitt av prosenter', () => {
    const b = byggMaaned('2026-08-01', to)
    expect(b.kategorier.find((k) => k.kode === '120')!.prosent).toBe(4)
  })

  it('samler ogsaa det ukoblede', () => {
    const b = byggMaaned('2026-08-01', to)
    expect(b.ikkeKobletKr).toBe(800)
    expect(b.kategorier.filter((k) => k.kode === null)).toHaveLength(1)
  })
})
