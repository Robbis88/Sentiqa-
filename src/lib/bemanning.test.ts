import { describe, expect, test } from 'vitest'
import {
  bundneTimer,
  maanedsvekter,
  dagerPerUkedag,
  disponibleTimerAar,
  fordelAaret,
  fordelPaaMaaneder,
  planleggMaaned,
  type Vindu,
} from './bemanning'

const FRADRAG = { reservePst: 1.8, sikkerhetPst: 3 }

describe('årsramme til måned', () => {
  test('fradragene tas multiplikativt, ikke som sum', () => {
    // 1,8 % og 3 % er ikke 4,8 % - de legges på hverandre.
    expect(disponibleTimerAar(10000, FRADRAG)).toBeCloseTo(10000 * 0.982 * 0.97, 6)
  })

  test('månedene summerer til nettorammen', () => {
    const brutto = [615671, 632617, 663619, 712681, 725674, 864280,
      977680, 845240, 638803, 590060, 490579, 548666]
    const m = fordelPaaMaaneder(11187.47, brutto, FRADRAG)
    expect(m.reduce((a, b) => a + b, 0)).toBeCloseTo(disponibleTimerAar(11187.47, FRADRAG), 6)
  })

  test('juli får mest og november minst — Dales egen bruttokurve', () => {
    const brutto = [615671, 632617, 663619, 712681, 725674, 864280,
      977680, 845240, 638803, 590060, 490579, 548666]
    const m = fordelPaaMaaneder(11187.47, brutto, FRADRAG)
    expect(Math.max(...m)).toBe(m[6]) // juli
    expect(Math.min(...m)).toBe(m[10]) // november
    expect(Math.max(...m) / Math.min(...m)).toBeCloseTo(977680 / 490579, 6)
  })

  test('uten BP faller den tilbake på flat fordeling', () => {
    const m = fordelPaaMaaneder(1200, new Array(12).fill(0), { reservePst: 0, sikkerhetPst: 0 })
    expect(m).toEqual(new Array(12).fill(100))
  })

  test('avviser feil antall månedstall', () => {
    expect(() => fordelPaaMaaneder(1000, [1, 2, 3], FRADRAG)).toThrow(/12/)
  })
})

describe('maanedsvekter', () => {
  const bp = [615671, 632617, 663619, 712681, 725674, 864280,
    977680, 845240, 638803, 590060, 490579, 548666]

  test('malte kunder styrer, ikke BP-kurven', () => {
    // Kundene sier juli er dobbelt saa travel som januar. BP sier 1,6x.
    // Kundene skal vinne.
    const kunder = new Array(12).fill(1000)
    kunder[6] = 2000
    const v = maanedsvekter(kunder, bp)
    expect(v[6] / v[0]).toBeCloseTo(2, 6)
    expect(v.reduce((a, b) => a + b, 0)).toBeCloseTo(1, 9)
  })

  test('en maaned uten kundedata faar vekt fra BP, ikke null timer', () => {
    // Vi har lastet opp januar-juni. Juli-desember mangler. De kan ikke
    // faa null timer bare fordi opplastingen ikke har naadd dem.
    const kunder: (number | null)[] = [1000, 1000, 1000, 1000, 1000, 1000,
      null, null, null, null, null, null]
    const v = maanedsvekter(kunder, bp)
    expect(v.every((x) => x > 0)).toBe(true)
    // Juli har hoyest BP av de manglende -> hoyest vekt av dem.
    expect(Math.max(...v.slice(6))).toBe(v[6])
    expect(v.reduce((a, b) => a + b, 0)).toBeCloseTo(1, 9)
  })

  test('uten kundedata i det hele tatt faller den tilbake paa BP', () => {
    const v = maanedsvekter(new Array(12).fill(null), bp)
    const sum = bp.reduce((a, b) => a + b, 0)
    expect(v[6]).toBeCloseTo(bp[6] / sum, 9)
  })

  test('uten noe som helst blir det flatt', () => {
    const v = maanedsvekter(new Array(12).fill(null), new Array(12).fill(0))
    expect(v).toEqual(new Array(12).fill(1 / 12))
  })

  test('BP i kroner og kunder i personer blandes ikke som samme enhet', () => {
    // Halve aaret malt (1000 kunder), halve fra BP i hundretusener. Uten
    // skalering ville BP-maanedene fatt 600x vekten av de malte.
    const kunder: (number | null)[] = [1000, 1000, 1000, 1000, 1000, 1000,
      null, null, null, null, null, null]
    const v = maanedsvekter(kunder, new Array(12).fill(700000))
    // Flat BP + flate kunder -> alle tolv skal vaere like.
    for (const x of v) expect(x).toBeCloseTo(1 / 12, 6)
  })
})

describe('dagerPerUkedag', () => {
  test('januar 2026 har fem torsdager og fire mandager', () => {
    const d = dagerPerUkedag(2026, 1)
    expect(d[4]).toBe(5) // torsdag: 1., 8., 15., 22., 29.
    expect(d[1]).toBe(4)
    expect(d.slice(1).reduce((a, b) => a + b, 0)).toBe(31)
  })

  test('februar 2026 har 28 dager', () => {
    expect(dagerPerUkedag(2026, 2).slice(1).reduce((a, b) => a + b, 0)).toBe(28)
  })
})

// Døgnåpent alle sju dager, én person i gulvet: 24 x antall dager i maaneden.
const DOGNAAPENT: Vindu[] = [1, 2, 3, 4, 5, 6, 7].map((ukedag) => ({
  ukedag, fraTime: 0, tilTime: 24, minBemanning: 1,
}))

describe('fordelAaret', () => {
  const rammer = (timer: number[]) => timer.map((t, i) => ({ maned: i + 1, timer: t }))

  test('gulvet regnes per maaned etter antall dager', () => {
    // Juni har 30 dager, juli 31.
    expect(bundneTimer({ ar: 2026, maned: 6, vinduer: DOGNAAPENT, krav: [], fasteVakter: [] })).toBe(720)
    expect(bundneTimer({ ar: 2026, maned: 7, vinduer: DOGNAAPENT, krav: [], fasteVakter: [] })).toBe(744)
  })

  test('en maaned som ikke dekker sitt eget gulv henter fra aaret', () => {
    // Vardens juni: 690 timer i brutto-fordelingen, men dognaapent koster 720.
    const varden = [770, 750, 773, 938, 1041, 690, 705, 658, 696, 595, 634, 636]
    const f = fordelAaret({ ar: 2026, rammer: rammer(varden), vinduer: DOGNAAPENT, krav: [], fasteVakter: [] })
    const juni = f.maaneder.find((m) => m.maned === 6)!
    expect(juni.bundne).toBe(720)
    expect(juni.disponible).toBeGreaterThan(720) // gulvet er dekket, pluss litt
    // Aarsrammen holdes — timene er flyttet, ikke skapt.
    expect(f.maaneder.reduce((a, m) => a + m.disponible, 0)).toBeCloseTo(f.pool, 6)
  })

  test('de frie timene folger fortsatt bruttokurven', () => {
    const r = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 200]
    // Gulv 0: ingen vinduer i det hele tatt.
    const f = fordelAaret({ ar: 2026, rammer: rammer(r), vinduer: [], krav: [], fasteVakter: [] })
    const des = f.maaneder.find((m) => m.maned === 12)!
    const jan = f.maaneder.find((m) => m.maned === 1)!
    expect(des.disponible / jan.disponible).toBeCloseTo(2, 6)
  })

  test('flagger aaret som ugjennomforbart naar gulvet sprenger hele rammen', () => {
    // 12 x 720-744 = 8760 timer dognaapent. Ramme paa 5000 holder ikke.
    const f = fordelAaret({
      ar: 2026, rammer: rammer(new Array(12).fill(5000 / 12)),
      vinduer: DOGNAAPENT, krav: [], fasteVakter: [],
    })
    expect(f.gjennomforbar).toBe(false)
    expect(f.sumBundne).toBe(8760)
    expect(Math.round(f.underskudd)).toBe(3760)
  })

  test('faste vakter senker gulvet og frigjor timer til fordeling', () => {
    const rr = rammer(new Array(12).fill(1000))
    const uten = fordelAaret({ ar: 2026, rammer: rr, vinduer: DOGNAAPENT, krav: [], fasteVakter: [] })
    const med = fordelAaret({
      ar: 2026, rammer: rr, vinduer: DOGNAAPENT, krav: [],
      fasteVakter: [1, 2, 3, 4, 5].map((ukedag) => ({ ukedag, fraTime: 7, tilTime: 15 })),
    })
    expect(med.sumBundne).toBeLessThan(uten.sumBundne)
    expect(med.fri).toBeGreaterThan(uten.fri)
    expect(med.pool).toBe(uten.pool) // rammen er den samme
  })
})

// Én stasjon, én ukedag, åpent 06-18 (tolv timer) — langt nok til at en
// femtimersvakt faktisk får plass.
const vindu = (minBemanning = 1, fra = 6, til = 18): Vindu[] => [
  { ukedag: 1, fraTime: fra, tilTime: til, minBemanning },
]
const profil = (verdier: Record<number, number>) =>
  new Map(Object.entries(verdier).map(([t, v]) => [`1:${t}`, v]))

describe('lonnsform paa faste vakter', () => {
  // Robert sin stasjon: butikksjef 08-16 paa fastlonn, NK 05-12 paa timelonn.
  const butikksjef = { ukedag: 1, fraTime: 8, tilTime: 16 }
  const nk = { ukedag: 1, fraTime: 5, tilTime: 12, timelonnet: true }

  test('fastlont vakt koster ingenting, timelont koster hele vakten', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const felles = { ar: 2026, maned: 1, vinduer: vindu(1), krav: [] }
    // Vindu 06-18 = tolv timer. Uten faste vakter: 12 x mandager.
    expect(bundneTimer({ ...felles, fasteVakter: [] })).toBe(12 * mandager)
    // Butikksjefen dekker 08-16 gratis -> fire timer igjen aa betale.
    expect(bundneTimer({ ...felles, fasteVakter: [butikksjef] })).toBe(4 * mandager)
    // NK alene dekker 05-12, men koster sine sju timer. Igjen av vinduet:
    // 12-16 = seks timer gulv. 6 + 7 = 13.
    expect(bundneTimer({ ...felles, fasteVakter: [nk] })).toBe(13 * mandager)
  })

  test('to vakter som overlapper teller som to, ikke som en', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    // Gulv paa to hele vinduet. Mellom 08 og 12 staar begge -> gulvet er
    // dekket der. Foer telte de som en, og planen kalte inn en tredje.
    const b = bundneTimer({
      ar: 2026, maned: 1, vinduer: vindu(2), krav: [], fasteVakter: [butikksjef, nk],
    })
    // 06-07: ingen dekning i vinduet fra butikksjef, NK dekker 1 -> gulv 1 (x2 timer)
    // 08-11: begge -> gulv 0 (x4)   12-15: butikksjef -> gulv 1 (x4)
    // 16-17: ingen -> gulv 2 (x2)   pluss NK sine sju timelonte
    expect(b).toBe((2 * 1 + 4 * 0 + 4 * 1 + 2 * 2 + 7) * mandager)
  })

  test('timelont vakt utenfor det bemannede vinduet betales likevel', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    // Vinduet aapner 06, NK starter 05. Den timen finnes ikke i rutenettet,
    // men den staar paa lonnslippen.
    const uten = bundneTimer({ ar: 2026, maned: 1, vinduer: vindu(1, 6, 12), krav: [], fasteVakter: [] })
    const med = bundneTimer({
      ar: 2026, maned: 1, vinduer: vindu(1, 6, 12), krav: [],
      fasteVakter: [{ ukedag: 1, fraTime: 5, tilTime: 12, timelonnet: true }],
    })
    expect(uten).toBe(6 * mandager)
    // NK dekker hele vinduet -> gulv 0, men koster sju timer inkludert 05.
    expect(med).toBe(7 * mandager)
  })

  test('planleggMaaned og bundneTimer er enige om regningen', () => {
    const p = planleggMaaned({
      disponibleTimer: 10000,
      ar: 2026, maned: 1, vinduer: vindu(1), krav: [],
      fasteVakter: [butikksjef, nk],
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0 }),
    })
    expect(p.bundneTimer).toBe(bundneTimer({
      ar: 2026, maned: 1, vinduer: vindu(1), krav: [], fasteVakter: [butikksjef, nk],
    }))
    // Raden viser begge, og skiller dem.
    const kl9 = p.timer.find((r) => r.time === 9)!
    expect(kl9.fast).toBe(2)
    expect(kl9.fastTimelonnet).toBe(1)
    expect(kl9.gulv).toBe(0)
  })
})

describe('planleggMaaned', () => {
  test('gulvet bindes først, og faste vakter belaster ikke rammen', () => {
    const p = planleggMaaned({
      disponibleTimer: 100,
      ar: 2026, maned: 1,
      vinduer: vindu(1, 6, 10), // kort vindu, saa regnestykket gaar i hodet
      krav: [],
      fasteVakter: [{ ukedag: 1, fraTime: 6, tilTime: 8 }], // dekker 06 og 07
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0 }),
    })
    const mandager = dagerPerUkedag(2026, 1)[1] // 4
    // 06 og 07 dekkes av fast vakt -> gulv 0. 08 og 09 koster 1 person hver.
    expect(p.bundneTimer).toBe(2 * mandager)
    expect(p.timer.find((r) => r.time === 6)?.gulv).toBe(0)
    expect(p.timer.find((r) => r.time === 6)?.fast).toBe(1)
    expect(p.timer.find((r) => r.time === 8)?.gulv).toBe(1)
  })

  test('krav-vindu hever gulvet der butikksjefen har sagt det trengs to', () => {
    const p = planleggMaaned({
      disponibleTimer: 200,
      ar: 2026, maned: 1,
      vinduer: vindu(1, 6, 10),
      krav: [{ ukedag: 1, fraTime: 6, tilTime: 8, antall: 2 }],
      fasteVakter: [],
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0 }),
    })
    expect(p.timer.find((r) => r.time === 6)?.gulv).toBe(2)
    expect(p.timer.find((r) => r.time === 8)?.gulv).toBe(1)
  })

  test('ekstrabemanning kommer som sammenhengende vakter, aldri lose timer', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 12 * mandager + 6 * mandager, // gulv + rom for en vakt
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [], fasteVakter: [],
      // Rush midt paa dagen, dodt i kantene.
      profil: profil({ 6: 1, 7: 2, 8: 3, 9: 30, 10: 40, 11: 45, 12: 50, 13: 40, 14: 20, 15: 5, 16: 2, 17: 1 }),
    })
    const medEkstra = p.timer.filter((r) => r.ekstra > 0).map((r) => r.time).sort((a, b) => a - b)
    expect(medEkstra.length).toBeGreaterThanOrEqual(5)
    // Sammenhengende: ingen hull i blokken.
    for (let i = 1; i < medEkstra.length; i++) {
      expect(medEkstra[i] - medEkstra[i - 1]).toBe(1)
    }
  })

  test('en vakt legges der kundene er, ikke i de dode timene', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 12 * mandager + 5 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [], fasteVakter: [],
      profil: profil({ 6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 11: 1, 12: 60, 13: 60, 14: 60, 15: 60, 16: 60, 17: 1 }),
    })
    const f = (t: number) => p.timer.find((r) => r.time === t)!
    expect(f(12).ekstra).toBe(1)
    expect(f(16).ekstra).toBe(1)
    expect(f(6).ekstra).toBe(0)
  })

  test('for kort vindu gir ingen ekstravakt i det hele tatt', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 4 * mandager + 20 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1, 6, 10), // fire timer - ingen femtimersvakt faar plass
      krav: [], fasteVakter: [],
      profil: profil({ 6: 50, 7: 50, 8: 50, 9: 50 }),
    })
    expect(p.timer.every((r) => r.ekstra === 0)).toBe(true)
    expect(p.brukteTimer).toBe(0)
  })

  test('kortere minstevakt slipper til der vinduet er smalt', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 4 * mandager + 20 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1, 6, 10),
      krav: [], fasteVakter: [],
      profil: profil({ 6: 50, 7: 50, 8: 50, 9: 50 }),
      minVaktTimer: 4,
    })
    expect(p.timer.every((r) => r.ekstra > 0)).toBe(true)
  })

  test('timer uten kunder får aldri ekstra bemanning', () => {
    const p = planleggMaaned({
      disponibleTimer: 10000,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0, 12: 0, 13: 0, 14: 0, 15: 0, 16: 0, 17: 0 }),
    })
    expect(p.timer.every((r) => r.ekstra === 0)).toBe(true)
    expect(p.brukteTimer).toBe(0)
  })

  test('maksBemanning respekteres', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 12 * mandager + 100 * mandager,
      ar: 2026, maned: 1,
      vinduer: vindu(1),
      krav: [],
      fasteVakter: [],
      profil: new Map([...Array(12).keys()].map((i) => [`1:${i + 6}`, 10] as [string, number])),
      maksBemanning: 3,
    })
    expect(Math.max(...p.timer.map((r) => r.sum))).toBe(3)
  })

  test('flagger at planen ikke er gjennomførbar når gulvet er dyrere enn rammen', () => {
    const mandager = dagerPerUkedag(2026, 1)[1]
    const p = planleggMaaned({
      disponibleTimer: 2 * mandager, // gulvet koster 4 timer x mandager
      ar: 2026, maned: 1,
      vinduer: vindu(1, 6, 10),
      krav: [],
      fasteVakter: [],
      profil: profil({ 6: 5, 7: 5, 8: 5, 9: 5 }),
    })
    expect(p.gjennomforbar).toBe(false)
    expect(p.underskudd).toBe(2 * mandager)
  })

  test('bruker aldri mer enn rammen', () => {
    const p = planleggMaaned({
      disponibleTimer: 137,
      ar: 2026, maned: 1,
      vinduer: [{ ukedag: 1, fraTime: 6, tilTime: 22, minBemanning: 1 },
        { ukedag: 6, fraTime: 8, tilTime: 20, minBemanning: 1 }],
      krav: [],
      fasteVakter: [],
      profil: new Map([...Array(24).keys()].flatMap((t) => [
        [`1:${t}`, t * 3] as [string, number],
        [`6:${t}`, t * 5] as [string, number],
      ])),
    })
    expect(p.bundneTimer + p.brukteTimer).toBeLessThanOrEqual(137)
  })
})
