import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  aktive, erSystem, importsaker, importtekst, SYSTEMMERKER, type Jobbrad,
} from './importsak'

// =====================================================================
// HENDELSE, SAK, TILSTAND
// =====================================================================
//
// Målt i produksjon 2026-09-17: 1 897 importjobber, 4 med status
// «feilet», 25 uleste varsler fra 12 strukturelt ulike filer. Forsiden
// viste 25 kort.
//
// Testene under feller de tre måtene det kan bli 25 igjen:
//
//   1  varselet blir kort per rad på nytt
//   2  tilstanden leses av varselet i stedet for jobben
//   3  en løst sak fortsetter å telle
// =====================================================================

const j = (
  fil: string, status: string, tid: string, navn = 'export.csv (27).csv',
): Jobbrad => ({
  id: `jobb-${fil}-${tid}`, raa_fil_id: fil, status, stasjon_id: 's1',
  feilmelding: status === 'feilet' ? 'Kunne ikke lese fil' : null,
  opprettet_tid: tid, raa_filer: { filnavn: navn },
})

describe('saken er fila, hendelsene er forsoekene', () => {
  it('fem forsoek paa samme fil er ÉN sak med fem hendelser', () => {
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
      j('f1', 'feilet', '2026-09-01T11:00:00Z'),
      j('f1', 'feilet', '2026-09-01T12:00:00Z'),
      j('f1', 'feilet', '2026-09-01T13:00:00Z'),
      j('f1', 'feilet', '2026-09-01T14:00:00Z'),
    ])
    expect(s).toHaveLength(1)
    expect(s[0].hendelser).toHaveLength(5)
    expect(s[0].tilstand).toBe('aktiv')
  })

  it('to ulike filer er to saker, ogsaa med samme filnavn', () => {
    // Maalt: 133 filnavn dekker mer enn én fil, ett av dem aatte.
    // Tekstbasert gruppering ville gjort disse til én.
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z', 'samme.xlsx'),
      j('f2', 'feilet', '2026-09-01T11:00:00Z', 'samme.xlsx'),
    ])
    expect(s).toHaveLength(2)
  })

  it('HISTORIKKEN FORSVINNER IKKE naar saken er loest', () => {
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
      j('f1', 'feilet', '2026-09-01T11:00:00Z'),
      j('f1', 'ferdig', '2026-09-01T12:00:00Z'),
    ])
    expect(s[0].tilstand).toBe('ikke_aktiv')
    expect(s[0].hendelser).toHaveLength(3)
    expect(s[0].hendelser.filter((h) => h.status === 'feilet')).toHaveLength(2)
  })
})

describe('tilstanden leses av SISTE jobb', () => {
  it('siste jobb ferdig -> ikke aktiv, selv med feil foer', () => {
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
      j('f1', 'ferdig', '2026-09-01T12:00:00Z'),
    ])
    expect(s[0].sisteStatus).toBe('ferdig')
    expect(s[0].tilstand).toBe('ikke_aktiv')
  })

  it('siste jobb feilet -> aktiv, selv med suksess foer', () => {
    const s = importsaker([
      j('f1', 'ferdig', '2026-09-01T10:00:00Z'),
      j('f1', 'feilet', '2026-09-01T12:00:00Z'),
    ])
    expect(s[0].tilstand).toBe('aktiv')
  })

  it('REKKEFOELGEN PAA INNGANGEN BESTEMMER INGENTING', () => {
    // Et kallsted som glemmer `order` skal ikke stille gi feil «siste
    // status». Det er den formen for feil som ser ut som data.
    const rader = [
      j('f1', 'ferdig', '2026-09-01T12:00:00Z'),
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
    ]
    expect(importsaker(rader)[0].tilstand).toBe('ikke_aktiv')
    expect(importsaker([...rader].reverse())[0].tilstand).toBe('ikke_aktiv')
  })
})

describe('teksten paa forsiden', () => {
  it('er null naar ingen sak er aktiv — da staar det ingenting', () => {
    const s = importsaker([j('f1', 'ferdig', '2026-09-01T12:00:00Z')])
    expect(aktive(s)).toHaveLength(0)
    expect(importtekst(s)).toBeNull()
  })

  it('sier hvor mange forsoek — skjuler ikke at det har skjedd flere ganger', () => {
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
      j('f1', 'feilet', '2026-09-01T11:00:00Z'),
      j('f1', 'feilet', '2026-09-01T12:00:00Z'),
    ])
    const t = importtekst(s)!
    expect(t).toContain('3 forsøk')
    expect(t).toContain('1 fil')
  })

  it('SIER IKKE MER ENN JOBBSTATUS BEVISER', () => {
    // «Siste jobb staar ikke som feilet» beviser at siste FORSOEK ikke
    // feilet - ikke at dataene er korrekte eller komplette. En import
    // kan lykkes teknisk og likevel mangle en stasjon.
    const t = importtekst(importsaker([j('f1', 'feilet', '2026-09-01T10:00:00Z')]))!
    expect(t).toContain('Siste forsøk feilet')
    expect(t).not.toMatch(/data(ene)? mangler|ikke importert|gikk tapt/i)
  })

  it('teller forsoek paa tvers av flere aktive filer', () => {
    const s = importsaker([
      j('f1', 'feilet', '2026-09-01T10:00:00Z'),
      j('f1', 'feilet', '2026-09-01T11:00:00Z'),
      j('f2', 'feilet', '2026-09-01T12:00:00Z'),
      j('f3', 'ferdig', '2026-09-01T13:00:00Z'),
    ])
    expect(importtekst(s)).toContain('2 filer')
    expect(importtekst(s)).toContain('3 forsøk')
  })
})

describe('drift mot system', () => {
  it('Import og Systemet er system, resten er drift', () => {
    expect(erSystem('Import')).toBe(true)
    expect(erSystem('Systemet')).toBe(true)
    expect(erSystem('Mulig utsolgt')).toBe(false)
    expect(erSystem('Treffsikkerhet')).toBe(false)
    expect(erSystem('Regnskap')).toBe(false)
    expect(erSystem('Bemanning')).toBe(false)
    expect(erSystem('IK-mat')).toBe(false)
  })

  it('KANARIFUGL — settet er ikke tomt', () => {
    // Blir `SYSTEMMERKER` tom, er hver rad drift igjen og delingen
    // forsvinner uten at noe blir roedt.
    expect(SYSTEMMERKER.size).toBeGreaterThan(0)
  })
})

// ---------------------------------------------------------------------
// FLATEN MAA FAKTISK BRUKE DETTE
// ---------------------------------------------------------------------
//
// Alt over kan vaere groent mens `butikksjef-dashbord.tsx` fortsatt
// pusher ett kort per varselrad. Det er det den porten skulle fjerne, og
// det kan ikke ses fra denne modulen.
const utenKommentarer = (s: string) =>
  s.replace(/\/\*[\s\S]*?\*\//g, '').split('\n')
    .filter((l) => !l.trim().startsWith('//'))
    .map((l) => l.replace(/\s\/\/.*$/, ''))
    .join('\n')

const SJEF = utenKommentarer(
  readFileSync('src/app/(beskyttet)/butikksjef-dashbord.tsx', 'utf8'))
const OPP = utenKommentarer(
  readFileSync('src/app/(beskyttet)/oppmerksomhet.tsx', 'utf8'))

describe('flaten bruker saken, ikke varselraden', () => {
  it('importvarsler blir ikke kort per rad', () => {
    expect(SJEF).toContain("if (v.type.startsWith('import_')) continue")
  })

  it('importsaken kommer fra jobbene', () => {
    expect(SJEF).toContain("from('import_jobber')")
    expect(SJEF).toContain('importsaker(')
    expect(SJEF).toContain('importtekst(')
  })

  it('kortet legges bare til naar teksten finnes', () => {
    // `importtekst` er null naar ingen sak er aktiv. Et `if` som mangler
    // her ville gitt et tomt kort som alltid staar der.
    expect(SJEF).toMatch(/const impTekst = importtekst\([^)]*\)\s*\n\s*if \(impTekst\)/)
  })

  it('oppmerksomhetsflaten deler paa merke, ikke paa tekst', () => {
    // BEGGE BOLKENE MAA VAERE UTLEDET AV FILTERET.
    //
    // Foerste utgave krevde bare at `erSystem` sto et sted i fila. Den
    // var groenn med systembolkens `rader` satt til `[]` — filteret laa
    // fortsatt i driftbolken og i overskriften, saa ordet fantes. Da var
    // delingen borte og vakta saa det ikke.
    expect(OPP, 'driftbolken er ikke utledet av erSystem')
      .toContain('signaler.filter((x) => !erSystem(x.merke))')
    expect(OPP, 'systembolken er ikke utledet av erSystem')
      .toContain('signaler.filter((x) => erSystem(x.merke))')
    expect(OPP).not.toMatch(/tittel[^\n]*includes\(['"]Import/)
  })

  it('overskriften teller bare driften', () => {
    const f = OPP.slice(OPP.indexOf('function overskrift'), OPP.indexOf('export function Oppmerksomhet'))
    expect(f).toContain('erSystem')
    expect(f).toContain('drift')
  })
})
