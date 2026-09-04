// =====================================================================
// Ukebriefen — typene.
//
// Dette er IKKE en ny motor. `signaler.ts` rangerer allerede etter alvor,
// konsekvens og varighet, og vet at en kategori som faller sammen med
// butikken er vær og ikke ledelse. Briefen legger til tre felt motoren
// ikke har trengt før, fordi den vises på en skjerm der noen står ved
// siden av og kan moderere seg selv:
//
//   GRUNNLAG  Et brev som sender seg selv mandag morgen har ingen til å
//             ta forbehold for seg. Forbeholdet må derfor ligge i DATAENE
//             og ikke i formuleringen — ellers er det opp til hvem som
//             skrev setningen om systemet lyver.
//   RETNING   Motoren leter etter avvik, og avvik er som regel dårlig
//             nytt. En brief som bare er dårlig nytt blir ikke lest to
//             ganger.
//   HANDLING  Festet til signalet sitt. Ingen anbefaling kan oppstå uten
//             et tall bak seg.
// =====================================================================

import type { RaaSignal, Signal } from '@/lib/signaler'
import type { Skjemabilde } from './skjema'

/**
 * Hvor sikkert er dette?
 *
 * Rekkefølgen er ikke tilfeldig — den er fallende sikkerhet, og brukes til
 * å sortere når to signaler ellers er like sterke.
 */
export type Grunnlag =
  /** Avlest av et tall vi har. «Omsetningen var 412 000 kr.» */
  | 'fakta'
  /** Avledet av tall vi har, men gjennom en fordeling eller et anslag. */
  | 'indikasjon'
  /** En forklaring som passer tallene. Kan være feil. «Kan ha gått tom.» */
  | 'hypotese'
  /** Vi kan ikke svare. Skal ALDRI presenteres som et av de tre over. */
  | 'mangler_data'

export type Retning = 'bra' | 'darlig'

export type Briefsignal = RaaSignal & {
  grunnlag: Grunnlag
  retning: Retning
  /** Hva sjefen kan gjøre med det. Uten denne blir signalet vist, men
      foreslår ingenting — som er riktig for det vi bare har observert. */
  handling?: string
}

export type Rangert = Briefsignal & Pick<Signal, 'poeng'>

export type Handling = {
  tekst: string
  /** `id` på signalet den kommer fra. Gjør at ingen anbefaling kan stå
      alene i brevet uten at tallet bak den også står der. */
  fraSignal: string
}

/** Det briefen får inn. Alt er allerede hentet — funksjonen som bygger
    briefen rører verken database eller klokke. */
export type Ukedata = {
  stasjonNavn: string
  /** Mandagen i uken briefen gjelder, ISO. */
  ukeMandag: string
  omsetning: number
  omsetningIfjor: number
  /** Ukens andel av månedens BP, summert fra dagsfordelingen. `null` når
      det ikke finnes BP for perioden — da skal briefen tie om BP. */
  bpUke: number | null
  avdelinger: { kode: string; navn: string; omsetning: number; ifjor: number; vekstPst: number }[]
  utsolgt: { navn: string; taptKr: number; dager: number }[]
  /** `null` = ikke målt denne uken. Ikke det samme som 100 % treff. */
  treff: { antall: number; snittTreffPst: number } | null
  timer: { brukt: number; ukesramme: number | null }
  tilbakemeldinger: { antall: number; ulest: number; harAlvorlig: boolean }
  /** Rutiner og sjekkpunkter, hver med sine sju dager. Tom liste betyr
      at stasjonen ikke har satt opp noen — ikke at ingenting ble gjort. */
  skjema: Skjemabilde[]
  /** «Nei» paa et sjekkpunkt merket kritisk. Et tall, aldri spoersmaalet:
      det kan gjelde noe som ikke hoerer hjemme i en innboks. */
  kritiskeNei: number
  /** Kilder med hull i uken. Blir til «hva vi ikke vet». */
  hull: { kilde: string; dagerMangler: number }[]
  /**
   * Siste dato i uken med salg, eller null. Brukes IKKE av brevet — den
   * finnes for at utsendingen skal kunne vente paa soendagsfila i stedet
   * for aa sende seks dager som om det var sju. Se `klar.ts`.
   */
  sisteDagMedSalg: string | null
}

export type Ukebrief = {
  stasjonNavn: string
  ukeMandag: string
  ukenummer: number
  overskrift: string
  /** Én setning, skrevet ut fra tallene. Aldri av en modell. */
  ingress: string
  bra: Rangert[]
  oppmerksomhet: Rangert[]
  handlinger: Handling[]
  /** Ukedagsraden. Staar som egen del i brevet og ikke inni et signal:
      den svarer paa «hvilken dag», og det er et annet spoersmaal enn
      «hva gikk galt». */
  skjema: Skjemabilde[]
  viIkkeVet: string[]
}
