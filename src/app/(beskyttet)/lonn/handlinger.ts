'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

export type Tilstand = { ok?: string; feil?: string } | undefined

const Form = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
  lonnsform: z.literal(['timelonn', 'fastlonn', 'tilkalling']),
})

/**
 * Setter lønnsformen for én ansatt.
 *
 * Upsert, ikke update: de fleste som stempler har ikke noe ansattkort fra
 * før — det er nettopp derfor lønnsformen mangler.
 */
export async function settLonnsform(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = Form.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
    lonnsform: fd.get('lonnsform'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/lonn')
  return { ok: 'Lagret' }
}
