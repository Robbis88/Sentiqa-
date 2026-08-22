'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function registrerBruk(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const beskrivelse = String(formData.get('beskrivelse') ?? '').trim()
  const belop = Number(String(formData.get('belop_kr') ?? '').replace(',', '.'))
  const dato = String(formData.get('dato') ?? '')
  if (!stasjonId || !beskrivelse || !Number.isFinite(belop) || belop <= 0) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('pengepremie_bruk').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    beskrivelse,
    belop_kr: belop,
    dato: /^\d{4}-\d{2}-\d{2}$/.test(dato) ? dato : undefined,
    opprettet_av: bruker.id,
  }), 'opprette pengepremie bruk')
  revalidatePath('/premier')
}

export async function slettBruk(
  _t: SlettTilstand, formData: FormData,
): Promise<SlettTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(formData.get('id') ?? '')
  if (!id) return { feil: 'Ikke tilgang.' }
  const supabase = await lagSupabaseServerKlient()
  // Feilen skal vaere synlig: «slettet» og «gikk ikke» ser
  // ellers helt like ut.
  const { error } = await supabase.from('pengepremie_bruk').delete().eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/premier')
  return { ok: 'Bruken slettet' }
}

// ---- Tildeling av premie (utenom konkurranse) — KUN admin/eier ----
export async function tildelPremie(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const beskrivelse = String(formData.get('beskrivelse') ?? '').trim()
  const belop = Number(String(formData.get('belop_kr') ?? '').replace(',', '.'))
  const dato = String(formData.get('dato') ?? '')
  if (!stasjonId || !beskrivelse || !Number.isFinite(belop) || belop <= 0) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('pengepremie').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    beskrivelse,
    belop_kr: belop,
    dato: /^\d{4}-\d{2}-\d{2}$/.test(dato) ? dato : undefined,
    opprettet_av: bruker.id,
  }), 'opprette pengepremie')
  revalidatePath('/premier')
}

export async function vekslUtbetalt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('pengepremie').update({ utbetalt: til }).eq('id', id), 'oppdatere pengepremie')
  revalidatePath('/premier')
}

export async function slettTildeling(
  _t: SlettTilstand, formData: FormData,
): Promise<SlettTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { feil: 'Ikke tilgang.' }
  const id = String(formData.get('id') ?? '')
  if (!id) return { feil: 'Ikke tilgang.' }
  const supabase = await lagSupabaseServerKlient()
  // Feilen skal vaere synlig: «slettet» og «gikk ikke» ser
  // ellers helt like ut.
  const { error } = await supabase.from('pengepremie').delete().eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/premier')
  return { ok: 'Tildelingen slettet' }
}
