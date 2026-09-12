// =====================================================================
// PARSERVERSJON: ET NAVN, IKKE ET TIDSPUNKT
// =====================================================================
//
// `0209` la kolonnen `import_jobber.parserversjon` fordi samme fil med
// ulik parser gir ulikt radantall — januarfila ga 324 rader i juni og
// 384 i september. Uten feltet ser det ut som to ulike filer.
//
// Kolonnen har stått `null` siden, fordi ingen skrev den. Fra og med
// nivåmodellen skal hver ny jobb bære et navn.
//
// **Navn, ikke tidsstempel og ikke hash.** Et tidspunkt sier når koden
// kjørte, ikke hva den gjorde — to jobber fra samme parser ville fått
// ulike verdier, og «hvilke jobber har den nye modellen?» blir
// uleselig. En hash av kilden endrer seg av en kommentar. Navnet endres
// bare når PARSEREN endrer betydning, og det er nettopp det spørsmålet
// feltet skal svare på.
//
// Regelen for å bumpe: **endres radsettet en gitt fil gir, endres
// navnet.** Nye kolonner på eksisterende rader er ikke nok; nye eller
// færre RADER er.
//
//   svinn-nivaa-1   parseren fra 0208/0210: begge nivåer, alle 14
//                   feltene, analyseområde utledet av arket, og uten de
//                   to filtrene som mistet økonomiske verdier
//   null            alle jobber fra før dette. Eldre parsergrunnlag —
//                   de kan ikke avstemmes mot identiteten, fordi
//                   teoretisk BF aldri ble lagret.
// =====================================================================

export const PARSERVERSJON = 'svinn-nivaa-1'

/** Er jobben parset med en versjon som kjenner nivåmodellen? */
export function kjennerNivaamodellen(parserversjon: string | null): boolean {
  return parserversjon === PARSERVERSJON
}

/** Menneskelesbar merkelapp for en jobb, til rapporter og flater. */
export function parsergrunnlag(parserversjon: string | null): string {
  return parserversjon == null ? 'eldre parsergrunnlag' : parserversjon
}
