'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { STANDARD_OPPLAERING } from '@/lib/opplaering/standard'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

// ---- Master-oppgaver ----
export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase.from('opplaering_oppgave').select('*', { count: 'exact', head: true }).eq('retailer_id', bruker.retailerId).is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  maaLykkes(await supabase.from('opplaering_oppgave').insert(
    STANDARD_OPPLAERING.map((o) => ({ retailer_id: bruker.retailerId, kategori: o.kategori, tittel: o.tittel, beskrivelse: o.beskrivelse, rekkefolge: o.rekkefolge, estimert_min: o.estimert_min, opprettet_av: bruker.id })),
  ), 'opprette opplaering oppgave')
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
  maaLykkes(await supabase.from('opplaering_oppgave').insert({ retailer_id: bruker.retailerId, kategori, tittel, estimert_min: Number.isFinite(estimert) && estimert > 0 ? estimert : null, rekkefolge: 999, opprettet_av: bruker.id }), 'opprette opplaering oppgave')
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
  maaLykkes(await supabase.from('opplaering_oppgave').update({ kategori, tittel }).eq('id', id), 'oppdatere opplaering oppgave')
  revalidatePath('/opplaring')
}

export async function slettOppgave(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('opplaering_oppgave').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette oppgave',
    ok: 'Oppgave slettet',
    oppfrisk: ['/opplaring'],
  })
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
  maaLykkes(await supabase.from('opplaering_periode').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    ansatt_navn: navn,
    start_dato: start,
    forventet_slutt: /^\d{4}-\d{2}-\d{2}$/.test(slutt) ? slutt : null,
    opprettet_av: bruker.id,
  }), 'opprette opplaering periode')
  revalidatePath('/opplaring')
}

export async function fullforPeriode(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('opplaering_periode').update({ fullfort_tid: til ? new Date().toISOString() : null }).eq('id', id), 'oppdatere opplaering periode')
  revalidatePath('/opplaring')
}

export async function slettPeriode(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('opplaering_periode').delete({ count: 'exact' }).eq('id', id), {
    hva: 'slette periode',
    ok: 'Periode slettet',
    oppfrisk: ['/opplaring'],
  })
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
    maaLykkes(await supabase.from('opplaering_utfort').upsert({ periode_id: periodeId, oppgave_id: oppgaveId, bekreftet_av: bruker.id }, { onConflict: 'periode_id,oppgave_id', ignoreDuplicates: true }), 'lagre opplaering utfort')
  } else {
    maaLykkes(await supabase.from('opplaering_utfort').delete().eq('periode_id', periodeId).eq('oppgave_id', oppgaveId), 'slette opplaering utfort')
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
  maaLykkes(await supabase.from('opplaering_skift').upsert({ periode_id: periodeId, dato, ansvarlig_bruker_id: bruker.id, notater }, { onConflict: 'periode_id,dato' }), 'lagre opplaering skift')
  revalidatePath('/opplaring')
}

export async function slettSkift(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('opplaering_skift').delete({ count: 'exact' }).eq('id', id), {
    hva: 'slette skift',
    ok: 'Skift slettet',
    oppfrisk: ['/opplaring'],
  })
}
