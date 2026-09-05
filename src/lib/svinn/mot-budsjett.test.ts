import { describe, it, expect } from 'vitest'
import { velgKilde, svinnstatus, kildenotat, svinnbilde, vareomradeAv, avdelingAv, type Budsjettlinje } from './mot-budsjett'

// =====================================================================
// Vakt over svinn mot budsjett.
//
// To kilder for samme maaned er én for mye. Reglene her avgjoer hvilken
// som gjelder, og om leseren faar vite det.
// =====================================================================

const LINJE: Budsjettlinje = {
  kode: '120', navn: 'MAT',
  kastPstAvSalg: 0.08415231157126303,
  kastBudsjettKr: 398657.63,
}

const kart = (o: Record<string, number>) => new Map(Object.entries(o))

describe('velgKilde', () => {
  // AVLAGT MAANED VINNER. To tall for samme maaned er ett for mye, og
  // det som gjelder utad maa vaere regnskapets.
  it('lar regnskapet slaa den daglige opplastingen', () => {
    const ut = velgKilde(kart({ '2026-07': 31000 }), kart({ '2026-07': 28000 }), kart({ '2026-07': 400000 }))
    expect(ut).toEqual([{ maaned: '2026-07', kastKr: 31000, kilde: 'regnskap', salgKr: 400000 }])
  })

  it('bruker den daglige der regnskapet ikke er kommet', () => {
    const ut = velgKilde(kart({}), kart({ '2026-08': 28000 }), kart({ '2026-08': 400000 }))
    expect(ut[0].kilde).toBe('daglig')
    expect(ut[0].kastKr).toBe(28000)
  })

  // KANARIFUGL. `||` i stedet for `??` ville latt en avlagt maaned med
  // NULL kastet falle tilbake paa den daglige summen - og da hadde
  // regnskapet sagt null mens skjermen viste 28 000.
  it('lar 0 kr i en avlagt maaned staa som 0', () => {
    const ut = velgKilde(kart({ '2026-07': 0 }), kart({ '2026-07': 28000 }), kart({ '2026-07': 400000 }))
    expect(ut[0].kastKr).toBe(0)
    expect(ut[0].kilde).toBe('regnskap')
  })

  it('tar med maaneder som bare finnes i én av kildene', () => {
    const ut = velgKilde(kart({ '2026-06': 30000 }), kart({ '2026-07': 28000 }), kart({}))
    expect(ut.map((m) => m.maaned)).toEqual(['2026-06', '2026-07'])
    expect(ut.map((m) => m.kilde)).toEqual(['regnskap', 'daglig'])
  })

  it('sorterer kronologisk', () => {
    const ut = velgKilde(kart({}), kart({ '2026-08': 1, '2026-02': 1, '2026-05': 1 }), kart({}))
    expect(ut.map((m) => m.maaned)).toEqual(['2026-02', '2026-05', '2026-08'])
  })
})

describe('svinnstatus', () => {
  const mnd = (m: string, kast: number, salg: number, kilde: 'regnskap' | 'daglig' = 'daglig') =>
    ({ maaned: m, kastKr: kast, salgKr: salg, kilde })

  // BUDSJETTET FOELGER SALGET. Kravet er en prosent, saa aaret delt paa
  // tolv ville vaert feil hver eneste maaned med sesong i.
  it('regner budsjettet av salget, ikke av kalenderen', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 30000, 400000), mnd('2026-08', 32000, 450000)])
    expect(s.salgHittilKr).toBe(850000)
    expect(Math.round(s.budsjettHittilKr)).toBe(Math.round(0.08415231157126303 * 850000))
    // ... og IKKE aarsbudsjettet delt paa tolv ganger to.
    expect(Math.round(s.budsjettHittilKr)).not.toBe(Math.round(398657.63 / 6))
  })

  it('gir positivt avvik naar det er kastet for mye', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 50000, 400000)])
    expect(s.avvikKr).toBeGreaterThan(0)
  })

  it('gir negativt avvik naar stasjonen ligger under', () => {
    const s = svinnstatus(LINJE, [mnd('2026-07', 20000, 400000)])
    expect(s.avvikKr).toBeLessThan(0)
  })

  it('teller kildene hver for seg', () => {
    const s = svinnstatus(LINJE, [
      mnd('2026-06', 30000, 400000, 'regnskap'),
      mnd('2026-07', 31000, 410000, 'regnskap'),
      mnd('2026-08', 28000, 420000, 'daglig'),
    ])
    expect(s.avlagteMaaneder).toBe(2)
    expect(s.forelopigeMaaneder).toBe(1)
  })

  // Ingen salg gir ingen prosent. 0 % ville sett ut som en maaling.
  it('gir null prosent - ikke 0 - uten salg', () => {
    expect(svinnstatus(LINJE, [mnd('2026-07', 0, 0)]).faktiskPst).toBeNull()
  })
})

describe('kildenotat', () => {
  const status = (avlagt: number, forelopig: number) => svinnstatus(LINJE, [
    ...Array.from({ length: avlagt }, (_, i) => ({ maaned: `2026-0${i + 1}`, kastKr: 1, salgKr: 1, kilde: 'regnskap' as const })),
    ...Array.from({ length: forelopig }, (_, i) => ({ maaned: `2026-1${i}`, kastKr: 1, salgKr: 1, kilde: 'daglig' as const })),
  ])

  // Et tall uten kildeangivelse leses som fasit. Notatet staar aldri tomt.
  it('sier alltid noe om hvor tallet kommer fra', () => {
    for (const [a, f] of [[0, 0], [3, 0], [0, 2], [2, 1]]) {
      const t = kildenotat(status(a, f))
      expect(t.length, `${a} avlagte, ${f} forelopige`).toBeGreaterThan(15)
    }
  })

  it('sier «fasit» bare naar alt er avlagt', () => {
    expect(kildenotat(status(3, 0))).toMatch(/fasit/)
    expect(kildenotat(status(2, 1))).not.toMatch(/fasit/)
  })

  it('varsler at tallet kan flytte seg naar noe er forelopig', () => {
    expect(kildenotat(status(2, 1))).toMatch(/flytte seg/)
    expect(kildenotat(status(0, 2))).toMatch(/flytte seg/)
  })
})

describe('regnskapskoden', () => {
  // `13010` er 130 VARM DRIKKE >> 10 KAFFE. Samme nummerering som
  // salgsdataene, bare skrevet i ett - og det er dét som lar de to
  // kildene legges ved siden av hverandre.
  it('deler koden i avdeling og vareomraade', () => {
    expect(avdelingAv('12010')).toBe('120')
    expect(vareomradeAv('12010')).toBe('10')
    expect(vareomradeAv('13011')).toBe('11')
  })

  // KANARIFUGL. Regnskapet har ogsaa korte koder (`120`, `40`) og
  // tekstkoder. Et blindt `slice(3)` ville laget vareomraade `''` av
  // dem og slaatt dem sammen til én meningsloes linje.
  it('svarer null paa alt som ikke er fem siffer', () => {
    for (const k of ['120', '4', 'RESULTAT', '', null, '1201', '120100']) {
      expect(vareomradeAv(k), String(k)).toBeNull()
    }
  })
})

describe('svinnbilde', () => {
  const b = (kode: string, navn: string, pst: number, kr: number): Budsjettlinje =>
    ({ kode, navn, kastPstAvSalg: pst, kastBudsjettKr: kr })
  const m = (o: Record<string, Record<string, number>>) =>
    new Map(Object.entries(o).map(([k, v]) => [k, new Map(Object.entries(v))]))

  it('setter hver linje mot sitt eget krav', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 119577), b('11', 'PØLSE', 0.058, 83663)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { '2026-08': 12000 }, '11': { '2026-08': 4000 } }),
      salg: m({ '10': { '2026-08': 80000 }, '11': { '2026-08': 120000 } }),
    })
    expect(ut.linjer).toHaveLength(2)
    // Bakeri: 12 000 kastet mot 12 % av 80 000 = 9 600. Over.
    const bakeri = ut.linjer.find((l) => l.linje.kode === '10')!
    expect(Math.round(bakeri.budsjettHittilKr)).toBe(9600)
    expect(bakeri.avvikKr).toBeGreaterThan(0)
  })

  it('sorterer verst foerst', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 1), b('11', 'PØLSE', 0.06, 1)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 100 }, '11': { x: 9000 } }),
      salg: m({ '10': { x: 10000 }, '11': { x: 10000 } }),
    })
    expect(ut.linjer[0].linje.kode).toBe('11')
  })

  // TOTALEN ER SUMMEN AV LINJENE. Budsjettet baerer baade Mat-totalen og
  // undergruppene; leste vi begge og la dem sammen, ville hver krone
  // telt to ganger.
  it('summerer linjene i stedet for aa lese en egen totalrad', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.1, 1000), b('11', 'PØLSE', 0.1, 2000)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 500 }, '11': { x: 700 } }),
      salg: m({ '10': { x: 5000 }, '11': { x: 9000 } }),
    })
    expect(ut.total!.kastHittilKr).toBe(1200)
    expect(ut.total!.salgHittilKr).toBe(14000)
    expect(ut.total!.linje.kastBudsjettKr).toBe(3000)
  })

  // Bakeri kaster 12 % av lite, poelse 6 % av mye. Snittet av de to
  // prosentene beskriver ingen av dem.
  it('gir en VEID totalprosent, ikke et snitt av linjenes', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.12, 1), b('11', 'PØLSE', 0.06, 1)],
      kastRegnskap: m({}),
      kastDaglig: m({ '10': { x: 0 }, '11': { x: 0 } }),
      salg: m({ '10': { x: 10000 }, '11': { x: 90000 } }),
    })
    // Veid: (0,12*10 000 + 0,06*90 000) / 100 000 = 6,6 %. Snitt: 9 %.
    expect(Math.round(ut.total!.linje.kastPstAvSalg * 1000) / 10).toBeCloseTo(6.6, 1)
  })

  it('sier fra naar det ikke finnes noe budsjett', () => {
    const ut = svinnbilde({ budsjett: [], kastRegnskap: m({}), kastDaglig: m({}), salg: m({}) })
    expect(ut.total).toBeNull()
    expect(ut.notat).toMatch(/Ingen kastbudsjett/)
  })

  it('teller kildene i totalens notat', () => {
    const ut = svinnbilde({
      budsjett: [b('10', 'BAKERI', 0.1, 1)],
      kastRegnskap: m({ '10': { '2026-07': 900 } }),
      kastDaglig: m({ '10': { '2026-08': 800 } }),
      salg: m({ '10': { '2026-07': 9000, '2026-08': 9000 } }),
    })
    expect(ut.total!.avlagteMaaneder).toBe(1)
    expect(ut.total!.forelopigeMaaneder).toBe(1)
    expect(ut.notat).toMatch(/flytte seg/)
  })
})
