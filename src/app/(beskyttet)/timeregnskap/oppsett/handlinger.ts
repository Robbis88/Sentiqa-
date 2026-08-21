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
// =====================================================================

/** Bare eier. Butikksjefen skal ikke kunne utvide sin egen ramme. */
async function eier() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return null
  return bruker
}

/**
 * Setter haken for én måned.
 *
 * TRE TILSTANDER, IKKE TO. «Ukjent» er ikke det samme som «nei»: en
 * måned ingen har tatt stilling til skal ikke justere rammen, og den
 * skal se uavklart ut. Derfor sletter `ukjent` raden i stedet for å
 * lagre `false` — da er tomt i basen og tomt på skjermen samme ting.
 */
export async function settDekning(formData: FormData) {
  const bruker = await eier()
  if (!bruker) return

  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const ar = Number(formData.get('ar'))
  const maned = Number(formData.get('maned'))
  const svar = String(formData.get('svar') ?? '')
  const notat = String(formData.get('notat') ?? '').trim() || null

  // TIMETALLET UTLEDES ALDRI AV LEDERSTATUSEN. Det leses fra feltet
  // eieren skrev i, og bare derfra. Automatikken i 0119 ga Laguneparken
  // 953 timer uten at noen hadde tatt stilling — et forhåndsutfylt felt
  // ville vært den samme automatikken med et ekstra klikk.
  const timer = normaliserTimer(String(formData.get('timer_tilbake') ?? ''))

  if (!stasjonId || !Number.isInteger(ar) || ar < 2020 || ar > 2100) return
  if (!Number.isInteger(maned) || maned < 1 || maned > 12) return
  if (!['ja', 'nei', 'ukjent'].includes(svar)) return

  const supabase = await lagSupabaseServerKlient()

  if (svar === 'ukjent' && timer === null && !notat) {
    // Ingenting å huske. Tomt i basen og tomt på skjermen er samme ting.
    await supabase.from('bemanning_lederdekning').delete()
      .eq('stasjon_id', stasjonId).eq('ar', ar).eq('maned', maned)
  } else {
    await supabase.from('bemanning_lederdekning').upsert({
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
  }

  revalidatePath('/timeregnskap/oppsett')
  revalidatePath('/timeregnskap')
}

/**
 * Setter årsverket St1 trakk fra, per stasjon og år.
 *
 * UTEN DETTE GJØR HAKENE INGENTING. `fast_arsverk_timer` er 0 på alle
 * stasjoner i dag, og en justering på 0/12 er ingen justering. Siden
 * viser derfor tallet, og sier fra når det mangler — en innstilling som
 * feiler stille er verre enn en som mangler.
 */
export async function settArsverk(formData: FormData) {
  const bruker = await eier()
  if (!bruker) return

  const stasjonId = String(formData.get('stasjon_id') ?? '')
  const ar = Number(formData.get('ar'))
  const timer = Number(formData.get('timer'))

  if (!stasjonId || !Number.isInteger(ar)) return
  // Øvre grense: et årsverk er ~1695 timer. Et tall over 3000 er en
  // tastefeil, ikke en stilling — og det ville doblet rammen.
  if (!Number.isFinite(timer) || timer < 0 || timer > 3000) return

  const supabase = await lagSupabaseServerKlient()
  const { data } = await supabase.from('bemanning_aar')
    .select('id').eq('stasjon_id', stasjonId).eq('ar', ar).maybeSingle()

  if (data) {
    await supabase.from('bemanning_aar')
      .update({ fast_arsverk_timer: timer }).eq('id', data.id)
  } else {
    // Ingen rad ennå: BP-en er ikke importert for dette året. Da lages
    // en med timer_aar = 0, som ikke gir noen ramme — bare et sted å
    // holde årsverket til importen kommer.
    await supabase.from('bemanning_aar').insert({
      stasjon_id: stasjonId, ar, timer_aar: 0, fast_arsverk_timer: timer,
    })
  }

  revalidatePath('/timeregnskap/oppsett')
  revalidatePath('/timeregnskap')
}

