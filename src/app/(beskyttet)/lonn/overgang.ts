'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { avstem, kanSnuStasjon } from '@/lib/stempling/avstem'

export type OvergangSvar = { ok?: true; feil?: string } | undefined

/**
 * Setter en stasjon over fra easy@work til stempling — eller tilbake.
 *
 * SJEKKER AVSTEMMINGEN PÅ NYTT HER, ikke bare i knappen. Sida kan ha
 * stått åpen siden i går, og det som avgjør om timene blir riktige skal
 * ikke være hvor fersk en HTML-side er.
 *
 * TILBAKE KREVER INGEN AVSTEMMING. Går noe galt etter overgangen, skal
 * veien tilbake til den kilden som virket være åpen med én gang — en
 * nødbrems med vilkår er ingen nødbrems.
 */
export async function settStemplingskilde(
  _t: OvergangSvar, formData: FormData,
): Promise<OvergangSvar> {
  const bruker = await hentInnloggetBruker()
  // Bare eier. En butikksjef kan rette sine egne stemplinger, men å
  // bytte hva som teller for lønn på en hel stasjon er en annen
  // beslutning — den endrer tallene for alle, med tilbakevirkende kraft.
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) {
    return { feil: 'Bare eier kan sette en stasjon over.' }
  }

  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const til = String(formData.get('til') ?? '')
  const ar = Number(formData.get('ar'))
  const maned = Number(formData.get('maned'))
  if (!stasjonId || (til !== 'tablet' && til !== 'import')) {
    return { feil: 'Ukjent valg.' }
  }

  const supabase = await lagSupabaseServerKlient()

  if (til === 'tablet') {
    if (!ar || !maned) return { feil: 'Mangler måneden det avstemmes mot.' }

    const mm = String(maned).padStart(2, '0')
    const sisteDag = new Date(Date.UTC(ar, maned, 0)).getUTCDate()
    const { data } = await supabase
      .from('stempling')
      .select('ansatt_nr, ansatt_navn, minutter, kilde')
      .eq('stasjon_id', stasjonId)
      .eq('betalt', true)
      .gte('dato', `${ar}-${mm}-01`)
      .lte('dato', `${ar}-${mm}-${sisteDag}`)
    const rader = (data ?? []) as
      { ansatt_nr: string; ansatt_navn: string; minutter: number; kilde: string }[]
    const somKilde = (k: string) => rader
      .filter((r) => r.kilde === k)
      .map((r) => ({ ansattNr: r.ansatt_nr, navn: r.ansatt_navn, minutter: r.minutter }))

    if (!kanSnuStasjon(avstem(somKilde('import'), somKilde('tablet')))) {
      return {
        feil: 'Avstemmingen er ikke ren for denne måneden. '
          + 'Rett avvikene først — timene endrer seg for alle når kilden byttes.',
      }
    }
  }

  const { error } = await supabase
    .from('stasjoner')
    .update({ stempling_kilde: til })
    .eq('id', stasjonId)
  if (error) return { feil: 'Ble ikke lagret. Prøv igjen.' }

  revalidatePath('/lonn')
  revalidatePath('/bemanning')
  return { ok: true }
}
