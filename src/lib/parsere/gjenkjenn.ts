import { celletekst, lastArbeidsbok } from './felles'
import type { Rapporttype } from './typer'

export const ER_BP = /budsjettfil til vb|timebudsjett grunnlagsfil/

// Kjenner igjen hvilken St1/Visma-rapport en opplastet xlsx er, basert på
// arknavn + tittelcelle. Brukes av arbeideren til å rute til riktig parser
// (§6). Gjetter aldri på tvers – ukjent format flagges som 'ukjent'.
//
// MERK: denne kjøres også i nettleseren (klient-opplaster.tsx), så den skal
// aldri importere node-moduler eller laste noe stort. BP-fila er ~27 MB og
// koster 2,3 GB heap å laste — den kjennes igjen i erBpFil() i bp.ts, som
// strømmer arknavnene og bare finnes på serveren.
export async function gjenkjennRapporttype(
  data: Buffer | ArrayBuffer,
): Promise<Rapporttype> {
  const wb = await lastArbeidsbok(data)

  const arknavn = wb.worksheets.map((w) => w.name.toLowerCase())
  const tittel = celletekst(wb.worksheets[0]?.getRow(1).getCell(1).value).toLowerCase()
  const tittel2 = celletekst(wb.worksheets[0]?.getRow(2).getCell(2).value).toLowerCase()
  const hint = `${arknavn.join(' ')} ${tittel} ${tittel2}`

  if (/0714|salgsstatistikk/.test(hint)) return 'st1_salgsstatistikk'
  // Timesalg = 0603-rapporten med inne-/utekunder (den gamle 0758 brukes ikke).
  if (/0603|0758|timesalg|inne-? ?og ?utekund|salesperhour/.test(hint)) return 'st1_salesperhour_inneute'
  if (/0018|kassererstat|cashierstat/.test(hint)) return 'st1_cashierstats'
  if (/0452|varetransaksj|breakageandwaste/.test(hint)) return 'salgsgrid_varetrans'
  // St1s forretningsplan (årsbudsjett). Må sjekkes før regnskapsrapporten:
  // BP-en har et «Cluster data»-ark, og selv om det ikke er et eksakt treff
  // på 'cluster' i dag, er de to filene like nok til at rekkefølgen betyr noe.
  if (ER_BP.test(hint)) return 'st1_bp'
  // Månedlig regnskaps-/resultatrapport (fra Azets el. annet regnskapskontor).
  if (arknavn.includes('cluster') || /endring nøkkeltall|statussamtale|azets/.test(hint)) {
    return 'regnskap_resultat'
  }
  return 'ukjent'
}
