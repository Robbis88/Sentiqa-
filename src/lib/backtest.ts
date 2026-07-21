// Backtest + selvlæring for prognosene. For hver historiske dag «spoler vi
// tilbake» (bruker KUN data fra før den dagen) og kjører nøyaktig samme motorer
// som skjermen — lagProduksjonsplan + lagSalgsprognose — og sammenligner med
// faktisk salg. Resultatet lagres i prognose_treff (treffsikkerhet) og
// destilleres til prognose_kalibrering (korreksjonsfaktor pr stasjon/kategori),
// som motoren ganger inn i framtidige forslag. All datahenting skjer her; selve
// regningen er de rene motorene. Kjøres med service-role (natt/knapp) → omgår
// RLS og slipper 1000-rad-fella via paginert henting.
import type { SupabaseClient } from '@supabase/supabase-js'
import { lagProduksjonsplan, leggTilDager, PRODUKSJON_KODER as KODER, type SalgsPunkt, type Vaerdag } from './produksjonsplan'
import { lagSalgsprognose, type AvdSalg } from './salgsprognose'
import { hentVaerKoeff } from './vaerprofil'
import { erHelligdag } from './helligdager'
import { hentAlt } from './paginer'

type Klient = SupabaseClient
const UTELAT = new Set(['10', '250', '40']) // drivstoff/pant/CR — ikke butikkdrift
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
  const idag = new Date().toISOString().slice(0, 10)
  const vinduStart = leggTilDager(idag, -antallDager)
  const hentFra = leggTilDager(vinduStart, -400) // dekker fjor-vindu for tidligste mål-dag
  const folsomhet = st.vaerfolsomhet_laert ?? st.vaerfolsomhet ?? 0.5

  // Produksjonssalg (antall pr produkt) + avdelingssalg (omsetning) + vær — alt for stasjonen, én gang.
  const [prodRaa, avdRaa, vaerRaa] = await Promise.all([
    hentAlt<{ varenavn: string | null; varegruppe_kode: string | null; varegruppe_navn: string | null; antall: number | null; dato: string }>((f, t) =>
      supabase.from('daglig_salg').select('varenavn, varegruppe_kode, varegruppe_navn, antall, dato')
        .eq('stasjon_id', st.id).in('varegruppe_kode', KODER).gte('dato', hentFra).lte('dato', idag).is('slettet_tid', null)
        .order('dato').order('ean').range(f, t)),
    hentAlt<{ dato: string; avdeling_kode: string | null; avdeling_navn: string | null; omsetning: number | null }>((f, t) =>
      supabase.from('v_salg_per_avdeling_dag').select('dato, avdeling_kode, avdeling_navn, omsetning')
        .eq('stasjon_id', st.id).gte('dato', hentFra).lte('dato', idag)
        .order('dato').order('avdeling_kode').range(f, t)),
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
    .map((r) => ({ dato: r.dato, varenavn: (r.varenavn ?? '').trim(), varegruppeKode: r.varegruppe_kode, varegruppeNavn: r.varegruppe_navn, antall: r.antall ?? 0 }))
    .filter((p) => p.varenavn)
  const avdPunkter: AvdSalg[] = avdRaa
    .filter((r) => r.avdeling_kode && !UTELAT.has(r.avdeling_kode))
    .map((r) => ({ dato: r.dato, avdelingKode: r.avdeling_kode!, avdelingNavn: r.avdeling_navn ?? r.avdeling_kode!, omsetning: r.omsetning ?? 0 }))

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
    const vFjor = vaer.get(leggTilDager(D, -364)) ?? null

    // ── Produksjonsplan ──
    const prodFor = prodPunkter.filter((p) => p.dato < D && p.dato >= leggTilDager(D, -392))
    const faktiskProdDag = faktiskProd.get(D)
    if (prodFor.length > 0 && faktiskProdDag && faktiskProdDag.size > 0) {
      const sisteSalgsdato = prodFor.reduce((m, p) => (p.dato > m ? p.dato : m), prodFor[0].dato)
      const plan = lagProduksjonsplan({ maalDato: D, sisteSalgsdato, salg: prodFor, vaerMaal: vMaal, vaerFjor: vFjor, vaerfolsomhet: folsomhet, vaerKoeff: koeffVg, helligdag })
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
      const prognose = lagSalgsprognose({ maalDato: D, sisteSalgsdato, salg: avdFor, vaerMaal: vMaal, vaerFjor: vFjor, vaerfolsomhet: folsomhet, vaerKoeff: koeffAvd, stasjonstype: st.stasjonstype, helligdag })
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

async function skrivTreff(supabase: Klient, stasjonId: string, treff: TreffRad[], kalibrering: KalRad[]): Promise<void> {
  // Erstatt forrige backtest for stasjonen (ren tavle, ingen utdaterte rader).
  await supabase.from('prognose_treff').delete().eq('stasjon_id', stasjonId)
  await supabase.from('prognose_kalibrering').delete().eq('stasjon_id', stasjonId)
  for (let i = 0; i < treff.length; i += 500) {
    const { error } = await supabase.from('prognose_treff').insert(treff.slice(i, i + 500))
    if (error) throw new Error(`prognose_treff: ${error.message}`)
  }
  if (kalibrering.length > 0) {
    const { error } = await supabase.from('prognose_kalibrering').insert(kalibrering)
    if (error) throw new Error(`prognose_kalibrering: ${error.message}`)
  }
}

// ── Alle stasjoner (nattjobb) ───────────────────────────────────────────────
export async function kjorBacktestAlle(supabase: Klient, antallDager = 60): Promise<number> {
  const { data } = await supabase
    .from('stasjoner').select('id, retailer_id, butikknummer, navn, stasjonstype, vaerfolsomhet, vaerfolsomhet_laert').is('slettet_tid', null)
  let n = 0
  for (const st of (data ?? []) as StasjonRad[]) {
    try {
      const { treff, kalibrering } = await kjorBacktestForStasjon(supabase, st, antallDager)
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
    await skrivTreff(supabase, st.id, treff, kalibrering)
    n++
  }
  return n
}

// ── Hjelper: hent kalibrering for en stasjon (brukt av live-motorene) ────────
export async function hentKalibrering(supabase: Klient, stasjonId: string, type: 'produksjonsplan' | 'salgsprognose'): Promise<Map<string, number>> {
  const { data } = await supabase
    .from('prognose_kalibrering').select('kategori, korreksjon').eq('stasjon_id', stasjonId).eq('type', type)
  const m = new Map<string, number>()
  for (const r of (data ?? []) as { kategori: string; korreksjon: number }[]) m.set(r.kategori, r.korreksjon)
  return m
}
