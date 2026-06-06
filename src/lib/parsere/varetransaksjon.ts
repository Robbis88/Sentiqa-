import {
  celletekst,
  celletall,
  forsteDatoIso,
  lastArbeidsbok,
  ParserFeil,
  tolkButikk,
} from './felles'
import type { SvinnTransaksjon, VaretransResultat, VaretransStasjon } from './typer'

// Parser St1 0452 "Varetransaksjonsliste" (synlig svinn, §11). Én fil kan ha
// flere stasjoner. Rader: "Butikk:" → "Underleverandør:" → transaksjoner +
// "Sum EAN …"-rader (hoppes over) + tomrader.
const KOL = {
  ean: 1, varenavn: 2, varenummer: 3, operatornr: 4,
  transaksjonstype: 5, arsakskode: 6, dato: 7,
  nettopris: 8, antall: 9, nettoprisTotal: 11,
} as const

export async function parseVaretransaksjon(
  data: Buffer | ArrayBuffer,
): Promise<VaretransResultat> {
  const wb = await lastArbeidsbok(data)
  const ws = wb.worksheets[0]
  if (!ws) throw new ParserFeil('Varetransaksjon: fant ingen ark.')

  const stasjoner: VaretransStasjon[] = []
  let stasjon: VaretransStasjon | null = null

  for (let r = 7; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)
    const c1 = celletekst(rad.getCell(1).value).trim()
    if (c1 === '') continue

    if (c1.startsWith('Butikk:')) {
      const b = tolkButikk(c1)
      if (b) { stasjon = { ...b, transaksjoner: [] }; stasjoner.push(stasjon) }
      continue
    }
    if (c1.startsWith('Underleverandør:') || c1.startsWith('Sum ')) continue

    // Transaksjonsrad: kol 1 er en numerisk EAN/kode.
    if (/^\d+$/.test(c1) && stasjon) {
      const varenr = celletekst(rad.getCell(KOL.varenummer).value).trim()
      const t: SvinnTransaksjon = {
        ean: c1,
        varenavn: celletekst(rad.getCell(KOL.varenavn).value).trim(),
        varenummer: varenr && varenr.toLowerCase() !== 'unknown' ? varenr : null,
        operatornr: celletekst(rad.getCell(KOL.operatornr).value).trim() || null,
        transaksjonstype: celletekst(rad.getCell(KOL.transaksjonstype).value).trim(),
        arsakskode: celletekst(rad.getCell(KOL.arsakskode).value).trim(),
        dato: forsteDatoIso(celletekst(rad.getCell(KOL.dato).value)),
        nettopris: celletall(rad.getCell(KOL.nettopris).value),
        antall: celletall(rad.getCell(KOL.antall).value),
        nettoprisTotal: celletall(rad.getCell(KOL.nettoprisTotal).value),
      }
      stasjon.transaksjoner.push(t)
    }
  }

  if (stasjoner.length === 0) throw new ParserFeil('Varetransaksjon: fant ingen stasjoner.')
  return { rapporttype: 'salgsgrid_varetrans', stasjoner }
}
