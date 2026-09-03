// =====================================================================
// Rutiner og sjekkpunkter, per ukedag.
//
// Begge er DAGLIGE — det finnes ingen frekvenskolonne, og
// `unique (rutine_id, dato)` / `unique (sjekkpunkt_id, dato)` sier at
// hver av dem kvitteres én gang per dag. Kravet for en dag er derfor
// antall skjemaer som fantes den dagen.
//
// PER DAG, IKKE BARE SAMLET. «86 % denne uken» sier at noe glapp; det
// sier ikke hva man skal gjøre. «Søndag 40 %, resten 100 %» sier at det
// er søndagsvakta som mangler et håndtak — og det er en handling.
//
// NEVNEREN ER DET VANSKELIGE. Legger en butikksjef inn fem nye rutiner
// på fredag, ville en naiv nevner (5 x 7) sagt at hun bommet på mandag
// til torsdag. Brevet ville anklaget henne for å ikke ha gjort noe som
// ikke fantes, og et brev som tar feil slik blir ikke lest en tredje gang.
//
// REGELEN ER KONSERVATIV I RIKTIG RETNING. Et skjema teller for en dag
// bare hvis det fantes ved DØGNETS START og fortsatt fantes ved døgnets
// slutt. En rutine opprettet kl. 23.00 kan ikke gjøres den dagen; en som
// ble slettet kl. 10.00 skal ikke kreves den dagen. Begge avrundinger går
// i stasjonens favør — med vilje: prosenten skal kunne stoles på når den
// er lav.
// =====================================================================

export type Skjemapost = {
  /** `opprettet_tid`, ISO med tidspunkt. Datoen alene holder ikke — det
      er nettopp klokkeslettet som avgjør om dagen kunne rekkes. */
  opprettet: string
  /** `slettet_tid`, eller null for et aktivt skjema. */
  slettet: string | null
}

export type Dagsrad = {
  dato: string
  /** «Man», «Tir» … Kort, fordi den skal stå i en kolonne på en telefon. */
  ukedag: string
  krevd: number
  utfort: number
  /** null = ingenting var krevd denne dagen. Ikke det samme som 0 %. */
  prosent: number | null
}

export type Skjemabilde = {
  navn: string
  dager: Dagsrad[]
  krevd: number
  utfort: number
  prosent: number | null
  /** Dagen med lavest oppfyllelse, når den er tydelig verre enn resten. */
  svakesteDag: Dagsrad | null
}

const UKEDAGER = ['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'] as const

const doegnstart = (dato: string) => Date.parse(`${dato}T00:00:00Z`)

function leggTil(iso: string, n: number): string {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

export function andel(utfort: number, krevd: number): number | null {
  if (krevd <= 0) return null
  return Math.round((utfort / krevd) * 100)
}

/** Hvor mange prosentpoeng under de andre dagene en dag må ligge for at
    det er dagen — og ikke uken — som er saken. */
const SVAKESTE_MARGIN = 25

/**
 * Bygger ukebildet for én skjematype.
 *
 * `utfortPerDato` er antall kvitteringer den dagen, uansett hvilket
 * skjema — summen er det som kan sammenlignes med kravet.
 *
 * `sisteDag` klipper uken der den slutter: en uke som fortsatt løper
 * skal ikke kreve noe av dager som ikke har vært.
 */
export function skjemabilde(opts: {
  navn: string
  poster: Skjemapost[]
  utfortPerDato: Map<string, number>
  ukeMandag: string
  sisteDag?: string
}): Skjemabilde {
  const dager: Dagsrad[] = []
  for (let i = 0; i < 7; i++) {
    const dato = leggTil(opts.ukeMandag, i)
    if (opts.sisteDag && dato > opts.sisteDag) break
    const start = doegnstart(dato)
    const slutt = doegnstart(leggTil(dato, 1))
    let krevd = 0
    for (const p of opts.poster) {
      if (Date.parse(p.opprettet) >= start) continue
      if (p.slettet !== null && Date.parse(p.slettet) < slutt) continue
      krevd++
    }
    // Kan ikke overstige kravet: en dag med seks kvitteringer på fem
    // rutiner er en datafeil, ikke 120 %.
    const utfort = Math.min(opts.utfortPerDato.get(dato) ?? 0, krevd)
    dager.push({ dato, ukedag: UKEDAGER[i], krevd, utfort, prosent: andel(utfort, krevd) })
  }

  const krevd = dager.reduce((a, d) => a + d.krevd, 0)
  const utfort = dager.reduce((a, d) => a + d.utfort, 0)

  // Den svakeste dagen er bare en sak hvis den skiller seg ut. Ligger
  // alle dagene likt lavt, er det rutinene som er for mange eller for
  // vanskelige — ikke en bestemt vakt.
  const medTall = dager.filter((d) => d.prosent !== null)
  let svakesteDag: Dagsrad | null = null
  if (medTall.length >= 3) {
    const sortert = [...medTall].sort((a, b) => a.prosent! - b.prosent!)
    const verst = sortert[0]
    const andreKrevd = krevd - verst.krevd
    const andrePst = andreKrevd > 0 ? ((utfort - verst.utfort) / andreKrevd) * 100 : 0
    if (andrePst - verst.prosent! >= SVAKESTE_MARGIN) svakesteDag = verst
  }

  return { navn: opts.navn, dager, krevd, utfort, prosent: andel(utfort, krevd), svakesteDag }
}
