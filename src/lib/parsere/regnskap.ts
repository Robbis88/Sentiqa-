import { celletekst, celletall, forsteDatoIso, lastArbeidsbok, ParserFeil } from './felles'
import { slaaOppKonto, slaaOppKontoOm } from './kontoregister'
import { sjekkOmsetningslinje } from './omsetningsvakt'
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

    // CLUSTERARKET: begrepet settes NAAR vi kjenner paret, ellers null.
    //
    // Her er det ikke en grense - disse radene har `stasjon_id = null`,
    // og policyen slipper aldri en butikksjef til dem. Derfor den myke
    // oppslagsformen: en ukjent linje paa clusterarket skal ikke felle
    // hele importen, slik den skal paa stasjonsarkene.
    const kodetall = /^\d+$/.test(kode) ? kode : null
    const klyngebegrep = kodetall && linjeSeksjon === 'driftskostnader'
      ? slaaOppKontoOm(kodetall, post)?.begrep ?? null
      : null

    linjer.push({
      seksjon: linjeSeksjon,
      kode: kodetall,
      begrep: klyngebegrep,
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

// Hva en kostnadskode betyr ligger i `kontoregister.ts`. Den tabellen som
// sto her slo opp KODEN ALENE, og var derfor blind for at St1 flyttet
// rapportlinjene i februar 2026. Se kommentaren i kontoregister.ts.

// «Sammenstilling»-arket. Her ligger stasjonene som KOLONNER, ikke rader, og
// arket har to like blokker: inneværende måned og hittil i år. Herfra henter vi
// nøkkeltallene St1 selv regner ut — særlig «Timelønn - antall timer», som er
// eneste sted i rapporten faktiske timer finnes (resten av kontoplanen er kroner).
//
// Blokkene finnes ved å lete etter overskriftsrader der cellene fra kolonne 4 og
// utover ser ut som «4177 ST1 Lone» — da slipper vi å hardkode radnumre, som
// flytter seg mellom versjoner av rapporten. Cluster-kolonnen («190 Kelsar Bil
// AS») faller utenfor av seg selv: tre siffer, ikke fire.
const NOKKELTALL: Record<string, string> = {
  'totale personalkostnader (i 1000 kr)': 'Totale personalkostnader',
  'herav timelønn og overtid (eks fp/aga)': 'Timelønn og overtid',
  'lønnskost vs budsjett': 'Lønnskost vs budsjett',
  'personalkost vs budsjett': 'Personalkost vs budsjett',
  'lønnskost pr åpningstime (døgnåpent)': 'Lønnskost pr åpningstime',
  'lønns% av omsetning': 'Lønns% av omsetning',
  'lønns% av bruttofortjeneste': 'Lønns% av bruttofortjeneste',
  'timelønn - antall timer': 'Timelønn - antall timer',
  'timelønn - gj.sn. timesats (ink overtid)': 'Timelønn - gj.sn. timesats',
  'timelønn - gj.sn. timesats': 'Timelønn - gj.sn. timesats',
  'omsetning pr variabel time': 'Omsetning pr variabel time',
  'bruttofortj pr variabel time': 'Bruttofortj pr variabel time',
}

// Etiketter i regnearket har linjeskift og dobbeltmellomrom om hverandre.
const normaliser = (s: string) => s.toLowerCase().replace(/\s+/g, ' ').trim()

type Nokkelverdi = { mnd: number | null; ytd: number | null }

function parseNokkeltall(
  wb: Awaited<ReturnType<typeof lastArbeidsbok>>,
): Map<string, { navn: string; verdier: Map<string, Nokkelverdi> }> {
  const ut = new Map<string, { navn: string; verdier: Map<string, Nokkelverdi> }>()
  const ws = wb.worksheets.find((w) => normaliser(w.name) === 'sammenstilling')
  if (!ws) return ut

  let kolonner: { kol: number; butikknummer: string; navn: string }[] = []
  let hittil = false

  for (let r = 1; r <= ws.rowCount; r++) {
    const rad = ws.getRow(r)

    const funnet: typeof kolonner = []
    for (let c = 4; c <= Math.min(ws.columnCount, 20); c++) {
      const m = celletekst(rad.getCell(c).value).trim().match(/^(\d{4})\s+(.+)$/)
      if (m) funnet.push({ kol: c, butikknummer: m[1], navn: m[2].trim() })
    }
    if (funnet.length >= 2) {
      kolonner = funnet
      hittil = /hittil/i.test(celletekst(rad.getCell(3).value))
      continue
    }
    if (kolonner.length === 0) continue

    const post = NOKKELTALL[normaliser(celletekst(rad.getCell(3).value))]
    if (!post) continue

    for (const k of kolonner) {
      const celle = rad.getCell(k.kol).value
      if (celle === null || celle === undefined) continue
      let stasjon = ut.get(k.butikknummer)
      if (!stasjon) {
        stasjon = { navn: k.navn, verdier: new Map<string, Nokkelverdi>() }
        ut.set(k.butikknummer, stasjon)
      }
      const verdi = stasjon.verdier.get(post) ?? { mnd: null, ytd: null }
      if (hittil) verdi.ytd = celletall(celle)
      else verdi.mnd = celletall(celle)
      stasjon.verdier.set(post, verdi)
    }
  }

  return ut
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
        // STASJONENS EGET RESULTAT. Arket oppgir det paa rad «RESULTAT»,
        // nivaa 4 med kode 300 - altsaa utenfor BEGGE filtrene under
        // (nivaa 1, kode >= 500). Det ble dermed aldri lest, og Kursen
        // maatte ellers utledet det av brutto minus driftskostnader.
        //
        // Et utledet resultat kan drive fra arkets eget. Da ville
        // «medvind» og «motvind» hvilt paa et tall regnskapsfoereren ikke
        // kjenner igjen, og det er en daarlig plass aa ha en egen mening.
        const nivaa = celletekst(rad.getCell(SKOL.nivaTall).value).trim()
        const navn = celletekst(rad.getCell(SKOL.navn).value).trim()
        if (nivaa === '4' && /^resultat$/i.test(navn)) {
          const reg = celletall(rad.getCell(SKOL.salgRegnskap).value)
          const bud = celletall(rad.getCell(SKOL.salgBudsjett).value)
          linjer.push({
            seksjon: 'resultat', kode: null, begrep: null, post: 'RESULTAT', sortering: null,
            regnskap: reg, budsjett: bud, avvik: reg - bud,
            indexPct: bud ? ((reg - bud) / bud) * 100 : 0,
            regnskapHittil: 0, budsjettHittil: 0,
          })
          continue
        }
        if (nivaa !== '1') continue
        const kk = celletekst(rad.getCell(SKOL.kode).value).trim()
        if (!/^\d+$/.test(kk) || Number(kk) < 500) continue
        const reg = celletall(rad.getCell(SKOL.salgRegnskap).value)
        const bud = celletall(rad.getCell(SKOL.salgBudsjett).value)
        if (reg === 0 && bud === 0) continue
        // Koden ALENE sier ikke hva linja er: St1 renummererte i februar
        // 2026, og 628 betydde «Leie driftsmidler» før det. Arket skriver
        // navnet ved siden av koden i samme celle — vi leser paret, og
        // `slaaOppKonto` kaster på en kombinasjon ingen har tatt stilling
        // til. Se `kontoregister.ts`.
        const trykt = celletekst(rad.getCell(SKOL.navn).value)
        const konto = slaaOppKonto(kk, trykt)
        linjer.push({
          // BEGREPET FOELGER MED RADEN. Koden blir staaende som den sto i
          // arket - den er sporet tilbake til fila - men det er `begrep`
          // tilgangsgrensen leser, og det er stabilt over renummereringen.
          seksjon: 'driftskostnader', kode: kk, begrep: konto.begrep, post: konto.navn, sortering: null,
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
      // Omsetningssiden har sin EGEN hardkodede kodeliste, og den har
      // ingen epoke. Naa som gamle filer slipper inn, maa den maales -
      // se `omsetningsvakt.ts`.
      sjekkOmsetningslinje(koder, post)

      const salgR = celletall(rad.getCell(SKOL.salgRegnskap).value)
      const salgB = celletall(rad.getCell(SKOL.salgBudsjett).value)
      const brR = celletall(rad.getCell(SKOL.bruttoRegnskap).value)
      const brB = celletall(rad.getCell(SKOL.bruttoBudsjett).value)

      linjer.push({
        seksjon: 'omsetning', kode: koder, begrep: null, post, sortering: null,
        regnskap: salgR, budsjett: salgB, avvik: salgR - salgB,
        indexPct: celletall(rad.getCell(SKOL.salgIndex).value),
        regnskapHittil: 0, budsjettHittil: 0,
      })
      linjer.push({
        seksjon: 'bruttofortjeneste', kode: koder, begrep: null, post, sortering: null,
        regnskap: brR, budsjett: brB, avvik: brR - brB,
        indexPct: brB ? ((brR - brB) / brB) * 100 : 0,
        regnskapHittil: 0, budsjettHittil: 0,
      })
    }

    if (linjer.length > 0) stasjoner.push({ butikknummer, navn: navn.trim(), linjer })
  }

  // Nøkkeltallene fra «Sammenstilling» legges på samme stasjon. Måneden havner
  // i regnskap, hittil-i-år i regnskapHittil — samme mønster som resten.
  for (const [butikknummer, data] of parseNokkeltall(wb)) {
    const linjer: RegnskapLinje[] = [...data.verdier].map(([post, v]) => ({
      seksjon: 'nokkeltall' as const,
      kode: null,
      begrep: null,
      post,
      sortering: null,
      regnskap: v.mnd ?? 0,
      budsjett: 0,
      avvik: 0,
      indexPct: 0,
      regnskapHittil: v.ytd ?? 0,
      budsjettHittil: 0,
    }))
    if (linjer.length === 0) continue
    const eksisterende = stasjoner.find((s) => s.butikknummer === butikknummer)
    if (eksisterende) eksisterende.linjer.push(...linjer)
    else stasjoner.push({ butikknummer, navn: data.navn, linjer })
  }

  return stasjoner
}
