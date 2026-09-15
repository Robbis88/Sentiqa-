// Samme person, to numre.
//
// =====================================================================
// BASIS EXPORT OG DAGLIG LØNNSKOST ER IKKE ALLTID ENIGE OM NUMMERET
//
// MÅLT på august 2026: fem ansatte står med ulikt stemplingsnummer i de
// to eksportene.
//
//     1058  ↔  11058
//     1021  ↔  11021
//     1013  ↔  11013
//      811  ↔  0811
//     1512  ↔  1104215
//
// ---------------------------------------------------------------------
// DERFOR ER DETTE EN TABELL OG IKKE EN REGEL
//
// Fire av de fem ser ut til å følge et mønster — en foranstilt ener,
// eller en ledende null. Den femte gjør ikke. En regel bygget på de fire
// ville tatt fire av fem og TIDD OM DEN SISTE: 57,5 timer som stille
// blir stående uten sats, i et estimat som ellers ser komplett ut.
//
// Det er nøyaktig formen på en vakt som slutter å se.
//
// ---------------------------------------------------------------------
// HVA SOM GJORDE KOBLINGEN SIKKER
//
// Ikke navnet. Navnet var utgangspunktet for å LETE, men beviset var at
// timetallet var identisk på tidelen i begge eksportene — 160,0 mot
// 160,0, 57,5 mot 57,5, 25,2 mot 25,2. To uavhengige rapporter som
// treffer hverandre på desimalen er et langt sterkere argument enn to
// like navn.
//
// `AGENTS.md` og [[sentiqa-tre-identiteter]]: koble aldri lønn på navn i
// stillhet. Denne fila gjør det ikke, og skal fortsette å la være.
//
// ---------------------------------------------------------------------
// EN UKOBLET TIMELØNNET ER ET FUNN, IKKE EN NULL
//
// Uten broa ville Hasan Gezers 160 timer på Varden stått uten sats:
// nærmere 38 000 kroner som mangler i et tall som ser ferdig ut. Derfor
// returnerer `koble` en ukoblet ansatt i stedet for å hoppe over ham,
// og `arbeidssted.ts` lar det slå gjennom helt ut i datagrunnlaget.
// =====================================================================

/**
 * Bro fra Basis Export-nummer til lønnsgrunnlagsnummer.
 *
 * HÅNDHOLDT MED VILJE. Hver rad er kvittert for av et menneske som har
 * sett at timene stemmer. Tabellen skal ikke utledes, og den skal ikke
 * vokse av seg selv — en ny sprik er et funn som skal opp, ikke et
 * tilfelle som skal fanges.
 *
 * Trinn 4 gir den et hjem i basen, per retailer. Så lenge det finnes én
 * kjede, holder det at den står her, lesbar ved siden av begrunnelsen.
 */
export const NUMMERBRO: Readonly<Record<string, string>> = {
  1058: '11058',
  1021: '11021',
  1013: '11013',
  811: '0811',
  1512: '1104215',
}

/**
 * Hvordan en ansatt i Basis Export er klassifisert.
 *
 * `fastlonn` MÅ komme fra noen som vet. Den skal ALDRI utledes av at
 * satsen mangler: i august hadde sju ansatte ingen sats, og fem av dem
 * var timelønnede med feil nummer. Hadde «ingen sats = fastlønn» vært
 * regelen, ville 160 timer blitt gratis i stillhet.
 */
export type Klassifisering = 'timelonn' | 'fastlonn'

export type Kobling =
  /** Funnet i lønnsgrunnlaget, med sats. Timene kan prises. */
  | { status: 'koblet'; lonnsnr: string }
  /** Klassifisert som fastlønnet av et menneske. Timene skal ikke prises. */
  | { status: 'fastlonn' }
  /**
   * BÅDE nummeret selv OG broas mål finnes i lønnsgrunnlaget.
   *
   * Da er broa gal eller foreldet: enten er 1013 og 11013 to
   * forskjellige personer, eller så ligger samme person inne to ganger.
   * Uansett kan vi ikke velge. Å ta det ene ville priset timene til en
   * sats som kan tilhøre noen andre — og det ville sett like riktig ut
   * som en korrekt kobling.
   */
  | { status: 'tvetydig'; kandidater: [string, string] }
  /** Ingen av delene. Estimatet er ufullstendig. */
  | { status: 'ukoblet' }

/**
 * Kobler et Basis Export-nummer mot lønnsgrunnlaget.
 *
 * @param nr nummeret slik Basis Export skriver det
 * @param finnesILonnsgrunnlaget om et nummer finnes der, med sats
 * @param fastlonnede numre et menneske har klassifisert som fastlønn
 *
 * INGEN GJETNING. Treffer verken nummeret selv eller broa, er svaret
 * `ukoblet` — ikke et forsøk på å ligne seg fram.
 */
export function koble(
  nr: string,
  finnesILonnsgrunnlaget: (kandidat: string) => boolean,
  fastlonnede: ReadonlySet<string> = new Set(),
): Kobling {
  const reint = nr.trim()
  const bro = NUMMERBRO[reint]
  const harReint = finnesILonnsgrunnlaget(reint)
  const harBro = Boolean(bro) && finnesILonnsgrunnlaget(bro)

  // TO KANDIDATER ER IKKE ET VALG, DET ER ET FUNN. Sjekkes dette ikke
  // FØR vi tar det direkte treffet, ville en gal bro ligget og priset
  // feil person i stillhet — broa ville aldri blitt brukt, og aldri
  // blitt oppdaget som gal heller.
  if (harReint && harBro) return { status: 'tvetydig', kandidater: [reint, bro] }

  if (harReint) return { status: 'koblet', lonnsnr: reint }
  if (harBro) return { status: 'koblet', lonnsnr: bro }

  // Fastlønn sjekkes SIST. Er personen faktisk i lønnsgrunnlaget med
  // sats, er han timelønnet der uansett hva noen har huket av — og da
  // skal timene prises. Klassifiseringen er for dem lønnsgrunnlaget
  // ikke kjenner.
  if (fastlonnede.has(reint) || (bro && fastlonnede.has(bro))) return { status: 'fastlonn' }

  return { status: 'ukoblet' }
}
