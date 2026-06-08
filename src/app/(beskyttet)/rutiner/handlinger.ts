'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'

function iDag(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
}

const NyRutine = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg en stasjon.' }),
  tittel: z.string().min(1, { error: 'Skriv en tittel.' }),
  beskrivelse: z.string().optional(),
  paakrevd_bilde: z.string().optional(),
})

export type RutineTilstand = { ok?: true; feil?: string } | undefined

export async function leggTilRutine(
  _t: RutineTilstand,
  formData: FormData,
): Promise<RutineTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return { feil: 'Du kan ikke opprette rutiner.' }
  }
  const felt = NyRutine.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    tittel: formData.get('tittel'),
    beskrivelse: formData.get('beskrivelse'),
    paakrevd_bilde: formData.get('paakrevd_bilde'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('rutiner').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: felt.data.stasjon_id,
    tittel: felt.data.tittel,
    beskrivelse: felt.data.beskrivelse || null,
    paakrevd_bilde: felt.data.paakrevd_bilde === 'on',
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/rutiner')
  return { ok: true }
}

export async function kryssAv(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  const stasjonId = String(formData.get('stasjon_id') ?? '')
  if (!rutineId || !stasjonId) return
  const ansatt = await lesAktivAnsatt()
  const supabase = await lagSupabaseServerKlient()
  await supabase
    .from('rutine_utforinger')
    .upsert(
      { rutine_id: rutineId, stasjon_id: stasjonId, dato: iDag(), utfort_av: bruker.id, ansatt_id: ansatt?.id ?? null },
      { onConflict: 'rutine_id,dato', ignoreDuplicates: true },
    )
  revalidatePath('/rutiner')
}

export async function fjernKryss(formData: FormData) {
  await hentInnloggetBruker()
  const rutineId = String(formData.get('rutine_id') ?? '')
  if (!rutineId) return
  const supabase = await lagSupabaseServerKlient()
  await supabase.from('rutine_utforinger').delete().eq('rutine_id', rutineId).eq('dato', iDag())
  revalidatePath('/rutiner')
}
