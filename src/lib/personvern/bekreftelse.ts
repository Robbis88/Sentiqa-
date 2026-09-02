import 'server-only'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import type { AktivAnsatt } from '@/lib/ansatt'

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
