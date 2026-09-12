// Løftestengene en butikksjef faktisk rår over — og de som bare ser sånn ut.
//
// =====================================================================
// SPAK, FØLGE ELLER FAST
// =====================================================================
//
// En kostnadslinje som ligger over budsjett er ikke det samme som en
// kostnad noen kan gjøre noe med. Tre klasser:
//
//   SPAK    butikksjefen bestemmer. Timer, forbruksvarer, kassediff.
//   FØLGE   faller ut av noe annet. Pensjon følger lønna; WashTec følger
//           vaskemaskinen.
//   FAST    avtale. Leasing, forsikring, henting av kontanter.
//
// **Bare spaker blir tiltak.** Følger forklares, aldri bes om.
//
// Regelen kom av et konkret svar fra Kelsar: `590 Andre personal` er
// 74 % OTP og AFP. En plan som ba butikksjefen «få ned 590» ville bedt
// dem redusere pensjonsinnbetaling. Det er ikke et tiltak, det er tull —
// og det er nøyaktig hva et system genererer når det bare ser at en linje
// ligger over budsjett.
//
// ---------------------------------------------------------------------
// OG KLASSEN SITTER PÅ LEVERANDØREN, IKKE PÅ KODEN
//
// `634 Rep & vedlikehold` er 82 % WashTec på stasjonene med vask — altså
// maskinen, ikke butikksjefens valg. På Dale, som ikke har vask, er den
// null WashTec: der er den kjøleanlegg og bygg, og dermed en spak.
//
// Klassen for en driftslinje avgjøres derfor av `bilagssum`, ikke her.
// Denne fila bærer løftestengene som gjelder uansett stasjon.
//
// ---------------------------------------------------------------------
// LØNN VISES SAMLET. ALLTID.
//
// Robert, 2026-09-11: «butikksjefene skal aldri se noe annet enn total
// lønnsbudsjett. aldri budsjett på fastlønn osv.»
//
// `regnskap-tilgang.ts` samler allerede personal til én linje. En
// generert plan må respektere det samme — og fristelsen er reell, for
// timelønn ER den ekte løftestangen i lønna og ville gitt et skarpere
// tiltak. Skarpere og forbudt.

export type Klasse = 'spak' | 'folge' | 'fast'

export type LoftestangId =
  | 'omsetning'
  | 'matkast'
  | 'usynlig_rest'
  | 'personal'
  | 'paavirkbar_drift'

export type Loftestang = {
  id: LoftestangId
  navn: string
  /** Veien som er ønsket. */
  god: 'opp' | 'ned'
  klasse: Klasse
  /**
   * Hva en forbedring her er: mer omsetning, eller mer margin på samme
   * omsetning? Avgjør om royalty tar noe av gevinsten.
   *
   * Se `royalty.ts`: grunnlaget er omsetning, så en svinngevinst
   * beholdes i sin helhet mens vekst betaler.
   */
  gevinst: 'margin' | 'volum'
  /** Én setning til butikksjefen om hva tallet er. */
  forklaring: string
}

export const LOFTESTENGER: readonly Loftestang[] = [
  {
    id: 'omsetning',
    navn: 'Omsetning mot budsjett',
    god: 'opp',
    klasse: 'spak',
    gevinst: 'volum',
    forklaring: 'Butikkomsetningen mot det som er budsjettert for måneden.',
  },
  {
    id: 'matkast',
    navn: 'Matkast',
    god: 'ned',
    klasse: 'spak',
    gevinst: 'margin',
    forklaring: 'Kroner kastet mat. Produksjonsplanen er verktøyet.',
  },
  {
    id: 'usynlig_rest',
    navn: 'Usynlig svinn utenom mat og vask',
    god: 'ned',
    klasse: 'spak',
    gevinst: 'margin',
    forklaring: 'Manko. Positivt tall betyr at varer mangler uten at de er ført.',
  },
  {
    id: 'personal',
    // SAMLET, og det er ikke en forenkling — det er grensen. Se toppen.
    navn: 'Personalkostnad mot budsjett',
    god: 'ned',
    klasse: 'spak',
    gevinst: 'margin',
    forklaring: 'Total lønn mot totalt lønnsbudsjett.',
  },
  {
    id: 'paavirkbar_drift',
    navn: 'Påvirkbare driftskostnader',
    god: 'ned',
    klasse: 'spak',
    gevinst: 'margin',
    forklaring: 'Renhold, renovasjon, forbruksmateriell, pengehåndtering, kassedifferanse.',
  },
] as const

export function loftestang(id: LoftestangId): Loftestang {
  const l = LOFTESTENGER.find((x) => x.id === id)
  if (!l) throw new Error(`Ukjent løftestang: ${id}`)
  return l
}

/**
 * Begrepene som utgjør «påvirkbare driftskostnader».
 *
 * Et utvalg av `BUTIKKSJEF_BEGREP`, ikke hele: leie, forsikring og
 * telefon er faste avtaler, og `rep_vedlikehold` avgjøres per stasjon av
 * hvem fakturaen kom fra — se `bilagssum`.
 */
export const DRIFT_BEGREP = [
  'renhold', 'renovasjon', 'forbruksmateriell',
  'pengehandtering', 'kontorrekvisita', 'kassedifferanse',
] as const
