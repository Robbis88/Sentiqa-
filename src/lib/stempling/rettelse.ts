import { LANG_VAKT_TIMER } from './tilstand'

// =====================================================================
// Reglene for å rette en stempling.
//
// SPORBARHET, IKKE OVERSKRIVING. Stemplingen er regnskapsdokumentasjon
// etter at den er kilden til lønn, og bokføringsloven krever at en
// rettet post viser hva som sto der før, hvem som endret den og når.
// Derfor gjør systemet aldri `update ... set tidspunkt`:
//
//   Lukke en glemt utstempling → ny hendelse, kilde 'korreksjon'.
//     Ingenting forfalskes; vi legger til det som mangler, merket med
//     at et menneske oppga tiden.
//   Feilstempling → `annullert_tid` settes. Raden blir stående.
//
// BEGRUNNELSE ER PÅKREVD. Ikke som formalitet: den som ser
// lønnsgrunnlaget et halvt år senere skal kunne se forskjell på «glemte
// å stemple ut, ringte og oppga 22:00» og «systemet var nede».
// =====================================================================

export type Rettelsesfeil =
  | 'mangler_tid'
  | 'for_tidlig'
  | 'i_framtiden'
  | 'for_lang'
  | 'mangler_begrunnelse'
  | 'kort_begrunnelse'

/** Minste begrunnelse vi godtar. Kort nok til å skrives, lang nok til å bety noe. */
export const MIN_BEGRUNNELSE = 5

export const FEILTEKST: Record<Rettelsesfeil, string> = {
  mangler_tid: 'Velg tidspunktet hun gikk.',
  for_tidlig: 'Tidspunktet må være etter at hun stemplet inn.',
  i_framtiden: 'Tidspunktet kan ikke være fram i tid.',
  for_lang: `Det blir over ${LANG_VAKT_TIMER} timer. Sjekk datoen — `
    + 'en vakt så lang er ikke lovlig, så det er nesten alltid feil dag.',
  mangler_begrunnelse: 'Skriv hvorfor. Det står i lønnsgrunnlaget.',
  kort_begrunnelse: 'Skriv litt mer — «glemte å stemple ut» holder.',
}

export type Lukking = {
  /** ISO-tidspunkt for innstemplingen som mangler en ut. */
  inn: string
  /** ISO-tidspunkt oppgitt av butikksjefen. */
  ut: string
  begrunnelse: string
}

/**
 * Kan denne utstemplingen registreres?
 *
 * Returnerer alle feilene, ikke bare den første: butikksjefen skal ikke
 * måtte trykke fire ganger for å få vite fire ting.
 */
export function vurderLukking(l: Lukking, naa: Date): Rettelsesfeil[] {
  const feil: Rettelsesfeil[] = []

  const ut = Date.parse(l.ut)
  if (!l.ut || Number.isNaN(ut)) {
    feil.push('mangler_tid')
  } else {
    const inn = Date.parse(l.inn)
    if (ut <= inn) feil.push('for_tidlig')
    // Litt slingringsmonn: klokka på nettbrettet og på serveren er ikke
    // synkrone på sekundet, og et avvist «nå» ville vært uforståelig.
    else if (ut > naa.getTime() + 60_000) feil.push('i_framtiden')
    else if ((ut - inn) / 3_600_000 > LANG_VAKT_TIMER) feil.push('for_lang')
  }

  const b = l.begrunnelse.trim()
  if (b.length === 0) feil.push('mangler_begrunnelse')
  else if (b.length < MIN_BEGRUNNELSE) feil.push('kort_begrunnelse')

  return feil
}

/**
 * Kan denne hendelsen annulleres?
 *
 * Annullering krever bare en begrunnelse — tidspunktet er allerede
 * lagret, og det er nettopp det vi sier at ikke skal telle.
 */
export function vurderAnnullering(begrunnelse: string): Rettelsesfeil[] {
  const b = begrunnelse.trim()
  if (b.length === 0) return ['mangler_begrunnelse']
  if (b.length < MIN_BEGRUNNELSE) return ['kort_begrunnelse']
  return []
}

/**
 * `2026-08-19` + `22:00` → ISO-tidspunkt i norsk tid.
 *
 * Skjemaet gir dato og klokkeslett hver for seg, slik nettleseren gjør
 * det. Uten sonen ville `new Date('2026-08-19T22:00')` blitt tolket i
 * serverens sone — som på Vercel er UTC, altså to timer feil om
 * sommeren. Det er nøyaktig den typen feil som ikke merkes før noen
 * teller timer.
 */
export function iNorskTid(dato: string, klokke: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dato) || !/^\d{2}:\d{2}$/.test(klokke)) return null

  // Finner forskyvningen ved å spørre hva UTC-tidspunktet heter i Oslo,
  // og justere til det stemmer. To runder holder over et soneskifte.
  let gjett = Date.parse(`${dato}T${klokke}:00Z`)
  if (Number.isNaN(gjett)) return null
  for (let i = 0; i < 2; i++) {
    const iOslo = new Intl.DateTimeFormat('sv-SE', {
      timeZone: 'Europe/Oslo', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hour12: false,
    }).format(new Date(gjett))
    const [d, t] = iOslo.split(' ')
    const avvik = Date.parse(`${d}T${t}:00Z`) - Date.parse(`${dato}T${klokke}:00Z`)
    if (avvik === 0) break
    gjett -= avvik
  }
  return new Date(gjett).toISOString()
}
