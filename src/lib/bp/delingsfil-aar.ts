import type { Delingsrad } from '@/lib/parsere/delingsfil'

// =====================================================================
// HVILKET ÅR GJELDER DELINGSFILA?
//
// Fila sier det ikke. Ingen kolonne, ingen celle, ingenting i filnavnet.
//
// Men den oppgir `Budsjettert matomsetning` per stasjon, og DET tallet
// står også i BP-en: Laguneparken 4 651 908 er BP 2025s Mat på krona.
// Året finnes altså ved å stille filas egne tall mot budsjettene vi
// allerede har lagret.
//
// ---------------------------------------------------------------------
// KRAVET ER STRENGT MED VILJE
//
// Et timebudsjett på feil år er verre enn ingen: bemanningsplanleggeren
// ville fordelt fjorårets timer på årets måneder, og planen ville sett
// helt normal ut. Derfor må ALLE stasjonene i fila treffe SAMME år, og
// bare det ene året.
//
// Toleransen er en krone. Tallene kommer fra samme kilde og skal være
// identiske; slingring her ville bare gjort det lettere å treffe feil.
// =====================================================================

/** Mat-omsetningen per stasjon, per år, slik den er budsjettert i BP-en. */
export type Matbudsjett = Map<number, Map<string, number>>

export type Aarssvar =
  | { ar: number; treff: { butikknavn: string; stasjonId: string }[] }
  | { ar: null; grunn: string }

const KRONE = 1

/**
 * Finner året, eller sier hvorfor det ikke lot seg finne.
 *
 * `navnTilStasjon` er kjedens egen navnematching — delingsfila skriver
 * «SHELL LAGUNEPARKEN», basen kan ha «St1 Laguneparken». Kallstedet eier
 * den koblingen; denne funksjonen gjetter ikke på navn.
 */
export function finnAaret(
  rader: Delingsrad[],
  navnTilStasjon: Map<string, string>,
  matbudsjett: Matbudsjett,
): Aarssvar {
  const kjente = rader
    .map((r) => ({ r, stasjonId: navnTilStasjon.get(r.butikknavn.trim().toLowerCase()) }))
    .filter((x): x is { r: Delingsrad; stasjonId: string } => Boolean(x.stasjonId))

  if (kjente.length === 0) {
    return {
      ar: null,
      grunn: `Ingen av de ${rader.length} stasjonene i delingsfila hører til denne kjeden.`,
    }
  }

  const traff: number[] = []
  for (const [ar, perStasjon] of matbudsjett) {
    // ALLE stasjonene må treffe. Treffer to av tre, er det like sannsynlig
    // at fila hører til et annet år som at den tredje har en avvikende rad.
    const alle = kjente.every((k) => {
      const bp = perStasjon.get(k.stasjonId)
      return bp !== undefined && Math.abs(bp - k.r.matomsetning) <= KRONE
    })
    if (alle) traff.push(ar)
  }

  if (traff.length === 1) {
    return {
      ar: traff[0],
      treff: kjente.map((k) => ({ butikknavn: k.r.butikknavn, stasjonId: k.stasjonId })),
    }
  }
  if (traff.length > 1) {
    return {
      ar: null,
      grunn:
        `Delingsfila passer like godt til ${traff.sort().join(' og ')}. `
        + 'Da kan den ikke plasseres uten å gjette, og et timebudsjett på feil år '
        + 'er verre enn ingen.',
    }
  }
  return {
    ar: null,
    grunn:
      'Fant ingen BP-årgang der budsjettert matomsetning stemmer med delingsfila. '
      + 'Last opp forretningsplanen for samme år først — delingsfila plasseres ved '
      + 'å kjenne igjen tallene i den.',
  }
}
