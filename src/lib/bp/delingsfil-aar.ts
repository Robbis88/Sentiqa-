import type { Kastbudsjett } from '@/lib/parsere/delingsfil'

// =====================================================================
// HVILKET ÅR GJELDER DELINGSFILA?
//
// Fila sier det ikke. Ingen årskolonne, ingen celle, ingenting i
// filnavnet. Den må plasseres av innholdet.
//
// ---------------------------------------------------------------------
// FØRSTE FORSØK VAR BYGGET PÅ ÉN OBSERVASJON, OG DEN HOLDT IKKE
//
// Laguneparkens `Budsjettert matomsetning` er 4 651 908, og BP 2025s Mat
// for samme stasjon er 4 651 907,99. Jeg så det, og gjorde det om til en
// regel: koble stasjon OG år på eksakt beløp.
//
// Målt mot alle tre:
//
//     Laguneparken   4 651 907,99  mot  4 651 908,00   avvik      0,01
//     Varden         2 164 028,88  mot  2 119 896,31   avvik 44 132,57
//     Bønes          1 721 635,41  mot  1 700 095,81   avvik 21 539,60
//
// Bare den ene stemmer. BP-fila heter `_v2` — den er revidert etter at
// delingsfila ble laget, og to av tre stasjoner flyttet seg. Importen
// skrev derfor timer for ÉN stasjon og meldte de to andre som ukjente.
//
// ---------------------------------------------------------------------
// SÅ: NAVNET KOBLER STASJONEN, BELØPET VELGER ÅRET
//
// Navnet er stabilt nok. Stasjonene byttet fra Shell til St1 mot slutten
// av 2025, men `koblePaaNavn` kobler på stedsnavnet uten kjedemerket og
// krever entydighet — den byttet tåler den.
//
// Året velges av beløpet, men på NÆRHET og ikke likhet: årgangen der
// delingsfilas mattall ligger nærmest BP-ens. Mellom 2025 og 2026 er det
// ingen tvil — 2025 bommer med 1–2 %, 2026 med titalls prosent. Kravet
// er at vinneren er klart bedre enn nummer to, ellers plasseres fila ikke.
//
// Det tåler en revisjon. Eksakt likhet gjorde det ikke.
// =====================================================================

/** Mat-omsetningen per år og stasjon, slik den er budsjettert i BP-en. */
export type Matbudsjett = Map<number, Map<string, number>>

export type Aarssvar =
  | { ar: number; kobling: Map<string, string>; ukoblet: string[]; avvikPst: number }
  | { ar: null; grunn: string }

/** Over dette er «nærmest» ikke nær nok til å bety noe. */
const MAKS_AVVIK_PST = 15
/** Vinneren må være så mye bedre enn nummer to. */
const MARGIN = 2

/**
 * Det aarssoeket trenger: et stasjonsnavn og den budsjetterte
 * matomsetningen.
 *
 * DET TALLET STAAR TO STEDER I FILA. «Timer»-arkets `Budsjettert
 * matomsetning` og Mat-arkets `Budsjettert salg` er samme stoerrelse -
 * Laguneparken 4 651 908 i begge, maalt paa Kelsars 2025-fil. 2026-fila
 * har bare det siste, saa aaret maa kunne finnes av begge.
 */
export type Aarsgrunnlag = { butikknavn: string; matomsetning: number }

/**
 * Henter aarsgrunnlaget ut av en parset delingsfil - fra «Timer» naar
 * arket er der, ellers fra Mat-arkets avdelingsrad.
 *
 * BARE AVDELINGSRADEN. Den ER Mat-totalen, og det er den som svarer til
 * Timer-arkets tall. Undergruppene ville lagt seks smaa avvik inn i et
 * snitt som skal treffe én aargang.
 */
export function aarsgrunnlagFra(
  r: { stasjoner: Aarsgrunnlag[]; kastbudsjett: Kastbudsjett[] },
): Aarsgrunnlag[] {
  if (r.stasjoner.length > 0) return r.stasjoner
  return r.kastbudsjett
    .filter((k) => k.nivaa === 'avdeling' && k.budsjettertSalg !== null)
    .map((k) => ({ butikknavn: k.butikknavn, matomsetning: k.budsjettertSalg! }))
}

export function finnAaret(
  rader: Aarsgrunnlag[],
  navnekobling: Map<string, string>,
  matbudsjett: Matbudsjett,
): Aarssvar {
  if (matbudsjett.size === 0) {
    return {
      ar: null,
      grunn:
        'Ingen forretningsplan er lastet inn ennå. Delingsfila plasseres ved å '
        + 'kjenne igjen budsjettert matomsetning i BP-en, så BP-en må komme først.',
    }
  }

  const kjente = rader
    .map((r) => ({ r, stasjonId: navnekobling.get(r.butikknavn.trim().toLowerCase()) }))
    .filter((x): x is { r: Aarsgrunnlag; stasjonId: string } => Boolean(x.stasjonId))

  if (kjente.length === 0) {
    return {
      ar: null,
      grunn:
        `Ingen av stasjonene i delingsfila (${rader.map((r) => r.butikknavn).join(', ')}) `
        + 'kunne kobles til en stasjon i kjeden.',
    }
  }

  // Hvor godt passer hver årgang? Gjennomsnittlig relativt avvik over de
  // stasjonene som finnes i begge.
  const kandidater: { ar: number; avvikPst: number; treff: number }[] = []
  for (const [ar, perStasjon] of matbudsjett) {
    const avvik: number[] = []
    for (const k of kjente) {
      const bp = perStasjon.get(k.stasjonId)
      if (bp === undefined || bp === 0) continue
      avvik.push(Math.abs(bp - k.r.matomsetning) / Math.abs(bp) * 100)
    }
    if (avvik.length === 0) continue
    kandidater.push({
      ar,
      avvikPst: avvik.reduce((a, b) => a + b, 0) / avvik.length,
      treff: avvik.length,
    })
  }

  if (kandidater.length === 0) {
    return {
      ar: null,
      grunn:
        'Fant ingen BP-årgang med de samme stasjonene. Last opp forretningsplanen '
        + 'for samme år først — delingsfila plasseres ved å kjenne igjen tallene i den.',
    }
  }

  kandidater.sort((a, b) => a.avvikPst - b.avvikPst)
  const beste = kandidater[0]

  if (beste.avvikPst > MAKS_AVVIK_PST) {
    return {
      ar: null,
      grunn:
        `Nærmeste årgang er ${beste.ar}, men budsjettert matomsetning avviker `
        + `${beste.avvikPst.toFixed(1).replace('.', ',')} % fra BP-en. Det er for langt `
        + 'unna til å si at fila hører til det året.',
    }
  }
  // Nummer to må være tydelig dårligere. Er de like gode, er valget en
  // gjetning — og et timebudsjett på feil år er verre enn ingen.
  const nestBeste = kandidater[1]
  if (nestBeste && nestBeste.avvikPst < beste.avvikPst * MARGIN) {
    return {
      ar: null,
      grunn:
        `Delingsfila passer nesten like godt til ${beste.ar} `
        + `(${beste.avvikPst.toFixed(1).replace('.', ',')} % avvik) som til ${nestBeste.ar} `
        + `(${nestBeste.avvikPst.toFixed(1).replace('.', ',')} %). Da kan den ikke `
        + 'plasseres uten å gjette.',
    }
  }

  const kobling = new Map(kjente.map((k) => [k.r.butikknavn.trim().toLowerCase(), k.stasjonId]))
  const ukoblet = rader
    .map((r) => r.butikknavn)
    .filter((n) => !kobling.has(n.trim().toLowerCase()))
  return { ar: beste.ar, kobling, ukoblet, avvikPst: beste.avvikPst }
}
