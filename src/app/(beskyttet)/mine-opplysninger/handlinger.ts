'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { KONTROLLTILTAK_VERSJON } from '@/lib/personvern/kontrolltiltak'

export type Tilstand = { ok?: string; feil?: string } | undefined

/**
 * Registrerer at informasjonen er lest.
 *
 * Versjonen kommer fra serveren, ikke fra skjemaet — ellers kunne en
 * gammel fane bekreftet en tekst som siden er endret, og bekreftelsen
 * ville dokumentert feil dokument.
 */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export async function bekreftLest(_t: Tilstand, _fd: FormData): Promise<Tilstand> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }

  const supabase = await lagSupabaseServerKlient()

  // På nettbrettet er det den aktive PIN-brukeren som bekrefter, ikke
  // enheten. Uten det ville én bekreftelse dekket hele stasjonen.
  const ansatt = bruker.rolle === 'butikkbruker_tablet' ? await lesAktivAnsatt() : null
  if (bruker.rolle === 'butikkbruker_tablet' && !ansatt) {
    return { feil: 'Logg inn med PIN-koden din først.' }
  }

  // Stasjonen slås opp, for PIN-informasjonskapselen bærer bare id og navn.
  // Null er greit: bekreftelsen gjelder personen, ikke stedet.
  const { data: rad } = ansatt
    ? await supabase.from('ansatte').select('stasjon_id').eq('id', ansatt.id)
      .maybeSingle<{ stasjon_id: string }>()
    : { data: null }

  const { error } = await supabase.from('kontrolltiltak_bekreftelse').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: rad?.stasjon_id ?? null,
    ansatt_id: ansatt?.id ?? null,
    bruker_id: ansatt ? null : bruker.id,
    versjon: KONTROLLTILTAK_VERSJON,
  })
  // Har hun bekreftet før, finnes raden allerede. Det er ikke en feil.
  if (error && !error.message.includes('duplicate')) return { feil: error.message }

  revalidatePath('/mine-opplysninger')
  return { ok: 'Takk — registrert' }
}
