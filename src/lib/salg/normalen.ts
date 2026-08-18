// =====================================================================
// Hva er normalt for en tirsdag?
//
// «34 200 kr» sier ingenting. «+7,8 % mot en vanlig tirsdag» sier alt —
// og systemet har alltid hatt tallene til å regne det ut, det har bare
// aldri gjort det.
//
// TO VALG SOM AVGJØR OM TALLET ER TIL Å STOLE PÅ:
//
// Sammenlign med SAMME UKEDAG. En tirsdag mot et snitt som inkluderer
// lørdager sier bare at lørdag er travlere enn tirsdag. Det visste vi.
//
// Bruk MEDIAN, ikke snitt. Én 17. mai eller én dag med veiarbeid utenfor
// drar snittet nok til at «normalen» blir noe som aldri har skjedd.
// Medianen står imot begge deler.
// =====================================================================

export type Dagsrad = { dato: string; omsetning: number }

export type MotNormalen = {
  /** Dagens tall. */
  verdi: number
  /** Medianen for samme ukedag i vinduet. */
  normal: number
  /** Positivt = over normalen. */
  avvikProsent: number
  /** Hvor mange dager medianen bygger på. */
  grunnlag: number
  /** Ukedagen, på norsk: «en vanlig tirsdag». */
  ukedag: string
  /** Ferdig setning, eller null når grunnlaget er for tynt. */
  tekst: string | null
}

const UKEDAGER = [
  'søndag', 'mandag', 'tirsdag', 'onsdag', 'torsdag', 'fredag', 'lørdag',
]

/**
 * Færre enn dette, og medianen er et tilfeldig tall.
 *
 * Fire like ukedager er en måned med data. Under det sier vi heller
 * ingenting enn noe vi ikke kan stå for.
 */
const MIN_GRUNNLAG = 4

// «7,8 %», ikke «7.8 %». Hele systemet er norsk, og toFixed skriver
// engelsk uansett hvor det står.
const prosent = new Intl.NumberFormat('nb-NO', {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
})

const median = (t: number[]) => {
  if (t.length === 0) return 0
  const s = [...t].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

/** Ukedag 0–6 fra en ISO-dato, tolket i UTC så tidssoner ikke flytter den. */
export const ukedagFor = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay()

export function motNormalen(
  dato: string,
  verdi: number,
  historikk: Dagsrad[],
): MotNormalen {
  const ukedag = ukedagFor(dato)
  const like = historikk
    // Dagen selv skal ikke være med i sitt eget sammenligningsgrunnlag.
    .filter((r) => r.dato !== dato && ukedagFor(r.dato) === ukedag)
    .map((r) => r.omsetning)
    .filter((v) => v > 0)

  const normal = median(like)
  const avvikProsent = normal > 0 ? ((verdi - normal) / normal) * 100 : 0
  const navn = UKEDAGER[ukedag]

  const nok = like.length >= MIN_GRUNNLAG && normal > 0
  const retning = avvikProsent >= 0 ? '+' : '−'
  return {
    verdi,
    normal,
    avvikProsent,
    grunnlag: like.length,
    ukedag: navn,
    tekst: nok
      ? `${retning}${prosent.format(Math.abs(avvikProsent))} % mot en vanlig ${navn}`
      : null,
  }
}

/**
 * Er avviket verdt å legge merke til?
 *
 * Under ti prosent er dagsvariasjon. Over det har som regel en årsak —
 * vær, kampanje, en buss, eller noe som er galt.
 */
export const verdtEtBlikk = (m: MotNormalen) =>
  m.tekst !== null && Math.abs(m.avvikProsent) >= 10
