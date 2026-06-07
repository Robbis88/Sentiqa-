'use server'
import { redirect } from 'next/navigation'
import * as z from 'zod'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const InnloggingSkjema = z.object({
  epost: z.email({ error: 'Skriv inn en gyldig e-postadresse.' }),
  passord: z.string().min(1, { error: 'Skriv inn passordet ditt.' }),
  retur: z.string().nullish(), // formData.get gir null når feltet mangler
})

export type InnloggingTilstand = { feil?: string } | undefined

export async function loggInn(
  _tilstand: InnloggingTilstand,
  formData: FormData,
): Promise<InnloggingTilstand> {
  const felt = InnloggingSkjema.safeParse({
    epost: formData.get('epost'),
    passord: formData.get('passord'),
    retur: formData.get('retur'),
  })

  if (!felt.success) {
    return { feil: z.prettifyError(felt.error) }
  }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.auth.signInWithPassword({
    email: felt.data.epost,
    password: felt.data.passord,
  })

  if (error) {
    // Bevisst generisk melding — avslører ikke om e-posten finnes.
    return { feil: 'Feil e-post eller passord.' }
  }

  // Kun interne stier som returmål (hindrer open-redirect).
  const retur = felt.data.retur
  const mål = retur && retur.startsWith('/') && !retur.startsWith('//') ? retur : '/oversikt'
  redirect(mål)
}
