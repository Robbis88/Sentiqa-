import { celletekst, celletall, forsteDatoIso, lastArbeidsbok, ParserFeil } from './felles'
import type {
  SalesPerHourResultat,
  SalesPerHourStasjon,
  TimesalgRad,
} from './typer'

// Parser St1 0758 "Timesalg" (salg pr time → heatmap/bemanning).
// Struktur: én navnerad per stasjon (kun navn, ikke butikknummer), så en
// total-rad, så 24 time-bøtter ("0-1" … "23-24"). Avsluttes med "Totalt".
const KOL = { time: 1, salg: 3, kostpris: 4, mva: 5, antallVarer: 8, antallKunder: 9 } as const

export async function parseSalesPerHour(
  data: Buffer | ArrayBuffer,
): Promise<SalesPerHourResultat> {
  const wb = await lastArbeidsbok(data)
  const ws = wb.worksheets[0]
  if (!ws) throw new ParserFeil('SalesPerHour: fant ingen ark.')

  // Dato finnes ikke alltid eksplisitt; let i de øverste radene.
  let dato: string | null = null
  for (let r = 1; r <= Math.min(ws.rowCount, 8); r++) {
    dato = forsteDatoIso(celletekst(ws.getRow(r).getCell(1).value))
    if (dato) break
  }

  const stasjoner: SalesPerHourStasjon[] = []
  let stasjon: SalesPerHourStasjon | null = null

  for (let r = 11; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)
    const c1 = celletekst(rad.getCell(1).value).trim()
    if (c1 === '') continue // total-rad mellom navn og timer

    if (/^\d+-\d+$/.test(c1)) {
      // Time-bøtte tilhører gjeldende stasjon
      if (!stasjon) continue
      const t: TimesalgRad = {
        time: c1,
        salg: celletall(rad.getCell(KOL.salg).value),
        kostpris: celletall(rad.getCell(KOL.kostpris).value),
        mva: celletall(rad.getCell(KOL.mva).value),
        antallVarer: celletall(rad.getCell(KOL.antallVarer).value),
        antallKunder: celletall(rad.getCell(KOL.antallKunder).value),
      }
      stasjon.timer.push(t)
      continue
    }

    // Grand total til slutt → ferdig.
    if (/^totalt$/i.test(c1)) break

    // Ellers: ny stasjon (navnerad). Navnet er gjentatt i kol 3.
    stasjon = { butikknummer: null, navn: c1, timer: [] }
    stasjoner.push(stasjon)
  }

  if (stasjoner.length === 0) {
    throw new ParserFeil('SalesPerHour: fant ingen stasjoner.')
  }
  return { rapporttype: 'st1_salesperhour', dato, stasjoner }
}
