// =====================================================================
// Avstemming: samme måned, begge kilder, holdt mot hverandre.
//
// «Én stasjon, én måned, begge kilder, avstemt mot hverandre før neste»
// (PROSJEKT_stempling.md). Dette er tallet som avgjør om stasjonen kan
// snus — og for St1 er det hele argumentet: ikke at Sentiqa har en
// stempleskjerm, men at timene den regner er de samme som easy@work kom
// fram til.
//
// SAMMENLIGNER TIMER PER ANSATT, ikke rad mot rad. Radene vil aldri være
// like: nettbrettet har det faktiske minuttet, easy@work et avrundet, og
// en vakt kan være delt i to i den ene og hel i den andre. Det som må
// stemme er summen hun får betalt for.
// =====================================================================

export type Kildetimer = { ansattNr: string; navn: string; minutter: number }

export type Avstemming = {
  ansattNr: string
  navn: string
  importTimer: number
  tabletTimer: number
  /** tablet − import. Positiv betyr at nettbrettet ga flere timer. */
  avvikTimer: number
  /** Avvik i prosent av import. `null` når import er null. */
  avvikProsent: number | null
  /** Bare i den ene kilden — som regel noen som ikke har begynt å stemple. */
  bareI: 'import' | 'tablet' | null
}

export type Avstemmingssvar = {
  linjer: Avstemming[]
  importTimer: number
  tabletTimer: number
  avvikTimer: number
  /** Antall ansatte der avviket er større enn terskelen. */
  antallOverTerskel: number
}

/**
 * Hvor stort avvik som er verdt å se på.
 *
 * Et kvarter i måneden er avrunding — easy@work runder til nærmeste fem
 * minutter, nettbrettet gjør ikke det, og over tjue vakter blir det noen
 * minutter uansett hvor riktig begge er. Er terskelen null, drukner det
 * ekte avviket i støy, og da slutter man å lese lista.
 */
export const TERSKEL_TIMER = 0.25

const rund = (t: number) => Math.round(t * 100) / 100

/**
 * Holder de to kildene mot hverandre.
 *
 * Ansatte som bare finnes i den ene kilden tas MED, ikke bort. Under en
 * overgang er det nettopp de som er interessante: en som ikke har
 * stemplet i det hele tatt er ikke et avvik på null, hun er en som ikke
 * har begynt — og det er hele forskjellen når man skal avgjøre om
 * stasjonen kan snus.
 */
export function avstem(
  imported: Kildetimer[],
  tablet: Kildetimer[],
): Avstemmingssvar {
  const perNr = new Map<string, { navn: string; imp: number; tab: number }>()

  for (const k of imported) {
    const p = perNr.get(k.ansattNr) ?? { navn: k.navn, imp: 0, tab: 0 }
    p.imp += k.minutter
    p.navn = k.navn || p.navn
    perNr.set(k.ansattNr, p)
  }
  for (const k of tablet) {
    const p = perNr.get(k.ansattNr) ?? { navn: k.navn, imp: 0, tab: 0 }
    p.tab += k.minutter
    // Navnet fra stemplingen vinner: den er ferskere enn importen, og
    // ansattnummeret er uansett den stabile nøkkelen.
    p.navn = k.navn || p.navn
    perNr.set(k.ansattNr, p)
  }

  const linjer: Avstemming[] = [...perNr]
    .map(([ansattNr, p]) => {
      const importTimer = rund(p.imp / 60)
      const tabletTimer = rund(p.tab / 60)
      return {
        ansattNr,
        navn: p.navn,
        importTimer,
        tabletTimer,
        avvikTimer: rund(tabletTimer - importTimer),
        avvikProsent: importTimer === 0
          ? null
          : rund(((tabletTimer - importTimer) / importTimer) * 100),
        bareI: (p.imp === 0 ? 'tablet' : p.tab === 0 ? 'import' : null) as
          Avstemming['bareI'],
      }
    })
    // Størst avvik øverst — det er det man kom hit for å se.
    .sort((a, b) => Math.abs(b.avvikTimer) - Math.abs(a.avvikTimer))

  const importTimer = rund(linjer.reduce((s, l) => s + l.importTimer, 0))
  const tabletTimer = rund(linjer.reduce((s, l) => s + l.tabletTimer, 0))

  return {
    linjer,
    importTimer,
    tabletTimer,
    avvikTimer: rund(tabletTimer - importTimer),
    antallOverTerskel: linjer.filter(
      (l) => Math.abs(l.avvikTimer) > TERSKEL_TIMER).length,
  }
}

/**
 * Kan stasjonen snus til nettbrettet?
 *
 * Krever at begge kilder har timer, og at ingen ansatt avviker mer enn
 * terskelen. Ikke bare at totalen stemmer: to feil som opphever
 * hverandre gir null i sum og feil lønn til to personer.
 */
export function kanSnuStasjon(a: Avstemmingssvar): boolean {
  return a.importTimer > 0 && a.tabletTimer > 0 && a.antallOverTerskel === 0
}
