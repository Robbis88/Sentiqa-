'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'
import { kvitter, type Kvittering } from '@/lib/kvittering'

// Kun eier (retailer_admin) styrer arrangementer/kalender-kilder.
async function kreverAdmin() {
  const bruker = await hentInnloggetBruker()
  return bruker.rolle === 'retailer_admin' ? bruker : null
}

function valgteStasjoner(formData: FormData): string[] {
  return formData.getAll('stasjon_id').map((v) => String(v)).filter(Boolean)
}

// Manuelt arrangement (kamp, festival …). Bekreftet med en gang. Velger man
// flere stasjoner lages én rad pr stasjon; ingen valgt = gjelder alle (null).
export async function leggTilArrangement(formData: FormData): Promise<void> {
  const bruker = await kreverAdmin()
  if (!bruker?.retailerId) return
  const dato = String(formData.get('dato') ?? '')
  const navn = String(formData.get('navn') ?? '').trim()
  const faktor = Math.max(0.1, Math.min(5, Number(formData.get('faktor')) || 1.2))
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dato) || !navn) return
  const stasjoner = valgteStasjoner(formData)
  const felles = { retailer_id: bruker.retailerId, dato, navn, faktor, status: 'bekreftet', opprettet_av: bruker.id }
  const stasjonIder: (string | null)[] = stasjoner.length > 0 ? stasjoner : [null]
  const rader = stasjonIder.map((stasjon_id) => ({ ...felles, stasjon_id }))
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('arrangementer').insert(rader), 'opprette arrangementer')
  revalidatePath('/arrangementer')
}

export async function bekreftArrangement(formData: FormData): Promise<void> {
  if (!(await kreverAdmin())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const faktor = Math.max(0.1, Math.min(5, Number(formData.get('faktor')) || 1.2))
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('arrangementer').update({ status: 'bekreftet', faktor }).eq('id', id), 'oppdatere arrangementer')
  revalidatePath('/arrangementer')
}

export async function forkastArrangement(formData: FormData): Promise<void> {
  if (!(await kreverAdmin())) return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('arrangementer').update({ slettet_tid: new Date().toISOString() }).eq('id', id), 'slette arrangementer')
  revalidatePath('/arrangementer')
}

// Kalender-kilde (iCal). stasjon_ider tomt = alle stasjoner.
export async function leggTilKalenderKilde(formData: FormData): Promise<void> {
  const bruker = await kreverAdmin()
  if (!bruker?.retailerId) return
  const navn = String(formData.get('navn') ?? '').trim()
  const ical_url = String(formData.get('ical_url') ?? '').trim()
  const standard_faktor = Math.max(0.1, Math.min(5, Number(formData.get('standard_faktor')) || 1.2))
  if (!navn || !/^https?:\/\//i.test(ical_url)) return
  const stasjoner = valgteStasjoner(formData)
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('kalender_kilder').insert({
    retailer_id: bruker.retailerId, navn, ical_url, standard_faktor,
    stasjon_ider: stasjoner.length > 0 ? stasjoner : null, opprettet_av: bruker.id,
  }), 'opprette kalender kilder')
  revalidatePath('/arrangementer')
}

export async function slettKalenderKilde(_t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  if (!(await kreverAdmin())) return { feil: 'Ikke tilgang.' }
  const id = String(fd.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  return kvitter(supabase.from('kalender_kilder').update({ slettet_tid: new Date().toISOString() }, { count: 'exact' }).eq('id', id), {
    hva: 'slette kalenderkilde',
    ok: 'Kalenderkilde slettet',
    oppfrisk: ['/arrangementer'],
  })
}
