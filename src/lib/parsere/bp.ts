import { celletall, ParserFeil } from './felles'
import { ER_BP } from './gjenkjenn'
import { lesArk, arknavn, type Celleverdi } from './xlsx-rader'
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
// ---------------------------------------------------------------------
// HVORFOR IKKE ExcelJS
//
// Fila er ~27 MB og inneholder ark på 289 000 rader vi ikke bruker. Full
// innlasting kostet 2,3 GB heap og 13 sekunder — ikke kjørbart i en
// funksjon. Strømming var svaret, og den holdt så lenge dette var det
// eneste BP-formatet.
//
// Men ExcelJS' strømmeleser MISTER VERDIER I STILLHET: en delt formel som
// peker tilbake med bare `si` mister sin bufrede `<v>`, selv om den står
// i XML-en. Det oppdaget vi da BP25 skulle leses — der ble Laguneparkens
// Mat 352 898 i stedet for 4 651 908, altså januar alene.
//
// «Budsjettfil til VB» er et eksportark med rene verdier, så dette arket
// har trolig aldri vært rammet. «Trolig» er ikke godt nok når tallet er et
// årsbudsjett: en slik feil gir ingen exception, bare et lavere tall.
// Derfor leses begge formatene nå med samme leser, og migreringen ble
// verifisert rad for rad mot den gamle — se `bp.test.ts`.
//
// `lesArk` pakker bare ut det arket vi spør etter. De 289 000 radene vi
// ikke bruker blir aldri dekomprimert.
// =====================================================================

// Mange celler er formler uten bufret verdi. Verifisert mot «Pivot»-arket at
// disse er nuller: summen av det som lot seg lese stemte på kronen med
// pivottotalene. Hadde de tomme cellene båret verdier, ville summen manglet.
function belop(v: Celleverdi | undefined): number {
  if (typeof v === 'number') return v
  if (v === undefined || v === null) return 0
  return celletall(v as Parameters<typeof celletall>[0])
}

const KONTO = { salg: '3010', varekost: '4090', timelonn: '5012', fastlonn: '5010' } as const

const tekst = (v: Celleverdi | undefined) =>
  v === undefined || v === null ? '' : String(v).trim()

// Finner kolonneindeks fra overskriftsraden i stedet for å hardkode
// posisjoner — kolonnerekkefølgen har ingen garanti mellom BP-årganger.
function kolonner(celler: Map<number, Celleverdi>): Map<string, number> {
  const ut = new Map<string, number>()
  for (const [nr, v] of celler) {
    const navn = tekst(v).toLowerCase()
    if (navn && !ut.has(navn)) ut.set(navn, nr)
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

/**
 * Kjenner igjen BP-fila uten å laste den. Arknavnene alene holder, og de
 * ligger i `xl/workbook.xml` — noen få kilobyte.
 *
 * Fortsatt `async` selv om den ikke trenger å være det: `kjerne.ts` kaller
 * den med `await … .catch(() => false)`, og signaturen er ikke verdt å
 * endre i samme slengen som lesemåten.
 */
export async function erBpFil(data: Uint8Array | ArrayBuffer): Promise<boolean> {
  const navn = arknavn(data).map((n) => n.toLowerCase())
  return ER_BP.test(navn.join(' '))
}

export async function parseBp(data: Uint8Array | ArrayBuffer): Promise<BpResultat> {
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

  // ---- Timebudsjettet ------------------------------------------------
  // Arket kan mangle i en revidert BP. Da er timene allerede lagret fra
  // forrige innlasting, og en tom `timerAar` er riktigere enn et kast.
  const harTimer = arknavn(data).some((n) => /timebudsjett/i.test(n))
  if (harTimer) {
    lesArk(data, (n) => /timebudsjett/i.test(n), (rad) => {
      const bnr = tekst(rad.celler.get(1))
      if (!/^\d{3,5}$/.test(bnr)) return
      const timer = belop(rad.celler.get(2))
      if (timer > 0) hent(bnr).timerAar = timer
      saaTimer = true
    })
  }

  // ---- Budsjettfil til VB --------------------------------------------
  const harBudsjett = arknavn(data).some((n) => /budsjettfil/i.test(n))
  if (harBudsjett) {
    let kol: Map<string, number> | null = null
    let iBnr = 0, iKonto = 0, iBelop = 0, iAr = 0, iPr = 0, iKat = 0, iKontonavn = 0

    lesArk(data, (n) => /budsjettfil/i.test(n), (rad) => {
      if (!kol) {
        kol = kolonner(rad.celler)
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
        return
      }

      const bnr = tekst(rad.celler.get(iBnr))
      if (!/^\d{3,5}$/.test(bnr)) return
      const maned = Number.parseInt(tekst(rad.celler.get(iPr)), 10)
      if (!(maned >= 1 && maned <= 12)) return
      saaBudsjett = true

      if (ar === null && iAr) {
        const a = Number.parseInt(tekst(rad.celler.get(iAr)), 10)
        if (a >= 2020 && a <= 2100) ar = a
      }

      const v = belop(rad.celler.get(iBelop))
      if (v === 0) return

      const konto = tekst(rad.celler.get(iKonto))
      const m = hent(bnr).maaneder[maned - 1]

      if (konto === KONTO.salg || konto === KONTO.varekost) {
        const erSalg = konto === KONTO.salg
        if (erSalg) m.salgKr += -v // kredit i fila, positiv omsetning her
        else m.varekostKr += v

        // Varegruppen ligger som «120 [Mat]». Rader uten kategori er
        // kostnadsrader og hører ikke hjemme i omsetningsoppstillingen.
        const kat = iKat ? kategori(tekst(rad.celler.get(iKat))) : null
        if (kat) {
          const k = m.kategorier.get(kat.kode) ?? { post: kat.post, salgKr: 0, varekostKr: 0 }
          if (erSalg) k.salgKr += -v
          else k.varekostKr += v
          m.kategorier.set(kat.kode, k)
        }
        return
      }

      if (konto === KONTO.timelonn) m.timelonnKr += v
      else if (konto === KONTO.fastlonn) m.fastlonnKr += v

      // Alle øvrige konti tas med som de er — BP-en er et fullt månedsbudsjett
      // per stasjon, ikke bare timer og brutto, og de månedene som ennå ikke er
      // avlagt finnes ikke i regnskapslinjer fra noen annen kilde.
      if (/^\d{3,4}$/.test(konto)) {
        const navn = iKontonavn ? tekst(rad.celler.get(iKontonavn)) : ''
        const post = navn ? `${konto} ${navn}` : `Konto ${konto}`
        const k = m.konti.get(konto) ?? { post, belopKr: 0 }
        k.belopKr += v
        m.konti.set(konto, k)
      }
    })
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
