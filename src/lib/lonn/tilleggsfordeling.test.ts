import { describe, expect, it } from 'vitest'
import { erHelgaften, erHelligdag, fordelVakt } from './tilleggsfordeling'
import { TILLEGGSSATS } from './tilleggssats'
import { minutterMellom } from '@/lib/parsere/basiseksport'

// `fordelVakt` tar minutter, ikke sluttidspunkt: lengden regnes ett
// sted, i parseren, der den også kontrolleres mot «Lengde»-kolonnen.
// Testene skriver klokkeslett fordi det er slik observasjonene er
// notert, og gaar veien om den samme utregningen produksjonen bruker.
const fordel = (dato: string, fra: string, til: string) =>
  fordelVakt(dato, fra, minutterMellom(dato, fra, til))

// Tallene under er MÅLT mot Lønnsoversikt (kronefila), ikke lest av
// overenskomsten. Hver påstand peker på observasjonen den kommer fra, så
// en endring kan holdes mot det samme beviset på nytt.

const t = (m: Map<string, number>, art: string) => Number((m.get(art) ?? 0).toFixed(2))

describe('fordelVakt — tilleggene', () => {
  it('deler en søndagsvakt på 06-18 og 18-24', () => {
    // MÅLT: Bønes 12. juli 2026, stemplet 13:01–19:00.
    // kronefila: 1434 = 4,97   1435 = 1,00   timelønn 5,97
    const f = fordel('2026-07-12', '13:01', '19:00')
    expect(t(f, '1434')).toBe(4.98)
    expect(t(f, '1435')).toBe(1)
    expect(t(f, '2')).toBe(5.98)
  })

  it('deler en hverdagskveld på 18-21 og 21-24', () => {
    // MÅLT: Bønes 23. juli 2026, stemplet 18:01–24:00.
    // kronefila: 1429 = 2,97   1430 = 3,00   timelønn 5,97
    const f = fordel('2026-07-23', '18:01', '00:00')
    expect(t(f, '1429')).toBe(2.98)
    expect(t(f, '1430')).toBe(3)
    expect(t(f, '2')).toBe(5.98)
  })

  it('gir ingen tillegg på en hverdagsformiddag', () => {
    const f = fordel('2026-07-20', '08:00', '16:00')
    expect([...f.keys()]).toEqual(['2'])
  })

  it('gir lørdagstillegg først fra 18', () => {
    // MÅLT: Dale 16. mai 2026, stemplet 15:00–22:00 → 1432 = 4,00.
    const f = fordel('2026-05-16', '15:00', '22:00')
    expect(t(f, '1432')).toBe(4)
    expect(t(f, '2')).toBe(7)
  })

  it('bytter art ved midnatt, ikke ved vaktens start', () => {
    // En vakt søndag 23:00 til mandag 07:00 er søndag kveld OG
    // hverdagsnatt. Ser man bare på startdagen, blir hele vakten søndag.
    const f = fordel('2026-07-26', '23:00', '07:00') // 26. juli er søndag
    expect(t(f, '1435')).toBe(1)
    expect(t(f, '1431')).toBe(6)
    expect(t(f, '2')).toBe(8)
  })
})

describe('fordelVakt — helligdag', () => {
  it('erstatter de vanlige tilleggene, også på en søndag', () => {
    // MÅLT: Dale 17. mai 2026 er søndag. Kronefila gir KUN 1410 og
    // timelønn — ingen 1434, ingen 1435.
    const f = fordel('2026-05-17', '15:00', '21:00')
    expect(t(f, '1410')).toBe(6)
    expect(f.has('1434')).toBe(false)
    expect(f.has('1435')).toBe(false)
  })

  it('lar dagen etter være en helt vanlig mandag', () => {
    // KANARIFUGL. Uten denne ville en helligdagsregel som traff for
    // bredt — f.eks. hele uken rundt 17. mai — sett riktig ut.
    // MÅLT: Dale 18. mai 2026 har 1429/1430/1431 som normalt.
    const f = fordel('2026-05-18', '15:00', '22:00')
    expect(f.has('1410')).toBe(false)
    expect(t(f, '1429')).toBe(3)
    expect(t(f, '1430')).toBe(1)
  })

  it('starter helligdagen kl. 15 på pinseaften', () => {
    // MÅLT: Dale 23. mai 2026, stemplet 09:00–15:57 → 1410 = 0,96 t.
    // Grensen er skarp, og den er nøyaktig kl. 15.
    const f = fordel('2026-05-23', '09:00', '15:57')
    expect(t(f, '1410')).toBe(0.95)
    expect(f.has('1432')).toBe(false)
  })

  it('gir hele pinseaftenvakten 1410 når den starter etter 15', () => {
    // MÅLT samme dag: 16:00–23:32 → 1410 for hele vakten, ingen 1432.
    const f = fordel('2026-05-23', '16:00', '23:32')
    expect(t(f, '1410')).toBe(7.53)
    expect(f.has('1432')).toBe(false)
  })

  it('behandler lørdagen før 17. mai som en helt vanlig lørdag', () => {
    // KANARIFUGL for aftenregelen. MÅLT: 16. mai 2026 fikk vanlig 1432.
    // Generaliserte vi «dagen før en helligdag», ville denne blitt 1410.
    expect(erHelgaften('2026-05-16')).toBe(false)
    const f = fordel('2026-05-16', '16:00', '23:00')
    expect(t(f, '1432')).toBe(5)
    expect(f.has('1410')).toBe(false)
  })
})

describe('helligdagskalenderen', () => {
  it('finner de bevegelige dagene i 2026', () => {
    // Påskedagen 5. april 2026.
    //
    // RETTET: her sto det at «easy@work betalte 1410 på nøyaktig disse
    // dagene». Det stemmer for Kristi himmelfart og de to pinsedagene,
    // som ligger i Dale mai 2026 — men IKKE for skjærtorsdag,
    // langfredag og 2. påskedag. Vi har ingen kronefil fra april, og
    // påskedagene er derfor modellert, ikke målt.
    //
    // Det som ER bekreftet av dataene, er PÅSKEREGNESTYKKET: easy@work
    // betalte 1410 på påske+39, +49 og +50, altså nøyaktig de dagene
    // formelen peker ut. Selve datoutregningen er verifisert; Easys
    // behandling av de fire påskedagene er det ikke.
    expect(erHelligdag('2026-04-02')).toBe(true) // skjærtorsdag
    expect(erHelligdag('2026-04-03')).toBe(true) // langfredag
    expect(erHelligdag('2026-04-06')).toBe(true) // 2. påskedag
    expect(erHelligdag('2026-05-14')).toBe(true) // Kristi himmelfart
    expect(erHelligdag('2026-05-24')).toBe(true) // 1. pinsedag
    expect(erHelligdag('2026-05-25')).toBe(true) // 2. pinsedag
  })

  it('finner de faste', () => {
    for (const d of ['2026-01-01', '2026-05-01', '2026-05-17', '2026-12-25', '2026-12-26']) {
      expect(erHelligdag(d)).toBe(true)
    }
  })

  it('holder påskeaften, julaften og nyttårsaften UTE', () => {
    // IKKE MÅLT. Vi har kronefil for mai, juli og august 2026 — ingen av
    // dem inneholder disse dagene. Skulle noen generalisere pinseaften
    // hit, skal denne bli rød og tvinge fram en måling først.
    expect(erHelgaften('2026-04-04')).toBe(false) // påskeaften
    expect(erHelgaften('2026-12-24')).toBe(false)
    expect(erHelgaften('2026-12-31')).toBe(false)
    expect(erHelgaften('2026-05-23')).toBe(true) // pinseaften — den målte
  })
})

describe('fordelingen og satsene kjenner de samme artene', () => {
  it('hver art fordelingen kan gi har en sats', () => {
    // KANARIFUGL mot at de to filene skiller lag. En art uten sats
    // ville fått `belopFor` til å kaste midt i en måned, ikke her.
    const arter = new Set<string>()
    // Et helt år, hver time — billig nok, og dekker hver gren.
    for (let d = 0; d < 365; d++) {
      const dato = new Date(Date.UTC(2026, 0, 1 + d)).toISOString().slice(0, 10)
      for (const [fra, til] of [['00:00', '06:00'], ['06:00', '12:00'], ['12:00', '18:00'], ['18:00', '00:00']]) {
        for (const art of fordel(dato, fra, til).keys()) arter.add(art)
      }
    }
    expect(arter.size).toBeGreaterThan(1)
    for (const art of arter) {
      if (art === '2' || art === '1410') continue // andel av timesats, ikke fast
      expect(TILLEGGSSATS[art], `art ${art} mangler sats`).toBeDefined()
    }
  })
})
