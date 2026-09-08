import { describe, expect, test } from 'vitest'
import { ukjenteKontoer, ukjentKontoNotat } from './ukjentkonto'

// =====================================================================
// FUNNET KOM FRA SONDEN, IKKE FRA EN TEST
//
// `0192` skulle bare gjøre `BUTIKKSJEF_KOSTNAD_KODER` til en RLS-grense.
// Sonden mot produksjon 2026-09-08 listet hva som ville forsvinne, og to
// av radene het `Konto 739` og `Konto 745` — altså koder kontoplanen i
// `src/lib/parsere/regnskap.ts` ikke kjenner. De er på 0 og 512 kroner.
//
// Beløpene er poenget mindre. Mekanismen er: parseren skriver
// `KONTO_NAVN[kk] ?? \`Konto ${kk}\`` og går videre, i stillhet. Fra
// `0192` avgjør den samme stillheten dessuten en tenantregel — en ukjent
// konto er eierens, fordi vi ikke vet bedre.
//
// Det er riktig som standard. Det er galt som noe ingen får vite.
// =====================================================================

const linje = (kode: string, post: string, seksjon = 'driftskostnader') =>
  ({ seksjon, kode, post })

describe('ukjenteKontoer', () => {
  test('finner kodene parseren ikke fant navn til', () => {
    expect(ukjenteKontoer([
      linje('627', 'Renhold'),
      linje('739', 'Konto 739'),
      linje('745', 'Konto 745'),
    ])).toEqual(['739', '745'])
  })

  test('sier ingenting om en kontoplan som holder', () => {
    expect(ukjenteKontoer([
      linje('501', 'Faste lønninger'),
      linje('622', 'Royalty'),
    ])).toEqual([])
  })

  test('teller hver kode én gang', () => {
    // Fem stasjoner gir fem rader per konto. Merknaden skal si «739»,
    // ikke «739, 739, 739, 739, 739».
    expect(ukjenteKontoer([
      linje('739', 'Konto 739'), linje('739', 'Konto 739'), linje('739', 'Konto 739'),
    ])).toEqual(['739'])
  })

  test('ser bare på driftskostnader', () => {
    // Omsetning og bruttofortjeneste har sine egne poster fra fila og
    // bruker ikke kontoplanen. En «Konto»-tekst der er ikke det samme.
    expect(ukjenteKontoer([linje('40', 'Konto 40', 'omsetning')])).toEqual([])
  })

  test('KANARIFUGL: et ekte kontonavn ligner ikke på fallbacken', () => {
    // Regelen leser posttekst. Ble mønsteret for løst — «Konto» uten
    // tallkravet — ville et framtidig navn som «Kontorrekvisita» blitt
    // meldt som ukjent, og en vakt med falske funn er en vakt folk
    // slutter å lese.
    expect(ukjenteKontoer([linje('638', 'Kontorrekvisita')])).toEqual([])
    expect(ukjenteKontoer([linje('636', 'Pengehåndtering')])).toEqual([])
  })
})

describe('ukjentKontoNotat', () => {
  test('navngir kodene, ikke bare antallet', () => {
    const n = ukjentKontoNotat(['739', '745'])!
    expect(n).toContain('739')
    expect(n).toContain('745')
    expect(n, 'skal peke på hva man gjør med det').toContain('KONTO_NAVN')
  })

  test('sier fra at ukjent = eierens', () => {
    // Den delen er ny fra 0192, og den er ikke opplagt: før var en ukjent
    // konto bare et manglende navn. Nå er den også en tilgangsregel.
    expect(ukjentKontoNotat(['739'])).toContain('0192')
  })

  test('er null når alt har navn', () => {
    expect(ukjentKontoNotat([])).toBeNull()
  })
})
