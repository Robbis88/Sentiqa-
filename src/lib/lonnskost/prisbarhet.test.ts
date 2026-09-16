import { describe, expect, it } from 'vitest'
import {
  avgjorPrisbarhet,
  type Avtalerad, type Koblet, type Registerobservasjon,
} from './prisbarhet'

// =====================================================================
// KANARIFUGLENE ER MÅLT
//
// Tallene er lest ut av de ekte easy@work-filene og av produksjon
// 2026-09-16. Filene ligger utenfor git — de bærer navngitte ansatte
// med lønn — så observasjonene er skrevet inn her med kilden nevnt.
//
//   Sandra, nr 118, Lone
//     jan–juli  48 736,00 / Måned
//     august       285,00 / Time,  193,5 timer
//     ansatt_avtale (Lone, 118) = fastlonn, sist satt 2026-09-08
//
//   Carmen, nr 1104265, register Lone, arbeider Bønes
//     138,00 / Time hver måned. Ingen avtalerad noe sted.
//
//   Marietta, nr 1018, register Bønes
//     ansatt_avtale (Bønes, 1018) = timelonn. Varden har ingen rad.
// =====================================================================

const LONE = '11111111-1111-1111-1111-111111111111'
const BONES = '22222222-2222-2222-2222-222222222222'
const VARDEN = '33333333-3333-3333-3333-333333333333'

const koblet = (lonnsnr: string, registerStasjonId: string): Koblet =>
  ({ status: 'koblet', lonnsnr, registerStasjonId, kilde: 'direkte' })

/** Et register som svarer på (stasjon, nummer) — aldri på nummer alene. */
const registeret = (...rader: Registerobservasjon[]) =>
  (stasjonId: string, ansattNr: string) =>
    rader.find((r) => r.stasjonId === stasjonId && r.ansattNr === ansattNr) ?? null

type Avtalenoekkel = { stasjonId: string; ansattNr: string } & Avtalerad

/**
 * Avtaleoppslag som HONORERER stasjonen.
 *
 * At faken er stasjonsbundet er hele poenget: en fake som ignorerte
 * stasjonen ville gjort lekkasjevakten grønn uansett hva koden gjorde.
 */
const avtalene = (...rader: Avtalenoekkel[]) =>
  (stasjonId: string, ansattNr: string): Avtalerad | null => {
    const t = rader.find((r) => r.stasjonId === stasjonId && r.ansattNr === ansattNr)
    return t ? { lonnsform: t.lonnsform, sistSatt: t.sistSatt } : null
  }

const INGEN_AVTALER = avtalene()

const SANDRA_JULI: Registerobservasjon = {
  stasjonId: LONE, ansattNr: '118', maaned: '2026-07',
  timesats: 48736, betalingsfrekvens: 'maaned',
}
const SANDRA_AUGUST: Registerobservasjon = {
  stasjonId: LONE, ansattNr: '118', maaned: '2026-08',
  timesats: 285, betalingsfrekvens: 'time',
}
const CARMEN: Registerobservasjon = {
  stasjonId: LONE, ansattNr: '1104265', maaned: '2026-07',
  timesats: 138, betalingsfrekvens: 'time',
}
const SANDRA_AVTALE: Avtalenoekkel = {
  stasjonId: LONE, ansattNr: '118', lonnsform: 'fastlonn', sistSatt: '2026-09-08',
}

describe('Sandra — de to månedene behandles ulikt', () => {
  it('juli: Easy sier Måned, og det avgjør alene', () => {
    // Avtalen ER med i oppslaget. Den skal ikke konsulteres i det hele
    // tatt når kilden selv har sagt månedslønn om måneden.
    expect(avgjorPrisbarhet(
      koblet('118', LONE),
      registeret(SANDRA_JULI),
      avtalene(SANDRA_AVTALE),
    )).toEqual({ status: 'maanedslonn', belop: 48736 })
  })

  it('august: Easy sa Time/285, avtalen kom etterpå', () => {
    const svar = avgjorPrisbarhet(
      koblet('118', LONE),
      registeret(SANDRA_AUGUST),
      avtalene(SANDRA_AVTALE),
    )
    expect(svar).toEqual({
      status: 'fastlonn_klassifisert',
      proveniens: 'ansatt_avtale',
      stasjonId: LONE,
      sistSatt: '2026-09-08',
      anvendtBakover: true,
      easyObservasjon: { betalingsfrekvens: 'time', timesats: 285 },
    })
  })

  it('august: Easy-observasjonen omskrives ikke', () => {
    // Systemet skal kunne si: «Easy sa Time/285 i august. En senere
    // ansattavtale klassifiserer personen som fastlønn. Derfor er
    // timene ikke timepriset.» Uten dette feltet kan den bare si det
    // siste.
    const svar = avgjorPrisbarhet(
      koblet('118', LONE), registeret(SANDRA_AUGUST), avtalene(SANDRA_AVTALE),
    )
    if (svar.status !== 'fastlonn_klassifisert') throw new Error('feil status')
    expect(svar.easyObservasjon.betalingsfrekvens).toBe('time')
    expect(svar.easyObservasjon.timesats).toBe(285)
  })

  it('en avtale satt FØR månedens utgang er ikke anvendt bakover', () => {
    const svar = avgjorPrisbarhet(
      koblet('118', LONE),
      registeret(SANDRA_AUGUST),
      avtalene({ ...SANDRA_AVTALE, sistSatt: '2026-08-01' }),
    )
    if (svar.status !== 'fastlonn_klassifisert') throw new Error('feil status')
    expect(svar.anvendtBakover).toBe(false)
  })

  it('siste dag i måneden er ikke bakover', () => {
    // Grensen skal være skarp, ikke omtrentlig. August har 31 dager.
    const svar = avgjorPrisbarhet(
      koblet('118', LONE),
      registeret(SANDRA_AUGUST),
      avtalene({ ...SANDRA_AVTALE, sistSatt: '2026-08-31' }),
    )
    if (svar.status !== 'fastlonn_klassifisert') throw new Error('feil status')
    expect(svar.anvendtBakover).toBe(false)
  })
})

describe('Carmen — kryssarbeid', () => {
  it('avtalen slås opp på REGISTERSTASJONEN, ikke arbeidsstedet', () => {
    // Hun arbeider på Bønes. Ansettelseskonteksten er Lone. Ingen
    // avtalerad noe sted, så hun er prisbar til 138.
    expect(avgjorPrisbarhet(
      koblet('1104265', LONE), registeret(CARMEN), INGEN_AVTALER,
    )).toEqual({
      status: 'prisbar',
      timesats: 138,
      kilde: { stasjonId: LONE, maaned: '2026-07' },
    })
  })

  it('en avtalerad på ARBEIDSSTEDET rører henne ikke', () => {
    // Om noen setter fastlønn på (Bønes, 1104265) — arbeidsstedet —
    // skal det ikke påvirke ansettelsesforholdet hennes på Lone.
    const svar = avgjorPrisbarhet(
      koblet('1104265', LONE),
      registeret(CARMEN),
      avtalene({
        stasjonId: BONES, ansattNr: '1104265',
        lonnsform: 'fastlonn', sistSatt: '2026-09-01',
      }),
    )
    expect(svar.status).toBe('prisbar')
  })

  it('oppslaget får nøyaktig registerstasjonen og lønnsnummeret', () => {
    const sett: [string, string][] = []
    avgjorPrisbarhet(koblet('1104265', LONE), registeret(CARMEN), (s, n) => {
      sett.push([s, n])
      return null
    })
    expect(sett).toEqual([[LONE, '1104265']])
  })
})

describe('lekkasjevakten — et globalt oppslag ville endret svaret', () => {
  it('(Lone, 118) = fastlonn når ALDRI en 118 på en annen stasjon', () => {
    // Dette er den diskriminerende vakten. Mariettas `timelonn` ville
    // vært en grønn kanarifugl i begge retninger — den endrer ingenting.
    // Sandras `fastlonn` gjør det: lekket den, ville en fremmed 118
    // sluttet å bli timepriset, og lønnsrommet blitt for stort.
    const svar = avgjorPrisbarhet(
      koblet('118', BONES),
      registeret({
        stasjonId: BONES, ansattNr: '118', maaned: '2026-08',
        timesats: 210, betalingsfrekvens: 'time',
      }),
      avtalene(SANDRA_AVTALE),
    )
    expect(svar).toEqual({
      status: 'prisbar', timesats: 210, kilde: { stasjonId: BONES, maaned: '2026-08' },
    })
  })

  it('Bønes-avtalen på 1018 når ikke Varden', () => {
    const svar = avgjorPrisbarhet(
      koblet('1018', VARDEN),
      registeret({
        stasjonId: VARDEN, ansattNr: '1018', maaned: '2026-07',
        timesats: 185.46, betalingsfrekvens: 'time',
      }),
      avtalene({
        stasjonId: BONES, ansattNr: '1018',
        lonnsform: 'timelonn', sistSatt: '2026-09-14',
      }),
    )
    expect(svar.status).toBe('prisbar')
  })
})

describe('ukjent enhet og manglende sats er ikke det samme', () => {
  it('null frekvens + null sats blir ukjent_enhet, IKKE mangler_sats', () => {
    // Vi vet ennå ikke engang at personen SKAL ha en timesats. Å kalle
    // det `mangler_sats` ville vært en påstand vi ikke har grunnlag for.
    expect(avgjorPrisbarhet(
      koblet('9001', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '9001', maaned: '2026-07',
        timesats: null, betalingsfrekvens: null,
      }),
      INGEN_AVTALER,
    )).toEqual({ status: 'ukjent_enhet', timesats: null })
  })

  it('time + null sats blir mangler_sats', () => {
    // Her HAR Easy sagt hva tallet skulle vært. Det er en annen feil.
    expect(avgjorPrisbarhet(
      koblet('9002', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '9002', maaned: '2026-07',
        timesats: null, betalingsfrekvens: 'time',
      }),
      INGEN_AVTALER,
    )).toEqual({ status: 'mangler_sats' })
  })

  it('null frekvens med sats blir ukjent_enhet og BEVARER satsen', () => {
    // B1-garantien: en rad skrevet før `0220` har null enhet. At det
    // står et tall der gjør den ikke til timelønn.
    expect(avgjorPrisbarhet(
      koblet('9003', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '9003', maaned: '2026-07',
        timesats: 48736, betalingsfrekvens: null,
      }),
      INGEN_AVTALER,
    )).toEqual({ status: 'ukjent_enhet', timesats: 48736 })
  })

  it('ukjent enhet blir ALDRI prisbar, uansett hvor pen satsen er', () => {
    const svar = avgjorPrisbarhet(
      koblet('9004', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '9004', maaned: '2026-07',
        timesats: 210, betalingsfrekvens: null,
      }),
      INGEN_AVTALER,
    )
    expect(svar.status).not.toBe('prisbar')
  })
})

describe('rekkefølgen', () => {
  it('Måned slår fastlønnsavtalen', () => {
    expect(avgjorPrisbarhet(
      koblet('118', LONE), registeret(SANDRA_JULI), avtalene(SANDRA_AVTALE),
    ).status).toBe('maanedslonn')
  })

  it('fastlønnsavtalen slår ukjent enhet', () => {
    const svar = avgjorPrisbarhet(
      koblet('118', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '118', maaned: '2026-08',
        timesats: 285, betalingsfrekvens: null,
      }),
      avtalene(SANDRA_AVTALE),
    )
    expect(svar.status).toBe('fastlonn_klassifisert')
  })

  it('ukjent enhet slår manglende sats', () => {
    expect(avgjorPrisbarhet(
      koblet('9005', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '9005', maaned: '2026-07',
        timesats: null, betalingsfrekvens: null,
      }),
      INGEN_AVTALER,
    ).status).toBe('ukjent_enhet')
  })
})

describe('klassifiseringer som IKKE er fastlønn', () => {
  it('tilkalling prises som vanlig', () => {
    // En tilkallingsvikar får betalt for timene sine — de føres bare
    // utenom Visma-fila. Å fjerne kostnaden ville gjort lønnskosten for
    // lav. Samme regel som `import/kjerne.ts` alt følger.
    expect(avgjorPrisbarhet(
      koblet('1104265', LONE),
      registeret(CARMEN),
      avtalene({
        stasjonId: LONE, ansattNr: '1104265',
        lonnsform: 'tilkalling', sistSatt: '2026-09-01',
      }),
    ).status).toBe('prisbar')
  })

  it('timelonn prises som vanlig', () => {
    expect(avgjorPrisbarhet(
      koblet('1104265', LONE),
      registeret(CARMEN),
      avtalene({
        stasjonId: LONE, ansattNr: '1104265',
        lonnsform: 'timelonn', sistSatt: '2026-09-14',
      }),
    ).status).toBe('prisbar')
  })

  it('lonnsform null er et spørsmål, ikke fastlønn', () => {
    // 9 av 13 avtalerader i produksjon har null. Ville de telt som
    // fastlønn, hadde lønnskosten falt for ni personer i stillhet.
    expect(avgjorPrisbarhet(
      koblet('1104265', LONE),
      registeret(CARMEN),
      avtalene({
        stasjonId: LONE, ansattNr: '1104265',
        lonnsform: null, sistSatt: '2026-09-06',
      }),
    ).status).toBe('prisbar')
  })
})

describe('feil som skal rope', () => {
  it('kaster når registerraden er borte', () => {
    // Identiteten KOM fra den raden. Er den vekk når vi spør igjen, er
    // noe galt i kallstedet — og et stille svar ville sett ut som en
    // person uten sats.
    expect(() => avgjorPrisbarhet(
      koblet('118', LONE), registeret(), INGEN_AVTALER,
    )).toThrow(/Ingen registerrad/)
  })

  it('kaster på en ugyldig måned', () => {
    expect(() => avgjorPrisbarhet(
      koblet('118', LONE),
      registeret({
        stasjonId: LONE, ansattNr: '118', maaned: 'august',
        timesats: 285, betalingsfrekvens: 'time',
      }),
      INGEN_AVTALER,
    )).toThrow(/Ugyldig måned/)
  })
})
