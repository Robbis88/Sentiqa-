// =====================================================================
// BP-ENS KONTOPLAN MOT REGNSKAPETS
//
// De to fører de samme kostnadene under ulike koder. Regnskapet bruker
// St1s tresifrede (`501`, `503`, `508`, `540`, `541`); BP-en bruker den
// firesifrede standardkontoplanen (`5010`, `5012`, `5090`, `5400`,
// `5401`).
//
// ---------------------------------------------------------------------
// NAVNET KAN IKKE BRUKES, OG DET ER FILA SOM BESTEMMER DET
//
// BP26 kaller HVER konto «Kostnader» — `post` er bokstavelig talt
// «5012 Kostnader» for alle 43 kodene, med tre unntak som bærer navn
// (`3705 Kommisjon`, `6312 Royalty`, `6315 FSA`). Det står alt i
// `bp/analyse.ts`: «BP25 har 18 aggregerte konti, BP26 har over femti og
// kaller dem alle Kostnader.»
//
// Å mappe på navn er derfor ikke et dårligere valg — det er umulig.
// Koden er det eneste håndtaket.
//
// ---------------------------------------------------------------------
// MAPPINGEN ER LEST AV KODEBASEN, IKKE GJETTET
//
// `bp/analyse.ts` slår den fast for de to viktigste:
//
//   «BP25 fører all lønn på 5010. BP26 splitter i 5012 timelønn og
//    5010 fastlønn.»
//
// De tre øvrige følger standardkontoplanen (5090 påløpte feriepenger,
// 5400 arbeidsgiveravgift, 5401 arbeidsgiveravgift av feriepenger), og
// størrelsesorden bekrefter det. Snitt per stasjonsmåned målt 2026-09-05,
// mot regnskapets eget budsjett for Bønes juli:
//
//     5010   56 327   mot  501 budsjett  53 176
//     5090   29 782   mot  508 budsjett  24 290
//     5400   34 942   mot  540 budsjett  29 276
//     5401    4 199   mot  541 budsjett   3 425
//
// Ingen av dem er bevis alene. Sammen med den skrevne splitten er de
// nok — og `ukjenteLonnskoder` under gjør at en kode vi IKKE har tatt
// stilling til blir synlig i stedet for å bli borte i en sum.
//
// ---------------------------------------------------------------------
// 59xx ER PERSONALKOST, IKKE LØNN — SAMME GRENSE SOM 590
//
// `bp/analyse.ts` regner ALT på `5\d{3}` som `personal`, og det er
// riktig for det den svarer på: hva hele personalrammen koster.
//
// Her går grensen et annet sted, og den må gå likt på begge sider.
// Regnskapssiden holder `590 Andre personalkostnader` utenfor
// lønnskosten; da må BP-siden holde `5917`, `5932`, `5945` og `5961`
// utenfor også. Ellers sammenligner en avlagt måned uten pensjon med en
// åpen måned med — og forskjellen leses som lønnsvekst.
//
// ---------------------------------------------------------------------
// BP-EN ER STRUKTURELT SMALERE, OG DET SKAL SIES
//
// Regnskapet har `502 Lønnstillegg`, `505 Sykelønn`, `506 Refundert
// sykelønn` og `509 Bonus`. BP-en har ingen tilsvarende koder — de
// budsjetteres ikke separat. Et BP-budsjett er derfor ikke helt det
// samme som et månedsbudsjett fra St1, og siden sier det.
// =====================================================================

/** BP-kode → regnskapskode. Bare kontiene som ER lønn. */
export const BP_TIL_REGNSKAP: Record<string, string> = {
  '5010': '501', // fastlønn  — slått fast i bp/analyse.ts
  '5012': '503', // timelønn  — samme sted
  '5090': '508', // påløpte feriepenger
  '5400': '540', // arbeidsgiveravgift av lønn
  '5401': '541', // arbeidsgiveravgift av feriepenger
}

/** BP-koder som er personalkost, men ikke lønn. Speiler `590`. */
export const BP_ANDRE_PERSONAL = new Set(['5917', '5932', '5945', '5961'])

export const BP_LONNSKODER: ReadonlySet<string> = new Set(Object.keys(BP_TIL_REGNSKAP))

/** Navn til visning. BP-fila har dem ikke, så de kommer herfra. */
export const BP_KONTONAVN: Record<string, string> = {
  '5010': 'Faste lønninger',
  '5012': 'Timelønn',
  '5090': 'Påløpte feriepenger',
  '5400': 'Arb.avg av lønn',
  '5401': 'Arb.avg av feriepenger',
}

/**
 * Personalkoder i BP-en som verken er klassifisert som lønn eller som
 * annen personalkost.
 *
 * **En slik kode er et FUNN, ikke en detalj.** St1 utvider kontoplanen
 * mellom årganger — BP25 hadde 18 konti, BP26 over femti — og en ny
 * `5xxx` ville ellers falt ut av lønnskosten i stillhet. Da ville
 * budsjettet krympet uten at noe sa fra, og avviket sett ut som god
 * kostnadsstyring.
 *
 * Siden viser dem. Det er billigere enn å oppdage det på et avvik ingen
 * kan forklare.
 */
export function ukjenteLonnskoder(koder: Iterable<string>): string[] {
  const ukjent = new Set<string>()
  for (const k of koder) {
    if (!/^5\d{3}$/.test(k)) continue
    if (k in BP_TIL_REGNSKAP) continue
    if (BP_ANDRE_PERSONAL.has(k)) continue
    ukjent.add(k)
  }
  return [...ukjent].sort()
}
