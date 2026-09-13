// P2 gjennom `byggMaanedsplan`, ikke bare gjennom `kastdom`.
//
// =====================================================================
// MOTEKSEMPELET SOM FELTE FØRSTE INTEGRASJON
// =====================================================================
//
// Første utgave lot `matkast.dom` bare FILTRERE bort matkast når slaget
// ikke var tiltak. Den generiske løypa — `serieFor → erIlle/erBra →
// kronerIAret` — bestemte fortsatt om matkast i det hele tatt ble
// vurdert, og den måler kastKRONER.
//
// Målt 2026-09-13, en stasjon 1,0 prosentpoeng over kastbudsjettet hver
// eneste måned, med fallende kroner:
//
//     dom: medvind
//     punkter: [{ matkast, bekreftelse, «Riktig vei 4 måneder på rad.
//                 Nå på 28 000 kroner.» }]
//
// Over budsjett hele veien, presentert som en bekreftelse. Nivået
// avgjør nå, og matkast går ikke gjennom kroneløypa i det hele tatt.

import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { byggMaanedsplan, type Maanedstall, type Maanedsdata } from './plan'

const sats = (andel: number, stasjonId = 's1', aar = 2026) =>
  ({ stasjonId, aar, andel, nivaa: 'avdeling' })

function mnd(over: Partial<Maanedstall> & { maaned: string }): Maanedstall {
  return {
    omsetningKr: 1_000_000, omsetningBudsjettKr: 1_000_000, bruttoKr: 500_000,
    matsalgKr: 400_000, matkastKr: 30_000,
    usynligRestKr: 5_000, usynligMatKr: 4_000,
    avvikAntall: 0, matRader: 9,
    harSvinndata: true, datastatus: 'gruppe',
    personalKr: 300_000, personalBudsjettKr: 300_000,
    paavirkbarDriftKr: 40_000, paavirkbarDriftBudsjettKr: 40_000,
    resultatKr: 50_000,
    ...over,
  }
}

function plan(over: Partial<Maanedsdata> & { historikk: Maanedstall[] }) {
  return byggMaanedsplan({
    stasjonNavn: 'Testeriet', stasjonId: 's1', butikknummer: '4185',
    leverandorer: [], satser: null, kastsats: sats(0.06), forbehold: null,
    ...over,
  })
}

const matkastpunkt = (p: ReturnType<typeof plan>) =>
  p.punkter.filter((x) => x.loftestang === 'matkast')

// =====================================================================
describe('over budsjett + fallende kroner → fortsatt tiltak', () => {
  // 10 % → 7 %, mot 6 % budsjettert. Over hele veien, men synkende.
  // MEDVIND i resultatet, så planen ville gjerne gitt en bekreftelse.
  const serie = [40, 36, 32, 30, 28].map((k, i) => mnd({
    maaned: `2026-0${i + 1}-01`, matkastKr: k * 1_000,
    resultatKr: 50_000 + i * 20_000,
  }))
  const p = plan({ historikk: serie })

  it('planen er i medvind', () => expect(p.dom).toBe('medvind'))

  it('dommen sier tiltak', () => {
    expect(p.matkast.dom?.slag).toBe('tiltak')
    expect(p.matkast.dom?.naa.avvikPstpoeng).toBeGreaterThan(0)
  })

  it('OG matkast er faktisk et tiltak i punktene', () => {
    expect(matkastpunkt(p).map((x) => x.slag)).toEqual(['tiltak'])
  })

  it('det finnes INGEN matkastbekreftelse', () => {
    expect(matkastpunkt(p).some((x) => x.slag === 'bekreftelse')).toBe(false)
  })

  it('teksten kommer fra dommen, ikke fra kronetrenden', () => {
    const tekst = matkastpunkt(p)[0].tekst
    expect(tekst).toBe(p.matkast.dom!.tekst)
    expect(tekst).toContain('over kastbudsjettet')
    expect(tekst).toContain('men det går riktig vei')
    // Den gamle setningen skal være borte.
    expect(tekst).not.toContain('Riktig vei 4 måneder på rad')
    expect(tekst).not.toMatch(/Nå på .* kroner/)
  })
})

// =====================================================================
describe('under budsjett + stigende prosent → observer', () => {
  // 3 % → 5,5 %, mot 6 %. Under hele veien, men på vei opp.
  const serie = [12, 14, 17, 20, 22].map((k, i) => mnd({
    maaned: `2026-0${i + 1}-01`, matkastKr: k * 1_000,
    resultatKr: 90_000 - i * 25_000,   // MOTVIND
  }))
  const p = plan({ historikk: serie })

  it('dommen sier observer', () => {
    expect(p.matkast.dom?.slag).toBe('observer')
    expect(p.matkast.dom?.naa.gunstig).toBe(true)
    expect(p.matkast.dom?.kurs?.vei).toBe('opp')
  })

  it('ALDRI tiltak', () => {
    expect(matkastpunkt(p).some((x) => x.slag === 'tiltak')).toBe(false)
  })

  it('og ALDRI bekreftelse — den er på vei mot budsjettet', () => {
    expect(matkastpunkt(p).some((x) => x.slag === 'bekreftelse')).toBe(false)
    expect(matkastpunkt(p)).toEqual([])
  })

  it('KANARI: kroneløypa ville kalt dette et tiltak', () => {
    // Kastkronene stiger fra 12 000 til 22 000. Den gamle motoren så
    // bare det, og ville gitt et tiltak til en stasjon under budsjett.
    const kroner = serie.map((m) => m.matkastKr as number)
    expect(kroner[kroner.length - 1]).toBeGreaterThan(kroner[0])
    expect(p.matkast.dom?.slag).not.toBe('tiltak')
  })
})

// =====================================================================
describe('blokkert gate → ingen matkast i punktene', () => {
  const grunn = [1, 2, 3, 4].map((i) => mnd({
    maaned: `2026-0${i}-01`, matkastKr: 40_000, resultatKr: 90_000 - i * 25_000,
  }))

  const tilfeller: [string, Partial<Maanedsdata>, Maanedstall[], string][] = [
    ['sats mangler', { kastsats: null }, grunn, 'Kastbudsjett er ikke lastet opp'],
    ['forbehold gjelder', { forbehold: 'Usikkert tall. Pantfeil i juni.' }, grunn, 'Pantfeil i juni'],
    ['satsen hører til en annen stasjon', { kastsats: sats(0.06, 'en-annen') }, grunn, 'Stasjonsidentiteten'],
    ['satsen er for et annet år', { kastsats: sats(0.06, 's1', 2025) }, grunn, 'Stasjonsidentiteten'],
    ['stasjonen mangler butikknummer', { butikknummer: null }, grunn, 'Stasjonsidentiteten'],
    ['svinnarket er ikke avstemt', {}, grunn.map((m, i) =>
      i === grunn.length - 1 ? { ...m, avvikAntall: 3 } : m), 'ikke avstemt'],
    ['avviksantallet er ikke målt', {}, grunn.map((m, i) =>
      i === grunn.length - 1 ? { ...m, avvikAntall: null } : m), 'ikke avstemt'],
    ['ingen matrader — kodemappingen', {}, grunn.map((m, i) =>
      i === grunn.length - 1 ? { ...m, matRader: 0 } : m), 'Kodemappingen'],
    ['matradene er ikke målt', {}, grunn.map((m, i) =>
      i === grunn.length - 1 ? { ...m, matRader: null } : m), 'Kodemappingen'],
    ['eldre datagrunnlag', {}, grunn.map((m, i) =>
      i === grunn.length - 1 ? { ...m, datastatus: 'eldre_grunnlag' } : m), 'Eldre datagrunnlag'],
    ['hull i serien', {}, grunn.map((m, i) =>
      i === 1 ? { ...m, harSvinndata: false, matkastKr: null, usynligMatKr: null } : m), 'Hull i serien'],
  ]

  it.each(tilfeller)('%s → ingen matkastpunkt, og årsaken sies', (_navn, over, historikk, tekst) => {
    const p = plan({ ...over, historikk })
    expect(p.matkast.dom).toBeNull()
    expect(p.matkast.blokkering).toContain('Datagrunnlag mangler')
    expect(p.matkast.blokkering).toContain(tekst)
    expect(matkastpunkt(p)).toEqual([])
  })

  it('KANARI: uten blokkering konkluderer den samme serien', () => {
    const p = plan({ historikk: grunn })
    expect(p.matkast.dom?.slag).toBe('tiltak')
    expect(matkastpunkt(p)).toHaveLength(1)
  })

  it('en ubevist port feiler LUKKET, ikke åpent', () => {
    // Ingen `?? true`. Er avvikAntall eller matRader `null`, er de ikke
    // maalt — og en umaalt kontroll er ikke en bestaatt kontroll.
    const kilde = plan({ historikk: grunn })
    expect(kilde.matkast.dom).not.toBeNull()
    for (const felt of ['avvikAntall', 'matRader'] as const) {
      const p = plan({
        historikk: grunn.map((m, i) =>
          i === grunn.length - 1 ? { ...m, [felt]: null } : m),
      })
      expect(p.matkast.dom, `${felt} = null skal blokkere`).toBeNull()
    }
  })
})

// =====================================================================
describe('matkast kan ikke maales i kroner igjen', () => {
  it('planen bygges uten aa kalle serieFor for matkast', () => {
    // Ville loekka kalt den, hadde `serieFor` kastet - og hele planen
    // med den. At planen finnes, er beviset paa at matkast er ute av
    // kroneloypa.
    const p = plan({
      historikk: [1, 2, 3, 4].map((i) => mnd({
        maaned: `2026-0${i}-01`, matkastKr: 40_000, resultatKr: 50_000,
      })),
    })
    expect(p.matkast.dom?.slag).toBe('tiltak')
  })

  it('KANARI: serieFor(matkast) kaster om noen kaller den', () => {
    // En kommentar som sier «matkast gaar ikke gjennom kroneloypa» er
    // sann helt til noen fjerner `continue`-en. Denne er ikke det.
    const kilde = readFileSync(
      join(process.cwd(), 'src/lib/kurs/plan.ts'), 'utf8')
    expect(kilde).toContain("case 'matkast':")
    const i = kilde.indexOf("case 'matkast':")
    expect(kilde.slice(i, i + 200)).toContain('throw new Error')
    // Og loekka hopper faktisk over den.
    expect(kilde).toContain("if (l.id === 'matkast') continue")
  })
})

// =====================================================================
describe('portene gjelder HELE serien, ikke bare siste maaned', () => {
  // Sju maaneder. Dommen regner trend over alle sju og teller «over
  // budsjett X av 7» over alle sju - saa en maaned MIDT I som ikke er
  // portet, er med i baade retningen og tellingen uten aa bli sett.
  const sju = [1, 2, 3, 4, 5, 6, 7].map((i) => mnd({
    maaned: `2026-0${i}-01`, matkastKr: 40_000, resultatKr: 50_000,
  }))
  const midt = 3   // april, midt i serien

  const medEndring = (i: number, over: Partial<Maanedstall>) =>
    sju.map((m, j) => (j === i ? { ...m, ...over } : m))

  const midtItilfeller: [string, Partial<Maanedstall>, string][] = [
    ['avvik i svinnarket', { avvikAntall: 2 }, 'ikke avstemt'],
    ['avviksantallet ikke maalt', { avvikAntall: null }, 'ikke avstemt'],
    ['matgruppen ikke funnet', { matRader: 0 }, 'Kodemappingen'],
    ['matradene ikke maalt', { matRader: null }, 'Kodemappingen'],
    ['eldre datagrunnlag', { datastatus: 'eldre_grunnlag' }, 'Eldre datagrunnlag'],
    ['matomsetning mangler', { matsalgKr: 0 }, 'Matomsetning mangler'],
  ]

  it.each(midtItilfeller)('%s i april blokkerer hele dommen', (_navn, over, tekst) => {
    const p = plan({ historikk: medEndring(midt, over) })
    expect(p.matkast.dom).toBeNull()
    expect(p.matkast.blokkering).toContain(tekst)
    // AARSAKEN NAVNGIR MAANEDEN. «Datagrunnlag mangler» uten aa si
    // hvilken maaned er ikke til aa handle paa.
    expect(p.matkast.blokkering).toContain('2026-04-01')
    expect(matkastpunkt(p)).toEqual([])
  })

  it.each(midtItilfeller)('%s i JULI blokkerer ogsaa', (_navn, over, tekst) => {
    const p = plan({ historikk: medEndring(6, over) })
    expect(p.matkast.dom).toBeNull()
    expect(p.matkast.blokkering).toContain(tekst)
  })

  it('KANARI: uten feilen i april konkluderer den samme serien paa sju maaneder', () => {
    const p = plan({ historikk: sju })
    expect(p.matkast.dom?.slag).toBe('tiltak')
    expect(p.matkast.dom?.antallMaaneder).toBe(7)
    expect(p.matkast.dom?.ugunstige).toBe(7)
  })

  it('en umaalt maaned midt i endrer BAADE trend og telling om den slipper gjennom', () => {
    // Beviset paa at porten paa siste maaned alene ikke rekker: en
    // maaned med et helt annet kasttall flytter retningen.
    const utenPort = plan({ historikk: medEndring(midt, { matkastKr: 5_000 }) })
    const ren = plan({ historikk: sju })
    expect(utenPort.matkast.dom?.ugunstige).not.toBe(ren.matkast.dom?.ugunstige)
  })
})

// =====================================================================
describe('de fem stasjonene gjennom hele planen', () => {
  // Målt jan–jul 2026, ett nivå per stasjonsmåned. Satsene fra
  // `kastbudsjett`, kontroll 3 mot produksjon 13.09.
  const STASJON: Record<string, { navn: string; andel: number; rader: [string, number, number][] }> = {
    '4185': { navn: 'Dale', andel: 0.06232289968, rader: [
      ['2026-01-01', 519573.61, 37861.32], ['2026-02-01', 517322.38, 35076.17],
      ['2026-03-01', 545167.87, 36961.30], ['2026-04-01', 625019.16, 40898.24],
      ['2026-05-01', 644784.51, 37144.00], ['2026-06-01', 724620.49, 32881.44],
      ['2026-07-01', 838292.15, 32018.74]] },
    '9467': { navn: 'Bønes', andel: 0.13592763033, rader: [
      ['2026-01-01', 128723.75, 20982.97], ['2026-02-01', 129492.82, 22363.96],
      ['2026-03-01', 140532.71, 23840.03], ['2026-04-01', 168575.43, 22312.78],
      ['2026-05-01', 193633.47, 24346.28], ['2026-06-01', 165075.54, 27301.36],
      ['2026-07-01', 135687.17, 26229.84]] },
    '9145': { navn: 'Varden', andel: 0.12136504768, rader: [
      ['2026-01-01', 173236.07, 19573.48], ['2026-02-01', 163947.04, 20957.13],
      ['2026-03-01', 198470.58, 25494.39], ['2026-04-01', 216003.51, 20135.56],
      ['2026-05-01', 251253.54, 22746.66], ['2026-06-01', 210500.75, 22475.90],
      ['2026-07-01', 172471.79, 19116.22]] },
    '4177': { navn: 'Lone', andel: 0.08687747639, rader: [
      ['2026-01-01', 258865.43, 26716.01], ['2026-02-01', 263172.66, 23385.83],
      ['2026-03-01', 304660.07, 26063.73], ['2026-04-01', 333981.87, 26217.37],
      ['2026-05-01', 409295.17, 31411.79], ['2026-06-01', 394543.29, 28612.31],
      ['2026-07-01', 397162.85, 32730.31]] },
    '9038': { navn: 'Laguneparken', andel: 0.08415231157, rader: [
      ['2026-01-01', 353850.18, 27403.79], ['2026-02-01', 326675.26, 26660.78],
      ['2026-03-01', 408986.08, 56110.75], ['2026-04-01', 401827.10, 33879.21],
      ['2026-05-01', 560972.08, 27800.77], ['2026-06-01', 488061.16, 30856.76],
      ['2026-07-01', 393158.91, 48717.58]] },
  }

  const planFor = (bn: string) => {
    const s = STASJON[bn]
    return plan({
      stasjonNavn: s.navn, stasjonId: `id-${bn}`, butikknummer: bn,
      kastsats: sats(s.andel, `id-${bn}`),
      historikk: s.rader.map(([m, salg, kast]) => mnd({
        maaned: m, matsalgKr: salg, matkastKr: kast,
        // Resultatet holdes flatt, saa utvalget ikke maskerer matkast.
        resultatKr: 50_000,
      })),
    })
  }

  const fasit: Record<string, { slag: string; punkt: string | null }> = {
    '4185': { slag: 'bekreftelse', punkt: null },
    '9467': { slag: 'tiltak', punkt: 'tiltak' },
    '9145': { slag: 'bekreftelse', punkt: null },
    '4177': { slag: 'bekreftelse', punkt: null },
    '9038': { slag: 'tiltak', punkt: 'tiltak' },
  }

  it.each(Object.keys(STASJON))('%s får riktig dom og riktig punkt', (bn) => {
    const p = planFor(bn)
    expect(p.matkast.dom?.slag).toBe(fasit[bn].slag)
    const punkt = matkastpunkt(p)
    if (fasit[bn].punkt === null) {
      // Flat plan gir ingen bekreftelse — flatt er ikke ros.
      expect(punkt.every((x) => x.slag !== 'tiltak')).toBe(true)
    } else {
      expect(punkt.map((x) => x.slag)).toContain(fasit[bn].punkt)
    }
  })

  it('Bønes får tiltaket, med budsjettavviket som forklaring', () => {
    const p = planFor('9467')
    const punkt = matkastpunkt(p)[0]
    expect(punkt.slag).toBe('tiltak')
    expect(punkt.tekst).toContain('over kastbudsjettet')
    expect(punkt.tekst).toContain('19,33 %')
    expect(punkt.tekst).toContain('13,59 %')
    expect(punkt.tekst).toContain('+5,74 pp')
    expect(punkt.tekst).toContain('ingen stabil forbedring')
    // KANARI: ingen doblet bindeord. «og og det staar stille» sto i
    // Laguneparkens tekst foerste gang hele kjeden ble skrevet ut.
    expect(punkt.tekst).not.toMatch(/og og/)
    // Ikke en påstand dataene ikke bærer.
    expect(punkt.tekst).not.toContain('feil vei')
  })

  it('ingen tekst har et doblet bindeord', () => {
    for (const bn of Object.keys(STASJON)) {
      const d = planFor(bn).matkast.dom
      expect(d!.tekst, `${bn}: ${d!.tekst}`).not.toMatch(/(og og|men men)/)
    }
  })

  it('Dale er en bekreftelse, ikke et tiltak', () => {
    const p = planFor('4185')
    expect(p.matkast.dom?.slag).toBe('bekreftelse')
    expect(matkastpunkt(p).some((x) => x.slag === 'tiltak')).toBe(false)
    expect(p.matkast.dom?.naa.avvikKr).toBeCloseTo(-20226.06, 2)
  })

  it('Lone er en bekreftelse — kronene stiger mest av alle', () => {
    expect(planFor('4177').matkast.dom?.slag).toBe('bekreftelse')
  })

  it('rangert på avvik: Bønes foran Laguneparken', () => {
    const tiltak = Object.keys(STASJON)
      .map((bn) => ({ bn, d: planFor(bn).matkast.dom }))
      .filter((x) => x.d?.slag === 'tiltak')
      .sort((a, b) => b.d!.naa.avvikPstpoeng - a.d!.naa.avvikPstpoeng)
    expect(tiltak.map((x) => x.bn)).toEqual(['9467', '9038'])
  })
})

// =====================================================================
describe('usynlig matsvinn er MATgruppen', () => {
  const serie = (verdier: (number | null)[]) => verdier.map((u, i) => mnd({
    maaned: `2026-0${i + 1}-01`,
    usynligMatKr: u, usynligRestKr: -99_999,   // rest skal ALDRI brukes
    harSvinndata: u !== null,
    matkastKr: u === null ? null : 30_000,
  }))

  it('leser usynligMatKr, ikke usynligRestKr', () => {
    const p = plan({ historikk: serie([5_000, 6_000, 7_000, 8_000]) })
    expect(p.usynlig.naaKr).toBe(8_000)
    expect(p.usynlig.naaKr).not.toBe(-99_999)
  })

  it('Dale juli gir 31 902,47 fra matgruppen', () => {
    const p = plan({ historikk: serie([20_000, 22_000, 25_000, 31_902.47]) })
    expect(p.usynlig.naaKr).toBeCloseTo(31902.47, 2)
  })

  it('fortegnet beholdes', () => {
    const p = plan({ historikk: serie([1_000, 2_000, 3_000, -4_200]) })
    expect(p.usynlig.naaKr).toBe(-4_200)
  })

  it('et fortegnsskifte i siste måned blokkerer retningen', () => {
    const p = plan({ historikk: serie([1_000, 2_000, 3_000, -4_200]) })
    expect(p.usynlig.usikker).toBe(true)
    expect(p.usynlig.aarsakUsikker).toContain('Fortegnet skifter')
    expect(p.usynlig.aarsakUsikker).toContain('Usikker enkeltmåling')
    expect(p.usynlig.aarsakUsikker).toContain('periodisering')
    expect(p.usynlig.kurs).toBeNull()
    expect(p.usynlig.vindu).toBe(0)
    // Verdien vises likevel, MED fortegn.
    expect(p.usynlig.naaKr).toBe(-4_200)
  })

  it('én positiv måned etter tre negative er ikke en trend', () => {
    const p = plan({ historikk: serie([-1_000, -2_000, -3_000, 4_000]) })
    expect(p.usynlig.usikker).toBe(true)
    expect(p.usynlig.aarsakUsikker).toContain('Fortegnet skifter')
    expect(p.usynlig.kurs).toBeNull()
  })

  it('KANARI: en ren, positiv serie får en retning paa vinduet', () => {
    const p = plan({ historikk: serie([8_000, 7_000, 6_000, 5_000]) })
    expect(p.usynlig.usikker).toBe(false)
    expect(p.usynlig.kurs?.vei).toBe('ned')
    expect(p.usynlig.vindu).toBe(3)
  })

  it('tre sammenhengende negative gir retning, men ingen gevinst', () => {
    // Fortegnet er konsistent, saa regelen slipper den gjennom. At et
    // overskudd ikke er en gevinst er en TEKST-regel, ikke en
    // retningsregel - se `usynligtekst` i plankortet.
    const p = plan({ historikk: serie([-1_000, -2_000, -3_000, -4_000]) })
    expect(p.usynlig.usikker).toBe(false)
    expect(p.usynlig.naaKr).toBe(-4_000)
    expect(p.usynlig.vindu).toBe(3)
  })

  it('svinnrader UTEN matrader: blokkert, ikke 0', () => {
    // Den falske nullen. `har_svinndata` er true, saa serien er hel -
    // men matgruppen ble ikke funnet, og `coalesce(..., 0)` i SQL ga
    // 0 kroner usynlig mat. `0215` gjoer den til NULL, og analysen
    // spoer `matRader` i tillegg.
    const p = plan({
      historikk: [1, 2, 3, 4].map((i) => mnd({
        maaned: `2026-0${i}-01`,
        usynligMatKr: 0, matRader: 0, harSvinndata: true,
      })),
    })
    expect(p.usynlig.naaKr).toBeNull()
    expect(p.usynlig.blokkering).toContain('Matgruppen ble ikke funnet')
    expect(p.usynlig.blokkering).toContain('2026-01-01')
  })

  it('matrader mangler i én maaned midt i: blokkert', () => {
    const p = plan({
      historikk: [1, 2, 3, 4].map((i) => mnd({
        maaned: `2026-0${i}-01`, usynligMatKr: 5_000,
        ...(i === 2 ? { matRader: 0, usynligMatKr: 0 } : {}),
      })),
    })
    expect(p.usynlig.naaKr).toBeNull()
    expect(p.usynlig.blokkering).toContain('2026-02-01')
  })

  it('KANARI: med matrader i alle maanedene konkluderer den', () => {
    const p = plan({
      historikk: [1, 2, 3, 4].map((i) => mnd({
        maaned: `2026-0${i}-01`, usynligMatKr: 5_000, matRader: 9,
      })),
    })
    expect(p.usynlig.naaKr).toBe(5_000)
    expect(p.usynlig.blokkering).toBeNull()
  })

  it('uten svinngrunnlag: blokkert, ikke 0', () => {
    const p = plan({ historikk: serie([5_000, 6_000, null, 8_000]) })
    expect(p.usynlig.naaKr).toBeNull()
    expect(p.usynlig.blokkering).toContain('Datagrunnlag mangler')
  })
})
