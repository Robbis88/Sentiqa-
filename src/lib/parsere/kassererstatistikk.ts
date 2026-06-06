import {
  celletekst,
  celletall,
  forsteDatoIso,
  lastArbeidsbok,
  ParserFeil,
  tolkButikk,
} from './felles'
import type { CashierStatsResultat, CashierStatsStasjon, KassererRad } from './typer'

// Parser St1 0018 "Kassererstatistikk". Ett ark per stasjon. Radposisjonene
// varierer mellom ark (noen har en ekstra tomrad), så vi finner "Butikk:"- og
// topptekst-radene dynamisk i stedet for å anta faste rad-nr.
const KOL = {
  nr: 1, navn: 2, omsetning: 3, bonger: 4,
  returAnt: 5, returBelop: 6, makulerteAnt: 7, makulerteBelop: 8,
  slettedeAnt: 9, slettedeBelop: 10,
} as const

export async function parseKassererstatistikk(
  data: Buffer | ArrayBuffer,
): Promise<CashierStatsResultat> {
  const wb = await lastArbeidsbok(data)
  if (wb.worksheets.length === 0) throw new ParserFeil('Kassererstatistikk: ingen ark.')

  let dato: string | null = null
  const stasjoner: CashierStatsStasjon[] = []

  for (const ws of wb.worksheets) {
    let butikkrad = -1
    for (let r = 1; r <= Math.min(ws.rowCount, 10); r++) {
      const c1 = celletekst(ws.getRow(r).getCell(1).value)
      if (!dato) dato = forsteDatoIso(c1) ?? dato
      if (c1.startsWith('Butikk:')) { butikkrad = r; break }
    }
    if (butikkrad === -1) continue // ark uten stasjon (tomt)

    const b = tolkButikk(celletekst(ws.getRow(butikkrad).getCell(1).value))
    if (!b) continue
    const stasjon: CashierStatsStasjon = { ...b, kasserere: [] }
    stasjoner.push(stasjon)

    // Finn datarad-start: raden etter "Nr | Navn"-toppteksten.
    let start = -1
    for (let r = butikkrad + 1; r <= Math.min(ws.rowCount, butikkrad + 5); r++) {
      if (celletekst(ws.getRow(r).getCell(1).value).trim() === 'Nr') { start = r + 1; break }
    }
    if (start === -1) continue

    for (let r = start; r <= ws.rowCount; r++) {
      const nr = celletekst(ws.getRow(r).getCell(KOL.nr).value).trim()
      if (nr === '' ) continue
      if (/^sum butikk/i.test(nr)) break // sumrad → ferdig for arket
      const rad = ws.getRow(r)
      const k: KassererRad = {
        nr,
        navn: celletekst(rad.getCell(KOL.navn).value).trim(),
        omsetningInkMva: celletall(rad.getCell(KOL.omsetning).value),
        bonger: celletall(rad.getCell(KOL.bonger).value),
        returAntall: celletall(rad.getCell(KOL.returAnt).value),
        returBelop: celletall(rad.getCell(KOL.returBelop).value),
        makulerteAntall: celletall(rad.getCell(KOL.makulerteAnt).value),
        makulerteBelop: celletall(rad.getCell(KOL.makulerteBelop).value),
        slettedeAntall: celletall(rad.getCell(KOL.slettedeAnt).value),
        slettedeBelop: celletall(rad.getCell(KOL.slettedeBelop).value),
      }
      stasjon.kasserere.push(k)
    }
  }

  if (stasjoner.length === 0) throw new ParserFeil('Kassererstatistikk: fant ingen stasjoner.')
  return { rapporttype: 'st1_cashierstats', dato, stasjoner }
}
