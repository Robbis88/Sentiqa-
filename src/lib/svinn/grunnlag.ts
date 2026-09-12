// =====================================================================
// HVILKET GRUNNLAG EN SVINNANALYSE LESER — ÉN REGEL, ETT STED
// =====================================================================
//
// `0208` ga tabellen to nivåer. Det er en grense, ikke en merkelapp:
// **grupperaden eier totalen, produktradene forklarer den**, og ingen
// analyse får summere begge. Gjorde den det, ville mat blitt regnet én
// gang som `120` og én gang som `12010 + 12020 + …`.
//
// ---------------------------------------------------------------------
// TO FASER, OG DERFOR ÉN REGEL SOM KJENNER BEGGE
//
// Produksjonsbasen har i dag **588 rader, alle produktrader**, uten
// `analyseomraade` — den gamle parseren tok bare `Prod`. Grupperadene
// kommer først med reimporten. Derfor kan ikke leserne bare filtrere på
// `nivaa = 'gruppe'`: da ville hver måned bli tom til den var
// reimportert, og det er nøyaktig fella som tømte månedsplanene før.
//
//   FØR reimport    produktradene ER grunnlaget. Tallene skal være
//                   identiske med dagens produksjon, til øret.
//   ETTER reimport  grupperaden eier totalen. Produktradene brukes bare
//                   til drilldown.
//
// Valget tas per **stasjonsmåned**, ikke per kjede: to stasjoner kan
// ligge i ulik fase midt i en reimport, og da skal hver av dem regnes på
// sitt eget grunnlag. Aldri begge samtidig, aldri en blanding.
//
// `datastatus` følger svaret ut, så flaten kan si hvilket grunnlag den
// viser. En analyse som ikke kan si det, kan ikke etterprøves.
//
// ---------------------------------------------------------------------
// FALLBACKEN ER MIDLERTIDIG, OG DET SKAL STÅ SKREVET
//
// `eldre_grunnlag` er sant i dag og skal bli usant. Når alle perioder er
// reimportert, strammes regelen: da er en manglende grupperad et funn,
// ikke en fase. `grunnlag.test.ts` har en kanarifugl for den dagen.
// Fallbacken skal ikke få skjule en ufullstendig import permanent.
//
// ---------------------------------------------------------------------
// ARKETS NAVN MOT BASENS VERDIER
//
// Robert 2026-09-12 skrev regelen som `nivaa = 'ProdGr3'`. Det er arkets
// egen typebetegnelse i kolonne 2. Basen lagrer den normalisert:
// `'gruppe'` og `'produkt'`, med `check (nivaa in ('gruppe','produkt'))`
// i `0208`. Et filter på `'ProdGr3'` ville truffet **null rader, i
// stillhet**. Mappingen står i `ARKTYPE` og brukes i rapportering, så
// ingen skriver arkets navn inn i et predikat igjen.
// =====================================================================

import type { Nivaa } from './nivaa'

/** Arkets typenavn for hvert basenivå. Rapportering, aldri predikat. */
export const ARKTYPE: Record<Nivaa, string> = {
  gruppe: 'ProdGr3',
  produkt: 'Prod',
}

/**
 * Hvilket grunnlag en stasjonsmåned faktisk ble regnet på.
 *
 *   gruppe          grupperaden eier totalen. Målet.
 *   eldre_grunnlag  ingen grupperad ennå — produktradene brukes.
 *   utilgjengelig   ingen rader i det hele tatt, eller ingen med de
 *                   feltene analysen krever. **Ikke 0.**
 */
export type Datastatus = 'gruppe' | 'eldre_grunnlag' | 'utilgjengelig'

/** Minimum en rad må bære for at regelen kan plassere den. */
export type Grunnlagsrad = {
  nivaa: string | null
  analyseomraade: string | null
}

export type Grunnlagsvalg<T> = {
  /** `null` bare når status er `utilgjengelig`. */
  grunnlag: Nivaa | null
  datastatus: Datastatus
  /** Menneskelesbar årsak. Følger med ut i flaten. */
  aarsak: string
  /** Radene analysen skal regne på. Aldri begge nivåer. */
  rader: T[]
}

/**
 * Er raden butikk, eller en gammel rad vi ikke kan plassere?
 *
 * `null` er de 588 eksisterende radene: `0208` etterfylte `nivaa`, men
 * IKKE `analyseomraade`, fordi det krever gruppekodene fra arket. De
 * skal fortsatt regnes med i fase 1 — ellers ville migrasjonen endret
 * tall, og den er additiv med vilje.
 *
 * `drivstoff` og `ukjent` faller ut: de er navngitt og blokkert.
 */
export function iGrunnlaget(r: Grunnlagsrad): boolean {
  return r.analyseomraade === 'butikk' || r.analyseomraade == null
}

/**
 * Velg grunnlag for ÉN stasjonsmåned.
 *
 * Kall aldri denne på et blandet utvalg over flere stasjoner eller
 * måneder — bruk `velgGrunnlagPerNoekkel`. Ligger to stasjoner i ulik
 * fase, ville ett felles valg regnet den ene på feil nivå.
 */
export function velgGrunnlag<T extends Grunnlagsrad>(rader: readonly T[]): Grunnlagsvalg<T> {
  const iSpill = rader.filter(iGrunnlaget)
  const grupperader = iSpill.filter((r) => r.nivaa === 'gruppe')

  if (grupperader.length > 0) {
    return {
      grunnlag: 'gruppe',
      datastatus: 'gruppe',
      aarsak: `Grupperaden eier totalen (${grupperader.length} ProdGr3-rader).`,
      rader: grupperader,
    }
  }

  // `nivaa == null` finnes ikke etter `0208` sin etterfylling, men
  // regelen tåler det: en rad uten nivå er en produktrad her, fordi den
  // gamle parseren ikke kunne lage annet.
  const produktrader = iSpill.filter((r) => r.nivaa === 'produkt' || r.nivaa == null)
  if (produktrader.length > 0) {
    return {
      grunnlag: 'produkt',
      datastatus: 'eldre_grunnlag',
      aarsak: 'Ingen grupperad for perioden ennå — regnet på produktradene, som før reimport.',
      rader: produktrader,
    }
  }

  return {
    grunnlag: null,
    datastatus: 'utilgjengelig',
    aarsak: 'Ingen svinnrader for perioden. Ikke nok datagrunnlag.',
    rader: [],
  }
}

/**
 * Samme regel, anvendt per nøkkel — typisk `stasjon|periode`.
 *
 * Returnerer ett valg per nøkkel, og `alleRader` er unionen av det hvert
 * valg landet på. Den kan derfor summeres trygt: et grunnlag er valgt
 * innenfor hver stasjonsmåned, og de to nivåene møtes aldri.
 */
export function velgGrunnlagPerNoekkel<T extends Grunnlagsrad>(
  rader: readonly T[],
  noekkel: (r: T) => string,
): { perNoekkel: Map<string, Grunnlagsvalg<T>>; alleRader: T[]; samletStatus: Datastatus } {
  const bunter = new Map<string, T[]>()
  for (const r of rader) {
    const k = noekkel(r)
    const b = bunter.get(k)
    if (b) b.push(r)
    else bunter.set(k, [r])
  }

  const perNoekkel = new Map<string, Grunnlagsvalg<T>>()
  const alleRader: T[] = []
  for (const [k, b] of bunter) {
    const valg = velgGrunnlag(b)
    perNoekkel.set(k, valg)
    alleRader.push(...valg.rader)
  }

  return { perNoekkel, alleRader, samletStatus: samlet([...perNoekkel.values()]) }
}

/**
 * Status for et sett stasjonsmåneder.
 *
 * **Den svakeste vinner.** Er én stasjonsmåned på eldre grunnlag, er
 * summen på eldre grunnlag — ellers ville et kjedetall sett ferdig ut
 * mens en av stasjonene lå i forrige fase.
 */
export function samlet(valg: readonly Grunnlagsvalg<unknown>[]): Datastatus {
  if (valg.length === 0) return 'utilgjengelig'
  if (valg.some((v) => v.datastatus === 'utilgjengelig')) return 'utilgjengelig'
  if (valg.some((v) => v.datastatus === 'eldre_grunnlag')) return 'eldre_grunnlag'
  return 'gruppe'
}

// =====================================================================
// KASTPROSENT: NEVNEREN KAN MANGLE, OG DA FINNES INGEN PROSENT
// =====================================================================
//
// Målt i produksjon: **Laguneparken april, `16015 KAMPANJE`** har
// salg 0, usynlig 0 og **kast 3 655,42**. Den gamle parseren kastet
// raden (`usynligKr === 0 && salg === 0`), så beløpet fantes ikke i
// basen i det hele tatt.
//
// Raden skal lagres og vises. Men prosenten finnes ikke:
//
//   3 655,42 / 0   er ikke 0, og det er ikke uendelig. Det er et
//                  regnestykke som ikke har et svar.
//
// Derfor returneres `null` med en status, ikke et tall. Ingen retning
// utledes, og «ingen kast» skal aldri stå på en rad med kast.

// `tekst` staar paa BEGGE utfall, ikke bare det ene. En union ville
// tvunget hver leser til aa narrowe foer den kan vise begrunnelsen, og
// da er snarveien aa skrive `?? 0` i stedet. Et tall uten begrunnelse er
// nettopp det denne regelen finnes for aa hindre.
// TRE UTFALL, OG DE ER IKKE DET SAMME:
//
//   ok               0 % kast MED gyldig positivt salg. Et ekte tall.
//   ikke_beregnbar   salget er 0. Broeken har ingen verdi.
//   mangler_data     kasttallet finnes ikke i det hele tatt.
//
// Alle tre er blitt til «0» i systemer foer. `pst` er derfor `null` i to
// av dem, og `null` er ikke et tall man kan runde, sortere eller
// sammenligne ved et uhell.
export type Kastprosent = {
  /** `null` = finnes ikke. ALDRI 0 som stand-in. */
  pst: number | null
  status: 'ok' | 'ikke_beregnbar' | 'mangler_data'
  tekst: string
}

export function kastprosent(kastKr: number | null, salgKr: number | null): Kastprosent {
  if (kastKr == null) {
    return { pst: null, status: 'mangler_data', tekst: 'Kasttall mangler for perioden.' }
  }
  if (salgKr != null && salgKr > 0) {
    // 0 % kast med ekte salg ER et tall, og skal se ut som et tall.
    return { pst: Math.round((kastKr / salgKr) * 1000) / 10, status: 'ok', tekst: '' }
  }
  if (salgKr == null) {
    return { pst: null, status: 'mangler_data', tekst: 'Salgstall mangler for perioden.' }
  }
  if (kastKr === 0) {
    return {
      pst: null,
      status: 'ikke_beregnbar',
      tekst: 'Ingen salg og ingen kast registrert i perioden.',
    }
  }
  return {
    pst: null,
    status: 'ikke_beregnbar',
    tekst: 'Kast registrert uten registrert salg i samme periode.',
  }
}

/** Hva flaten viser. Den underliggende verdien er og blir `null`. */
export function kastprosentTekst(k: Kastprosent): string {
  return k.status === 'ok' ? `${k.pst!.toFixed(1)} %` : 'Ikke beregnbar'
}

// =====================================================================
// DESEMBER 2025: UTILGJENGELIG, IKKE NULL
// =====================================================================
//
// Desemberfila (`202512-202512_3.xlsx`, 195 rader) er i et eldre
// rapportformat og har ingen svinnrader i det hele tatt — kvitteringen
// fra `0208` sier `eldste = 2026-01-01`. Reimport kan ikke gi den
// teoretisk BF; feltene finnes ikke i kilden.
//
// En analyse som krever teoretisk BF skal derfor **blokkere** desember
// med årsak, og serien skal starte i januar 2026. Et nullpunkt i
// desember ville gjort «ingen data» til «ingenting skjedde», og hver
// retning ut av desember ville vært oppdiktet.
//
// Andre serier — BP, omsetning, resultat — har sine egne data i
// desember og røres ikke av dette.

export const AARSAK_ELDRE_FORMAT =
  'Eldre rapportformat uten nødvendig datagrunnlag for denne analysen.'

export type Feltkrav = 'teoretisk_kr' | 'bf_kr' | 'kast' | 'usynlig_kr'

export type Periodestatus = {
  periode: string
  datastatus: Datastatus
  aarsak: string
}

/**
 * Har perioden feltene analysen krever?
 *
 * Brukes av analyser som leser teoretisk BF, identiteten eller
 * kontrollberegningen. Mangler feltet i ALLE rader, er perioden
 * utilgjengelig — ikke null, og ikke et startpunkt for en retning.
 */
export function periodeHarFelt<T extends Record<string, unknown>>(
  rader: readonly T[],
  felt: Feltkrav,
): boolean {
  return rader.some((r) => r[felt] != null)
}

export function periodestatus<T extends Record<string, unknown>>(
  periode: string,
  rader: readonly T[],
  felt: Feltkrav,
): Periodestatus {
  if (rader.length === 0) {
    return { periode, datastatus: 'utilgjengelig', aarsak: AARSAK_ELDRE_FORMAT }
  }
  if (!periodeHarFelt(rader, felt)) {
    return {
      periode,
      datastatus: 'utilgjengelig',
      aarsak: `${AARSAK_ELDRE_FORMAT} Mangler «${felt}».`,
    }
  }
  return { periode, datastatus: 'gruppe', aarsak: '' }
}

/**
 * Første periode i en SAMMENHENGENDE serie som har feltet.
 *
 * Retning måles aldri ut av en blokkert periode. Er desember blokkert og
 * januar hel, starter serien i januar — og det skal stå i svaret, ikke
 * regnes som et fall fra null.
 */
export function serieStart(statuser: readonly Periodestatus[]): string | null {
  const sortert = [...statuser].sort((a, b) => a.periode.localeCompare(b.periode))
  let start: string | null = null
  for (const s of sortert) {
    if (s.datastatus === 'utilgjengelig') { start = null; continue }
    if (start == null) start = s.periode
  }
  return start
}
