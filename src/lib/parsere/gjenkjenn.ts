import { celletekst, lastArbeidsbok } from './felles'
import { arknavn as lesArknavn } from './xlsx-rader'
import type { Rapporttype } from './typer'

export const ER_BP = /budsjettfil til vb|timebudsjett grunnlagsfil/

/**
 * St1s GAMLE BP-mal. Engelske arknavn, og `Cluster data` deles med det
 * nye formatet — det er `cr-sales` og `costs` sammen som skiller dem.
 *
 * FORMATET FØLGER IKKE ÅRSTALLET. Kelsars BP for 2025 er den gamle malen
 * for Laguneparken, Varden og Bønes, mens Dales BP for SAMME ÅR er den
 * nye arbeidsboka — St1 flyttet stasjonene over hver for seg. Derfor
 * leser gjenkjenningen ark, aldri år.
 */
export const erBp25Arknavn = (navn: string[]): boolean =>
  navn.includes('cr-sales') && navn.includes('costs') && navn.includes('cluster data')

/**
 * St1s DELINGSFIL — følgefila til forretningsplanen. Den bærer
 * timebudsjettet, som den gamle BP-malen ikke har.
 *
 * «Timer» ALENE er for tynt — ordet kan stå i hvilken som helst
 * arbeidsbok. Det er kombinasjonen med varegruppearkene som skiller
 * den.
 */
export const erDelingsfilArknavn = (navn: string[]): boolean =>
  navn.includes('timer') && navn.includes('mat')
  && (navn.includes('bilvask') || navn.includes('vask'))

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
  // BP-FILENE SKAL ALDRI LASTES HELT, HELLER IKKE HER.
  //
  // Denne funksjonen kjoerer ogsaa i nettleseren, paa hver eneste fil
  // brukeren velger. BP26 er 27 MB og koster 2,3 GB aa laste; BP25 er
  // 11 MB og koster 2,1 GB. Fram til naa gikk begge rett i
  // `lastArbeidsbok` - en fane som ryker, med en fil som er helt i orden.
  //
  // Arknavnene ligger i `xl/workbook.xml`, noen faa kilobyte, og de er
  // nok til aa kjenne igjen begge formatene.
  try {
    const navn = lesArknavn(data).map((n) => n.toLowerCase())
    if (ER_BP.test(navn.join(' ')) || erBp25Arknavn(navn)) return 'st1_bp'
    // Delingsfila: «Timer» ALENE er for tynt - ordet kan staa i hvilken
    // som helst arbeidsbok. Det er kombinasjonen med varegruppearkene
    // som skiller den.
    if (erDelingsfilArknavn(navn)) return 'st1_delingsfil'
  } catch {
    // Ikke en xlsx, eller en vi ikke kan pakke ut. Da faar den vanlige
    // veien svare - den gir 'ukjent' med en lesbar feil.
  }

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
