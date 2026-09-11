// Hva en forbedring er verdt, etter royalty.
//
// =====================================================================
// GRUNNLAGET ER OMSETNING, IKKE MARGIN
// =====================================================================
//
// Dette er hele regelen, og alt annet i fila følger av den.
//
// St1 tar royalty av OMSETNINGEN. Selger du like mye og mister mindre på
// veien, øker ikke omsetningen — og da øker ikke royaltyen heller.
// **Hele svinngevinsten blir værende hos deg.** Bare vekst betaler, fordi
// bare vekst gir mer omsetning å regne den av.
//
//   mindre matkast      →  royalty tar INGENTING
//   mindre usynlig svinn →  royalty tar INGENTING
//   bedre innkjøpspris   →  royalty tar INGENTING
//   mer salg             →  royalty tar satsen for den kanalen
//
// Et system som trekker en flat royaltyprosent fra enhver forbedring
// undervurderer svinnarbeid og overvurderer volumarbeid. Begge deler
// sender folk feil vei, og det er den feilen denne fila finnes for å
// hindre.
//
// ---------------------------------------------------------------------
// «ROYALTY ER 30 % AV BUTIKKMARGINEN» ER EN OBSERVASJON, IKKE EN REGEL
//
// Kelsars kluster havner tilfeldigvis der, fordi varemiksen er som den
// er. Regner man konsekvensen av en ENDRING i miks med 30 %, blir svaret
// feil vei: vask over kassa betaler 60 % av omsetningen, mat 10 %.
//
// ---------------------------------------------------------------------
// KANALENE
//
// `vask_kasse` og `vask_app` er samme vask. Forskjellen er hvor den
// selges, og den er stor nok til å snu en anbefaling: 86,6 % brutto minus
// 60 % royalty gir 26,6 øre netto per krone over kassa, mens mat gir
// 38,9. Uten kanalen blir rådet «selg mer bilvask», og det er feil råd.

export type Satser = {
  /** Av omsetning. Alt unntatt vask og pant. */
  lavSats: number
  /** Av omsetning. Bare vask solgt over kassa. */
  hoySatsVask: number
  /** Av omsetning. Normalt 0. */
  pantSats: number
}

export type Kanal = 'ordinaer' | 'vask_kasse' | 'vask_app' | 'pant'

export type Gevinst =
  /**
   * Mer margin på samme omsetning: mindre svinn, mindre kast, bedre
   * innkjøp, mindre kassedifferanse. `kroner` er bruttoforbedringen.
   */
  | { type: 'margin'; kroner: number }
  /**
   * Mer omsetning. `omsetningKr` er den nye omsetningen, `bruttomargin`
   * er andelen av den som er bruttofortjeneste (0–1).
   */
  | { type: 'volum'; omsetningKr: number; bruttomargin: number; kanal: Kanal }

/** Royaltysatsen for en kanal, som andel av OMSETNING. */
export function satsFor(kanal: Kanal, s: Satser): number {
  switch (kanal) {
    case 'ordinaer': return s.lavSats
    case 'vask_kasse': return s.hoySatsVask
    // Vask på abonnement betaler ingen royalty. Stasjonen får en fast sum
    // per gjennomkjøring i stedet.
    case 'vask_app': return 0
    case 'pant': return s.pantSats
  }
}

/**
 * Hva som blir igjen av hver krone OMSETNING i en kanal, etter varekost
 * og royalty. Tallet å rangere varegrupper på — ikke bruttomarginen.
 */
export function nettoPerKrone(bruttomargin: number, kanal: Kanal, s: Satser): number {
  return bruttomargin - satsFor(kanal, s)
}

/**
 * Hva en forbedring faktisk er verdt, i kroner.
 *
 * DET ENESTE STEDET som skal regne dette. Ligger regnestykket spredt,
 * driver de fra hverandre — og forskjellen mellom en marginforbedring og
 * en volumvekst er nettopp den som er lett å miste underveis.
 */
export function verdiAvGevinst(g: Gevinst, s: Satser): number {
  if (g.type === 'margin') {
    // Omsetningen er uendret. Royalty regnes av omsetning. Derfor null.
    return g.kroner
  }
  const brutto = g.omsetningKr * g.bruttomargin
  const royalty = g.omsetningKr * satsFor(g.kanal, s)
  return brutto - royalty
}

/** Royaltyen alene, for visning ved siden av verdien. */
export function royaltyAv(g: Gevinst, s: Satser): number {
  return g.type === 'margin' ? 0 : g.omsetningKr * satsFor(g.kanal, s)
}

/**
 * Royalty for et helt år, av grunnlagstallene. Formen avstemmingen i
 * `parsere/bp-royalty.ts` bruker, og den `royaltysats`-radens `bp_*`-
 * kolonner gjør etterprøvbar.
 */
export function royaltyForAaret(
  grunnlag: { crSalg: number; omsetningVask: number; omsetningPant: number; vaskOverKassa: number },
  s: Satser,
): number {
  const ordinaert = grunnlag.crSalg - grunnlag.omsetningVask - grunnlag.omsetningPant
  return (
    ordinaert * s.lavSats +
    grunnlag.vaskOverKassa * s.hoySatsVask +
    grunnlag.omsetningPant * s.pantSats
  )
}
