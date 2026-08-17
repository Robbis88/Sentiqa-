// =====================================================================
// Hvem skal med i lønnsfila?
//
// Ikke alle som stempler. Avstemmingen av mai viste det tydelig:
// Laguneparken stemte på hundredelen mot easy@works egen fil, mens Bønes
// manglet 191,68 timer — 27 % av måneden. To personer:
//
//   butikksjefen   fastlønn, og fastlønn kommer ikke fra stemplingene
//   Carmen         tilkallingsvikar, føres utenom
//
// Begge stempler. Begge jobber. Ingen av dem skal stå i denne fila.
//
// DERFOR ER null IKKE «ta med». En ansatt uten avklart lønnsform er et
// spørsmål, ikke en standardverdi — og fila lages ikke før spørsmålet er
// besvart. Det er den ene gangen det er riktig å stoppe brukeren: en fil
// som mangler en persons timer betyr at hun ikke får lønn den måneden,
// og det oppdages først på kontoutskriften.
//
// Etter at det er svart én gang, huskes det. Kostnaden er én gang per
// ansatt, ikke én gang per måned.
// =====================================================================

export type Lonnsform = 'timelonn' | 'fastlonn' | 'tilkalling'

export const LONNSFORM_NAVN: Record<Lonnsform, string> = {
  timelonn: 'Timelønn',
  fastlonn: 'Fastlønn',
  tilkalling: 'Tilkallingsvikar',
}

/** Hvorfor noen holdes utenfor — vises i lista, ikke bare telles. */
export const UTELATT_FORDI: Record<Exclude<Lonnsform, 'timelonn'>, string> = {
  fastlonn: 'Fastlønn — beløpet er fast og kommer ikke fra stemplingene',
  tilkalling: 'Tilkallingsvikar — føres utenom denne fila',
}

export type Linje = { ansattNr: string; lonnsart: string; antall: number }

export type Fordeling<L extends Linje> = {
  /** Linjene som skal i fila. */
  med: L[]
  /** Holdt utenfor med vilje, per ansatt. */
  utelatt: { ansattNr: string; lonnsform: Exclude<Lonnsform, 'timelonn'>; timer: number }[]
  /** Ikke avklart. Så lenge denne ikke er tom, lages ingen fil. */
  uavklart: { ansattNr: string; timer: number }[]
}

/**
 * Deler lønnslinjene i tre: med, bevisst utelatt, og ikke avklart.
 *
 * `timer` er summen av den ansattes timelønnslinjer, ikke av alle
 * linjene — tilleggene ligger oppå de samme timene, og å summere alt
 * ville telt en kveldsvakt to ganger.
 */
export function delEtterLonnsform<L extends Linje>(
  linjer: L[],
  lonnsform: Map<string, Lonnsform | null>,
  timelonnsart: string,
): Fordeling<L> {
  const timerFor = new Map<string, number>()
  for (const l of linjer) {
    if (l.lonnsart === timelonnsart) {
      timerFor.set(l.ansattNr, (timerFor.get(l.ansattNr) ?? 0) + l.antall)
    }
  }

  const med: L[] = []
  const utelatt: Fordeling<L>['utelatt'] = []
  const uavklart: Fordeling<L>['uavklart'] = []
  const sett = new Set<string>()

  for (const l of linjer) {
    const form = lonnsform.get(l.ansattNr) ?? null
    if (form === 'timelonn') {
      med.push(l)
      continue
    }
    if (sett.has(l.ansattNr)) continue
    sett.add(l.ansattNr)
    const timer = timerFor.get(l.ansattNr) ?? 0
    if (form === null) uavklart.push({ ansattNr: l.ansattNr, timer })
    else utelatt.push({ ansattNr: l.ansattNr, lonnsform: form, timer })
  }

  const paaTimer = (a: { timer: number }, b: { timer: number }) => b.timer - a.timer
  return { med, utelatt: utelatt.sort(paaTimer), uavklart: uavklart.sort(paaTimer) }
}
