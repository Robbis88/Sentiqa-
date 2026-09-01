// =====================================================================
// EN CACHE UTEN INVALIDERING BLIR STILLE FEIL
//
// `uke_rapport` er ikke et view. Den skrives én gang per (stasjon, uke)
// og leses med `if (c) bruk cachen` — den regner aldri om. Da 25. august
// 2026 ble importert på nytt for Laguneparken, ble uka 24.–30. august
// stående med de gamle tallene: feil omsetning, feil bruttofortjeneste,
// feil avdelingsfordeling, og et AI-sammendrag skrevet på grunnlag av
// dem.
//
// Vi ryddet det opp for hånd én gang. Denne modulen gjør at vi slipper
// neste gang.
//
// ---------------------------------------------------------------------
// TO UKER, IKKE ÉN
//
// Ukerapporten sammenligner mot samme uke i fjor — `mandag - 364` dager,
// altså 52 uker, som treffer samme ukedager. Endres en dag i august
// 2025, er det ikke bare 2025-uka som blir gal: august 2026-uka bruker
// den som `omsetning_ifjor`, og den er like feil.
//
// Det er lett å glemme, fordi feilen viser seg et helt år unna dagen man
// rettet. Derfor returnerer denne funksjonen begge.
// =====================================================================

/** 52 uker, slik ukerapporten selv regner «samme uke i fjor». */
const ET_AAR_I_DAGER = 364

function iso(d: Date): string {
  return d.toISOString().slice(0, 10)
}

/** Mandagen i uka som inneholder datoen. */
export function mandagenI(dato: string): string {
  const d = new Date(`${dato}T12:00:00Z`)
  // getUTCDay: 0 = søndag. (dag + 6) % 7 gir avstanden bakover til mandag,
  // og gjør søndag til 6 i stedet for 0 — ellers ville søndag hoppet fram
  // til neste uke.
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7))
  return iso(d)
}

/**
 * Ukene som blir feil når denne datoen endres.
 *
 * Alltid to: uka datoen ligger i, og uka 52 uker senere — den som bruker
 * datoen som sitt fjorårstall.
 */
export function berorteUker(dato: string): string[] {
  const naa = mandagenI(dato)
  const nesteAar = new Date(`${naa}T12:00:00Z`)
  nesteAar.setUTCDate(nesteAar.getUTCDate() + ET_AAR_I_DAGER)
  return [naa, iso(nesteAar)]
}
