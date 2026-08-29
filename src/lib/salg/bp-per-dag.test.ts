import { describe, it, expect } from 'vitest'
import {
  AAR_I_DAGER, motpartFor, dageneI, motpartsvindu, fordelBp, hittil,
} from './bp-per-dag'

// =====================================================================
// TALLENE HER ER DALES EGNE, august 2026, hentet 2026-08-29.
//
// En test med oppdiktede tall beviser at koden gjor det den sier. Disse
// beviser at den gjor det RIKTIGE - og de to lordagene som ikke var i
// normal drift er grunnen til at fordelingen er som den er.
// =====================================================================

const FJOR: Record<string, number> = {
  '2025-08-02': 56483, '2025-08-03': 82731, '2025-08-04': 53542, '2025-08-05': 40540,
  '2025-08-06': 41951, '2025-08-07': 45724, '2025-08-08': 63133, '2025-08-09': 42529,
  '2025-08-10': 73385, '2025-08-11': 40950, '2025-08-12': 41652, '2025-08-13': 44024,
  '2025-08-14': 45031, '2025-08-15': 65893, '2025-08-16': 18582, '2025-08-17': 82930,
  '2025-08-18': 44088, '2025-08-19': 42342, '2025-08-20': 39480, '2025-08-21': 47507,
  '2025-08-22': 54437, '2025-08-23': 38308, '2025-08-24': 87954, '2025-08-25': 43343,
  '2025-08-26': 40228, '2025-08-27': 35373, '2025-08-28': 41806, '2025-08-29': 57966,
  '2025-08-30': 13998, '2025-08-31': 54952, '2025-09-01': 30492,
}
const SALG: Record<string, number> = {
  '2026-08-01': 55660, '2026-08-02': 76455, '2026-08-03': 51765, '2026-08-04': 47273,
  '2026-08-05': 52678, '2026-08-06': 55072, '2026-08-07': 60198, '2026-08-08': 40336,
  '2026-08-09': 73349, '2026-08-10': 45629, '2026-08-11': 36602, '2026-08-12': 42517,
  '2026-08-13': 52950, '2026-08-14': 65865, '2026-08-15': 40348, '2026-08-16': 77952,
  '2026-08-17': 45635, '2026-08-18': 41907, '2026-08-19': 42220, '2026-08-20': 49001,
  '2026-08-21': 54798, '2026-08-22': 45008, '2026-08-23': 83089, '2026-08-24': 45684,
  '2026-08-25': 37314, '2026-08-26': 50085, '2026-08-27': 51048,
}
const BP_AUGUST = 1606922

const rader = Object.entries(FJOR).map(([dato, omsetning]) => ({ dato, omsetning }))
const salgKart = new Map(Object.entries(SALG))

describe('motparten', () => {
  it('er 364 dager, ikke 365', () => {
    expect(AAR_I_DAGER).toBe(364)
  })

  it('KANARIFUGL: treffer alltid samme ukedag', () => {
    // Hele metoden hviler paa dette. Ble det 365, ville soendag blitt
    // loerdag - og fordelingen ville vaert feil paa hver eneste dag
    // uten at noe kastet.
    for (const dato of dageneI('2026-08-01')) {
      const a = new Date(`${dato}T12:00:00Z`).getUTCDay()
      const b = new Date(`${motpartFor(dato)}T12:00:00Z`).getUTCDay()
      expect(b, `${dato} -> ${motpartFor(dato)}`).toBe(a)
    }
  })

  it('taaler skuddaar', () => {
    // 2028 er skuddaar. 364 dager er 364 dager uansett.
    const a = new Date('2028-03-01T12:00:00Z').getUTCDay()
    const b = new Date(`${motpartFor('2028-03-01')}T12:00:00Z`).getUTCDay()
    expect(b).toBe(a)
  })
})

describe('motpartsvinduet', () => {
  it('er IKKE fjoraarets maaned', () => {
    // Den ene linja som hindrer at noen spor om august 2025 i stedet.
    expect(motpartsvindu('2026-08-01')).toEqual({ fra: '2025-08-02', til: '2025-09-01' })
  })

  it('KANARIFUGL: siste dag i august peker inn i september', () => {
    expect(motpartFor('2026-08-31')).toBe('2025-09-01')
  })

  it('dageneI teller riktig, ogsaa i februar', () => {
    expect(dageneI('2026-08-01')).toHaveLength(31)
    expect(dageneI('2026-02-01')).toHaveLength(28)
    expect(dageneI('2028-02-01')).toHaveLength(29)
    expect(dageneI('2026-04-01')).toHaveLength(30)
  })
})

describe('fordelBp', () => {
  const b = fordelBp('2026-08-01', BP_AUGUST, rader)

  it('summerer til maanedens BP paa krona', () => {
    // DEN VIKTIGSTE PAASTANDEN. Robert: «viktigste er jo alltid mnd
    // totalt». Summerer ikke dagene til BP, er hele tabellen usann.
    const sum = b.reduce((s, d) => s + d.bp, 0)
    expect(Math.round(sum)).toBe(BP_AUGUST)
  })

  it('gir alle like ukedager samme maaltall', () => {
    const lordager = b.filter((d) => new Date(`${d.dato}T12:00:00Z`).getUTCDay() === 6)
    expect(lordager).toHaveLength(5)
    for (const d of lordager) expect(Math.round(d.bp)).toBe(39138)
  })

  it('KANARIFUGL: de to oedelagte loerdagene smitter ikke', () => {
    // 2025-08-16 gjorde 18 582 og 2025-08-30 gjorde 13 998. Ble dagene
    // brukt raa, ville 15. og 29. august faatt under 20 000 i maaltall.
    const femtende = b.find((d) => d.dato === '2026-08-15')!
    const tjueniende = b.find((d) => d.dato === '2026-08-29')!

    expect(femtende.ifjor).toBe(18582)      // faktumet staar
    expect(tjueniende.ifjor).toBe(13998)
    expect(Math.round(femtende.bp)).toBe(39138)   // maaltallet lar seg ikke smitte
    expect(Math.round(tjueniende.bp)).toBe(39138)
  })

  it('lar «i fjor» vaere det som faktisk skjedde', () => {
    // Budsjettet er et MAAL og skal taale at fjoraaret var i stykker.
    // Fjoraaret er et FAKTUM og skal vise hva som skjedde. Lappes
    // kolonnen ogsaa, forsvinner sporet av at dagen var unormal.
    for (const d of b) expect(d.ifjor).toBe(FJOR[d.motpart] ?? 0)
  })

  it('soendag er stoerst paa en utfartsstasjon - uten at noen sa det', () => {
    // Metoden leser stasjonstypen ut av tallene. Ingen konfigurasjon.
    const per = new Map<number, number>()
    for (const d of b) per.set(new Date(`${d.dato}T12:00:00Z`).getUTCDay(), Math.round(d.bp))
    expect(per.get(0)!).toBeGreaterThan(per.get(2)! * 1.9) // søndag ~2x tirsdag
  })

  it('tomt fjoraar gir lik fordeling i stedet for aa kaste', () => {
    const tom = fordelBp('2026-08-01', 310000, [])
    expect(tom).toHaveLength(31)
    expect(Math.round(tom[0].bp)).toBe(10000)
    expect(Math.round(tom.reduce((s, d) => s + d.bp, 0))).toBe(310000)
  })

  it('KANARIFUGL: raa fordeling ville gitt et ANNET svar', () => {
    // Beviset paa at valget betyr noe. Ville de to metodene gitt samme
    // tall, var hele resonnementet over pynt.
    const raaVekt = (d: string) => FJOR[motpartFor(d)] ?? 0
    const dager = dageneI('2026-08-01')
    const sumRaa = dager.reduce((s, d) => s + raaVekt(d), 0)
    const raa15 = (BP_AUGUST * raaVekt('2026-08-15')) / sumRaa
    expect(Math.round(raa15)).toBe(19757)
    expect(Math.round(raa15)).toBeLessThan(39138 * 0.55)
  })
})

describe('hittil', () => {
  const b = fordelBp('2026-08-01', BP_AUGUST, rader)
  const h = hittil(b, salgKart)

  it('teller bare dagene som har vaert', () => {
    expect(h.dager).toBe(27)
    expect(h.salg).toBe(1420438)
  })

  it('maaler BP over NOEYAKTIG de samme dagene', () => {
    // Sammenlignes 27 dagers salg med et helt maanedsbudsjett, ser hver
    // stasjon ut til aa ligge katastrofalt bak den 27. i maaneden.
    expect(Math.round(h.bp)).toBe(1377120)
    expect(h.salg).toBeGreaterThan(h.bp)
  })

  it('KANARIFUGL: fjoraaret hittil er MOTPARTENE, ikke 1.-27. i fjor', () => {
    // Motpartene til 1.-27. august 2026 er 2025-08-02 .. 2025-08-28.
    // Den naive summen av 1.-27. august 2025 er et annet tall, og gir
    // +8,3 % der den riktige gir +4,9 %.
    expect(h.ifjor).toBe(1353946)

    const naiv = dageneI('2025-08-01').slice(0, 27)
      .reduce((s, d) => s + (FJOR[d] ?? 0), 0)
    expect(h.ifjor).not.toBe(naiv)

    const riktig = (h.salg / h.ifjor - 1) * 100
    const feil = (h.salg / naiv - 1) * 100
    expect(riktig).toBeCloseTo(4.9, 1)
    expect(feil - riktig).toBeGreaterThan(3) // over tre prosentpoeng fra hverandre
  })

  it('landingen bruker takten, ikke budsjettet', () => {
    expect(Math.round(h.landing!)).toBe(1657469)
    expect(h.landing!).toBeGreaterThan(BP_AUGUST)
  })

  it('uten maalte dager finnes ingen landing', () => {
    // Null dager gir ingen takt. Aa svare «lander paa BP» ville vaert en
    // paastand uten dekning - og den ville sett ut som et resultat.
    expect(hittil(b, new Map()).landing).toBeNull()
  })
})
