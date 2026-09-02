import { describe, expect, test } from 'vitest'
import { bpLinjer } from './rader'
import { bruttoKurve, timelonnKurve, maanedsrammer, KONTO_TIMELONN } from './fordeling'
import type { BpStasjon } from '@/lib/parsere/typer'

// =====================================================================
// DE TO VEIENE INN I BEMANNINGEN MAA GI SAMME TALL
//
// `lagreBp` fordeler timene mens den har FILA: bruttokurven ligger som
// `m.bruttoKr`. `lagreDelingsfil` kommer etterpaa uten fil og maa lese
// kurven ut av `bp_linje`.
//
//   fila -> parseBp -> m.bruttoKr                (lagreBp)
//   fila -> bpLinjer() -> basen -> bruttoKurve() (lagreDelingsfil)
//
// Sklir de fra hverandre, faar en kjede paa den gamle malen en
// maanedsfordeling som ikke stemmer med sin egen BP - og INGENTING sier
// fra, fordi begge tall er plausible. Derfor bevises likheten her, paa
// den ekte radbyggingen, ikke paa en avskrift av den.
//
// Dette er samme grep som `rader.ts` selv er bygget for: ligger
// utregningen inne i importoeren, beviser testen at kopien stemmer med
// seg selv.
// =====================================================================

const maaned = (
  m: number,
  kategorier: { kode: string; post: string; salgKr: number; varekostKr: number }[],
  konti: { kode: string; post: string; belopKr: number }[] = [],
) => ({
  maned: m,
  salgKr: kategorier.reduce((a, k) => a + k.salgKr, 0),
  varekostKr: kategorier.reduce((a, k) => a + k.varekostKr, 0),
  bruttoKr: kategorier.reduce((a, k) => a + k.salgKr - k.varekostKr, 0),
  timelonnKr: konti.filter((k) => k.kode === KONTO_TIMELONN).reduce((a, k) => a + k.belopKr, 0),
  fastlonnKr: 0,
  kategorier,
  konti,
})

/** En BP26-stasjon: to varegrupper, splittet lønn, ujevn kurve. */
function bp26(): BpStasjon {
  const maaneder = Array.from({ length: 12 }, (_, i) =>
    maaned(
      i + 1,
      [
        { kode: '120', post: 'Mat', salgKr: 100_000 + i * 7_000, varekostKr: 60_000 + i * 3_000 },
        { kode: '210', post: 'Vask', salgKr: 40_000 - i * 1_000, varekostKr: 5_000 },
      ],
      [
        { kode: KONTO_TIMELONN, post: 'Timelønn', belopKr: 90_000 + i * 500 },
        { kode: '5010', post: 'Fastlønn', belopKr: 45_000 },
      ],
    ))
  return { butikknummer: '9467', butikknavn: 'St1 Test', timerAar: 12_000, maaneder } as BpStasjon
}

/** En BP25-stasjon: hele lønna på 5010, ingen splitt, ingen timer i fila. */
function bp25(): BpStasjon {
  const maaneder = Array.from({ length: 12 }, (_, i) =>
    maaned(
      i + 1,
      [{ kode: '120', post: 'Mat', salgKr: 90_000 + i * 4_000, varekostKr: 55_000 }],
      [{ kode: '5010', post: 'Site Salary costs', belopKr: 130_000 }],
    ))
  return { butikknummer: '9467', butikknavn: 'SHELL Test', timerAar: null, maaneder } as BpStasjon
}

describe('bruttokurven overlever turen gjennom bp_linje', () => {
  test('KANARIFUGL: dokumentet gir samme brutto som fila, maaned for maaned', () => {
    // Selve saken. Endres seksjonsnavnene, fortegnet eller radbyggingen,
    // faller denne - og ikke en bemanningsplan hos en kunde.
    const s = bp26()
    expect(bruttoKurve(bpLinjer(s))).toEqual(s.maaneder.map((m) => m.bruttoKr))
  })

  test('ogsaa naar kurven er ujevn og en varegruppe krymper', () => {
    const s = bp26()
    const fasit = s.maaneder.map((m) => m.bruttoKr)
    // Ikke tolv like tall - en flat kurve ville bestaatt selv om
    // maanedsindeksen var feil.
    expect(new Set(fasit).size).toBeGreaterThan(6)
    expect(bruttoKurve(bpLinjer(s))).toEqual(fasit)
  })

  test('BP25 ogsaa: en varegruppe, ingen loennssplitt', () => {
    const s = bp25()
    expect(bruttoKurve(bpLinjer(s))).toEqual(s.maaneder.map((m) => m.bruttoKr))
  })

  test('KANARIFUGL: fikstureren lyver ikke - bruttoKr er faktisk salg minus varekost', () => {
    // Regnet `maaned()` bruttoKr paa samme maate som `bruttoKurve`, ville
    // testene over sammenlignet to avskrifter av samme feil.
    const s = bp26()
    const m = s.maaneder[3]
    expect(m.bruttoKr).toBe(m.salgKr - m.varekostKr)
    expect(m.salgKr).toBeGreaterThan(0)
    expect(m.varekostKr).toBeGreaterThan(0)
  })
})

describe('timeloennskurven', () => {
  test('BP26: bare 5012, aldri fastloenna', () => {
    const s = bp26()
    expect(timelonnKurve(bpLinjer(s))).toEqual(s.maaneder.map((m) => m.timelonnKr))
    // 5010 skal ikke lekke inn - det var nettopp den forvekslingen som
    // ville gitt 4,6 mot 1,8 millioner mot BP26.
    expect(timelonnKurve(bpLinjer(s)).every((v) => v < 100_000)).toBe(true)
  })

  test('BP25: tolv nuller, ikke et gjett paa splitten', () => {
    // Malen foerer hele loenna paa 5010. `lagreBp` ville skrevet samme
    // `lonn_kr` for den fila, saa null er det TROFASTE svaret her.
    expect(timelonnKurve(bpLinjer(bp25()))).toEqual(new Array(12).fill(0))
  })

  test('en maaned uten linjer blir null, ikke hull', () => {
    expect(bruttoKurve([])).toEqual(new Array(12).fill(0))
    expect(timelonnKurve([])).toHaveLength(12)
  })
})

describe('maanedsrammer: en implementasjon for begge veiene', () => {
  const flat = new Array(12).fill(100_000)
  const ingen = { reservePst: 0, sikkerhetPst: 0 }

  test('flat kurve gir tolv like rammer som summerer til aarsrammen', () => {
    const r = maanedsrammer(12_000, flat, ingen)
    expect(r).toHaveLength(12)
    expect(r.map((x) => x.maned)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    expect(r.reduce((a, x) => a + x.timer, 0)).toBeCloseTo(12_000, 6)
    expect(new Set(r.map((x) => Math.round(x.timer)))).toEqual(new Set([1000]))
  })

  test('ujevn kurve fordeler etter brutto, ikke flatt', () => {
    // Dobbelt saa stor brutto i januar skal gi dobbelt saa mange timer.
    const kurve = [200_000, ...new Array(11).fill(100_000)]
    const r = maanedsrammer(13_000, kurve, ingen)
    expect(r[0].timer).toBeCloseTo(r[1].timer * 2, 6)
    expect(r.reduce((a, x) => a + x.timer, 0)).toBeCloseTo(13_000, 6)
  })

  test('KANARIFUGL: `timer` og `disponible_timer` er IKKE samme tall', () => {
    // Fradragene er hele poenget - se [[sentiqa-timeregnskap]]. Blir de
    // like, er reserve og sikkerhet sluttet aa virke, og planleggeren
    // deler ut timer stasjonen ikke har fortjent.
    const r = maanedsrammer(12_000, flat, { reservePst: 10, sikkerhetPst: 3 })
    expect(r[0].disponible_timer).toBeLessThan(r[0].timer)
    expect(r.reduce((a, x) => a + x.timer, 0)).toBeCloseTo(12_000, 6)
    expect(r.reduce((a, x) => a + x.disponible_timer, 0)).toBeLessThan(12_000)
  })

  test('uten fradrag er de to like - saa testen over maaler fradraget, ikke stoey', () => {
    const r = maanedsrammer(12_000, flat, ingen)
    expect(r[0].disponible_timer).toBeCloseTo(r[0].timer, 6)
  })

  test('brutto paa null gir flat fordeling, ikke null timer', () => {
    // En BP uten omsetningstall skal ikke gi en planlegger uten timer.
    const r = maanedsrammer(12_000, new Array(12).fill(0), ingen)
    expect(r.reduce((a, x) => a + x.disponible_timer, 0)).toBeCloseTo(12_000, 6)
  })

  test('negativ ramme klippes til null, aldri under', () => {
    const r = maanedsrammer(0, flat, { reservePst: 50, sikkerhetPst: 50 })
    expect(r.every((x) => x.disponible_timer >= 0)).toBe(true)
  })

  test('brutto foelger med ut, saa budsjettraden ikke maa regne den paa nytt', () => {
    const kurve = [200_000, ...new Array(11).fill(100_000)]
    expect(maanedsrammer(1_000, kurve, ingen).map((x) => x.brutto_bp_kr)).toEqual(kurve)
  })
})
