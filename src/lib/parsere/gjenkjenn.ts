import { celletekst, lastArbeidsbok } from './felles'
import type { Rapporttype } from './typer'

// Kjenner igjen hvilken St1/Visma-rapport en opplastet xlsx er, basert på
// arknavn + tittelcelle. Brukes av arbeideren til å rute til riktig parser
// (§6). Gjetter aldri på tvers – ukjent format flagges som 'ukjent'.
export async function gjenkjennRapporttype(
  data: Buffer | ArrayBuffer,
): Promise<Rapporttype> {
  const wb = await lastArbeidsbok(data)

  const arknavn = wb.worksheets.map((w) => w.name.toLowerCase())
  const tittel = celletekst(wb.worksheets[0]?.getRow(1).getCell(1).value).toLowerCase()
  const tittel2 = celletekst(wb.worksheets[0]?.getRow(2).getCell(2).value).toLowerCase()
  const hint = `${arknavn.join(' ')} ${tittel} ${tittel2}`

  if (/0714|salgsstatistikk/.test(hint)) return 'st1_salgsstatistikk'
  if (/0758|timesalg|salesperhour/.test(hint)) return 'st1_salesperhour'
  if (/0018|kassererstat|cashierstat/.test(hint)) return 'st1_cashierstats'
  if (/0452|varetransaksj|breakageandwaste/.test(hint)) return 'salgsgrid_varetrans'
  // Månedlig regnskaps-/resultatrapport (fra Azets el. annet regnskapskontor).
  if (arknavn.includes('cluster') || /endring nøkkeltall|statussamtale|azets/.test(hint)) {
    return 'regnskap_resultat'
  }
  return 'ukjent'
}
