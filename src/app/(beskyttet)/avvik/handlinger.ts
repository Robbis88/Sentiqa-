'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'

const Ny = z.object({
  stasjon_id: z.string().uuid({ error: 'Velg en stasjon.' }),
  kategori: z.enum(['produkt', 'utstyr']),
  dato: z.string().min(1, { error: 'Velg dato.' }),
  beskrivelse: z.string().min(1, { error: 'Beskriv avviket.' }),
  strakstiltak: z.string().optional(),
  korrigerende: z.string().optional(),
  frist: z.string().optional(),
  varslet_til: z.string().optional(),
})

export type AvvikTilstand = { ok?: true; feil?: string } | undefined

export async function opprettAvvik(_t: AvvikTilstand, formData: FormData): Promise<AvvikTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const felt = Ny.safeParse({
    stasjon_id: formData.get('stasjon_id'),
    kategori: formData.get('kategori'),
    dato: formData.get('dato'),
    beskrivelse: formData.get('beskrivelse'),
    strakstiltak: formData.get('strakstiltak'),
    korrigerende: formData.get('korrigerende'),
    frist: formData.get('frist'),
    varslet_til: formData.get('varslet_til'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const d = felt.data

  const supabase = await lagSupabaseServerKlient()
  const { count } = await supabase
    .from('avvik')
    .select('*', { count: 'exact', head: true })
    .eq('retailer_id', bruker.retailerId)
  const lopenr = (count ?? 0) + 1

  const { error } = await supabase.from('avvik').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: d.stasjon_id,
    lopenr,
    kategori: d.kategori,
    dato: d.dato,
    beskrivelse: d.beskrivelse,
    strakstiltak: d.strakstiltak || null,
    korrigerende: d.korrigerende || null,
    frist: d.frist || null,
    varslet_til: d.varslet_til || null,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/avvik')
  return { ok: true }
}

export async function settGjennomfort(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!['retailer_admin', 'butikksjef'].includes(bruker.rolle)) return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  const idag = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
  await supabase
    .from('avvik')
    .update({ gjennomfort: til, gjennomfort_dato: til ? idag : null })
    .eq('id', id)
  revalidatePath('/avvik')
}
