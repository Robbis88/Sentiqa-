// Bilvaskabonnementene kassa aldri ser.
//
// =====================================================================
// EN UKE ER IKKE EN MÅNED
//
// Rapporten kommer per uke, og uke 26 kan ligge halvt i juni og halvt i
// juli. Beløpet deles derfor på sju og fordeles per dag; hver måned får
// dagene sine.
//
// Lagres det som «uke 26 = juli», mister juni sin del og juli får for
// mye — i to måneder på rad, og i motsatt retning. En slik feil ser ut
// som sesong.
//
// ---------------------------------------------------------------------
// BARE BRUTTOBIDRAGET
//
// Omsetningen har sin egen bilvaskkolonne; det som mangler er de 75
// prosentene som er fortjeneste. Å legge beløpet inn to steder ville
// gjort ett hull til to tall som ikke stemmer.
//
// ---------------------------------------------------------------------
// BARE MÅNEDER SOM IKKE ER AVLAGT
//
// Regnskapet har allerede disse kronene når det kommer — det er derfor
// bilvask der alltid er høyere enn kassaomsetningen. Legges de inn i en
// avlagt måned, telles de to ganger. Samme asymmetri som fastlønn og
// sykelønn: regnskapet er komplett, det som mangler er underveis.
// Filtreringen hører hjemme hos den som kaller, som vet hvilke måneder
// som er avlagt.
// =====================================================================

/**
 * Hvor stor del av abonnementsbeløpet som er bruttofortjeneste.
 *
 * Oppgitt av Kelsar. Som satsene i `SATSER` er dette en driftsopplysning
 * som kan variere mellom kjeder — den blir konfigurasjon per retailer
 * den dagen kunde nummer to kommer.
 */
export const BILVASK_BRUTTOANDEL = 0.75

export type Ukebelop = { ar: number; uke: number; belopKr: number }

const iso = (d: Date) => d.toISOString().slice(0, 10)

/**
 * De sju datoene i en ISO-uke.
 *
 * ISO-UKE, IKKE «UKE SOM STARTER 1. JANUAR». Uke 1 er uka som
 * inneholder årets første torsdag, og den kan begynne i desember året
 * før. En uke som teller fra nyttår ville forskjøvet hele året med
 * inntil tre dager — og rapporten fra vaskeleverandøren er ISO.
 *
 * 4. januar ligger alltid i uke 1. Derfra finnes mandagen, og uke N er
 * N−1 uker etter den.
 */
export function ukensDager(ar: number, uke: number): string[] {
  const fjerde = new Date(Date.UTC(ar, 0, 4))
  // getUTCDay: 0 = søndag. ISO teller mandag som 1.
  const isoDag = fjerde.getUTCDay() === 0 ? 7 : fjerde.getUTCDay()
  const mandagUke1 = new Date(fjerde)
  mandagUke1.setUTCDate(fjerde.getUTCDate() - (isoDag - 1))

  const start = new Date(mandagUke1)
  start.setUTCDate(mandagUke1.getUTCDate() + (uke - 1) * 7)

  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start)
    d.setUTCDate(start.getUTCDate() + i)
    return iso(d)
  })
}

/**
 * Bruttobidraget per måned, av ukesbeløpene.
 *
 * Hver uke deles på sju og legges på dagen sin; dagene summeres per
 * måned. Summen over alle måneder er derfor alltid lik summen av
 * ukesbeløpene ganget med andelen — ingen kroner blir borte i skjøtene.
 *
 * Nøkkelen ut er `yyyy-mm`.
 */
export function bruttoPerMaaned(
  uker: Ukebelop[],
  andel = BILVASK_BRUTTOANDEL,
): Map<string, number> {
  const ut = new Map<string, number>()
  for (const u of uker) {
    const perDag = (u.belopKr * andel) / 7
    for (const dato of ukensDager(u.ar, u.uke)) {
      const m = dato.slice(0, 7)
      ut.set(m, (ut.get(m) ?? 0) + perDag)
    }
  }
  // Rundes til slutt, ikke per dag: syv sjuendedeler skal bli en hel.
  for (const [m, kr] of ut) ut.set(m, Math.round(kr * 100) / 100)
  return ut
}
