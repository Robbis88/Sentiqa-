import { forventetSalg, type Modell, type Salgsenhet, type Salgsrad } from './motor'

// =====================================================================
// HVOR GODT HAR MOTOREN TRUFFET PÅ AKKURAT DENNE VAREN, HER?
// =====================================================================
//
// Backtesten 2026-09-17 viste det viktigste om denne motoren: den er
// ikke like god overalt. Samme vare, samme modell, Coca-Cola 0,5L:
//
//   Dale          22,2 %   38,5 stk/dag
//   Laguneparken  26,6 %   17,3
//   Lone          33,3 %   14,8
//   Varden        33,2 %    8,3
//   Bønes         48,1 %    6,8
//
// TREFFSIKKERHET ER PER STASJON, IKKE PER MODELL. «Omtrent 38 på Dale»
// er forsvarlig. «Omtrent 7 på Bønes» er det ikke uten at usikkerheten
// følger med.
//
// ---------------------------------------------------------------------
// DETTE ER IKKE ET PREDIKSJONSINTERVALL
// ---------------------------------------------------------------------
//
// `wmape` er hvor mye modellen HAR bommet historisk. Den er ikke et
// spenn rundt morgendagens tall, og skal aldri gjøres om til «38 ± 22 %»
// eller «30–46 stk». Vi har ikke bevist at feilen er fordelt slik at et
// slikt intervall betyr noe — og et intervall som ser statistisk ut uten
// å være det, er verre enn ingen.
//
// Typen bærer derfor ingen `fra`/`til`, og ingen felt som heter
// `intervall`, `konfidens` eller `sannsynlig`. Det som ikke kan
// uttrykkes, kan ikke lekke ut i et svar.
//
// ---------------------------------------------------------------------
// SAMME MOTOR, IKKE EN REKONSTRUKSJON
// ---------------------------------------------------------------------
//
// Målingen kaller `forventetSalg` — den samme funksjonen flaten bruker.
// Et eget regnestykke her ville målt noe annet enn det brukeren får.
// Fremtidslekkasjen håndheves fortsatt inne i motoren.
// =====================================================================

export type Treffmaal = {
  /** Måldatoer med fasit OG dekning. Er den lav, betyr resten lite. */
  dager: number
  /** Gjennomsnittlig bom i ANTALL. Alltid meningsfull. */
  mae: number
  /** Den vanlige dagen. Snittet dras av en hale — backtesten ga median 2. */
  medianFeil: number
  /**
   * `sum|feil| / sum(faktisk)`, i prosent.
   *
   * Nevneren er totalvolumet, så en dag med 1 solgt ikke drar snittet.
   * `null` når det ikke ble solgt noe i det hele tatt.
   */
  wmape: number | null
  /**
   * Snitt av `forventet − faktisk`.
   *
   * EN OBSERVASJON OM MODELLEN, IKKE EN KORREKSJONSFAKTOR. Dale målte
   * −3,0: motoren ligger systematisk lavt der. Å legge tre på tallet
   * ville vært å kalibrere i presentasjonslaget, og da eier ingen
   * lenger sannheten.
   */
  bias: number
  snittFaktisk: number
}

export type Treffinput = {
  enhet: Salgsenhet
  /** Historikken. Motoren kaster selv alt fra og med hver måldato. */
  salg: readonly Salgsrad[]
  /** Datoene som måles. Nyest sist. */
  maaldatoer: readonly string[]
  modell: Modell
  minstDagerMedSalg: number
}

/**
 * Måler motoren mot fasit for én salgsenhet.
 *
 * `null` når ingen måldato hadde både fasit og dekning — og det er et
 * ærlig svar, ikke en feil. Da vet vi ikke hvor godt den treffer.
 */
export function maalTreff(inn: Treffinput): Treffmaal | null {
  // FASIT PER DAG. En dag uten rad hoppes over: vi vet ikke om varen
  // ikke ble solgt eller ikke ble registrert (206 av 223 708 rader har
  // `antall = 0`), og en måling som gjetter null ville belønnet en
  // motor som alltid sier lite.
  const fasit = new Map<string, number>()
  for (const r of inn.salg) {
    if (r.stasjonId !== inn.enhet.stasjonId || r.ean !== inn.enhet.ean) continue
    fasit.set(r.dato, (fasit.get(r.dato) ?? 0) + r.antall)
  }

  const par: { forventet: number; faktisk: number }[] = []
  for (const d of inn.maaldatoer) {
    const f = fasit.get(d)
    if (f === undefined) continue
    const sv = forventetSalg({
      enhet: inn.enhet, maalDato: d, salg: inn.salg,
      modell: inn.modell, minstDagerMedSalg: inn.minstDagerMedSalg,
    })
    if (sv.slag !== 'beregnet') continue
    par.push({ forventet: sv.antall, faktisk: f })
  }
  if (par.length === 0) return null

  const feil = par.map((p) => Math.abs(p.forventet - p.faktisk))
  const sumFeil = feil.reduce((a, b) => a + b, 0)
  const sumFaktisk = par.reduce((a, p) => a + p.faktisk, 0)
  const sortert = [...feil].sort((a, b) => a - b)
  return {
    dager: par.length,
    mae: Math.round((sumFeil / par.length) * 10) / 10,
    medianFeil: sortert[Math.floor(sortert.length / 2)],
    wmape: sumFaktisk > 0 ? Math.round((sumFeil / sumFaktisk) * 1000) / 10 : null,
    bias: Math.round((par.reduce((a, p) => a + (p.forventet - p.faktisk), 0) / par.length) * 10) / 10,
    snittFaktisk: Math.round((sumFaktisk / par.length) * 10) / 10,
  }
}

/**
 * Hvor mye tillit tallet fortjener, som ett ord.
 *
 * GRENSENE ER LEST AV MÅLINGEN, IKKE VALGT. Backtesten ga 22–48 % på
 * samme vare over fem stasjoner, og hele utvalget lå på 50–72 %. Ordene
 * beskriver den fordelingen:
 *
 *   under 25 %   Dale-enden. Tallet kan brukes som det står.
 *   25–40 %      de tre i midten. Bruk tallet, men vit at det spriker.
 *   over 40 %    Bønes-enden. Tallet er en pekepinn, ikke et anslag.
 *
 * ORDENE ER IKKE ET INTERVALL. De sier noe om historikken, ikke om
 * hvor morgendagens tall kommer til å ligge.
 */
export type Tillit = 'god' | 'middels' | 'svak' | 'ukjent'

export function tillit(m: Treffmaal | null): Tillit {
  // FÅ DAGER ER IKKE GOD TREFFSIKKERHET. Har vi målt fire dager og
  // truffet perfekt, vet vi fortsatt ikke noe.
  if (!m || m.wmape == null || m.dager < 10) return 'ukjent'
  if (m.wmape < 25) return 'god'
  if (m.wmape <= 40) return 'middels'
  return 'svak'
}
