// =====================================================================
// Fra hendelser til vakter.
//
// `stempling_hendelse` er raa inn og ut. `stempling` er ferdige vakter.
// Denne funksjonen er broen, og den er der de vonde tilfellene bor.
//
// TRE VALG SOM AVGJOR OM LONNA BLIR RIKTIG:
//
// VI GJETTER ALDRI EN SLUTTID. Glemt utstempling er den vanligste
// feilen. En automatisk lukking som treffer feil er verre enn ingen,
// fordi ingen oppdager den - timene ser riktige ut og er det ikke.
// Vakten staar AAPEN, dukker opp paa butikksjefens liste, og lonnsfila
// lages ikke for den er lukket. Samme monster som lonnsform, og det
// virker: en blokkering folk maa rydde i, framfor et stille feil tall.
//
// FORRETNINGSDATOEN FOLGER STARTEN. En vakt som begynner 23:30 hoerer
// til den dagen den begynte, ogsaa de tretti minuttene etter midnatt.
// Samme regel som tidsband.ts bruker for helligdager, og den maa vaere
// den samme - ellers sier de to sidene av systemet ulike ting om samme
// vakt.
//
// EN «INN» MENS MAN ER INNE ER EN FEIL, IKKE EN NY VAKT. Den forrige
// staar aapen og blokkerer. Aa la den andre starte en ny vakt i stillhet
// ville skjult at noen glemte aa stemple ut.
// =====================================================================

export type Hendelse = {
  id: string
  ansattNr: string
  ansattNavn: string
  stasjonId: string
  /** ISO-tidspunkt med sone. */
  tidspunkt: string
  type: 'inn' | 'ut'
}

export type Vakt = {
  ansattNr: string
  ansattNavn: string
  stasjonId: string
  /** Forretningsdato — folger STARTEN, ogsaa over midnatt. */
  dato: string
  fraTid: string
  tilTid: string
  minutter: number
  innId: string
  utId: string
}

export type Avvik =
  | { slag: 'aapen'; hendelse: Hendelse; grunn: 'mangler_ut' }
  | { slag: 'foreldrelos'; hendelse: Hendelse; grunn: 'ut_uten_inn' }
  | { slag: 'dobbel_inn'; hendelse: Hendelse; grunn: 'inn_mens_inne' }

export type Avledning = { vakter: Vakt[]; avvik: Avvik[] }

/** Oslo-tid ut av et ISO-tidspunkt. Hele systemet regner i Europe/Oslo (§18). */
const oslo = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Europe/Oslo',
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hour12: false,
})

/** `2026-08-19 07:30` → `{ dato: '2026-08-19', tid: '07:30' }` */
function iOslo(iso: string): { dato: string; tid: string } {
  const [dato, tid] = oslo.format(new Date(iso)).split(' ')
  return { dato, tid }
}

/**
 * Vakter og avvik ut av en strøm hendelser.
 *
 * Hendelsene sorteres på tidspunkt per ansatt. Rekkefølgen de kommer i
 * betyr ingenting — en korreksjon lagt inn i etterkant hører hjemme der
 * den skjedde, ikke der den ble skrevet.
 */
export function avledVakter(hendelser: Hendelse[]): Avledning {
  const vakter: Vakt[] = []
  const avvik: Avvik[] = []

  // Per ansatt, ikke per dato: en vakt kan krysse midnatt, og da ville
  // gruppering på dato delt den i to halve.
  const perAnsatt = new Map<string, Hendelse[]>()
  for (const h of hendelser) {
    const liste = perAnsatt.get(h.ansattNr) ?? []
    liste.push(h)
    perAnsatt.set(h.ansattNr, liste)
  }

  for (const liste of perAnsatt.values()) {
    const sortert = [...liste].sort(
      (a, b) => Date.parse(a.tidspunkt) - Date.parse(b.tidspunkt),
    )

    let aapen: Hendelse | null = null

    for (const h of sortert) {
      if (h.type === 'inn') {
        if (aapen) {
          // Hun stemplet inn uten å ha stemplet ut. Den forrige blir
          // stående åpen — den skal ryddes av et menneske, ikke lukkes
          // av en gjetning.
          avvik.push({ slag: 'aapen', hendelse: aapen, grunn: 'mangler_ut' })
          avvik.push({ slag: 'dobbel_inn', hendelse: h, grunn: 'inn_mens_inne' })
        }
        aapen = h
        continue
      }

      if (!aapen) {
        avvik.push({ slag: 'foreldrelos', hendelse: h, grunn: 'ut_uten_inn' })
        continue
      }

      const start = iOslo(aapen.tidspunkt)
      const slutt = iOslo(h.tidspunkt)
      const minutter = Math.round(
        (Date.parse(h.tidspunkt) - Date.parse(aapen.tidspunkt)) / 60_000,
      )

      vakter.push({
        ansattNr: aapen.ansattNr,
        ansattNavn: aapen.ansattNavn,
        // Stasjonen følger INNSTEMPLINGEN. Går noen over til nabostasjonen
        // midt i vakta, hører timene til der vakta begynte — ellers ville
        // en vakt tilhørt to stasjoner og talt i begges bemanning.
        stasjonId: aapen.stasjonId,
        dato: start.dato,
        fraTid: start.tid,
        tilTid: slutt.tid,
        minutter,
        innId: aapen.id,
        utId: h.id,
      })
      aapen = null
    }

    // Står hun fortsatt inne når hendelsene tar slutt, er vakta åpen.
    if (aapen) avvik.push({ slag: 'aapen', hendelse: aapen, grunn: 'mangler_ut' })
  }

  return { vakter, avvik }
}

/**
 * Kan lønnsfila lages?
 *
 * Én åpen vakt er nok til å blokkere. En fil som mangler noens timer
 * betyr at hun ikke får lønn den måneden, og det oppdages først på
 * kontoutskriften.
 */
export function kanLageLonnsfil(avvik: Avvik[]): boolean {
  return avvik.length === 0
}
