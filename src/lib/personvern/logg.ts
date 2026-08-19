import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'

// =====================================================================
// Hvem har sett hva om hvem.
//
// Uten dette finnes det ikke noe svar når en ansatt spør «hvem har sett
// lønna mi?». Det er et sikkerhetstiltak etter GDPR art. 32, men det er
// like mye et arbeidsmiljøtiltak: oppslag som kan spores, blir gjort med
// omhu.
//
// Vi logger MÅLRETTEDE oppslag — de som gjelder én navngitt person, og
// de som tar hele stasjonen ut av huset. Ikke hver sidevisning: en logg
// full av «butikksjefen åpnet /lonn» skjuler den ene raden som betyr
// noe.
// =====================================================================

export type Handling =
  | 'innsyn'              // full utskrift etter art. 15
  | 'kontrakt_vist'
  | 'kontrakt_lastet_ned'
  | 'kontrakt_generert'
  | 'signert_lastet_ned'
  | 'lonnsfil_lastet_ned' // hele stasjonen, ikke én person
  | 'persondata_slettet'
  // Butikksjefen har endret noens stemplinger. Stemplingen er
  // regnskapsdokumentasjon når den er kilden til lønn, og da skal det
  // stå hvem som rettet hva — også i HENNES logg, ikke bare i
  // hendelsestabellen. Hun skal kunne se at noen rørte timene hennes
  // uten å måtte be om innsyn i en tabell hun ikke vet finnes.
  | 'stempling_rettet'

export const HANDLING_TEKST: Record<Handling, string> = {
  innsyn: 'Tok ut innsynsutskrift',
  kontrakt_vist: 'Åpnet arbeidsavtale',
  kontrakt_lastet_ned: 'Lastet ned arbeidsavtale',
  kontrakt_generert: 'Skrev ny arbeidsavtale',
  signert_lastet_ned: 'Lastet ned signert avtale',
  lonnsfil_lastet_ned: 'Lastet ned lønnsfil for stasjonen',
  persondata_slettet: 'Slettet persondata',
  stempling_rettet: 'Rettet en stempling',
}

export type Oppslag = {
  retailerId: string
  stasjonId: string | null
  ansattNr?: string | null
  ansattNavn?: string | null
  handling: Handling
  brukerId: string
  brukerNavn?: string | null
  detaljer?: Record<string, unknown>
}

/**
 * Skriver én linje i tilgangsloggen.
 *
 * Feiler skrivingen, stopper vi IKKE handlingen. Det er et bevisst valg
 * med en ubehagelig side: en lønnsfil som ikke lot seg logge, blir
 * likevel lastet ned. Alternativet — å nekte butikksjefen å levere lønn
 * fordi en logglinje feilet — er verre, og ville gjort loggen til noe
 * folk ba om å få skrudd av.
 *
 * Feilen havner i serverloggen, som dreneres til driftsovervåkingen.
 */
export async function loggOppslag(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: SupabaseClient<any, any, any>,
  o: Oppslag,
): Promise<void> {
  const { error } = await supabase.from('persondata_logg').insert({
    retailer_id: o.retailerId,
    stasjon_id: o.stasjonId,
    ansatt_nr: o.ansattNr ?? null,
    ansatt_navn: o.ansattNavn ?? null,
    handling: o.handling,
    bruker_id: o.brukerId,
    bruker_navn: o.brukerNavn ?? null,
    detaljer: o.detaljer ?? {},
  })
  if (error) console.error('persondata_logg feilet:', error.message, o.handling)
}
