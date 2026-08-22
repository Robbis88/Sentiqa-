'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { formulerNyhetstekst } from '@/lib/ai/nyhet'
import { maaLykkes } from '@/lib/skriv-svar'

const Nytt = z.object({
  tittel: z.string().min(1, { error: 'Skriv en tittel.' }),
  innhold: z.string().min(1, { error: 'Skriv innhold.' }),
})

export type RedTilstand = { ok?: true; feil?: string } | undefined

export async function opprettInnlegg(_t: RedTilstand, formData: FormData): Promise<RedTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return { feil: 'Kun plattform-redaktør.' }
  const felt = Nytt.safeParse({ tittel: formData.get('tittel'), innhold: formData.get('innhold') })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const publiser = formData.get('publiser') === 'on'

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('plattform_innlegg').insert({
    tittel: felt.data.tittel,
    innhold: felt.data.innhold,
    publisert: publiser,
    publisert_tid: publiser ? new Date().toISOString() : null,
    forfatter: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/redaktor')
  return { ok: true }
}

// AI-hjelp: formuler nyhetstekst fra stikkord. Returnerer forslag (ikke lagret).
export async function formulerNyhet(
  ide: string,
  tone: string,
): Promise<{ tittel: string; innhold: string } | { feil: string }> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return { feil: 'Kun plattform-redaktør.' }
  if (!ide || ide.trim().length < 3) return { feil: 'Skriv noen stikkord om hva nyheten skal handle om.' }
  try {
    const r = await formulerNyhetstekst(ide.trim(), tone || 'nøytral og informativ')
    if (!r) return { feil: 'AI er ikke tilgjengelig akkurat nå.' }
    return { tittel: r.tittel, innhold: r.innhold }
  } catch {
    return { feil: 'Klarte ikke å lage forslag. Prøv igjen.' }
  }
}

export async function settPublisert(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return
  const id = String(formData.get('id') ?? '')
  const til = String(formData.get('til') ?? '') === 'ja'
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase
    .from('plattform_innlegg')
    .update({ publisert: til, publisert_tid: til ? new Date().toISOString() : null })
    .eq('id', id), 'oppdatere plattform innlegg')
  revalidatePath('/redaktor')
}

export async function slettInnlegg(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('plattform_innlegg').update({ slettet_tid: new Date().toISOString() }).eq('id', id), 'slette plattform innlegg')
  revalidatePath('/redaktor')
}
