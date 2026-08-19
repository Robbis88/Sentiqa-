import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// =====================================================================
// Alt som summerer timer skal lese `v_stempling_aktiv`, ikke `stempling`.
//
// Under parallellkjøring finnes samme vakt to ganger: én fra easy@work-
// importen og én avledet fra nettbrettet. De KOLLIDERER IKKE, fordi den
// unike nøkkelen inneholder `fra_tid` og de to kildene ikke gir samme
// minutt — nettbrettet har det faktiske, easy@work et avrundet. De
// legger seg ved siden av hverandre, og timene dobles.
//
// Det er den farligste feilen dette systemet kan gjøre, fordi den ser ut
// som vekst: flere timer i lønnsfila, høyere stillingsanslag, og
// kontraktsvarsler som ser ekte ut. Ingen av dem stemmer.
//
// Samme form som drivstoffregelen for `daglig_salg` i AGENTS.md — og av
// samme grunn: en regel ingen kan glemme er bedre enn en regel alle
// kjenner.
// =====================================================================

const SRC = join(process.cwd(), 'src')

/** Filer som har lov til å røre tabellen direkte, med grunn. */
const UNNTAK: Record<string, string> = {
  // Avledningen SKRIVER radene. Den må treffe tabellen — et view kan
  // ikke ta imot insert her, og den setter selv `kilde = 'tablet'`.
  'lib/stempling/skriv.ts': 'skriver de avledte radene',
  // Avstemmingen skal se BEGGE kilder ved siden av hverandre — det er
  // hele poenget med den. Resten av samme side leser v_stempling_aktiv.
  'app/(beskyttet)/lonn/page.tsx': 'avstemmer import mot tablet',
}

function alleKildefiler(katalog: string): string[] {
  const ut: string[] = []
  for (const navn of readdirSync(katalog)) {
    const sti = join(katalog, navn)
    if (statSync(sti).isDirectory()) {
      ut.push(...alleKildefiler(sti))
    } else if (/\.tsx?$/.test(navn) && !/\.test\.tsx?$/.test(navn)) {
      ut.push(sti)
    }
  }
  return ut
}

const filer = alleKildefiler(SRC)

function relativ(sti: string): string {
  return sti.slice(SRC.length + 1).replace(/\\/g, '/')
}

describe('kilden for timer', () => {
  it('leser ingen andre enn avledningen `stempling` direkte', () => {
    const syndere = filer
      .filter((f) => /\.from\('stempling'\)/.test(readFileSync(f, 'utf8')))
      .map(relativ)
      .filter((f) => !(f in UNNTAK))
      .sort()

    expect(syndere).toEqual([])
  })

  // KANARIFUGL. Slutter uttrekket å finne filer — katalogen flyttes,
  // endelsene endres, mønsteret slutter å treffe — blir lista tom og
  // testen grønn uten å ha målt noe. Den skal se hele kodebasen.
  it('leser faktisk kildefilene', () => {
    expect(filer.length).toBeGreaterThan(100)
    const treff = filer.filter((f) => /v_stempling_aktiv/.test(readFileSync(f, 'utf8')))
    expect(treff.length).toBeGreaterThanOrEqual(3)
  })

  // Unntakslista skal ikke gro. Står det noe der som ikke lenger finnes,
  // er unntaket dødt og skjuler ingenting — men da vet vi heller ikke om
  // det fortsatt trengs.
  it('har bare unntak som finnes', () => {
    const finnes = new Set(filer.map(relativ))
    for (const f of Object.keys(UNNTAK)) expect(finnes.has(f)).toBe(true)
  })

  // Regelen skal også gjelde nye SQL-funksjoner, slik drivstoffregelen
  // gjør. Viewet er poenget; en migrasjon som summerer minutter rett fra
  // tabellen ville omgått hele sikringen.
  it('lar ingen migrasjon etter 0111 summere minutter fra tabellen', () => {
    const kat = join(process.cwd(), 'supabase', 'migrations')
    const etter = readdirSync(kat)
      .filter((n) => /^0(1[1-9][2-9]|[2-9]\d\d)_/.test(n) || /^[1-9]\d{3}_/.test(n))
    const syndere = etter.filter((n) => {
      const sql = readFileSync(join(kat, n), 'utf8').toLowerCase()
      return /sum\(\s*minutter\s*\)/.test(sql) && /from\s+public\.stempling\b/.test(sql)
    })
    expect(syndere).toEqual([])
  })
})
