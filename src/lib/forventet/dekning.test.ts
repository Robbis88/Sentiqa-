import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// HVOR MANGE VARER VIL VERKTØYET FAKTISK TØRRE Å SVARE PÅ? — READ ONLY
// =====================================================================
//
// Horisont-backtesten målte 21 varer og rapporterte «dekning 85,2 %».
// Det er dekning INNENFOR UTVALGET, ikke i universet — og utvalget var
// hver 71. vare etter volumrang, opp til rang 1349 av 1426.
//
// Spredningen er rimelig, men den sier ingenting om hvor stor
// populasjonen er. Lavvolumsvarer faller trolig oftere på terskelen på
// 60 salgsdager, og da er 85,2 % for optimistisk for helheten.
//
// Denne fila teller populasjonen: hvor mange (stasjon, vare)-par som i
// det hele tatt passerer terskelen, fordelt på volum. Først da vet vi om
// horisontmålingen kan generaliseres.
//
// ---------------------------------------------------------------------
// ET KONSERVATIVT ANSLAG, OG DET ER MED VILJE
// ---------------------------------------------------------------------
//
// Motoren ser 432 dager bakover i produksjon. Her telles 182, fordi et
// fullt 432-dagers uttrekk for alle varer er for tungt.
//
// Det gir et NEDRE ANSLAG: et par med ≥60 salgsdager på 182 dager har
// dem også på 432. Motsatt kan et par med færre enn 60 på 182 likevel nå
// terskelen på 432. Tallet under er derfor et gulv, ikke en fasit — og
// det står slik i utskriften.
//
// KREVER KANARI_EPOST og KANARI_PASSORD.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD
const kjor = EPOST && PASSORD ? it : it.skip

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

const DAGER = 182
const TERSKEL = 60
const iso = (d: Date) => d.toISOString().slice(0, 10)
const minus = (n: number) => {
  const d = new Date()
  d.setUTCDate(d.getUTCDate() - n)
  return iso(d)
}
const n0 = (n: number) => Math.round(n).toLocaleString('nb-NO')
const pst = (a: number, b: number) => (b > 0 ? `${((a / b) * 100).toFixed(1)} %` : '—')

type Rad = { stasjon_id: string; dato: string; ean: string; antall: number | null }

describe('DEKNING — populasjonen bak horisontmaalingen', () => {
  kjor('hvor mange (stasjon, vare)-par passerer terskelen', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    const { data: srader } = await supabase
      .from('stasjoner').select('id, navn, butikknummer')
      .is('slettet_tid', null).order('butikknummer').limit(200)
    const stasjoner = (srader ?? []) as { id: string; navn: string; butikknummer: string }[]
    const navnFor = new Map(stasjoner.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))

    const fra = minus(DAGER)
    const til = minus(2)
    const L: string[] = ['', '  DEKNING — POPULASJONEN, READ ONLY', '']
    L.push(`  vindu ${fra} .. ${til}  (${DAGER} dager)   terskel ${TERSKEL} salgsdager`)
    L.push('  NEDRE ANSLAG: motoren ser 432 dager i produksjon. Et par med')
    L.push(`  >= ${TERSKEL} salgsdager paa ${DAGER} dager har dem ogsaa paa 432; det motsatte`)
    L.push('  gjelder ikke. Tallene er derfor et gulv.')

    const SIDE = 1000
    const rader: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall')
        .gte('dato', fra).lte('dato', til)
        .order('dato', { ascending: true }).order('stasjon_id').order('ean', { ascending: true }).order('retailer_id')
        .range(f, f + SIDE - 1).overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg: ${rf.message}`)
      const side = data ?? []
      rader.push(...side)
      if (side.length < SIDE) break
    }
    L.push(`  rader lest: ${n0(rader.length)} (paginert)`)
    expect(rader.length, 'ingen rader').toBeGreaterThan(0)

    // ── PER (STASJON, VARE) ─────────────────────────────────────────────
    //
    // NULLRADER TELLER IKKE. Motoren teller `antall > 0` som salgsdag, og
    // 206 av 223 708 rader har `antall = 0`. Telte vi dem, ville
    // populasjonen sett stoerre ut enn den motoren faktisk svarer paa.
    const dager = new Map<string, Set<string>>()
    const parVolum = new Map<string, number>()
    const eanVolum = new Map<string, number>()
    for (const r of rader) {
      const a = r.antall ?? 0
      const n = `${r.stasjon_id}|${r.ean}`
      eanVolum.set(r.ean, (eanVolum.get(r.ean) ?? 0) + a)
      parVolum.set(n, (parVolum.get(n) ?? 0) + a)
      if (a <= 0) continue
      const s = dager.get(n) ?? new Set<string>()
      s.add(r.dato)
      dager.set(n, s)
    }

    const alleEan = [...eanVolum.keys()]
    const alleRang = [...eanVolum.entries()].sort((a, b) => b[1] - a[1]).map(([e]) => e)
    const rangFor = new Map(alleRang.map((e, i) => [e, i]))

    L.push('')
    L.push('  POPULASJONEN')
    L.push(`    distinkte varer (EAN):        ${n0(alleEan.length)}`)
    L.push(`    (stasjon, vare)-par med salg: ${n0(dager.size)}`)
    const over = [...dager.entries()].filter(([, s]) => s.size >= TERSKEL)
    L.push(`    par som passerer ${TERSKEL} salgsdager: ${n0(over.length)}   `
      + `${pst(over.length, dager.size)} av parene med salg`)
    const totVolum = [...parVolum.values()].reduce((a, b) => a + b, 0)
    const overVolum = over.reduce((a, [n]) => a + (parVolum.get(n) ?? 0), 0)
    L.push(`    de dekker ${pst(overVolum, totVolum)} av alt solgt antall`)
    // Distinkte varer som passerer paa MINST én stasjon.
    const eanOver = new Set(over.map(([n]) => n.split('|')[1]))
    L.push(`    distinkte varer som passerer paa minst én stasjon: ${n0(eanOver.size)}   `
      + `${pst(eanOver.size, alleEan.length)}`)

    L.push('')
    L.push('  PER STASJON')
    L.push('    stasjon                  par med salg   passerer   andel   av volum')
    for (const s of stasjoner) {
      const egne = [...dager.entries()].filter(([n]) => n.startsWith(`${s.id}|`))
      if (egne.length === 0) continue
      const o = egne.filter(([, d]) => d.size >= TERSKEL)
      const v = egne.reduce((a, [n]) => a + (parVolum.get(n) ?? 0), 0)
      const ov = o.reduce((a, [n]) => a + (parVolum.get(n) ?? 0), 0)
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(n0(egne.length)).padStart(13)}   `
        + `${String(n0(o.length)).padStart(8)}   ${pst(o.length, egne.length).padStart(6)}   `
        + `${pst(ov, v).padStart(7)}`,
      )
    }

    // ── VOLUMDESILER: hvor terskelen faktisk biter ──────────────────────
    L.push('')
    L.push('  PER VOLUMDESIL (varer rangert paa solgt antall, 1 = stoerst)')
    L.push('    desil   varer   par med salg   passerer   andel   av volum')
    const D = 10
    const perDesil = Array.from({ length: D }, () => ({ varer: 0, par: 0, over: 0, vol: 0, oVol: 0 }))
    for (const [i, ean] of alleRang.entries()) {
      const d = Math.min(D - 1, Math.floor((i / alleRang.length) * D))
      perDesil[d].varer++
      for (const s of stasjoner) {
        const n = `${s.id}|${ean}`
        if (!dager.has(n)) continue
        perDesil[d].par++
        perDesil[d].vol += parVolum.get(n) ?? 0
        if ((dager.get(n)?.size ?? 0) >= TERSKEL) {
          perDesil[d].over++
          perDesil[d].oVol += parVolum.get(n) ?? 0
        }
      }
    }
    for (const [i, d] of perDesil.entries()) {
      L.push(
        `    ${String(i + 1).padStart(5)}   ${String(n0(d.varer)).padStart(5)}   `
        + `${String(n0(d.par)).padStart(13)}   ${String(n0(d.over)).padStart(8)}   `
        + `${pst(d.over, d.par).padStart(6)}   ${pst(d.oVol, d.vol).padStart(7)}`,
      )
    }

    // ── HVOR UTVALGET I HORISONTMAALINGEN LAA ───────────────────────────
    //
    // Samme regel som `horisont.test.ts`: hver 71. vare etter volumrang
    // i et 60-dagers vindu, pluss kanarien. Her gjengis den mot DETTE
    // vinduet, saa spredningen kan leses mot populasjonen.
    L.push('')
    L.push('  UTVALGET I HORISONTMAALINGEN — hvor det laa')
    const STEG = Math.max(1, Math.floor(alleRang.length / 20))
    const utvalg: string[] = []
    for (let i = 0; i < alleRang.length && utvalg.length < 20; i += STEG) utvalg.push(alleRang[i])
    L.push(`    regel: hver ${STEG}. vare etter volumrang, 20 stk + kanarien`)
    L.push(`    hoeyeste rang beroert: ${(utvalg.length - 1) * STEG} av ${alleRang.length - 1}`)
    L.push('    desilfordeling i utvalget: '
      + Array.from({ length: D }, (_, i) =>
        `${i + 1}:${utvalg.filter((e) => Math.min(D - 1, Math.floor(((rangFor.get(e) ?? 0) / alleRang.length) * D)) === i).length}`,
      ).join('  '))
    const utvalgPar = utvalg.flatMap((e) => stasjoner.map((s) => `${s.id}|${e}`))
      .filter((n) => dager.has(n))
    const utvalgOver = utvalgPar.filter((n) => (dager.get(n)?.size ?? 0) >= TERSKEL)
    L.push(`    par i utvalget med salg: ${n0(utvalgPar.length)}   `
      + `passerer: ${n0(utvalgOver.length)}   ${pst(utvalgOver.length, utvalgPar.length)}`)
    L.push(`    mot populasjonen:        ${pst(over.length, dager.size)}`)
    L.push('    -> spriker disse to, er horisontmaalingen gjort paa et lettere utvalg')

    L.push('')
    L.push('  Ingen rad er endret. Ingen prognose er beregnet.')
    L.push('')
    console.log(L.join('\n'))

    expect(dager.size, 'ingen par funnet').toBeGreaterThan(0)
    // Kanarifugl: passerer ALLE par terskelen, maaler kolonnen ingenting.
    expect(over.length, 'alle par passerer — biter terskelen i det hele tatt?')
      .toBeLessThan(dager.size)
  }, 900_000)
})
