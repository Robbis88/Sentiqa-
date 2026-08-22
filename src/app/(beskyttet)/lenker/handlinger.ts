'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

// Lenker er tablet-funksjonen (hurtiglenker for å hjelpe kunder). Alle i
// tenanten (også tablet) kan legge til/fjerne — kun plattform-redaktør sperres.
function kanLenke(rolle: string) {
  return rolle !== 'plattform_redaktor'
}

export async function leggTilLenke(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!kanLenke(bruker.rolle) || !bruker.retailerId) return
  const tittel = String(formData.get('tittel') ?? '').trim()
  let url = String(formData.get('url') ?? '').trim()
  const ikon = String(formData.get('ikon') ?? '').trim() || '🔗'
  if (!tittel || !url) return
  if (!/^https?:\/\//i.test(url)) url = `https://${url}`
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('lenker').insert({ retailer_id: bruker.retailerId, tittel, url, ikon, opprettet_av: bruker.id }), 'opprette lenker')
  revalidatePath('/lenker')
}

export async function slettLenke(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!kanLenke(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('lenker').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette lenke',
    ok: 'Lenke slettet',
    oppfrisk: ['/lenker'],
  })
}
