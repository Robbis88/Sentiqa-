// Hva flaten skal si om mat og svinn — ett sted, for kort og e-post.
//
// =====================================================================
// INGEN BEREGNING HER
// =====================================================================
//
// Alt kommer fra det lagrede øyeblikksbildet. Denne fila formaterer og
// velger ord; den regner ikke. To flater som regner hver for seg er to
// sannheter, og e-posten er den ene butikksjefen faktisk leser.
//
// ---------------------------------------------------------------------
// «OPP» I ET POSITIVT UFORKLART AVVIK BETYR VERRE
//
// Et uforklart matavvik er teoretisk BF minus faktisk BF minus synlig
// kast. Pluss betyr at varer er borte uten at noen vet hvor; minus at
// faktisk bruttofortjeneste er høyere enn den teoretiske.
//
// **Minus er ikke en gevinst.** Det er som oftest periodisering, telling
// eller fakturatidspunkt, og det kan snu neste måned. Ordet «gevinst»
// står ikke i noen av tekstene under, og `analysevisning.test.ts`
// holder det slik.

import type { Matkastsnapshot, Usynligsnapshot } from './snapshot'

/**
 * Tall paa norsk, med HARDT mellomrom.
 *
 * `toLocaleString('nb-NO')` gir et SMALT no-break space (U+202F). Det
 * ser ut som et vanlig mellomrom, sammenlignes ikke som ett, og brekker
 * ulikt i e-post. Huset bruker hardt mellomrom (U+00A0) - se `kr()` i
 * `plan.ts` - saa alt normaliseres hit.
 */
const HARDT = String.fromCharCode(160)
const nb = (n: number, d = 0) =>
  n.toLocaleString('nb-NO', { minimumFractionDigits: d, maximumFractionDigits: d })
    .replace(/\s/g, HARDT)

export const kr = (n: number) => nb(Math.round(n))
export const pst = (n: number) => nb(n, 2) + ' %'
export const pp = (n: number) => (n >= 0 ? '+' : '−') + nb(Math.abs(n), 2) + ' pp'

// =====================================================================
// SYNLIG MATKAST
// =====================================================================

export type Matkastvisning =
  | { slag: 'ikke_beregnet'; merke: string; tittel: string; tekst: string }
  | { slag: 'blokkert'; merke: string; tittel: string; tekst: string; maaned: string | null }
  | {
      slag: 'tiltak' | 'observer' | 'bekreftelse'
      merke: string
      rader: { navn: string; verdi: string; bi?: string }[]
      forklaring: string
      retning: string
    }

const MERKE: Record<string, string> = {
  tiltak: 'tiltak',
  observer: 'observer',
  bekreftelse: 'bekreftelse',
}

/** Månedsnavnet i en blokkeringsårsak, når den navngir en. */
export function maanedIAarsak(aarsak: string | null): string | null {
  return aarsak?.match(/\d{4}-\d{2}-\d{2}/)?.[0] ?? null
}

export function matkastvisning(s: Matkastsnapshot | null): Matkastvisning {
  // GAMMEL PLAN. Ikke blokkert — den ble aldri analysert.
  if (!s) {
    return {
      slag: 'ikke_beregnet',
      merke: 'ikke beregnet',
      tittel: 'Ikke beregnet',
      tekst: 'Planen ble laget før mat- og svinnanalysen var tilgjengelig.',
    }
  }
  if (!s.dom) {
    return {
      slag: 'blokkert',
      merke: 'ikke beregnet',
      tittel: 'Datagrunnlag mangler',
      tekst: s.blokkering ?? 'Analysen er blokkert.',
      maaned: maanedIAarsak(s.blokkering),
    }
  }

  const d = s.dom
  const n = d.naa
  const bedre = n.avvikKr <= 0
  return {
    slag: d.slag,
    merke: MERKE[d.slag] ?? d.slag,
    rader: [
      { navn: 'Matomsetning', verdi: kr(n.matsalgKr) },
      { navn: 'Synlig kast', verdi: kr(n.synligKastKr) },
      { navn: 'Kastprosent', verdi: pst(n.faktiskPst) },
      { navn: 'Budsjettert', verdi: pst(n.budsjettPst) },
      { navn: 'Justert kastbudsjett', verdi: kr(n.justertBudsjettKr) },
      {
        navn: 'Avvik',
        verdi: pp(n.avvikPstpoeng),
        bi: `${kr(Math.abs(n.avvikKr))} ${bedre ? 'bedre enn' : 'over'} budsjett`,
      },
    ],
    forklaring: d.tekst,
    retning: d.kurs === null
      ? 'Ikke nok grunnlag til en retning'
      : d.kurs.vei === 'ned' ? 'Kastprosenten faller'
        : d.kurs.vei === 'opp' ? 'Kastprosenten stiger'
          : 'Kastprosenten står stille',
  }
}

// =====================================================================
// UFORKLART MATAVVIK
// =====================================================================

export type Usynligvisning =
  | { slag: 'ikke_beregnet'; merke: string; tittel: string; tekst: string }
  | { slag: 'blokkert'; merke: string; tittel: string; tekst: string; maaned: string | null }
  | {
      slag: 'usikker' | 'retning'
      merke: string
      /** «+31 902 kr», med fortegn. */
      verdi: string
      /** Setningen om utviklingen, eller om hvorfor den mangler. */
      utvikling: string
      forklaring: string
      aarsaker: string
    }

export const USYNLIG_FORKLARING =
  'Uforklart matavvik er teoretisk bruttofortjeneste minus faktisk '
  + 'bruttofortjeneste minus synlig kast.'

export const USYNLIG_AARSAKER =
  'Mulige årsaker: overproduksjon, manglende registrering, tyveri, '
  + 'telling, periodisering, fakturatidspunkt.'

/** «+31 902 kr» / «−4 200 kr». Fortegnet står alltid. */
export function medFortegn(n: number): string {
  return (n >= 0 ? '+' : '−') + kr(Math.abs(n)) + ' kr'
}

export function usynligvisning(s: Usynligsnapshot | null): Usynligvisning {
  if (!s) {
    return {
      slag: 'ikke_beregnet',
      merke: 'ikke beregnet',
      tittel: 'Ikke beregnet',
      tekst: 'Planen ble laget før mat- og svinnanalysen var tilgjengelig.',
    }
  }
  if (s.blokkering || s.naaKr === null) {
    return {
      slag: 'blokkert',
      merke: 'ikke beregnet',
      tittel: 'Datagrunnlag mangler',
      tekst: s.blokkering ?? 'Analysen er blokkert.',
      maaned: maanedIAarsak(s.blokkering),
    }
  }

  const felles = {
    verdi: medFortegn(s.naaKr),
    forklaring: USYNLIG_FORKLARING,
    aarsaker: USYNLIG_AARSAKER,
  }

  if (s.usikker || s.kurs === null) {
    return {
      ...felles,
      slag: 'usikker',
      merke: 'usikker måling',
      utvikling: s.aarsakUsikker
        ?? 'Usikker enkeltmåling — kontroller telling, periodisering og '
          + 'fakturaflyt før tiltak.',
    }
  }

  // PERIODEN MAA STAA I SETNINGEN. «Stigende» alene ville presentert en
  // tremaanedersbevegelse som en stabil trend for hele aaret.
  const periode = `de siste ${s.vindu} månedene`
  const positivt = s.naaKr >= 0
  const utvikling = s.kurs.vei === 'opp'
    ? positivt
      ? `Uforklart matavvik har økt ${periode}.`
      : `Overskuddet mot teoretisk bruttofortjeneste har blitt mindre ${periode}.`
    : s.kurs.vei === 'ned'
      ? positivt
        ? `Uforklart matavvik har falt ${periode}, men er fortsatt ${medFortegn(s.naaKr)}.`
        : `Overskuddet mot teoretisk bruttofortjeneste har vokst ${periode}.`
      : `Uforklart matavvik har holdt seg ${periode}.`

  return { ...felles, slag: 'retning', merke: 'retning tilgjengelig', utvikling }
}

// =====================================================================
// RANGERING
// =====================================================================

/**
 * Kan tiltakene sammenlignes økonomisk?
 *
 * Uten royaltysatser er `kronerIAret` `null` paa hvert punkt, og en
 * sortering ville gitt en vilkaarlig rekkefoelge som SER UT som en
 * rangering. Da skal flaten si det i stedet.
 */
export const UTEN_KRONEVERDI =
  'Kroneverdi mangler — tiltakene er ikke økonomisk rangert.'

export function erRangert(punkter: readonly { kronerIAret: number | null }[]): boolean {
  const tiltak = punkter.filter((p) => p.kronerIAret !== null)
  return tiltak.length === punkter.length && punkter.length > 0
}
