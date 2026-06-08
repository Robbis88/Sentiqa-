'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin } from '@/lib/ansatt'

const Ny = z.object({
  navn: z.string().min(1, { error: 'Skriv inn navn.' }),
  stasjon_id: z.string().uuid({ error: 'Velg stasjon.' }),
  pin: z.string().regex(/^\d{4,6}$/, { error: 'PIN må være 4–6 siffer.' }),
})

export type AnsattTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilAnsatt(_t: AnsattTilstand, formData: FormData): Promise<AnsattTilstand> {
  const bruker = await hentInnloggetBruker()
  if ((bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') || !bruker.retailerId) {
    return { feil: 'Ikke tilgang.' }
  }
  const felt = Ny.safeParse({
    navn: formData.get('navn'),
    stasjon_id: formData.get('stasjon_id'),
    pin: formData.get('pin'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('ansatte').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    navn: felt.data.navn,
    pin_hash: hashPin(bruker.retailerId, felt.data.pin),
    opprettet_av: bruker.id,
  })
  if (error) {
    return { feil: /duplicate|unique/i.test(error.message) ? 'PIN er allerede i bruk — velg en annen.' : error.message }
  }
  revalidatePath('/ansatte')
  return { ok: true }
}

export async function deaktiverAnsatt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('ansatte').update({ aktiv: false, slettet_tid: new Date().toISOString() }).eq('id', id)
  revalidatePath('/ansatte')
}
