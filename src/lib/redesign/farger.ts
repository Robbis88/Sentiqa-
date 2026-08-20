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

// =====================================================================
// Kontrast.
//
// HVORFOR DETTE MAA MAALES DETERMINISTISK: axe i jsdom regner ikke
// kontrast - det krever layout, altsaa en ekte nettleser - og axe i
// nettleseren ser bare de flatene testdataene faktisk framkaller. Et
// signal paa rod tone finnes ikke paa en side der ingenting er kritisk.
//
// Derfor stod `.sq-signal-tekst p` med `--tekst-svak` fra primitiven ble
// skrevet til bolge 4B.1: 4,76:1 paa hvitt (bestaatt, saa vidt), men
// 3,94-4,15 paa de tre tonene under. Alle signaler i hele systemet, i
// maanedsvis, uten at noen vakt saa det.
//
// Formelen er WCAG 2.1 sin relative luminans. Den maaler bare farge -
// ikke storrelse, ikke vekt, ikke gjennomsiktighet. Legger noen en
// halvgjennomsiktig flate oppa, lyver den; da hjelper bare nettleseren.
// =====================================================================

/** Relativ luminans etter WCAG 2.1, av `#rrggbb`. */
function luminans(hex: string): number {
  const k = hex.replace('#', '')
  const kanal = [0, 2, 4]
    .map((i) => parseInt(k.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * kanal[0] + 0.7152 * kanal[1] + 0.0722 * kanal[2]
}

/** Kontrastforholdet mellom to farger, 1–21. Rekkefolgen er likegyldig. */
export function kontrast(a: string, b: string): number {
  const [ly, mork] = [luminans(a), luminans(b)].sort((x, y) => y - x)
  return (ly + 0.05) / (mork + 0.05)
}

/**
 * Tokenene slik de er definert i `:root`.
 *
 * BARE FORSTE DEFINISJON TELLER, som i tokens.test.ts. Nettbrettet
 * skriver om de samme navnene inne i `.tablet` - `--rod` blir
 * `--natt-rod` der - og en siste-vinner-lesning ville faatt
 * kontrastvakten til aa maale nattens roede mot dagens lyse tone. Et
 * par ingen har, altsaa, mens paret alle ser sto umaalt.
 */
export function tokenverdier(css: string): Record<string, string> {
  const ut: Record<string, string> = {}
  for (const [, navn, verdi] of css.matchAll(/(--[a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{6})\s*;/g)) {
    if (!(navn in ut)) ut[navn] = verdi
  }
  return ut
}
