'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { normaliserTimer } from '@/lib/bemanning/lederdekning'

// =====================================================================
// Oppsettet som styrer timeregnskapet.
//
// EIER, IKKE BUTIKKSJEF — og det er ikke en tilfeldighet i menyen.
// Hakene her utvider stasjonens ramme. Kunne butikksjefen sette dem,
// kunne hun utvide sin egen. Portneren står her OG i RLS-policyen på
// `bemanning_lederdekning`; den i databasen er den som gjelder, denne
// er den som gir et forståelig svar i stedet for en tom liste.
//
// FEILEN SKAL VÆRE SYNLIG. Første utgave returnerte `void` og ignorerte
// `{ error }` fra Supabase. Da så en avvist lagring nøyaktig ut som en
// vellykket: knappen ble trykket, siden lastet, og ingenting hadde
// skjedd. Robert meldte det som «det går ikke an å lagre», og han hadde
// ikke noe å gå på — for det var ingenting å se.
//
// En serverhandling som svelger feilen sin er verre enn en som kaster:
// den lærer brukeren at knappen ikke virker, uten å si hvorfor.
// =====================================================================

export type DekningTilstand = { ok?: true; feil?: string } | undefined

/** Bare eier. Butikksjefen skal ikke kunne utvide sin egen ramme. */
async function eier() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return null
  return bruker
}

/**
 * Lagrer én måned: faktumet og beslutningen.
 *
 * TO FELTER, OG DE KAN VÆRE UENIGE. `fastlonnet` sier om det var en
 * fastlønnet butikksjef på plass; `timer_tilbake` sier hva eieren valgte
 * å gi. En leder i permisjon uten vikar er «nei» og «ingenting», og det
 * er en fullt gyldig rad.
 *
 * TIMETALLET UTLEDES ALDRI AV LEDERSTATUSEN. Skjemaet viser forslaget
 * 141,25 som tekst, men fyller aldri feltet — det var nettopp
 * automatikken i 0119 som ga bort 953 timer på Laguneparken uten at noen
 * hadde tatt stilling.
 */
export async function settDekning(
  _t: DekningTilstand, formData: FormData,
): Promise<DekningTilstand> {
  const bruker = await eier()
  if (!bruker) return { feil: 'Kun eier kan endre lederdekning.' }

  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const ar = Number(formData.get('ar'))
  const maned = Number(formData.get('maned'))
  const svar = String(formData.get('svar') ?? '')
  const notat = String(formData.get('notat') ?? '').trim() || null
  const raaTimer = String(formData.get('timer_tilbake') ?? '').trim()
  const timer = normaliserTimer(raaTimer)

  if (!stasjonId) return { feil: 'Mangler stasjon.' }
  if (!Number.isInteger(ar) || ar < 2020 || ar > 2100) return { feil: 'Ugyldig år.' }
  if (!Number.isInteger(maned) || maned < 1 || maned > 12) return { feil: 'Ugyldig måned.' }
  if (!['ja', 'nei', 'ukjent'].includes(svar)) return { feil: 'Ugyldig lederdekning.' }

  // ET TALL SOM BLE FORKASTET SKAL SI FRA. Skrev noen «1695» i et
  // månedsfelt, eller «to», er stillhet feil svar — da ville raden blitt
  // lagret uten timene og sett riktig ut.
  if (raaTimer !== '' && timer === null && raaTimer !== '0') {
    return { feil: `«${raaTimer}» er ikke et gyldig timetall. Bruk et tall mellom 0 og 300, for eksempel 141,25.` }
  }

  const supabase = await lagSupabaseServerKlient()

  if (svar === 'ukjent' && timer === null && !notat) {
    // Ingenting å huske. Tomt i basen og tomt på skjermen er samme ting.
    const { error } = await supabase.from('bemanning_lederdekning').delete()
      .eq('stasjon_id', stasjonId).eq('ar', ar).eq('maned', maned)
    if (error) return { feil: `Kunne ikke nullstille måneden: ${error.message}` }
  } else {
    const { error } = await supabase.from('bemanning_lederdekning').upsert({
      retailer_id: bruker.retailerId,
      stasjon_id: stasjonId,
      ar,
      maned,
      // `fastlonnet` er `not null` i basen. Har eieren ikke tatt
      // stilling, men skrevet timer eller et notat, er `false` det
      // ærligste: «ikke bekreftet at det var en fastlønnet leder her».
      // Å lagre `true` ville vært en påstand ingen har kommet med.
      fastlonnet: svar === 'ja',
      timer_tilbake: timer,
      notat,
      oppdatert_av: bruker.id,
      oppdatert_tid: new Date().toISOString(),
    }, { onConflict: 'stasjon_id,ar,maned' })
    if (error) return { feil: `Kunne ikke lagre: ${error.message}` }
  }

  revalidatePath('/timeregnskap/oppsett')
  revalidatePath('/timeregnskap')
  return { ok: true }
}

/**
 * Setter årsverket St1 trakk fra, per stasjon og år.
 *
 * BARE ET FORSLAG. Tallet inngår ikke i noen beregning — det brukes til
 * å regne ut «full måned = 141,25 timer», som vises som tekst ved siden
 * av timefeltet. Rammen justeres bare av `timer_tilbake`.
 */
export async function settArsverk(
  _t: DekningTilstand, formData: FormData,
): Promise<DekningTilstand> {
  const bruker = await eier()
  if (!bruker) return { feil: 'Kun eier kan endre årsverket.' }

  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const ar = Number(formData.get('ar'))
  const timer = Number(String(formData.get('timer') ?? '').replace(',', '.'))

  if (!stasjonId) return { feil: 'Mangler stasjon.' }
  if (!Number.isInteger(ar)) return { feil: 'Ugyldig år.' }
  // Øvre grense: et årsverk er ~1695 timer. Et tall over 3000 er en
  // tastefeil, ikke en stilling.
  if (!Number.isFinite(timer) || timer < 0 || timer > 3000) {
    return { feil: 'Årsverket må være mellom 0 og 3000 timer.' }
  }

  const supabase = await lagSupabaseServerKlient()
  const { data, error: lesFeil } = await supabase.from('bemanning_aar')
    .select('id').eq('stasjon_id', stasjonId).eq('ar', ar).maybeSingle()
  if (lesFeil) return { feil: `Kunne ikke lese årsrammen: ${lesFeil.message}` }

  const { error } = data
    ? await supabase.from('bemanning_aar')
      .update({ fast_arsverk_timer: timer }).eq('id', data.id)
    // Ingen rad ennå: BP-en er ikke importert for dette året. Da lages
    // en med timer_aar = 0, som ikke gir noen ramme — bare et sted å
    // holde årsverket til importen kommer.
    : await supabase.from('bemanning_aar').insert({
      stasjon_id: stasjonId, ar, timer_aar: 0, fast_arsverk_timer: timer,
    })

  if (error) return { feil: `Kunne ikke lagre årsverket: ${error.message}` }

  revalidatePath('/timeregnskap/oppsett')
  revalidatePath('/timeregnskap')
  return { ok: true }
}
