import { celletekst, celletall, lastArbeidsbok, ParserFeil } from './felles'

// Usynlig svinn pr produkt fra per-stasjon-arkene i regnskapsfila ("4177 ST1 Lone" …).
// St1-formatet (fast oppsett): kol 1=kode, 2=type, 7=navn, 8=salg, 12=Brf %,
// 23="Usynlig" (kr), 24=Usynlig %. Fortegn: + = manko, - = overskudd.
const KOL = { kode: 1, type: 2, navn: 7, salg: 8, brfPst: 12, usynlig: 23, usynligPst: 24 } as const

export type UsynligProdukt = {
  kode: string | null
  navn: string
  salg: number
  brfPst: number
  usynligKr: number
  usynligPst: number
}
export type UsynligStasjon = {
  butikknummer: string
  produkter: UsynligProdukt[]
  totalManko: number // sum av positive
  totalOverskudd: number // sum av negative
}
export type UsynligResultat = {
  rapporttype: 'usynlig_svinn'
  stasjoner: UsynligStasjon[]
}

export async function parseUsynligSvinn(data: Buffer | ArrayBuffer): Promise<UsynligResultat> {
  const wb = await lastArbeidsbok(data)
  const stasjoner: UsynligStasjon[] = []

  for (const ws of wb.worksheets) {
    const m = /^(\d{4})\s/.exec(ws.name.trim())
    if (!m) continue // kun stasjons-arkene (starter med 4-sifret butikknummer)
    const butikknummer = m[1]

    // Finn header-raden (har "Usynlig" i en celle) — bekrefter at oppsettet stemmer.
    let headerRad = 0
    for (let r = 1; r <= Math.min(ws.rowCount, 6); r++) {
      const rad = ws.getRow(r)
      for (let c = 1; c <= 30; c++) {
        if (/usynlig/i.test(celletekst(rad.getCell(c).value))) { headerRad = r; break }
      }
      if (headerRad) break
    }
    if (!headerRad) continue

    const produkter: UsynligProdukt[] = []
    let totalManko = 0
    let totalOverskudd = 0
    for (let r = headerRad + 1; r <= ws.rowCount; r++) {
      const rad = ws.getRow(r)
      if (celletekst(rad.getCell(KOL.type).value).trim() !== 'Prod') continue // kun enkeltprodukter
      const navn = celletekst(rad.getCell(KOL.navn).value).trim()
      if (!navn || /totalt/i.test(navn)) continue
      const usynligKr = celletall(rad.getCell(KOL.usynlig).value)
      const salg = celletall(rad.getCell(KOL.salg).value)
      if (usynligKr === 0 && salg === 0) continue
      if (usynligKr > 0) totalManko += usynligKr
      else if (usynligKr < 0) totalOverskudd += usynligKr
      produkter.push({
        kode: celletekst(rad.getCell(KOL.kode).value).trim() || null,
        navn,
        salg,
        brfPst: celletall(rad.getCell(KOL.brfPst).value),
        usynligKr,
        usynligPst: celletall(rad.getCell(KOL.usynligPst).value),
      })
    }

    if (produkter.length > 0) {
      stasjoner.push({ butikknummer, produkter, totalManko: Math.round(totalManko), totalOverskudd: Math.round(totalOverskudd) })
    }
  }

  if (stasjoner.length === 0) throw new ParserFeil('UsynligSvinn: fant ingen stasjons-ark med usynlig svinn.')
  return { rapporttype: 'usynlig_svinn', stasjoner }
}
