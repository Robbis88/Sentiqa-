import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import ts from 'typescript'
import { describe, expect, it } from 'vitest'

// Katalogens nøkler, ikke «minst én order». stasjon_id er en global UUID.
const NOEKLER: Record<string, string[]> = {
  v_butikksalg: ['stasjon_id', 'dato', 'ean'],
  v_salg_per_avdeling_dag: ['stasjon_id', 'dato', 'avdeling_kode', 'avdeling_navn'],
  v_salg_per_stasjon_dag: ['stasjon_id', 'dato'],
  // 0131 grupperer på retailer, stasjon, kasserernummer og måned.
  // Stasjonens globale UUID binder også retailer.
  v_kasserer_maaned: ['stasjon_id', 'kasserer_nr', 'maned'],
  vaer: ['stasjon_id', 'dato'],
  prognose_treff: ['stasjon_id', 'type', 'dato', 'kategori'],
  retailers: ['id'], stasjoner: ['id'], basisvakt: ['id'], lonnsregister: ['id'], bp_linje: ['id'],
  ansatt_avtale: ['stasjon_id', 'ansatt_nr'], import_jobber: ['id'],
  // Regnskapslinjer har ingen teknisk id. Disse feltene utgjør den stabile
  // rapportnøkkelen når analysegrunnlaget hentes sidevis.
  regnskapslinjer: ['seksjon', 'post', 'kode'],
  regnskap_usynlig_svinn: ['stasjon_id', 'navn'],
  // Bilagssummeringen er aggregert per stasjon, begrep og leverandørtekst.
  v_rommet_leverandor: ['stasjon_id', 'begrep', 'tekst'],
}

type Kall = { navn: string; arg: string | null; betinget: boolean }
function kallI(node: ts.Node): Kall[] {
  const ut: Kall[] = []
  function les(n: ts.Node, betinget = false) {
    if (ts.isCallExpression(n) && ts.isPropertyAccessExpression(n.expression)) {
      const a = n.arguments[0]
      ut.push({ navn: n.expression.name.text, arg: a && ts.isStringLiteral(a) ? a.text : null, betinget })
    }
    ts.forEachChild(n, (barn) => les(barn, betinget || ts.isIfStatement(n) || ts.isConditionalExpression(n) || ts.isSwitchStatement(n)))
  }
  les(node)
  return ut
}

function vurder(kall: Kall[]): string | null {
  const fra = kall.filter((k) => k.navn === 'from')
  if (fra.length !== 1 || !fra[0].arg) return 'Kan ikke bevise hvilken tabell som pagineres'
  const tabell = fra[0].arg
  const noekkel = NOEKLER[tabell]
  if (!noekkel) return `Uklassifisert paginert tabell: ${tabell}`
  const bundet = new Set(kall.filter((k) => !k.betinget && (k.navn === 'order' || k.navn === 'eq')).map((k) => k.arg))
  const mangler = noekkel.filter((k) => !bundet.has(k))
  return mangler.length ? `${tabell}: mangler stabil nøkkel ${mangler.join(', ')}` : null
}

function analyser(kilde: string, fil = 'kanari.ts'): { antall: number; funn: string[] } {
  const ast = ts.createSourceFile(fil, kilde, ts.ScriptTarget.Latest, true, fil.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS)
  const sett = new Set<ts.Node>()
  const funn: string[] = []
  function registrer(n: ts.Node) {
    if (sett.has(n)) return
    sett.add(n)
    const feil = vurder(kallI(n))
    if (feil) funn.push(`${fil}:${ast.getLineAndCharacterOfPosition(n.getStart()).line + 1}: ${feil}`)
  }
  function les(n: ts.Node) {
    if (ts.isCallExpression(n)) {
      if (ts.isIdentifier(n.expression) && ['hentAlle', 'hentAlt'].includes(n.expression.text)) {
        const callback = n.arguments[0]
        if (callback && (ts.isArrowFunction(callback) || ts.isFunctionExpression(callback)) && kallI(callback).some((k) => k.navn === 'from')) registrer(callback)
        else if (!/\.test\.tsx?$/.test(fil)) registrer(n)
      }
      if (ts.isPropertyAccessExpression(n.expression) && n.expression.name.text === 'range') {
        const kall = kallI(n)
        // Den felles hjelperen har ikke egen tabell: hvert callback sjekkes.
        if (!(fil === 'src/lib/supabase/sider.ts' && !kall.some((k) => k.navn === 'from'))) {
          let p: ts.Node | undefined = n.parent
          let iHelper = false
          while (p && !ts.isSourceFile(p)) {
            if (ts.isCallExpression(p) && ts.isIdentifier(p.expression) && ['hentAlle', 'hentAlt'].includes(p.expression.text)) { iHelper = true; break }
            p = p.parent
          }
          if (!iHelper) registrer(n)
        }
      }
    }
    ts.forEachChild(n, les)
  }
  les(ast)
  return { antall: sett.size, funn }
}

function filer(mappe: string): string[] {
  return readdirSync(mappe, { withFileTypes: true }).flatMap((r) => {
    const sti = join(mappe, r.name)
    return r.isDirectory() ? filer(sti) : /\.tsx?$/.test(sti) ? [sti.replaceAll('\\', '/')] : []
  })
}

describe('stabil paginering — vakten ser også kommentarer og callbacks', () => {
  it('KANARI: én order er ikke en unik sortering over flere stasjoner', () => {
    expect(analyser("sb.from('v_butikksalg').eq('ean', ean).order('dato').range(0, 999)").funn).toHaveLength(1)
    expect(analyser("sb.from('v_butikksalg').eq('ean', ean).order('dato')\n// kommentaren skjuler ikke neste ledd\n.order('stasjon_id').range(0,999)").funn).toEqual([])
  })
  it('KANARI: callback uten range i sin egen kilde må også ha stabil nøkkel', () => {
    expect(analyser("hentAlle(() => { const q = sb.from('lonnsregister').select('navn'); return q })").funn).toHaveLength(1)
    expect(analyser("hentAlle(() => { const q = sb.from('lonnsregister').select('navn').order('id'); return q })").funn).toEqual([])
    expect(analyser("sb.from('ny').order('id').range(0,999)").funn).toHaveLength(1)
    expect(analyser("query.range(0,999)").funn).toHaveLength(1)
    expect(analyser("hentAlle(() => { let q = sb.from('lonnsregister').select('navn'); if (flag) q = q.order('id'); return q })").funn).toHaveLength(1)
  })
  it('alle faktiske paginerte spørringer har dokumentert stabil sortering', () => {
    const resultat = filer('src').map((fil) => analyser(readFileSync(fil, 'utf8'), fil))
    expect(resultat.flatMap((r) => r.funn)).toEqual([])
    // Dekningskanari: en vakt som slutter å se hele repoet skal bli rød.
    expect(resultat.reduce((n, r) => n + r.antall, 0)).toBe(36)
  })
})
