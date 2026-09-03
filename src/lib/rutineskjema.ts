// Rutineskjema-logikk: hvilket vakttype-skjema er aktivt «nå», og hvilke
// rutiner gjelder. Alt i Europe/Oslo. Håndterer ±1t overlapp og vakter som
// krysser midnatt (f.eks. 22:00–06:00). Ren logikk → testbar.

export type OsloNaa = { dato: string; ukedag: number; minutter: number } // dato YYYY-MM-DD, ukedag 0=søn..6=lør

const UKEDAG_KORT: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }

export function osloNaa(d: Date): OsloNaa {
  const deler = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Oslo', weekday: 'short', hour: '2-digit', minute: '2-digit', hour12: false,
  }).formatToParts(d)
  const hent = (t: string) => deler.find((p) => p.type === t)?.value ?? ''
  const ukedag = UKEDAG_KORT[hent('weekday')] ?? 0
  let time = parseInt(hent('hour'), 10)
  if (time === 24) time = 0
  const minutter = time * 60 + parseInt(hent('minute'), 10)
  const dato = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Oslo' }).format(d)
  return { dato, ukedag, minutter }
}

function tilMin(hhmm: string): number {
  const [h, m] = hhmm.split(':').map((x) => parseInt(x, 10))
  return (h || 0) * 60 + (m || 0)
}

function forrigeDato(dato: string): string {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - 1)
  return d.toISOString().slice(0, 10)
}

export type Vaktvindu = { aktiv: boolean; vaktdag: number; vaktdato: string }

// Er skjemaet aktivt nå? Returnerer også vakt-dag/-dato som rutinene filtreres
// og registreres på (viktig for vakter over midnatt — da «hører» morgenen til
// gårsdagens vakt).
export function skjemaAktiv(
  skjema: { tid_start: string; tid_slutt: string; ukedager: number[] },
  naa: OsloNaa,
  overlappMin = 60,
): Vaktvindu {
  const start = tilMin(skjema.tid_start)
  const slutt = tilMin(skjema.tid_slutt)
  const passerDag = (wd: number) => skjema.ukedager.length === 0 || skjema.ukedager.includes(wd)
  const s = start - overlappMin
  const e = slutt + overlappMin

  if (start <= slutt) {
    const aktiv = naa.minutter >= s && naa.minutter <= e && passerDag(naa.ukedag)
    return { aktiv, vaktdag: naa.ukedag, vaktdato: naa.dato }
  }
  // Krysser midnatt
  if (naa.minutter >= s) {
    // Kveldsdel — vakten startet i dag
    return { aktiv: passerDag(naa.ukedag), vaktdag: naa.ukedag, vaktdato: naa.dato }
  }
  if (naa.minutter <= e) {
    // Morgendel — vakten startet i går
    const vaktdag = (naa.ukedag + 6) % 7
    return { aktiv: passerDag(vaktdag), vaktdag, vaktdato: forrigeDato(naa.dato) }
  }
  return { aktiv: false, vaktdag: naa.ukedag, vaktdato: naa.dato }
}

// To-nivå ukedag: rutinens egne dager ∧ vaktens dag (tom rutine = arv fra
// skjemaet, som allerede er sjekket). Hopp over rutiner opprettet etter vakten.
export function rutineGjelder(
  rutine: { ukedager: number[]; opprettet_dato: string },
  vindu: Vaktvindu,
): boolean {
  const dagOk = rutine.ukedager.length === 0 || rutine.ukedager.includes(vindu.vaktdag)
  const ikkeForTidlig = rutine.opprettet_dato <= vindu.vaktdato
  return dagOk && ikkeForTidlig
}

export type Rutinerad = {
  id: string
  skjema_id: string | null
  ukedager: number[]
  opprettet_dato: string
}

/**
 * Rutinene som gjelder en gitt DATO.
 *
 * Dette er den ene regelen, og den maa vaere det: den bestemmer
 * nevneren i hver eneste rutineprosent. Regnes den to steder, faar
 * statistikksida og ukebriefen ulike tall for samme uke — og da er begge
 * mistenkelige.
 *
 * TO NIVAAER UKEDAG. Skjemaet velger dagene vakta finnes, rutinen kan
 * snevre inn ytterligere. Tom liste betyr «alle dager» paa begge nivaa,
 * ikke «ingen».
 *
 * En rutine uten skjema teller ikke: skjemaet baerer vakttypen, og uten
 * det finnes det ingen vakt aa gjoere den paa.
 *
 * `opprettet_dato` klipper bakover. Uten den ville en rutine laget i dag
 * blitt krevd for hele fjoraaret.
 */
export function rutinerForDato(
  rutiner: Rutinerad[],
  skjemaUkedager: Map<string, number[]>,
  dato: string,
): string[] {
  const ukedag = new Date(`${dato}T12:00:00Z`).getUTCDay()
  const ut: string[] = []
  for (const r of rutiner) {
    if (r.skjema_id === null) continue
    const skjema = skjemaUkedager.get(r.skjema_id)
    if (!skjema) continue
    if (skjema.length > 0 && !skjema.includes(ukedag)) continue
    if (r.ukedager.length > 0 && !r.ukedager.includes(ukedag)) continue
    if (r.opprettet_dato > dato) continue
    ut.push(r.id)
  }
  return ut
}

export const VAKTTYPER = ['morgen', 'dag', 'kveld', 'natt'] as const
export const VAKTTYPE_ETIKETT: Record<string, string> = {
  morgen: 'Morgen', dag: 'Dag', kveld: 'Kveld', natt: 'Natt',
}
export const UKEDAG_NAVN = ['Søn', 'Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør']
