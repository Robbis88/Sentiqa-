import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

// Bygger scope-treet for målekort-velgeren fra v_varehierarki (RLS → eget
// cluster). Hierarki: Avdeling → Vareområde → Varegruppe. Individuelle varer
// (EAN) hentes på søk i stedet for å lastes i bulk (kan være tusenvis).

export type VareNivaa = 'avdeling' | 'vareomrade' | 'varegruppe' | 'ean'
export type VareNode = {
  nivaa: 'avdeling' | 'vareomrade' | 'varegruppe'
  kode: string
  navn: string
  barn: VareNode[]
}

type HierarkiRad = {
  avdeling_kode: string | null
  avdeling_navn: string | null
  vareomrade_kode: string | null
  vareomrade_navn: string | null
  varegruppe_kode: string | null
  varegruppe_navn: string | null
}

export async function hentVarehierarki(supabase: SupabaseClient): Promise<VareNode[]> {
  const { data } = await supabase
    .from('v_varehierarki')
    .select('avdeling_kode,avdeling_navn,vareomrade_kode,vareomrade_navn,varegruppe_kode,varegruppe_navn')
    .limit(5000)
    .overrideTypes<HierarkiRad[]>()

  const avdelinger = new Map<string, VareNode>()
  for (const r of data ?? []) {
    if (!r.avdeling_kode) continue
    let avd = avdelinger.get(r.avdeling_kode)
    if (!avd) {
      avd = { nivaa: 'avdeling', kode: r.avdeling_kode, navn: r.avdeling_navn ?? r.avdeling_kode, barn: [] }
      avdelinger.set(r.avdeling_kode, avd)
    }
    if (!r.vareomrade_kode) continue
    let vomr = avd.barn.find((b) => b.kode === r.vareomrade_kode)
    if (!vomr) {
      vomr = { nivaa: 'vareomrade', kode: r.vareomrade_kode, navn: r.vareomrade_navn ?? r.vareomrade_kode, barn: [] }
      avd.barn.push(vomr)
    }
    if (!r.varegruppe_kode) continue
    if (!vomr.barn.some((b) => b.kode === r.varegruppe_kode)) {
      vomr.barn.push({ nivaa: 'varegruppe', kode: r.varegruppe_kode, navn: r.varegruppe_navn ?? r.varegruppe_kode, barn: [] })
    }
  }

  const sorter = (ns: VareNode[]) => {
    ns.sort((a, b) => a.navn.localeCompare(b.navn, 'nb'))
    ns.forEach((n) => sorter(n.barn))
  }
  const tre = [...avdelinger.values()]
  sorter(tre)
  return tre
}

export type VareTreff = { ean: string; varenavn: string; varegruppe: string | null }

export async function sokVarer(supabase: SupabaseClient, q: string): Promise<VareTreff[]> {
  const term = q.trim()
  if (term.length < 2) return []
  const { data } = await supabase
    .from('v_varer')
    .select('ean,varenavn,varegruppe_navn')
    .ilike('varenavn', `%${term}%`)
    .limit(30)
    .overrideTypes<{ ean: string; varenavn: string; varegruppe_navn: string | null }[]>()
  return (data ?? []).map((r) => ({ ean: r.ean, varenavn: r.varenavn, varegruppe: r.varegruppe_navn }))
}
