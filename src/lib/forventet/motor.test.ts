import { describe, expect, it } from 'vitest'
import {
  aggreger, forventetSalg, MODELLER, type Modell, type Salgsrad,
} from './motor'

// =====================================================================
// FORVENTET SALG — DE FIRE MÅTENE MOTOREN KAN LYVE PÅ
// =====================================================================
//
//   1  den ser måldagen (fremtidslekkasje)
//   2  den svarer 0 der den mener «vet ikke»
//   3  den svarer selv om grunnlaget ikke bærer
//   4  et aggregat skjuler at halve varegruppen manglet
//
// Alle fire ser ut som fungerende prognoser.
// =====================================================================

const S = 'stasjon-1'
const E = '5000112636833' // Coca-Cola 0,5L. Produksjonskanarien.

const r = (dato: string, antall: number, ean = E, stasjonId = S): Salgsrad => ({
  stasjonId, ean, dato, antall, varegruppeKode: '1402', varegruppeNavn: 'BRUS MEDIUM',
})

const M: Record<string, Modell> = Object.fromEntries(MODELLER.map((m) => [m.navn, m]))

/** 60 sammenhengende dager fram til og med `til`, `n` stk per dag. */
function serie(til: string, dager: number, n: number, ean = E, stasjonId = S): Salgsrad[] {
  const ut: Salgsrad[] = []
  const d = new Date(`${til}T12:00:00Z`)
  for (let i = 0; i < dager; i++) {
    ut.push(r(d.toISOString().slice(0, 10), n, ean, stasjonId))
    d.setUTCDate(d.getUTCDate() - 1)
  }
  return ut
}

describe('INGEN FREMTIDSLEKKASJE', () => {
  it('kaster maaldagens egne rader, selv naar kallstedet gir dem', () => {
    // Kallstedet kan ikke betros med denne grensen. En backtest som fikk
    // med maaldagen ville sett straalende ut og vaert verdiloes.
    const historikk = serie('2026-09-09', 40, 10)
    const utenD = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: historikk, modell: M.basis, minstDagerMedSalg: 10,
    })
    const medD = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      // Maaldagen med et vilt tall. Ser motoren den, flytter svaret seg.
      salg: [...historikk, r('2026-09-10', 9_999)], modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(medD).toEqual(utenD)
  })

  it('kaster ogsaa dager ETTER maaldagen', () => {
    const h = serie('2026-09-09', 40, 10)
    const a = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: h, modell: M['basis+trend'], minstDagerMedSalg: 10,
    })
    const b = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: [...h, r('2026-09-15', 9_999), r('2026-10-01', 9_999)],
      modell: M['basis+trend'], minstDagerMedSalg: 10,
    })
    expect(b).toEqual(a)
  })

  it('nylig-vinduet utledes av maaldagen, ikke av siste rad', () => {
    // `lagProduksjonsplan` tar `sisteSalgsdato` som ARGUMENT. Gjorde vi
    // det samme, kunne en backtest flyttet vinduet forbi D.
    const h = serie('2026-09-09', 40, 10)
    const svar = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: h, modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(svar.slag).toBe('beregnet')
    if (svar.slag !== 'beregnet') return
    expect(svar.grunnlag.nyligSnitt).toBe(10)
  })

  it('ET HULL FOER MAALDAGEN FLYTTER IKKE VINDUET FRAMOVER', () => {
    // Testen over kan ikke skille de to: historikken slutter noeyaktig
    // dagen foer maaldagen, saa «siste rad» og «maaldagen minus én» er
    // samme dato. Med et hull spriker de.
    //
    // Salg 1.-31. juni 2026, maaldag 10. september. Riktig nylig-vindu
    // (13. aug - 9. sep) er TOMT; foelger vinduet siste rad (4. juni -
    // 1. juli), finner det 31 dager med salg og svarer et tall.
    const h = serie('2026-07-01', 31, 10)
    const svar = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: h, modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(svar.slag, 'vinduet fulgte siste rad — motoren svarte paa gammelt salg').toBe('ikke_dekning')
    if (svar.slag === 'ikke_dekning') {
      expect(svar.grunn).toBe('ingen_basis')
      // Radene FINNES - det er vinduet som er tomt, ikke historikken.
      expect(svar.dagerMedSalg).toBe(31)
    }
  })
})

describe('bevegelige helligdager', () => {
  it('bruker samme helligdagsrolle i fjor, ikke kalenderdato', () => {
    const svar = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-04-02',
      salg: [r('2025-04-17', 40), r('2025-04-03', 5), ...serie('2026-03-30', 10, 10)],
      modell: M.basis, minstDagerMedSalg: 1,
    })
    expect(svar.slag).toBe('beregnet')
    if (svar.slag === 'beregnet') expect(svar.grunnlag.fjorMedian).toBe(40)
  })

  it('fortsetter riktig når neste påske flyttes igjen', () => {
    const svar = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2027-03-25',
      // Skjærtorsdag 2027 mot skjærtorsdag 2026. 26. mars 2026 er en
      // vanlig fredag og skal ikke brukes som helligdagsgrunnlag.
      salg: [r('2026-04-02', 52), r('2026-03-26', 7), ...serie('2027-03-22', 10, 10)],
      modell: M.basis, minstDagerMedSalg: 1,
    })
    expect(svar.slag).toBe('beregnet')
    if (svar.slag === 'beregnet') expect(svar.grunnlag.fjorMedian).toBe(52)
  })
})

describe('IKKE DEKNING ER IKKE NULL', () => {
  it('ingen historikk gir ikke_dekning, ikke 0', () => {
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: [], modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(s.slag).toBe('ikke_dekning')
    if (s.slag === 'ikke_dekning') expect(s.grunn).toBe('ingen_historikk')
  })

  it('for faa salgsdager gir ikke_dekning', () => {
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: serie('2026-09-09', 3, 5), modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(s.slag).toBe('ikke_dekning')
    if (s.slag === 'ikke_dekning') {
      expect(s.grunn).toBe('for_fa_dager')
      expect(s.dagerMedSalg).toBe(3)
    }
  })

  it('RADER MED ANTALL 0 TELLER IKKE SOM SALGSDAGER', () => {
    // Maalt: 206 av 223 708 rader har antall = 0. De finnes, og de er
    // ikke etterspoersel.
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: serie('2026-09-09', 40, 0), modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(s.slag).toBe('ikke_dekning')
    if (s.slag === 'ikke_dekning') expect(s.dagerMedSalg).toBe(0)
  })

  it('en annen stasjons salg teller ikke', () => {
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: serie('2026-09-09', 40, 10, E, 'stasjon-2'),
      modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(s.slag).toBe('ikke_dekning')
  })

  it('en annen EAN teller ikke — heller ikke med samme navn', () => {
    // Fire ulike EAN heter noe med «Coca-Cola uten sukker». De er ikke
    // samme salgsenhet.
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: serie('2026-09-09', 40, 10, '5000112636840'),
      modell: M.basis, minstDagerMedSalg: 10,
    })
    expect(s.slag).toBe('ikke_dekning')
  })
})

describe('modellene er fire, og ingen er utpekt', () => {
  it('alle fire kan kjoeres paa samme grunnlag', () => {
    const h = serie('2026-09-09', 40, 10)
    for (const m of MODELLER) {
      const s = forventetSalg({
        enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
        salg: h, modell: m, minstDagerMedSalg: 10,
      })
      expect(s.slag, m.navn).toBe('beregnet')
      if (s.slag === 'beregnet') expect(s.modell).toBe(m.navn)
    }
  })

  it('trendfaktor er 1 naar modellen ikke bruker trend', () => {
    const h = serie('2026-09-09', 40, 10)
    const s = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: h, modell: M.basis, minstDagerMedSalg: 10,
    })
    if (s.slag !== 'beregnet') throw new Error('ventet beregnet')
    expect(s.grunnlag.trendfaktor).toBe(1)
    expect(s.grunnlag.vaerfaktor).toBe(1)
  })

  it('trenden er PER ENHET, ikke over hele utvalget', () => {
    // `lagProduksjonsplan` regner trenden over alle produkter i planen.
    // Her svarer motoren per enhet, og da maa trenden vaere det ogsaa -
    // ellers er det et annet tall som ligner.
    //
    // DEN FREMMEDE SERIEN MAA LIGGE I FJORVINDUET. Foerste utgave la den
    // i naa-vinduet, der `nylig` alt er filtrert til egne rader - saa en
    // injeksjon som byttet `egne` mot `inn.salg` i FJOR-leddet gikk rett
    // gjennom. Vakta saa ordet, ikke virkningen.
    const maal = '2026-09-10'
    const naa = serie('2026-09-09', 28, 20)
    const fjor = serie('2025-09-10', 28, 10)
    const annen = serie('2025-09-10', 28, 1_000, '9999999999999')
    const utenAnnen = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: maal,
      salg: [...naa, ...fjor], modell: M['basis+trend'], minstDagerMedSalg: 10,
    })
    const medAnnen = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: maal,
      salg: [...naa, ...fjor, ...annen], modell: M['basis+trend'], minstDagerMedSalg: 10,
    })
    expect(medAnnen).toEqual(utenAnnen)
  })

  it('KANARIFUGL — trenden gjoer faktisk noe', () => {
    // Slutter trendleddet aa virke, blir `basis` og `basis+trend` like,
    // og testene over ville fortsatt vaert groenne.
    const maal = '2026-09-10'
    const salg = [...serie('2026-09-09', 28, 20), ...serie('2025-09-10', 28, 10)]
    const u = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: maal, salg,
      modell: M.basis, minstDagerMedSalg: 10,
    })
    const t = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: maal, salg,
      modell: M['basis+trend'], minstDagerMedSalg: 10,
    })
    if (u.slag !== 'beregnet' || t.slag !== 'beregnet') throw new Error('ventet beregnet')
    expect(t.grunnlag.trendfaktor).toBeGreaterThan(1)
    expect(t.antall).not.toBe(u.antall)
  })
})

describe('AGGREGATET SKJULER IKKE EN MANGEL', () => {
  it('teller med og uten dekning hver for seg', () => {
    const b = forventetSalg({
      enhet: { stasjonId: S, ean: E }, maalDato: '2026-09-10',
      salg: serie('2026-09-09', 40, 10), modell: M.basis, minstDagerMedSalg: 10,
    })
    const u = forventetSalg({
      enhet: { stasjonId: S, ean: 'x' }, maalDato: '2026-09-10',
      salg: [], modell: M.basis, minstDagerMedSalg: 10,
    })
    const a = aggreger([
      { forventning: b, historiskVolum: 100 },
      { forventning: u, historiskVolum: 900 },
    ])
    expect(a.medDekning).toBe(1)
    expect(a.utenDekning).toBe(1)
    // DEN VIKTIGE: 90 % av volumet manglet. Summen er ikke en prognose
    // for nivaaet over - den er en delsum.
    expect(a.manglendeVolumandel).toBeCloseTo(0.9)
  })

  it('en manglende enhet bidrar ALDRI med 0 til summen', () => {
    const u = forventetSalg({
      enhet: { stasjonId: S, ean: 'x' }, maalDato: '2026-09-10',
      salg: [], modell: M.basis, minstDagerMedSalg: 10,
    })
    const bare = aggreger([{ forventning: u, historiskVolum: 500 }])
    expect(bare.antall).toBe(0)
    expect(bare.medDekning).toBe(0)
    // Et aggregat der INGEN enhet kunne beregnes har `antall: 0` - og
    // `medDekning: 0` er det som skiller det fra «vi forventer null».
    expect(bare.manglendeVolumandel).toBe(1)
  })

  it('tomt aggregat gir ikke deling paa null', () => {
    expect(aggreger([])).toEqual({
      antall: 0, medDekning: 0, utenDekning: 0, manglendeVolumandel: 0,
    })
  })
})
