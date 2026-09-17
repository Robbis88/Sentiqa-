import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { leggTilDager } from '@/lib/produksjonsplan'
import { forventetSalg, MODELLER, type Salgsrad } from './motor'

// =====================================================================
// HORISONT PÅ ET UTVALG SOM FAKTISK LIGNER POPULASJONEN — READ ONLY
// =====================================================================
//
// Den første horisontmålingen ga h1–h7 flatt på ~32 % wMAPE. Den hvilte
// på ATTEN (stasjon, vare)-par.
//
// Dekningsmålingen forklarte hvorfor: utvalget ble trukket fra hele
// katalogen, hver 86. vare etter volumrang — men terskelen på 60
// salgsdager er i praksis et topp-3-desil-filter:
//
//   desil 1   87,6 % passerer      desil 4    4,8 %
//   desil 2   50,1 %               desil 5    0,8 %
//   desil 3   18,9 %               desil 6-10 0,0 %
//
// To av tre trukne varer lå i desiler der ingenting passerer. Riktig
// utvalgsramme er PARENE SOM PASSERER — de er de eneste verktøyet
// svarer på.
//
// ---------------------------------------------------------------------
// SELEKSJONSLEKKASJE ER OGSÅ LEKKASJE
// ---------------------------------------------------------------------
//
// Å kvalifisere et par på data fra HELE vinduet, og så måle prognoser
// midt inne i det vinduet, er å velge testobjekter med fasiten i hånd.
// Et par som såvidt nådde 60 salgsdager takket være uken etter
// prognosetidspunktet, ville kommet med — og det er en lettere
// populasjon enn den motoren møter.
//
// Derfor kvalifiseres hvert par ÉN gang, på `T0` = det TIDLIGSTE
// prognosetidspunktet i hele målingen, med bare `dato <= T0`. Alt som
// måles ligger etter T0.
//
// Motoren sjekker terskelen på nytt ved hvert kall. Et par valgt ved T0
// som ikke lenger holder ved måldagen, faller ut som `ikke_dekning` —
// og det er nettopp hva dekningskolonnen skal vise.
//
// ---------------------------------------------------------------------
// TO PASS OVER BASEN
// ---------------------------------------------------------------------
//
//   1  Kvalifisering: teller salgsdager per par over motorens
//      432-dagersvindu fram til T0. Radene KASTES underveis —
//      primærnøkkelen `(retailer, stasjon, dato, ean)` garanterer én rad
//      per par og dag, så en teller holder; et `Set` ville brukt
//      hundrevis av megabyte til ingen nytte.
//
//   2  Historikk for de 200 valgte parene. Lite nok til å holde i minnet.
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
const pst = (a: number, b: number) => (b > 0 ? `${((a / b) * 100).toFixed(1)} %` : '—')

/** Samme modell og terskel som `ai/forventetverktoy.ts`. */
const MODELL = MODELLER.find((m) => m.navn === 'basis+trend')!
const MINST_DAGER = 60
/** Motorens eget tilbakeblikk. Kvalifiseringen bruker samme vindu. */
const LOOKBACK = 432

const HORISONTER = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
const TEST_DAGER = 28
const MAAL_PAR = 200
const MIN_PER_STASJON = 30
const KANARI = '5000112636833'

type Rad = { stasjon_id: string; dato: string; ean: string; antall: number | null }
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

const rad = (etikett: string, k: ReturnType<typeof maal>, ekstra = '') =>
  `    ${etikett.padEnd(24)} ${String(n0(k?.n ?? 0)).padStart(6)}  `
  + `${(k ? n1(k.mae) : '—').padStart(7)}  ${(k ? n1(k.medianFeil) : '—').padStart(6)}  `
  + `${(k?.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(8)}  `
  + `${(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—').padStart(7)}  `
  + `${(k ? n1(k.snittFaktisk) : '—').padStart(13)}${ekstra}`

const HODE = '    gruppe                        n      MAE   median     wMAPE     bias   snitt faktisk'

/**
 * Populasjonsvektet samling over stasjoner.
 *
 * DET BALANSERTE UTVALGET ER IKKE KJEDEN. Vi tar 40 par fra hver
 * stasjon, men Boenes har ~167 kvalifiserte og Laguneparken ~361. Et
 * uvektet snitt gir da Boenes for stor vekt i totalen.
 *
 * Hver stasjons bidrag skaleres med `kvalifiserte / valgte`, slik at
 * totalen svarer paa «hvordan gjoer motoren det over KJEDENS
 * kvalifiserte par» - ikke «over mine 200».
 *
 * BEGGE RAPPORTERES. Totalen erstatter ikke stasjonstallene; den er et
 * annet spoersmaal, og et snitt som skjuler at Boenes ligger dobbelt saa
 * hoeyt ville vaert den verste av de to.
 */
function vektet(
  perStasjon: Map<string, Treff[]>,
  vekt: Map<string, number>,
): { n: number; mae: number; wmape: number | null; bias: number; snittFaktisk: number } | null {
  let vN = 0
  let vFeil = 0
  let vFaktisk = 0
  let vBias = 0
  let n = 0
  for (const [st, t] of perStasjon) {
    if (t.length === 0) continue
    const w = (vekt.get(st) ?? 0) / t.length
    if (w <= 0) continue
    n += t.length
    vN += w * t.length
    for (const x of t) {
      vFeil += w * Math.abs(x.forventet - x.faktisk)
      vFaktisk += w * x.faktisk
      vBias += w * (x.forventet - x.faktisk)
    }
  }
  if (vN === 0) return null
  return {
    n, mae: vFeil / vN, wmape: vFaktisk > 0 ? (vFeil / vFaktisk) * 100 : null,
    bias: vBias / vN, snittFaktisk: vFaktisk / vN,
  }
}

describe('HORISONT BREDT — representativt utvalg av kvalifiserte par', () => {
  kjor('h1-h13, rullerende uke og kalenderuke', async () => {
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
    // T0 er det TIDLIGSTE prognosetidspunktet i hele maalingen.
    // Kalenderuken gaar lengst bakover: TEST_DAGER + 13.
    const T0 = leggTilDager(til, -(TEST_DAGER + 13))
    const kvalFra = leggTilDager(T0, -LOOKBACK)

    const L: string[] = ['', '  HORISONT BREDT — REPRESENTATIVT UTVALG', '']
    L.push('  DATOER — for kontroll mot off-by-one')
    L.push(`    T0 (kvalifiseringstidspunkt)   ${T0}`)
    L.push(`    kvalifiseringsvindu foerste    ${kvalFra}`)
    L.push(`    kvalifiseringsvindu siste      ${T0}`)
    L.push(`    foerste maaldato               ${leggTilDager(til, -(TEST_DAGER - 1))}`)
    L.push(`    siste maaldato                 ${til}`)
    L.push(`    tidligste prognosetidspunkt    ${leggTilDager(til, -(TEST_DAGER + 13))}`)
    L.push('  VINDUET ER PRODUKSJONENS. `ai/forventetverktoy.ts` bruker')
    L.push('  HISTORIKK_DAGER = 364 + 28 + 40 = 432 og henter')
    L.push('  `gte(idag-432) .. lte(idag)` - begge ender med. Her staar T0 der')
    L.push('  `idag` staar, med samme inklusivitet i begge ender.')
    L.push('  SELEKSJONSLEKKASJE SPERRET: kvalifisering bruker bare `dato <= T0`,')
    L.push('  og alt som maales ligger etter T0.')
    L.push(`  modell ${MODELL.navn}   terskel ${MINST_DAGER} salgsdager`)

    // ── PASS 1: KVALIFISERING ───────────────────────────────────────────
    const SIDE = 1000
    const salgsdager = new Map<string, number>()
    const parVolum = new Map<string, number>()
    let lest = 0
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall')
        .gte('dato', kvalFra).lte('dato', T0)
        .order('dato', { ascending: true }).order('ean', { ascending: true })
        .range(f, f + SIDE - 1).overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg (kvalifisering): ${rf.message}`)
      const side = data ?? []
      lest += side.length
      for (const r of side) {
        const a = r.antall ?? 0
        const n = `${r.stasjon_id}|${r.ean}`
        parVolum.set(n, (parVolum.get(n) ?? 0) + a)
        // PRIMAERNOEKKELEN GARANTERER ÉN RAD PER PAR OG DAG, saa en
        // teller er noeyaktig og et `Set` ville bare kostet minne.
        if (a > 0) salgsdager.set(n, (salgsdager.get(n) ?? 0) + 1)
      }
      if (side.length < SIDE) break
    }
    L.push(`  rader lest i kvalifiseringen: ${n0(lest)}`)

    const kvalifiserte = [...salgsdager.entries()]
      .filter(([, d]) => d >= MINST_DAGER).map(([n]) => n)
    L.push('')
    L.push(`  KVALIFISERTE PAR: ${n0(kvalifiserte.length)} av ${n0(salgsdager.size)} med salg   `
      + pst(kvalifiserte.length, salgsdager.size))
    expect(kvalifiserte.length, 'ingen par kvalifiserte').toBeGreaterThan(0)

    // ── UTVALGET ────────────────────────────────────────────────────────
    //
    // Per stasjon: kvalifiserte par sortert paa volum, delt i tre like
    // store grupper (hoey/middels/lav BLANT DE KVALIFISERTE), og hver
    // gruppe systematisk gjennomtrukket. Deterministisk - ingen
    // `Math.random`, saa to kjoeringer kan sammenlignes.
    //
    // Har en stasjon faerre kvalifiserte enn kvoten, tas alle, og resten
    // fordeles paa de andre. Kvoten er et maal, ikke en sperre.
    const GRUPPER = ['hoey', 'middels', 'lav'] as const
    type Gruppe = typeof GRUPPER[number]
    const gruppeFor = new Map<string, Gruppe>()
    const perStasjonKval = new Map<string, string[]>()
    for (const n of kvalifiserte) {
      const st = n.split('|')[0]
      perStasjonKval.set(st, [...(perStasjonKval.get(st) ?? []), n])
    }
    for (const [, liste] of perStasjonKval) {
      liste.sort((a, b) => (parVolum.get(b) ?? 0) - (parVolum.get(a) ?? 0))
    }

    const valgte: string[] = []
    const kvote = Math.max(MIN_PER_STASJON, Math.floor(MAAL_PAR / stasjoner.length))
    for (const s of stasjoner) {
      const liste = perStasjonKval.get(s.id) ?? []
      const perGruppe = Math.ceil(kvote / GRUPPER.length)
      const bolkStr = Math.ceil(liste.length / GRUPPER.length)
      for (const [gi, g] of GRUPPER.entries()) {
        const bolk = liste.slice(gi * bolkStr, (gi + 1) * bolkStr)
        if (bolk.length === 0) continue
        // FAST, DOKUMENTERT STARTPUNKT: indeks 0 i hver bolk, deretter
        // hvert `steg`-te element. Ingen offset, ingen `Math.random`.
        // Samme kvalifiseringsvindu gir samme 200 par, hver gang.
        const steg = Math.max(1, Math.floor(bolk.length / perGruppe))
        for (let i = 0, tatt = 0; i < bolk.length && tatt < perGruppe; i += steg, tatt++) {
          valgte.push(bolk[i])
          gruppeFor.set(bolk[i], g)
        }
      }
    }
    // Kanarien staar SEPARAT. Den er en fast kontroll over tid, ikke en
    // del av det representative utvalget - blandes de, kan ikke det ene
    // tallet lenger sammenlignes med tidligere kjoeringer.
    const kanariPar = stasjoner.map((s) => `${s.id}|${KANARI}`)
      .filter((n) => salgsdager.has(n))
    const alleMaalte = [...new Set([...valgte, ...kanariPar])]

    L.push('')
    L.push(`  UTVALG: ${n0(valgte.length)} par (maal ${MAAL_PAR}) `
      + `+ ${kanariPar.length} kanaripar, maalt separat`)
    L.push('    trekk: start paa indeks 0 i hver volumbolk, steg = floor(bolk / kvote)')
    L.push('    stasjon                  kvalifiserte   valgt   hoey  middels  lav')
    for (const s of stasjoner) {
      const kval = (perStasjonKval.get(s.id) ?? []).length
      const mine = valgte.filter((n) => n.startsWith(`${s.id}|`))
      const tell = (g: Gruppe) => mine.filter((n) => gruppeFor.get(n) === g).length
      L.push(
        `    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(n0(kval)).padStart(13)}   `
        + `${String(mine.length).padStart(5)}   ${String(tell('hoey')).padStart(4)}  `
        + `${String(tell('middels')).padStart(7)}  ${String(tell('lav')).padStart(3)}`,
      )
    }
    // VEKTENE, SAA DE KAN KONTROLLERES. Antall kvalifiserte par per
    // stasjon ved T0 er bade grunnlaget for vektingen og tallet som skal
    // kunne etterprøves mot tabellen over.
    const vekt = new Map<string, number>(
      stasjoner.map((s) => [s.id, (perStasjonKval.get(s.id) ?? []).length]))
    const sumKval = [...vekt.values()].reduce((a2, b2) => a2 + b2, 0)
    L.push('    vekter til populasjonsvektet total (kvalifiserte par ved T0):')
    L.push('      ' + stasjoner.map((s) =>
      `${s.butikknummer} ${n0(vekt.get(s.id) ?? 0)} (${pst(vekt.get(s.id) ?? 0, sumKval)})`,
    ).join('   '))

    // Volumspennet i hver gruppe, saa «lav» kan leses som noe konkret.
    L.push('    volumspenn i utvalget (solgt antall i kvalifiseringsvinduet):')
    for (const g of GRUPPER) {
      const v = valgte.filter((n) => gruppeFor.get(n) === g)
        .map((n) => parVolum.get(n) ?? 0).sort((a, b) => a - b)
      if (v.length === 0) continue
      L.push(`      ${g.padEnd(8)} n ${String(v.length).padStart(3)}   `
        + `min ${n0(v[0])}   median ${n0(v[Math.floor(v.length / 2)])}   maks ${n0(v[v.length - 1])}`)
    }

    // ── PASS 2: HISTORIKK FOR UTVALGET ──────────────────────────────────
    const eanListe = [...new Set(alleMaalte.map((n) => n.split('|')[1]))]
    const perEnhet = new Map<string, Salgsrad[]>()
    const fasit = new Map<string, number>()
    let lest2 = 0
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall')
        .in('ean', eanListe).gte('dato', kvalFra).lte('dato', til)
        .order('dato', { ascending: true }).range(f, f + SIDE - 1)
        .overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg (historikk): ${rf.message}`)
      const side = data ?? []
      lest2 += side.length
      for (const r of side) {
        const n = `${r.stasjon_id}|${r.ean}`
        if (!alleMaalte.includes(n)) continue
        const s: Salgsrad = {
          stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
          varegruppeKode: null, varegruppeNavn: null,
        }
        perEnhet.set(n, [...(perEnhet.get(n) ?? []), s])
        fasit.set(`${n}|${r.dato}`, (fasit.get(`${n}|${r.dato}`) ?? 0) + s.antall)
      }
      if (side.length < SIDE) break
    }
    L.push(`  rader lest for utvalget: ${n0(lest2)}`)

    const maaldatoer: string[] = []
    for (let i = TEST_DAGER; i >= 1; i--) maaldatoer.push(leggTilDager(til, -(i - 1)))

    // =================================================================
    // 1 ENKELTDAG h1..h13
    // =================================================================
    type Bunt = {
      treff: Treff[]; forsokt: number; svart: number
      perStasjon: Map<string, Treff[]>; perGruppe: Map<string, Treff[]>
      kanari: Treff[]
    }
    const perH = new Map<number, Bunt>()
    for (const h of HORISONTER) {
      perH.set(h, {
        treff: [], forsokt: 0, svart: 0,
        perStasjon: new Map(), perGruppe: new Map(), kanari: [],
      })
    }

    for (const h of HORISONTER) {
      const b = perH.get(h)!
      for (const d of maaldatoer) {
        const sisteKjente = leggTilDager(d, -h)
        for (const n of alleMaalte) {
          const [stasjonId, ean] = n.split('|')
          const f = fasit.get(`${n}|${d}`)
          if (f === undefined) continue
          const erKanari = ean === KANARI
          if (!erKanari) b.forsokt++
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: d,
            salg: (perEnhet.get(n) ?? []).filter((r) => r.dato <= sisteKjente),
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet') continue
          const t = { forventet: sv.antall, faktisk: f }
          if (erKanari) { b.kanari.push(t); continue }
          b.svart++
          b.treff.push(t)
          b.perStasjon.set(stasjonId, [...(b.perStasjon.get(stasjonId) ?? []), t])
          const g = gruppeFor.get(n) ?? 'ukjent'
          b.perGruppe.set(g, [...(b.perGruppe.get(g) ?? []), t])
        }
      }
    }

    L.push('')
    L.push('  ENKELTDAG h1..h13 — UVEKTET (det balanserte utvalget)')
    L.push('    h    dekning' + HODE.slice(HODE.indexOf('n', 10) - 6))
    for (const h of HORISONTER) {
      const b = perH.get(h)!
      const k = maal(b.treff)
      L.push(`   ${String(h).padStart(2)}    ${pst(b.svart, b.forsokt).padStart(7)}`
        + rad('', k).slice(4))
    }

    L.push('')
    L.push('  ENKELTDAG h1..h13 — POPULASJONSVEKTET (kvalifiserte par per stasjon)')
    L.push('    h         n      MAE     wMAPE     bias   snitt faktisk')
    for (const h of HORISONTER) {
      const v = vektet(perH.get(h)!.perStasjon, vekt)
      L.push(
        `   ${String(h).padStart(2)}   ${String(n0(v?.n ?? 0)).padStart(6)}  `
        + `${(v ? n1(v.mae) : '—').padStart(7)}  `
        + `${(v?.wmape != null ? `${n1(v.wmape)} %` : '—').padStart(8)}  `
        + `${(v ? (v.bias >= 0 ? '+' : '') + n1(v.bias) : '—').padStart(7)}  `
        + `${(v ? n1(v.snittFaktisk) : '—').padStart(13)}`,
      )
    }
    L.push('    Vektet total ERSTATTER IKKE stasjonstallene under. Den svarer paa')
    L.push('    et annet spoersmaal, og et snitt som skjuler at én stasjon ligger')
    L.push('    dobbelt saa hoeyt er den verste av de to.')

    for (const [tittel, velg] of [
      ['PER STASJON', (b: Bunt) => b.perStasjon],
      ['PER VOLUMGRUPPE', (b: Bunt) => b.perGruppe],
    ] as const) {
      L.push('')
      L.push(`  ${tittel} — wMAPE per horisont`)
      const noekler = [...new Set(HORISONTER.flatMap((h) => [...velg(perH.get(h)!).keys()]))]
      L.push('    gruppe                ' + HORISONTER.map((h) => `h${h}`.padStart(7)).join(''))
      for (const key of noekler) {
        const celler = HORISONTER.map((h) => {
          const k = maal(velg(perH.get(h)!).get(key) ?? [])
          return (k?.wmape != null ? `${n1(k.wmape)}%` : '—').padStart(7)
        })
        L.push(`    ${(navnFor.get(key) ?? key).padEnd(20)}${celler.join('')}`)
      }
    }

    L.push('')
    L.push(`  KANARIEN ${KANARI} — separat fra utvalget`)
    L.push('    h1..h13 wMAPE: ' + HORISONTER.map((h) => {
      const k = maal(perH.get(h)!.kanari)
      return k?.wmape != null ? `${n1(k.wmape)}%` : '—'
    }).join('  '))

    // =================================================================
    // 2 RULLERENDE UKE h1..h7 — KOMPLETTE
    // =================================================================
    const uke: Treff[] = []
    const ukePerStasjon = new Map<string, Treff[]>()
    const ukePerGruppe = new Map<string, Treff[]>()
    let ukeForsokt = 0
    for (let i = TEST_DAGER; i >= 1; i--) {
      const T = leggTilDager(til, -(7 + i - 1))
      for (const n of valgte) {
        const [stasjonId, ean] = n.split('|')
        const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
        let sumF = 0
        let sumA = 0
        let komplett = true
        for (let d = 1; d <= 7; d++) {
          const dato = leggTilDager(T, d)
          const a = fasit.get(`${n}|${dato}`)
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: dato, salg: tilgjengelig,
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet' || a === undefined) { komplett = false; break }
          sumF += sv.antall
          sumA += a
        }
        ukeForsokt++
        if (!komplett) continue
        const t = { forventet: sumF, faktisk: sumA }
        uke.push(t)
        ukePerStasjon.set(stasjonId, [...(ukePerStasjon.get(stasjonId) ?? []), t])
        const g = gruppeFor.get(n) ?? 'ukjent'
        ukePerGruppe.set(g, [...(ukePerGruppe.get(g) ?? []), t])
      }
    }
    L.push('')
    L.push(`  RULLERENDE UKE h1..h7 — KOMPLETTE (${n0(uke.length)} av ${n0(ukeForsokt)} forsoek)`)
    L.push(HODE)
    L.push(rad('samlet (uvektet)', maal(uke)))
    const vUke = vektet(ukePerStasjon, vekt)
    L.push(`    ${'samlet (populasjonsvektet)'.padEnd(24)} `
      + `${String(n0(vUke?.n ?? 0)).padStart(6)}  ${(vUke ? n1(vUke.mae) : '—').padStart(7)}  `
      + `${'—'.padStart(6)}  `
      + `${(vUke?.wmape != null ? `${n1(vUke.wmape)} %` : '—').padStart(8)}  `
      + `${(vUke ? (vUke.bias >= 0 ? '+' : '') + n1(vUke.bias) : '—').padStart(7)}  `
      + `${(vUke ? n1(vUke.snittFaktisk) : '—').padStart(13)}`)
    for (const s of stasjoner) {
      const t = ukePerStasjon.get(s.id)
      if (t?.length) L.push(rad(navnFor.get(s.id) ?? s.id, maal(t)))
    }
    for (const g of GRUPPER) {
      const t = ukePerGruppe.get(g)
      if (t?.length) L.push(rad(`volum: ${g}`, maal(t)))
    }

    // =================================================================
    // 3 NESTE KALENDERUKE, PER UKEDAG
    // =================================================================
    const UKEDAG = ['soendag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'loerdag']
    const ukedagAv = (d: string) => new Date(`${d}T12:00:00Z`).getUTCDay()
    const nesteMandag = (d: string) => leggTilDager(d, ((8 - ukedagAv(d)) % 7) || 7)

    const perUkedag = new Map<number, { treff: Treff[]; hs: Set<number> }>()
    for (let i = TEST_DAGER + 13; i >= 13; i--) {
      const T = leggTilDager(til, -i)
      const man = nesteMandag(T)
      const hStart = Math.round(
        (Date.parse(`${man}T12:00:00Z`) - Date.parse(`${T}T12:00:00Z`)) / 86400000)
      if (hStart + 6 > 13) continue
      const b = perUkedag.get(ukedagAv(T)) ?? { treff: [], hs: new Set<number>() }
      for (let k = 0; k < 7; k++) b.hs.add(hStart + k)
      for (const n of valgte) {
        const [stasjonId, ean] = n.split('|')
        const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
        let sumF = 0
        let sumA = 0
        let komplett = true
        for (let k = 0; k < 7; k++) {
          const dato = leggTilDager(man, k)
          const a = fasit.get(`${n}|${dato}`)
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: dato, salg: tilgjengelig,
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet' || a === undefined) { komplett = false; break }
          sumF += sv.antall
          sumA += a
        }
        if (komplett) b.treff.push({ forventet: sumF, faktisk: sumA })
      }
      perUkedag.set(ukedagAv(T), b)
    }
    L.push('')
    L.push('  NESTE KALENDERUKE — komplette uker, per ukedag spoersmaalet stilles')
    L.push('    spurt paa    horisonter' + HODE.slice(HODE.indexOf('n', 10) - 6))
    for (let u = 0; u < 7; u++) {
      const b = perUkedag.get(u)
      if (!b || b.treff.length === 0) continue
      const hs = [...b.hs].sort((x, y) => x - y)
      L.push(`    ${UKEDAG[u].padEnd(11)}  ${`h${hs[0]}..h${hs[hs.length - 1]}`.padStart(10)}`
        + rad('', maal(b.treff)).slice(4))
    }

    L.push('')
    L.push('  Ingen grense er satt. Ingen rad er endret.')
    L.push('')
    console.log(L.join('\n'))

    // ── VAKTER ──────────────────────────────────────────────────────────
    expect(valgte.length, 'utvalget ble tomt').toBeGreaterThan(0)
    expect(perH.get(1)!.treff.length, 'h1 ga ingen observasjoner').toBeGreaterThan(0)
    // Alle fem stasjoner MAA vaere representert, ellers er «per stasjon»
    // en delmengde forkledd som en oversikt.
    expect(
      new Set(valgte.map((n) => n.split('|')[0])).size,
      'ikke alle stasjoner er med i utvalget',
    ).toBe(stasjoner.length)
    // Og alle tre volumgrupper, ellers maaler «per volumgruppe» ingenting.
    expect(new Set([...gruppeFor.values()]).size, 'ikke alle volumgrupper er med').toBe(3)
  }, 1_800_000)
})
