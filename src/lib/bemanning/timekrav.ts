// =====================================================================
// Snudd: hvor mye brutto må til for å ha råd til timene?
//
// Robert, 2026-08-22: «vi vet forventet brutto i BP i august, vi vet
// historisk brutto etter telling, regnskap kommer hver måned — vi vet
// da hvor mye vi må omsette for i brutto for å nå timebudsjettet?»
//
// Ja, og det er samme regnestykke lest fra den andre enden:
//
//   opptjente timer = ramme × (realisert brutto ÷ BP-brutto)
//
// Løser man for brutto i stedet for timer:
//
//   brutto som kreves = BP-brutto × (brukte timer ÷ ramme)
//
// HVORFOR DET ER ET BEDRE TALL. «1 745 timer over» er sant, men ikke
// noe man kan gjøre noe med etter at timene er brukt — det er en dom
// over noe som har skjedd. Snudd blir det en salgsoppgave, og midt i
// måneden er den fortsatt mulig å påvirke.
//
// Samme tall, den enden butikksjefen kan ta i.
// =====================================================================

export type Krav = {
  /** Brutto som må til for at timene skal være tjent inn. */
  bruttoKreves: number
  /** Det som mangler. Negativt = timene er allerede dekket. */
  bruttoMangler: number
  /** Omsetningen som gir den bruttoen, til realisert margin. */
  omsetningMangler: number | null
}

/**
 * Hva som skal til, i kroner.
 *
 * MARGINEN ER DEN REALISERTE, ikke kassens. Kassen sier 80 % der
 * tellingen sier 50 %, og regner man om med kassens margin, ser
 * oppgaven mindre ut enn den er. Feilen peker mot «det ordner seg»,
 * som er den dyre retningen å ta feil i.
 *
 * `null` for omsetningen når margen ikke er kjent: en oppgave i kroner
 * omsetning vi ikke kan regne ut, skal ikke gjettes.
 */
export function bruttoKrav(
  { rammeTimer, brukteTimer, bpBruttoKr, realisertBruttoKr, realisertMarginPst }: {
    rammeTimer: number | null
    brukteTimer: number | null
    bpBruttoKr: number | null
    realisertBruttoKr: number | null
    realisertMarginPst: number | null
  },
): Krav | null {
  if (!rammeTimer || rammeTimer <= 0) return null
  if (brukteTimer == null || bpBruttoKr == null || realisertBruttoKr == null) return null
  if (bpBruttoKr <= 0) return null

  const bruttoKreves = bpBruttoKr * (brukteTimer / rammeTimer)
  const bruttoMangler = bruttoKreves - realisertBruttoKr

  // Margin på 0 eller negativ gir ingen omsetning som hjelper.
  const margin = realisertMarginPst != null && realisertMarginPst > 0
    ? realisertMarginPst / 100
    : null

  return {
    bruttoKreves: Math.round(bruttoKreves),
    bruttoMangler: Math.round(bruttoMangler),
    omsetningMangler: margin ? Math.round(bruttoMangler / margin) : null,
  }
}

/**
 * Setningen butikksjefen skal lese.
 *
 * SIER DET SOM SKAL GJØRES, ikke hva som gikk galt. «284 500 kr mer i
 * brutto» er en oppgave; «1 745 timer over» er en dom over noe som
 * allerede har skjedd.
 */
export function kravtekst(k: Krav, kr: (n: number) => string): string {
  if (k.bruttoMangler <= 0) {
    return `Timene er dekket — ${kr(Math.abs(k.bruttoMangler))} mer brutto enn de krevde.`
  }
  const oms = k.omsetningMangler
    ? ` — rundt ${kr(k.omsetningMangler)} i omsetning`
    : ''
  return `${kr(k.bruttoMangler)} mer i brutto for å ha råd til timene${oms}.`
}
