'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { VAKTTYPER } from '@/lib/rutineskjema'

function erLeder(rolle: string) {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}
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
  await supabase.from('rutiner').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    skjema_id: skjemaId,
    tittel,
    beskrivelse,
    ukedager: ukedagerFra(formData),
    paakrevd_bilde: paakrevdBilde,
    opprettet_av: bruker.id,
  })
  revalidatePath('/rutiner/oppsett')
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
