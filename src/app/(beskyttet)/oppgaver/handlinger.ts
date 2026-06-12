'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const Ny = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg en stasjon.' }),
  tittel: z.string().min(1, { error: 'Skriv en tittel.' }),
  beskrivelse: z.string().optional(),
  frist: z.string().optional(),
})

export type OppgaveTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilOppgave(
  _t: OppgaveTilstand,
  formData: FormData,
): Promise<OppgaveTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return { feil: 'Du kan ikke opprette oppgaver.' }
  }
  const felt = Ny.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    tittel: formData.get('tittel'),
    beskrivelse: formData.get('beskrivelse'),
    frist: formData.get('frist'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const visPaaTablet = formData.get('vis_paa_tablet') === 'on'
  const bilde = String(formData.get('bilde_url') ?? '').trim() || null
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('oppgaver').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    tittel: felt.data.tittel,
    beskrivelse: felt.data.beskrivelse || null,
    frist: felt.data.frist || null,
    vis_paa_tablet: visPaaTablet,
    bilde_url: bilde,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/oppgaver')
  return { ok: true }
}

export async function slettOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('oppgaver').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/oppgaver')
}

// Tablet: ansatte kvitterer «utført» på en vis_paa_tablet-melding (RPC m/ RLS-sjekk).
export async function kvitterTablet(oppgaveId: string, fullfort: boolean): Promise<void> {
  await hentInnloggetBruker() // sikrer innlogget sesjon
  if (!oppgaveId) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.rpc('kvitter_tablet_melding', { p_oppgave: oppgaveId, p_fullfort: fullfort })
}

export async function veksleOppgave(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const id = String(formData.get('id') ?? '')
  const tilFullfort = String(formData.get('til') ?? '') === 'fullfort'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase
    .from('oppgaver')
    .update(
      tilFullfort
        ? { status: 'fullfort', fullfort_av: bruker.id, fullfort_tid: new Date().toISOString() }
        : { status: 'apen', fullfort_av: null, fullfort_tid: null },
    )
    .eq('id', id)
  revalidatePath('/oppgaver')
}
