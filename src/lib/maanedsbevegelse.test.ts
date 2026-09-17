import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// BESLUTNINGSKANARI — TILSTAND MOT BEVEGELSE
// =====================================================================
//
// `hentRegnskapVarsler` kaller `regnskap_sum(jan, valgt)` og
// `svinn_sum(jan, valgt)`. Hvert tall i varslene er altså summen
// **januar til valgt måned**, og tersklene (15 000 / 5 000 / 4 000) er
// absolutte kroner mot den summen.
//
// Følgen, målt mai–juli 2026: null nye fenomener, null nivåskifter, og
// utbredelse som bare vokser. En stasjon blir rød når årssummen passerer
// 15 000 — ikke når noe skjer.
//
// ---------------------------------------------------------------------
// KONTRAKTEN, LEST OG IKKE ANTATT
// ---------------------------------------------------------------------
//
//   where periode between p_fra and p_til
//   group by stasjon_id, kode, ...   sum(...)
//
// `periode` er ÉN RAD PER MÅNED (`yyyy-mm-01`, satt av parseren). Da er
// `p_fra = p_til = periode` nøyaktig den måneden — `between` er inklusiv
// i begge ender, og det finnes bare én periodeverdi i måneden.
//
// Og `YTD(juli) − YTD(juni) = juli alene` er matematisk gyldig, fordi
// begge er summer over samme radmengde med `slettet_tid is null`, lest i
// samme kjøring. **Den identiteten bevises her, den forutsettes ikke** —
// en reimport som lot to utgaver av samme måned stå åpne ville brutt
// den, og det ville sett ut som en bevegelse.
//
// ---------------------------------------------------------------------
// MÅNEDEN FÅR IKKE ET NIVÅ
// ---------------------------------------------------------------------
//
// `mankoRod = 15 000` er etablert mot en ÅRSSUM. Brukt på ett månedstall
// ville den gjort nesten alt grønt, og en terskel som nesten aldri
// utløses er like ubrukelig som en som alltid gjør det.
//
// Denne fila returnerer derfor MÅLTE VERDIER uten rød/gul. Vi ser
// fordelingen først.
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

const MAANEDER = ['2026-05-01', '2026-06-01', '2026-07-01']
const navnPaa = (p: string) => ({ '05': 'mai', '06': 'juni', '07': 'juli' })[p.slice(5, 7)] ?? p
const kr = (n: number) => Math.round(n).toLocaleString('nb-NO')
/** Med fortegn, så en bevegelse nedover er synlig som det. */
const krTegn = (n: number) => (n >= 0 ? '+' : '−') + kr(Math.abs(n))

type Svinnrad = {
  stasjon_id: string; kode: string | null; navn: string
  salg: number | null; usynlig_kr: number | null; kast: number | null
}
type Linjerad = {
  stasjon_id: string | null; seksjon: string; kode: string | null
  post: string; regnskap: number | null; budsjett: number | null
}

describe('BESLUTNINGSKANARI — maaneden som egen sannhet', () => {
  kjor('YTD, maaned og delta side om side', async () => {
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

    const aar = MAANEDER[0].slice(0, 4)
    const svinn = async (fra: string, til: string) => {
      const { data, error: e } = await supabase.rpc('svinn_sum', { p_fra: fra, p_til: til })
      if (e) throw new Error(`svinn_sum(${fra},${til}): ${e.message}`)
      return (data ?? []) as Svinnrad[]
    }
    const linjer = async (fra: string, til: string) => {
      const { data, error: e } = await supabase.rpc('regnskap_sum', { p_fra: fra, p_til: til })
      if (e) throw new Error(`regnskap_sum(${fra},${til}): ${e.message}`)
      return (data ?? []) as Linjerad[]
    }

    const L: string[] = ['', '  TILSTAND MOT BEVEGELSE — PRODUKSJON', '']
    L.push('  RPC-KONTRAKT')
    L.push(`    regnskap_sum / svinn_sum:  where periode between p_fra and p_til`)
    L.push(`    periode er én rad per maaned  ->  p_fra = p_til = maaneden alene`)

    // =================================================================
    // 1 IDENTITETEN BEVISES: YTD(n) − YTD(n−1) == maaneden alene
    // =================================================================
    const ytd = new Map<string, Svinnrad[]>()
    const mnd = new Map<string, Svinnrad[]>()
    for (const p of MAANEDER) {
      ytd.set(p, await svinn(`${aar}-01-01`, p))
      mnd.set(p, await svinn(p, p))
    }

    const noekkel = (r: Svinnrad) => `${r.stasjon_id}|${r.kode ?? ''}`
    const felt = (rader: Svinnrad[], n: string, f: keyof Svinnrad) => {
      const r = rader.find((x) => noekkel(x) === n)
      return r ? Number(r[f] ?? 0) : 0
    }

    L.push('')
    L.push('  BEVIS — YTD(n) − YTD(n−1) mot maaneden alene (usynlig_kr)')
    let proevde = 0
    let avvik = 0
    for (let i = 1; i < MAANEDER.length; i++) {
      const naa = MAANEDER[i]
      const forr = MAANEDER[i - 1]
      const alleN = new Set([
        ...ytd.get(naa)!.map(noekkel), ...ytd.get(forr)!.map(noekkel),
        ...mnd.get(naa)!.map(noekkel),
      ])
      let verst = 0
      let verstN = ''
      for (const n of alleN) {
        const d = felt(ytd.get(naa)!, n, 'usynlig_kr') - felt(ytd.get(forr)!, n, 'usynlig_kr')
        const m = felt(mnd.get(naa)!, n, 'usynlig_kr')
        proevde++
        const diff = Math.abs(d - m)
        if (diff > 0.5) { avvik++; if (diff > verst) { verst = diff; verstN = n } }
      }
      L.push(`    ${navnPaa(naa)}: ${alleN.size} (stasjon,varegruppe)-par`
        + `   avvik ${verst > 0 ? `STOERSTE ${kr(verst)} kr paa ${verstN}` : 'INGEN'}`)
    }
    L.push(`    proevde ${proevde} par, avvik ${avvik}`)
    L.push(avvik === 0
      ? '    -> identiteten HOLDER. Maanedstallet kan leses som en bevegelse.'
      : '    -> IDENTITETEN HOLDER IKKE. Se over foer noe tolkes som bevegelse.')

    // =================================================================
    // 2 LONE · 160 KIOSKVARER · JUNI — mot de fire andre
    // =================================================================
    //
    // YTD viste Lone under terskel i mai og 23 148 i juni, mens de andre
    // beveget seg 1-2 000. Isolerer maanedsmaalingen den bevegelsen?
    L.push('')
    L.push('  160 KIOSKVARER — YTD, MAANED OG DELTA')
    L.push('    stasjon                  maaned   YTD          maaneden      YTD-delta')
    for (const s of stasjoner) {
      for (const p of MAANEDER) {
        const n = `${s.id}|160`
        const y = felt(ytd.get(p)!, n, 'usynlig_kr')
        const m = felt(mnd.get(p)!, n, 'usynlig_kr')
        const i = MAANEDER.indexOf(p)
        const d = i === 0 ? null : y - felt(ytd.get(MAANEDER[i - 1])!, n, 'usynlig_kr')
        L.push(`    ${navnFor.get(s.id)!.padEnd(24)} ${navnPaa(p).padEnd(7)}`
          + ` ${kr(y).padStart(10)}  ${krTegn(m).padStart(11)}`
          + `  ${(d === null ? '—' : krTegn(d)).padStart(11)}`)
      }
    }

    // =================================================================
    // 3 ALLE VAREGRUPPER, JULI ALENE — fordelingen uten nivaa
    // =================================================================
    //
    // INGEN ROED/GUL. Tersklene er etablert mot en aarssum; brukt paa ett
    // maanedstall ville de gjort nesten alt groent. Her staar
    // fordelingen, saa terskler kan designes paa tall i stedet for paa
    // magefoelelse.
    L.push('')
    L.push('  JULI ALENE — usynlig_kr per (stasjon, varegruppe), uten nivaa')
    const juli = [...mnd.get('2026-07-01')!]
      .filter((r) => Math.abs(Number(r.usynlig_kr ?? 0)) >= 1)
      .sort((a, b) => Math.abs(Number(b.usynlig_kr ?? 0)) - Math.abs(Number(a.usynlig_kr ?? 0)))
    for (const r of juli.slice(0, 20)) {
      L.push(`    ${krTegn(Number(r.usynlig_kr ?? 0)).padStart(11)} kr`
        + `   ${(navnFor.get(r.stasjon_id) ?? r.stasjon_id).padEnd(24)}`
        + ` ${(r.kode ?? '—').padEnd(5)} ${r.navn}`)
    }
    const abs = juli.map((r) => Math.abs(Number(r.usynlig_kr ?? 0))).sort((a, b) => a - b)
    if (abs.length > 0) {
      const kvartil = (q: number) => abs[Math.min(abs.length - 1, Math.floor(abs.length * q))]
      L.push(`    fordeling |kr|: median ${kr(kvartil(0.5))}`
        + `   75% ${kr(kvartil(0.75))}   90% ${kr(kvartil(0.9))}`
        + `   maks ${kr(abs[abs.length - 1])}   n=${abs.length}`)
    }

    // =================================================================
    // 4 DALE · RESULTAT · JULI ALENE
    // =================================================================
    L.push('')
    L.push('  RESULTAT (ex 9900) — YTD og maaneden alene')
    const resFor = (rader: Linjerad[], sid: string) => {
      const mine = rader.filter((l) => l.stasjon_id === sid && l.seksjon === 'resultat')
      const ex = mine.find((l) => /resultat ex 9900/i.test(l.post))
        ?? mine.find((l) => /^resultat$/i.test(l.post))
      return ex ? Number(ex.regnskap ?? 0) : null
    }
    const lY = new Map<string, Linjerad[]>()
    const lM = new Map<string, Linjerad[]>()
    for (const p of MAANEDER) {
      lY.set(p, await linjer(`${aar}-01-01`, p))
      lM.set(p, await linjer(p, p))
    }
    L.push('    stasjon                  maaned   YTD          maaneden      YTD-delta')
    for (const s of stasjoner) {
      for (const p of MAANEDER) {
        const y = resFor(lY.get(p)!, s.id)
        const m = resFor(lM.get(p)!, s.id)
        const i = MAANEDER.indexOf(p)
        const d = i === 0 || y === null ? null
          : (() => { const f = resFor(lY.get(MAANEDER[i - 1])!, s.id); return f === null ? null : y - f })()
        L.push(`    ${navnFor.get(s.id)!.padEnd(24)} ${navnPaa(p).padEnd(7)}`
          + ` ${(y === null ? '—' : krTegn(y)).padStart(11)}`
          + ` ${(m === null ? '—' : krTegn(m)).padStart(12)}`
          + ` ${(d === null ? '—' : krTegn(d)).padStart(12)}`)
      }
    }

    L.push('')
    console.log(L.join('\n'))

    // KANARIFUGL FOR KANARIFUGLEN.
    expect(proevde, 'ingen par proevd - identiteten er ikke maalt').toBeGreaterThan(20)
    expect(juli.length, 'ingen svinnrader i juli alene - maalte vi noe?').toBeGreaterThan(0)
    // MAANEDEN MAA VAERE EN EKTE DELMENGDE AV AARET. Er maanedssummen
    // stoerre enn YTD for samme par, er vinduet feil forstaatt.
    for (const r of mnd.get('2026-07-01')!) {
      const y = felt(ytd.get('2026-07-01')!, noekkel(r), 'salg')
      const m = Number(r.salg ?? 0)
      if (y > 0) expect(m, `${r.navn}: maanedssalg over aarssalg`).toBeLessThanOrEqual(y + 0.5)
    }
  }, 300_000)
})
