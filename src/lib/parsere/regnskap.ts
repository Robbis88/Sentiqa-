import { celletekst, celletall, forsteDatoIso, lastArbeidsbok, ParserFeil } from './felles'
import type {
  RegnskapLinje,
  RegnskapResultat,
  RegnskapSeksjon,
  RegnskapStasjon,
} from './typer'

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

  // Periode: les EKSPLISITT fra «Denne periode DD.MM.YYYY - …»-feltet (ikke
  // filnavnet, ikke «Hittil i år»). Tar startdatoens måned. Fallback: første
  // dato i topptekst. Så systemet alltid filer regnskapet på riktig måned.
  let periode: string | null = null
  for (let r = 1; r <= 8 && !periode; r++) {
    for (let k = 1; k <= ws.columnCount && !periode; k++) {
      const t = celletekst(ws.getRow(r).getCell(k).value)
      if (/denne periode/i.test(t)) {
        const iso = forsteDatoIso(t)
        if (iso) periode = iso.slice(0, 8) + '01'
      }
    }
  }
  if (!periode) {
    for (let r = 1; r <= 6 && !periode; r++) {
      for (let k = 1; k <= 13 && !periode; k++) {
        const iso = forsteDatoIso(celletekst(ws.getRow(r).getCell(k).value))
        if (iso) periode = iso.slice(0, 8) + '01'
      }
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

// Per-stasjon-arkene ("4177 ST1 Lone" …). Kolonner: 1 kode, 2 nivå
// (Prod/ProdGrN), 3 type (Oms), 7 navn, 8–10 Salg (regnskap/budsjett/index),
// 11/13 Bruttofortjeneste (regnskap/budsjett). Vi tar avdelings-rollupene
// (nivå med «Gr») i omsetnings-seksjonen, og hopper «totalt»-rollups så
// summering per stasjon blir ren.
const SKOL = {
  kode: 1, niva: 2, type: 3, nivaTall: 4, navn: 7,
  salgRegnskap: 8, salgBudsjett: 9, salgIndex: 10,
  bruttoRegnskap: 11, bruttoBudsjett: 13,
} as const

// St1-kontoplan: kostnadskonti i «Res»-seksjonen på per-stasjon-arket (kun
// kode i regnearket, ikke navn). Brukes for per-stasjon driftskostnader.
const KONTO_NAVN: Record<string, string> = {
  '501': 'Faste lønninger', '502': 'Lønnstillegg', '503': 'Timelønn', '505': 'Sykelønn',
  '508': 'Påløpte feriepenger', '509': 'Bonus', '540': 'Arb.avg av lønn', '541': 'Arb.avg av feriepenger',
  '590': 'Andre personalkostnader', '621': 'Markedsbidrag', '622': 'Royalty', '623': 'FSA', '624': 'Franchiseavgift',
  '627': 'Renhold', '628': 'Renovasjon', '629': 'Brøyting', '630': 'Leie driftsmidler', '631': 'Leie utstyr utleie',
  '632': 'Utstyr & verktøy', '633': 'Forbruksmateriell', '634': 'Rep & vedlikehold', '635': 'Data & kortsystem',
  '636': 'Pengehåndtering', '637': 'Fremmedtjenester & vakthold', '638': 'Kontorrekvisita', '639': 'Telefon',
  '740': 'Bilutgifter', '741': 'Reise, møter, kurs', '742': 'Reklame', '743': 'Diverse', '744': 'Forsikringer',
  '746': 'Kassedifferanse', '771': 'Bank & kortprovisjon', '780': 'Ekstraordinært tap/gevinst', '790': 'Avskrivninger',
  '810': 'Finanskostnader', '840': 'Ikke driftsrelatert',
}

export async function parseRegnskapStasjoner(
  data: Buffer | ArrayBuffer,
): Promise<RegnskapStasjon[]> {
  const wb = await lastArbeidsbok(data)
  const stasjoner: RegnskapStasjon[] = []

  for (const ws of wb.worksheets) {
    const m = ws.name.match(/^(\d{4})\s+(.*)$/) // "4177 ST1 Lone"
    if (!m) continue
    const [, butikknummer, navn] = m
    if (/admin/i.test(navn)) continue // strukturelt ark (f.eks. "9900 Admin"), ikke en stasjon
    const linjer: RegnskapLinje[] = []

    for (let r = 4; r <= ws.rowCount; r++) {
      const rad = ws.getRow(r)
      const type = celletekst(rad.getCell(SKOL.type).value).trim()

      // Driftskostnader pr stasjon («Res»-seksjon): leaf-konto (nivå 1), kun
      // kostnadskonti (>= 500). Regnskap=kol 8, Budsjett=kol 9 (som salg).
      if (type === 'Res') {
        if (celletekst(rad.getCell(SKOL.nivaTall).value).trim() !== '1') continue
        const kk = celletekst(rad.getCell(SKOL.kode).value).trim()
        if (!/^\d+$/.test(kk) || Number(kk) < 500) continue
        const reg = celletall(rad.getCell(SKOL.salgRegnskap).value)
        const bud = celletall(rad.getCell(SKOL.salgBudsjett).value)
        if (reg === 0 && bud === 0) continue
        linjer.push({
          seksjon: 'driftskostnader', kode: kk, post: KONTO_NAVN[kk] ?? `Konto ${kk}`, sortering: null,
          regnskap: reg, budsjett: bud, avvik: reg - bud, indexPct: bud ? ((reg - bud) / bud) * 100 : 0,
          regnskapHittil: 0, budsjettHittil: 0,
        })
        continue
      }

      const niva = celletekst(rad.getCell(SKOL.niva).value)
      if (type !== 'Oms' || !/gr/i.test(niva)) continue // kun avdelings-rollup i omsetning
      const post = celletekst(rad.getCell(SKOL.navn).value).trim()
      if (!post || /totalt/i.test(post)) continue // hopp grand-total/CR-totalt
      const kode = celletekst(rad.getCell(SKOL.kode).value).trim()
      const koder = /^\d+$/.test(kode) ? kode : null

      const salgR = celletall(rad.getCell(SKOL.salgRegnskap).value)
      const salgB = celletall(rad.getCell(SKOL.salgBudsjett).value)
      const brR = celletall(rad.getCell(SKOL.bruttoRegnskap).value)
      const brB = celletall(rad.getCell(SKOL.bruttoBudsjett).value)

      linjer.push({
        seksjon: 'omsetning', kode: koder, post, sortering: null,
        regnskap: salgR, budsjett: salgB, avvik: salgR - salgB,
        indexPct: celletall(rad.getCell(SKOL.salgIndex).value),
        regnskapHittil: 0, budsjettHittil: 0,
      })
      linjer.push({
        seksjon: 'bruttofortjeneste', kode: koder, post, sortering: null,
        regnskap: brR, budsjett: brB, avvik: brR - brB,
        indexPct: brB ? ((brR - brB) / brB) * 100 : 0,
        regnskapHittil: 0, budsjettHittil: 0,
      })
    }

    if (linjer.length > 0) stasjoner.push({ butikknummer, navn: navn.trim(), linjer })
  }

  return stasjoner
}
