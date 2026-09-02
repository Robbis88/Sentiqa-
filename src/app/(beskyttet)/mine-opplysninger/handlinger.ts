'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { lesAktivAnsatt } from '@/lib/ansatt'
import { KONTROLLTILTAK_VERSJON } from '@/lib/personvern/kontrolltiltak'
import { DUBLETT } from '@/lib/db-koder'
import { skrivBekreftelse } from '@/lib/personvern/bekreftelse'

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

  // På nettbrettet er det den som står på vakt som bekrefter, ikke
  // enheten. Uten det ville én bekreftelse dekket hele stasjonen.
  // `lesAktivAnsatt` slår opp vakta i basen ved hver lesing, så en
  // skrevet informasjonskapsel kan ikke bekrefte på andres vegne.
  const ansatt = bruker.rolle === 'butikkbruker_tablet' ? await lesAktivAnsatt(supabase) : null
  if (bruker.rolle === 'butikkbruker_tablet' && !ansatt) {
    return { feil: 'Start vakt med ansattnummer og PIN først.' }
  }

  // Stasjonen slås opp, for vaktkapselen bærer bare en ansatt-ID.
  // Null er greit: bekreftelsen gjelder personen, ikke stedet.
  const { data: rad } = ansatt
    ? await supabase.from('ansatte').select('stasjon_id').is('slettet_tid', null).eq('id', ansatt.id)
      .maybeSingle<{ stasjon_id: string }>()
    : { data: null }

  // TO VEIER, FORDI DE TO IDENTITETENE ER ULIKE (0168).
  //
  // Nettbrettet skrev foer sin rad gjennom RLS, og policyen tillot da
  // `ansatt_id` for HVILKEN SOM HELST ansatt paa stasjonen - appen
  // skriver alltid kapselens egen id, men RLS avgjoer hva som ER mulig.
  // En § 9-2-bekreftelse er dokumentasjon paa at en navngitt person er
  // informert; skrives den for feil person, dokumenterer den noe som
  // ikke har skjedd.
  //
  // En RPC loeser det ikke: den ser like lite av vaktkapselen som RLS.
  // Serveren ser den - `lesAktivAnsatt` har signatur OG oppslag gjennom
  // nettbrettets egen RLS - saa raden skrives der, med den identiteten.
  if (ansatt) {
    const svar = await skrivBekreftelse(
      ansatt, bruker.retailerId, rad?.stasjon_id ?? null, KONTROLLTILTAK_VERSJON,
    )
    if (svar.slag === 'feil') return { feil: svar.melding }
    return { ok: svar.slag === 'fantes' ? 'Du har bekreftet denne versjonen fra før' : 'Takk — registrert' }
  }

  // Den innloggede skriver som seg selv, gjennom RLS. `kontrolltiltak_ins`
  // krever naa `bruker_id = auth.uid()` og lederrolle - hun er begge.
  const { error } = await supabase.from('kontrolltiltak_bekreftelse').insert({
    retailer_id: bruker.retailerId,
    stasjon_id: null,
    ansatt_id: null,
    bruker_id: bruker.id,
    versjon: KONTROLLTILTAK_VERSJON,
  })

  // EN KVITTERING SKAL SI HVA SOM FAKTISK SKJEDDE.
  //
  // Har hun bekreftet før, finnes raden alt — de unike indeksene i `0103`
  // er `(ansatt_id, versjon)` og `(bruker_id, versjon)`. Det er ikke en
  // feil, men det er heller ikke en ny registrering, og «Takk —
  // registrert» var derfor et svar systemet ikke hadde dekning for.
  //
  // Det er ikke en teoretisk forskjell på nettbrettet: lesepolicyen i
  // `0147` slipper ikke nettbrettet til på sine egne rader (den matcher
  // `bruker_id`, nettbrettet skriver `ansatt_id`), så siden spør HVER
  // gang — og fikk «registrert» hver gang uten at noe ble skrevet.
  //
  // KODEN, IKKE MELDINGSTEKSTEN. `error.message.includes('duplicate')`
  // sto her, og den er engelsk PostgREST-prosa som kan endres uten
  // varsel. Blir den det, får den ansatte en rå databasefeil i ansiktet
  // på en helt normal handling. `23505` er unique_violation i Postgres og
  // endrer seg ikke.
  if (error) {
    if (error.code !== DUBLETT) return { feil: error.message }
    return { ok: 'Du har bekreftet denne versjonen fra før' }
  }

  return { ok: 'Takk — registrert' }
}
