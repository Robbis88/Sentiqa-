'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export type LinjeData = {
  stasjon_id: string
  dato: string
  varenavn: string
  varegruppe_kode: string | null
  varegruppe_navn: string | null
  foreslatt: number
  planlagt: number
  start_antall?: number
  ekskludert?: boolean
}

// Lagrer/overstyrer en plan-linje (planlagt, startAntall, ekskluder). Bevarer
// lagd_hittil (settes ikke her — kun fra tableten).
export async function setLinje(data: LinjeData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !data.stasjon_id || !data.dato || !data.varenavn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('produksjonsplan_linjer').upsert(
    {
      retailer_id: bruker.retailerId,
      stasjon_id: data.stasjon_id,
      dato: data.dato,
      varenavn: data.varenavn,
      varegruppe_kode: data.varegruppe_kode,
      varegruppe_navn: data.varegruppe_navn,
      foreslatt: Math.round(data.foreslatt),
      planlagt: Math.max(0, Math.round(data.planlagt)),
      start_antall: Math.max(0, Math.round(data.start_antall ?? 0)),
      ekskludert: data.ekskludert ?? false,
      oppdatert_tid: new Date().toISOString(),
    },
    { onConflict: 'stasjon_id,dato,varenavn' },
  )
}

// Notat til de ansatte (per stasjon/dag).
export async function setNotat(stasjon_id: string, dato: string, notat: string): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !stasjon_id || !dato) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('produksjonsplan_hode').upsert(
    { retailer_id: bruker.retailerId, stasjon_id, dato, notat: notat.trim() || null, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,dato' },
  )
}

// Publiser planen til tableten (bevarer «lagd hittil»). Setter publisert_tid.
export async function publiser(stasjon_id: string, dato: string): Promise<{ ok: boolean }> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId || !stasjon_id || !dato) return { ok: false }
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('produksjonsplan_hode').upsert(
    { retailer_id: bruker.retailerId, stasjon_id, dato, publisert_tid: new Date().toISOString(), oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,dato' },
  )
  return { ok: !error }
}

// Arrangement (Brann-kamp o.l.) — egen faktor på forslaget for en dag.
export async function leggTilArrangement(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const dato = String(formData.get('dato') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  const stasjon_id = String(formData.get('stasjon_id') ?? '') || null
  const faktor = Math.max(0.1, Math.min(5, Number(formData.get('faktor')) || 1.2))
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dato) || !navn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('arrangementer').insert({ retailer_id: bruker.retailerId, stasjon_id, dato, navn, faktor, opprettet_av: bruker.id })
  revalidatePath('/produksjonsplan')
}

export async function slettArrangement(formData: FormData): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('arrangementer').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/produksjonsplan')
}

// Tablet: ansatte logger hvor mange som er lagd hittil (absolutt verdi).
export async function loggLagd(stasjon_id: string, dato: string, varenavn: string, lagd: number): Promise<void> {
  await hentInnloggetBruker() // sikrer innlogget sesjon; RLS styrer tilgang
  if (!stasjon_id || !dato || !varenavn) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('produksjonsplan_linjer')
    .update({ lagd_hittil: Math.max(0, Math.round(lagd)), oppdatert_tid: new Date().toISOString() })
    .eq('stasjon_id', stasjon_id).eq('dato', dato).eq('varenavn', varenavn)
}
