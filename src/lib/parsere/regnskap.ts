import { celletekst, celletall, forsteDatoIso, lastArbeidsbok, ParserFeil } from './felles'
import type { RegnskapLinje, RegnskapResultat, RegnskapSeksjon } from './typer'

// Parser den månedlige regnskaps-/resultatrapporten (Azets m.fl.), Cluster-arket.
// Strukturert P&L i tre seksjoner. Per seksjon: Regnskap/Budsjett/Avvik/Index
// for «Denne periode» (kol 4–7) og «Hittil i år» (kol 9–10).
//
// Seksjonsrad kjennes igjen ved at kol 4 = teksten "Regnskap".
const SEKSJONER: Record<string, RegnskapSeksjon> = {
  omsetning: 'omsetning',
  bruttofortjeneste: 'bruttofortjeneste',
  driftskostnader: 'driftskostnader',
}
const KOL = {
  kode: 1, sortering: 2, post: 3,
  regnskap: 4, budsjett: 5, avvik: 6, index: 7,
  regnskapHittil: 9, budsjettHittil: 10,
} as const

export async function parseRegnskap(
  data: Buffer | ArrayBuffer,
): Promise<RegnskapResultat> {
  const wb = await lastArbeidsbok(data)
  const ws = wb.getWorksheet('Cluster')
  if (!ws) throw new ParserFeil('Regnskap: fant ikke «Cluster»-arket.')

  const retailerNavn = celletekst(ws.getRow(1).getCell(3).value).trim() || null

  // Periode: let etter første DD.MM.YYYY i topptekstradene (1–5).
  let periode: string | null = null
  for (let r = 1; r <= 5 && !periode; r++) {
    for (let k = 1; k <= 13 && !periode; k++) {
      const iso = forsteDatoIso(celletekst(ws.getRow(r).getCell(k).value))
      if (iso) periode = iso.slice(0, 8) + '01' // første i måneden
    }
  }

  const linjer: RegnskapLinje[] = []
  let seksjon: RegnskapSeksjon | null = null

  for (let r = 4; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)
    const post = celletekst(rad.getCell(KOL.post).value).trim()
    if (post === '') continue

    // Seksjonsrad? (kol 4 inneholder teksten "Regnskap")
    if (celletekst(rad.getCell(KOL.regnskap).value).trim().toLowerCase() === 'regnskap') {
      seksjon = SEKSJONER[post.toLowerCase()] ?? seksjon
      continue
    }
    if (/^kommentarer/i.test(post)) break
    if (!seksjon) continue

    // Resultatlinjer tagges som egen seksjon
    const linjeSeksjon: RegnskapSeksjon = /^resultat/i.test(post) ? 'resultat' : seksjon
    const kode = celletekst(rad.getCell(KOL.kode).value).trim()

    linjer.push({
      seksjon: linjeSeksjon,
      kode: /^\d+$/.test(kode) ? kode : null,
      post,
      sortering: celletall(rad.getCell(KOL.sortering).value) || null,
      regnskap: celletall(rad.getCell(KOL.regnskap).value),
      budsjett: celletall(rad.getCell(KOL.budsjett).value),
      avvik: celletall(rad.getCell(KOL.avvik).value),
      indexPct: celletall(rad.getCell(KOL.index).value),
      regnskapHittil: celletall(rad.getCell(KOL.regnskapHittil).value),
      budsjettHittil: celletall(rad.getCell(KOL.budsjettHittil).value),
    })
  }

  if (linjer.length === 0) throw new ParserFeil('Regnskap: fant ingen linjer i Cluster-arket.')
  return { rapporttype: 'regnskap_resultat', periode, retailerNavn, linjer }
}
