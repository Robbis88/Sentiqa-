import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { registrertePar } from '../parsere/kontoregister'

// =====================================================================
// ETTERFYLLINGEN I 0203 OG REGISTERET SKAL SI DET SAMME
// =====================================================================
//
// `0203` etterfyller `regnskapslinjer.begrep` fra koden for hver rad fra
// februar 2026 og senere. Kartet står i SQL fordi en migrasjon ikke kan
// importere en TypeScript-modul — og da finnes det to steder.
//
// Driver de fra hverandre, blir en historisk rad merket med FEIL begrep.
// Det er verre enn ingen merking: en rad uten begrep er skjult for
// butikksjefen, mens en rad med feil begrep er synlig og gal. Samme
// retning som hele `0203` handler om.
//
// Kartet skal dekke epokene `fra_feb_2026` og `null` — ikke den gamle.
// Etterfyllingen stopper ved februar 2026 nettopp fordi koden alene ikke
// sier noe sikkert før det.
// =====================================================================

const SQL = join(process.cwd(), 'supabase', 'migrations', '0203_begrepet_ikke_koden.sql')

/** `('627', 'renhold')`-parene i `values`-blokken. */
function kartISql(): Map<string, string> {
  const sql = readFileSync(SQL, 'utf8')
    .split('\n')
    .map((l) => l.replace(/--[^\n]*$/, ''))
    .join('\n')
  const blokk = /from \(values([\s\S]*?)\) as k\(kode, begrep\)/i.exec(sql)
  if (!blokk) throw new Error('fant ikke etterfyllingskartet i 0203')
  const par = [...blokk[1].matchAll(/\(\s*'(\d{3})'\s*,\s*'([a-z_]+)'\s*\)/g)]
  return new Map(par.map((m) => [m[1], m[2]]))
}

/** Registeret slik det gjelder for filer fra februar 2026 og senere. */
function kartINaa(): Map<string, string> {
  const ut = new Map<string, string>()
  for (const p of registrertePar()) {
    if (p.epoke === 'for_feb_2026') continue
    const fra = ut.get(p.kode)
    // To navnevarianter kan dele kode (541, 590) — men aldri to begrep.
    if (fra && fra !== p.begrep) {
      throw new Error(`registeret gir kode ${p.kode} to begrep: ${fra} og ${p.begrep}`)
    }
    ut.set(p.kode, p.begrep)
  }
  return ut
}

describe('etterfyllingskartet i 0203', () => {
  it('KANARI: uttrekket finner faktisk kartet', () => {
    // Skrives `values`-blokken om, eller bytter kolonnene navn, blir
    // kartet tomt — og «de er like» ville vært sant fordi det ikke er
    // noe å sammenligne.
    const k = kartISql()
    expect(k.size, 'fant ingen par i etterfyllingen').toBeGreaterThan(30)
    expect(k.get('628')).toBe('renovasjon')
  })

  it('dekker nøyaktig kodene registeret kjenner i dagens skjema', () => {
    const sql = kartISql()
    const naa = kartINaa()
    const bareSql = [...sql.keys()].filter((k) => !naa.has(k)).sort()
    const bareTs = [...naa.keys()].filter((k) => !sql.has(k)).sort()
    expect(
      { bareSql, bareTs },
      '\nEtterfyllingen i 0203 og kontoregisteret har skilt lag.\n\n'
      + `  bare i SQL:  ${bareSql.join(', ') || '(ingen)'}\n`
      + `  bare i TS:   ${bareTs.join(', ') || '(ingen)'}\n\n`
      + 'Bare i SQL: en kode registeret ikke kjenner blir etterfylt med et '
      + 'begrep ingen har tatt stilling til.\n'
      + 'Bare i TS: raden staar igjen uten begrep og er dermed skjult for '
      + 'butikksjefen - en kostnad som mangler ser ut som en kostnad som '
      + 'er null.\n',
    ).toEqual({ bareSql: [], bareTs: [] })
  })

  it('gir hver kode det samme begrepet som registeret', () => {
    const sql = kartISql()
    const naa = kartINaa()
    const uenige = [...naa.entries()]
      .filter(([k, b]) => sql.has(k) && sql.get(k) !== b)
      .map(([k, b]) => `${k}: SQL=${sql.get(k)} TS=${b}`)
    expect(uenige, `\nEtterfyllingen merker rader feil:\n  ${uenige.join('\n  ')}\n`).toEqual([])
  })

  it('etterfyller ikke rader fra før februar 2026', () => {
    // Rader fra den gamle epoken ble navngitt ut av koden alene, med
    // DAGENS betydning. Å etterfylle dem fra koden ville støpt feilen
    // fast — og gjort en leasingkostnad synlig som renovasjon.
    const sql = readFileSync(SQL, 'utf8')
    expect(sql, 'etterfyllingen har ingen periodegrense').toMatch(
      /periode\s*>=\s*date\s*'2026-02-01'/i,
    )
  })

  it('er vaktet, saa den kan kjoeres om igjen', () => {
    // Migrasjonene kjøres manuelt og hele settet kjøres av og til fra
    // bunn. En uvaktet update ville skrevet over et begrep importen
    // hadde satt riktig.
    const sql = readFileSync(SQL, 'utf8')
    expect(sql).toMatch(/where\s+l\.begrep\s+is\s+null/i)
  })
})
