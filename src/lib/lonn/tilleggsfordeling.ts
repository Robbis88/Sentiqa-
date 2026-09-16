// Hvilke lønnsarter en vakt utløser.
//
// =====================================================================
// SATSENE LIGGER I `tilleggssats.ts`. HER LIGGER KLOKKESLETTENE.
//
// `tilleggssats.ts` vet hva en time under art 1434 koster. Den vet ikke
// hvilke timer som ER 1434. Det avgjøres av når på døgnet og hvilken
// dag arbeidet skjedde, og det er denne fila.
//
// ---------------------------------------------------------------------
// REGLENE ER MÅLT MOT KRONEFILA, IKKE LEST AV OVERENSKOMSTEN
//
// Samme innsats som satsene. Fordelingen ble holdt mot Lønnsoversikt
// for Bønes juli 2026, linje for linje: 199 av 200 innenfor 0,02 timer.
// Den ene bommen var overtid, som denne fila med vilje ikke rører.
//
// `tilleggsfordeling.test.ts` gjør målingen om til en påstand.
//
// ---------------------------------------------------------------------
// DØGNGRENSEN ER EKTE
//
// En vakt 23:00–07:00 er søndag kveld OG mandag natt, med hver sin art.
// Derfor går vi minutt for minutt gjennom intervallet i stedet for å se
// på hvilken dag vakten startet. Det er tregere og det er riktig.
//
// ---------------------------------------------------------------------
// HELLIGDAG ERSTATTER, DEN KOMMER IKKE I TILLEGG
//
// MÅLT mot Dale mai 2026. På 1., 14., 17., 24. og 25. mai står KUN
// «2 Timelønn» og «1410 Helligdagsgodtgjørelse», med identisk timetall,
// og ingen 1429/1430/1431/1434/1435. 17. mai er en søndag og får
// likevel ingen søndagstillegg.
//
// Mandag 18. mai — en helt vanlig dag i samme fil — har tilleggene som
// normalt. Det er den kontrasten som gjør dette til en regel og ikke et
// sammentreff.
//
// ---------------------------------------------------------------------
// PINSEAFTEN BEGYNNER KL. 15. DE ANDRE AFTENENE ER IKKE MÅLT.
//
// MÅLT samme sted: pinseaften 23. mai er ikke helligdag, men kronefila
// gir 1410 likevel, og grensen er skarp. En vakt 09:00–15:57 fikk
// 1410 = 0,96 t — nøyaktig fra kl. 15. Tre vakter som startet kl. 15
// eller senere fikk 1410 for HELE vakten, og ingen av dem fikk
// lørdagstillegg.
//
// Lørdag 16. mai — dagen før 17. mai — fikk derimot helt vanlig 1432.
// Regelen gjelder altså IKKE enhver dag før en helligdag.
//
// PÅSKEAFTEN, JULAFTEN OG NYTTÅRSAFTEN STÅR DERFOR IKKE HER. Vi har
// kronefil for mai, juli og august 2026; ingen av dem inneholder de
// dagene. Skal de inn, må de måles mot en kronefil fra april eller
// desember — ikke utledes av at pinseaften oppfører seg slik.
// =====================================================================

/** Lønnsarten som bærer selve timene. Tilleggene teller de samme på nytt. */
export const TIMEART = '2'

/** Helligdagsgodtgjørelse. Dobler timesatsen og slår ut de andre tilleggene. */
export const HELLIGDAGSART = '1410'

const DOEGN = 86_400_000

/**
 * Påskedagen, som alle de bevegelige helligdagene måles fra.
 *
 * Regnestykket er bekreftet av dataene, ikke bare av almanakken: Kristi
 * himmelfart faller 39 dager etter, pinse 49 og 50 — og easy@work
 * betalte 1410 på nøyaktig de dagene i mai 2026.
 */
function paaske(aar: number): number {
  const a = aar % 19
  const b = Math.floor(aar / 100)
  const c = aar % 100
  const d = Math.floor(b / 4)
  const e = b % 4
  const f = Math.floor((b + 8) / 25)
  const g = Math.floor((b - f + 1) / 3)
  const h = (19 * a + b - d - g + 15) % 30
  const i = Math.floor(c / 4)
  const k = c % 4
  const l = (32 + 2 * e + 2 * i - h - k) % 7
  const m = Math.floor((a + 11 * h + 22 * l) / 451)
  const mnd = Math.floor((h + l - 7 * m + 114) / 31)
  const dag = ((h + l - 7 * m + 114) % 31) + 1
  return Date.UTC(aar, mnd - 1, dag)
}

const iso = (ms: number): string => new Date(ms).toISOString().slice(0, 10)

const helligCache = new Map<number, Set<string>>()

/**
 * Helligdagene et år.
 *
 * TO TING MED ULIK STYRKE, OG DE MÅ IKKE BLANDES.
 *
 *   REGELEN er målt: på en helligdag betaler easy@work `2` + `1410` og
 *   INGEN andre tillegg. Observert på fem dager i Dale mai 2026, med
 *   mandag 18. mai som kontrast.
 *
 *   LISTEN er MODELLERT, ikke en slutning fra dataene. Den har TOLV
 *   unike dager i 2026. Fem av dem er direkte målt mot Easy@Work:
 *   1., 14., 17., 24. og 25. mai. De sju andre — nyttårsdag,
 *   skjærtorsdag, langfredag, 1. og 2. påskedag samt 1. og 2. juledag —
 *   er ikke direkte målt; vi har ingen kronefil fra de månedene.
 *
 * Å bruke en målt regel på en modellert kalender er noe annet enn å
 * gjette en ny regel. Men skulle en påskemåned vise seg å oppføre seg
 * annerledes, er det HER det står feil — ikke i regelen.
 *
 * TRE NIVÅER SOM IKKE ER DET SAMME: regel implementert, regel støttet
 * av ekstern norm, regel empirisk målt mot Easy. Her sto det tidligere
 * «LISTEN er norsk lov» — en formulering som kan leses som at Easys
 * 1410-behandling på de dagene er verifisert. Den er ikke det.
 *
 * Aftenene er en helt annen sak og ligger i `helgaftener`: der er bare
 * den ene målte dagen med.
 */
function helligdager(aar: number): Set<string> {
  const truffet = helligCache.get(aar)
  if (truffet) return truffet
  const p = paaske(aar)
  const s = new Set([
    `${aar}-01-01`,
    ...[-3, -2, 0, 1, 39, 49, 50].map((n) => iso(p + n * DOEGN)),
    `${aar}-05-01`,
    `${aar}-05-17`,
    `${aar}-12-25`,
    `${aar}-12-26`,
  ])
  helligCache.set(aar, s)
  return s
}

const aftenCache = new Map<number, Set<string>>()

/**
 * Aftener der helligdagen begynner kl. 15.
 *
 * BARE PINSEAFTEN — den eneste som er målt. Se toppen av fila.
 */
function helgaftener(aar: number): Set<string> {
  const truffet = aftenCache.get(aar)
  if (truffet) return truffet
  const s = new Set([iso(paaske(aar) + 48 * DOEGN)])
  aftenCache.set(aar, s)
  return s
}

export const erHelligdag = (dato: string): boolean =>
  helligdager(Number(dato.slice(0, 4))).has(dato)

export const erHelgaften = (dato: string): boolean =>
  helgaftener(Number(dato.slice(0, 4))).has(dato)

/** Timen da helligdagstillegget begynner på en helgaften. */
export const AFTEN_FRA_TIME = 15

/**
 * Arten en gitt time på en gitt ukedag utløser.
 *
 * `null` betyr ingen tillegg — bare timelønn. Helligdag håndteres av
 * `fordelVakt`, ikke her, fordi den overstyrer hele oppslaget.
 */
function tilleggsart(ukedag: number, time: number): string | null {
  if (ukedag === 0) {
    if (time < 6) return '1433' // søndag 00-06
    if (time < 18) return '1434' // søndag 06-18
    return '1435' // søndag 18-24
  }
  if (ukedag === 6) {
    // «Lørdag natt og formiddag har ikke tillegg» — se `tilleggssats.ts`,
    // der bare lørdag 18-24 har en sats.
    //
    // IKKE BEKREFTET: natten 00-06 behandles som hverdagsnatt. Ingen av
    // de fem målte stasjonsmånedene motbeviser det, og ingen bekrefter
    // det heller. Dukker det opp en kronefil med lørdagsnattarbeid, er
    // dette første sted å se etter.
    if (time < 6) return '1431'
    if (time < 18) return null
    return '1432' // lørdag 18-24
  }
  if (time < 6) return '1431' // hverdag 00-06
  if (time < 18) return null
  if (time < 21) return '1429' // hverdag 18-21
  return '1430' // hverdag 21-24
}

/**
 * Fordeler en vakt på lønnsarter.
 *
 * @param fraDato datoen arbeidet BEGYNTE — ikke forretningsdatoen. En
 *   vakt som starter 1. august er mandag selv om easy@work fører den på
 *   søndag 31. juli.
 * @param minutter vaktens lengde, som parseren har regnet den ut OG
 *   kontrollert mot `Lengde`-kolonnen. Den regnes med vilje IKKE på nytt
 *   her: to steder som utleder samme tall av samme klokkeslett er to
 *   steder som kan skille lag. «16:00–16:00» er null minutter, ikke et
 *   døgn, og den regelen skal bo ett sted.
 * @returns art → timer. Timelønn ligger under `TIMEART` og bærer hele
 *   vakten; tilleggene teller de samme minuttene på nytt, hver under sin
 *   art. Summen av tilleggene er derfor IKKE vaktens lengde.
 */
export function fordelVakt(
  fraDato: string,
  fraTid: string,
  minutter: number,
): Map<string, number> {
  const [Y, M, D] = fraDato.split('-').map(Number)
  const [fh, fm] = fraTid.split(':').map(Number)
  const start = Date.UTC(Y, M - 1, D, fh, fm)

  const ut = new Map<string, number>()
  const legg = (art: string, timer: number) =>
    ut.set(art, (ut.get(art) ?? 0) + timer)

  if (minutter <= 0) return ut
  legg(TIMEART, minutter / 60)

  for (let i = 0; i < minutter; i++) {
    const t = new Date(start + i * 60_000)
    const dag = t.toISOString().slice(0, 10)
    if (erHelligdag(dag)) { legg(HELLIGDAGSART, 1 / 60); continue }
    if (erHelgaften(dag) && t.getUTCHours() >= AFTEN_FRA_TIME) {
      legg(HELLIGDAGSART, 1 / 60)
      continue
    }
    const art = tilleggsart(t.getUTCDay(), t.getUTCHours())
    if (art) legg(art, 1 / 60)
  }
  return ut
}
