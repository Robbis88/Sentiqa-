import { lastArbeidsbok, celletekst, celletall, ParserFeil } from './felles'
import {
  analyseomraade, gruppekodeFor, kontrollerUsynlig, nivaaFraType,
  TYPE_BLOKK, TYPE_GRUPPE,
  type Analyseomraade, type Avviksstatus, type Nivaa,
} from '@/lib/svinn/nivaa'

// =====================================================================
// SVINN OG BRUTTOFORTJENESTE PER VAREGRUPPE, FRA REGNSKAPSARKET
// =====================================================================
//
// Fortegn: usynlig + = manko, − = overskudd. Kast: positivt = kastet.
//
// ---------------------------------------------------------------------
// HELE ARKET, IKKE FEM AV NI KOLONNER
//
// Første utgave leste `salg`, `brf_pst`, `kast`, `usynlig` og
// `usynlig_pst`. Da kunne matanalysen ikke etterprøves, for identiteten
//
//   teoretisk BF  −  faktisk BF  −  synlig kast  =  usynlig svinn
//
// manglet to av tre ledd. Målt på Kelsars sju månedsfiler holder
// identiteten til øret i arkets egne tall — `diff = 0` i alle 35
// stasjonsmåneder. Den skal derfor **kontrolleres**, og begge verdier
// bevares: St1s egen i `usynligKr`, vår i `kontrollKr`.
//
// ---------------------------------------------------------------------
// BEGGE NIVÅER. GRUPPEN EIER TOTALEN
//
// Her sto `if (type !== 'Prod') continue`. Grupperaden — `120 Mat`,
// `ProdGr3`, den som eier totalen — ble aldri lagret. Målt: 546
// grupperader og 2 346 butikkproduktrader i de sju filene, og
// produktradene summerer eksakt til gruppen for mat i alle 35
// stasjonsmåneder.
//
// ---------------------------------------------------------------------
// INGEN RADER DROPPES
//
// Lagringen filtrerte bort produktrader der både kast og usynlig var
// under 1 000 kroner. Det kostet Dale 75,90 kroner i juli — nok til at
// viewet viste 31 943 der arket sier 32 018,74 — og Laguneparken
// 1 402 kroner. Mange små rader blir et stort beløp.
//
// Rader med bare nuller hoppes fortsatt over: de bærer ingen
// informasjon, og de ville gjort hvert ark tre ganger så stort.
// =====================================================================

const KOL = {
  kode: 1, type: 2, nivaa: 4, navn: 7,
  salg: 8, bfKr: 11, brfPst: 12, teoretiskKr: 15, teoretiskPst: 16,
  kast: 20, kastPst: 21, usynlig: 23, usynligPst: 24,
} as const

export type UsynligProdukt = {
  kode: string | null
  navn: string
  nivaa: Nivaa
  analyseomraade: Analyseomraade
  /** Gruppa raden hører til. `null` for grupperaden selv og for ukjente. */
  kodeGruppe: string | null
  /** Kontrollsignal for dagens format. Aldri en regel. */
  kodelengde: number
  salg: number
  /** Faktisk bruttofortjeneste i kroner, kolonne 11. */
  bfKr: number
  /** FAKTISK bruttofortjenesteprosent, kolonne 12. Ikke teoretisk. */
  brfPst: number
  /** Teoretisk bruttofortjeneste, kolonne 15 og 16. */
  teoretiskKr: number
  teoretiskPst: number
  kast: number
  kastPst: number
  /** St1s eget tall, kolonne 23. */
  usynligKr: number
  usynligPst: number
  /** Vår egen beregning av identiteten. Begge bevares. */
  kontrollUsynligKr: number
  avviksstatus: Avviksstatus
  /** Radnummeret i arket. Proveniens — gjør et funn etterprøvbart. */
  kildeRad: number
}

export type UsynligStasjon = {
  butikknummer: string
  produkter: UsynligProdukt[]
  totalManko: number
  totalOverskudd: number
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

    // FØRSTE GJENNOMGANG: arkets egne gruppekoder.
    //
    // De definerer butikkens univers, og de må være kjent FØR en
    // produktrad kan plasseres. Uten dette ville analyseområdet hvilt på
    // antall siffer — og da slipper en ny firesifret butikkode inn i
    // stillhet, eller en femsifret drivstoffkode blir butikk.
    // Samtidig registreres hvilke ProdGr1-blokker som INNEHOLDER
    // grupper. `10 Drivstoff` inneholder alle de 13 butikkgruppene; en
    // ren produktblokk uten grupper er en drivstoff-/CR-oppstilling.
    // Det er strukturen som skiller «vet ikke» fra «vet at det er
    // drivstoff», ikke overskriften alene.
    const gruppekoder = new Set<string>()
    const blokkMedGrupper = new Set<string>()
    {
      let b = ''
      for (let r = headerRad + 1; r <= ws.rowCount; r++) {
        const rad = ws.getRow(r)
        const type = celletekst(rad.getCell(KOL.type).value).trim()
        const kode = celletekst(rad.getCell(KOL.kode).value).trim()
        if (type === TYPE_BLOKK) {
          b = `${kode} ${celletekst(rad.getCell(KOL.navn).value).trim()}`
          continue
        }
        if (type !== TYPE_GRUPPE) continue
        if (kode) gruppekoder.add(kode)
        if (b) blokkMedGrupper.add(b)
      }
    }

    const produkter: UsynligProdukt[] = []
    let totalManko = 0
    let totalOverskudd = 0
    let blokk = ''

    for (let r = headerRad + 1; r <= ws.rowCount; r++) {
      const rad = ws.getRow(r)
      const type = celletekst(rad.getCell(KOL.type).value).trim()
      const navn = celletekst(rad.getCell(KOL.navn).value).trim()

      // Blokkoverskriften holdes med videre: den skiller «vet at dette
      // er drivstoff» fra «vet ikke hva dette er». Begge blokkeres, men
      // de er ikke samme funn.
      if (type === TYPE_BLOKK) { blokk = `${celletekst(rad.getCell(KOL.kode).value).trim()} ${navn}`; continue }

      const nivaa = nivaaFraType(type)
      if (!nivaa) continue
      if (!navn || /totalt/i.test(navn)) continue

      const kode = celletekst(rad.getCell(KOL.kode).value).trim()
      const salg = celletall(rad.getCell(KOL.salg).value)
      const bfKr = celletall(rad.getCell(KOL.bfKr).value)
      const teoretiskKr = celletall(rad.getCell(KOL.teoretiskKr).value)
      const kast = celletall(rad.getCell(KOL.kast).value)
      const usynligKr = celletall(rad.getCell(KOL.usynlig).value)

      // GRUPPERADEN BEHOLDES ALLTID, ogsaa naar alt er null.
      //
      // «Dale har ingen bilvask» er en ekte null og et svar. Hoppet vi
      // over den, kunne analysen ikke skille «ingen bilvask» fra «ingen
      // data om bilvask» - og det er nøyaktig regelen Robert satte:
      // manglende datagrunnlag skal aldri tolkes som en ekte 0.
      //
      // En PRODUKTrad med bare nuller bærer derimot ingenting, og
      // grupperaden eier likevel totalen.
      if (nivaa === 'produkt'
        && salg === 0 && bfKr === 0 && teoretiskKr === 0 && kast === 0 && usynligKr === 0) continue

      const omraade = analyseomraade(nivaa, kode, {
        gruppekoder, blokk, blokkHarGrupper: blokkMedGrupper.has(blokk),
      })
      const { kontrollKr, status } = kontrollerUsynlig(teoretiskKr, bfKr, kast, usynligKr)

      if (usynligKr > 0) totalManko += usynligKr
      else if (usynligKr < 0) totalOverskudd += usynligKr

      produkter.push({
        kode: kode || null,
        navn,
        nivaa,
        analyseomraade: omraade,
        kodeGruppe: nivaa === 'produkt' && omraade === 'butikk' ? gruppekodeFor(kode) : null,
        kodelengde: kode.length,
        salg,
        bfKr,
        brfPst: celletall(rad.getCell(KOL.brfPst).value),
        teoretiskKr,
        teoretiskPst: celletall(rad.getCell(KOL.teoretiskPst).value),
        kast,
        kastPst: celletall(rad.getCell(KOL.kastPst).value),
        usynligKr,
        usynligPst: celletall(rad.getCell(KOL.usynligPst).value),
        kontrollUsynligKr: kontrollKr,
        avviksstatus: status,
        kildeRad: r,
      })
    }

    if (produkter.length > 0) {
      stasjoner.push({
        butikknummer,
        produkter,
        totalManko: Math.round(totalManko),
        totalOverskudd: Math.round(totalOverskudd),
      })
    }
  }

  if (stasjoner.length === 0) throw new ParserFeil('UsynligSvinn: fant ingen stasjons-ark med usynlig svinn.')
  return { rapporttype: 'usynlig_svinn', stasjoner }
}

/**
 * Avstemming: summerer produktradene til grupperaden?
 *
 * =====================================================================
 * GRUPPEN EIER TOTALEN — DIFFERANSEN VISES, IKKE FORDELES
 * =====================================================================
 *
 * Målt på de sju filene: mat (120) avstemmer til 0 i alle 35
 * stasjonsmåneder. 64 av 546 gruppemåneder har differanse, og de er
 * konsentrerte og forklarlige:
 *
 *   210 Bilvask / 211 Selvvask   salg bytter plass mellom de to,
 *                                likt og motsatt, netto null over paret
 *   240 Drift                    små restposter
 *
 * Differansen skal **lagres og vises**, aldri korrigeres bort og aldri
 * fordeles automatisk. Produktnivået overstyrer ikke gruppenivået: er
 * det uenighet, er gruppen sann og uenigheten et funn.
 */
export type Gruppeavstemming = {
  butikknummer: string
  gruppe: string
  navn: string
  gruppeSalg: number
  produktSalg: number
  gruppeKast: number
  produktKast: number
  gruppeUsynlig: number
  produktUsynlig: number
  /** Gruppe minus produkt. 0 betyr avstemt. */
  diffSalg: number
  diffKast: number
  diffUsynlig: number
  avstemt: boolean
}

/** Toleranse i kroner. Målt diff er 0; 0,50 gir rom for flyttallsstøy. */
export const AVSTEMMING_TOLERANSE_KR = 0.5

export function avstemGrupper(r: UsynligResultat): Gruppeavstemming[] {
  const ut: Gruppeavstemming[] = []
  const rund = (n: number) => Math.round(n * 100) / 100

  for (const st of r.stasjoner) {
    const butikk = st.produkter.filter((p) => p.analyseomraade === 'butikk')
    const grupper = butikk.filter((p) => p.nivaa === 'gruppe')
    for (const g of grupper) {
      if (!g.kode) continue
      const barn = butikk.filter((p) => p.nivaa === 'produkt' && p.kodeGruppe === g.kode)
      const sum = barn.reduce(
        (a, p) => ({ salg: a.salg + p.salg, kast: a.kast + p.kast, usyn: a.usyn + p.usynligKr }),
        { salg: 0, kast: 0, usyn: 0 },
      )
      const d = {
        salg: rund(g.salg - sum.salg),
        kast: rund(g.kast - sum.kast),
        usyn: rund(g.usynligKr - sum.usyn),
      }
      ut.push({
        butikknummer: st.butikknummer,
        gruppe: g.kode,
        navn: g.navn,
        gruppeSalg: rund(g.salg), produktSalg: rund(sum.salg),
        gruppeKast: rund(g.kast), produktKast: rund(sum.kast),
        gruppeUsynlig: rund(g.usynligKr), produktUsynlig: rund(sum.usyn),
        diffSalg: d.salg, diffKast: d.kast, diffUsynlig: d.usyn,
        avstemt: Math.abs(d.salg) <= AVSTEMMING_TOLERANSE_KR
          && Math.abs(d.kast) <= AVSTEMMING_TOLERANSE_KR
          && Math.abs(d.usyn) <= AVSTEMMING_TOLERANSE_KR,
      })
    }
  }
  return ut
}
