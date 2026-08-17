'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesTimesats } from '@/lib/lonn/timesats'

export type Tilstand = { ok?: string; feil?: string } | undefined

const Sats = z.object({
  stasjon_id: z.string().uuid(),
  ansatt_nr: z.string().min(1),
  navn: z.string().min(1),
})

/**
 * Registrerer utbetalt timesats for én ansatt.
 *
 * Satsen brukes ikke til å regne ut lønn — Visma-fila bærer timer, og
 * Azets holder satsene. Den er en KONTROLL: uten den ser ingen at Helene
 * ligger 15,44 under laveste voksensats i Energiavtalen.
 *
 * Derfor kan den også endres fritt, når som helst. Ingenting nedstrøms
 * fryser på den, og en allerede generert kontrakt beholder sitt eget
 * øyeblikksbilde av verdiene uansett.
 */
export async function settTimesats(_t: Tilstand, fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }

  const felt = Sats.safeParse({
    stasjon_id: fd.get('stasjon_id'),
    ansatt_nr: fd.get('ansatt_nr'),
    navn: fd.get('navn'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const sats = lesTimesats(fd.get('timesats'))
  if (!sats.ok) return { feil: sats.feil }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatt_avtale').upsert(
    { ...felt.data, timesats: sats.verdi, oppdatert_tid: new Date().toISOString() },
    { onConflict: 'stasjon_id,ansatt_nr' },
  )
  if (error) return { feil: error.message }
  revalidatePath('/lonn')
  return { ok: 'Lagret' }
}

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
