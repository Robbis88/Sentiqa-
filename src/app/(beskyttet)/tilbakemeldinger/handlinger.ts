'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt, hentStasjonId } from '@/lib/ansatt'

const ALVOR = ['generelt', 'uhell', 'nestenuhell', 'krenkelse']
export type TilbakeResultat = { ok?: true; feil?: string }

export async function sendTilbakemelding(_t: TilbakeResultat | undefined, formData: FormData): Promise<TilbakeResultat> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const tekst = String(formData.get('tekst') ?? '').trim()
  const alvorlighet = String(formData.get('alvorlighet') ?? 'generelt')
  const involvert = String(formData.get('involvert_beskrivelse') ?? '').trim() || null
  if (!tekst) return { feil: 'Skriv en melding.' }
  if (!ALVOR.includes(alvorlighet)) return { feil: 'Ugyldig type.' }

  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt()
  const stasjonId = await hentStasjonId(supabase, ansatt)
  if (!stasjonId) return { feil: 'Fant ingen stasjon.' }

  const { error } = await supabase.from('tilbakemelding').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: stasjonId,
    opprettet_av: bruker.id,
    ansatt_id: ansatt?.id ?? null,
    alvorlighet,
    tekst,
    involvert_beskrivelse: involvert,
  })
  if (error) return { feil: error.message }
  return { ok: true }
}

export async function markerLest(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('tilbakemelding').update({ lest_tid: new Date().toISOString(), lest_av: bruker.id }).eq('id', id)
  revalidatePath('/tilbakemeldinger')
}
