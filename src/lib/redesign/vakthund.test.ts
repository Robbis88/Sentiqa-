import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  borte, borteI, lenker, naabarhet, rutenavn, rutetre, seksjoner, serverhandlinger,
  type Fasit,
} from './fasit'
import { MONSTRE, RUTEMONSTER, TABLETRUTER } from './monstre'

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

  // EN LESING PER FIL. Komponenter deles mellom ruter - `oppmerksomhet`
  // rendres av begge dashbordene - og uten hurtigbufferen leses de om
  // igjen for hver rute som naar dem.
  const buffer = new Map<string, string | null>()
  const les = (sti: string): string | null => {
    if (!buffer.has(sti)) {
      try { buffer.set(sti, readFileSync(sti, 'utf8')) }
      catch { buffer.set(sti, null) }
    }
    return buffer.get(sti) ?? null
  }

  const seksjonKart: Record<string, string[]> = {}
  const lenkeKart: Record<string, string[]> = {}
  for (const sti of sider) {
    const rute = rutenavn(sti)

    // SEKSJONENE LESES AV HELE RUTENS UI-TRE, ikke bare page.tsx.
    // /produksjonsplan har hele plantabellen i en klientkomponent; den
    // var usynlig for vakten fram til trinn 08.
    const treet = rutetre(sti, les, APP)
    const s = [...new Set(treet.flatMap((f) => seksjoner(les(f) ?? '')))].sort()

    // LENKENE LESES FORTSATT BARE AV page.tsx. Det er ikke glemt: en
    // delt komponent tar med seg lenkene sine til hver rute som rendrer
    // den, og navigasjonsveiene ut av en side ville da blitt en liste
    // over alt appskallet og dashbordkortene peker paa. Skal de
    // utvides, er det en egen vurdering med egen begrunnelse.
    const l = lenker(les(sti) ?? '')

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
    naabart: naabarhet(readFileSync(join(APP, '(beskyttet)', 'navigasjon.ts'), 'utf8')),
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

  test('ingen rolle har mistet tilgang til en side', () => {
    // Maalt paa NAABARHET, ikke paa menylinjer: aa flytte en side fra
    // menyen til en fane er en omorganisering, aa ta den ut av begge er
    // et tap. En fasit som teller menylinjer ville ropt paa det forste
    // og vaert blind for forskjellen.
    expect(borteI(fasit!.naabart, naa.naabart), `Noen mistet tilgang. ${hjelp}`)
      .toEqual({})
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

  // --- Klassifiseringen ---

  test('hver rute har et mønster', () => {
    // Uten dette blir hver side lost for seg, og systemet ender som 68
    // sider bygget paa 68 tidspunkt - det vi proever aa komme oss vekk
    // fra. Legger noen til en side uten aa ta stilling til hva slags
    // side det er, stopper det her.
    const uten = naa.ruter.filter((r) => !(r in RUTEMONSTER))
    expect(uten, 'Ruter uten mønster. Velg ett i src/lib/redesign/monstre.ts.')
      .toEqual([])
  })

  test('ingen mønster peker på en rute som ikke finnes', () => {
    const finnes = new Set(naa.ruter)
    expect(Object.keys(RUTEMONSTER).filter((r) => !finnes.has(r))).toEqual([])
  })

  test('hvert mønster har en spesifikasjon', () => {
    for (const m of new Set(Object.values(RUTEMONSTER))) {
      expect(MONSTRE[m], m).toBeDefined()
      expect(MONSTRE[m].nivaa1.length, `nivaa1 for ${m}`).toBeGreaterThan(10)
      expect(MONSTRE[m].fella.length, `fella for ${m}`).toBeGreaterThan(20)
    }
  })

  test('nettbrettrutene finnes og deler rute med desktop', () => {
    const finnes = new Set(naa.ruter)
    for (const r of TABLETRUTER) expect(finnes.has(r), r).toBe(true)
  })

  // --- At vakthunden faktisk maaler noe ---

  test('den ser hele systemet — ellers er den grønn av feil grunn', () => {
    expect(naa.ruter.length).toBeGreaterThan(60)
    expect(Object.keys(naa.naabart).length).toBeGreaterThan(3)
    expect(naa.naabart['butikksjef'].length).toBeGreaterThan(25)
    expect(Object.keys(naa.handlinger).length).toBeGreaterThan(20)
  })
})
