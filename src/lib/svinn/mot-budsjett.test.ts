import { describe, it, expect } from 'vitest'
import { velgKilde, svinnstatus, kildenotat, type Budsjettlinje } from './mot-budsjett'

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
