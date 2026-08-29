import { erDag, type Dag } from '@/lib/periode'

// =====================================================================
// MÅNEDENS BP, FORDELT PÅ DAGENE
//
// BP finnes bare per måned — `regnskapslinjer` har én rad per måned, per
// avdeling, per stasjon. Men spørsmålet en butikksjef stiller den 27.
// er «ligger jeg an til å klare måneden», og det krever et måltall for
// akkurat de dagene som har vært.
//
// ---------------------------------------------------------------------
// REGELEN
//
// **Månedens BP er tallet. Ukedagsmedianen fra fjoråret er formen.**
//
// Hver dag peker 364 dager tilbake — 52 uker, så en søndag alltid
// treffer en søndag. Månedens BP deles i forhold til MEDIANEN for
// ukedagen, ikke etter den enkelte fjorårsdagen.
//
// Vekstprosenten blir da et resultat man kan lese av, ikke noe som
// legges på. Dale august 2026: BP 1 606 922 mot et motpartsvindu på
// 1 511 354 = +6,3 %.
//
// ---------------------------------------------------------------------
// HVORFOR MEDIAN OG IKKE FJORÅRETS DAG
//
// To lørdager i Dales motpartsvindu var ikke i normal drift:
// `2025-08-16` gjorde 18 582 og `2025-08-30` gjorde 13 998, mot en
// lørdagsmedian på 38 308. Stengt, halv dag eller manglende import —
// hvilken vet vi ikke.
//
// Brukes dagene rå, ARVER august 2026 feilen: 15. og 29. august ville
// fått under 20 000 i måltall. Verre: de fire siste dagene i måneden
// peker alle på svake fjorårsdager, så den siste uka ville fått 62 440
// kr for lite — hvert år, uten at noe endret seg i driften.
//
// Og valget snur svaret. Samme 27 dager målt: rå fordeling sier 1,3 %
// BAK budsjett, median sier 3,1 % FORAN.
//
// Det er husets egen regel, allerede skrevet i Forklaringen på /salg:
// medianen, ikke snittet, fordi «normalen» ellers blir noe som aldri
// har skjedd. Se `motNormalen` i `./normalen`.
//
// ---------------------------------------------------------------------
// MEDIANEN LESER STASJONSTYPEN AV SEG SELV
//
// Dale er utfartsstasjon: søndagsmedianen er 82 731 mot tirsdagens
// 41 096. `stasjonstype` finnes som enum og brukes av
// produksjonsplanen — men fordelingen her trenger den ikke. Stasjonens
// eget fjorår sier allerede hvilke dager som bærer den.
//
// En ny kjede med andre ukedagsmønstre får derfor riktig fordeling fra
// første måned, uten et oppsettsteg.
// =====================================================================

/** Dager mellom en dag og motparten. 52 uker, så ukedagen holder. */
export const AAR_I_DAGER = 364

export type Dagsrad = { dato: string; omsetning: number }

export type Dagsbudsjett = {
  dato: Dag
  /** Dagen 364 døgn tilbake. Samme ukedag, per definisjon. */
  motpart: Dag
  /** Motpartens faktiske omsetning. Et FAKTUM — vises som det er. */
  ifjor: number
  /** Medianen for ukedagen i motpartsvinduet. Grunnlaget for fordelingen. */
  normal: number
  /** Månedens BP × normal / sum(normal). Summerer til BP på krona. */
  bp: number
}

/** `2026-08-14` → `2025-08-15`. Samme ukedag. */
export function motpartFor(dato: Dag): Dag {
  const d = new Date(`${dato}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - AAR_I_DAGER)
  return d.toISOString().slice(0, 10)
}

/** Alle dagene i måneden `maaned` (`YYYY-MM-01`), i rekkefølge. */
export function dageneI(maaned: string): Dag[] {
  const ar = Number(maaned.slice(0, 4))
  const mnd = Number(maaned.slice(5, 7))
  const antall = new Date(Date.UTC(ar, mnd, 0)).getUTCDate()
  const ut: Dag[] = []
  for (let i = 1; i <= antall; i++) {
    ut.push(`${maaned.slice(0, 7)}-${String(i).padStart(2, '0')}`)
  }
  return ut
}

/**
 * MOTPARTSVINDUET, som ikke er fjorårets måned.
 *
 * `2026-08-31` minus 364 er `2025-09-01` — riktig ukedag, men september.
 * Og `2025-08-01` brukes aldri av noen dag i august 2026. Vinduet er
 * `2025-08-02 .. 2025-09-01`.
 *
 * Spørres det om fjorårets måned i stedet, summerer ikke dagene til BP.
 * Avviket er lite nok til at ingen oppdager det, stort nok til å være
 * feil — og det er den verste kombinasjonen et budsjettall kan ha.
 */
export function motpartsvindu(maaned: string): { fra: Dag; til: Dag } {
  const dager = dageneI(maaned)
  return { fra: motpartFor(dager[0]), til: motpartFor(dager[dager.length - 1]) }
}

const ukedagFor = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay()

function median(t: number[]): number {
  if (t.length === 0) return 0
  const s = [...t].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

/**
 * Fordel `bpMaaned` på dagene i `maaned`.
 *
 * `ifjor` skal være motpartsvinduet — hentes med `motpartsvindu()`, ikke
 * med fjorårets måned.
 *
 * Er hele vinduet tomt (ny stasjon, ingen historikk), er det ingen form
 * å fordele etter, og hver dag får like mye. Det er ikke riktig, men det
 * er det ærligste et tomt grunnlag tillater — og alternativet, å la være
 * å vise BP, ville skjult at budsjettet finnes.
 */
export function fordelBp(
  maaned: string,
  bpMaaned: number,
  ifjor: Dagsrad[],
): Dagsbudsjett[] {
  const perDag = new Map<string, number>()
  for (const r of ifjor) {
    if (!erDag(r.dato)) continue
    perDag.set(r.dato, (perDag.get(r.dato) ?? 0) + r.omsetning)
  }

  const dager = dageneI(maaned).map((dato) => {
    const motpart = motpartFor(dato)
    return { dato, motpart, ifjor: perDag.get(motpart) ?? 0, ukedag: ukedagFor(dato) }
  })

  // MEDIANEN REGNES AV HELE VINDUET, ikke av dagene som ser normale ut.
  // Det er nettopp uteliggerne medianen er robust mot — å luke dem ut
  // først ville vært å løse problemet to ganger, og den andre gangen
  // ville krevd en terskel ingen kan begrunne.
  const normalFor = new Map<number, number>()
  for (let u = 0; u < 7; u++) {
    normalFor.set(u, median(dager.filter((d) => d.ukedag === u).map((d) => d.ifjor)))
  }

  const vekter = dager.map((d) => normalFor.get(d.ukedag) ?? 0)
  const sum = vekter.reduce((a, b) => a + b, 0)

  return dager.map((d, i) => ({
    dato: d.dato,
    motpart: d.motpart,
    ifjor: d.ifjor,
    normal: normalFor.get(d.ukedag) ?? 0,
    bp: sum > 0 ? (bpMaaned * vekter[i]) / sum : bpMaaned / dager.length,
  }))
}

/**
 * Hittil i måneden, mot BP og mot fjoråret.
 *
 * FJORÅRET HITTIL ER MOTPARTENE, ikke fjorårets 1.–27. Samme antall
 * dager er ikke samme ukedager: for Dale gir den naive sammenligningen
 * +8,3 % der den ukedagsjusterte gir +4,9 %. 3,4 prosentpoeng, bare fra
 * å telle feil dager.
 *
 * `salg` trenger bare inneholde dagene som har vært — det er nettopp de
 * som avgrenser «hittil».
 */
export function hittil(
  budsjett: Dagsbudsjett[],
  salg: Map<string, number>,
): {
  dager: number
  salg: number
  bp: number
  ifjor: number
  /** Der måneden lander om takten holder. Null når ingenting er målt. */
  landing: number | null
} {
  const gjort = budsjett.filter((d) => salg.has(d.dato))
  const s = gjort.reduce((a, d) => a + (salg.get(d.dato) ?? 0), 0)
  const b = gjort.reduce((a, d) => a + d.bp, 0)
  const f = gjort.reduce((a, d) => a + d.ifjor, 0)
  const igjen = budsjett.filter((d) => !salg.has(d.dato)).reduce((a, d) => a + d.bp, 0)

  return {
    dager: gjort.length,
    salg: s,
    bp: b,
    ifjor: f,
    // Takten er salg/BP hittil. Uten målte dager finnes ingen takt, og
    // en landing lik BP ville vært en påstand vi ikke har dekning for.
    landing: b > 0 ? s + igjen * (s / b) : null,
  }
}
