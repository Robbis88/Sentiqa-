import { describe, expect, it } from 'vitest'
import { erLonnsartFil, gjenkjennLonnsart, lesLonnsart } from './lonnsart'
import { erStemplingFil } from './stempling'

// Formen er hentet fra en ekte eksport (Dale, august 2026, 400 linjer),
// men navnene er byttet ut. Lønn per navngitt person er personopplysninger
// og hører ikke hjemme i et repo.
const RAD = (
  navn: string, nr: string, dato: string, art: string, timer: string, belop: string,
) => `"St1 - Dale","${navn}",${nr},"${dato} 00:00:00",,"${dato} 10:00:00-${dato} 16:00:00","${art}",${timer},"${belop}"`

const FIL = [
  RAD('Anne Berg', '1104238', '2026-08-03', '2 Timelønn', '6.00', '1 542.00'),
  RAD('Anne Berg', '1104238', '2026-08-13', '2 Timelønn', '7.47', '1 920.15'),
  RAD('Bjørn Dal', '1104245', '2026-08-01', '1431 Tillegg hverdag 00-06', '0.32', '10.25'),
  RAD('Bjørn Dal', '1104245', '2026-08-01', '96 50% O.tidstillegg uke', '0.95', '134.74'),
].join('\n')

describe('lesLonnsart', () => {
  it('leser kode, tekst, timer og kroner', () => {
    const r = lesLonnsart(FIL)
    expect(r.rapporttype).toBe('easyatwork_lonnsart')
    expect(r.linjer).toHaveLength(4)
    expect(r.lokasjoner).toEqual(['St1 - Dale'])
    expect(r.fraDato).toBe('2026-08-01')
    expect(r.tilDato).toBe('2026-08-13')

    const f = r.linjer[0]
    expect(f.ansattNr).toBe('1104238')
    expect(f.dato).toBe('2026-08-03')
    expect(f.lonnsart).toBe('2')
    expect(f.lonnsartTekst).toBe('2 Timelønn')
    expect(f.timer).toBe(6)
    // «1 542.00» — tusenskillet er et mellomrom. Uten strippingen blir
    // dette NaN, og linja til null kroner uten at noe klager.
    expect(f.belopKr).toBe(1542)
  })

  it('leser hardt mellomrom som tusenskille', () => {
    const r = lesLonnsart(RAD('A B', '1', '2026-08-03', '2 Timelønn', '6.00', '1 542.00'))
    expect(r.linjer[0].belopKr).toBe(1542)
  })

  // NØKKELEN ER TEKSTEN, IKKE KODEN.
  //
  // Dette er hele grunnen til at `lonnsartTekst` finnes. Lønnsart 97 har
  // fire varianter, og to av dem traff samme person samme dag to ganger i
  // august. En nøkkel på koden alene ville slått dem sammen og spist
  // søndagsovertiden i en 23505 som ser ut som en avvisning.
  it('skiller to varianter av samme kode på samme dag', () => {
    const r = lesLonnsart([
      RAD('Bjørn Dal', '1104245', '2026-08-08', '97 100% O.tidstillegg dag', '1.00', '198.94'),
      RAD('Bjørn Dal', '1104245', '2026-08-08', '97 O.tidstillegg uke 100% søn', '2.00', '570.14'),
    ].join('\n'))

    expect(r.linjer.map((l) => l.lonnsart)).toEqual(['97', '97'])
    const noekler = r.linjer.map((l) => `${l.ansattNr}|${l.dato}|${l.lonnsartTekst}`)
    expect(new Set(noekler).size).toBe(2)
    // Kanarifugl: slår noen sammen koden og teksten igjen, kolliderer disse.
    const paaKode = r.linjer.map((l) => `${l.ansattNr}|${l.dato}|${l.lonnsart}`)
    expect(new Set(paaKode).size).toBe(1)
  })

  it('kaster på en rad den ikke forstår, i stedet for å hoppe over den', () => {
    expect(() => lesLonnsart('"St1 - Dale","A",1,"2026-08-03 00:00:00",,,"2 Timelønn",6'))
      .toThrow(/ventet 9 kolonner, fant 8/)
    expect(() => lesLonnsart(RAD('A', '1', 'i går', '2 Timelønn', '6', '1')))
      .toThrow(/forsto ikke datoen/)
    expect(() => lesLonnsart(RAD('A', '1', '2026-08-03', 'Timelønn', '6', '1')))
      .toThrow(/forsto ikke lønnsarten/)
    expect(() => lesLonnsart(RAD('A', '', '2026-08-03', '2 Timelønn', '6', '1')))
      .toThrow(/ansattnummeret mangler/)
  })
})

describe('gjenkjenning', () => {
  it('kjenner igjen lønnsartfila på formen, ikke på en topprad', () => {
    expect(erLonnsartFil(FIL)).toBe(true)
    expect(gjenkjennLonnsart(FIL)).toBe('easyatwork_lonnsart')
  })

  it('tar ikke Basis Export', () => {
    const basis = [
      'Forretningsdato,Stemplingsnummer,Ansatt,Type,Fra,Til,Lengde,Lokasjon',
      '"13 aug 2026",1104238,"Anne Berg","Betalt tid","07:30","15:00",7.50,"St1 - Dale"',
    ].join('\n')
    expect(erLonnsartFil(basis)).toBe(false)
    expect(gjenkjennLonnsart(basis)).toBe('ukjent')
  })

  // De to eksportene kommer fra samme system og må ikke kunne forveksles.
  // Uten denne ville rekkefølgen i `import/kjerne.ts` vært en usynlig
  // avhengighet i stedet for en påstand.
  it('de to gjenkjennerne overlapper ikke', () => {
    expect(erStemplingFil(FIL)).toBe(false)
  })

  it('sier nei til tomt og til tull', () => {
    expect(erLonnsartFil('')).toBe(false)
    expect(erLonnsartFil('hei,hopp')).toBe(false)
  })
})
