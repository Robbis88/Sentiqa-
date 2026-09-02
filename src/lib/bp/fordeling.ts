import type { Bplinje } from './rader'
import { fordelPaaMaaneder } from '@/lib/bemanning'

// =====================================================================
// BP-KURVENE LEST TILBAKE UT AV DOKUMENTET
//
// `lagreBp` fordeler timene mens den har FILA i hånden: bruttokurven
// ligger som `m.bruttoKr` på hver månedsrad. Delingsfila kommer etterpå
// og har ingen fil å lese — bare et årstall og et timebudsjett.
//
// Da må kurven komme fra basen. `bp_linje` er dokumentet slik fila var,
// urørt av månedslåsen, og bærer alt som trengs: brutto er omsetning
// minus varekost per måned, og timelønna er sin egen konto.
//
// REN MED VILJE, av samme grunn som `rader.ts` er det: testen som
// beviser at de to veiene inn i bemanningen gir SAMME svar må kunne
// kjøre begge. Ligger utregningen inne i importøren, må testen skrive
// den av — og da beviser den at kopien stemmer med seg selv.
//
//   fila         -> parseBp -> m.bruttoKr          (lagreBp)
//   fila -> bp_linje -> basen -> bruttoKurve()     (lagreDelingsfil)
//
// De to skal møtes. `fordeling.test.ts` er kanarifuglen på det.
// =====================================================================

/**
 * Timelønnskontoen i BP26.
 *
 * BP25-malen fører HELE stasjonens lønn på 5010 og splitter ikke, så en
 * BP25-årgang har ingen 5012-linjer og kurven blir tolv nuller. Det er
 * riktig: `lagreBp` ville skrevet nøyaktig samme `lonn_kr` for den fila.
 * Å gjette splitten ville gitt 4,6 mot 1,8 millioner mot BP26 — se
 * kommentaren i `parsere/bp25.ts`.
 */
export const KONTO_TIMELONN = '5012'

const tolv = () => new Array<number>(12).fill(0)

/**
 * Bruttofortjeneste per måned, januar først.
 *
 * Samme størrelse som `m.bruttoKr` i den parsede BP-en: omsetning minus
 * varekost. `bpLinjer()` hopper over nullbeløp, så en måned uten linjer
 * blir 0 — som den skal.
 */
export function bruttoKurve(linjer: Bplinje[]): number[] {
  const ut = tolv()
  for (const l of linjer) {
    if (l.maned < 1 || l.maned > 12) continue
    if (l.seksjon === 'omsetning') ut[l.maned - 1] += l.belop_kr
    else if (l.seksjon === 'varekost') ut[l.maned - 1] -= l.belop_kr
  }
  return ut
}

/** Budsjettert timelønn per måned, januar først. Tolv nuller på BP25. */
export function timelonnKurve(linjer: Bplinje[]): number[] {
  const ut = tolv()
  for (const l of linjer) {
    if (l.maned < 1 || l.maned > 12) continue
    if (l.seksjon === 'kostnad' && l.kode === KONTO_TIMELONN) ut[l.maned - 1] += l.belop_kr
  }
  return ut
}


/** Én måneds ramme, slik bemanningstabellene trenger den. */
export type Maanedsramme = {
  maned: number
  /** Rå andel av årsrammen, FØR fradrag — det retailer ser. */
  timer: number
  /** Etter reserve og sikkerhet. Det planleggeren faktisk kan dele ut. */
  disponible_timer: number
  brutto_bp_kr: number
}

/**
 * Årsrammen fordelt på tolv måneder etter bruttokurven.
 *
 * EN IMPLEMENTASJON, TO KALLSTEDER. `lagreBp` fordeler fra fila,
 * `fordelFraDokument` fra `bp_linje` — og da må de regne likt. Sto
 * regnestykket i begge, ville en endring i det ene gitt en kjede på den
 * gamle malen en fordeling som ikke stemmer med sin egen BP, uten at
 * noe sa fra: begge tall er plausible.
 *
 * `timer` og `disponible_timer` er IKKE det samme tallet. Det første er
 * andelen av årsrammen; det andre er det som står igjen etter reserve
 * og sikkerhet. `bemanning_budsjett` bærer det første, `bemanning_maned`
 * det andre — se [[sentiqa-timeregnskap]]: timene er fortjent, ikke
 * gitt, og fradragene er eierens margin.
 *
 * En brutto-sum på 0 gir flat fordeling framfor null timer: en BP uten
 * omsetningstall skal ikke gi en planlegger uten timer i det hele tatt.
 */
export function maanedsrammer(
  timerAar: number,
  brutto: number[],
  f: { reservePst: number; sikkerhetPst: number },
): Maanedsramme[] {
  const sum = brutto.reduce((a, b) => a + b, 0)
  const disponible = fordelPaaMaaneder(timerAar, brutto, f)
  return brutto.map((b, i) => ({
    maned: i + 1,
    timer: timerAar * (sum > 0 ? b / sum : 1 / 12),
    disponible_timer: Math.max(0, disponible[i]),
    brutto_bp_kr: b,
  }))
}
