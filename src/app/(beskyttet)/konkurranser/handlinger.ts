'use server'
import { revalidatePath } from 'next/cache'
import * as z from 'zod'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maalKonkurranse } from '@/lib/konkurranse'
import { maaLykkes } from '@/lib/skriv-svar'

const Ny = z.object({
  navn: z.string().min(1, { error: 'Skriv et navn.' }),
  kpi: z.string().min(1, { error: 'Beskriv hva som måles.' }),
  maaltype: z.enum(['omsetning', 'antall']),
  varegruppe_kode: z.string().optional(),
  periode_start: z.string().min(1, { error: 'Velg startdato.' }),
  periode_slutt: z.string().min(1, { error: 'Velg sluttdato.' }),
  premie_kr: z.string().optional(),
  premie_tekst: z.string().optional(),
})

export type KonkTilstand = { ok?: true; feil?: string } | undefined

export async function opprettKonkurranse(_t: KonkTilstand, formData: FormData): Promise<KonkTilstand> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return { feil: 'Kun eier kan opprette konkurranser.' }
  const felt = Ny.safeParse({
    navn: formData.get('navn'),
    kpi: formData.get('kpi'),
    maaltype: formData.get('maaltype'),
    varegruppe_kode: formData.get('varegruppe_kode'),
    periode_start: formData.get('periode_start'),
    periode_slutt: formData.get('periode_slutt'),
    premie_kr: formData.get('premie_kr'),
    premie_tekst: formData.get('premie_tekst'),
  })
  if (!felt.success) return { feil: z.prettifyError(felt.error) }
  const d = felt.data
  const premieKr = d.premie_kr ? Number(d.premie_kr.replace(',', '.')) : null

  const supabase = await lagSupabaseServerKlient()
  const { error } = await supabase.from('konkurranser').insert({
    retailer_id: bruker.retailerId,
    navn: d.navn,
    kpi: d.kpi,
    maaltype: d.maaltype,
    varegruppe_kode: d.varegruppe_kode || null,
    periode_start: d.periode_start,
    periode_slutt: d.periode_slutt,
    premie_kr: Number.isFinite(premieKr) ? premieKr : null,
    premie_tekst: d.premie_tekst || null,
    opprettet_av: bruker.id,
  })
  if (error) return { feil: error.message }
  revalidatePath('/konkurranser')
  return { ok: true }
}

export async function kaarVinner(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  const res = await maalKonkurranse(supabase, id)
  if (!res) return // ingen salgsdata ennå
  const { data: k } = await supabase
    .from('konkurranser')
    .select('retailer_id, navn, premie_kr, periode_slutt, premie_utbetalt')
    .eq('id', id)
    .maybeSingle<{ retailer_id: string; navn: string; premie_kr: number | null; periode_slutt: string; premie_utbetalt: boolean }>()
  maaLykkes(await supabase
    .from('konkurranser')
    .update({ status: 'avsluttet', vinner_stasjon_id: res.vinner.stasjon_id })
    .eq('id', id), 'oppdatere konkurranser')
  // Vinneren får premien automatisk som pengepremie-tildeling.
  if (k?.retailer_id && k.premie_kr && Number(k.premie_kr) > 0) {
    maaLykkes(await supabase.from('pengepremie').upsert(
      { retailer_id: k.retailer_id, stasjon_id: res.vinner.stasjon_id, beskrivelse: k.navn, belop_kr: k.premie_kr, dato: k.periode_slutt, utbetalt: k.premie_utbetalt ?? false, konkurranse_id: id, opprettet_av: bruker.id },
      { onConflict: 'konkurranse_id' },
    ), 'lagre pengepremie')
  }
  revalidatePath('/konkurranser')
  revalidatePath('/premier')
}

export async function markerUtbetalt(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase
    .from('konkurranser')
    .update({ premie_utbetalt: true, utbetalt_tid: new Date().toISOString() })
    .eq('id', id), 'oppdatere konkurranser')
  // Hold den koblede tildelingen i synk
  maaLykkes(await supabase.from('pengepremie').update({ utbetalt: true }).eq('konkurranse_id', id), 'oppdatere pengepremie')
  revalidatePath('/konkurranser')
  revalidatePath('/premier')
}

export async function slettKonkurranse(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin') return
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('konkurranser').update({ slettet_tid: new Date().toISOString() }).eq('id', id), 'slette konkurranser')
  revalidatePath('/konkurranser')
}
