// =====================================================================
// FORBEHOLD HØRER TIL EN ANALYSE, IKKE TIL EN PERIODE
// =====================================================================
//
// Juni 2026 finnes i to filversjoner. Det er lett — og galt — å si
// «juni er usikker» og sperre måneden. Vi har målt hva som faktisk
// skiller dem, og forskjellen treffer noen analyser og ikke andre:
//
//   IDENTISK   de 48 kontrollerte stasjonsfeltene. Stasjonsnivået er
//              bevist likt mellom versjonene.
//   ULIKT      pant, linje 741 og samlet resultat. Avstemt til øret mot
//              RESULTAT-linja i begge filer:
//
//                 selskap        −13 101,49
//                 4177 Lone       −7 143,80
//                 4185 Dale       −6 617,69
//                 9900 Admin        +660,00
//                 tre stasjoner       0,00
//
// Stasjonssummen treffer selskapets differanse eksakt. **Derfor er
// klyngen og kjederesultatet usikre, mens hver stasjon for seg er det
// ikke** — og en stasjonsanalyse skal ikke sperres av en konflikt på
// klyngearket.
//
// ---------------------------------------------------------------------
// HVORFOR EN TABELL OG IKKE EN IF
//
// Forbeholdet er et FUNN med en årsak og en dato, ikke en regel i koden.
// Står det som data, kan det fjernes den dagen regnskapsfører har svart
// — og det kan leses av et menneske uten å lese koden. En `if (periode
// === '2026-06-01')` gjemt i en analyse ville overlevd svaret.
// =====================================================================

/** Analysene som kan bære et forbehold. Utvides når nye kommer til. */
export type Analyse =
  | 'stasjonsanalyse'
  | 'mat_svinn_stasjon'
  | 'personalkost_stasjon'
  | 'resultat_stasjon'
  | 'klyngeanalyse'
  | 'kjederesultat'

export const ALLE_ANALYSER: readonly Analyse[] = [
  'stasjonsanalyse', 'mat_svinn_stasjon', 'personalkost_stasjon',
  'resultat_stasjon', 'klyngeanalyse', 'kjederesultat',
]

export type Forbeholdsstatus = 'ok' | 'usikker' | 'blokkert'

export type Forbehold = {
  status: Forbeholdsstatus
  /** Tom når status er `ok`. Ellers alltid utfylt. */
  aarsak: string
}

const OK: Forbehold = { status: 'ok', aarsak: '' }

type Post = {
  periode: string
  /** Bare disse analysene rammes. Resten er `ok`. */
  gjelder: readonly Analyse[]
  status: Exclude<Forbeholdsstatus, 'ok'>
  aarsak: string
  /** Hva som må skje for at posten kan fjernes. */
  loeses_av: string
}

/**
 * Kjente forbehold, med årsak og utvei.
 *
 * Hver post skal ha en `loeses_av` — et forbehold uten utvei blir
 * stående for alltid, og da slutter folk å tro på dem.
 */
export const FORBEHOLD: readonly Post[] = [
  {
    periode: '2026-06-01',
    gjelder: ['klyngeanalyse', 'kjederesultat'],
    status: 'blokkert',
    aarsak:
      'Filversjonene for juni avviker på pant, linje 741 og samlet resultat '
      + '(netto −13 101,49 mot RESULTAT-linja). De 48 kontrollerte '
      + 'stasjonsfeltene er identiske, så stasjonsnivået er upåvirket.',
    loeses_av:
      'Regnskapsfører bekrefter hvilken juniversjon som er korrekt, og om '
      + 'pant skal stå med positiv bruttofortjeneste.',
  },
]

/**
 * Har denne analysen et forbehold i denne perioden?
 *
 * Ukjent periode og ukjent analyse er `ok` — forbehold er en positiv
 * liste over det vi VET er usikkert, ikke en tvil om alt annet.
 */
export function forbehold(periode: string, analyse: Analyse): Forbehold {
  for (const p of FORBEHOLD) {
    if (p.periode !== periode) continue
    if (!p.gjelder.includes(analyse)) continue
    return { status: p.status, aarsak: p.aarsak }
  }
  return OK
}

/** Alle analyser for én periode, til en statuslinje i flaten. */
export function forbeholdForPeriode(periode: string): Record<Analyse, Forbehold> {
  return Object.fromEntries(
    ALLE_ANALYSER.map((a) => [a, forbehold(periode, a)]),
  ) as Record<Analyse, Forbehold>
}

/** Kan analysen vise et tall i det hele tatt? */
export function kanVises(periode: string, analyse: Analyse): boolean {
  return forbehold(periode, analyse).status !== 'blokkert'
}
