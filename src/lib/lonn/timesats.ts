// =====================================================================
// Timesatsen slik den skrives inn.
//
// Egen modul framfor et zod-skjema inne i serverhandlingen, fordi 'use
// server' bare kan eksportere async funksjoner — og et regelsett som
// ikke lar seg teste, blir før eller siden testet i produksjon.
//
// Satsen brukes ikke til å regne ut lønn. Visma-fila bærer timer, og
// Azets holder satsene. Den står her som KONTROLL: uten den ser ingen at
// Helene ligger 15,44 under laveste voksensats i Energiavtalen.
// =====================================================================

/** Øvre grense, samme som databasens sjekk. Over dette er det en skrivefeil. */
const MAKS = 2000

export type Satssvar =
  | { ok: true; verdi: number | null }
  | { ok: false; feil: string }

/**
 * Leser en timesats fra et skjemafelt.
 *
 * Komma godtas: 196,02 er slik den står på lønnsslippen, og et felt som
 * avviser skrivemåten folk faktisk bruker blir stående tomt.
 *
 * Tomt felt gir null — det fjerner satsen igjen. Uten den veien ut er en
 * feiltasting permanent, og da tør ingen skrive noe i det hele tatt.
 */
export function lesTimesats(raa: unknown): Satssvar {
  if (typeof raa !== 'string') return { ok: false, feil: 'Ugyldig verdi.' }
  const tekst = raa.trim().replace(',', '.')
  if (tekst === '') return { ok: true, verdi: null }

  const tall = Number(tekst)
  if (!Number.isFinite(tall)) {
    return { ok: false, feil: 'Timesatsen må være et tall, for eksempel 196,02.' }
  }
  if (tall <= 0) return { ok: false, feil: 'Timesatsen må være over null.' }
  if (tall >= MAKS) {
    return { ok: false, feil: `Timesatsen må være under ${MAKS} — er det en månedslønn?` }
  }
  // To desimaler. Satsene oppgis i kroner og øre, og en flyttallsrest
  // fra 196,019999 ville dukket opp igjen i tariffsammenligningen.
  return { ok: true, verdi: Math.round(tall * 100) / 100 }
}
