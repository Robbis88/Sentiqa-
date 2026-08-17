import { describe, expect, test } from 'vitest'
import {
  innsynFilnavn, innsynTilMarkdown, maanederSiden, type Innsyn, type Seksjon,
} from './innsyn'

const seksjon = (over: Partial<Seksjon> = {}): Seksjon => ({
  tittel: 'Stemplinger',
  kobling: 'ansattnummer',
  hva: 'Når du har stemplet inn og ut',
  kolonner: ['Dato', 'Fra', 'Til'],
  rader: [['2026-05-02', '06:00', '14:00']],
  ...over,
})

const dok = (seksjoner: Seksjon[]): Innsyn => ({
  navn: 'Alida Nordmann',
  ansattNr: '1042',
  stasjon: 'Lone',
  kjede: 'R-G Invest AS',
  laget: '2026-08-17',
  oppbevaringMaaneder: 60,
  seksjoner,
})

describe('innsynTilMarkdown', () => {
  test('navngir personen og arbeidsstedet øverst', () => {
    const m = innsynTilMarkdown(dok([seksjon()]))
    expect(m).toContain('# Personopplysninger om Alida Nordmann')
    expect(m).toContain('| Ansattnummer | 1042 |')
    expect(m).toContain('| Arbeidssted | Lone |')
  })

  test('hver seksjon sier hvordan den ble koblet', () => {
    const m = innsynTilMarkdown(dok([
      seksjon(),
      seksjon({ tittel: 'Ferie og fravær', kobling: 'navn', hva: 'Registrert fravær' }),
    ]))
    expect(m).toContain('Koblet på **ansattnummer**')
    expect(m).toContain('Koblet på **navn**')
  })

  test('den usikre koblingen forklares, ikke bare merkes', () => {
    const m = innsynTilMarkdown(dok([seksjon({ kobling: 'navn' })]))
    expect(m).toContain('Heter noen andre det samme')
  })

  test('tomme kategorier listes — ellers ser de ut som noe vi glemte', () => {
    const m = innsynTilMarkdown(dok([
      seksjon(),
      seksjon({ tittel: 'Merker', hva: 'Merker du har fått', rader: [] }),
    ]))
    expect(m).toContain('## Kategorier uten registreringer')
    expect(m).toContain('- Merker — Merker du har fått')
    // Den tomme skal ikke få sin egen tabelloverskrift lenger opp.
    expect(m).not.toContain('## Merker')
  })

  test('rader kommer med, og tomme celler blir tankestrek', () => {
    const m = innsynTilMarkdown(dok([seksjon({
      kolonner: ['Dato', 'Merknad'],
      rader: [['2026-05-02', null], ['2026-05-03', '']],
    })]))
    expect(m).toContain('| 2026-05-02 | — |')
    expect(m).toContain('| 2026-05-03 | — |')
  })

  test('loddrett strek i data bryter ikke tabellen', () => {
    const m = innsynTilMarkdown(dok([seksjon({
      kolonner: ['Felt'], rader: [['a|b']],
    })]))
    expect(m).toContain('a\\|b')
  })

  test('forteller om oppbevaring og retten til å klage', () => {
    const m = innsynTilMarkdown(dok([seksjon()]))
    expect(m).toContain('60 måneder')
    expect(m).toContain('Datatilsynet')
    expect(m).toContain('bokføringsloven')
  })

  test('tåler at det ikke finnes noe som helst', () => {
    const m = innsynTilMarkdown(dok([]))
    expect(m).toContain('# Personopplysninger om Alida Nordmann')
    expect(m).not.toContain('Kategorier uten registreringer')
  })
})

describe('maanederSiden', () => {
  test('teller hele måneder', () => {
    expect(maanederSiden('2021-08-17', '2026-08-17')).toBe(60)
    expect(maanederSiden('2026-05-01', '2026-08-01')).toBe(3)
  })

  test('runder NED når dagen ikke er nådd — feilen må ikke slette for tidlig', () => {
    // 15. mai til 14. november er fem måneder, ikke seks.
    expect(maanederSiden('2026-05-15', '2026-11-14')).toBe(5)
    expect(maanederSiden('2026-05-15', '2026-11-15')).toBe(6)
  })

  test('dagen før fristen er ute havner ikke på slettelista', () => {
    // 60 måneders frist: 16. august er 59, 17. august er 60.
    expect(maanederSiden('2021-08-17', '2026-08-16')).toBe(59)
    expect(maanederSiden('2021-08-17', '2026-08-17')).toBe(60)
  })

  test('krysser årsskiftet riktig', () => {
    expect(maanederSiden('2025-11-30', '2026-01-30')).toBe(2)
    expect(maanederSiden('2025-12-31', '2026-01-01')).toBe(0)
  })
})

describe('innsynFilnavn', () => {
  test('navn og dato i filnavnet, uten tegn som brekker nedlastingen', () => {
    expect(innsynFilnavn('Alida Nordmann', '2026-08-17'))
      .toBe('Personopplysninger - Alida Nordmann - 2026-08-17.md')
    expect(innsynFilnavn('Bjørn/Ø:se', '2026-08-17'))
      .toBe('Personopplysninger - BjørnØse - 2026-08-17.md')
  })
})
