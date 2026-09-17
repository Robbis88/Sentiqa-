import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// HAR SENTIQA EN STABIL VAREIDENTITET? — READ ONLY
// =====================================================================
//
// Dom C (2026-09-17): ingen motor eier forventet salg på varenivå.
// `lagProduksjonsplan` identifiserer produktet med `varenavn` — en
// streng — og hele produksjonskoden leser nøyaktig én ting fra
// salgstabellene:
//
//   select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
//
// `daglig_salg` har `ean text not null` og `varenr text`, og EAN er
// dessuten del av primærnøkkelen:
//
//   primary key (retailer_id, stasjon_id, dato, ean)
//
// DET GJØR EAN TIL RADIDENTITET, IKKE TIL VAREIDENTITET. At to rader
// ikke kan kollidere samme dag sier ingenting om at samme vare bærer
// samme EAN over tid. Emballasjeskifte, ny leverandør og
// kampanjeartikler kan alle gi ny EAN på det kunden opplever som samme
// vare — og motsatt kan en EAN gjenbrukes.
//
// DENNE FILA AVGJØR IKKE. Den teller, og legger fram kollisjonene så en
// kanonisk modell kan velges på tall.
//
// ---------------------------------------------------------------------
// NAVN BRUKES TIL Å FINNE, ALDRI TIL Å IDENTIFISERE
// ---------------------------------------------------------------------
//
// Coca-Cola-seksjonen søker på navn for å finne KANDIDATER. Derfra går
// alt på EAN. Å slå sammen «Coca Cola 0,5» og «Coca-Cola 0.5L» fordi de
// ligner, ville vært å bygge identiteten av presentasjonen — samme feil
// som importvarslene hadde.
//
// ---------------------------------------------------------------------
// INGEN RAD ER IKKE NULL SOLGT
// ---------------------------------------------------------------------
//
// En prognosemotor som lærer at manglende rad betyr null etterspørsel,
// vil forutsi null for alt som ikke ble solgt i går. Kontrakten måles
// her i stedet for å antas.
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

/** 26 uker — den dypeste historikkbøtta vi spør om. */
const DAGER = 182
const iso = (d: Date) => d.toISOString().slice(0, 10)
const minus = (n: number) => {
  const d = new Date()
  d.setUTCDate(d.getUTCDate() - n)
  return iso(d)
}
const n0 = (n: number) => Math.round(n).toLocaleString('nb-NO')
const pst = (a: number, b: number) => (b > 0 ? `${((a / b) * 100).toFixed(1)} %` : '—')

type Rad = {
  stasjon_id: string
  dato: string
  ean: string
  varenr: string | null
  varenavn: string | null
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  avdeling_navn: string | null
  antall: number | null
  omsetning_eks_mva: number | null
}

const KOLONNER = 'stasjon_id, dato, ean, varenr, varenavn, varegruppe_kode,'
  + ' varegruppe_navn, avdeling_navn, antall, omsetning_eks_mva'

describe('VAREIDENTITET — grunnlaget for en forventet-salg-motor', () => {
  kjor('teller uten aa roere noe', async () => {
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
    expect(stasjoner.length).toBeGreaterThan(0)

    const fra = minus(DAGER)
    const til = minus(0)
    const L: string[] = ['', '  VAREIDENTITET — PRODUKSJON, READ ONLY', '']
    L.push(`  vindu ${fra} .. ${til}  (${DAGER} dager)`)
    L.push('  kilde: v_butikksalg (uten drivstoff)')

    // Hvor stort er dette foer vi drar det ned?
    const { count } = await supabase
      .from('v_butikksalg').select('*', { count: 'exact', head: true })
      .gte('dato', fra).lte('dato', til)
    L.push(`  rader i vinduet: ${n0(count ?? 0)}`)
    if ((count ?? 0) > 500_000) {
      L.push('  FOR STORT — maalingen stopper her i stedet for aa male halve sannheten.')
      console.log(L.join('\n'))
      throw new Error('for mange rader; snevre vinduet foer du kjoerer igjen')
    }

    const SIDE = 1000
    const rader: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select(KOLONNER)
        .gte('dato', fra).lte('dato', til)
        .order('dato', { ascending: true }).order('ean', { ascending: true })
        .range(f, f + SIDE - 1).overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg: ${rf.message}`)
      const side = data ?? []
      rader.push(...side)
      if (side.length < SIDE) break
    }
    L.push(`  lest: ${n0(rader.length)} rader (paginert)`)
    // Avkortet nevner ser ut som en liten kjede.
    expect(Math.abs(rader.length - (count ?? 0)), 'lest antall stemmer ikke med count').toBeLessThan(SIDE)

    // =================================================================
    // 1 IDENTITETEN — HVA PEKER PAA HVA
    // =================================================================
    const eanTilVarenr = new Map<string, Set<string>>()
    const varenrTilEan = new Map<string, Set<string>>()
    const eanTilNavn = new Map<string, Set<string>>()
    const varenrTilNavn = new Map<string, Set<string>>()
    const utenVarenr = new Set<string>()
    for (const r of rader) {
      const vn = (r.varenr ?? '').trim()
      const nv = (r.varenavn ?? '').trim()
      if (!vn) utenVarenr.add(r.ean)
      const put = (m: Map<string, Set<string>>, k: string, v: string) => {
        if (!k || !v) return
        const s = m.get(k) ?? new Set<string>()
        s.add(v)
        m.set(k, s)
      }
      put(eanTilVarenr, r.ean, vn)
      put(varenrTilEan, vn, r.ean)
      put(eanTilNavn, r.ean, nv)
      put(varenrTilNavn, vn, nv)
    }
    const flere = (m: Map<string, Set<string>>) => [...m].filter(([, s]) => s.size > 1)

    L.push('')
    L.push('  IDENTITET — ENTYDIGHET OVER HELE VINDUET')
    L.push(`    distinkte EAN        ${n0(eanTilVarenr.size)}`)
    L.push(`    distinkte varenr     ${n0(varenrTilEan.size)}`)
    L.push(`    EAN uten varenr      ${n0(utenVarenr.size)}`)
    const r1 = flere(eanTilVarenr)
    const r2 = flere(varenrTilEan)
    const r3 = flere(eanTilNavn)
    const r4 = flere(varenrTilNavn)
    L.push(`    EAN -> flere varenr   ${n0(r1.length)}`)
    L.push(`    varenr -> flere EAN   ${n0(r2.length)}`)
    L.push(`    EAN -> flere navn     ${n0(r3.length)}`)
    L.push(`    varenr -> flere navn  ${n0(r4.length)}`)

    const vis = (tittel: string, par: [string, Set<string>][], n = 6) => {
      if (par.length === 0) return
      L.push(`    ${tittel}`)
      for (const [k, s] of par.slice(0, n)) {
        L.push(`      ${k} -> ${[...s].slice(0, 4).map((x) => `«${x}»`).join('  ')}`
          + (s.size > 4 ? `  (+${s.size - 4})` : ''))
      }
    }
    vis('EKSEMPLER — samme EAN, flere varenr:', r1)
    vis('EKSEMPLER — samme varenr, flere EAN:', r2)
    vis('EKSEMPLER — samme EAN, flere navn:', r3)

    // =================================================================
    // 2 VAREUNIVERSET — HVOR MYE HISTORIKK FINNES
    // =================================================================
    //
    // Historikk maales i DAGER MED SALG, ikke i kalenderdager. En vare
    // som ble solgt tre ganger i lopet av et halvaar har ikke 26 ukers
    // historikk i noen brukbar forstand.
    type Vare = {
      dager: Set<string>; stasjoner: Set<string>
      antall: number; kr: number; siste: string; forste: string
    }
    const perEan = new Map<string, Vare>()
    const perStasjonEan = new Map<string, Set<string>>()
    let totAntall = 0
    let totKr = 0
    for (const r of rader) {
      const v = perEan.get(r.ean) ?? {
        dager: new Set(), stasjoner: new Set(), antall: 0, kr: 0,
        siste: r.dato, forste: r.dato,
      }
      v.dager.add(r.dato)
      v.stasjoner.add(r.stasjon_id)
      v.antall += r.antall ?? 0
      v.kr += r.omsetning_eks_mva ?? 0
      if (r.dato > v.siste) v.siste = r.dato
      if (r.dato < v.forste) v.forste = r.dato
      perEan.set(r.ean, v)
      const se = perStasjonEan.get(r.stasjon_id) ?? new Set<string>()
      se.add(r.ean)
      perStasjonEan.set(r.stasjon_id, se)
      totAntall += r.antall ?? 0
      totKr += r.omsetning_eks_mva ?? 0
    }

    const uker = (v: Vare) => {
      const d1 = Date.parse(`${v.forste}T12:00:00Z`)
      const d2 = Date.parse(`${v.siste}T12:00:00Z`)
      return (d2 - d1) / 86400000 / 7
    }
    const BOTTER = [4, 8, 13, 26]
    const s28 = minus(28)
    L.push('')
    L.push('  VAREUNIVERSET — HELE KJEDEN')
    L.push(`    strukturelle varer (EAN): ${n0(perEan.size)}`)
    for (const b of BOTTER) {
      const m = [...perEan.values()].filter((v) => uker(v) >= b)
      const a = m.reduce((n, v) => n + v.antall, 0)
      const k = m.reduce((n, v) => n + v.kr, 0)
      L.push(`      spenn >= ${String(b).padStart(2)} uker: ${String(n0(m.length)).padStart(6)} varer   `
        + `${pst(a, totAntall).padStart(7)} av antall   ${pst(k, totKr).padStart(7)} av omsetning`)
    }
    const solgt28 = [...perEan.values()].filter((v) => v.siste >= s28)
    L.push(`      solgt siste 28 dager: ${n0(solgt28.length)} varer`)
    // TETTHET, ikke bare spenn. En vare med salg 120 av 182 dager er noe
    // helt annet enn en med salg 3 dager fordelt over samme halvaar.
    for (const t of [10, 30, 60, 120]) {
      const m = [...perEan.values()].filter((v) => v.dager.size >= t)
      const k = m.reduce((n, v) => n + v.kr, 0)
      L.push(`      >= ${String(t).padStart(3)} dager MED salg: ${String(n0(m.length)).padStart(6)} varer   `
        + `${pst(k, totKr).padStart(7)} av omsetning`)
    }

    L.push('')
    L.push('  PER STASJON')
    for (const s of stasjoner) {
      const e = perStasjonEan.get(s.id)
      if (!e) continue
      L.push(`    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(n0(e.size)).padStart(6)} varer`)
    }

    // =================================================================
    // 3 INGEN RAD ER IKKE NULL SOLGT
    // =================================================================
    const nullrader = rader.filter((r) => (r.antall ?? 0) === 0).length
    const dagerPerStasjon = new Map<string, Set<string>>()
    for (const r of rader) {
      const d = dagerPerStasjon.get(r.stasjon_id) ?? new Set<string>()
      d.add(r.dato)
      dagerPerStasjon.set(r.stasjon_id, d)
    }
    L.push('')
    L.push('  DATAKONTRAKT — NULL, NULLSALG, INGEN RAD')
    L.push(`    rader med antall = 0: ${n0(nullrader)} av ${n0(rader.length)}`)
    L.push('    -> Finnes det knapt slike rader, foeres en vare BARE naar den ble solgt,')
    L.push('       og «ingen rad» kan ikke leses som «null etterspoersel».')
    L.push('    dager MED rader per stasjon (av 182 mulige):')
    for (const s of stasjoner) {
      const d = dagerPerStasjon.get(s.id)
      if (!d) continue
      L.push(`      ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(d.size).padStart(4)} dager`
        + (d.size < DAGER ? `   <- ${DAGER - d.size} dager UTEN én eneste rad` : ''))
    }

    // =================================================================
    // 4 COCA-COLA — KANDIDATER FUNNET PAA NAVN, MAALT PAA EAN
    // =================================================================
    const kandidater = [...perEan.entries()].filter(([, v]) => v.antall > 0)
      .map(([ean, v]) => {
        const r = rader.find((x) => x.ean === ean)
        return { ean, v, navn: r?.varenavn ?? '', vg: r?.varegruppe_navn ?? '',
          vgk: r?.varegruppe_kode ?? '', avd: r?.avdeling_navn ?? '', varenr: r?.varenr ?? null }
      })
      .filter((k) => /cola/i.test(k.navn))
      .sort((a, b) => b.v.antall - a.v.antall)

    L.push('')
    L.push(`  COCA-COLA — ${kandidater.length} kandidater funnet paa navn (identitet = EAN)`)
    L.push('    EAN            varenr      antall   dager  stasjoner  varegruppe            navn')
    for (const k of kandidater.slice(0, 12)) {
      L.push(`    ${k.ean.padEnd(14)} ${(k.varenr ?? '—').padEnd(11)} `
        + `${String(n0(k.v.antall)).padStart(7)} ${String(k.v.dager.size).padStart(6)} `
        + `${String(k.v.stasjoner.size).padStart(9)}  ${(k.vgk + ' ' + k.vg).padEnd(21)} «${k.navn}»`)
    }

    const beste = kandidater[0]
    if (beste) {
      const fire = minus(28)
      const aatte = minus(56)
      const egne = rader.filter((r) => r.ean === beste.ean)
      L.push('')
      L.push(`  KANDIDAT I DETALJ — EAN ${beste.ean}  «${beste.navn}»`)
      L.push(`    varenr ${beste.varenr ?? '—'}   varegruppe ${beste.vgk} ${beste.vg}   avdeling ${beste.avd}`)
      L.push(`    foerste salgsdato ${beste.v.forste}   siste ${beste.v.siste}`)
      L.push(`    dager med salg ${beste.v.dager.size} av ${DAGER}   `
        + `stasjoner med historikk ${beste.v.stasjoner.size} av ${stasjoner.length}`)
      L.push(`    totalt antall ${n0(beste.v.antall)}   `
        + `siste 4 uker ${n0(egne.filter((r) => r.dato >= fire).reduce((n, r) => n + (r.antall ?? 0), 0))}   `
        + `siste 8 uker ${n0(egne.filter((r) => r.dato >= aatte).reduce((n, r) => n + (r.antall ?? 0), 0))}`)
      L.push('    per stasjon:')
      for (const s of stasjoner) {
        const e = egne.filter((r) => r.stasjon_id === s.id)
        if (e.length === 0) { L.push(`      ${(navnFor.get(s.id) ?? '').padEnd(22)} ingen historikk`); continue }
        L.push(`      ${(navnFor.get(s.id) ?? '').padEnd(22)} `
          + `${String(n0(e.reduce((n, r) => n + (r.antall ?? 0), 0))).padStart(6)} stk   `
          + `${String(new Set(e.map((r) => r.dato)).size).padStart(3)} dager med salg`)
      }
      // Navnene denne EAN-en har baaret. Historisk navneendring er
      // legitimt; det er nettopp derfor navnet ikke kan vaere identitet.
      const navnene = eanTilNavn.get(beste.ean)
      if (navnene && navnene.size > 1) {
        L.push(`    NAVN OVER TID: ${[...navnene].map((x) => `«${x}»`).join('  ')}`)
      }
    }

    L.push('')
    L.push('  Ingen fremtidig salg er beregnet. Ingen rad er endret.')
    L.push('')
    console.log(L.join('\n'))

    expect(perEan.size, 'ingen varer funnet — maalte denne fila noe?').toBeGreaterThan(0)
  }, 600_000)
})
