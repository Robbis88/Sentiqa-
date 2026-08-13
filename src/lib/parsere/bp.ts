import { Readable } from 'node:stream'
import ExcelJS from 'exceljs'
import { celletall, celletekst, ParserFeil } from './felles'
import { ER_BP } from './gjenkjenn'
import type { BpResultat, BpStasjon } from './typer'

// =====================================================================
// St1s forretningsplan (BP) — årsbudsjettet retailer laster opp én gang.
//
// To ark er interessante:
//
//   «Timebudsjett Grunnlagsfil»  Butikknr | Timebudsjett
//       Årsrammen i timer. Den er VARIABEL — St1 har allerede trukket fra
//       ett årsverk (1695 t) for butikksjefens fastlønn. De timene er ekte
//       dekning på gulvet og legges inn igjen som faste vakter.
//
//   «Budsjettfil til VB»  Butikknr | … | Kontonr | … | Yr | Pr | Beløp pivot
//       Én rad per stasjon × varegruppe × konto × måned. Herfra tar vi
//       brutto per måned, som er kurven timene skal fordeles etter.
//
// Konti (verifisert mot regnskapslinjer): 3010 CR salg (negativ, kredit),
// 4090 varekost, 5012 timelønn, 5010 butikksjefens fastlønn.
//
// Drivstoff er ikke med i BP-en i det hele tatt; «CR salg» er butikk alene.
// Det stemmer med at kode 10 Drivstoff står på 0 i regnskapsrapporten.
//
// Fila dekker HELE kjeden, ikke bare én retailer. Stasjoner som ikke
// tilhører innlogget retailer filtreres bort ved lagring — det er normalt,
// ikke en feil.
//
// STRØMMES, ikke lastes. Fila er ~27 MB og inneholder ark på 289 000 rader
// som vi ikke bruker. Full innlasting kostet 2,3 GB heap og 13 sekunder —
// ikke kjørbart i en funksjon. WorkbookReader leser rad for rad og kaster
// det den har passert, og vi hopper over ark vi ikke trenger.
// =====================================================================

// Mange celler er formler uten bufret verdi. Verifisert mot «Pivot»-arket at
// disse er nuller: summen av det som lot seg lese stemte på kronen med
// pivottotalene. Hadde de tomme cellene båret verdier, ville summen manglet.
function belop(v: unknown): number {
  if (typeof v === 'number') return v
  if (v && typeof v === 'object') {
    const o = v as { result?: unknown; formula?: unknown; sharedFormula?: unknown }
    if (typeof o.result === 'number') return o.result
    if (o.formula !== undefined || o.sharedFormula !== undefined) return 0
  }
  return celletall(v as Parameters<typeof celletall>[0])
}

const KONTO = { salg: '3010', varekost: '4090', timelonn: '5012', fastlonn: '5010' } as const

type Celle = { value: unknown }
type StroemRad = { getCell(i: number): Celle; cellCount: number }

const tekst = (c: Celle | undefined) => celletekst((c?.value ?? null) as never).trim()

// Finner kolonneindeks fra overskriftsraden i stedet for å hardkode
// posisjoner — kolonnerekkefølgen har ingen garanti mellom BP-årganger.
function kolonner(rad: StroemRad): Map<string, number> {
  const ut = new Map<string, number>()
  for (let c = 1; c <= Math.max(rad.cellCount, 24); c++) {
    const navn = tekst(rad.getCell(c)).toLowerCase()
    if (navn && !ut.has(navn)) ut.set(navn, c)
  }
  return ut
}

// Akkumulator: kategorier og konti samles i Map under lesing og gjøres om til
// lister til slutt. Fila dekker 134 stasjoner × 12 måneder, så det er verdt å
// ikke bygge arrays underveis.
type Akk = {
  butikknummer: string
  timerAar: number | null
  maaneder: {
    maned: number
    salgKr: number; varekostKr: number; timelonnKr: number; fastlonnKr: number
    kategorier: Map<string, { post: string; salgKr: number; varekostKr: number }>
    konti: Map<string, { post: string; belopKr: number }>
  }[]
}

function tomStasjon(butikknummer: string): Akk {
  return {
    butikknummer,
    timerAar: null,
    maaneder: Array.from({ length: 12 }, (_, i) => ({
      maned: i + 1, salgKr: 0, varekostKr: 0, timelonnKr: 0, fastlonnKr: 0,
      kategorier: new Map(), konti: new Map(),
    })),
  }
}

// «120 [Mat]» → { kode: '120', post: '120 Mat' }. Formen matcher den
// regnskapslinjer allerede bruker, så BP og regnskap kan stilles side om side.
function kategori(raa: string): { kode: string; post: string } | null {
  const m = raa.match(/^(\d+)\s*\[(.+)\]$/)
  if (!m) return null
  return { kode: m[1], post: `${m[1]} ${m[2]}` }
}

// Kjenner igjen BP-fila uten å laste den. Arknavnene alene holder, og de kan
// strømmes for noen titalls MB i stedet for 2,3 GB. Ligger her og ikke i
// gjenkjenn.ts fordi den filen også kjøres i nettleseren.
export async function erBpFil(data: Buffer | ArrayBuffer): Promise<boolean> {
  const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data)
  const leser = new ExcelJS.stream.xlsx.WorkbookReader(Readable.from(buffer), {
    worksheets: 'emit', sharedStrings: 'ignore', styles: 'ignore',
    hyperlinks: 'ignore', entries: 'ignore',
  })
  const navn: string[] = []
  for await (const ws of leser as AsyncIterable<{ name: string }>) navn.push(ws.name.toLowerCase())
  return ER_BP.test(navn.join(' '))
}

export async function parseBp(data: Buffer | ArrayBuffer): Promise<BpResultat> {
  const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data)
  const leser = new ExcelJS.stream.xlsx.WorkbookReader(Readable.from(buffer), {
    worksheets: 'emit',
    sharedStrings: 'cache',
    styles: 'ignore',
    hyperlinks: 'ignore',
    entries: 'ignore',
  })

  const stasjoner = new Map<string, Akk>()
  const hent = (bnr: string): Akk => {
    const s = stasjoner.get(bnr)
    if (s) return s
    const ny = tomStasjon(bnr)
    stasjoner.set(bnr, ny)
    return ny
  }

  let ar: number | null = null
  let saaTimer = false
  let saaBudsjett = false

  for await (const ws of leser as AsyncIterable<{ name: string } & AsyncIterable<StroemRad>>) {
    const erTimer = /timebudsjett/i.test(ws.name)
    const erBudsjett = /budsjettfil/i.test(ws.name)
    // Hopp over ark vi ikke bruker — de store er nettopp dem.
    if (!erTimer && !erBudsjett) continue

    let kol: Map<string, number> | null = null
    let iBnr = 0, iKonto = 0, iBelop = 0, iAr = 0, iPr = 0, iKat = 0, iKontonavn = 0
    let forste = true

    for await (const rad of ws) {
      if (erTimer) {
        const bnr = tekst(rad.getCell(1))
        if (!/^\d{3,5}$/.test(bnr)) continue
        const timer = belop(rad.getCell(2).value)
        if (timer > 0) hent(bnr).timerAar = timer
        saaTimer = true
        continue
      }

      if (forste) {
        forste = false
        kol = kolonner(rad)
        iBnr = kol.get('butikknr') ?? 0
        iKonto = kol.get('kontonr') ?? 0
        iBelop = kol.get('beløp pivot') ?? kol.get('belop pivot') ?? 0
        iAr = kol.get('yr') ?? 0
        iPr = kol.get('pr') ?? 0
        iKat = kol.get('varekategori') ?? 0
        iKontonavn = kol.get('kontonavn') ?? 0
        if (!iBnr || !iKonto || !iBelop || !iPr) {
          throw new ParserFeil(
            'BP: «Budsjettfil til VB» mangler forventede kolonner (Butikknr, Kontonr, Beløp pivot, Pr).',
          )
        }
        continue
      }

      const bnr = tekst(rad.getCell(iBnr))
      if (!/^\d{3,5}$/.test(bnr)) continue
      const maned = Number.parseInt(tekst(rad.getCell(iPr)), 10)
      if (!(maned >= 1 && maned <= 12)) continue
      saaBudsjett = true

      if (ar === null && iAr) {
        const a = Number.parseInt(tekst(rad.getCell(iAr)), 10)
        if (a >= 2020 && a <= 2100) ar = a
      }

      const v = belop(rad.getCell(iBelop).value)
      if (v === 0) continue

      const konto = tekst(rad.getCell(iKonto))
      const m = hent(bnr).maaneder[maned - 1]

      if (konto === KONTO.salg || konto === KONTO.varekost) {
        const erSalg = konto === KONTO.salg
        if (erSalg) m.salgKr += -v // kredit i fila, positiv omsetning her
        else m.varekostKr += v

        // Varegruppen ligger som «120 [Mat]». Rader uten kategori er
        // kostnadsrader og hører ikke hjemme i omsetningsoppstillingen.
        const kat = iKat ? kategori(tekst(rad.getCell(iKat))) : null
        if (kat) {
          const k = m.kategorier.get(kat.kode) ?? { post: kat.post, salgKr: 0, varekostKr: 0 }
          if (erSalg) k.salgKr += -v
          else k.varekostKr += v
          m.kategorier.set(kat.kode, k)
        }
        continue
      }

      if (konto === KONTO.timelonn) m.timelonnKr += v
      else if (konto === KONTO.fastlonn) m.fastlonnKr += v

      // Alle øvrige konti tas med som de er — BP-en er et fullt månedsbudsjett
      // per stasjon, ikke bare timer og brutto, og de månedene som ennå ikke er
      // avlagt finnes ikke i regnskapslinjer fra noen annen kilde.
      if (/^\d{3,4}$/.test(konto)) {
        const navn = iKontonavn ? tekst(rad.getCell(iKontonavn)) : ''
        const post = navn ? `${konto} ${navn}` : `Konto ${konto}`
        const k = m.konti.get(konto) ?? { post, belopKr: 0 }
        k.belopKr += v
        m.konti.set(konto, k)
      }
    }
  }

  if (!saaTimer && !saaBudsjett) {
    throw new ParserFeil('BP: fant verken «Timebudsjett Grunnlagsfil» eller «Budsjettfil til VB».')
  }

  // Akkumulatorene gjøres om til lister, og brutto regnes til slutt.
  const ut: BpStasjon[] = []
  for (const s of stasjoner.values()) {
    const maaneder = s.maaneder.map((m) => ({
      maned: m.maned,
      salgKr: m.salgKr,
      varekostKr: m.varekostKr,
      bruttoKr: m.salgKr - m.varekostKr,
      timelonnKr: m.timelonnKr,
      fastlonnKr: m.fastlonnKr,
      kategorier: [...m.kategorier].map(([kode, k]) => ({ kode, ...k })),
      konti: [...m.konti].map(([kode, k]) => ({ kode, ...k })),
    }))
    if (s.timerAar === null && maaneder.every((m) => m.bruttoKr === 0)) continue
    ut.push({ butikknummer: s.butikknummer, timerAar: s.timerAar, maaneder })
  }

  return { rapporttype: 'st1_bp', ar, stasjoner: ut }
}
