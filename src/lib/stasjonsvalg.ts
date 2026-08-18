// =====================================================================
// Hvilken stasjon ser jeg på?
//
// Ti sider spurte om det hver for seg. Butikksjefen med én stasjon svarte
// på det samme spørsmålet ti ganger, og fikk aldri et annet svar.
//
// Nå velges det ett sted og huskes. Reglene under er hele mekanikken, og
// rekkefølgen er den viktige delen:
//
//   1  URL-en vinner alltid. En delt lenke skal vise det den lovet,
//      uansett hva mottakeren valgte sist.
//   2  Så det man valgte sist.
//   3  Så det fornuftige: én stasjon for butikksjefen, hele porteføljen
//      for eieren der siden tåler det.
//
// Snur man 1 og 2, blir dyplenker upålitelige — og det oppdages ikke før
// noen sender en lenke til feil tall.
// =====================================================================

export type Stasjon = { id: string; navn: string; butikknummer?: string }

/** `null` betyr «alle stasjoner samlet», og er en gyldig verdi — ikke et tomt valg. */
export type Valg = string | null

export function velgStasjon(
  alle: Stasjon[],
  opts: {
    fraUrl?: string | null
    fraHukommelse?: string | null
    /** Tåler siden å vise alle stasjoner samlet? De færreste gjør det. */
    tillatAlle?: boolean
  } = {},
): Valg {
  const { fraUrl, fraHukommelse, tillatAlle = false } = opts
  if (alle.length === 0) return null

  const finnes = (id: string | null | undefined) =>
    id != null && alle.some((s) => s.id === id)

  // «alle» er et eksplisitt valg, ikke fravær av et valg.
  if (fraUrl === 'alle') return tillatAlle ? null : alle[0].id
  if (finnes(fraUrl)) return fraUrl!

  if (fraHukommelse === 'alle') return tillatAlle ? null : alle[0].id
  // En husket stasjon som ikke finnes lenger — slettet, eller en bruker
  // som byttet kjede — skal falle tilbake, ikke gi tom side.
  if (finnes(fraHukommelse)) return fraHukommelse!

  return tillatAlle ? null : alle[0].id
}

/** Skal velgeren i det hele tatt vises? */
export function visVelger(alle: Stasjon[], tillatAlle: boolean): boolean {
  // Én stasjon og ingen porteføljevisning er ikke et valg. Å vise en
  // nedtrekksliste med ett alternativ er å be om en beslutning som ikke
  // finnes.
  return alle.length > 1 || (alle.length === 1 && tillatAlle)
}

/** Navnet slik det vises: «9467 Bønes», eller bare navnet om nummer mangler. */
export const stasjonsnavn = (s: Stasjon) =>
  (s.butikknummer ? `${s.butikknummer} ${s.navn}` : s.navn)
