// Backtest + selvlæring for prognosene. For hver historiske dag «spoler vi
// tilbake» med salg fra før den dagen. Vær og konfigurasjon er dagens
// historiske scenario, ikke et arkiv over hva som faktisk var kjent da.
// Den kjører de samme motorene
// som skjermen — lagProduksjonsplan + lagSalgsprognose — og sammenligner med
// faktisk salg. Resultatet lagres i prognose_treff (treffsikkerhet) og
// destilleres til prognose_kalibrering (korreksjonsfaktor pr stasjon/kategori),
// som motoren ganger inn i framtidige forslag. All datahenting skjer her; selve
// regningen er de rene motorene. Kjøres med service-role (natt/knapp) → omgår
// RLS og slipper 1000-rad-fella via paginert henting.
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagProduksjonsplan, leggTilDager, produksjonsreferanse, type SalgsPunkt, type Vaerdag } from './produksjonsplan'
import { hentProduksjonskoder } from './produksjonskoder'
import { lagSalgsprognose, type AvdSalg } from './salgsprognose'
import { hentVaerKoeff } from './vaerprofil'
import { erHelligdag } from './helligdager'
import { hentAlt } from './paginer'
import { idagOslo } from './ai/periode'
import { fjorHelligdag } from './helligdager'
import { maaVaereHele } from './supabase/datobolker'

type Klient = SupabaseClient
const UTELAT = new Set(['250', '40']) // pant/CR; drivstoff er allerede fjernet i v_butikksalg
const TOTAL = '*'
const MIN_N = 8 // minst så mange backtest-dager bak en kalibreringsfaktor

type StasjonRad = {
  id: string; retailer_id: string; butikknummer: string; navn: string
  stasjonstype: string; vaerfolsomhet: number | null; vaerfolsomhet_laert: number | null
}
type TreffRad = { retailer_id: string; stasjon_id: string; type: 'produksjonsplan' | 'salgsprognose'; dato: string; kategori: string; forventet: number; faktisk: number; treff: number }
type KalRad = { retailer_id: string; stasjon_id: string; type: 'produksjonsplan' | 'salgsprognose'; kategori: string; korreksjon: number; n: number }

function treffProsent(forventet: number, faktisk: number): number {
  return Math.max(0, Math.round(100 - (Math.abs(forventet - faktisk) / Math.max(faktisk, forventet, 1)) * 100))
}
function klem(x: number, lav: number, hoy: number): number {
  return Math.max(lav, Math.min(hoy, x))
}
function dagerMellom(fra: string, til: string): string[] {
  const ut: string[] = []
  for (let d = fra; d < til; d = leggTilDager(d, 1)) ut.push(d)
  return ut
}

// ── Én stasjon: kjør backtesten, returner treff-rader + kalibrering ──────────
export async function kjorBacktestForStasjon(
  supabase: Klient,
  st: StasjonRad,
  antallDager = 60,
): Promise<{ treff: TreffRad[]; kalibrering: KalRad[] }> {
  // 0152: uten mapping finnes det ingen produksjonsvarer aa treffe paa.
  // AA KJOERE VIDERE MED TOM KODELISTE VILLE GITT treff=0 PAA ALT - en
  // treffsikkerhet paa null prosent som ser ut som en elendig prognose,
  // ikke som en manglende konfigurasjon. Tomme lister er verre enn ingen.
  const oppsett = await hentProduksjonskoder(supabase, st.retailer_id)
  if (oppsett.status === 'ikke_konfigurert') return { treff: [], kalibrering: [] }
  const KODER = oppsett.koder

  const idag = idagOslo()
  const vinduStart = leggTilDager(idag, -antallDager)
  const hentFra = leggTilDager(vinduStart, -400) // dekker fjor-vindu for tidligste mål-dag
  const folsomhet = st.vaerfolsomhet_laert ?? st.vaerfolsomhet ?? 0.5
  const arrangementSvar = await supabase.from('arrangementer')
    .select('dato, stasjon_id, faktor').eq('retailer_id', st.retailer_id)
    .neq('status', 'forslag').is('slettet_tid', null)
    .gte('dato', vinduStart).lt('dato', idag).limit(1000)
    .overrideTypes<{ dato: string; stasjon_id: string | null; faktor: number }[]>()
  if (!arrangementSvar.error && !arrangementSvar.data) throw new Error('Mangler svar om arrangementer.')
  const arrangementer = maaVaereHele(arrangementSvar, 'backtestens arrangementer')

  // Produksjonssalg (antall pr produkt) + avdelingssalg (omsetning) + vær — alt for stasjonen, én gang.
  const [prodRaa, avdRaa, vaerRaa] = await Promise.all([
    hentAlt<{ varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }>((f, t) =>
      supabase.from('v_butikksalg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', st.id).in('varegruppe_kode', KODER).gte('dato', hentFra).lte('dato', idag).is('slettet_tid', null)
        .order('dato').order('ean').range(f, t)),
    hentAlt<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }>((f, t) =>
      supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning')
        .eq('stasjon_id', st.id).gte('dato', hentFra).lte('dato', idag)
        .order('dato').order('avdeling_kode').order('avdeling_navn').range(f, t)),
    hentAlt<{ dato: string; temp_maks: number | null; nedbor_mm: number | null }>((f, t) =>
      supabase.from('vaer').select('dato, temp_maks, nedbor_mm').eq('stasjon_id', st.id).gte('dato', hentFra).lte('dato', idag).order('dato').range(f, t)),
  ])

  const vaer = new Map<string, Vaerdag>()
  for (const v of vaerRaa) vaer.set(v.dato, { temp_maks: v.temp_maks, nedbor_mm: v.nedbor_mm })

  // Lært vær-effekt pr kategori (samme som live-motoren bruker).
  const [koeffVg, koeffAvd] = await Promise.all([
    hentVaerKoeff(supabase, st.id, 'varegruppe'),
    hentVaerKoeff(supabase, st.id, 'avdeling'),
  ])

  const prodPunkter: SalgsPunkt[] = prodRaa
    .map((r) => {
      if (r.antall == null || !Number.isFinite(r.antall)) {
        throw new Error(`Backtest mangler gyldig salgsantall for ${r.dato}. Ingen ny kalibrering lagres.`)
      }
      return { dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall }
    })
    .filter((p) => p.varenavn)
  const avdPunkter: AvdSalg[] = avdRaa
    .filter((r) => r.avdeling_kode && !UTELAT.has(r.avdeling_kode))
    .map((r) => {
      if (r.omsetning == null || !Number.isFinite(r.omsetning)) {
        throw new Error(`Backtest mangler gyldig omsetning for ${r.dato}. Ingen ny kalibrering lagres.`)
      }
      return { dato: r.dato, avdelingKode: r.avdeling_kode!, avdelingNavn: r.avdeling_navn ?? r.avdeling_kode!, omsetning: r.omsetning }
    })

  // Faktisk salg pr dag (fasit): produksjon pr varegruppe, avd pr avdeling.
  const faktiskProd = new Map<string, Map<string, number>>() // dato -> varegruppe -> antall
  for (const p of prodPunkter) {
    if (!p.varegruppeKode) continue
    const m = faktiskProd.get(p.dato) ?? new Map<string, number>()
    m.set(p.varegruppeKode, (m.get(p.varegruppeKode) ?? 0) + p.antall)
    faktiskProd.set(p.dato, m)
  }
  const faktiskAvd = new Map<string, Map<string, number>>() // dato -> avdeling -> omsetning
  for (const a of avdPunkter) {
    const m = faktiskAvd.get(a.dato) ?? new Map<string, number>()
    m.set(a.avdelingKode, (m.get(a.avdelingKode) ?? 0) + a.omsetning)
    faktiskAvd.set(a.dato, m)
  }

  const treff: TreffRad[] = []
  const grunn = { retailer_id: st.retailer_id, stasjon_id: st.id }

  for (const D of dagerMellom(vinduStart, idag)) {
    const helligdag = erHelligdag(D)
    const vMaal = vaer.get(D) ?? null
    const referanse = produksjonsreferanse(D, leggTilDager(D, -1))
    const fjorDato = referanse.fjorDato
    const vFjor = vaer.get(fjorDato) ?? null
    const arrangementFaktor = arrangementer
      .filter((a) => a.dato === D && (a.stasjon_id === null || a.stasjon_id === st.id))
      .reduce((f, a) => f * a.faktor, 1)

    // ── Produksjonsplan ──
    const prodFor = prodPunkter.filter((p) => p.dato <= referanse.til && p.dato >= referanse.fra)
    const faktiskProdDag = faktiskProd.get(D)
    if (prodFor.length > 0 && faktiskProdDag && faktiskProdDag.size > 0) {
      const sisteSalgsdato = prodFor.reduce((m, p) => (p.dato > m ? p.dato : m), prodFor[0].dato)
      const plan = lagProduksjonsplan({ maalDato: D, sisteSalgsdato, salg: prodFor, vaerMaal: vMaal, vaerFjor: vFjor, vaerfolsomhet: folsomhet, vaerKoeff: koeffVg, helligdag, fjorHelligdag: fjorHelligdag(D), arrangementFaktor })
      const forventet = new Map<string, number>()
      for (const f of plan.forslag) {
        if (!f.varegruppeKode) continue
        forventet.set(f.varegruppeKode, (forventet.get(f.varegruppeKode) ?? 0) + f.foreslatt)
      }
      const koder = new Set([...forventet.keys(), ...faktiskProdDag.keys()])
      let tF = 0, tA = 0
      for (const k of koder) {
        const fv = forventet.get(k) ?? 0, fa = faktiskProdDag.get(k) ?? 0
        tF += fv; tA += fa
        treff.push({ ...grunn, type: 'produksjonsplan', dato: D, kategori: k, forventet: fv, faktisk: fa, treff: treffProsent(fv, fa) })
      }
      treff.push({ ...grunn, type: 'produksjonsplan', dato: D, kategori: TOTAL, forventet: tF, faktisk: tA, treff: treffProsent(tF, tA) })
    }

    // ── Salgsprognose ──
    const avdFor = avdPunkter.filter((p) => p.dato < D && p.dato >= leggTilDager(D, -400))
    const faktiskAvdDag = faktiskAvd.get(D)
    if (avdFor.length > 0 && faktiskAvdDag && faktiskAvdDag.size > 0) {
      const sisteSalgsdato = avdFor.reduce((m, p) => (p.dato > m ? p.dato : m), avdFor[0].dato)
      const prognose = lagSalgsprognose({ maalDato: D, sisteSalgsdato, salg: avdFor, vaerMaal: vMaal, vaerFjor: vaer.get(leggTilDager(D, -364)) ?? null, vaerfolsomhet: folsomhet, vaerKoeff: koeffAvd, stasjonstype: st.stasjonstype, helligdag })
      const forventet = new Map<string, number>()
      for (const f of prognose.forslag) forventet.set(f.kode, f.forventet)
      const koder = new Set([...forventet.keys(), ...faktiskAvdDag.keys()])
      let tF = 0, tA = 0
      for (const k of koder) {
        const fv = forventet.get(k) ?? 0, fa = faktiskAvdDag.get(k) ?? 0
        tF += fv; tA += fa
        treff.push({ ...grunn, type: 'salgsprognose', dato: D, kategori: k, forventet: fv, faktisk: fa, treff: treffProsent(fv, fa) })
      }
      treff.push({ ...grunn, type: 'salgsprognose', dato: D, kategori: TOTAL, forventet: tF, faktisk: tA, treff: treffProsent(tF, tA) })
    }
  }

  // ── Kalibrering: sum(faktisk)/sum(forventet) pr type+kategori (eks total) ──
  type Akk = { f: number; a: number; n: number }
  const akk = new Map<string, Akk>()
  for (const r of treff) {
    if (r.kategori === TOTAL) continue
    if (r.forventet <= 0 || r.faktisk <= 0) continue // begge må finnes for en ærlig ratio
    const key = `${r.type}|${r.kategori}`
    const v = akk.get(key) ?? { f: 0, a: 0, n: 0 }
    v.f += r.forventet; v.a += r.faktisk; v.n += 1
    akk.set(key, v)
  }
  const kalibrering: KalRad[] = []
  for (const [key, v] of akk.entries()) {
    if (v.n < MIN_N || v.f <= 0) continue
    const [type, kategori] = key.split('|') as ['produksjonsplan' | 'salgsprognose', string]
    kalibrering.push({ ...grunn, type, kategori, korreksjon: Math.round(klem(v.a / v.f, 0.6, 1.6) * 1000) / 1000, n: v.n })
  }

  return { treff, kalibrering }
}

export async function skrivTreff(supabase: Klient, stasjonId: string, treff: TreffRad[], kalibrering: KalRad[]): Promise<void> {
  const { error } = await supabase.rpc('erstatt_prognosehistorikk', {
    p_stasjon: stasjonId, p_treff: treff, p_kalibrering: kalibrering,
  })
  if (error) throw new Error(`Kunne ikke erstatte prognosehistorikk: ${error.message}. Tidligere gyldig historikk er beholdt.`)
}

// ── Alle stasjoner (nattjobb) ───────────────────────────────────────────────
export async function kjorBacktestAlle(supabase: Klient, antallDager = 60): Promise<number> {
  const { data } = await supabase
    .from('stasjoner').select('id, retailer_id, butikknummer, navn, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert').is('slettet_tid', null)
  let n = 0
  for (const st of (data ?? []) as StasjonRad[]) {
    try {
      const { treff, kalibrering } = await kjorBacktestForStasjon(supabase, st, antallDager)
      if (treff.length === 0) continue
      await skrivTreff(supabase, st.id, treff, kalibrering)
      n++
    } catch {
      // én stasjon skal ikke velte hele jobben
    }
  }
  return n
}

// ── Én kjede (manuell knapp, scopet til innlogget eier) ─────────────────────
export async function kjorBacktestForRetailer(supabase: Klient, retailerId: string, antallDager = 60): Promise<number> {
  const { data } = await supabase
    .from('stasjoner').select('id, retailer_id, butikknummer, navn, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert')
    .eq('retailer_id', retailerId).is('slettet_tid', null)
  let n = 0
  for (const st of (data ?? []) as StasjonRad[]) {
    const { treff, kalibrering } = await kjorBacktestForStasjon(supabase, st, antallDager)
    if (treff.length === 0) continue
    await skrivTreff(supabase, st.id, treff, kalibrering)
    n++
  }
  return n
}

// ── Hjelper: hent kalibrering for en stasjon (brukt av live-motorene) ────────
export async function hentKalibrering(supabase: Klient, stasjonId: string, type: 'produksjonsplan' | 'salgsprognose'): Promise<Map<string, number>> {
  const svar = await supabase
    .from('prognose_kalibrering').select('kategori, korreksjon').eq('stasjon_id', stasjonId).eq('type', type).limit(1000)
  if (!svar.error && !svar.data) throw new Error('Mangler svar om kalibrering.')
  const m = new Map<string, number>()
  for (const r of maaVaereHele(svar, 'kalibrering') as { kategori: string; korreksjon: number }[]) m.set(r.kategori, r.korreksjon)
  return m
}
