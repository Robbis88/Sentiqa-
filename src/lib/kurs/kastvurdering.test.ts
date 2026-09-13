// P2-motoren målt mot produksjonstallene.
//
// =====================================================================
// TALLENE HER ER FASIT, IKKE KILDE
// =====================================================================
//
// Satsene står i denne fila fordi en test må vite hva den forventer.
// Produksjonskoden leser dem fra `kastbudsjett` via `stasjon_id` og `ar`
// — `hardkodet-sats.test.ts` feller enhver sats som sniker seg inn i
// `src/lib/kurs/*.ts` utenom testene.
//
// Grunnlaget er kontroll 3 og 4, kjørt mot produksjon 2026-09-13, og
// filmålingen med produksjonsparseren over de sju aktive filene.

import { describe, expect, it } from 'vitest'
import {
  gate, kastdom, kasttall, retningErFolsom,
  type Kastmaaned, type Kastsats, type Gateinput,
} from './kastvurdering'
import { retning } from './retning'

const sats = (stasjonId: string, andel: number): Kastsats =>
  ({ stasjonId, aar: 2026, andel, nivaa: 'avdeling' })

const mnd = (maaned: string, salg: number, kast: number | null): Kastmaaned => ({
  maaned, matsalgKr: salg, matkastKr: kast,
  harSvinndata: kast !== null, datastatus: kast !== null ? 'gruppe' : null,
})

const aapen = (over: Partial<Gateinput> = {}): Gateinput => ({
  maaned: mnd('2026-07-01', 400_000, 30_000),
  sats: sats('s1', 0.1),
  avstemt: true, kodemappingSikker: true,
  forbehold: null, serieblokkering: null, stasjonBevist: true,
  ...over,
})

// Målt jan–jul 2026, ett nivå per stasjonsmåned (grunnlagsregelen fra P1).
const DATA: Record<string, { navn: string; andel: number; mnd: [string, number, number][] }> = {
  '4185': { navn: 'Dale', andel: 0.06232289968, mnd: [
    ['2026-01-01', 519573.61, 37861.32], ['2026-02-01', 517322.38, 35076.17],
    ['2026-03-01', 545167.87, 36961.30], ['2026-04-01', 625019.16, 40898.24],
    ['2026-05-01', 644784.51, 37144.00], ['2026-06-01', 724620.49, 32881.44],
    ['2026-07-01', 838292.15, 32018.74]] },
  '4177': { navn: 'Lone', andel: 0.08687747639, mnd: [
    ['2026-01-01', 258865.43, 26716.01], ['2026-02-01', 263172.66, 23385.83],
    ['2026-03-01', 304660.07, 26063.73], ['2026-04-01', 333981.87, 26217.37],
    ['2026-05-01', 409295.17, 31411.79], ['2026-06-01', 394543.29, 28612.31],
    ['2026-07-01', 397162.85, 32730.31]] },
  '9038': { navn: 'Laguneparken', andel: 0.08415231157, mnd: [
    ['2026-01-01', 353850.18, 27403.79], ['2026-02-01', 326675.26, 26660.78],
    ['2026-03-01', 408986.08, 56110.75], ['2026-04-01', 401827.10, 33879.21],
    ['2026-05-01', 560972.08, 27800.77], ['2026-06-01', 488061.16, 30856.76],
    ['2026-07-01', 393158.91, 48717.58]] },
  '9145': { navn: 'Varden', andel: 0.12136504768, mnd: [
    ['2026-01-01', 173236.07, 19573.48], ['2026-02-01', 163947.04, 20957.13],
    ['2026-03-01', 198470.58, 25494.39], ['2026-04-01', 216003.51, 20135.56],
    ['2026-05-01', 251253.54, 22746.66], ['2026-06-01', 210500.75, 22475.90],
    ['2026-07-01', 172471.79, 19116.22]] },
  '9467': { navn: 'Bønes', andel: 0.13592763033, mnd: [
    ['2026-01-01', 128723.75, 20982.97], ['2026-02-01', 129492.82, 22363.96],
    ['2026-03-01', 140532.71, 23840.03], ['2026-04-01', 168575.43, 22312.78],
    ['2026-05-01', 193633.47, 24346.28], ['2026-06-01', 165075.54, 27301.36],
    ['2026-07-01', 135687.17, 26229.84]] },
}

const serieFor = (bn: string) =>
  DATA[bn].mnd.map(([m, s, k]) => kasttall(mnd(m, s, k), sats(bn, DATA[bn].andel)))

// =====================================================================
describe('Dale juli — obligatorisk kanarifugl', () => {
  const juli = serieFor('4185')[6]

  it('matomsetning 838 292,15', () => expect(juli.matsalgKr).toBeCloseTo(838292.15, 2))
  it('synlig kast 32 018,74', () => expect(juli.synligKastKr).toBeCloseTo(32018.74, 2))
  it('kastprosent 3,8195 %', () => expect(juli.faktiskPst).toBeCloseTo(3.8195, 4))
  it('justert budsjett 52 244,80', () => expect(juli.justertBudsjettKr).toBeCloseTo(52244.80, 2))
  it('avvik −20 226,06', () => expect(juli.avvikKr).toBeCloseTo(-20226.06, 2))
  it('gunstig', () => expect(juli.gunstig).toBe(true))

  const dom = kastdom(serieFor('4185'))
  it('retning ned', () => expect(dom.kurs?.vei).toBe('ned'))
  it('INGEN matkast-tiltak', () => expect(dom.slag).not.toBe('tiltak'))
  it('bekreftelse, ikke observer', () => expect(dom.slag).toBe('bekreftelse'))

  it('KANARI: kronene alene gir et svakere signal', () => {
    // Kastkronene faller bare 4 657 over sju måneder. Prosenten faller
    // 3,41 pp, og det gunstige avviket er 20 226 kroner i juli alene.
    const kroner = DATA['4185'].mnd.map(([, , k]) => k)
    expect(Math.abs(retning(kroner)!.endring)).toBeLessThan(5_000)
    expect(Math.abs(dom.naa.avvikKr)).toBeGreaterThan(20_000)
  })
})

// =====================================================================
describe('Varden 9145 — gunstig i juli', () => {
  const juli = serieFor('9145')[6]

  it('kastprosent 11,0837 %', () => expect(juli.faktiskPst).toBeCloseTo(11.0837, 4))
  it('budsjett 12,136504768 %', () => expect(juli.budsjettPst).toBeCloseTo(12.136504768, 9))
  it('avvik −1,0528 pp', () => expect(juli.avvikPstpoeng).toBeCloseTo(-1.0528, 4))
  it('gunstig', () => expect(juli.gunstig).toBe(true))

  it('ingen tiltak — den ligger under budsjett', () => {
    expect(kastdom(serieFor('9145')).slag).not.toBe('tiltak')
  })

  it('KANARI: med Bønes-satsen ville Varden vært ugunstig', () => {
    // Nøyaktig feilen som ble gjort. Satsen er 13,59 mot 12,14, og
    // dommen snur.
    const feil = kasttall(mnd('2026-07-01', 172471.79, 19116.22), sats('9145', 0.13592763033))
    expect(feil.gunstig).toBe(true)
    // Under BEGGE satsene her, men avviket er et helt annet tall.
    expect(feil.avvikPstpoeng).not.toBeCloseTo(juli.avvikPstpoeng, 2)
  })
})

// =====================================================================
describe('Bønes 9467 — første tiltak', () => {
  const serie = serieFor('9467')
  const juli = serie[6]
  const dom = kastdom(serie)

  it('kastprosent 19,3311 %', () => expect(juli.faktiskPst).toBeCloseTo(19.3311, 4))
  it('budsjett 13,592763033 %', () => expect(juli.budsjettPst).toBeCloseTo(13.592763033, 9))
  it('avvik +5,7383 pp', () => expect(juli.avvikPstpoeng).toBeCloseTo(5.7383, 4))
  it('ugunstig', () => expect(juli.gunstig).toBe(false))
  it('TILTAK', () => expect(dom.slag).toBe('tiltak'))
  it('ugunstig 5 av 7 måneder', () => expect(dom.ugunstige).toBe(5))

  it('trendklassifiseringen ER følsom', () => {
    expect(retningErFolsom(serie.map((k) => k.faktiskPst))).toBe(true)
  })

  it('teksten påstår ikke at kastet øker', () => {
    expect(dom.tekst).toContain('ingen stabil forbedring')
    expect(dom.tekst).not.toContain('feil vei')
    expect(dom.tekst).not.toContain('øker')
  })

  it('teksten bærer nivået, som er det tiltaket hviler på', () => {
    expect(dom.tekst).toContain('over kastbudsjettet')
    expect(dom.tekst).toContain('+5,74 pp')
    expect(dom.tekst).toContain('5 av 7')
  })

  it('KANARI: en stabil serie får en retning i teksten', () => {
    // Beviset på at «ingen stabil forbedring» ikke er standardsvaret.
    expect(kastdom(serieFor('4185')).tekst).toContain('kastprosenten faller')
    expect(retningErFolsom(serieFor('4185').map((k) => k.faktiskPst))).toBe(false)
  })
})

// =====================================================================
describe('nivået avgjør, ikke retningen', () => {
  it('over budsjett med FALLENDE trend gir likevel tiltak', () => {
    const s = [30, 25, 22, 20].map((p, i) =>
      kasttall(mnd(`2026-0${i + 1}-01`, 100_000, p * 1_000), sats('x', 0.15)))
    const d = kastdom(s)
    expect(d.kurs?.vei).toBe('ned')
    expect(d.naa.avvikPstpoeng).toBeGreaterThan(0)
    expect(d.slag).toBe('tiltak')
    expect(d.tekst).toContain('men det går riktig vei')
  })

  it('under budsjett med STIGENDE trend gir observer, ikke tiltak', () => {
    const s = [5, 7, 9, 11].map((p, i) =>
      kasttall(mnd(`2026-0${i + 1}-01`, 100_000, p * 1_000), sats('x', 0.15)))
    const d = kastdom(s)
    expect(d.kurs?.vei).toBe('opp')
    expect(d.naa.gunstig).toBe(true)
    expect(d.slag).toBe('observer')
    expect(d.tekst).toContain('Ikke et tiltak ennå')
  })

  it('under budsjett med fallende trend gir bekreftelse', () => {
    const s = [12, 10, 8, 6].map((p, i) =>
      kasttall(mnd(`2026-0${i + 1}-01`, 100_000, p * 1_000), sats('x', 0.15)))
    expect(kastdom(s).slag).toBe('bekreftelse')
  })

  it('eksakt på budsjett er ikke et avvik', () => {
    const k = kasttall(mnd('2026-07-01', 100_000, 15_000), sats('x', 0.15))
    expect(k.avvikKr).toBeCloseTo(0, 6)
    expect(k.gunstig).toBe(true)
  })
})

// =====================================================================
describe('confidence gate — ni porter', () => {
  it('åpen når alt er på plass', () => {
    expect(gate(aapen()).kanKonkludere).toBe(true)
  })

  const tilfeller: [string, Partial<Gateinput>, string, string][] = [
    ['1 matomsetning', { maaned: mnd('2026-07-01', 0, 30_000) }, 'matomsetning', 'Matomsetning mangler'],
    ['2 kast', { maaned: mnd('2026-07-01', 400_000, null) }, 'kast', 'Kasttall mangler'],
    ['3 budsjettsats', { sats: null }, 'budsjettsats', 'Kastbudsjett er ikke lastet opp'],
    ['4 avstemming', { avstemt: false }, 'avstemming', 'ikke avstemt'],
    ['5 datastatus', { maaned: { ...mnd('2026-07-01', 400_000, 30_000), datastatus: 'eldre_grunnlag' } }, 'datastatus', 'Eldre datagrunnlag'],
    ['6 kodemapping', { kodemappingSikker: false }, 'kodemapping', 'Kodemappingen'],
    ['7 forbehold', { forbehold: 'Usikkert tall. Pantfeil juni.' }, 'forbehold', 'Pantfeil juni'],
    ['8 hull', { serieblokkering: 'Hull i serien: 2026-03-01 mangler svinngrunnlag.' }, 'hull', 'Hull i serien'],
    ['9 stasjonsidentitet', { stasjonBevist: false }, 'stasjonsidentitet', 'Stasjonsidentiteten'],
  ]

  it.each(tilfeller)('port %s blokkerer med årsak', (_navn, over, port, tekst) => {
    const g = gate(aapen(over))
    expect(g.kanKonkludere).toBe(false)
    if (g.kanKonkludere) return
    expect(g.port).toBe(port)
    expect(g.aarsak).toContain(tekst)
  })

  it('0 kast MED grunnlag slipper gjennom — det er null kroner', () => {
    const g = gate(aapen({ maaned: mnd('2026-07-01', 400_000, 0) }))
    expect(g.kanKonkludere).toBe(true)
  })

  it('KANARI: 0 kast UTEN grunnlag blokkeres', () => {
    // Desember 2025. Forskjellen mellom de to er hele poenget.
    const desember: Kastmaaned = {
      maaned: '2025-12-01', matsalgKr: 511_258, matkastKr: null,
      harSvinndata: false, datastatus: null,
    }
    const g = gate(aapen({ maaned: desember }))
    expect(g.kanKonkludere).toBe(false)
    if (!g.kanKonkludere) expect(g.port).toBe('kast')
  })

  it('alle ni portene er dekket av en test', () => {
    expect(new Set(tilfeller.map(([, , p]) => p)).size).toBe(9)
  })
})

// =====================================================================
describe('alle fem stasjoner, januar–juli', () => {
  const forventet: Record<string, { slag: string; ugunstige: number }> = {
    '4185': { slag: 'bekreftelse', ugunstige: 4 },
    '4177': { slag: 'bekreftelse', ugunstige: 2 },
    '9038': { slag: 'tiltak', ugunstige: 3 },
    '9145': { slag: 'bekreftelse', ugunstige: 2 },
    '9467': { slag: 'tiltak', ugunstige: 5 },
  }

  it.each(Object.keys(DATA))('%s får riktig dom', (bn) => {
    const d = kastdom(serieFor(bn))
    expect(d.slag).toBe(forventet[bn].slag)
    expect(d.ugunstige).toBe(forventet[bn].ugunstige)
    expect(d.antallMaaneder).toBe(7)
  })

  it('Bønes ligger først, Laguneparken nest — etter avvik, ikke kroner', () => {
    const rangert = Object.keys(DATA)
      .map((bn) => ({ bn, d: kastdom(serieFor(bn)) }))
      .filter((x) => x.d.slag === 'tiltak')
      .sort((a, b) => b.d.naa.avvikPstpoeng - a.d.naa.avvikPstpoeng)
    expect(rangert.map((x) => x.bn)).toEqual(['9467', '9038'])
  })

  it('KANARI: kronemodellen ville rangert Laguneparken og Lone først', () => {
    // Dagens motor sorterer på kronebevegelse. Lone er ikke engang et
    // tiltak i P2 — den ligger under budsjett fem av sju måneder.
    const perKroner = Object.entries(DATA)
      .map(([bn, d]) => ({ bn, endring: retning(d.mnd.map(([, , k]) => k))!.endring }))
      .sort((a, b) => b.endring - a.endring)
      .map((x) => x.bn)
    expect(perKroner.slice(0, 2)).toEqual(['9038', '4177'])
    expect(kastdom(serieFor('4177')).slag).toBe('bekreftelse')
  })
})
