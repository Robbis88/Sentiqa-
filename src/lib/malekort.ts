import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

// Målekort-motoren (fase 2). Regner ut én KPI per stasjon for siste periode +
// samme periode i fjor, rangerer butikkene, og håndhever «aldri halv uke»-
// regelen (krev_fullstendig_periode). Tenant-isolasjon arver fra RPC-ene
// (SECURITY DEFINER + retailer-filter) → kun eget cluster.

export type Metrikk = 'omsetning' | 'antall' | 'brutto' | 'snittpris_kunde' | 'snittbong' | 'kunder'
export type Normalisering = 'per_kunde' | 'vekst_pst'
export type PeriodeType = 'uke' | 'maaned' | 'rullende4uker'

export type Malekort = {
  id: string
  navn: string
  metrikk: Metrikk
  normalisering: Normalisering
  periode: PeriodeType
  retning: 'hoy' | 'lav'
  krev_fullstendig_periode: boolean
  anonymiser: boolean
}

export type MalekortRad = {
  stasjonId: string
  navn: string
  verdi: number
  vekstPst: number | null
}
export type Enhet = 'kr' | 'antall' | 'pst'
export type MalekortResultat =
  | { klar: false; grunn: string }
  | { klar: true; enhet: Enhet; etikett: string; rader: MalekortRad[] }

// --- dato-aritmetikk via UTC-middag (samme mønster som ukerapport.ts) ---
function ukedag(iso: string): number {
  return new Date(`${iso}T12:00:00Z`).getUTCDay() // 0 = søndag
}
function leggTil(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}
function antallDager(fra: string, til: string): number {
  return Math.round((Date.parse(`${til}T12:00:00Z`) - Date.parse(`${fra}T12:00:00Z`)) / 86_400_000) + 1
}
function manedsSlutt(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`)
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).toISOString().slice(0, 10)
}
function kortDato(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`)
  return `${d.getUTCDate()}.${d.getUTCMonth() + 1}.`
}

type Kandidat = { fra: string; til: string; etikett: string }

// Genererer kandidat-perioder (nyeste først) for periodetypen, fra siste dato.
function kandidater(type: PeriodeType, sisteDato: string): Kandidat[] {
  const ut: Kandidat[] = []
  // Mest nylige søndag på/før sisteDato (ukedag: 0 = søndag).
  const sondag0 = leggTil(sisteDato, ukedag(sisteDato) === 0 ? 0 : -ukedag(sisteDato))

  if (type === 'uke') {
    for (let i = 0; i < 8; i++) {
      const sondag = leggTil(sondag0, -i * 7)
      const mandag = leggTil(sondag, -6)
      ut.push({ fra: mandag, til: sondag, etikett: `Uke ${kortDato(mandag)}–${kortDato(sondag)}` })
    }
  } else if (type === 'rullende4uker') {
    for (let i = 0; i < 8; i++) {
      const til = leggTil(sondag0, -i * 7)
      const fra = leggTil(til, -27)
      ut.push({ fra, til, etikett: `4 uker til ${kortDato(til)}` })
    }
  } else {
    // maaned: kalendermåneder bakover fra måneden til sisteDato
    for (let i = 0; i < 8; i++) {
      const d = new Date(`${sisteDato}T12:00:00Z`)
      const ny = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - i, 1))
      const fra = ny.toISOString().slice(0, 10)
      ut.push({ fra, til: manedsSlutt(fra), etikett: ny.toLocaleDateString('nb-NO', { month: 'long', year: 'numeric', timeZone: 'UTC' }) })
    }
  }
  return ut
}

// Samme periode i fjor: uke/rullende → 364 dager (ukedags-justert),
// måned → samme måned ett år tilbake.
function iFjor(type: PeriodeType, fra: string, til: string): { fra: string; til: string } {
  if (type === 'maaned') {
    const d = new Date(`${fra}T12:00:00Z`)
    const f = new Date(Date.UTC(d.getUTCFullYear() - 1, d.getUTCMonth(), 1)).toISOString().slice(0, 10)
    return { fra: f, til: manedsSlutt(f) }
  }
  return { fra: leggTil(fra, -364), til: leggTil(til, -364) }
}

async function erKomplett(supabase: SupabaseClient, fra: string, til: string): Promise<boolean> {
  const { data } = await supabase.rpc('malekort_salgsdatoer', { p_fra: fra, p_til: til })
  const dager = new Set(((data ?? []) as { dato: string }[]).map((r) => r.dato))
  return dager.size >= antallDager(fra, til)
}

type SalgRad = { stasjon_id: string; omsetning: number; antall: number; brutto: number }
type KunderRad = { stasjon_id: string; kunder: number; bonger: number }

function metrikkVerdi(m: Metrikk, salg: SalgRad | undefined, kunder: KunderRad | undefined): number {
  const oms = Number(salg?.omsetning ?? 0)
  const k = Number(kunder?.kunder ?? 0)
  const b = Number(kunder?.bonger ?? 0)
  switch (m) {
    case 'omsetning': return oms
    case 'antall': return Number(salg?.antall ?? 0)
    case 'brutto': return Number(salg?.brutto ?? 0)
    case 'kunder': return k
    case 'snittpris_kunde': return k > 0 ? oms / k : 0
    case 'snittbong': return b > 0 ? oms / b : 0
  }
}

function enhetFor(kort: Malekort): Enhet {
  if (kort.normalisering === 'vekst_pst') return 'pst'
  if (kort.metrikk === 'antall' || kort.metrikk === 'kunder') return 'antall'
  return 'kr'
}

export async function beregnMalekort(
  supabase: SupabaseClient,
  kort: Malekort,
  stasjoner: { id: string; navn: string }[],
): Promise<MalekortResultat> {
  if (stasjoner.length === 0) return { klar: false, grunn: 'Ingen stasjoner.' }

  const { data: siste } = await supabase
    .from('daglig_salg').select('dato').order('dato', { ascending: false }).limit(1).maybeSingle<{ dato: string }>()
  if (!siste) return { klar: false, grunn: 'Ingen salgsdata ennå.' }

  // Velg periode: nyeste KOMPLETTE (eller bare nyeste hvis regelen er av).
  let valgt: Kandidat | null = null
  for (const k of kandidater(kort.periode, siste.dato)) {
    if (!kort.krev_fullstendig_periode || (await erKomplett(supabase, k.fra, k.til))) { valgt = k; break }
  }
  if (!valgt) return { klar: false, grunn: 'Venter på fullstendige tall for perioden.' }

  const fjor = iFjor(kort.periode, valgt.fra, valgt.til)
  const trengerKunder = kort.metrikk === 'snittpris_kunde' || kort.metrikk === 'snittbong' || kort.metrikk === 'kunder' || kort.normalisering === 'per_kunde'

  const [salgNaaR, salgFjorR, kunderNaaR, kunderFjorR] = await Promise.all([
    supabase.rpc('beregn_malekort_salg', { p_malekort: kort.id, p_fra: valgt.fra, p_til: valgt.til }),
    supabase.rpc('beregn_malekort_salg', { p_malekort: kort.id, p_fra: fjor.fra, p_til: fjor.til }),
    trengerKunder ? supabase.rpc('beregn_stasjon_kunder', { p_fra: valgt.fra, p_til: valgt.til }) : Promise.resolve({ data: [] }),
    trengerKunder ? supabase.rpc('beregn_stasjon_kunder', { p_fra: fjor.fra, p_til: fjor.til }) : Promise.resolve({ data: [] }),
  ])

  const salgNaa = new Map<string, SalgRad>(((salgNaaR.data ?? []) as SalgRad[]).map((r) => [r.stasjon_id, r]))
  const salgFjor = new Map<string, SalgRad>(((salgFjorR.data ?? []) as SalgRad[]).map((r) => [r.stasjon_id, r]))
  const kunderNaa = new Map<string, KunderRad>(((kunderNaaR.data ?? []) as KunderRad[]).map((r) => [r.stasjon_id, r]))
  const kunderFjor = new Map<string, KunderRad>(((kunderFjorR.data ?? []) as KunderRad[]).map((r) => [r.stasjon_id, r]))

  const volum = kort.metrikk === 'omsetning' || kort.metrikk === 'antall' || kort.metrikk === 'brutto'

  const rader: MalekortRad[] = stasjoner.map((s) => {
    const naaBase = metrikkVerdi(kort.metrikk, salgNaa.get(s.id), kunderNaa.get(s.id))
    const fjorBase = metrikkVerdi(kort.metrikk, salgFjor.get(s.id), kunderFjor.get(s.id))
    const vekstPst = fjorBase > 0 ? ((naaBase - fjorBase) / fjorBase) * 100 : null

    let verdi: number
    if (kort.normalisering === 'vekst_pst') {
      verdi = vekstPst ?? 0
    } else if (kort.normalisering === 'per_kunde' && volum) {
      const k = Number(kunderNaa.get(s.id)?.kunder ?? 0)
      verdi = k > 0 ? naaBase / k : 0
    } else {
      verdi = naaBase // ratio-metrikker (snittpris/snittbong) + kunder er allerede normalisert
    }
    return { stasjonId: s.id, navn: s.navn, verdi, vekstPst }
  })

  rader.sort((a, b) => (kort.retning === 'lav' ? a.verdi - b.verdi : b.verdi - a.verdi))

  return { klar: true, enhet: enhetFor(kort), etikett: valgt.etikett, rader }
}
