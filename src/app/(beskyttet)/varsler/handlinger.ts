'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'

export async function markerLest(formData: FormData) {
  await hentInnloggetBruker()
  const id = String(formData.get('id') ?? '')
  if (!id) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('varsler').update({ lest: true }).eq('id', id), 'oppdatere varsler')
  revalidatePath('/varsler')
}

/**
 * Marker alle som lest.
 *
 * =====================================================================
 * NETTBRETTET KUNNE TOEMME BUTIKKSJEFENS INNBOKS
 * =====================================================================
 * Varsler ligger per STASJON, ikke per person, og `varsler_update`
 * (`0107`) slipper nettbrettet gjennom paa hele stasjonen. Bjella i
 * nettbrettets topplinje lenker hit.
 *
 * Én ansatt som ryddet bjella si markerte dermed ogsaa butikksjefens
 * uleste IK-mat- og sjekkpunktvarsler som lest - og de er nettopp de
 * som ikke skal kunne forsvinne uten at noen har sett dem.
 *
 * `.eq('lest', false)` uten flere filtre er en samlehandling, og en
 * samlehandling paa en delt enhet rammer alltid noen andre enn den som
 * trykket. Den hoerer til lederen.
 *
 * ENKELTVARSLER STAAR IGJEN AAPNE. En ansatt kan fortsatt kvittere ut
 * ett hun har lest; det er en handling med et menneske bak hver rad.
 */
export async function markerAlle() {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    throw new Error('Bare butikksjef og eier kan markere alle varsler som lest.')
  }
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('varsler').update({ lest: true }).eq('lest', false), 'oppdatere varsler')
  revalidatePath('/varsler')
}
