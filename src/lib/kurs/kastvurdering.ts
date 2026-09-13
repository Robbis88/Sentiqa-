// Synlig matkast målt mot et omsetningsjustert budsjett.
//
// =====================================================================
// KRONER ER FEIL MÅLESTOKK
// =====================================================================
//
// `serieFor('matkast')` returnerte nominelle kastkroner, og
// `loftestenger.ts` sier `god: 'ned'`. En stasjon som vokser i
// matomsetning får derfor stigende kastkroner og blir fortalt at det går
// feil vei — selv når andelen faller.
//
// Målt over Kelsars januar–juli 2026 gir de to målestokkene MOTSATT svar
// på tre av fem stasjoner:
//
//   Lone         kroner opp   (+7 252)   prosent ned   (−2,23 pp)
//   Varden       kroner flat  (−232)     prosent ned   (−1,85 pp)
//   Laguneparken kroner opp   (+9 434)   prosent flat  (+0,32 pp)
//
// I dag ville Lone fått matkast-tiltaket fordi kronene stiger mest. Lone
// ligger under budsjett fem av sju måneder. Den som faktisk trenger
// tiltaket er Bønes: 19,33 % mot 13,59 % budsjettert i juli.
//
// ---------------------------------------------------------------------
// NIVÅ OG RETNING ER TO SPØRSMÅL
//
//   NIVÅ     = kastavvik_pstpoeng denne måneden. Over eller under.
//   RETNING  = trenden i faktisk kastprosent. Bedre eller verre.
//
// De er uavhengige, og begge vises. Høyt nivå og god retning kan
// eksistere samtidig — Dale er nettopp det, fire ugunstige måneder og en
// klar forbedring.
//
// **Tiltaket styres av nivået.** Retningen forklarer, den frikjenner
// ikke. En stasjon over budsjett slipper ikke unna fordi trenden er
// svakt bedre, og en stasjon under budsjett får ikke tiltak fordi siste
// måned steg.
//
// ---------------------------------------------------------------------
// SATSEN LESES, DEN SKRIVES IKKE INN
//
// `kastbudsjett.kast_pst_av_salg`, per `stasjon_id` og `ar`. Lagret som
// andel: 6,232289968 % er `0.06232289968`. Ingen sats hører hjemme i
// denne fila — `satsTest` i testene er en fasit, ikke en kilde.

import { type Kurs, retning } from './retning'

/** Budsjettsatsen for én stasjon og ett år, slik `kastbudsjett` bærer den. */
export type Kastsats = {
  stasjonId: string
  aar: number
  /** Andel av OMSETNING, ikke av varekost. `0.06232289968`. */
  andel: number
  /** `avdeling` (Mat-totalen) eller `vareomrade`. */
  nivaa: string
}

export type Kastmaaned = {
  maaned: string
  matsalgKr: number
  matkastKr: number | null
  harSvinndata: boolean
  datastatus: string | null
}

// =====================================================================
// CONFIDENCE GATE
// =====================================================================
//
// Ni porter. Den første som slår, vinner — og årsaken følger med ut, så
// flaten kan si hvorfor og ikke bare at.
//
// MANGLER DATA -> «Datagrunnlag mangler», ALDRI 0. En null er et svar om
// virkeligheten; en manglende måling er et svar om oss.

export type Portnavn =
  | 'matomsetning' | 'kast' | 'budsjettsats' | 'avstemming' | 'datastatus'
  | 'kodemapping' | 'forbehold' | 'hull' | 'stasjonsidentitet'

export type Gate =
  | { kanKonkludere: true }
  | { kanKonkludere: false; port: Portnavn; aarsak: string }

export type Gateinput = {
  maaned: Kastmaaned
  sats: Kastsats | null
  /** `false` når svinnarket for perioden ikke er avstemt. */
  avstemt: boolean
  /** `false` når den historiske kodemappingen ikke er verifisert. */
  kodemappingSikker: boolean
  /** Teksten fra `forbehold.ts`, eller `null` når ingen gjelder. */
  forbehold: string | null
  /** Fra `svinnserie()`: årsaken til at serien ikke kan brukes. */
  serieblokkering: string | null
  /** `false` når stasjonens identitet ikke er bevist. */
  stasjonBevist: boolean
}

/** Teksten flaten viser når en port slår. Aldri et tall. */
export const MANGLER = 'Datagrunnlag mangler'

export function gate(i: Gateinput): Gate {
  const m = i.maaned

  // 1 MATOMSETNING. Nevneren. Uten den er prosenten ikke definert, og
  //   en 0-nevner ville gitt Infinity eller NaN ut i flaten.
  if (!Number.isFinite(m.matsalgKr) || m.matsalgKr <= 0) {
    return { kanKonkludere: false, port: 'matomsetning', aarsak: 'Matomsetning mangler for perioden.' }
  }

  // 2 KAST. `harSvinndata` er autoriteten, ikke verdien: 0 med grunnlag
  //   er null kroner, 0 uten grunnlag er en oppdiktet perfekt måned.
  if (!m.harSvinndata || m.matkastKr === null) {
    return { kanKonkludere: false, port: 'kast', aarsak: 'Kasttall mangler for perioden.' }
  }

  // 3 BUDSJETTSATSEN. Uten den finnes det ingenting å måle mot, og et
  //   avvik mot 0 % ville gjort hver stasjon katastrofal.
  if (!i.sats || !(i.sats.andel > 0)) {
    return { kanKonkludere: false, port: 'budsjettsats', aarsak: 'Kastbudsjett er ikke lastet opp for året.' }
  }

  // 4 AVSTEMMINGEN. Et uavstemt svinnark kan ha en identitet som ikke
  //   går opp, og da er kasttallet ikke ferdig.
  if (!i.avstemt) {
    return { kanKonkludere: false, port: 'avstemming', aarsak: 'Svinnarket for perioden er ikke avstemt.' }
  }

  // 5 DATASTATUS. `eldre_grunnlag` er produktrader uten grupperad -
  //   tallet er brukbart, men ikke sammenlignbart med gruppenivå.
  if (m.datastatus !== 'gruppe') {
    return {
      kanKonkludere: false, port: 'datastatus',
      aarsak: `Eldre datagrunnlag for perioden (${m.datastatus ?? 'ukjent'}).`,
    }
  }

  // 6 KODEMAPPINGEN. St1 renummererte kontokodene i februar 2026.
  if (!i.kodemappingSikker) {
    return { kanKonkludere: false, port: 'kodemapping', aarsak: 'Kodemappingen for perioden er ikke verifisert.' }
  }

  // 7 FORBEHOLD. Fra `forbehold.ts`, dimensjonert per periode, stasjon
  //   og analyse. Juni treffer resultat og brutto - ikke mat og svinn.
  if (i.forbehold) {
    return { kanKonkludere: false, port: 'forbehold', aarsak: i.forbehold }
  }

  // 8 HULL. Fra `svinnserie()`. Nivået kunne vært vist, men retningen
  //   ikke - og en konklusjon uten retning er et tall uten retning.
  if (i.serieblokkering) {
    return { kanKonkludere: false, port: 'hull', aarsak: i.serieblokkering }
  }

  // 9 STASJONSIDENTITETEN. Satsen kobles paa NAVN i delingsfil-importen,
  //   fordi fila ikke baerer butikknummer. Kan vi ikke bevise hvilken
  //   stasjon satsen hoerer til, skal ingenting konkluderes.
  if (!i.stasjonBevist) {
    return { kanKonkludere: false, port: 'stasjonsidentitet', aarsak: 'Stasjonsidentiteten er ikke verifisert.' }
  }

  return { kanKonkludere: true }
}

// =====================================================================
// BEREGNINGEN
// =====================================================================

export type Kasttall = {
  maaned: string
  matsalgKr: number
  synligKastKr: number
  /** `100 * synlig / matomsetning`. */
  faktiskPst: number
  budsjettPst: number
  /** `matomsetning * budsjettandel`. */
  justertBudsjettKr: number
  /** `synlig − justert`. Negativt er gunstig. */
  avvikKr: number
  /** `faktisk − budsjett`. Negativt er gunstig. */
  avvikPstpoeng: number
  gunstig: boolean
}

export function kasttall(m: Kastmaaned, sats: Kastsats): Kasttall {
  const salg = m.matsalgKr
  const kast = m.matkastKr as number
  const budsjettPst = sats.andel * 100
  const justert = salg * sats.andel
  const faktisk = (kast / salg) * 100
  return {
    maaned: m.maaned,
    matsalgKr: salg,
    synligKastKr: kast,
    faktiskPst: faktisk,
    budsjettPst,
    justertBudsjettKr: justert,
    avvikKr: kast - justert,
    avvikPstpoeng: faktisk - budsjettPst,
    // `<= 0` og ikke `< 0`: eksakt på budsjett er ikke et avvik.
    gunstig: kast - justert <= 0,
  }
}

// =====================================================================
// DOMMEN
// =====================================================================

export type Slag = 'tiltak' | 'bekreftelse' | 'observer'

export type Kastdom = {
  slag: Slag
  naa: Kasttall
  /** `null` når serien er for kort. Et annet svar enn «flat». */
  kurs: Kurs | null
  /** Antall måneder over budsjett i serien. */
  ugunstige: number
  antallMaaneder: number
  /** Setningen til butikksjefen. Skrevet ut av tallene, ikke av en modell. */
  tekst: string
}

/**
 * Er trendklassifiseringen følsom for terskelen?
 *
 * Målt på Bønes: «opp» ved 0,08, «flat» ved 0,12 med spenn, «opp» ved
 * 0,12 med et robust spredningsmål. Fire av fem stasjoner er stabile;
 * Bønes er ikke, og Bønes er den som trenger tiltaket.
 *
 * Da skal teksten ikke påstå en retning dataene ikke bærer. Tiltaket er
 * riktig uansett, fordi nivået avgjør det.
 */
export function retningErFolsom(serie: readonly number[]): boolean {
  if (serie.length < 3) return false
  const ved = (grense: number) => {
    const k = retning(serie)
    if (!k) return null
    const flat = k.spenn === 0 || Math.abs(k.endring) < k.spenn * grense
    return flat ? 'flat' : k.endring > 0 ? 'opp' : 'ned'
  }
  const dommer = new Set([ved(0.08), ved(0.12), ved(0.2)])
  return dommer.size > 1
}

const pst = (n: number) => n.toFixed(2).replace('.', ',')
const pp = (n: number) => (n >= 0 ? '+' : '−') + Math.abs(n).toFixed(2).replace('.', ',')

export function kastdom(serie: readonly Kasttall[]): Kastdom {
  const naa = serie[serie.length - 1]
  if (!naa) throw new Error('kastdom: tom serie')

  const prosenter = serie.map((k) => k.faktiskPst)
  const kurs = retning(prosenter)
  const ugunstige = serie.filter((k) => !k.gunstig).length
  const folsom = retningErFolsom(prosenter)

  // NIVÅET AVGJØR. Retningen forklarer.
  const slag: Slag = !naa.gunstig
    ? 'tiltak'
    : kurs?.vei === 'opp' ? 'observer' : 'bekreftelse'

  return { slag, naa, kurs, ugunstige, antallMaaneder: serie.length, tekst: tekstFor(slag, naa, kurs, ugunstige, serie.length, folsom) }
}

function tekstFor(
  slag: Slag, naa: Kasttall, kurs: Kurs | null,
  ugunstige: number, antall: number, folsom: boolean,
): string {
  const niv = `${pst(naa.faktiskPst)} % mot ${pst(naa.budsjettPst)} % budsjettert`

  if (slag === 'tiltak') {
    const hvorOfte = ugunstige === antall
      ? `hver av de ${antall} månedene`
      : `${ugunstige} av ${antall} måneder`
    // FØLSOM TREND: ikke påstå «kastet øker» når klassifiseringen
    // avhenger av terskelen. Nivået bærer tiltaket alene.
    const utvikling = folsom || kurs === null
      ? 'serien viser ingen stabil forbedring'
      : kurs.vei === 'ned'
        ? 'men det går riktig vei'
        : kurs.vei === 'opp' ? 'og det går feil vei' : 'og det står stille'
    return `Ligger klart over kastbudsjettet: ${niv} (${pp(naa.avvikPstpoeng)} pp), `
      + `og ${utvikling}. Over budsjett ${hvorOfte}.`
  }

  if (slag === 'observer') {
    return `Under kastbudsjettet: ${niv} (${pp(naa.avvikPstpoeng)} pp), `
      + 'men kastprosenten er på vei opp. Ikke et tiltak ennå.'
  }

  const utvikling = folsom || kurs === null
    ? 'serien viser ingen stabil forverring'
    : kurs.vei === 'ned' ? 'og kastprosenten faller' : 'og den holder seg'
  return `Under kastbudsjettet: ${niv} (${pp(naa.avvikPstpoeng)} pp), ${utvikling}.`
}
