'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const STASJONSTYPER = ['utfart', 'pendler', 'bydel', 'gjennomfart', 'sentrum'] as const

const Skjema = z.object({
  butikknummer: z.string().regex(/^\d{4}$/, { error: 'Butikknummer må være 4 siffer.' }),
  navn: z.string().min(1, { error: 'Skriv inn et navn.' }),
  stasjonstype: z.enum(STASJONSTYPER),
  svinnterskel: z.string().optional(),
})

export type StasjonTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilStasjon(
  _tilstand: StasjonTilstand,
  formData: FormData,
): Promise<StasjonTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan legge til stasjoner.' }
  }

  const felt = Skjema.safeParse({
    butikknummer: formData.get('butikknummer'),
    navn: formData.get('navn'),
    stasjonstype: formData.get('stasjonstype'),
    svinnterskel: formData.get('svinnterskel'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const terskel = felt.data.svinnterskel?.replace(',', '.').trim()
  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('stasjoner').insert({
    retailer_id: bruker.retailerId,
    butikknummer: felt.data.butikknummer,
    navn: felt.data.navn,
    stasjonstype: felt.data.stasjonstype,
    svinnterskel_prosent: terskel ? Number(terskel) : null,
  })

  if (error) {
    if (error.code === '23505') return { feil: `Butikknummer ${felt.data.butikknummer} finnes allerede.` }
    return { feil: error.message }
  }

  revalidatePath('/stasjoner')
  return { ok: true }
}
