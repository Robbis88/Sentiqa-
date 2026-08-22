// =====================================================================
// Midt i måneden: har du timer igjen, eller har du brukt dem opp?
//
// Robert, 2026-08-22: «underveis i august — har du brukt mer enn X timer
// bør du justere timene, for du ligger langt bak eller litt bak
// forventet.»
//
// Dette er det eneste tallet i timeregnskapet som kommer tidsnok til å
// endre noe. Alt annet er oppgjør: sant, men over.
//
// REGNESTYKKET
//
//   framskrevet brutto = brutto hittil ÷ fjorårets andel av måneden
//   opptjent hel måned = ramme × (framskrevet ÷ BP-brutto)
//   timer igjen        = opptjent − brukt hittil
//
// FJORÅRETS ANDEL, IKKE DAGER DELT PÅ DAGER. 20 av 31 dager er ikke
// 65 % av månedens brutto — helger, lønningsdager og utfartshelger
// ligger ikke jevnt. Regner man lineært, ser en stasjon som har hatt en
// travel første halvdel ut til å ligge foran, og butikksjefen som
// stoler på det bemanner opp inn i en rolig uke.
//
// FRAMSKRIVING ER ET ANSLAG, OG SIES Å VÆRE DET. Den forutsetter at
// resten av måneden ligner fjoråret. Det er den beste antakelsen vi
// har, men den er en antakelse — og et anslag som ikke er merket blir
// lest som en måling.
// =====================================================================

export type Styring = {
  /** Timer igjen av rammen hvis bruttoen fortsetter som nå. */
  timerIgjen: number
  /** Dager igjen av måneden. */
  dagerIgjen: number
  /** Timer per dag det gir. Null når måneden er over. */
  perDag: number | null
  /** Framskrevet brutto for hele måneden. */
  framskrevetBrutto: number
  /** Hvor mye brutto ligger an til å avvike fra BP, i prosent. */
  motBpPst: number
}

export function styring(
  { rammeTimer, brukteTimer, bpBruttoKr, bruttoHittilKr, ifjorAndel,
    dagerMedSalg, dagerIMaaned }: {
    rammeTimer: number | null
    brukteTimer: number | null
    bpBruttoKr: number | null
    bruttoHittilKr: number | null
    ifjorAndel: number | null
    dagerMedSalg: number | null
    dagerIMaaned: number | null
  },
): Styring | null {
  if (!rammeTimer || rammeTimer <= 0) return null
  if (brukteTimer == null || bpBruttoKr == null || bpBruttoKr <= 0) return null
  if (bruttoHittilKr == null) return null
  // Uten fjorårets kurve finnes ingen framskriving. Lineært som reserve
  // ville gitt et anslag som ser ut som en måling.
  if (!ifjorAndel || ifjorAndel <= 0) return null
  if (dagerMedSalg == null || dagerIMaaned == null) return null

  // MÅNEDEN MÅ VÆRE UFERDIG. Er den over, er dette et oppgjør og ikke
  // en styring — og «timer igjen» av en måned som er slutt er ikke et
  // tall noen kan bruke.
  if (dagerMedSalg >= dagerIMaaned) return null

  const framskrevetBrutto = bruttoHittilKr / ifjorAndel
  const opptjentHelMaaned = rammeTimer * (framskrevetBrutto / bpBruttoKr)
  const timerIgjen = opptjentHelMaaned - brukteTimer
  const dagerIgjen = dagerIMaaned - dagerMedSalg

  return {
    timerIgjen: Math.round(timerIgjen),
    dagerIgjen,
    perDag: dagerIgjen > 0 ? Math.round((timerIgjen / dagerIgjen) * 10) / 10 : null,
    framskrevetBrutto: Math.round(framskrevetBrutto),
    motBpPst: Math.round(((framskrevetBrutto - bpBruttoKr) / bpBruttoKr) * 1000) / 10,
  }
}

/**
 * Setningen butikksjefen skal lese midt i måneden.
 *
 * SIER HVA SOM SKAL GJØRES MED RESTEN AV MÅNEDEN, ikke hva som er brukt.
 * «Du har 84 timer igjen — 7,6 per dag» er en vaktplan; «660 timer
 * brukt» er en opplysning.
 *
 * ER TIMENE ALLEREDE BRUKT OPP, sies det rett ut. Å pakke det inn i
 * «ligger noe over» gjør at ingen justerer noe.
 */
export function styringstekst(s: Styring): string {
  const trend = s.motBpPst < -1
    ? `Brutto ligger an til ${Math.abs(s.motBpPst).toFixed(1).replace('.', ',')} % under plan. `
    : s.motBpPst > 1
      ? `Brutto ligger an til ${s.motBpPst.toFixed(1).replace('.', ',')} % over plan. `
      : ''

  if (s.timerIgjen <= 0) {
    return `${trend}Timene for måneden er brukt opp — ${Math.abs(s.timerIgjen)} `
      + `over, med ${s.dagerIgjen} dager igjen.`
  }
  const perDag = s.perDag != null
    ? ` — ${s.perDag.toFixed(1).replace('.', ',')} timer per dag`
    : ''
  return `${trend}${s.timerIgjen} timer igjen på ${s.dagerIgjen} dager${perDag}.`
}
