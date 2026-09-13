// Uforklart matavvik: når tåler serien en retning?
//
// =====================================================================
// TO POSITIVE MÅNEDER HVOR SOM HELST ER IKKE EN UTVIKLING
// =====================================================================
//
// Første regel var `naaKr < 0 || positive <= 1`. Den godkjente en
// retning så snart serien hadde to positive måneder — uansett hvor de
// lå. Målt på Dale januar–juli 2026:
//
//     jan +19 034   feb −6 333   mar −2 062   apr −9 992
//     mai  −2 958   jun −5 643   jul +31 902
//
// To positive med fem negative imellom passerte, og juli fikk en trend.
// Snittet de seks foregående var −1 326; juli er +31 902. Det er ikke
// en utvikling, det er et sprang — og det kan like gjerne være telling,
// periodisering eller fakturatidspunkt som svinn.
//
// Seriene under er MÅLT med produksjonsparseren over de sju aktive
// filene, med grunnlagsregelen fra P1.

import { describe, expect, it } from 'vitest'
import { usynligretning, USYNLIG_VINDU } from './plan'
import { retning } from './retning'

/** Uforklart matavvik per måned, januar → juli 2026. */
const SERIE: Record<string, { navn: string; tall: number[] }> = {
  '4177': { navn: 'Lone', tall: [-1641.16, 8276.34, 13884.62, -4290.40, 610.95, -4746.57, 15268.25] },
  '4185': { navn: 'Dale', tall: [19034.08, -6333.21, -2061.95, -9991.53, -2958.12, -5642.90, 31902.47] },
  '9038': { navn: 'Laguneparken', tall: [11348.51, 3707.44, -9894.58, -7993.11, 14501.30, 2510.86, 1404.77] },
  '9145': { navn: 'Varden', tall: [6173.62, 3928.10, -84.93, 182.66, 2352.71, 3133.44, 3814.60] },
  '9467': { navn: 'Bønes', tall: [-1361.55, 193.90, 166.42, -6618.73, 2146.11, -3588.04, 1079.67] },
}

describe('de fem faktiske seriene', () => {
  it.each([
    ['4185', 'Dale'],
    ['4177', 'Lone'],
    ['9467', 'Bønes'],
  ])('%s %s: usikker, ingen retning', (bn) => {
    const v = usynligretning(SERIE[bn].tall)
    expect(v.usikker).toBe(true)
    expect(v.kurs).toBeNull()
    expect(v.vindu).toBe(0)
    expect(v.aarsak).toBeTruthy()
  })

  it('Dale blokkeres av BÅDE fortegn og dominans', () => {
    // mai −2 958, jun −5 643, jul +31 902.
    const v = usynligretning(SERIE['4185'].tall)
    expect(v.aarsak).toContain('Fortegnet skifter')
    // Fortegnsregelen slår først. At dominansen også ville slått,
    // vises med en serie der fortegnet er likt.
    const bareDominans = [-2958.12, -5642.90, -31902.47]
    const d = usynligretning([...SERIE['4185'].tall.slice(0, 4), ...bareDominans])
    expect(d.usikker).toBe(true)
    expect(d.aarsak).toContain('tre ganger medianen')
  })

  it('Varden: retning OPP på mai–juli', () => {
    // 2 353 → 3 133 → 3 815. Tre positive, ingen ekstrem.
    // OPP i et positivt uforklart avvik betyr VERRE.
    const v = usynligretning(SERIE['9145'].tall)
    expect(v.usikker).toBe(false)
    expect(v.kurs?.vei).toBe('opp')
    expect(v.vindu).toBe(USYNLIG_VINDU)
  })

  it('Laguneparken: retning NED på mai–juli', () => {
    // 14 501 → 2 511 → 1 405. Forbedring, men fortsatt +1 405.
    const v = usynligretning(SERIE['9038'].tall)
    expect(v.usikker).toBe(false)
    expect(v.kurs?.vei).toBe('ned')
    expect(v.vindu).toBe(USYNLIG_VINDU)
  })

  it('bare de to stasjonene får retning', () => {
    const med = Object.keys(SERIE).filter((bn) => !usynligretning(SERIE[bn].tall).usikker)
    expect(med.sort()).toEqual(['9038', '9145'])
  })
})

describe('retningen regnes PÅ VINDUET, ikke på hele serien', () => {
  it('januar–april endrer ikke retningen når mai–juli er like', () => {
    // Dette er punkt 3 i regelen: brukes tre måneder som bevis for at
    // retningen finnes, må retningen også måles på de tre.
    // Halen maa ikke selv utloese dominanssperren - medianen av de
    // foregaaende er 1 000 i den foerste serien, saa 4 000 ville blitt
    // en ekstremverdi. Det oppdaget testen selv, foerste kjoering.
    const halen = [2_000, 2_100, 2_200]
    const a = usynligretning([1_000, 1_000, 1_000, 1_000, ...halen])
    const b = usynligretning([9_000, 8_000, 7_000, 6_000, ...halen])
    expect(a.kurs?.vei).toBe('opp')
    expect(b.kurs?.vei).toBe('opp')
    expect(a.kurs?.endring).toBeCloseTo(b.kurs!.endring, 6)
  })

  it('KANARI: hele serien ville gitt motsatt svar', () => {
    // 9 000 ned til 2 000, saa opp igjen til 2 200. Hele serien faller;
    // de tre siste stiger. Det er nettopp forskjellen vinduet finnes for.
    const heleSerien = [9_000, 8_000, 7_000, 6_000, 2_000, 2_100, 2_200]
    expect(usynligretning(heleSerien).kurs?.vei).toBe('opp')
    expect(retning(heleSerien)?.vei).toBe('ned')
  })
})

describe('de to sperrene', () => {
  it('et fortegnsskifte i juli blokkerer', () => {
    expect(usynligretning([3_000, 3_100, 3_200, 3_300, -100]).usikker).toBe(true)
    expect(usynligretning([3_000, 3_100, 3_200, 3_300, -100]).aarsak)
      .toContain('Fortegnet skifter')
  })

  it('en ekstrem verdi i juli blokkerer', () => {
    const v = usynligretning([3_000, 3_100, 3_200, 3_300, 40_000])
    expect(v.usikker).toBe(true)
    expect(v.aarsak).toContain('tre ganger medianen')
    expect(v.aarsak).toContain('Usikker enkeltmåling')
  })

  it('akkurat tre ganger medianen slipper gjennom', () => {
    // Grensen er `>`, ikke `>=`. En stasjon som treffer den eksakt er
    // ikke en ekstremverdi.
    const v = usynligretning([1_000, 1_000, 1_000, 1_000, 3_000])
    expect(v.usikker).toBe(false)
  })

  it('færre enn tre måneder gir null, ikke «flat»', () => {
    expect(usynligretning([1_000, 2_000]).kurs).toBeNull()
    expect(usynligretning([1_000, 2_000]).aarsak).toContain('Færre enn 3')
  })

  it('null i vinduet bryter ikke fortegnet', () => {
    // En måned på null er ikke et fortegnsskifte — den snur ingenting.
    expect(usynligretning([1_000, 2_000, 0, 3_000]).usikker).toBe(false)
  })

  it('tre sammenhengende negative gir retning', () => {
    // Fortegnet er konsistent. At et overskudd ikke er en gevinst er en
    // TEKST-regel, ikke en retningsregel.
    const v = usynligretning([-1_000, -1_500, -2_000, -2_500])
    expect(v.usikker).toBe(false)
    expect(v.kurs?.vei).toBe('ned')
  })
})

describe('dominansen måles likt uansett lesning', () => {
  it('median over hele historikken og over vinduet gir samme utfall', () => {
    // «Tidligere relevante måneder» kan leses som alle foregående, eller
    // som de to andre i vinduet. Målt på alle fem seriene gir de samme
    // svar — det er dokumentert her så valget ikke blir usynlig.
    const median = (a: number[]) => {
      const s = [...a].sort((x, y) => x - y)
      const m = Math.floor(s.length / 2)
      return s.length % 2 === 0 ? (s[m - 1] + s[m]) / 2 : s[m]
    }
    for (const [bn, { tall }] of Object.entries(SERIE)) {
      const siste = Math.abs(tall[tall.length - 1])
      const heleHistorikken = siste > 3 * median(tall.slice(0, -1).map(Math.abs))
      const bareVinduet = siste > 3 * median(tall.slice(-3, -1).map(Math.abs))
      expect(heleHistorikken, `${bn} leses ulikt`).toBe(bareVinduet)
    }
  })
})
