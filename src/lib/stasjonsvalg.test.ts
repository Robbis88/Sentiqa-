import { describe, expect, test } from 'vitest'
import {
  fraLagring, sidenTaalerAggregat, stasjonFraUrl, stasjonsnavn, tilLagring,
  velgStasjon, visVelger,
} from './stasjonsvalg'

const ALLE = [
  { id: 'a', navn: 'Lone', butikknummer: '4177' },
  { id: 'b', navn: 'Bønes', butikknummer: '9467' },
]

describe('velgStasjon', () => {
  test('URL-en vinner over det man valgte sist', () => {
    // En delt lenke skal vise det den lovet. Snur man dette, blir
    // dyplenker upaalitelige - og det oppdages forst naar noen sender en
    // lenke til feil tall.
    expect(velgStasjon(ALLE, { fraUrl: 'b', fraHukommelse: 'a' })).toBe('b')
  })

  test('uten URL brukes det man valgte sist', () => {
    expect(velgStasjon(ALLE, { fraHukommelse: 'b' })).toBe('b')
  })

  test('uten noe som helst velges den første', () => {
    expect(velgStasjon(ALLE, {})).toBe('a')
  })

  test('en husket stasjon som ikke finnes lenger, faller tilbake', () => {
    // Slettet stasjon, eller en bruker som byttet kjede. Skal ikke gi
    // tom side.
    expect(velgStasjon(ALLE, { fraHukommelse: 'borte' })).toBe('a')
  })

  test('en ugyldig stasjon i URL-en faller tilbake, den også', () => {
    expect(velgStasjon(ALLE, { fraUrl: 'tull' })).toBe('a')
  })

  test('«alle» er et valg, ikke fravær av et valg', () => {
    expect(velgStasjon(ALLE, { fraUrl: 'alle', tillatAlle: true })).toBeNull()
    expect(velgStasjon(ALLE, { fraHukommelse: 'alle', tillatAlle: true })).toBeNull()
  })

  test('sider som ikke tåler «alle», får likevel en stasjon', () => {
    // Lonnsfila lages per stasjon. «Alle samlet» gir ingen mening der,
    // og skal ikke gi en tom side heller.
    expect(velgStasjon(ALLE, { fraUrl: 'alle', tillatAlle: false })).toBe('a')
    expect(velgStasjon(ALLE, { fraHukommelse: 'alle' })).toBe('a')
  })

  test('eieren lander på porteføljen der siden tåler det', () => {
    expect(velgStasjon(ALLE, { tillatAlle: true })).toBeNull()
  })

  test('ingen stasjoner gir null, ikke krasj', () => {
    expect(velgStasjon([], { fraUrl: 'a' })).toBeNull()
  })
})

describe('visVelger', () => {
  test('én stasjon og ingen porteføljevisning er ikke et valg', () => {
    expect(visVelger([ALLE[0]], false)).toBe(false)
  })

  test('én stasjon, men «alle» finnes — da er det to alternativer', () => {
    expect(visVelger([ALLE[0]], true)).toBe(true)
  })

  test('flere stasjoner vises alltid', () => {
    expect(visVelger(ALLE, false)).toBe(true)
  })

  test('ingen stasjoner gir ingen velger', () => {
    expect(visVelger([], true)).toBe(false)
  })
})

describe('stasjonsnavn', () => {
  test('nummer foran navn', () => {
    expect(stasjonsnavn(ALLE[1])).toBe('9467 Bønes')
  })

  test('uten nummer bare navnet', () => {
    expect(stasjonsnavn({ id: 'x', navn: 'Ny stasjon' })).toBe('Ny stasjon')
  })
})

// =====================================================================
// Trinn 09: appskallet og siden skal aldri kunne svare forskjellig.
//
// Feilen var ikke at reglene manglet - de sto her hele tiden - men at
// halve systemet aldri sporte. Testene under maaler de nye delene som
// gjor at BEGGE kan sporre om det samme.
// =====================================================================

describe('stasjonFraUrl', () => {
  const sok = (s: string) => new URLSearchParams(s)

  test('id i ?stasjon= brukes naar den finnes', () => {
    expect(stasjonFraUrl(sok('stasjon=b'), ALLE)).toBe('b')
  })

  test('?stasjon=alle er et eksplisitt valg', () => {
    expect(stasjonFraUrl(sok('stasjon=alle'), ALLE)).toBe('alle')
  })

  test('butikknummer oversettes til id', () => {
    // Uten denne oversettelsen maatte appskallet kjenne hver sides
    // parameternavn - og da ville de to for eller siden svart ulikt.
    expect(stasjonFraUrl(sok('butikknummer=9467'), ALLE)).toBe('b')
  })

  test('K - en stasjon brukeren ikke har, gir ingenting', () => {
    // `ALLE` er det brukeren FAAR se (RLS har allerede filtrert). En id
    // utenfor lista er enten slettet eller en annen kjedes, og skal
    // hverken vises eller skrives inn i hukommelsen.
    expect(stasjonFraUrl(sok('stasjon=en-annen-kjede'), ALLE)).toBeUndefined()
    expect(stasjonFraUrl(sok('butikknummer=0000'), ALLE)).toBeUndefined()
  })

  test('ingen parameter er ikke et valg', () => {
    expect(stasjonFraUrl(sok(''), ALLE)).toBeUndefined()
  })

  test('K - ugyldig verdi lar hukommelsen staa', () => {
    // Hele poenget: en daarlig lenke skal ikke kunne flytte brukeren.
    const fraUrl = stasjonFraUrl(sok('stasjon=tull'), ALLE)
    expect(velgStasjon(ALLE, { fraUrl, fraHukommelse: 'b' })).toBe('b')
  })
})

describe('sidenTaalerAggregat', () => {
  test('salgssidene summerer', () => {
    expect(sidenTaalerAggregat('/salg')).toBe(true)
    expect(sidenTaalerAggregat('/svinn')).toBe(true)
  })

  test('produksjonsplanen krever en stasjon', () => {
    // En plan for «alle stasjoner» er ikke en plan noen kan bake etter.
    expect(sidenTaalerAggregat('/produksjonsplan')).toBe(false)
  })

  test('KANARIFUGL - en ukjent rute krever en stasjon', () => {
    // Standarden maa vaere den trygge. En ny side som glemmer aa ta
    // stilling skal ikke begynne aa summere tall som ikke kan summeres.
    expect(sidenTaalerAggregat('/en-helt-ny-side')).toBe(false)
  })

  test('skraastrek paa slutten endrer ingenting', () => {
    expect(sidenTaalerAggregat('/salg/')).toBe(true)
  })
})

describe('J - fra «alle» til en side som krever en stasjon', () => {
  test('hukommelsen «alle» faller tilbake til forste stasjon', () => {
    // Brukeren staar paa /salg med alle stasjoner og gaar til
    // /produksjonsplan. Sida kan ikke aggregere, og BEGGE - skall og
    // side - lander paa samme konkrete stasjon fordi begge kaller denne.
    expect(velgStasjon(ALLE, { fraHukommelse: 'alle', tillatAlle: false })).toBe('a')
  })

  test('og den samme regelen gjelder URL-en', () => {
    expect(velgStasjon(ALLE, { fraUrl: 'alle', tillatAlle: false })).toBe('a')
  })
})

describe('lagring av «alle»', () => {
  test('domeneverdi ut og inn igjen', () => {
    expect(tilLagring(null)).toBe('alle')
    expect(tilLagring('a')).toBe('a')
  })

  test('tom streng er IKKE «alle»', () => {
    // De tre tilstandene som ble blandet: valgt aggregat, ingenting
    // valgt, og tom verdi. Blandes de, kan en foerstegangsbruker havne
    // paa et aggregat hun aldri ba om.
    expect(fraLagring('')).toBeNull()
    expect(fraLagring(undefined)).toBeNull()
    expect(fraLagring('alle')).toBe('alle')
  })
})
