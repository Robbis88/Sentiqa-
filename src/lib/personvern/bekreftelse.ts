import 'server-only'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import type { AktivAnsatt } from '@/lib/ansatt'
import { DUBLETT } from '@/lib/db-koder'

// =====================================================================
// NETTBRETTET SKAL SE SIN EGEN BEKREFTELSE
//
// Det kunne det ikke. Nettbrettet skriver `ansatt_id` med `bruker_id =
// null` (0145), og ingen av de tre grenene i lesepolicyen (`0147`)
// treffer da: egen-grenen matcher `bruker_id`, de to andre krever
// lederrolle. Følgen var at `/mine-opplysninger` spurte hver gang, og at
// hver gjentatt bekreftelse ble avvist av den unike indeksen.
//
// HVORFOR IKKE EN POLICYGREN
//
// Den smaleste greia RLS kan uttrykke er «ansatt ved en av mine
// stasjoner» — og det lar nettbrettet lese kollegenes
// bekreftelsesstatus. Behovet er én person: den som står på vakt.
//
// Grunnen til at RLS ikke kommer nærmere: `checkInn` setter en signert
// kapsel og etterlater INGEN rad i basen, så databasen har ingen måte å
// vite hvem som står på nettbrettet nå.
//
// DERFOR SERVEREN, MED EN IDENTITET DEN ALT HAR BEVIST
//
// `lesAktivAnsatt` har to låser som begge må åpne: signaturen beviser at
// noen tastet nummer og PIN, og oppslaget beviser at identiteten fortsatt
// gjelder — og det oppslaget går gjennom nettbrettets EGEN RLS, altså
// `mine_stasjoner()`. En `AktivAnsatt` kan derfor ikke være en ansatt ved
// en annen stasjon eller i en annen kjede.
//
// Det er nøyaktig den tilliten skrivepåstanden alt hviler på
// (`bekreftLest` skriver `ansatt_id` fra samme kilde). Lesingen var det
// eneste stedet som krevde et bevis databasen ikke kan se.
//
// FLATEN ER TO KOLONNER OG ÉN PERSON. Ingenting av dette er nåbart over
// PostgREST — det finnes ingen ny policy, ingen ny RPC og ingen ny
// rettighet. Kjeden står som andre lås, av samme grunn som i
// `lesAktivAnsatt`: to lag som må svikte samtidig.
// =====================================================================

export type Bekreftelse = { versjon: string; bekreftetTid: string }

/** Bare det siden spør om: har denne personen bekreftet, og når. */
const KOLONNER = 'versjon, bekreftet_tid'

type Klient = { from: (t: string) => any } // eslint-disable-line @typescript-eslint/no-explicit-any

/**
 * Siste bekreftelse for den som står på vakt.
 *
 * `ansatt` må komme fra `lesAktivAnsatt` — typen finnes for å gjøre det
 * vanskelig å sende inn en id fra en forespørsel. Kommer den derfra, er
 * den PIN-bevist og stasjonsavgrenset før den når hit.
 *
 * `klient` er til for testen. Utelates den, lages admin-klienten her.
 */
export async function sisteBekreftelse(
  ansatt: AktivAnsatt,
  retailerId: string,
  klient?: Klient,
): Promise<Bekreftelse | null> {
  // FEILER LUKKET. Mangler tjenestenøkkelen, vet vi ikke om hun har
  // bekreftet — og da skal hun spørres, ikke slippes forbi. Det er
  // samme retning som `vaktnokkel()` i `lesAktivAnsatt`.
  let db: Klient
  try {
    db = klient ?? lagSupabaseAdminKlient()
  } catch {
    return null
  }

  const { data } = await db
    .from('kontrolltiltak_bekreftelse')
    .select(KOLONNER)
    .eq('ansatt_id', ansatt.id)
    .eq('retailer_id', retailerId)
    .order('bekreftet_tid', { ascending: false })
    .limit(1)
    .maybeSingle()

  const rad = data as { versjon: string; bekreftet_tid: string } | null
  return rad ? { versjon: rad.versjon, bekreftetTid: rad.bekreftet_tid } : null
}

export type Skriveresultat =
  | { slag: 'ny' }
  | { slag: 'fantes' }
  | { slag: 'feil'; melding: string }

/**
 * Skriver bekreftelsen for den som står på vakt.
 *
 * SPEILBILDET AV LESINGEN OVER, OG AV SAMME GRUNN. `kontrolltiltak_ins`
 * tillot før en nettbrettsesjon å skrive en § 9-2-bekreftelse for
 * hvilken som helst ansatt på sin stasjon. En bekreftelse er
 * dokumentasjon på at en navngitt person ER informert; skrives den for
 * feil person, dokumenterer den noe som ikke har skjedd.
 *
 * En RPC ville ikke løst det: `security definer` ser like lite av
 * vaktkapselen som RLS gjør, og måtte tatt id-en fra kalleren.
 *
 * INGENTING HER KOMMER FRA FORESPØRSELEN. `ansatt` er PIN-bevist,
 * `stasjonId` er slått opp gjennom nettbrettets egen RLS, og `versjon`
 * er en serverkonstant. Det er hele grunnen til at tjenestenøkkelen er
 * forsvarlig her — se regelen i `admin.ts`.
 */
export async function skrivBekreftelse(
  ansatt: AktivAnsatt,
  retailerId: string,
  stasjonId: string | null,
  versjon: string,
  klient?: Klient,
): Promise<Skriveresultat> {
  // FEILER LUKKET, OG SIER FRA. Mangler tjenestenøkkelen, ble ingenting
  // skrevet — og da skal hun ikke få «Takk, registrert». Se `bekreftLest`.
  let db: Klient
  try {
    db = klient ?? lagSupabaseAdminKlient()
  } catch {
    return { slag: 'feil', melding: 'Kunne ikke registrere bekreftelsen. Si fra til butikksjefen.' }
  }

  const { error } = await db.from('kontrolltiltak_bekreftelse').insert({
    retailer_id: retailerId,
    stasjon_id: stasjonId,
    ansatt_id: ansatt.id,
    // ALLTID NULL. Nettbrettets konto er en enhet, ikke personen som
    // bekrefter. Settes den, ville én rad dekket hele stasjonen.
    bruker_id: null,
    versjon,
  })

  if (!error) return { slag: 'ny' }
  // Den unike indeksen `(ansatt_id, versjon)` fra 0103. Ikke en feil,
  // men heller ikke en ny registrering — og de to skal ikke kvitteres likt.
  if (error.code === DUBLETT) return { slag: 'fantes' }
  return { slag: 'feil', melding: error.message }
}
