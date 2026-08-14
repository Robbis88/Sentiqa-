import { describe, expect, test } from 'vitest'
import { erStemplingFil, parseStempling, vakter } from './stempling'

// Slik teksten faktisk ser ut etter PDF-utpakking: linjeskift midt i felter,
// og navn med ø. Begge deler har brutt en parser her før.
const HODE = 'Forretningsdato Stemplingsnummer Ansatt Type Fra Til Lengde Akkumulert Siden Forrige Lokasjon'
const post = (d: number, nr: string, navn: string, fra: string, til: string, t: number, m: number) =>
  `${d} juli 2026 ${nr} ${navn} Betalt tid ${fra} ${til} ${t}t ${m}m ${t}t ${m}m St1 - Bønes`

describe('stempling', () => {
  test('kjenner igjen fila på kolonneoverskriftene', () => {
    expect(erStemplingFil(HODE)).toBe(true)
    expect(erStemplingFil('Salgsstatistikk 0714')).toBe(false)
  })

  test('leser navn med ø — feilen som gjorde at kveldsvaktene forsvant', () => {
    const r = parseStempling([HODE,
      post(1, '589', 'Helene Løvfall', '12:01', '18:00', 5, 58),
      post(2, '1104270', 'Julian Toro', '18:01', '00:00', 5, 58),
      post(3, '999', 'Leni Forstrønen', '06:00', '12:00', 6, 0),
    ].join(' '))
    expect(r.stemplinger.map((s) => s.ansattNavn))
      .toEqual(['Helene Løvfall', 'Julian Toro', 'Leni Forstrønen'])
  })

  test('kaster hvis en post ikke lot seg lese', () => {
    // To typefelt, men den andre posten mangler klokkeslett.
    const rot = `${HODE} ${post(1, '589', 'Helene Løvfall', '12:01', '18:00', 5, 58)} `
      + '2 juli 2026 589 Helene Løvfall Betalt tid St1 - Bønes'
    expect(() => parseStempling(rot)).toThrow(/2 poster, men bare 1/)
  })

  test('leser dato, tid og lengde', () => {
    const r = parseStempling(`${HODE} ${post(9, '308', 'Drevt Pohlman', '10:00', '18:00', 8, 0)}`)
    expect(r.stemplinger[0]).toMatchObject({
      ansattNr: '308', dato: '2026-07-09', fraTid: '10:00', tilTid: '18:00',
      minutter: 480, betalt: true,
    })
    expect(r.fraDato).toBe('2026-07-09')
    expect(r.lokasjon).toContain('Bønes')
  })

  test('slår sammen ut/inn-stempling på samme vakt', () => {
    // 12:01-18:00 og 18:00-18:13 er én vakt, ikke to.
    const r = parseStempling([HODE,
      post(4, '308', 'Drevt Pohlman', '12:01', '18:00', 5, 58),
      post(4, '308', 'Drevt Pohlman', '18:00', '18:13', 0, 13),
    ].join(' '))
    expect(r.stemplinger).toHaveLength(2)
    const v = vakter(r.stemplinger)
    expect(v).toHaveLength(1)
    expect(v[0].minutter).toBe(371)
    expect(v[0].tilTid).toBe('18:13')
  })

  test('to vakter samme dag med lang pause er to vakter', () => {
    const r = parseStempling([HODE,
      post(5, '308', 'A B', '06:00', '12:00', 6, 0),
      post(5, '308', 'A B', '18:00', '00:00', 6, 0),
    ].join(' '))
    expect(vakter(r.stemplinger)).toHaveLength(2)
  })

  test('avviser en fil som ikke er en Basis Export', () => {
    expect(() => parseStempling('Salgsstatistikk 0714 whatever')).toThrow(/Ikke en Basis Export/)
  })
})

// easy@work kan eksportere samme rapport som CSV. Én fil dekket 19 måneder.
const CSV_HODE = 'Forretningsdato,Stemplingsnummer,Ansatt,Type,Fra,Til,Lengde,Akkumulert,"Siden forrige",Lokasjon'
const csvRad = (d: string, nr: string, navn: string, fra: string, til: string, lengde: string) =>
  `" ${d} ",${nr},"${navn}","Betalt tid"," ${fra}"," ${til}",${lengde},${lengde},0,"St1 - Bønes"`

describe('stempling som CSV', () => {
  test('leser kolonnene ved navn, ikke ved posisjon', () => {
    const r = parseStempling([CSV_HODE,
      csvRad('7 juni 2025', '1104265', 'Carmen Valentina Toro', '12:00', '18:00', '6'),
      csvRad('1 august 2025', '589', 'Helene Løvfall', '12:07', '18:00', '5.88'),
    ].join('\n'))
    expect(r.stemplinger).toHaveLength(2)
    expect(r.stemplinger[0]).toMatchObject({
      ansattNr: '1104265', dato: '2025-06-07', fraTid: '12:00', tilTid: '18:00', minutter: 360,
    })
    // Lengden er desimaltimer i CSV-en, ikke «5t 53m».
    expect(r.stemplinger[1].minutter).toBe(353)
    expect(r.stemplinger[1].ansattNavn).toBe('Helene Løvfall')
    expect(r.lokasjon).toBe('St1 - Bønes')
  })

  test('spenner over flere måneder og finner ytterpunktene', () => {
    const r = parseStempling([CSV_HODE,
      csvRad('7 juni 2025', '1', 'A B', '12:00', '18:00', '6'),
      csvRad('3 januar 2026', '1', 'A B', '06:00', '12:00', '6'),
      csvRad('30 juli 2026', '1', 'A B', '12:00', '18:00', '6'),
    ].join('\n'))
    expect(r.fraDato).toBe('2025-06-07')
    expect(r.tilDato).toBe('2026-07-30')
  })

  test('kaster hvis en rad ikke lot seg lese', () => {
    expect(() => parseStempling([CSV_HODE,
      csvRad('7 juni 2025', '1', 'A B', '12:00', '18:00', '6'),
      '" tullball ",1,"A B","Betalt tid"," 12:00"," 18:00",6,6,0,"St1 - Bønes"',
    ].join('\n'))).toThrow(/forsto ikke datoen/)
  })

  test('komma i et sitert felt splitter ikke raden', () => {
    const r = parseStempling([CSV_HODE,
      '" 7 juni 2025 ",1,"Toro, Carmen","Betalt tid"," 12:00"," 18:00",6,6,0,"St1 - Bønes"',
    ].join('\n'))
    expect(r.stemplinger[0].ansattNavn).toBe('Toro, Carmen')
  })
})
