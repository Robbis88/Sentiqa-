// =====================================================================
// Terskler — alt justerbart på ett sted.
//
// EGEN MODUL, UTEN `server-only`. Grensene brukes av regnskapsvarslene
// (server) OG av dommen på /businessplan, og skal kunne felles av en
// test. `regnskap-varsler.ts` er server-only, så en test som importerte
// derfra falt på `Cannot find package 'server-only'` — og da ville
// alternativet vært å skrive grensene opp to steder.
//
// To sannheter om hva «bak plan» betyr ville gitt butikksjefen gult ett
// sted og grønt et annet for nøyaktig samme tall.
// =====================================================================
export const TERSKLER = {
  omsRod: -10, omsGul: -3, // omsetning, index % under budsjett
  driftRod: 10, driftGul: 3, // driftskostnader, % over budsjett
  brfGul: -5, // bruttofortjeneste, index % under budsjett
  resGul: -10_000, // resultat, kr under budsjett (men positivt)
  lonnOverRod: 10, lonnOverGul: 5, // lønn over LØNNSBUDSJETT i % (St1 setter budsjett)
  lonnBruttoMiss: -3, // brutto under budsjett % når lønnsbudsjettet er brukt
  mankoRod: 15_000, mankoGul: 5_000, mankoPstRod: 10, mankoPstGul: 4,
  overskudd: 5_000, overskuddPst: 4,
  kast: 4_000, kastPst: 3,
} as const
