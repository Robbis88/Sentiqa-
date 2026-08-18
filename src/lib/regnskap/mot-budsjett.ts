// =====================================================================
// Ligger vi over eller under budsjett — og hva drar mest?
//
// Regnskapssiden har alltid hatt budsjettet ved siden av regnskapet, i
// hver eneste rad. Den har bare aldri sagt hva summen av dem betyr.
// Brukeren har måttet lese seg gjennom fire tabeller og regne selv.
//
// TRE VALG SOM AVGJØR OM SVARET ER TIL Å STOLE PÅ:
//
// FORTEGNET FØLGER PENGENE, DOMMEN FØLGER SEKSJONEN. På omsetning er
// over budsjett bra; på driftskostnader er det ikke. Samme feilen som
// skiller salg fra svinn: pilen kan peke opp mens fargen er rød.
//
// DRIVEREN MÅLES I KRONER, IKKE PROSENT. 40 % over på en konto til
// 5 000 kr er 2 000 kr og uten betydning. 3 % over på personal er
// 90 000 kr og hele forklaringen. Prosent ville løftet støyen øverst.
//
// LINJER UTEN BUDSJETT KAN IKKE AVVIKE FRA DET. Uten den regelen blir
// avviket lik hele beløpet, og en konto ingen har budsjettert vinner
// alltid kampen om å være «driveren».
// =====================================================================

export type Budsjettlinje = {
  post: string
  regnskap: number | null
  budsjett: number | null
}

export type MotBudsjett = {
  regnskap: number
  budsjett: number
  /** Kroner. Positivt = regnskapet er høyere enn budsjettet. */
  avvik: number
  /** Null når det ikke finnes et budsjett å måle mot. */
  avvikProsent: number | null
  /**
   * Dommen, ikke retningen. `null` betyr «ingen dom»: enten mangler
   * budsjettet, eller avviket er for lite til å være en sak.
   */
  bra: boolean | null
  /** Ferdig setning, eller null når det ikke finnes noe å påstå. */
  tekst: string | null
}

/**
 * Under dette er avviket budsjettpresisjon, ikke en hendelse.
 *
 * Samme grense som `avviksKlasse` bruker for grønn (§12) — et regnskap
 * som treffer innenfor to prosent har truffet.
 */
const PA_BUDSJETT_PROSENT = 2

const heltall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })

/**
 * @param kostnad Settes for driftskostnader, der høyere regnskap er verre.
 */
export function motBudsjett(
  regnskap: number | null,
  budsjett: number | null,
  kostnad = false,
): MotBudsjett {
  const r = regnskap ?? 0
  const b = budsjett ?? 0
  const avvik = r - b

  if (b === 0) {
    return { regnskap: r, budsjett: b, avvik, avvikProsent: null, bra: null, tekst: null }
  }

  const avvikProsent = (avvik / Math.abs(b)) * 100
  const paBudsjett = Math.abs(avvikProsent) < PA_BUDSJETT_PROSENT
  // Over budsjett er bra på inntekt, dårlig på kostnad.
  const bra = paBudsjett ? null : kostnad ? avvik < 0 : avvik > 0

  return {
    regnskap: r,
    budsjett: b,
    avvik,
    avvikProsent,
    bra,
    tekst: paBudsjett
      ? 'på budsjett'
      : `${heltall.format(Math.abs(avvik))} kr ${avvik > 0 ? 'over' : 'under'} budsjett`,
  }
}

export type Driver = { post: string; avvik: number }

/**
 * Linja som trekker mest i feil retning, målt i kroner.
 *
 * Summeringslinjene («Omsetning totalt») utelates: de er sine egne
 * underlinjer lagt sammen, og ville alltid slått delene de består av.
 */
export function storsteAvvik(linjer: Budsjettlinje[], kostnad = false): Driver | null {
  const kandidater = linjer
    .filter((l) => !/totalt$/i.test(l.post.trim()))
    .map((l) => ({ post: l.post, avvik: (l.regnskap ?? 0) - (l.budsjett ?? 0), budsjett: l.budsjett ?? 0 }))
    // Uten budsjett finnes det ikke noe avvik å snakke om.
    .filter((l) => l.budsjett !== 0)
    // Bare det som gjør bildet verre — ikke det som redder det.
    .filter((l) => (kostnad ? l.avvik > 0 : l.avvik < 0))

  if (kandidater.length === 0) return null
  const verst = kandidater.reduce((a, l) => (Math.abs(l.avvik) > Math.abs(a.avvik) ? l : a))
  return { post: verst.post, avvik: verst.avvik }
}

/**
 * Nivå 1 på en analyseside: hele svaret som én setning på norsk.
 *
 * Driveren nevnes bare når hovedtallet faktisk er dårligere enn
 * budsjett. «Vi ligger over budsjett, og X drar mest» er selvmotsigende
 * — da er det ingenting som drar noe sted.
 */
export function svaret(merke: string, mot: MotBudsjett, driver: Driver | null): string | null {
  if (!mot.tekst) return null
  const hoved = `${merke} ligger ${mot.tekst}`
  return mot.bra === false && driver ? `${hoved}. ${driver.post} drar mest` : hoved
}
