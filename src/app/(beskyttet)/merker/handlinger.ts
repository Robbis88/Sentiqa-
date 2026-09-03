'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { iDag } from '@/lib/format'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { STANDARD_MERKER } from '@/lib/merker/standard'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

export async function settOppStandard() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase
    .from('merker')
    .select('*', { count: 'exact', head: true })
    .eq('retailer_id', bruker.retailerId)
    .is('slettet_tid', null)
  if ((count ?? 0) > 0) return
  maaLykkes(await supabase.from('merker').insert(
    STANDARD_MERKER.map((m, i) => ({
      retailer_id: bruker.retailerId,
      navn: m.navn,
      beskrivelse: m.beskrivelse,
      emoji: m.emoji,
      sortering: i,
    })),
  ), 'opprette merker')
  revalidatePath('/merker')
}

export async function leggTilMerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const navn = String(formData.get('navn') ?? '').trim()
  const emoji = String(formData.get('emoji') ?? '').trim() || '⭐'
  const beskrivelse = String(formData.get('beskrivelse') ?? '').trim() || null
  if (!navn) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('merker').insert({ retailer_id: bruker.retailerId, navn, emoji, beskrivelse, sortering: 999 }), 'opprette merker')
  revalidatePath('/merker')
}

/**
 * Peker ut merket som deles ut naar en opplaering fullfoeres.
 *
 * NOEYAKTIG ETT PER KJEDE — den partielle unike indeksen i `0171` haandhever
 * det. To merker med samme betydning ville tvunget koden til aa velge, og
 * et valg mellom to like gyldige rader er et tilfeldig valg.
 *
 * Derfor nulles alle foerst, og saa settes den ene. Uten det ville
 * innsettingen kollidert med indeksen og sett ut som en feil, mens det
 * brukeren mente var «flytt den hit».
 */
export async function settOpplaeringsmerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const id = String(formData.get('id') ?? '')
  const supabase = await lagSupabaseServerKlient()

  maaLykkes(await supabase.from('merker').update({ tildeles_ved: null })
    .eq('retailer_id', bruker.retailerId).eq('tildeles_ved', 'opplaering_fullfort'),
  'nullstille opplaeringsmerke')

  // Tom id betyr «ingen skal deles ut automatisk», og det er et gyldig
  // valg - da fullfoeres opplaeringer uten at noe merke gis.
  if (id) {
    maaLykkes(await supabase.from('merker').update({ tildeles_ved: 'opplaering_fullfort' })
      .eq('id', id).eq('retailer_id', bruker.retailerId),
    'sette opplaeringsmerke')
  }
  revalidatePath('/merker')
}

export async function slettMerke(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('merker').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette merke',
    ok: 'Merke slettet',
    oppfrisk: ['/merker'],
  })
}

export async function tildelMerke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const merkeId = String(formData.get('merke_id') ?? '')
  const ansattId = String(formData.get('ansatt_id') ?? '')
  if (!merkeId || !ansattId) return
  const supabase = await lagSupabaseServerKlient()
  const { data: ansatt } = await supabase.from('ansatte').select('stasjon_id').eq('id', ansattId).maybeSingle<{ stasjon_id: string }>()
  if (!ansatt) return
  maaLykkes(await supabase.from('tildelte_merker').upsert(
    { merke_id: merkeId, ansatt_id: ansattId, stasjon_id: ansatt.stasjon_id, tildelt_av: bruker.id, tildelt_dato: iDag() },
    { onConflict: 'merke_id,ansatt_id', ignoreDuplicates: true },
  ), 'lagre tildelte merker')
  revalidatePath('/merker')
}

export async function fjernTildeling(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('tildelte_merker').delete({ count: 'exact' }).eq('id', id), {
    hva: 'fjerne tildeling',
    ok: 'Tildeling fjernet',
    oppfrisk: ['/merker'],
  })
}
