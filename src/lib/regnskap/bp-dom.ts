// =====================================================================
// Dommen om en avdeling: ordet, alvoret og rekkefølgen.
//
// SKILT FRA KOMPONENTEN MED VILJE. CI-basen har ingen `regnskapslinjer`
// i det hele tatt, så `/businessplan` viser alltid tomtilstanden der.
// Lå denne logikken inne i JSX-en, ville den viktigste delen av sida —
// hva som står øverst, og hva det heter — vært uten bevis helt til noen
// oppdaget en feil i produksjon.
//
// Her er den ren, og kan felles av en test som kjører på 20 ms.
// =====================================================================

export type Alvor = 'normal' | 'endring' | 'handling'

/**
 * Hvor alvorlig er avviket mot planen?
 *
 * Grensene er DE SAMME som regnskapsvarslene bruker (regnskap-varsler.ts:24):
 * −3 % er verdt å se på, −10 % krever noe. Å finne på egne grenser her
 * ville gitt to sannheter om hva «bak plan» betyr — og butikksjefen
 * ville sett gult ett sted og grønt et annet for det samme tallet.
 */
export function alvor(motBpPst: number | null): Alvor {
  if (motBpPst == null) return 'normal'
  if (motBpPst <= -10) return 'handling'
  if (motBpPst <= -3) return 'endring'
  return 'normal'
}

/**
 * «28 400 kr bak plan» — ordet, ikke fortegnet.
 *
 * Et minustegn er ikke en dom. Den som skanner en liste skal kunne lese
 * retningen uten å tolke et symbol, og uten å se farge.
 */
export function domsord(kroner: number): 'bak plan' | 'foran plan' {
  return kroner < 0 ? 'bak plan' : 'foran plan'
}

/**
 * Rekkefølgen på lista: det som mangler mest mot planen først.
 *
 * IKKE alfabetisk, og ikke etter størrelse. En avdeling som omsetter
 * mye er ikke interessant i seg selv — den som mangler mest mot det den
 * skulle ha levert, er det.
 */
export function sorterEtterAvvik<T extends { mot_bp_kr: number | null }>(rader: T[]): T[] {
  return [...rader].sort((a, b) => (a.mot_bp_kr ?? 0) - (b.mot_bp_kr ?? 0))
}

/**
 * Hvor mye ligger stasjonen bak planen, summert?
 *
 * BARE DE NEGATIVE. En avdeling som ligger foran skal ikke skjule at en
 * annen ligger bak: «vi er i rute» fordi Tobakk går bra er ikke et svar
 * på at Mat mangler 28 000. Nettosummen ville sagt nettopp det.
 */
export function sumBakPlan(rader: { mot_bp_kr: number | null }[]): number {
  return rader.reduce((s, r) => s + Math.min(0, r.mot_bp_kr ?? 0), 0)
}

/**
 * Deler radene i «kan måles» og «kan ikke måles», og teller det siste.
 *
 * MÅLT I PRODUKSJON 2026-08-21, og det er derfor det ble en fotnote og
 * ikke rader: av 5 987 890 kr budsjett lå 5 980 694 på avdelinger som
 * møter salgstall. `211 Selvvask` sto for 7 196 kr — 0,12 % — og `DRIFT`
 * og `SYSTEM` for 146 kr salg uten plan.
 *
 * Å gi dem hver sin rad ville lagt to–tre innholdsløse linjer mellom ni
 * ekte per stasjon. DRIFT er dessuten nøyaktig raden som viste −3536 %
 * brutto før 0114.
 *
 * MEN DE SKJULES IKKE. Tallene står som én linje under lista, i kroner.
 * Blir 211 Selvvask en dag til en reell del av planen, vokser det tallet
 * i stedet for å forsvinne — og det er hele forskjellen på en fotnote og
 * en utelatelse.
 */
export function delEtterKobling<T extends {
  kobling: string | null
  bp_omsetning_kr: number | null
  faktisk_omsetning: number | null
}>(rader: T[]): { maalbare: T[], umaalte: T[], umaaltBudsjett: number, salgUtenPlan: number } {
  const umaalte = rader.filter(
    (r) => r.kobling === 'plan_uten_kobling' || r.kobling === 'salg_uten_plan',
  )
  return {
    // `plan_uten_salg` blir MED i lista: den har en plan, den er kjent i
    // salgsdataene, og null omsetning er et svar - ikke et hull.
    maalbare: rader.filter((r) => !umaalte.includes(r)),
    umaalte,
    umaaltBudsjett: umaalte.reduce((s, r) => s + (r.bp_omsetning_kr ?? 0), 0),
    salgUtenPlan: umaalte
      .filter((r) => r.kobling === 'salg_uten_plan')
      .reduce((s, r) => s + (r.faktisk_omsetning ?? 0), 0),
  }
}

/**
 * Er brutto-gapet verdt å reagere på?
 *
 * Gapet er teoretisk minus faktisk margin — svinn, feilpris eller
 * telling. Et par tideler er støy; tre prosentpoeng på en avdeling med
 * volum er penger som forsvinner uten å vises i salgstallene.
 */
export function gapAlvor(gapPp: number | null): Alvor {
  if (gapPp == null) return 'normal'
  if (gapPp >= 3) return 'handling'
  if (gapPp >= 1) return 'endring'
  return 'normal'
}
