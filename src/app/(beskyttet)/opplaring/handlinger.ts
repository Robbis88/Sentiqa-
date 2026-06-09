'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { STANDARD_OPPLAERING } from '@/lib/opplaering/standard'

function erLeder(rolle: string) {
  return rolle === 'retailer_admin' || rolle === 'butikksjef'
}

// ---- Master-oppgaver ----
export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase.from('opplaering_oppgave').select('*', { count: 'exact', head: true }).eq('retailer_id', bruker.retailerId).is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  await supabase.from('opplaering_oppgave').insert(
    STANDARD_OPPLAERING.map((o) => ({ retailer_id: bruker.retailerId, kategori: o.kategori, tittel: o.tittel, beskrivelse: o.beskrivelse, rekkefolge: o.rekkefolge, estimert_min: o.estimert_min, opprettet_av: bruker.id })),
  )
  revalidatePath('/opplaring')
}

export async function leggTilOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const kategori = String(formData.get('kategori') ?? '').trim() || 'Generelt'
  const tittel = String(formData.get('tittel') ?? '').trim()
  const estimert = Number(formData.get('estimert_min'))
  if (!tittel) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_oppgave').insert({ retailer_id: bruker.retailerId, kategori, tittel, estimert_min: Number.isFinite(estimert) && estimert > 0 ? estimert : null, rekkefolge: 999, opprettet_av: bruker.id })
  revalidatePath('/opplaring')
}

export async function redigerOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const kategori = String(formData.get('kategori') ?? '').trim() || 'Generelt'
  const tittel = String(formData.get('tittel') ?? '').trim()
  if (!id || !tittel) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_oppgave').update({ kategori, tittel }).eq('id', id)
  revalidatePath('/opplaring')
}

export async function slettOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_oppgave').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/opplaring')
}

// ---- Perioder (nyansatte) ----
export async function leggTilPeriode(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const navn = String(formData.get('ansatt_navn') ?? '').trim()
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const start = String(formData.get('start_dato') ?? '')
  const slutt = String(formData.get('forventet_slutt') ?? '')
  if (!navn || !stasjonId || !/^\d{4}-\d{2}-\d{2}$/.test(start)) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_periode').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    ansatt_navn: navn,
    start_dato: start,
    forventet_slutt: /^\d{4}-\d{2}-\d{2}$/.test(slutt) ? slutt : null,
    opprettet_av: bruker.id,
  })
  revalidatePath('/opplaring')
}

export async function fullforPeriode(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_periode').update({ fullfort_tid: til ? new Date().toISOString() : null }).eq('id', id)
  revalidatePath('/opplaring')
}

export async function slettPeriode(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_periode').delete().eq('id', id)
  revalidatePath('/opplaring')
}

// ---- Kvitt-bok (utført) ----
export async function vekslUtfort(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const periodeId = String(formData.get('periode_id') ?? '')
  const oppgaveId = String(formData.get('oppgave_id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!periodeId || !oppgaveId) return
  const supabase = await lagSupabaseServerKlient()
  if (til) {
    await supabase.from('opplaering_utfort').upsert({ periode_id: periodeId, oppgave_id: oppgaveId, bekreftet_av: bruker.id }, { onConflict: 'periode_id,oppgave_id', ignoreDuplicates: true })
  } else {
    await supabase.from('opplaering_utfort').delete().eq('periode_id', periodeId).eq('oppgave_id', oppgaveId)
  }
  revalidatePath('/opplaring')
}

// ---- Skift-kalender ----
export async function leggTilSkift(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const periodeId = String(formData.get('periode_id') ?? '')
  const dato = String(formData.get('dato') ?? '')
  const notater = String(formData.get('notater') ?? '').trim() || null
  if (!periodeId || !/^\d{4}-\d{2}-\d{2}$/.test(dato)) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_skift').upsert({ periode_id: periodeId, dato, ansvarlig_bruker_id: bruker.id, notater }, { onConflict: 'periode_id,dato' })
  revalidatePath('/opplaring')
}

export async function slettSkift(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('opplaering_skift').delete().eq('id', id)
  revalidatePath('/opplaring')
}
