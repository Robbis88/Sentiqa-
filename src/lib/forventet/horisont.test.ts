import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { leggTilDager } from '@/lib/produksjonsplan'
import { forventetSalg, MODELLER, type Salgsrad } from './motor'

// =====================================================================
// HVOR LANGT FRAM TØR MOTOREN SE? — READ ONLY
// =====================================================================
//
// `forventetSalg` tar én dato og svarer på den. Å løkke over et
// intervall er trivielt. Spørsmålet er om tallene er like mye verdt.
//
// ---------------------------------------------------------------------
// MOTORENS EGEN GRENSE ER IKKE NOK FOR h > 1
// ---------------------------------------------------------------------
//
// Motoren kaster rader med `dato >= maalDato`. Det er riktig for +1: en
// prognose for i morgen lages i dag, og i dag er alt som finnes.
//
// For +7 er det IKKE nok. Prognosen lages på dag T for måldag D = T+7,
// og `dato < D` ville sluppet inn dagene T…D−1 — syv døgn som ikke
// hadde skjedd ennå da prognosen ble laget. Da måler vi en motor som
// har sett fasiten nesten helt fram.
//
// Derfor filtreres grunnlaget til `dato <= D − h` FØR motoren kalles.
// Det er prognosetidspunktet, og det er denne filas ansvar.
//
// ---------------------------------------------------------------------
// MODELLEN DEGRADERER STILLE
// ---------------------------------------------------------------------
//
//   nyligSlutt = maalDato − 1
//   nyligStart = nyligSlutt − 27
//
// For +1 er det vinduet fullt av ekte salg. For +30 ligger hele vinduet
// etter prognosetidspunktet: ingen rader, `nyligSnitt = null`,
// `trendfaktor = 1`, og `basis` blir fjorårsmedianen alene.
//
// Motoren svarer fortsatt med et tall — men det er en ANNEN modell enn
// den som ble backtestet. Fila teller derfor hvor ofte `nyligSnitt`
// mangler, ved siden av treffsikkerheten.
//
// ---------------------------------------------------------------------
// PERIODETOTALEN ER IKKE SUMMEN AV FEILENE
// ---------------------------------------------------------------------
//
// 7 dagsprognoser summert har ikke 7 ganger dagsfeilen. Feilene kan
// utlikne hverandre eller forsterke seg, og vi vet ikke hvilken. Derfor
// måles totalen for seg: alle dagene laget på SAMME tidspunkt T, summert
// og holdt mot faktisk sum.
//
// INGEN GRENSE ER SATT PÅ FORHÅND. Fila rapporterer; den anbefaler ikke.
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

const iso = (d: Date) => d.toISOString().slice(0, 10)
const minus = (n: number) => {
  const d = new Date()
  d.setUTCDate(d.getUTCDate() - n)
  return iso(d)
}
const n0 = (n: number) => Math.round(n).toLocaleString('nb-NO')
const n1 = (n: number) => n.toFixed(1)

/** Samme modell og terskel som `ai/forventetverktoy.ts` bruker. */
const MODELL = MODELLER.find((m) => m.navn === 'basis+trend')!
const MINST_DAGER = 60

// h8..h13 er med fordi «NESTE KALENDERUKE» kan naa saa langt.
//
// Spurt paa en soendag er neste uke h1..h7. Spurt paa en mandag er den
// h7..h13 - mandagen etter ligger syv dager fram, soendagen tretten.
// Skal spoersmaalet virke uansett ukedag, maa hele spennet vaere maalt.
const HORISONTER = [1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 30]
const PERIODER = [7, 30]
const TEST_DAGER = 28
const KANARI = '5000112636833'
/** Nok til at fjorårsvinduet finnes også for den lengste horisonten. */
const HISTORIKK = TEST_DAGER + 2 + 30 + 364 + 45

type Rad = {
  stasjon_id: string; dato: string; ean: string; antall: number | null
  varegruppe_kode: string | null; varegruppe_navn: string | null
}
type Treff = { forventet: number; faktisk: number }

function maal(t: Treff[]) {
  if (t.length === 0) return null
  const feil = t.map((x) => Math.abs(x.forventet - x.faktisk))
  const sumFeil = feil.reduce((a, b) => a + b, 0)
  const sumFaktisk = t.reduce((a, x) => a + x.faktisk, 0)
  const sortert = [...feil].sort((a, b) => a - b)
  return {
    n: t.length,
    mae: sumFeil / t.length,
    medianFeil: sortert[Math.floor(sortert.length / 2)],
    wmape: sumFaktisk > 0 ? (sumFeil / sumFaktisk) * 100 : null,
    bias: t.reduce((a, x) => a + (x.forventet - x.faktisk), 0) / t.length,
    snittFaktisk: sumFaktisk / t.length,
  }
}

describe('HORISONT — hvor langt fram holder motoren', () => {
  kjor('h = 1, 2, 3, 7, 14, 30 og periodetotal for 7 og 30', async () => {
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

    const til = minus(2)
    const fra = minus(HISTORIKK)
    const L: string[] = ['', '  HORISONT-BACKTEST — FORVENTET SALG', '']
    L.push(`  historikk fra ${fra}   maaldatoer t.o.m. ${til}   ${TEST_DAGER} per horisont`)
    L.push(`  modell ${MODELL.navn}   terskel ${MINST_DAGER} salgsdager`)
    L.push('  PROGNOSETIDSPUNKT: for horisont h ser motoren bare `dato <= D - h`.')

    // ── UTVALGET: kanarien + tverrsnitt paa volum ───────────────────────
    const SIDE = 1000
    const univers: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: uf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall, varegruppe_kode, varegruppe_navn')
        .gte('dato', minus(60)).lte('dato', til)
        .order('dato', { ascending: true }).order('ean', { ascending: true })
        .range(f, f + SIDE - 1).overrideTypes<Rad[]>()
      if (uf) throw new Error(`v_butikksalg (univers): ${uf.message}`)
      const side = data ?? []
      univers.push(...side)
      if (side.length < SIDE) break
    }
    const volum = new Map<string, number>()
    for (const r of univers) volum.set(r.ean, (volum.get(r.ean) ?? 0) + (r.antall ?? 0))
    const sortert = [...volum.entries()].sort((a, b) => b[1] - a[1])
    const valgte = new Set<string>([KANARI])
    const STEG = Math.max(1, Math.floor(sortert.length / 20))
    for (let i = 0; i < sortert.length && valgte.size < 21; i += STEG) valgte.add(sortert[i][0])
    L.push(`  varer i utvalget: ${valgte.size} av ${sortert.length} i vinduet`)

    // ── HISTORIKKEN FOR UTVALGET ────────────────────────────────────────
    const eanListe = [...valgte]
    const rader: Rad[] = []
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall, varegruppe_kode, varegruppe_navn')
        .in('ean', eanListe).gte('dato', fra).lte('dato', til)
        .order('dato', { ascending: true }).range(f, f + SIDE - 1)
        .overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg: ${rf.message}`)
      const side = data ?? []
      rader.push(...side)
      if (side.length < SIDE) break
    }
    L.push(`  historiske rader lest: ${n0(rader.length)}`)
    expect(rader.length, 'ingen historikk').toBeGreaterThan(0)

    // Per enhet, sortert. Motoren filtrerer selv paa stasjon/ean, men aa
    // sende bare enhetens egne rader er samme resultat og langt raskere.
    const perEnhet = new Map<string, Salgsrad[]>()
    const fasit = new Map<string, number>()
    for (const r of rader) {
      const n = `${r.stasjon_id}|${r.ean}`
      const s: Salgsrad = {
        stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
        varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn,
      }
      perEnhet.set(n, [...(perEnhet.get(n) ?? []), s])
      fasit.set(`${n}|${r.dato}`, (fasit.get(`${n}|${r.dato}`) ?? 0) + s.antall)
    }

    const maaldatoer: string[] = []
    for (let i = TEST_DAGER; i >= 1; i--) maaldatoer.push(leggTilDager(til, -(i - 1)))

    // =================================================================
    // 1 ENKELTDAG PER HORISONT
    // =================================================================
    type Bunt = {
      treff: Treff[]; forsokt: number; svart: number; utenNylig: number
      perStasjon: Map<string, Treff[]>
    }
    const perH = new Map<number, Bunt>()
    for (const h of HORISONTER) {
      perH.set(h, { treff: [], forsokt: 0, svart: 0, utenNylig: 0, perStasjon: new Map() })
    }

    for (const h of HORISONTER) {
      const b = perH.get(h)!
      for (const d of maaldatoer) {
        // PROGNOSETIDSPUNKTET. Alt etter dette fantes ikke da.
        const sisteKjente = leggTilDager(d, -h)
        for (const s of stasjoner) {
          for (const ean of eanListe) {
            const n = `${s.id}|${ean}`
            const f = fasit.get(`${n}|${d}`)
            if (f === undefined) continue
            b.forsokt++
            const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= sisteKjente)
            const sv = forventetSalg({
              enhet: { stasjonId: s.id, ean }, maalDato: d, salg: tilgjengelig,
              modell: MODELL, minstDagerMedSalg: MINST_DAGER,
            })
            if (sv.slag !== 'beregnet') continue
            b.svart++
            if (sv.grunnlag.nyligSnitt === null) b.utenNylig++
            const t = { forventet: sv.antall, faktisk: f }
            b.treff.push(t)
            if (ean === KANARI) {
              b.perStasjon.set(s.id, [...(b.perStasjon.get(s.id) ?? []), t])
            }
          }
        }
      }
    }

    L.push('')
    L.push('  ENKELTDAG PER HORISONT')
    L.push('    h    dekning   uten nylig      n     MAE   median   wMAPE    bias   snitt faktisk')
    for (const h of HORISONTER) {
      const b = perH.get(h)!
      const k = maal(b.treff)
      const dek = b.forsokt > 0 ? `${((b.svart / b.forsokt) * 100).toFixed(1)} %` : '—'
      const un = b.svart > 0 ? `${((b.utenNylig / b.svart) * 100).toFixed(1)} %` : '—'
      L.push(
        `   ${String(h).padStart(2)}    ${dek.padStart(7)}   ${un.padStart(8)}  `
        + `${String(n0(k?.n ?? 0)).padStart(5)}  ${(k ? n1(k.mae) : '—').padStart(6)}  `
        + `${(k ? n1(k.medianFeil) : '—').padStart(6)}  `
        + `${(k?.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(7)}  `
        + `${(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—').padStart(6)}  `
        + `${(k ? n1(k.snittFaktisk) : '—').padStart(13)}`,
      )
    }

    L.push('')
    L.push(`  KANARIEN ${KANARI} PER STASJON OG HORISONT — wMAPE`)
    L.push('    stasjon                ' + HORISONTER.map((h) => `h${h}`.padStart(8)).join(''))
    for (const s of stasjoner) {
      const celler = HORISONTER.map((h) => {
        const k = maal(perH.get(h)!.perStasjon.get(s.id) ?? [])
        return (k?.wmape != null ? `${n1(k.wmape)}%` : '—').padStart(8)
      })
      L.push(`    ${(navnFor.get(s.id) ?? '').padEnd(22)}${celler.join('')}`)
    }

    // =================================================================
    // 2 PERIODETOTAL — alle dagene laget paa SAMME tidspunkt
    // =================================================================
    //
    // «Hvor mye neste uke?» er syv dagsprognoser laget I DAG, ikke syv
    // prognoser laget hver sin dag. Derfor ett prognosetidspunkt T per
    // periode, og horisontene 1..P under det.
    L.push('')
    L.push('  PERIODETOTAL — alle dager laget paa samme tidspunkt')
    L.push('  En P-dagers total bestaar av horisontene h1..hP fra ETT '
      + 'prognosetidspunkt.')
    L.push('  «De neste sju dagene» er h1..h7. «Neste kalenderuke» spurt en '
      + 'torsdag er h4..h10')
    L.push('  og er IKKE det samme - den er ikke maalt her.')
    L.push('')
    L.push('    dager   horisonter   perioder   komplette      MAE     wMAPE    bias   snitt faktisk')
    for (const P of PERIODER) {
      const treff: Treff[] = []
      // KOMPLETTE PERIODER FOR SEG.
      //
      // Foerste kjoering ga «7 dager: wMAPE 19,9 %» - men bare 306 av 923
      // perioder hadde data alle sju dagene. `46,9 / 11,0 ~ 4,3`: en
      // gjennomsnittlig «uke» var fire dager. Sammenligningen var aerlig
      // (samme dager paa begge sider), men det var ikke en ukesum.
      const komplettTreff: Treff[] = []
      const komplettPerStasjon = new Map<string, Treff[]>()
      let forsokt = 0
      let komplette = 0
      for (let i = TEST_DAGER; i >= 1; i--) {
        const T = leggTilDager(til, -(P + i - 1))
        for (const s of stasjoner) {
          for (const ean of eanListe) {
            const n = `${s.id}|${ean}`
            const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
            let sumF = 0
            let sumA = 0
            let alleDekket = true
            let harFasit = false
            for (let d = 1; d <= P; d++) {
              const dato = leggTilDager(T, d)
              const a = fasit.get(`${n}|${dato}`)
              const sv = forventetSalg({
                enhet: { stasjonId: s.id, ean }, maalDato: dato, salg: tilgjengelig,
                modell: MODELL, minstDagerMedSalg: MINST_DAGER,
              })
              if (sv.slag !== 'beregnet') { alleDekket = false; continue }
              // BARE DAGER MED FASIT TELLES PAA BEGGE SIDER. En dag uten
              // rad vet vi ikke salget for, og den kan ikke ligge i den
              // ene summen og mangle i den andre.
              if (a === undefined) { alleDekket = false; continue }
              harFasit = true
              sumF += sv.antall
              sumA += a
            }
            forsokt++
            if (!harFasit) continue
            const t = { forventet: sumF, faktisk: sumA }
            treff.push(t)
            if (alleDekket) {
              komplette++
              komplettTreff.push(t)
              komplettPerStasjon.set(s.id, [...(komplettPerStasjon.get(s.id) ?? []), t])
            }
          }
        }
      }
      const rad = (merke: string, k: ReturnType<typeof maal>, n: number) => L.push(
        `    ${String(P).padStart(5)}   ${`h1..h${P}`.padStart(10)}   `
        + `${String(n0(n)).padStart(8)}   ${merke.padStart(9)}  `
        + `${(k ? n1(k.mae) : '—').padStart(7)}  `
        + `${(k?.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(8)}  `
        + `${(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—').padStart(6)}  `
        + `${(k ? n1(k.snittFaktisk) : '—').padStart(13)}`,
      )
      rad('alle', maal(treff), treff.length)
      rad('KOMPLETTE', maal(komplettTreff), komplettTreff.length)
      L.push(`            av ${n0(forsokt)} forsoek, ${n0(komplette)} komplette; «komplett» = `
        + `alle ${P} dagene hadde baade dekning og fasit`)

      if (P === 7) {
        L.push('            komplette 7-dagersperioder per stasjon:')
        for (const st of stasjoner) {
          const t = komplettPerStasjon.get(st.id) ?? []
          const k2 = maal(t)
          if (!k2) continue
          L.push(
            `              ${(navnFor.get(st.id) ?? '').padEnd(22)} `
            + `n ${String(k2.n).padStart(4)}   MAE ${n1(k2.mae).padStart(6)}   `
            + `wMAPE ${(k2.wmape != null ? `${n1(k2.wmape)} %` : '—').padStart(7)}   `
            + `bias ${((k2.bias >= 0 ? '+' : '') + n1(k2.bias)).padStart(6)}   `
            + `snitt faktisk ${n1(k2.snittFaktisk)}`,
          )
        }
      }
    }

    // =================================================================
    // 3 NESTE KALENDERUKE, SPURT PAA HVER UKEDAG
    // =================================================================
    //
    // «De neste sju dagene» og «neste kalenderuke» er ikke det samme.
    // Den foerste er alltid h1..h7. Den andre flytter seg med ukedagen
    // spoersmaalet stilles paa:
    //
    //   spurt soendag   -> man..soen er h1..h7
    //   spurt torsdag   -> h4..h10
    //   spurt mandag    -> h7..h13
    //
    // Maalt her: for hvert prognosetidspunkt T finnes foerste mandag
    // STRENGT etter T, og de syv dagene fra den. Bare komplette uker
    // teller - en uke der noen dager mangler fasit eller dekning er ikke
    // en ukesum.
    const UKEDAG = ['soendag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'loerdag']
    const ukedagAv = (d: string) => new Date(`${d}T12:00:00Z`).getUTCDay()
    /** Foerste mandag strengt etter `d`. */
    const nesteMandag = (d: string) => {
      const u = ukedagAv(d)
      return leggTilDager(d, ((8 - u) % 7) || 7)
    }

    type Ukebunt = { treff: Treff[]; horisonter: Set<number> }
    const perUkedag = new Map<number, Ukebunt>()

    // Prognosetidspunktene maa ligge slik at hele uken er innenfor
    // datavinduet: verste fall er h13.
    for (let i = TEST_DAGER + 13; i >= 13; i--) {
      const T = leggTilDager(til, -i)
      const man = nesteMandag(T)
      const hStart = Math.round(
        (Date.parse(`${man}T12:00:00Z`) - Date.parse(`${T}T12:00:00Z`)) / 86400000)
      if (hStart + 6 > 13) continue
      const b2 = perUkedag.get(ukedagAv(T)) ?? { treff: [], horisonter: new Set<number>() }
      for (let k = 0; k < 7; k++) b2.horisonter.add(hStart + k)
      for (const s of stasjoner) {
        for (const ean of eanListe) {
          const n = `${s.id}|${ean}`
          const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
          let sumF = 0
          let sumA = 0
          let komplett = true
          for (let k = 0; k < 7; k++) {
            const dato = leggTilDager(man, k)
            const a2 = fasit.get(`${n}|${dato}`)
            const sv = forventetSalg({
              enhet: { stasjonId: s.id, ean }, maalDato: dato, salg: tilgjengelig,
              modell: MODELL, minstDagerMedSalg: MINST_DAGER,
            })
            if (sv.slag !== 'beregnet' || a2 === undefined) { komplett = false; break }
            sumF += sv.antall
            sumA += a2
          }
          if (!komplett) continue
          b2.treff.push({ forventet: sumF, faktisk: sumA })
        }
      }
      perUkedag.set(ukedagAv(T), b2)
    }

    L.push('')
    L.push('  NESTE KALENDERUKE — komplette uker, per ukedag spoersmaalet stilles')
    L.push('    spurt paa    horisonter       n      MAE     wMAPE    bias   snitt faktisk')
    for (let u = 0; u < 7; u++) {
      const b3 = perUkedag.get(u)
      if (!b3 || b3.treff.length === 0) continue
      const hs = [...b3.horisonter].sort((x, y) => x - y)
      const k = maal(b3.treff)!
      L.push(
        `    ${UKEDAG[u].padEnd(11)}  ${`h${hs[0]}..h${hs[hs.length - 1]}`.padStart(10)}   `
        + `${String(n0(k.n)).padStart(5)}  ${n1(k.mae).padStart(7)}  `
        + `${(k.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(8)}  `
        + `${((k.bias >= 0 ? '+' : '') + n1(k.bias)).padStart(6)}  `
        + `${n1(k.snittFaktisk).padStart(13)}`,
      )
    }

    L.push('')
    L.push('  Ingen grense er satt. Ingen rad er endret.')
    L.push('')
    console.log(L.join('\n'))

    // ── VAKTER ──────────────────────────────────────────────────────────
    expect(perH.get(1)!.treff.length, 'h=1 ga ingen observasjoner').toBeGreaterThan(0)

    // KANARIFUGL FOR PROGNOSETIDSPUNKTET.
    //
    // Er filteret uvirksomt, ser h=30 like mye data som h=1, og hele
    // maalingen blir en kopi av seg selv. Da MAA `nyligSnitt` finnes
    // like ofte paa h=30 som paa h=1 - og det er nettopp det som ikke
    // skal skje.
    const u1 = perH.get(1)!
    const u30 = perH.get(30)!
    expect(
      u30.svart > 0 ? u30.utenNylig / u30.svart : 0,
      'h=30 mangler ikke nyligSnitt oftere enn h=1 — ser motoren framtidige data?',
    ).toBeGreaterThan(u1.svart > 0 ? u1.utenNylig / u1.svart : 0)
  }, 900_000)
})
