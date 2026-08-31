import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative, dirname } from 'node:path'
import { RUTEMONSTER, SPALTE, monsterFor, MONSTRE, type Monster } from './monstre'

// =====================================================================
// SIDERAMMEN HAR TRE MÅTER Å SLUTTE Å VIRKE PÅ, OG INGEN AV DEM ROPER
//
//   1. Skallet slutter å sette `data-bredde`  → alt blir smalt i stillhet.
//   2. CSS-en mister `[data-bredde='bred']`   → alt blir smalt i stillhet.
//   3. En side wrappes uten å stå i mønster-  → siden blir smal i stillhet.
//      kartet
//
// Alle tre gir en side som ser ut som en side. Det er derfor de måles her
// og ikke overlates til øyet. Hver kontroll har en kanarifugl som sier
// hvordan man ser at den fortsatt måler.
// =====================================================================

const ROT = process.cwd()
const APP = join(ROT, 'src', 'app')
const les = (...p: string[]) => readFileSync(join(ROT, ...p), 'utf8')

function sider(rot: string): string[] {
  const ut: string[] = []
  for (const n of readdirSync(rot)) {
    const p = join(rot, n)
    if (statSync(p).isDirectory()) { ut.push(...sider(p)); continue }
    if (n === 'page.tsx') ut.push(p)
  }
  return ut
}
const ruteFor = (p: string) =>
  ('/' + relative(APP, dirname(p)).replace(/\\/g, '/')
    .replace(/\(.*?\)\/?/g, '').replace(/\/$/, '')) || '/'

describe('Sideramme: bredden kommer fra mønsteret', () => {
  it('hvert mønster har en bredde, og bare de to som finnes i CSS-en', () => {
    // Typen `Record<Monster, Bredde>` sikrer at ingen glemmes. Denne
    // kontrollen sikrer det motsatte: at ingen verdi er oppfunnet som
    // CSS-en ikke kjenner — `data-bredde="middels"` ville gitt smal side
    // uten et eneste varsel.
    const kjente = new Set(['smal', 'bred'])
    for (const m of Object.keys(MONSTRE) as Monster[]) {
      expect(SPALTE[m], `mønsteret «${m}» mangler bredde`).toBeDefined()
      expect(kjente, `«${m}» har bredde «${SPALTE[m]}» som CSS-en ikke kjenner`)
        .toContain(SPALTE[m])
    }
  })

  it('KANARIFUGL: skallet setter data-bredde på .innhold', () => {
    // Forsvinner attributtet, faller `--sq-spalte` til standarden og HELE
    // systemet blir 880 px. Ingen test ville ellers merket det — sidene
    // rendrer like fint, bare feil.
    const skall = les('src', 'app', '(beskyttet)', 'appskall.tsx')
    expect(skall, 'appskall.tsx setter ikke lenger data-bredde på .innhold')
      .toMatch(/className="innhold"[^>]*data-bredde=\{bredde\}/)

    const layout = les('src', 'app', '(beskyttet)', 'layout.tsx')
    expect(layout, 'layouten utleder ikke lenger bredden av mønsteret')
      .toMatch(/monsterFor\(/)
    expect(layout, 'layouten leser ikke lenger SPALTE').toMatch(/SPALTE\[/)
  })

  it('KANARIFUGL: CSS-en har både standarden og unntaket', () => {
    // Mister `[data-bredde='bred']`, blir analysesidene 880 px brede med
    // tabeller som ikke får plass — og attributtet står der fortsatt, så
    // det ser riktig ut i DOM-en.
    const css = les('src', 'components', 'ui', 'ui.css')
    expect(css, 'standardbredden --sq-spalte mangler')
      .toMatch(/\.innhold\s*\{\s*--sq-spalte:/)
    expect(css, 'unntaket [data-bredde=\'bred\'] mangler')
      .toMatch(/\.innhold\[data-bredde='bred'\]\s*\{\s*--sq-spalte:\s*none/)
    expect(css, '.sq-sideramme leser ikke --sq-spalte')
      .toMatch(/\.sq-sideramme\s*\{[^}]*max-width:\s*var\(--sq-spalte\)/)
  })

  it('hver side som bruker rammen står i mønsterkartet', () => {
    // Uten mønster får siden `smal` av sikkerhetsgrunner. Det er trygt,
    // men det er ikke en beslutning — og en analysesidesom havner der
    // ville blitt smal uten at noen valgte det.
    const uten: string[] = []
    for (const p of sider(APP)) {
      if (!/\bSideramme\b/.test(readFileSync(p, 'utf8'))) continue
      const r = ruteFor(p)
      if (!RUTEMONSTER[r]) uten.push(r)
    }
    expect(uten, `bruker Sideramme uten å stå i RUTEMONSTER: ${uten.join(', ')}`)
      .toEqual([])
  })

  it('ingen migrert side setter sin egen bredde', () => {
    // Poenget med rammen er at bredden har én eier. En side som legger på
    // `max-width` selv har tatt den tilbake, og da er vi der vi startet.
    const synder: string[] = []
    for (const p of sider(APP)) {
      const k = readFileSync(p, 'utf8')
      if (!/\bSideramme\b/.test(k)) continue
      if (/max-?[Ww]idth/.test(k)) synder.push(ruteFor(p))
    }
    expect(synder, `setter egen bredde inni Sideramme: ${synder.join(', ')}`).toEqual([])
  })
})

describe('monsterFor', () => {
  it('finner mønsteret for hver rute i kartet', () => {
    for (const rute of Object.keys(RUTEMONSTER)) {
      expect(monsterFor(rute), `fant ikke mønster for ${rute}`).toBe(RUTEMONSTER[rute])
    }
  })

  it('KANARIFUGL: en ekte id treffer den dynamiske ruta', () => {
    // Nettleseren ber om `/kontrakt/9f2c-…`, kartet har `/kontrakt/[id]`.
    // Uten oversettelsen faller HVER detaljside tilbake til standarden —
    // og siden detalj ER smal, ville feilen vært usynlig i dag og dukket
    // opp første gang et detaljmønster ble bredt.
    expect(monsterFor('/kontrakt/9f2c-4a1b-8e7d')).toBe('detalj')
    expect(monsterFor('/puls/42')).toBe('detalj')
    expect(monsterFor('/rutiner/oppsett/abc')).toBe('detalj')
    // Og den skal ikke finne på noe: /kontrakt/[id] må ikke gjøre
    // /kontrakt/a/b til en detaljside.
    expect(monsterFor('/finnes-ikke')).toBeNull()
  })

  it('tåler etterslepende skråstrek', () => {
    expect(monsterFor('/salg/')).toBe(RUTEMONSTER['/salg'])
  })
})
