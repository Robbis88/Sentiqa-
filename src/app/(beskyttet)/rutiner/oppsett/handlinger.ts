'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { VAKTTYPER } from '@/lib/rutineskjema'

function ukedagerFra(formData: FormData): number[] {
  return formData.getAll('ukedager').map((u) => Number(u)).filter((n) => n >= 0 && n <= 6)
}

export async function leggTilSkjema(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const vakttype = String(formData.get('vakttype') ?? '')
  const navn = String(formData.get('navn') ?? '').trim() || null
  const start = String(formData.get('tid_start') ?? '')
  const slutt = String(formData.get('tid_slutt') ?? '')
  if (!stasjonId || !(VAKTTYPER as readonly string[]).includes(vakttype)) return
  if (!/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(slutt)) return

  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutineskjemaer').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    vakttype,
    navn,
    tid_start: start,
    tid_slutt: slutt,
    ukedager: ukedagerFra(formData),
    opprettet_av: bruker.id,
  })
  revalidatePath('/rutiner/oppsett')
}

export async function slettSkjema(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutineskjemaer').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/rutiner/oppsett')
}

export async function oppdaterSkjema(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const navn = String(formData.get('navn') ?? '').trim() || null
  const start = String(formData.get('tid_start') ?? '')
  const slutt = String(formData.get('tid_slutt') ?? '')
  if (!id || !/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(slutt)) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutineskjemaer').update({ navn, tid_start: start, tid_slutt: slutt, ukedager: ukedagerFra(formData) }).eq('id', id)
  revalidatePath(`/rutiner/oppsett/${id}`)
  revalidatePath('/rutiner/oppsett')
}

export async function leggTilRutine(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const skjemaId = String(formData.get('skjema_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const tittel = String(formData.get('tittel') ?? '').trim()
  const beskrivelse = String(formData.get('beskrivelse') ?? '').trim() || null
  const paakrevdBilde = formData.get('paakrevd_bilde') === 'on'
  if (!skjemaId || !stasjonId || !tittel) return

  const supabase = await lagSupabaseServerKlient()
  // Plasser nederst: sortering = høyeste i skjemaet + 1.
  const { data: siste } = await supabase.from('rutiner').select('sortering').eq('skjema_id', skjemaId).is('slettet_tid', null).order('sortering', { ascending: false }).limit(1).maybeSingle<{ sortering: number | null }>()
  await supabase.from('rutiner').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    skjema_id: skjemaId,
    tittel,
    beskrivelse,
    ukedager: ukedagerFra(formData),
    paakrevd_bilde: paakrevdBilde,
    sortering: (siste?.sortering ?? -1) + 1,
    opprettet_av: bruker.id,
  })
  revalidatePath(`/rutiner/oppsett/${skjemaId}`)
  revalidatePath('/rutiner/oppsett')
}

export async function oppdaterRutine(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const skjemaId = String(formData.get('skjema_id') ?? '')
  const tittel = String(formData.get('tittel') ?? '').trim()
  if (!id || !tittel) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutiner').update({
    tittel,
    beskrivelse: String(formData.get('beskrivelse') ?? '').trim() || null,
    ukedager: ukedagerFra(formData),
    paakrevd_bilde: formData.get('paakrevd_bilde') === 'on',
  }).eq('id', id)
  revalidatePath(`/rutiner/oppsett/${skjemaId}`)
}

// Lagre ny rekkefølge fra drag-and-drop: sortering = posisjon i lista.
export async function lagreRekkefolge(skjemaId: string, ids: string[]): Promise<void> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !skjemaId || !Array.isArray(ids)) return
  const supabase = await lagSupabaseServerKlient()
  await Promise.all(ids.map((id, i) => supabase.from('rutiner').update({ sortering: i }).eq('id', id).eq('skjema_id', skjemaId)))
  revalidatePath(`/rutiner/oppsett/${skjemaId}`)
}

export async function slettRutine(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutiner').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/rutiner/oppsett')
}
