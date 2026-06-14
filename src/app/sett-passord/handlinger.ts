'use server'
import { redirect } from 'next/navigation'
import * as z from 'zod'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const Skjema = z.object({
  passord: z.string().min(8, { error: 'Passordet må være minst 8 tegn.' }),
  passord2: z.string(),
}).refine((d) => d.passord === d.passord2, { error: 'Passordene er ikke like.', path: ['passord2'] })

export type SettTilstand = { feil?: string } | undefined

export async function settPassord(_t: SettTilstand, formData: FormData): Promise<SettTilstand> {
  const felt = Skjema.safeParse({ passord: formData.get('passord'), passord2: formData.get('passord2') })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { feil: 'Invitasjonslenken er utløpt eller allerede brukt. Be om en ny.' }

  const { error } = await supabase.auth.updateUser({ password: felt.data.passord })
  if (error) return { feil: 'Kunne ikke sette passordet. Prøv igjen.' }
  redirect('/oversikt')
}
