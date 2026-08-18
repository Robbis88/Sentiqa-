import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  borte, borteI, lenker, menypunkter, rutenavn, seksjoner, serverhandlinger,
  type Fasit,
} from './fasit'

// =====================================================================
// Vakthund for redesignet.
//
// «Ingen funksjoner skal forsvinne» er hovedkravet i bestillingen, og
// et løfte er ikke en garanti. Denne leser kildekoden, bygger fasit paa
// nytt, og feiler hvis noe er borte.
//
// Den forbyr ikke endring. Skal noe faktisk fjernes eller slaas sammen,
// oppdaterer du fasiten med vilje:
//
//     OPPDATER_FASIT=1 npx vitest run src/lib/redesign
//
// Da viser git nøyaktig hva som ble gitt slipp paa. Forskjellen paa aa
// FLYTTE noe og aa MISTE det, er om noen skrev det ned.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app')
const FASIT = join(ROT, 'src', 'lib', 'redesign', 'fasit.json')

function filer(mappe: string, treff: (n: string) => boolean): string[] {
  const ut: string[] = []
  for (const rad of readdirSync(mappe, { withFileTypes: true })) {
    const sti = join(mappe, rad.name)
    if (rad.isDirectory()) ut.push(...filer(sti, treff))
    else if (treff(rad.name)) ut.push(sti)
  }
  return ut
}

function byggFasit(): Fasit {
  const sider = filer(APP, (n) => n === 'page.tsx')
  const ruter = sider.map(rutenavn).sort()

  const seksjonKart: Record<string, string[]> = {}
  const lenkeKart: Record<string, string[]> = {}
  for (const sti of sider) {
    const kilde = readFileSync(sti, 'utf8')
    const rute = rutenavn(sti)
    const s = seksjoner(kilde)
    const l = lenker(kilde)
    if (s.length > 0) seksjonKart[rute] = s
    if (l.length > 0) lenkeKart[rute] = l
  }

  // Serverhandlinger samles per MAPPE, ikke per side: de ligger i egne
  // filer og deles ofte av flere sider under samme omraade.
  const handlingKart: Record<string, string[]> = {}
  for (const sti of filer(APP, (n) => n.endsWith('.ts') && !n.includes('.test.'))) {
    const funksjoner = serverhandlinger(readFileSync(sti, 'utf8'))
    if (funksjoner.length === 0) continue
    const omraade = rutenavn(sti.replace(/[^\\/]+$/, 'page.tsx'))
    handlingKart[omraade] = [...(handlingKart[omraade] ?? []), ...funksjoner].sort()
  }

  return {
    ruter,
    meny: menypunkter(readFileSync(join(APP, '(beskyttet)', 'layout.tsx'), 'utf8')),
    handlinger: handlingKart,
    seksjoner: seksjonKart,
    lenker: lenkeKart,
  }
}

const naa = byggFasit()

if (process.env.OPPDATER_FASIT) {
  writeFileSync(FASIT, `${JSON.stringify(naa, null, 2)}\n`, 'utf8')
}

const fasit: Fasit | null = existsSync(FASIT)
  ? JSON.parse(readFileSync(FASIT, 'utf8')) as Fasit
  : null

const hjelp = 'Er dette meningen, kjør: OPPDATER_FASIT=1 npx vitest run src/lib/redesign '
  + '— og la diffen i git vise hva som ble gitt slipp på.'

describe('funksjonsbevaring', () => {
  test('fasiten finnes', () => {
    expect(fasit, 'Fasit mangler. Lag den med OPPDATER_FASIT=1.').not.toBeNull()
  })

  // --- HARDT: dette skal aldri forsvinne i stillhet ---

  test('ingen rute er borte', () => {
    expect(borte(fasit!.ruter, naa.ruter), `Ruter borte. ${hjelp}`).toEqual([])
  })

  test('ingen ansatt har mistet tilgang til en side', () => {
    // Bade stien og rollelista sammenlignes. Blir /lonn liggende, men
    // uten butikksjef, har butikksjefen mistet lonnsgrunnlaget sitt.
    expect(borte(fasit!.meny, naa.meny), `Menypunkt eller roller endret. ${hjelp}`)
      .toEqual([])
  })

  test('ingen serverhandling er borte', () => {
    // En knapp kan flyttes til et sidepanel uten tap. Blir handlingen
    // bak den borte, er en evne borte.
    expect(borteI(fasit!.handlinger, naa.handlinger), `Handlinger borte. ${hjelp}`)
      .toEqual({})
  })

  // --- MYKT: skal endres, men ikke umerket ---

  test('ingen seksjon er borte uten at det er erklært', () => {
    expect(borteI(fasit!.seksjoner, naa.seksjoner), `Seksjoner borte. ${hjelp}`)
      .toEqual({})
  })

  test('ingen navigasjonsvei er borte uten at det er erklært', () => {
    // Den lumske varianten: alt finnes, men ingen kommer seg dit.
    expect(borteI(fasit!.lenker, naa.lenker), `Lenker borte. ${hjelp}`).toEqual({})
  })

  // --- At vakthunden faktisk maaler noe ---

  test('den ser hele systemet — ellers er den grønn av feil grunn', () => {
    expect(naa.ruter.length).toBeGreaterThan(60)
    expect(naa.meny.length).toBeGreaterThan(40)
    expect(Object.keys(naa.handlinger).length).toBeGreaterThan(20)
  })
})
