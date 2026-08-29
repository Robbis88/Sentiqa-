'use server'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { formulerNyhetstekst } from '@/lib/ai/nyhet'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

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
}

export async function slettInnlegg(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'plattform_redaktor') return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('plattform_innlegg').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette innlegg',
    ok: 'Innlegg slettet',
    oppfrisk: ['/redaktor'],
  })
}
