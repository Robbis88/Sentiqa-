// =====================================================================
// FORBEHOLD HØRER TIL ÉN ANALYSE PÅ ÉN STASJON I ÉN PERIODE
// =====================================================================
//
// Juni 2026 finnes i to eksportversjoner. Første utgave av denne fila sa
// at «de 48 kontrollerte stasjonsfeltene er identiske» og merket bare
// klynge og kjederesultat. **Det var feil.**
//
// Rad-for-rad-avstemming av de to filene 2026-09-13 (A − B):
//
//   ark              rad  kode                          differanse
//   4177 Lone         77  25010 PANT, BF kr               −7 143,80
//   4177 Lone         99  490 Beholdningsendring          +7 143,80   ← motpost
//   4177 Lone        145  300 RESULTAT                    −7 143,80
//   4185 Dale         77  25010 PANT, BF kr               −6 617,70
//   4185 Dale        135  746 Kassedifferanse                 −0,01
//   4185 Dale        145  300 RESULTAT                    −6 617,69
//   9900 Admin       130  741 Reise-møter-kurs               −660,00
//   selskap 36090    145  300 RESULTAT                   −13 101,49
//
// Panten fordeler seg eksakt: 7 143,80 + 6 617,70 = 13 761,50, som er
// selskapets pantlinje. Og resultatene summerer seg eksakt:
// −7 143,80 − 6 617,69 + 660,00 = −13 101,49.
//
// **Stasjonsnivået ER berørt** — men bare for pant, bruttofortjeneste,
// CR og resultat, og bare på Lone og Dale. Ingen diff-rad treffer gruppe
// 120, og ingen treffer kastkolonnene: **mat- og svinnanalysen for juni
// er identisk mellom filene.**
//
// ---------------------------------------------------------------------
// DERFOR ER FORBEHOLDET DIMENSJONERT
//
// Et forbehold på «juni» ville sperret Bønes' matanalyse for en
// pantpostering på Lone. Et forbehold på «Lone i juni» ville sperret
// Lones matanalyse, som er bevist identisk. Posten bærer derfor periode,
// stasjon, analyse, årsak, beløp, kildeversjoner og hva som lukker den.
//
// En post uten `loesesAv` blir stående for alltid, og da slutter folk å
// tro på dem.
// =====================================================================

/** Analysene som kan bære et forbehold. Utvides når nye kommer til. */
export type Analyse =
  | 'stasjonsanalyse'
  | 'mat_svinn_stasjon'
  | 'personalkost_stasjon'
  | 'resultat_stasjon'
  | 'bruttofortjeneste_stasjon'
  | 'cr_stasjon'
  | 'klyngeanalyse'
  | 'kjederesultat'

export const ALLE_ANALYSER: readonly Analyse[] = [
  'stasjonsanalyse', 'mat_svinn_stasjon', 'personalkost_stasjon',
  'resultat_stasjon', 'bruttofortjeneste_stasjon', 'cr_stasjon',
  'klyngeanalyse', 'kjederesultat',
]

/** Analyser som gjelder kjeden, ikke én stasjon. */
export const KJEDEANALYSER: readonly Analyse[] = ['klyngeanalyse', 'kjederesultat']

export type Forbeholdsstatus = 'ok' | 'usikker' | 'blokkert'

export type Forbehold = {
  status: Forbeholdsstatus
  /** Tom når status er `ok`. Ellers alltid utfylt. */
  aarsak: string
  /** Kjent differanse i kroner. `null` når den ikke er tallfestet. */
  belopKr: number | null
  /** Hvilke kildeversjoner som skiller seg. `null` når det ikke gjelder. */
  kildeversjoner: string | null
  /** Hva som må skje for at posten kan fjernes. */
  loesesAv: string
}

const OK: Forbehold = {
  status: 'ok', aarsak: '', belopKr: null, kildeversjoner: null, loesesAv: '',
}

export type Post = {
  periode: string
  /** Butikknummer, eller `null` for kjede-/klyngenivå. */
  stasjon: string | null
  /** Bare disse analysene rammes. Resten er `ok`. */
  gjelder: readonly Analyse[]
  status: Exclude<Forbeholdsstatus, 'ok'>
  aarsak: string
  belopKr: number | null
  kildeversjoner: string | null
  loesesAv: string
}

const JUNI_VERSJONER =
  'A: 202606-202606.xlsx (avlagt, i produksjon) · B: 202606-202606(1).xlsx'
const JUNI_LOESES =
  'Augustregnskapet inneholder korreksjonen. Posten fjernes når august er '
  + 'importert og korreksjonen er avstemt mot juni.'

/**
 * Kjente forbehold. Hver post er én analyse på ett nivå i én periode.
 *
 * Laguneparken, Varden og Bønes står ikke her: rad-for-rad-avstemmingen
 * viste ingen differanse på dem, og et forbehold uten en målt differanse
 * er en anelse, ikke et funn.
 */
export const FORBEHOLD: readonly Post[] = [
  {
    periode: '2026-06-01',
    stasjon: '4177',
    gjelder: ['resultat_stasjon', 'bruttofortjeneste_stasjon', 'cr_stasjon'],
    status: 'usikker',
    aarsak:
      'Versjon B inneholder en senere pantomklassifisering som endrer '
      + 'resultat og bruttofortjeneste for Lone med 7 143,80 kroner '
      + '(25010 PANT rad 77, motpost 490 Beholdningsendring rad 99). '
      + 'Mat, kast og usynlig matsvinn er identiske mellom filene.',
    belopKr: 7143.80,
    kildeversjoner: JUNI_VERSJONER,
    loesesAv: JUNI_LOESES,
  },
  {
    periode: '2026-06-01',
    stasjon: '4185',
    gjelder: ['resultat_stasjon', 'bruttofortjeneste_stasjon', 'cr_stasjon'],
    status: 'usikker',
    aarsak:
      'Versjon B inneholder en senere pantomklassifisering som endrer '
      + 'resultat og bruttofortjeneste for Dale med 6 617,69 kroner '
      + '(6 617,70 på pant, pluss 0,01 på 746 Kassedifferanse). '
      + 'Mat, kast og usynlig matsvinn er identiske mellom filene.',
    belopKr: 6617.69,
    kildeversjoner: JUNI_VERSJONER,
    loesesAv: JUNI_LOESES,
  },
  {
    periode: '2026-06-01',
    stasjon: null,
    gjelder: ['klyngeanalyse', 'kjederesultat'],
    status: 'usikker',
    aarsak:
      'Samlet forskjell i selskapsresultatet mellom eksportversjonene er '
      + '13 101,49 kroner: pant −13 761,50 fordelt på Lone og Dale, '
      + 'Admin +660,00 på 741 Reise-møter-kurs, og 0,01 på kassedifferanse. '
      + 'Versjon B er ikke vedtatt regnskapsfasit.',
    belopKr: 13101.49,
    kildeversjoner: JUNI_VERSJONER,
    loesesAv: JUNI_LOESES,
  },
]

/**
 * Har denne analysen et forbehold?
 *
 * `stasjon` er butikknummeret for stasjonsanalyser, og utelates for
 * kjedeanalyser. Ukjent kombinasjon er `ok` — forbehold er en positiv
 * liste over det vi VET er usikkert, ikke en tvil om alt annet.
 */
export function forbehold(
  periode: string,
  analyse: Analyse,
  stasjon?: string | null,
): Forbehold {
  for (const p of FORBEHOLD) {
    if (p.periode !== periode) continue
    if (!p.gjelder.includes(analyse)) continue
    // En stasjonspost gjelder BARE sin stasjon. En kjedepost har
    // `stasjon: null` og gjelder uansett hva kalleren sender.
    if (p.stasjon !== null && p.stasjon !== (stasjon ?? null)) continue
    return {
      status: p.status,
      aarsak: p.aarsak,
      belopKr: p.belopKr,
      kildeversjoner: p.kildeversjoner,
      loesesAv: p.loesesAv,
    }
  }
  return OK
}

/** Alle analyser for én stasjon i én periode, til en statuslinje. */
export function forbeholdForStasjon(
  periode: string,
  stasjon: string,
): Record<Analyse, Forbehold> {
  return Object.fromEntries(
    ALLE_ANALYSER.map((a) => [a, forbehold(periode, a, stasjon)]),
  ) as Record<Analyse, Forbehold>
}

/** Kan analysen vise et tall i det hele tatt? */
export function kanVises(
  periode: string,
  analyse: Analyse,
  stasjon?: string | null,
): boolean {
  return forbehold(periode, analyse, stasjon).status !== 'blokkert'
}

/**
 * Teksten flaten viser ved siden av tallet.
 *
 * **Beløpet står i den**, fordi «usikker» uten et tall er en advarsel
 * ingen kan handle på. Og formuleringen sier eksplisitt at versjon B
 * ikke er vedtatt — et forbehold skal ikke leses som at det andre tallet
 * er det riktige.
 */
export function forbeholdstekst(f: Forbehold): string | null {
  if (f.status === 'ok') return null
  const belop = f.belopKr == null
    ? ''
    : ` Kjent differanse: ${f.belopKr.toLocaleString('nb-NO', {
      minimumFractionDigits: 2, maximumFractionDigits: 2,
    })} kr.`
  return `${f.status === 'blokkert' ? 'Blokkert' : 'Usikkert tall'}. ${f.aarsak}${belop}`
}
