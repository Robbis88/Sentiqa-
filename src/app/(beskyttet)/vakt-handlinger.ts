'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin, settAktivAnsatt, fjernAktivAnsatt, vaktErSattOpp } from '@/lib/ansatt'

export type VaktTilstand = { feil?: string } | undefined

/**
 * Samme melding for ukjent nummer og feil PIN.
 *
 * «Ukjent PIN» mot «feil PIN» er forskjellen på å vite at et nummer
 * finnes og ikke. Med to meldinger kan man kartlegge hvem som jobber
 * her ved å prøve numre — og nummeret er ingen hemmelighet, men lista
 * over hvem som er ansatt er noe annet.
 *
 * Setningen om ansattnummer står HER, i den ene meldingen, i stedet for
 * som et eget svar for «du har ikke nummer ennå». Et slikt eget svar
 * ville vært nøyaktig lekkasjen over, med vennlig ordlyd. Nå får den
 * som mangler nummer en vei videre, uten at noen kan lese ut av svaret
 * hvilken av de tre tingene som var galt.
 */
const AVVIST =
  'Fant ingen med det nummeret og den PIN-en. '
  + 'Har du ikke fått ansattnummer ennå, må butikksjefen legge det inn.'

/**
 * Start vakt: ansattnummer + PIN.
 *
 * NUMMER OG PIN, IKKE PIN ALENE. Fram til dette trinnet slo innsjekken
 * opp på `pin_hash` og LOT PIN-en være identiteten. Følgen var ikke at
 * to kunne kollidere — en unik indeks hindrer det — men at man ikke
 * trengte å utpeke noen: enhver gyldig PIN logget deg inn som den som
 * eide den. Med femti ansatte traff et tilfeldig firesifret forsøk én av
 * to hundre, og PIN-feltet sto i klartekst i toppstripa, i en butikk,
 * ved siden av kolleger og kunder.
 *
 * Å navngi personen først gjør gjettingen til én av ti tusen for en
 * BESTEMT person, og gjør skuldersurfing alene utilstrekkelig.
 *
 * Formen er den samme som `stemple()` (0110): oppslag på nummer,
 * sammenligning av hash etterpå. To steder som svarer på det samme
 * spørsmålet skal ikke gjøre det på hver sin måte.
 */
export async function checkInn(_t: VaktTilstand, formData: FormData): Promise<VaktTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!bruker.retailerId) return { feil: 'Mangler tilgang.' }

  // FEILER LUKKET. Uten signaturnokkelen kan kapselen skrives for
  // haand, og da er vakta en paastand. Da er det riktigere at ingen kan
  // starte vakt enn at alle kan starte som hvem som helst.
  if (!vaktErSattOpp()) {
    return { feil: 'Vakt er ikke satt opp paa denne installasjonen. Si fra til butikksjefen.' }
  }

  const nummer = String(formData.get('ansatt_nr') ?? '').trim()
  const pin = String(formData.get('pin') ?? '').trim()
  if (!nummer) return { feil: 'Skriv inn ansattnummeret ditt.' }
  if (!/^\d{4,6}$/.test(pin)) return { feil: 'PIN må være 4–6 siffer.' }

  const supabase = await lagSupabaseServerKlient()

  // OPPSLAG PÅ NUMMER. PIN-en står ikke i spørringen i det hele tatt:
  // en `where pin_hash = …` er per definisjon å bruke hemmeligheten som
  // identitet, uansett hva som sammenlignes etterpå.
  const { data: ansatt } = await supabase
    .from('ansatte')
    .select('id, pin_hash')
    .eq('retailer_id', bruker.retailerId)
    .eq('ansatt_nr', nummer)
    .eq('aktiv', true)
    .is('slettet_tid', null)
    .maybeSingle<{ id: string; pin_hash: string }>()

  if (!ansatt || ansatt.pin_hash !== hashPin(bruker.retailerId, pin)) {
    return { feil: AVVIST }
  }

  // BARE ID-EN LAGRES. Navnet hentes fra basen ved hver lesing — se
  // `lesAktivAnsatt`. En kapsel skal huske et resultat, ikke bære et
  // navn systemet viser fram som om det var kontrollert.
  await settAktivAnsatt({ id: ansatt.id })
  revalidatePath('/', 'layout')
  return undefined
}

export async function checkUt() {
  await fjernAktivAnsatt()
  revalidatePath('/', 'layout')
}
