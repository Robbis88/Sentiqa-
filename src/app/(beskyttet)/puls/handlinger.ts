'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'

function iDag(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(new Date())
}

export type PulsTilstand = { ok?: true; feil?: string } | undefined

export async function giPuls(_t: PulsTilstand, formData: FormData): Promise<PulsTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const humor = Number(formData.get('humor'))
  const kommentar = String(formData.get('kommentar') ?? '').trim() || null
  if (!Number.isInteger(humor) || humor < 1 || humor > 5) return { feil: 'Velg humør.' }

  const supabase = await lagSupabaseServerKlient()
  const ansatt = await lesAktivAnsatt()

  // Finn stasjon: aktiv ansatt sin stasjon, ellers valgt i skjema.
  let stasjonId = String(formData.get('stasjon_id') ?? '')
  let ansattId: string | null = null
  if (ansatt) {
    const { data } = await supabase.from('ansatte').select('stasjon_id').eq('id', ansatt.id).maybeSingle<{ stasjon_id: string }>()
    if (data) { stasjonId = data.stasjon_id; ansattId = ansatt.id }
  }
  if (!stasjonId) return { feil: 'Logg på vakt med PIN, eller velg stasjon.' }

  if (ansattId) {
    await supabase.from('puls_svar').upsert(
      { retailer_id: bruker.retailerId, stasjon_id: stasjonId, ansatt_id: ansattId, dato: iDag(), humor, kommentar },
      { onConflict: 'ansatt_id,dato' },
    )
  } else {
    await supabase.from('puls_svar').insert({
      retailer_id: bruker.retailerId, stasjon_id: stasjonId, dato: iDag(), humor, kommentar,
    })
  }
  revalidatePath('/puls')
  return { ok: true }
}
