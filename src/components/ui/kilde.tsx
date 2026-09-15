import type { Kilde } from '@/lib/okonomi/bilde'

// =====================================================================
// KILDEMERKET: HVOR SIKKERT ETT TALL ER
// =====================================================================
//
// REN VISNING. Komponenten utleder ingenting. `byggOkonomibilde` har
// alt bestemt kilden — lov 3 sier at den følger med ut, og at flaten
// aldri skal regne den selv. Sto det en `if` her om når noe er en
// prognose, ville vi hatt to svar på samme spørsmål.
//
// ---------------------------------------------------------------------
// FASIT ER FARGELØS, OG DET ER MED VILJE
// ---------------------------------------------------------------------
//
// Farge er et budsjett. Fasit er NORMALTILSTANDEN — det er ingen god
// nyhet at et tall er avstemt, det er utgangspunktet. Får hver avstemt
// linje et grønt merke, er det ingenting igjen å bruke den dagen et
// tall faktisk er usikkert.
//
// Samme valg som `Status`: «aktiv» på en ansattliste er normal, ikke
// suksess.
//
// ---------------------------------------------------------------------
// «SKJULT» ER IKKE EN SVAKERE KILDE
// ---------------------------------------------------------------------
//
// De fire andre svarer på «hvor sikre er vi». `skjult` svarer på «er
// dette ditt å se», og den skal ikke se ut som en mangel — da leser
// butikksjefen det som at systemet har et hull, og spør etter et tall
// ingen kommer til å gi henne.
// =====================================================================

/** Ordet på merket. Kort nok til å stå etter et tall. */
const ORD: Record<Kilde, string> = {
  fasit: 'Fasit',
  prognose: 'Prognose',
  plan: 'Plan',
  mangler: 'Mangler',
  skjult: 'Skjult',
}

/**
 * Hele setningen, for den som trenger den.
 *
 * STÅR SOM `title` OG SOM `aria-label`. Et merke som bare sier
 * «Prognose» forutsetter at leseren kjenner ordboka vår; den som ikke
 * gjør det, får ingen vei inn.
 */
const FORKLARING: Record<Kilde, string> = {
  fasit: 'Lest av regnskapet. Avstemt.',
  prognose: 'Anslått av tidlige data. Kan flytte seg.',
  plan: 'Hva budsjettet sa. Ikke et anslag på hva som skjer.',
  mangler: 'Tallet finnes ikke ennå.',
  skjult: 'Finnes, men vises ikke for din rolle.',
}

export function Kildemerke({ kilde }: { kilde: Kilde }) {
  return (
    <span
      className={`sq-kilde sq-kilde-${kilde}`}
      title={FORKLARING[kilde]}
      aria-label={`${ORD[kilde]}. ${FORKLARING[kilde]}`}
    >
      {ORD[kilde]}
    </span>
  )
}
