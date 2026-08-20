// =====================================================================
// Fargevakten.
//
// Design-skrallen teller allerede `#rrggbb` i .tsx. Den ser ikke CSS, og
// den ser ingen av de andre skrivemåtene. Det hullet var ikke teoretisk:
// etter palettbyttet i trinn 01 stod `button:hover` og `.ai-fab` igjen
// med BLÅ skygger — `rgba(37,99,235,…)` skrevet rett inn i regler — på
// flater som nå var grønne. Tokenvakten så dem ikke, fordi den bare
// leser `:root`. Design-skrallen så dem ikke, fordi de ikke er hex og
// ikke står i .tsx.
//
// TOKENDEFINISJONENE ER IKKE GJELD. En linje som definerer `--primaer`
// SKAL inneholde en farge; det er hele poenget med et token. Derfor
// hoppes deklarasjoner av egendefinerte egenskaper over. Alt annet
// telles: en farge midt i en regel er en farge som ikke kan endres per
// kjede.
//
// SKRALLE, IKKE PORT. Tallet står i tresifret område i dag. En port
// hadde vært rød fra dag én, og en rød port som ikke kan bli grønn blir
// skrudd av innen uka.
// =====================================================================

import { utenKommentarer } from './design'

/**
 * De fire skrivemåtene som faktisk finnes i dette repoet.
 *
 * `currentColor`, `transparent` og `inherit` er ikke farger i denne
 * forstand — de arver, og det er nettopp det vi vil ha.
 */
const FARGE = /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?)\s*\(/g

/**
 * Linjer som definerer et token.
 *
 * `--primaer: #2e7d6b;` er stedet fargen SKAL stå. Alt annet er et sted
 * den ikke kan endres fra.
 */
const TOKENLINJE = /^\s*--[a-z0-9-]+\s*:/i

/**
 * Filer som får ha farger, med grunn.
 *
 * Ikke en samlepost for det som er vanskelig — hver linje her er en
 * beslutning om at fargen hører hjemme akkurat der.
 */
export const UNNTAK: Record<string, string> = {
  // Landingssida er en egen visuell verden utenfor produktets
  // designsystem (mønsteret 'utenfor'). Den har sine egne variabler og
  // skal ikke tvinges inn i Sentiqa-paletten — det er en markedsside,
  // ikke en arbeidsflate.
  'components/lp/lp.css': 'egen visuell verden, mønsteret utenfor',
}

export function tellFarger(kilde: string): number {
  return utenKommentarer(kilde)
    .split('\n')
    .filter((l) => !TOKENLINJE.test(l))
    .reduce((sum, l) => sum + (l.match(FARGE) ?? []).length, 0)
}
