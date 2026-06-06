import {
  celletekst,
  celletall,
  forsteDatoIso,
  kodeOgNavn,
  lastArbeidsbok,
  ParserFeil,
  tolkButikk,
} from './felles'
import type {
  Salgslinje,
  SalgsstatistikkResultat,
  SalgsstatistikkStasjon,
} from './typer'

// Parser St1 0714 "Salgsstatistikk avdeling drilldown".
// Én fil kan inneholde flere stasjoner. Strukturen er hierarkisk:
//   Butikk: → Avdeling: → Vareområde: → Varegruppe: → produktrader
// Vi vandrer radene, holder gjeldende kontekst, og emitterer én Salgslinje
// per produktrad. Ren funksjon, ingen DB (§14).
//
// Kolonner (1-basert), fra topptekst rad 6–7:
//   1 EAN  2 Varenavn  3 Varenr.  4 Antall totalt  5 Antall tilbud
//   6 Omsetning eks mva totalt  11 Bto.fortj. kr  12 Bto.fortj. %
const KOL = {
  ean: 1,
  varenavn: 2,
  varenr: 3,
  antallTotalt: 4,
  antallTilbud: 5,
  omsetning: 6,
  btoKr: 11,
  btoPct: 12,
} as const

export async function parseSalgsstatistikk(
  data: Buffer | ArrayBuffer,
): Promise<SalgsstatistikkResultat> {
  const wb = await lastArbeidsbok(data)
  const ws = wb.worksheets[0]
  if (!ws) throw new ParserFeil('Salgsstatistikk: fant ingen ark.')

  const tittel = celletekst(ws.getRow(1).getCell(1).value)
  if (!/salgsstatistikk/i.test(tittel)) {
    throw new ParserFeil(`Salgsstatistikk: uventet tittel «${tittel}».`)
  }

  const datorad = celletekst(ws.getRow(3).getCell(1).value)
  const dato = forsteDatoIso(datorad)
  if (!dato) throw new ParserFeil(`Salgsstatistikk: fant ingen dato i «${datorad}».`)
  const inkludererMoms = /inkluder moms:\s*true/i.test(datorad)

  const stasjoner: SalgsstatistikkStasjon[] = []
  let stasjon: SalgsstatistikkStasjon | null = null
  let avd = { kode: null as string | null, navn: null as string | null }
  let vomr = { kode: null as string | null, navn: null as string | null }
  let vgr = { kode: null as string | null, navn: null as string | null }

  for (let r = 8; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)
    const c1 = celletekst(rad.getCell(1).value).trim()
    if (c1 === '') continue

    if (c1.startsWith('Butikk:')) {
      const b = tolkButikk(c1)
      const butikknummer = b?.butikknummer ?? ''
      const navn = b?.navn ?? c1.replace(/^Butikk:\s*/, '').trim()
      // Stasjonen gjentas som avslutnings-sum; start kun ny ved nytt nummer.
      if (!stasjon || stasjon.butikknummer !== butikknummer) {
        stasjon = { butikknummer, navn, linjer: [] }
        stasjoner.push(stasjon)
        avd = vomr = vgr = { kode: null, navn: null }
      }
      continue
    }
    if (c1.startsWith('Avdeling:')) {
      avd = kodeOgNavn(c1.replace(/^Avdeling:\s*/, ''))
      continue
    }
    if (c1.startsWith('Vareområde:')) {
      vomr = kodeOgNavn(c1.replace(/^Vareområde:\s*/, ''))
      continue
    }
    if (c1.startsWith('Varegruppe:')) {
      vgr = kodeOgNavn(c1.replace(/^Varegruppe:\s*/, ''))
      continue
    }

    // Produktrad: kol 1 er en numerisk EAN/kode.
    if (/^\d+$/.test(c1) && stasjon) {
      const varenr = celletekst(rad.getCell(KOL.varenr).value).trim()
      const linje: Salgslinje = {
        ean: c1,
        varenavn: celletekst(rad.getCell(KOL.varenavn).value).trim(),
        varenr: varenr && varenr.toLowerCase() !== 'unknown' ? varenr : null,
        avdelingKode: avd.kode,
        avdelingNavn: avd.navn,
        vareomradeKode: vomr.kode,
        vareomradeNavn: vomr.navn,
        varegruppeKode: vgr.kode,
        varegruppeNavn: vgr.navn,
        antallTotalt: celletall(rad.getCell(KOL.antallTotalt).value),
        antallTilbud: celletall(rad.getCell(KOL.antallTilbud).value),
        omsetningEksMva: celletall(rad.getCell(KOL.omsetning).value),
        btoFortjenesteKr: celletall(rad.getCell(KOL.btoKr).value),
        btoFortjenestePct: celletall(rad.getCell(KOL.btoPct).value),
      }
      stasjon.linjer.push(linje)
    }
  }

  if (stasjoner.length === 0) {
    throw new ParserFeil('Salgsstatistikk: fant ingen stasjoner/produktrader.')
  }

  return { rapporttype: 'st1_salgsstatistikk', dato, inkludererMoms, stasjoner }
}
