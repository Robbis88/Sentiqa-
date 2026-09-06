'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hashPin, settAktivAnsatt, fjernAktivAnsatt, vaktErSattOpp } from '@/lib/ansatt'

export type VaktTilstand = { feil?: string } | undefined

/** Raden `verifiser_ansatt_pin` gir. Hashen er ikke med - det er hele poenget. */
type Verifikasjon = { ansatt_id: string | null; status: 'ok' | 'avvist' | 'sperret'; vent_sekunder: number }

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
 * Pausen er et FJERDE svar, og det lekker ingenting.
 *
 * Forsøkene telles på nummeret som ble tastet — også når det ikke finnes
 * noen med det nummeret. «Vent litt» sier derfor ikke om personen er
 * ansatt her; det sier bare at noen har prøvd for mange ganger.
 *
 * Og det MÅ være et eget svar. Fikk hun «feil PIN» mens systemet i
 * virkeligheten ikke engang så på PIN-en, ville hun stått og tastet
 * riktig kode om og om igjen uten å forstå hvorfor den ikke virket.
 */
function sperret(sekunder: number): string {
  const min = Math.max(1, Math.ceil(sekunder / 60))
  return `For mange forsøk. Prøv igjen om ${min} ${min === 1 ? 'minutt' : 'minutter'}.`
}

/**
 * Start vakt: ansattnummer + PIN.
 *
 * NUMMER OG PIN, IKKE PIN ALENE. Fram til korrekthetstrinnet slo
 * innsjekken opp på `pin_hash` og lot PIN-en være identiteten. Følgen var
 * ikke kollisjon — en unik indeks hindrer det — men at man ikke trengte å
 * utpeke noen: enhver gyldig PIN logget deg inn som den som eide den.
 *
 * VERIFISERINGEN LIGGER I BASEN NÅ, og det er ikke en omskriving for
 * ryddighetens skyld. `pin_hash` er ikke lenger lesbar for klientrollen
 * (0112), fordi en nettbrettsesjon ellers kunne hente hashene til alle
 * kolleger på stasjonen og knekke dem offline på sekunder.
 *
 * `verifiser_ansatt_pin` er security definer, henter tenanten fra
 * databasekonteksten, teller forsøk og skriver revisjonssporet — alt i
 * ett kall. En funksjon som svarte ja/nei uten å telle ville byttet et
 * offline-angrep mot et online-angrep, og ikke lukket noe.
 *
 * Hashen regnes fortsatt ut her i Node. Da slipper PIN-en aldri inn i en
 * databasespørring, og dermed heller ikke inn i en spørringslogg.
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

  const { data: svar, error } = await supabase.rpc('verifiser_ansatt_pin', {
    p_ansatt_nr: nummer,
    p_pin_hash: hashPin(bruker.retailerId, pin),
    p_kilde: 'vakt',
  })
  // EN NEDE DATABASE ER IKKE FEIL PIN. Samme grunn som i
  // `stempling/handlinger.ts`: uten denne ble en infrastrukturfeil vist
  // som «feil PIN», og hun taster videre på noe som aldri kan lykkes.
  // Fortsatt fail-closed — ingen slipper inn.
  if (error) {
    console.error('verifiser_ansatt_pin feilet (vakt):', error.message)
    return { feil: 'Innlogging er nede akkurat nå. Si fra til butikksjef.' }
  }
  const rad = (svar as Verifikasjon[] | null)?.[0]

  if (rad?.status === 'sperret') return { feil: sperret(rad.vent_sekunder) }
  if (!rad || rad.status !== 'ok' || !rad.ansatt_id) return { feil: AVVIST }

  // BARE ID-EN LAGRES. Navnet hentes fra basen ved hver lesing — se
  // `lesAktivAnsatt`. En kapsel skal huske et resultat, ikke bære et
  // navn systemet viser fram som om det var kontrollert.
  await settAktivAnsatt({ id: rad.ansatt_id })
  revalidatePath('/', 'layout')
  return undefined
}

export async function checkUt() {
  await fjernAktivAnsatt()
  revalidatePath('/', 'layout')
}
