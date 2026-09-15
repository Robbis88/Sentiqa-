// Hvilke lønnskroner måles mot Business Plan — og hvilke gjør det ikke.
//
// =====================================================================
// DE TO SIDENE LÅ PÅ ULIKT NIVÅ, OG DET VAR MÅLT
//
// Lønnsrommet er `BP-lønn / BP-brutto × faktisk brutto`. BP-lønn dekker
// fem konti (`BP_TIL_REGNSKAP`). Lønnstallet som ble holdt mot rommet
// var summen av NI. Differansen ble lest som overforbruk.
//
// MÅLT over 30 stasjonsmåneder (regnskapet, januar–juli 2026): 502, 505,
// 506 og 509 er budsjettert med **null i hver eneste av dem**. De måles,
// men de budsjetteres aldri.
//
// Hvor stort det er varierer voldsomt:
//
//     Bønes    juli 2026      1 612 kr    0,67 %
//     Dale     mai  2026     16 048 kr    3,97 %
//     Varden   feb  2026     27 651 kr   10,28 %
//     Dale     juli 2026     35 330 kr    8,71 %
//
// Dale i juli er kanarifuglen. 34 830 av de 35 330 kronene er sykelønn.
// Med det gamle oppsettet fikk butikksjefen beskjed om at han hadde
// brukt 35 330 kroner av rommet sitt fordi noen var syk — en beskjed om
// et styringsproblem som ikke fantes.
//
// Retningen er den «trygge» (det ser dyrere ut enn det er). Men et
// varsel som lyser når ingen har gjort noe galt, lærer folk å se bort
// fra varsler.
//
// ---------------------------------------------------------------------
// VI UTVIDER IKKE BUDSJETTET
//
// Alternativet var å legge de fire kontiene inn på budsjettsiden også.
// Det ble forkastet: Sentiqa skal ikke konstruere et budsjett St1 ikke
// har gitt oss. Kostnaden er ekte og skal være synlig — den skal bare
// ikke spise av et rom som aldri var satt av til den.
//
// ---------------------------------------------------------------------
// EN UKJENT KOSTNAD ER IKKE NULL
//
// `easyatwork.ts` hadde `egen ?? oppgitt ?? baaret?.[1] ?? 0` for
// fastlønn. Den siste `?? 0` gjorde «vi vet ikke» om til «null kroner»
// — og 501 ligger INNE i styringsnivået. En åpen måned uten fastlønn
// ga dermed for lav styringskost og for stort rom. På Bønes er lederens
// fastlønn 27 % av lønnskosten.
//
// Derfor er `styringskostKr` her `number | null`, og `null` betyr
// «kan ikke regnes», ikke «null kroner». `ukjenteKonti` sier hvilke.
// =====================================================================

import { BP_TIL_REGNSKAP } from './bp'

/**
 * Kontiene BP faktisk budsjetterer: 501, 503, 508, 540, 541.
 *
 * UTLEDET av `BP_TIL_REGNSKAP`, ikke skrevet av på nytt. To lister over
 * de samme kontiene er to lister som kan skille lag — og den ene ville
 * da stille bestemt lønnsrommet mens den andre så riktig ut.
 */
export const STYRINGSKONTI: ReadonlySet<string> = new Set(Object.values(BP_TIL_REGNSKAP))

/**
 * Lønnskonti BP ikke har: 502, 505, 506, 509.
 *
 * Skrevet ut, ikke utledet av `LONNSKONTI` — det ville gitt en
 * importsyklus. `kostnadsniva.test.ts` holder de to mot hverandre, så
 * en ny lønnskonto i `maaned.ts` ikke kan falle mellom stolene.
 */
export const UTENFOR_BP: ReadonlySet<string> = new Set(['502', '505', '506', '509'])

/**
 * Lønnskostnaden delt på det budsjettet faktisk dekker.
 *
 * `null` betyr KAN IKKE REGNES, aldri «null kroner». Se toppen av fila.
 */
export type Kostnadsniva = {
  /** 501+503+508+540+541. Dette er tallet lønnsrommet måles mot. */
  styringskostKr: number | null
  /** 502+505+506+509. Ekte kostnad, men utenfor budsjettet. */
  ovrigLonnKr: number | null
  /**
   * Konti vi ikke kjenner verdien av ennå — ikke konti som er null.
   *
   * Sortert, så to like nivåer ser like ut.
   */
  ukjenteKonti: string[]
}

/**
 * Deler kroner per konto i styringskost og øvrig lønnskost.
 *
 * @param perKonto kroner per kontokode. En konto som mangler her er
 *   NULL KRONER — det er hva et regnskap uten linje betyr.
 * @param ukjenteKonti konti der vi ikke vet beløpet. Disse er noe helt
 *   annet enn fravær, og de gjør sin side av summen `null`.
 *
 * KASTER PÅ EN UKJENT KONTO. En kode som verken er styringskost eller
 * utenfor BP er en lønnskonto ingen har tatt stilling til, og den ville
 * ellers forsvunnet ut av begge summene uten at noe sa fra — samme
 * fristelse som «alt som ikke er 2 eller 12 er tillegg» i `TIL_KONTO`.
 */
export function delOppKostnad(
  perKonto: Readonly<Record<string, number>>,
  ukjenteKonti: readonly string[] = [],
): Kostnadsniva {
  let styring = 0
  let ovrig = 0

  for (const [kode, kr] of Object.entries(perKonto)) {
    if (STYRINGSKONTI.has(kode)) styring += kr
    else if (UTENFOR_BP.has(kode)) ovrig += kr
    else {
      throw new Error(
        `Konto ${kode} er verken styringskost eller utenfor BP. `
        + 'Nye lønnskonti må klassifiseres i kostnadsniva.ts før de kan summeres.',
      )
    }
  }

  const ukjent = [...new Set(ukjenteKonti)].sort()
  for (const kode of ukjent) {
    if (!STYRINGSKONTI.has(kode) && !UTENFOR_BP.has(kode)) {
      throw new Error(`Ukjent konto ${kode} er ikke en lønnskonto.`)
    }
  }

  return {
    // ETT UKJENT LEDD GJØR HELE SUMMEN UKJENT. Å returnere «det vi vet
    // så langt» ville gitt et tall som ser komplett ut og er for lavt.
    styringskostKr: ukjent.some((k) => STYRINGSKONTI.has(k)) ? null : rund(styring),
    ovrigLonnKr: ukjent.some((k) => UTENFOR_BP.has(k)) ? null : rund(ovrig),
    ukjenteKonti: ukjent,
  }
}

const rund = (n: number): number => Math.round(n * 100) / 100
