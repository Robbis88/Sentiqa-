import { celletekst, celletall, forsteDatoIso, lastArbeidsbok, ParserFeil } from './felles'
import type {
  SalesPerHourResultat,
  SalesPerHourStasjon,
  TimesalgRad,
} from './typer'

// Parser St1 0603 "Timesalgsrapport med inne- og utekunder".
// Struktur som 0758, men annet kolonneoppsett + kundene splittes i inne/ute.
// Kolonner (1-indeksert): A=Time, B=Salg, C=Kostpris, D=Mva, G=Antall varer,
// H=Innekunder antall, K=Utekunder antall. Totalt antall kunder = inne + ute.
const KOL = { time: 1, salg: 2, kostpris: 3, mva: 4, antallVarer: 7, inne: 8, ute: 11 } as const

export async function parseSalesPerHourInneUte(
  data: Buffer | ArrayBuffer,
): Promise<SalesPerHourResultat> {
  const wb = await lastArbeidsbok(data)
  const ws = wb.worksheets[0]
  if (!ws) throw new ParserFeil('SalesPerHourInneUte: fant ingen ark.')

  let dato: string | null = null
  for (let r = 1; r <= Math.min(ws.rowCount, 8); r++) {
    dato = forsteDatoIso(celletekst(ws.getRow(r).getCell(1).value))
    if (dato) break
  }

  const stasjoner: SalesPerHourStasjon[] = []
  let stasjon: SalesPerHourStasjon | null = null

  for (let r = 9; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)
    const c1 = celletekst(rad.getCell(1).value).trim()
    if (c1 === '') continue // total-rad mellom navn og timer

    if (/^\d+-\d+$/.test(c1)) {
      if (!stasjon) continue
      const inne = celletall(rad.getCell(KOL.inne).value)
      const ute = celletall(rad.getCell(KOL.ute).value)
      const t: TimesalgRad = {
        time: c1,
        salg: celletall(rad.getCell(KOL.salg).value),
        kostpris: celletall(rad.getCell(KOL.kostpris).value),
        mva: celletall(rad.getCell(KOL.mva).value),
        antallVarer: celletall(rad.getCell(KOL.antallVarer).value),
        antallKunder: inne + ute,
        inneKunder: inne,
        uteKunder: ute,
      }
      stasjon.timer.push(t)
      continue
    }

    if (/^totalt$/i.test(c1)) break

    // Ny stasjon (navnerad).
    stasjon = { butikknummer: null, navn: c1, timer: [] }
    stasjoner.push(stasjon)
  }

  if (stasjoner.length === 0) {
    throw new ParserFeil('SalesPerHourInneUte: fant ingen stasjoner.')
  }
  return { rapporttype: 'st1_salesperhour_inneute', dato, stasjoner }
}
