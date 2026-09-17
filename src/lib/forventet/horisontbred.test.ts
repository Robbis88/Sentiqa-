import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { leggTilDager } from '@/lib/produksjonsplan'
import { forventetSalg, MODELLER, type Salgsrad } from './motor'
import { maalTreff, tillit, type Tillit } from './treffsikkerhet'

// =====================================================================
// HORISONT OG MÅLT KVALITET PER PAR — READ ONLY
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
// «INGEN RAD» ER IKKE ALLTID «INGEN FASIT»
// ---------------------------------------------------------------------
//
// Forrige kjøring meldte: «Ingen lavvolumspar fikk en komplett uke.»
// Det var en feil i MÅLINGEN, ikke et funn om dataene.
//
// En dag uten varerad ble behandlet som manglende fasit. Men har
// STASJONEN salgsdata den dagen — importen kjørte, andre varer ble
// solgt — så solgte denne varen null. Det er et tall, ikke et hull.
//
//   stasjonen har INGEN rad den dagen    ->  fasit mangler, hopp over
//   stasjonen har rader, varen ikke      ->  faktisk = 0
//
// Uten det skillet krever «komplett uke» at varen selger alle sju
// dagene, og da måler vi bare toppsjiktet — nøyaktig det utvalget
// skulle komme bort fra. 669 av 678 komplette uker var høyvolum.
//
// Skillet gjelder BARE fasiten i denne målingen. `maalTreff` hopper
// fortsatt over dager uten rad, fordi det er det produksjonen gjør, og
// klassifiseringen må speile produksjonen for å bety noe.
//
// ---------------------------------------------------------------------
// KVALITET KLASSIFISERES PÅ PROGNOSETIDSPUNKTET
// ---------------------------------------------------------------------
//
// «god/middels/svak» avgjøres av `maalTreff` over de 28 dagene FØR
// prognosetidspunktet T — samme vindu `ai/forventetverktoy.ts` bruker.
// Hver forecast der inne ser bare data før sin egen måldag, og alle
// måldagene ligger før T. Måldagen vi skal bedømme, og alt etter den,
// rører ikke klassifiseringen.
//
// Så måles den faktiske feilen ETTERPÅ. Er «god» ikke bedre framover
// enn «svak», er nivåene en merkelapp uten innhold, og en sperre på dem
// ville fjernet svar uten å fjerne feil.
//
// ---------------------------------------------------------------------
// SELEKSJONSLEKKASJE ER OGSÅ LEKKASJE
// ---------------------------------------------------------------------
//
// Å kvalifisere et par på data fra HELE vinduet, og så måle prognoser
// midt inne i det vinduet, er å velge testobjekter med fasiten i hånd.
// Derfor kvalifiseres hvert par ÉN gang, på `T0` = det TIDLIGSTE
// prognosetidspunktet i hele målingen, med bare `dato <= T0`.
//
// ---------------------------------------------------------------------
// TRE PASS OVER BASEN
// ---------------------------------------------------------------------
//
//   1  Kvalifisering: salgsdager og volum per par over motorens
//      432-dagersvindu fram til T0.
//
//   2  Historikk for de ~200 valgte parene. Rad for rad — motoren
//      trenger selve serien, og det er det eneste stedet den trengs.
//
//   3  Hvilke (stasjon, dag) som i det hele tatt har salgsdata.
//
// PASS 1 OG 3 ER RENE TELLINGER, og de kommer fra SQL i stedet for fra
// PostgREST. `v_butikksalg` returnerer maks 1 000 rader per kall, så
// klienten måtte dra 565 000 rader hjem for å telle dem selv — 598 av
// 671 forespørsler, og det meste av de 23 minuttene kjøringen tok.
//
// Det er IKKE en annen sannhet: samme telling av samme rader, gjort ett
// sted i stedet for to. `supabase/tests/forventet_grunnlag.sql` kjøres i
// SQL Editor, resultatet lastes ned som `kanari-grunnlag.csv` i repoets
// rot. Modellen ligger fortsatt i `forventetSalg` og skal aldri skrives
// om i SQL — da ville målingen målt noe annet enn brukeren får.
//
// VAKT: etter pass 2 telles salgsdager og volum på nytt for hvert målt
// par, ut av de levende radene, og holdes mot CSV-en. Er fila gammel
// eller fra et annet vindu, blir kjøringen rød i stedet for å måle en
// annen populasjon i stillhet.
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

/**
 * Minimal CSV-leser for nedlastingen fra Supabase SQL Editor.
 *
 * Haandterer sitat, doblet sitat inne i sitat, og CRLF. Ingen avhengighet
 * - en parser paa tjue linjer er lettere aa etterproeve enn en pakke.
 */
function lesCsv(sti: string): Record<string, string>[] {
  const tekst = readFileSync(sti, 'utf8').replace(/^﻿/, '')
  const rader: string[][] = []
  let felt = ''
  let rad: string[] = []
  let iSitat = false
  for (let i = 0; i < tekst.length; i++) {
    const c = tekst[i]
    if (iSitat) {
      if (c !== '"') felt += c
      else if (tekst[i + 1] === '"') { felt += '"'; i++ }
      else iSitat = false
    } else if (c === '"') iSitat = true
    else if (c === ',') { rad.push(felt); felt = '' }
    else if (c === '\n') { rad.push(felt); felt = ''; rader.push(rad); rad = [] }
    else if (c !== '\r') felt += c
  }
  if (felt !== '' || rad.length > 0) { rad.push(felt); rader.push(rad) }
  const hode = (rader.shift() ?? []).map((h) => h.trim())
  return rader
    .filter((r) => r.some((x) => x !== ''))
    .map((r) => Object.fromEntries(hode.map((h, i) => [h, r[i] ?? ''])))
}

const n0 = (n: number) => Math.round(n).toLocaleString('nb-NO')
const n1 = (n: number) => n.toFixed(1)
const pst = (a: number, b: number) => (b > 0 ? `${((a / b) * 100).toFixed(1)} %` : '—')

/** Samme modell og terskel som `ai/forventetverktoy.ts`. */
const MODELL = MODELLER.find((m) => m.navn === 'basis+trend')!
const MINST_DAGER = 60
/** Motorens eget tilbakeblikk. Kvalifiseringen bruker samme vindu. */
const LOOKBACK = 432
/** `TREFF_DAGER` i `ai/forventetverktoy.ts`. Klassifiseringens vindu. */
const TREFF_VINDU = 28

const HORISONTER = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
const TEST_DAGER = 28
const MAAL_PAR = 200
const MIN_PER_STASJON = 30
const KANARI = '5000112636833'
const NIVAAER: Tillit[] = ['god', 'middels', 'svak', 'ukjent']

/**
 * VINDUET ER PINNET, IKKE UTLEDET AV `new Date()`.
 *
 * Grunnlaget kommer fra en CSV som ble laget paa et bestemt tidspunkt.
 * Regnet testen ut `idag - 2` selv, ville en kjoering dagen etter maalt
 * et vindu CSV-en ikke dekker - og den slags gli merkes ikke, den bare
 * gir et litt annet tall.
 *
 * Endres denne, skal `supabase/tests/forventet_grunnlag.sql` kjoeres paa
 * nytt med de samme datoene. Kryssjekken mot levende data felle
 * kjoeringen hvis de to sklir fra hverandre.
 */
const TIL = '2026-09-15'
const T0 = leggTilDager(TIL, -(TEST_DAGER + 13))
const KVAL_FRA = leggTilDager(T0, -LOOKBACK)
const GRUNNLAG = 'kanari-grunnlag.csv'

type Rad = { stasjon_id: string; dato: string; ean: string; antall: number | null }
type Treff = { forventet: number; faktisk: number }

function maal(t: readonly Treff[]) {
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

// Kolonnene bygges av de SAMME uttrykkene i hodet og i raden, saa de
// ikke kan gli fra hverandre naar en bredde endres.
const K = {
  etikett: (s: string) => s.padEnd(26),
  n: (s: string) => s.padStart(7),
  mae: (s: string) => s.padStart(8),
  med: (s: string) => s.padStart(7),
  wmape: (s: string) => s.padStart(9),
  bias: (s: string) => s.padStart(8),
  snitt: (s: string) => s.padStart(14),
}
const HODE = '    ' + K.etikett('gruppe') + K.n('n') + K.mae('MAE') + K.med('median')
  + K.wmape('wMAPE') + K.bias('bias') + K.snitt('snitt faktisk')
/** Der talldelen av HODE begynner — brukes av tabeller med eget venstrefelt. */
const HODE_TALL = HODE.slice(4 + 26)

const tall = (k: ReturnType<typeof maal>, median = true) =>
  K.n(n0(k?.n ?? 0)) + K.mae(k ? n1(k.mae) : '—')
  + K.med(!median ? '—' : k ? n1(k.medianFeil) : '—')
  + K.wmape(k?.wmape != null ? `${n1(k.wmape)} %` : '—')
  + K.bias(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—')
  + K.snitt(k ? n1(k.snittFaktisk) : '—')

const rad = (etikett: string, k: ReturnType<typeof maal>) =>
  '    ' + K.etikett(etikett) + tall(k)

/**
 * Populasjonsvektet samling over stasjoner.
 *
 * DET BALANSERTE UTVALGET ER IKKE KJEDEN. Vi tar like mange par fra
 * hver stasjon, men Boenes har 392 kvalifiserte og Laguneparken 674. Et
 * uvektet snitt gir da Boenes for stor vekt i totalen.
 *
 * BEGGE RAPPORTERES. Totalen erstatter ikke stasjonstallene; den svarer
 * paa et annet spoersmaal, og et snitt som skjuler at én stasjon ligger
 * dobbelt saa hoeyt ville vaert den verste av de to.
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

describe('HORISONT OG KVALITET — representativt utvalg av kvalifiserte par', () => {
  kjor('h1-h13, uke, kalenderuke og maalt kvalitetsnivaa', async () => {
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

    // T0 er det TIDLIGSTE prognosetidspunktet i hele maalingen.
    // Kalenderuken gaar lengst bakover: TEST_DAGER + 13.
    const til = TIL
    const kvalFra = KVAL_FRA

    const L: string[] = ['', '  HORISONT OG MAALT KVALITET PER PAR', '']
    L.push('  DATOER — for kontroll mot off-by-one')
    L.push(`    T0 (kvalifiseringstidspunkt)   ${T0}`)
    L.push(`    kvalifiseringsvindu foerste    ${kvalFra}`)
    L.push(`    kvalifiseringsvindu siste      ${T0}`)
    L.push(`    foerste maaldato               ${leggTilDager(til, -(TEST_DAGER - 1))}`)
    L.push(`    siste maaldato                 ${til}`)
    L.push(`    tidligste prognosetidspunkt    ${T0}`)
    L.push(`    klassifiseringens vindu        ${TREFF_VINDU} dager foer hvert T, alt < T`)
    L.push('  VINDUET ER PRODUKSJONENS. `ai/forventetverktoy.ts` bruker')
    L.push('  HISTORIKK_DAGER = 364 + 28 + 40 = 432 og henter')
    L.push('  `gte(idag-432) .. lte(idag)` - begge ender med. Her staar T0 der')
    L.push('  `idag` staar, med samme inklusivitet i begge ender.')
    L.push('  SELEKSJONSLEKKASJE SPERRET: kvalifisering bruker bare `dato <= T0`,')
    L.push('  og alt som maales ligger etter T0.')
    L.push(`  modell ${MODELL.navn}   terskel ${MINST_DAGER} salgsdager`)

    // ── PASS 1 OG 3: GRUNNLAGET FRA SQL ─────────────────────────────────
    //
    // To rene tellinger. `kilde='par'` er salgsdager og volum per
    // (stasjon, vare) i kvalifiseringsvinduet; `kilde='dag'` er hvilke
    // (stasjon, dag) som har salgsdata i det hele tatt.
    //
    // Mangler fila, stopper vi med beskjed. Ingen stille fallback til aa
    // telle selv: to veier til samme tall er nettopp det denne omleggingen
    // skulle bli kvitt.
    const SIDE = 1000
    const salgsdager = new Map<string, number>()
    const parVolum = new Map<string, number>()
    const harDag = new Set<string>()
    let grunnlag: Record<string, string>[]
    try {
      grunnlag = lesCsv(GRUNNLAG)
    } catch {
      throw new Error(
        `${GRUNNLAG} mangler i repoets rot. Kjoer supabase/tests/forventet_grunnlag.sql `
        + `i SQL Editor (vindu ${KVAL_FRA} .. ${TIL}) og last ned resultatet som CSV.`,
      )
    }
    for (const r of grunnlag) {
      if (r.kilde === 'par') {
        const n = `${r.stasjon_id}|${r.noekkel}`
        salgsdager.set(n, Number(r.salgsdager))
        parVolum.set(n, Number(r.volum))
      } else if (r.kilde === 'dag') {
        harDag.add(`${r.stasjon_id}|${r.noekkel}`)
      }
    }
    L.push(`  grunnlag fra ${GRUNNLAG}: ${n0(salgsdager.size)} par, `
      + `${n0(harDag.size)} (stasjon, dag)`)
    // En CSV med bare den ene kilden er en avkortet nedlasting, og den
    // ville sett ut som en liten kjede i stedet for en halv fil.
    expect(salgsdager.size, `${GRUNNLAG} har ingen kilde='par'-rader`).toBeGreaterThan(0)
    expect(harDag.size, `${GRUNNLAG} har ingen kilde='dag'-rader`).toBeGreaterThan(0)

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
        const steg = Math.max(1, Math.floor(bolk.length / perGruppe))
        for (let i = 0, tatt = 0; i < bolk.length && tatt < perGruppe; i += steg, tatt++) {
          valgte.push(bolk[i])
          gruppeFor.set(bolk[i], g)
        }
      }
    }
    // Kanarien staar SEPARAT. Den er en fast kontroll over tid, ikke en
    // del av det representative utvalget.
    const kanariPar = stasjoner.map((s) => `${s.id}|${KANARI}`)
      .filter((n) => salgsdager.has(n))
    const valgteSett = new Set(valgte)
    const alleMaalte = [...new Set([...valgte, ...kanariPar])]
    const maalteSett = new Set(alleMaalte)

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
    const vekt = new Map<string, number>(
      stasjoner.map((s) => [s.id, (perStasjonKval.get(s.id) ?? []).length]))
    const sumKval = [...vekt.values()].reduce((a2, b2) => a2 + b2, 0)
    L.push('    vekter til populasjonsvektet total (kvalifiserte par ved T0):')
    L.push('      ' + stasjoner.map((s) =>
      `${s.butikknummer} ${n0(vekt.get(s.id) ?? 0)} (${pst(vekt.get(s.id) ?? 0, sumKval)})`,
    ).join('   '))

    L.push('    volumspenn i utvalget (solgt antall i kvalifiseringsvinduet):')
    for (const g of GRUPPER) {
      const v = valgte.filter((n) => gruppeFor.get(n) === g)
        .map((n) => parVolum.get(n) ?? 0).sort((a, b) => a - b)
      if (v.length === 0) continue
      L.push(`      ${g.padEnd(8)} n ${String(v.length).padStart(3)}   `
        + `min ${n0(v[0])}   median ${n0(v[Math.floor(v.length / 2)])}   maks ${n0(v[v.length - 1])}`)
    }
    const utvalgVolum = valgte.reduce((a, n) => a + (parVolum.get(n) ?? 0), 0)

    // ── PASS 2: HISTORIKK FOR UTVALGET ──────────────────────────────────
    const eanListe = [...new Set(alleMaalte.map((n) => n.split('|')[1]))]
    const perEnhet = new Map<string, Salgsrad[]>()
    const varerad = new Map<string, number>()
    let lest2 = 0
    for (let f = 0; ; f += SIDE) {
      const { data, error: rf } = await supabase
        .from('v_butikksalg').select('stasjon_id, dato, ean, antall')
        .in('ean', eanListe).gte('dato', kvalFra).lte('dato', til)
        .order('dato', { ascending: true })
        .order('stasjon_id', { ascending: true })
        .order('ean', { ascending: true })
        .range(f, f + SIDE - 1)
        .overrideTypes<Rad[]>()
      if (rf) throw new Error(`v_butikksalg (historikk): ${rf.message}`)
      const side = data ?? []
      lest2 += side.length
      for (const r of side) {
        const n = `${r.stasjon_id}|${r.ean}`
        if (!maalteSett.has(n)) continue
        const s: Salgsrad = {
          stasjonId: r.stasjon_id, ean: r.ean, dato: r.dato, antall: r.antall ?? 0,
          varegruppeKode: null, varegruppeNavn: null,
        }
        perEnhet.set(n, [...(perEnhet.get(n) ?? []), s])
        varerad.set(`${n}|${r.dato}`, (varerad.get(`${n}|${r.dato}`) ?? 0) + s.antall)
      }
      if (side.length < SIDE) break
    }
    L.push(`  rader lest for utvalget: ${n0(lest2)}`)

    // ── KRYSSJEKK: STEMMER CSV-EN MED LEVENDE DATA? ─────────────────────
    //
    // EN GAMMEL FIL GIR IKKE FEIL, DEN GIR ET LITT ANNET TALL. Derfor
    // telles salgsdager og volum paa nytt for hvert maalt par, ut av
    // radene vi nettopp hentet, og holdes mot det CSV-en paastod. Er
    // vinduet et annet, eller fila fra i gaar, spriker de.
    const avvik: string[] = []
    for (const n of alleMaalte) {
      let dager = 0
      let volum = 0
      for (const r of perEnhet.get(n) ?? []) {
        if (r.dato < kvalFra || r.dato > T0) continue
        volum += r.antall
        if (r.antall > 0) dager++
      }
      if (dager !== salgsdager.get(n) || volum !== parVolum.get(n)) {
        avvik.push(`${n}: levende ${dager}d/${volum} mot CSV `
          + `${salgsdager.get(n)}d/${parVolum.get(n)}`)
      }
    }
    L.push(`  kryssjekk mot levende data: ${n0(alleMaalte.length - avvik.length)} av `
      + `${n0(alleMaalte.length)} par stemmer`)
    expect(avvik.slice(0, 5).join('  |  '),
      `${GRUNNLAG} stemmer ikke med levende data — feil vindu eller gammel fil`).toBe('')

    const muligeDager = Math.round(
      (Date.parse(`${til}T12:00:00Z`) - Date.parse(`${T0}T12:00:00Z`)) / 86400000) + 1
    L.push('')
    L.push(`  DAGDEKNING ${T0} .. ${til} — dager stasjonen har minst én salgsrad`)
    for (const s of stasjoner) {
      const d = [...harDag].filter((k) => k.startsWith(`${s.id}|`)).length
      L.push(`    ${(navnFor.get(s.id) ?? '').padEnd(22)} ${String(d).padStart(3)} av ${muligeDager}`
        + (d < muligeDager ? `   <- ${muligeDager - d} dag(er) uten data` : ''))
    }

    /**
     * Faktisk salg, med skillet mellom null og manglende.
     *
     *   varerad finnes                    -> antallet
     *   ingen varerad, stasjonen har data -> 0, varen solgte ikke
     *   ingen varerad, stasjonen mangler  -> undefined, vi vet ikke
     */
    const fasitFor = (par: string, dato: string): number | undefined => {
      const r = varerad.get(`${par}|${dato}`)
      if (r !== undefined) return r
      return harDag.has(`${par.slice(0, par.indexOf('|'))}|${dato}`) ? 0 : undefined
    }

    const maaldatoer: string[] = []
    for (let i = TEST_DAGER; i >= 1; i--) maaldatoer.push(leggTilDager(til, -(i - 1)))

    // ── KVALITET PAA PROGNOSETIDSPUNKTET, UTEN FREMTIDSLEKKASJE ─────────
    //
    // `maalTreff` over de 28 dagene FOER T. Motoren haandhever selv at
    // hver av de forecastene bare ser data foer sin egen maaldag, og
    // alle maaldagene ligger foer T. Maaldagen som skal bedoemmes, og
    // alt etter den, roerer ikke klassifiseringen.
    //
    // Cachet paa (par, T): samme T brukes av flere horisonter.
    const nivaaCache = new Map<string, Tillit>()
    const nivaaVed = (par: string, T: string): Tillit => {
      const noekkel = `${par}|${T}`
      const truffet = nivaaCache.get(noekkel)
      if (truffet !== undefined) return truffet
      const [stasjonId, ean] = par.split('|')
      const dager: string[] = []
      for (let i = TREFF_VINDU; i >= 1; i--) dager.push(leggTilDager(T, -i))
      const t = tillit(maalTreff({
        enhet: { stasjonId, ean },
        salg: (perEnhet.get(par) ?? []).filter((r) => r.dato <= T),
        maaldatoer: dager, modell: MODELL, minstDagerMedSalg: MINST_DAGER,
      }))
      nivaaCache.set(noekkel, t)
      return t
    }

    // =================================================================
    // 1 ENKELTDAG h1..h13
    // =================================================================
    type Bunt = {
      treff: Treff[]; forsokt: number; svart: number
      perStasjon: Map<string, Treff[]>; perGruppe: Map<string, Treff[]>
      perNivaa: Map<Tillit, Treff[]>; kanari: Treff[]
    }
    const perH = new Map<number, Bunt>()
    for (const h of HORISONTER) {
      perH.set(h, {
        treff: [], forsokt: 0, svart: 0, perStasjon: new Map(),
        perGruppe: new Map(), perNivaa: new Map(), kanari: [],
      })
    }
    // Paa tvers av horisonter, for nivaarapporten.
    const nivTreff = new Map<Tillit, Treff[]>()
    const nivPar = new Map<Tillit, Set<string>>()
    const nivPerStasjon = new Map<string, Map<Tillit, Treff[]>>()
    let nullFasit = 0

    for (const h of HORISONTER) {
      const b = perH.get(h)!
      for (const d of maaldatoer) {
        const T = leggTilDager(d, -h)
        for (const n of alleMaalte) {
          const [stasjonId, ean] = n.split('|')
          const f = fasitFor(n, d)
          if (f === undefined) continue
          const erKanari = ean === KANARI
          if (!erKanari) b.forsokt++
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: d,
            salg: (perEnhet.get(n) ?? []).filter((r) => r.dato <= T),
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet') continue
          const t = { forventet: sv.antall, faktisk: f }
          if (erKanari) { b.kanari.push(t); continue }
          if (varerad.get(`${n}|${d}`) === undefined) nullFasit++
          b.svart++
          b.treff.push(t)
          b.perStasjon.set(stasjonId, [...(b.perStasjon.get(stasjonId) ?? []), t])
          const g = gruppeFor.get(n) ?? 'ukjent'
          b.perGruppe.set(g as Tillit, [...(b.perGruppe.get(g as Tillit) ?? []), t])
          const niv = nivaaVed(n, T)
          b.perNivaa.set(niv, [...(b.perNivaa.get(niv) ?? []), t])
          nivTreff.set(niv, [...(nivTreff.get(niv) ?? []), t])
          nivPar.set(niv, (nivPar.get(niv) ?? new Set<string>()).add(n))
          const pn = nivPerStasjon.get(stasjonId) ?? new Map<Tillit, Treff[]>()
          pn.set(niv, [...(pn.get(niv) ?? []), t])
          nivPerStasjon.set(stasjonId, pn)
        }
      }
    }

    L.push('')
    L.push('  ENKELTDAG h1..h13 — UVEKTET (det balanserte utvalget)')
    L.push('     h   dekning        ' + HODE_TALL)
    for (const h of HORISONTER) {
      const b = perH.get(h)!
      L.push(`    ${String(h).padStart(2)}   ${pst(b.svart, b.forsokt).padStart(7)}        `
        + tall(maal(b.treff)))
    }
    L.push(`  av disse observasjonene kom ${n0(nullFasit)} fra en dag der stasjonen hadde`)
    L.push('  salgsdata mens varen ikke hadde rad — faktisk = 0, ikke manglende fasit')

    L.push('')
    L.push('  ENKELTDAG h1..h13 — POPULASJONSVEKTET (kvalifiserte par per stasjon)')
    L.push('     h' + K.n('n') + K.mae('MAE') + K.wmape('wMAPE') + K.bias('bias')
      + K.snitt('snitt faktisk'))
    for (const h of HORISONTER) {
      const v = vektet(perH.get(h)!.perStasjon, vekt)
      L.push(
        `    ${String(h).padStart(2)}` + K.n(n0(v?.n ?? 0)) + K.mae(v ? n1(v.mae) : '—')
        + K.wmape(v?.wmape != null ? `${n1(v.wmape)} %` : '—')
        + K.bias(v ? (v.bias >= 0 ? '+' : '') + n1(v.bias) : '—')
        + K.snitt(v ? n1(v.snittFaktisk) : '—'),
      )
    }
    L.push('    Vektet total ERSTATTER IKKE stasjonstallene under.')

    for (const [tittel, velg] of [
      ['PER STASJON', (b: Bunt) => b.perStasjon],
      ['PER VOLUMGRUPPE', (b: Bunt) => b.perGruppe],
      ['PER MAALT KVALITETSNIVAA (klassifisert paa prognosetidspunktet)',
        (b: Bunt) => b.perNivaa],
    ] as const) {
      L.push('')
      L.push(`  ${tittel} — wMAPE per horisont`)
      const noekler = [...new Set(HORISONTER.flatMap((h) => [...velg(perH.get(h)!).keys()]))]
      L.push('    gruppe                ' + HORISONTER.map((h) => `h${h}`.padStart(7)).join(''))
      for (const key of noekler) {
        const celler = HORISONTER.map((h) => {
          const k = maal(velg(perH.get(h)!).get(key as never) ?? [])
          return (k?.wmape != null ? `${n1(k.wmape)}%` : '—').padStart(7)
        })
        L.push(`    ${String(navnFor.get(key as string) ?? key).padEnd(20)}${celler.join('')}`)
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
    //
    // `strengt` teller hvor mange uker som ville vaert komplette under
    // DEN GAMLE REGELEN, der en dag uten varerad gjorde uken ukomplett.
    // Differansen er hva nullhaandteringen faktisk henter inn.
    const uke: Treff[] = []
    const ukePerStasjon = new Map<string, Treff[]>()
    const ukePerGruppe = new Map<string, Treff[]>()
    const ukePerNivaa = new Map<Tillit, Treff[]>()
    const ukeNy = new Map<string, number>()
    const ukeGammel = new Map<string, number>()
    let ukeForsokt = 0
    let ukeStrengt = 0
    for (let i = TEST_DAGER; i >= 1; i--) {
      const T = leggTilDager(til, -(7 + i - 1))
      for (const n of valgte) {
        const [stasjonId, ean] = n.split('|')
        const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
        let sumF = 0
        let sumA = 0
        let komplett = true
        let bruktNull = false
        for (let d = 1; d <= 7; d++) {
          const dato = leggTilDager(T, d)
          const a = fasitFor(n, dato)
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: dato, salg: tilgjengelig,
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet' || a === undefined) { komplett = false; break }
          if (varerad.get(`${n}|${dato}`) === undefined) bruktNull = true
          sumF += sv.antall
          sumA += a
        }
        ukeForsokt++
        if (!komplett) continue
        const g = gruppeFor.get(n) ?? 'ukjent'
        ukeNy.set(g, (ukeNy.get(g) ?? 0) + 1)
        if (!bruktNull) {
          ukeStrengt++
          ukeGammel.set(g, (ukeGammel.get(g) ?? 0) + 1)
        }
        const t = { forventet: sumF, faktisk: sumA }
        uke.push(t)
        ukePerStasjon.set(stasjonId, [...(ukePerStasjon.get(stasjonId) ?? []), t])
        ukePerGruppe.set(g, [...(ukePerGruppe.get(g) ?? []), t])
        const niv = nivaaVed(n, T)
        ukePerNivaa.set(niv, [...(ukePerNivaa.get(niv) ?? []), t])
      }
    }
    L.push('')
    L.push(`  RULLERENDE UKE h1..h7 — KOMPLETTE (${n0(uke.length)} av ${n0(ukeForsokt)} forsoek)`)
    L.push(`    under den gamle regelen (ingen rad = ukomplett): ${n0(ukeStrengt)}`)
    L.push(`    hentet inn av korrekt nullhaandtering:            ${n0(uke.length - ukeStrengt)}`)
    L.push('    per volumgruppe, gammel -> ny: ' + GRUPPER.map((g) =>
      `${g} ${n0(ukeGammel.get(g) ?? 0)} -> ${n0(ukeNy.get(g) ?? 0)}`,
    ).join('   '))
    L.push(HODE)
    L.push(rad('samlet (uvektet)', maal(uke)))
    const vUke = vektet(ukePerStasjon, vekt)
    L.push('    ' + K.etikett('samlet (populasjonsvektet)')
      + K.n(n0(vUke?.n ?? 0)) + K.mae(vUke ? n1(vUke.mae) : '—') + K.med('—')
      + K.wmape(vUke?.wmape != null ? `${n1(vUke.wmape)} %` : '—')
      + K.bias(vUke ? (vUke.bias >= 0 ? '+' : '') + n1(vUke.bias) : '—')
      + K.snitt(vUke ? n1(vUke.snittFaktisk) : '—'))
    for (const s of stasjoner) {
      const t = ukePerStasjon.get(s.id)
      if (t?.length) L.push(rad(navnFor.get(s.id) ?? s.id, maal(t)))
    }
    for (const g of GRUPPER) L.push(rad(`volum: ${g}`, maal(ukePerGruppe.get(g) ?? [])))
    for (const niv of NIVAAER) L.push(rad(`nivaa: ${niv}`, maal(ukePerNivaa.get(niv) ?? [])))

    // =================================================================
    // 3 NESTE KALENDERUKE, PER UKEDAG
    // =================================================================
    const UKEDAG = ['soendag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'loerdag']
    const ukedagAv = (d: string) => new Date(`${d}T12:00:00Z`).getUTCDay()
    const nesteMandag = (d: string) => leggTilDager(d, ((8 - ukedagAv(d)) % 7) || 7)

    type Kal = {
      treff: Treff[]; hs: Set<number>; strengt: number
      perGruppe: Map<string, Treff[]>; perNivaa: Map<Tillit, Treff[]>
    }
    const perUkedag = new Map<number, Kal>()
    for (let i = TEST_DAGER + 13; i >= 13; i--) {
      const T = leggTilDager(til, -i)
      const man = nesteMandag(T)
      const hStart = Math.round(
        (Date.parse(`${man}T12:00:00Z`) - Date.parse(`${T}T12:00:00Z`)) / 86400000)
      if (hStart + 6 > 13) continue
      const b: Kal = perUkedag.get(ukedagAv(T))
        ?? { treff: [], hs: new Set<number>(), strengt: 0, perGruppe: new Map(), perNivaa: new Map() }
      for (let k = 0; k < 7; k++) b.hs.add(hStart + k)
      for (const n of valgte) {
        const [stasjonId, ean] = n.split('|')
        const tilgjengelig = (perEnhet.get(n) ?? []).filter((r) => r.dato <= T)
        let sumF = 0
        let sumA = 0
        let komplett = true
        let bruktNull = false
        for (let k = 0; k < 7; k++) {
          const dato = leggTilDager(man, k)
          const a = fasitFor(n, dato)
          const sv = forventetSalg({
            enhet: { stasjonId, ean }, maalDato: dato, salg: tilgjengelig,
            modell: MODELL, minstDagerMedSalg: MINST_DAGER,
          })
          if (sv.slag !== 'beregnet' || a === undefined) { komplett = false; break }
          if (varerad.get(`${n}|${dato}`) === undefined) bruktNull = true
          sumF += sv.antall
          sumA += a
        }
        if (!komplett) continue
        if (!bruktNull) b.strengt++
        const t = { forventet: sumF, faktisk: sumA }
        b.treff.push(t)
        const g = gruppeFor.get(n) ?? 'ukjent'
        b.perGruppe.set(g, [...(b.perGruppe.get(g) ?? []), t])
        const niv = nivaaVed(n, T)
        b.perNivaa.set(niv, [...(b.perNivaa.get(niv) ?? []), t])
      }
      perUkedag.set(ukedagAv(T), b)
    }
    L.push('')
    L.push('  NESTE KALENDERUKE — komplette uker, per ukedag spoersmaalet stilles')
    L.push('    spurt paa   horisonter  gammel' + HODE_TALL)
    for (let u = 0; u < 7; u++) {
      const b = perUkedag.get(u)
      if (!b || b.treff.length === 0) continue
      const hs = [...b.hs].sort((x, y) => x - y)
      L.push(`    ${UKEDAG[u].padEnd(10)}  ${`h${hs[0]}..h${hs[hs.length - 1]}`.padStart(10)}`
        + `${String(n0(b.strengt)).padStart(8)}` + tall(maal(b.treff)))
    }
    L.push('    «gammel» = komplette uker under regelen der en dag uten varerad')
    L.push('    gjorde uken ukomplett. Kolonnen «n» er etter rettingen.')

    L.push('')
    L.push('  KALENDERUKE — per volumgruppe og nivaa, alle ukedager slaatt sammen')
    L.push(HODE)
    const kalAlle = [...perUkedag.values()]
    for (const g of GRUPPER) {
      L.push(rad(`volum: ${g}`, maal(kalAlle.flatMap((b) => b.perGruppe.get(g) ?? []))))
    }
    for (const niv of NIVAAER) {
      L.push(rad(`nivaa: ${niv}`, maal(kalAlle.flatMap((b) => b.perNivaa.get(niv) ?? []))))
    }

    // =================================================================
    // 4 KVALITETSNIVAAENE — HOLDER KLASSIFISERINGEN?
    // =================================================================
    L.push('')
    L.push('  MAALT KVALITETSNIVAA — klassifisert FOER, feilen maalt ETTER')
    L.push('    nivaa       unike par  andel par  andel volum' + HODE_TALL)
    const totObs = NIVAAER.reduce((a, niv) => a + (nivTreff.get(niv) ?? []).length, 0)
    for (const niv of NIVAAER) {
      const par = nivPar.get(niv) ?? new Set<string>()
      const vol = [...par].reduce((a, n) => a + (parVolum.get(n) ?? 0), 0)
      L.push(
        `    ${niv.padEnd(10)}  ${String(par.size).padStart(9)}  `
        + `${pst(par.size, valgte.length).padStart(9)}  ${pst(vol, utvalgVolum).padStart(11)}`
        + tall(maal(nivTreff.get(niv) ?? [])),
      )
    }
    L.push('    MERK: et par kan ligge paa ulike nivaa paa ulike prognosetidspunkt,')
    L.push('    saa «unike par» summerer til mer enn utvalget. «andel volum» er')
    L.push('    kvalifiseringsvinduets volum for de parene, av utvalgets totale.')

    L.push('')
    L.push('  HVA EN SPERRE VILLE FJERNET — enkeltdag, alle horisonter')
    L.push('    svarer bare paa                fjernet   andel   wMAPE igjen    bias')
    const daarligst: Tillit[] = ['ukjent', 'svak', 'middels']
    for (let i = 0; i < daarligst.length; i++) {
      const sperret = new Set(daarligst.slice(0, i + 1))
      const beholdt = NIVAAER.filter((x) => !sperret.has(x))
      const ut = NIVAAER.filter((x) => sperret.has(x)).flatMap((x) => nivTreff.get(x) ?? [])
      const k = maal(beholdt.flatMap((x) => nivTreff.get(x) ?? []))
      L.push(
        `    ${beholdt.join(', ').padEnd(29)}  ${String(n0(ut.length)).padStart(7)}   `
        + `${pst(ut.length, totObs).padStart(6)}   `
        + `${(k?.wmape != null ? `${n1(k.wmape)} %` : '—').padStart(11)}   `
        + `${(k ? (k.bias >= 0 ? '+' : '') + n1(k.bias) : '—').padStart(5)}`,
      )
    }

    L.push('')
    L.push('  PER STASJON OG NIVAA — wMAPE (antall observasjoner)')
    L.push('    stasjon               ' + NIVAAER.map((n) => n.padStart(17)).join(''))
    for (const s of stasjoner) {
      const pn = nivPerStasjon.get(s.id)
      if (!pn) continue
      L.push(`    ${(navnFor.get(s.id) ?? '').padEnd(22)}`
        + NIVAAER.map((niv) => {
          const t = pn.get(niv) ?? []
          const k = maal(t)
          return (k?.wmape != null ? `${n1(k.wmape)}% (${n0(t.length)})` : '—').padStart(17)
        }).join(''))
    }

    L.push('')
    L.push('  Ingen grense er satt. Ingen rad er endret.')
    L.push('')
    console.log(L.join('\n'))

    // ── VAKTER ──────────────────────────────────────────────────────────
    expect(valgte.length, 'utvalget ble tomt').toBeGreaterThan(0)
    expect(perH.get(1)!.treff.length, 'h1 ga ingen observasjoner').toBeGreaterThan(0)
    expect(
      new Set(valgte.map((n) => n.split('|')[0])).size,
      'ikke alle stasjoner er med i utvalget',
    ).toBe(stasjoner.length)
    expect(new Set([...gruppeFor.values()]).size, 'ikke alle volumgrupper er med').toBe(3)
    // NULLHAANDTERINGEN MAA FAKTISK BITE. Finnes det ingen dag der
    // stasjonen har data mens varen mangler rad, er skillet uvirksomt og
    // «komplett uke» krever fortsatt salg alle sju dagene - da maaler
    // denne kjoeringen det samme som forrige, uten aa si fra.
    expect(nullFasit, 'ingen nulldager — skillet mellom 0 og manglende biter ikke')
      .toBeGreaterThan(0)
    // KLASSIFISERINGEN MAA SKILLE. Havner alt paa ett nivaa, maaler
    // nivaatabellen ingenting, og en sperre ville enten fjernet alt
    // eller ingenting.
    expect(
      NIVAAER.filter((n) => (nivTreff.get(n) ?? []).length > 0).length,
      'alle observasjoner havnet paa samme kvalitetsnivaa',
    ).toBeGreaterThan(1)
    // Kanarien skal ikke ha sneket seg inn i nivaatallene.
    for (const par of [...nivPar.values()].flatMap((s) => [...s])) {
      expect(valgteSett.has(par), `fremmed par i nivaatallene: ${par}`).toBe(true)
    }
  }, 3_000_000)
})
