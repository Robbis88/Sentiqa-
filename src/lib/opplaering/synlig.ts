// =====================================================================
// SKAL SJEKKLISTA VISES PAA NETTBRETTET NAA?
//
// `dagens.ts` svarer paa «finnes det en opplæring på denne stasjonen i
// dag?». Denne svarer på de to spørsmålene som kom etterpå:
//
//   HVEM   Er det den nyansatte som står ved nettbrettet — eller en av
//          de andre? Nettbrettet har én delt pålogging, så identiteten
//          kommer fra PIN-en. Se `lesAktivAnsatt`.
//   NAAR   Er hun på vakt nå? Skiftet bærer klokkeslettene.
//
// ---------------------------------------------------------------------
// GAMLE PERIODER ROERES IKKE
//
// `ansatt_id` kom i `0171`. En periode uten den er fra før, og den
// beholder den gamle oppførselen: synlig for stasjonen hele dagen. Å
// skjule dem ville vært en stille endring i noe som virket — en
// opplæring som plutselig ikke dukker opp ser ut som en ødelagt tablet,
// ikke som en ny regel.
//
// ---------------------------------------------------------------------
// HVORFOR EN NAADETID
//
// Man haker av ETTER at noe er lært bort, og den siste oppgaven er som
// regel den som tok lengst tid. En liste som forsvinner på minuttet
// 23:00 forsvinner midt i den siste haken.
//
// En time er ikke et tall fra ingensteds: det er lenge nok til å rydde
// og kvittere ut, og kort nok til at lista ikke står fremme på neste
// vakt. Står den her som en navngitt konstant nettopp fordi den er et
// valg noen kan være uenig i.
// =====================================================================

/** Hvor lenge lista blir stående etter at vakten er slutt. */
export const NAADETID_MIN = 60

export type Synlighet =
  | { synlig: true }
  /** Ingen har identifisert seg med PIN. Nettbrettet vet ikke hvem som står der. */
  | { synlig: false; grunn: 'ikke_identifisert' }
  /** Noen andre enn den nyansatte er på vakt. */
  | { synlig: false; grunn: 'annen_ansatt' }
  /** Vakten har ikke begynt ennå. */
  | { synlig: false; grunn: 'for_tidlig' }
  /** Vakten er over, og nådetiden med. */
  | { synlig: false; grunn: 'vakten_er_over' }

/** «HH:MM» eller «HH:MM:SS» → minutter siden midnatt. */
export function minutter(tid: string): number {
  const [t, m] = tid.split(':')
  return Number(t) * 60 + Number(m)
}

export function opplaeringSynlig(opts: {
  /** `opplaering_periode.ansatt_id`. Null = periode fra før `0171`. */
  periodeAnsattId: string | null
  /** Den som er identifisert med PIN nå, eller null. */
  aktivAnsattId: string | null
  /** Skiftets klokkeslett. Begge er null eller begge satt (skranke i `0133`). */
  startTid: string | null
  sluttTid: string | null
  /** Minutter siden midnatt, Oslo-tid. */
  naaMinutter: number
}): Synlighet {
  // Periode fra før koblingen fantes: uendret oppførsel.
  if (opts.periodeAnsattId === null) return { synlig: true }

  if (opts.aktivAnsattId === null) return { synlig: false, grunn: 'ikke_identifisert' }
  if (opts.aktivAnsattId !== opts.periodeAnsattId) return { synlig: false, grunn: 'annen_ansatt' }

  // Skift uten klokkeslett setter ingen grense. Å finne på en ville vært
  // å oppgi en vakt butikksjefen ikke har lagt inn.
  if (opts.startTid === null || opts.sluttTid === null) return { synlig: true }

  const start = minutter(opts.startTid)
  const slutt = minutter(opts.sluttTid)
  if (opts.naaMinutter < start) return { synlig: false, grunn: 'for_tidlig' }
  if (opts.naaMinutter > slutt + NAADETID_MIN) return { synlig: false, grunn: 'vakten_er_over' }
  return { synlig: true }
}

/** Én setning til nettbrettet, så en tom skjerm aldri ser ut som en feil. */
export function forklaring(s: Synlighet, navn: string, tidsrom: string | null): string | null {
  if (s.synlig) return null
  switch (s.grunn) {
    case 'ikke_identifisert':
      return 'Logg inn med PIN for å se opplæringen din.'
    case 'annen_ansatt':
      return `${navn} har opplæring i dag. Lista vises når hun logger inn med sin PIN.`
    case 'for_tidlig':
      return tidsrom ? `Opplæringen til ${navn} vises fra ${tidsrom}.` : `Opplæringen til ${navn} har ikke begynt.`
    case 'vakten_er_over':
      return `Vakten er over. Opplæringen til ${navn} vises igjen neste oppsatte dag.`
  }
}
