'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
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
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return { feil: 'Du kan ikke opprette oppgaver.' }
  }
  const felt = Ny.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    tittel: formData.get('tittel'),
    beskrivelse: formData.get('beskrivelse'),
    frist: formData.get('frist'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('oppgaver').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    tittel: felt.data.tittel,
    beskrivelse: felt.data.beskrivelse || null,
    frist: felt.data.frist || null,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/oppgaver')
  return { ok: true }
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
