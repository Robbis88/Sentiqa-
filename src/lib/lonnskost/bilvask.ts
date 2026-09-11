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
// Omsetningen har sin egen bilvaskkolonne; det som mangler er
// bruttofortjenesten. Å legge beløpet inn to steder ville gjort ett hull
// til to tall som ikke stemmer.
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
 * =====================================================================
 * DENNE MODULEN SKAL TREFFE REGNSKAPET, IKKE SANNHETEN
 * =====================================================================
 *
 * Sto på 0,75 i lang tid, oppgitt av Kelsar. To ting gjorde den feil, og
 * de trekker i hver sin retning — derfor står begge skrevet her, så ingen
 * «retter» den tilbake med det ene halve argumentet.
 *
 * 1. ØKONOMISK er 0,75 for HØYT. Beløpet i ukesrapporten er det
 *    stasjonen får utbetalt: 90 kroner per gjennomkjøring. Såpen koster
 *    ~10,5 % av KASSEPRISEN, ikke av de 90 — og kasseprisene er 249–499.
 *    Ekte bruttoandel av de 90 blir da 71 % på det billigste programmet
 *    og 42 % på det dyreste.
 *
 * 2. MEN DET ER IKKE DET DENNE MODULEN MÅLER. Jobben her er å tette
 *    hullet fram til regnskapet kommer, og treffe det regnskapet vil
 *    vise. Regnskapet fører `21014 MASKINVASK APP` med **100 %
 *    bruttofortjeneste** — såpen havner på kasselinja `21010`, ikke på
 *    app-linja. Målt på Kelsar januar–juli 2026: salg 1 206 107,
 *    bruttofortjeneste 1 206 107, på alle fire stasjoner med vask.
 *
 * Modulen skal altså legge inn HELE beløpet. Med 0,75 underrapporterte
 * den bruttoen med en firedel hver måned som ikke var avlagt — og
 * lønnsrommet ble tilsvarende for stramt, hver eneste måned.
 *
 * At de ekte 42–71 prosentene ikke vises noe sted er et EGET hull, og det
 * hører hjemme i kostnadsbildet — ikke her, der det ville gjort at
 * tallene sluttet å stemme med regnskapet de skal forutsi.
 *
 * Som satsene i `SATSER` er dette en driftsopplysning som kan variere
 * mellom kjeder — den blir konfigurasjon per retailer den dagen kunde
 * nummer to kommer. En kjede som fører app-omsetningen MED varekost skal
 * ha sin egen andel her.
 */
export const BILVASK_BRUTTOANDEL = 1

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
