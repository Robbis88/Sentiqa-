'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin, settAktivAnsatt, fjernAktivAnsatt } from '@/lib/ansatt'

export type VaktTilstand = { feil?: string } | undefined

// Innsjekk på vakt med PIN. Setter aktiv ansatt i cookie.
export async function checkInn(_t: VaktTilstand, formData: FormData): Promise<VaktTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }
  const pin = String(formData.get('pin') ?? '').trim()
  if (!/^\d{4,6}$/.test(pin)) return { feil: 'PIN må være 4–6 siffer.' }

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase
    .from('ansatte')
    .select('id, navn')
    .eq('pin_hash', hashPin(bruker.retailerId, pin))
    .eq('aktiv', true)
    .is('slettet_tid', null)
    .maybeSingle<{ id: string; navn: string }>()
  if (!data) return { feil: 'Ukjent PIN.' }

  await settAktivAnsatt({ id: data.id, navn: data.navn })
  revalidatePath('/', 'layout')
  return undefined
}

export async function checkUt() {
  await fjernAktivAnsatt()
  revalidatePath('/', 'layout')
}
