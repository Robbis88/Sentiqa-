'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { iDag } from '@/lib/format'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { opprettVarsel } from '@/lib/varsler'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { maaLykkes } from '@/lib/skriv-svar'

const Nytt = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg en stasjon.' }),
  sporsmaal: z.string().min(1, { error: 'Skriv et spørsmål.' }),
  klokkeslett: z.string().regex(/^\d{2}:\d{2}$/, { error: 'Ugyldig klokkeslett.' }).optional().or(z.literal('')),
  kritisk: z.string().optional(),
})

export type SjekkTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilSjekkpunkt(
  _t: SjekkTilstand,
  formData: FormData,
): Promise<SjekkTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return { feil: 'Du kan ikke opprette sjekkpunkter.' }
  }
  const felt = Nytt.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    sporsmaal: formData.get('sporsmaal'),
    klokkeslett: formData.get('klokkeslett'),
    kritisk: formData.get('kritisk'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('sjekkpunkter').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    sporsmaal: felt.data.sporsmaal,
    klokkeslett: felt.data.klokkeslett || null,
    kritisk: felt.data.kritisk === 'on',
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/sjekkpunkt')
  return { ok: true }
}

export async function slettSjekkpunkt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('sjekkpunkter').update({ slettet_tid: new Date().toISOString() }).eq('id', id), 'slette sjekkpunkter')
  revalidatePath('/sjekkpunkt')
}

// Tablet: svar på ett sjekkpunkt (sporadisk popup). Tar args, ikke formData.
export async function svarSjekkpunktTablet(sjekkpunktId: string, stasjonId: string, ja: boolean): Promise<{ ok: boolean }> {
  const bruker = await hentInnloggetBruker()
  if (!sjekkpunktId || !stasjonId) return { ok: false }
  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt(supabase)
  maaLykkes(await supabase.from('sjekkpunkt_svar').upsert(
    { sjekkpunkt_id: sjekkpunktId, stasjon_id: stasjonId, dato: iDag(), svar: ja, svart_av: bruker.id, svart_tid: new Date().toISOString(), ansatt_id: ansatt?.id ?? null },
    { onConflict: 'sjekkpunkt_id,dato' },
  ), 'lagre sjekkpunkt svar')
  if (!ja && bruker.retailerId) {
    const { data: sp } = await supabase.from('sjekkpunkter').select('sporsmaal, kritisk').eq('id', sjekkpunktId).maybeSingle<{ sporsmaal: string; kritisk: boolean }>()
    if (sp?.kritisk) {
      await opprettVarsel(supabase, { retailer_id: bruker.retailerId, stasjon_id: stasjonId, type: 'sjekkpunkt', tittel: 'Kritisk sjekkpunkt: Nei', tekst: sp.sporsmaal, lenke: '/sjekkpunkt' })
    }
  }
  return { ok: true }
}

export async function svar(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const sjekkpunktId = String(formData.get('sjekkpunkt_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const verdi = String(formData.get('svar') ?? '') === 'ja'
  if (!sjekkpunktId || !stasjonId) return
  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt(supabase)
  maaLykkes(await supabase.from('sjekkpunkt_svar').upsert(
    { sjekkpunkt_id: sjekkpunktId, stasjon_id: stasjonId, dato: iDag(), svar: verdi, svart_av: bruker.id, svart_tid: new Date().toISOString(), ansatt_id: ansatt?.id ?? null },
    { onConflict: 'sjekkpunkt_id,dato' },
  ), 'lagre sjekkpunkt svar')

  // Kritisk sjekkpunkt besvart «Nei» → varsle stasjonen (§11).
  if (!verdi && bruker.retailerId) {
    const { data: sp } = await supabase
      .from('sjekkpunkter')
      .select('sporsmaal, kritisk')
      .eq('id', sjekkpunktId)
      .maybeSingle<{ sporsmaal: string; kritisk: boolean }>()
    if (sp?.kritisk) {
      await opprettVarsel(supabase, {
        retailer_id: bruker.retailerId,
        stasjon_id: stasjonId,
        type: 'sjekkpunkt',
        tittel: 'Kritisk sjekkpunkt: Nei',
        tekst: sp.sporsmaal,
        lenke: '/sjekkpunkt',
      })
    }
  }

  revalidatePath('/sjekkpunkt')
}
