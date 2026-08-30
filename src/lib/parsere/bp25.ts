import { lesArk, type Celleverdi } from './xlsx-rader'
import { ParserFeil } from './felles'
import type { BpResultat, BpStasjon, BpMaaned } from './typer'

// =====================================================================
// St1s GAMLE BP-mal — den som gjelder til og med budsjettåret 2025.
//
// BP26 er en helt annen arbeidsbok: norske arknavn, «Omsetning
// Grunnlagsfil», «Timebudsjett Grunnlagsfil», «Budsjettfil til VB».
// BP25 er St1s internasjonale mal med engelske arknavn — «CR-Sales»,
// «Costs», «Cluster data». Formatet kommer ikke tilbake; denne parseren
// finnes for at fjoråret skal kunne stilles ved siden av det nye.
//
// Begge arkene har en «VB indata»-blokk til høyre for det menneskene
// leser. Den er flat og selvbeskrivende — konto, stasjon, varegruppe,
// beløp, år og periode på hver rad — og det er den vi leser. Kolonnene
// finnes ved overskrift, ikke ved posisjon.
//
// ---------------------------------------------------------------------
// TO FELLER I DENNE FILA
//
// 1. «Budget year» ER GRUNNLAGSÅRET, IKKE BUDSJETTÅRET.
//    Fila heter BP25, men hvert eneste sted den nevner et årstall står
//    det 2024. Grunnlagsperioden er 01.09.23–31.08.24, og feltet merker
//    den perioden. Budsjettåret står ingensteds i fila.
//    Vi utleder det: grunnlagsperioden slutter i august, så budsjettet
//    gjelder året etter det siste grunnlagsåret.
//    BP26 gjør det motsatte — der er `Yr` budsjettåret (2026) direkte.
//    Samme etikett, motsatt betydning.
//
// 2. LØNNEN ER IKKE SPLITTET.
//    2025-malen fører hele stasjonens lønn på 5010 «Site Salary costs».
//    BP26 splitter i 5012 timelønn og 5010 butikksjefens fastlønn.
//    Vi later derfor IKKE som om vi vet splitten: `timelonnKr` og
//    `fastlonnKr` blir stående på 0, og hele beløpet ligger som konto.
//    Å legge alt på `fastlonnKr` ville gitt 4,6 mot 1,8 millioner mot
//    BP26 og sett ut som et voldsomt kutt som aldri har funnet sted.
// =====================================================================

const ARK_SALG = 'CR-Sales'
const ARK_KOST = 'Costs'

const tall = (v: Celleverdi | undefined): number =>
  typeof v === 'number' && Number.isFinite(v) ? v : 0
const tekst = (v: Celleverdi | undefined): string =>
  v === undefined || v === null ? '' : String(v).trim()

/** Overskriftsrad → alle kolonnene hver overskrift står i. */
function kolonner(celler: Map<number, Celleverdi>): Map<string, number[]> {
  const ut = new Map<string, number[]>()
  for (const [nr, v] of celler) {
    const navn = tekst(v).toLowerCase()
    if (!navn) continue
    const liste = ut.get(navn) ?? []
    liste.push(nr)
    ut.set(navn, liste)
  }
  for (const liste of ut.values()) liste.sort((a, b) => a - b)
  return ut
}

/**
 * SAMME OVERSKRIFT STÅR FLERE GANGER I RADEN, og det er ikke tilfeldig:
 * arkene har en menneskelesbar blokk til venstre og én VB-blokk per
 * bokføringslinje til høyre. «Period» finnes i «Costs» både i kolonne 9,
 * der den er «Jan», og i kolonne 16, der den er «01».
 *
 * Å ta den første ga `Number.parseInt('Jan')` → NaN, og alle 8 173
 * kostnadsrader falt ut i stillhet. Summen ble 0 kroner, ikke en feil.
 *
 * Derfor: kolonnen som hører til en blokk er den nærmeste ankeret —
 * kolonnen som navngir blokken — innenfor et vindu som er BLOKKENS EGET.
 *
 * Vinduet er ikke symmetrisk, og det er med vilje. I «CR-Sales» navngir
 * ankeret sin egen blokk og feltene følger etter (`VB-myynti`, så Site
 * ID, ProdCode, beløp, år, periode). I «Costs» står `Budget year` og
 * `Period` FORAN `VB AcNo`. Et symmetrisk vindu ville i CR-Sales plukket
 * menneskeblokkens år og periode, som ligger nærmere ankeret enn VB-
 * blokkens egne — og det virker helt til de to slutter å være like.
 *
 * 0 tilbake tvinger et kast hos den som spurte.
 */
function iBlokk(
  kol: Map<string, number[]>, navn: string, anker: number,
  fra: number, til: number,
): number {
  const treff = (kol.get(navn) ?? [])
    .filter((c) => c >= anker + fra && c <= anker + til)
  if (!treff.length) return 0
  return treff.sort((a, b) => Math.abs(a - anker) - Math.abs(b - anker))[0]
}

/** «120 MAT» → { kode: '120', post: '120 Mat' }. Samme form som BP26 gir. */
function varegruppe(raa: string): { kode: string; post: string } | null {
  const m = raa.trim().match(/^(\d{2,4})\s+(.+)$/)
  if (!m) return null
  const ord = m[2].toLowerCase()
  return { kode: m[1], post: `${m[1]} ${ord.charAt(0).toUpperCase()}${ord.slice(1)}` }
}

type Akk = {
  butikknummer: string
  maaneder: {
    maned: number
    salgKr: number; varekostKr: number
    kategorier: Map<string, { post: string; salgKr: number; varekostKr: number }>
    konti: Map<string, { post: string; belopKr: number }>
  }[]
}

function tomStasjon(butikknummer: string): Akk {
  return {
    butikknummer,
    maaneder: Array.from({ length: 12 }, (_, i) => ({
      maned: i + 1, salgKr: 0, varekostKr: 0,
      kategorier: new Map(), konti: new Map(),
    })),
  }
}

/**
 * Kjenner igjen den gamle malen på arknavnene. Leser bare `workbook.xml`
 * — noen kilobyte — så den kan brukes før man bestemmer seg for å parse.
 */
export function erBp25Fil(data: Uint8Array | ArrayBuffer): boolean {
  const funnet: string[] = []
  try {
    lesArk(data, (navn) => { funnet.push(navn); return false }, () => {})
  } catch {
    // lesArk kaster alltid når ingen ark velges — navnene er samlet inn.
  }
  const n = funnet.map((x) => x.toLowerCase())
  return n.includes('cr-sales') && n.includes('costs') && n.includes('cluster data')
}

export function parseBp25(data: Uint8Array | ArrayBuffer): BpResultat {
  const stasjoner = new Map<string, Akk>()
  const hent = (bnr: string): Akk => {
    const s = stasjoner.get(bnr)
    if (s) return s
    const ny = tomStasjon(bnr)
    stasjoner.set(bnr, ny)
    return ny
  }

  const grunnlagsaar = new Set<number>()
  let saaSalg = 0
  let saaKost = 0

  // ---- CR-Sales: omsetning, varekost og royalty per varegruppe --------
  // «Budget year» og «Period» står tre ganger i overskriftsraden, én gang
  // per VB-blokk (salg, innkjøp, royalty). Vi tar den første av hver og
  // stoler på at de tre blokkene gjelder samme rad — det gjør de, de er
  // tre linjer utledet av det samme månedsbeløpet.
  {
    let kol: Map<string, number[]> | null = null
    let iSalgSite = 0, iProd = 0, iSalgKr = 0, iAr = 0, iPr = 0
    let iKjopSite = 0, iKjopKr = 0
    let iRoySite = 0, iRoyKr = 0
    let iNavn = 0

    lesArk(data, (n) => n === ARK_SALG, (rad) => {
      if (!kol) {
        const k = kolonner(rad.celler)
        if (!k.has('vb-myynti') || !k.has('vb-ostot') || !k.has('vb-royalty')) return
        kol = k
        // Tre blokker, tre ankre: salg, innkjoep og royalty.
        const aSalg = k.get('vb-myynti')![0]
        const aKjop = k.get('vb-ostot')![0]
        const aRoy = k.get('vb-royalty')![0]
        // Feltene ligger ETTER sitt eget anker i CR-Sales.
        const e = (navn: string, anker: number) => iBlokk(k, navn, anker, 0, 7)
        iSalgSite = e('site id', aSalg); iProd = e('prodcode', aSalg)
        iSalgKr = e('crcurram', aSalg)
        iAr = e('budget year', aSalg); iPr = e('period', aSalg)
        iKjopSite = e('site id', aKjop); iKjopKr = e('dbcurram', aKjop)
        iRoySite = e('site id', aRoy); iRoyKr = e('dbcurram', aRoy)
        iNavn = 7
        if (!iSalgSite || !iProd || !iSalgKr || !iAr || !iPr) {
          throw new ParserFeil(
            'BP25: «CR-Sales» mangler forventede kolonner i VB-blokken (Site ID, ProdCode, CrCurrAm, Budget year, Period).',
          )
        }
        return
      }

      const site = tekst(rad.celler.get(iSalgSite))
      const pr = Number.parseInt(tekst(rad.celler.get(iPr)), 10)
      const kode = tekst(rad.celler.get(iProd))
      if (!/^\d{3,5}$/.test(site) || !(pr >= 1 && pr <= 12) || !/^\d{2,4}$/.test(kode)) return

      const ar = Number.parseInt(tekst(rad.celler.get(iAr)), 10)
      if (ar >= 2000 && ar <= 2100) grunnlagsaar.add(ar)

      const gruppe = varegruppe(tekst(rad.celler.get(iNavn))) ?? { kode, post: kode }
      const m = hent(site).maaneder[pr - 1]
      const salgKr = tall(rad.celler.get(iSalgKr))
      const varekostKr = iKjopSite && tekst(rad.celler.get(iKjopSite)) === site
        ? tall(rad.celler.get(iKjopKr)) : 0

      m.salgKr += salgKr
      m.varekostKr += varekostKr
      const k = m.kategorier.get(gruppe.kode) ?? { post: gruppe.post, salgKr: 0, varekostKr: 0 }
      k.salgKr += salgKr
      k.varekostKr += varekostKr
      m.kategorier.set(gruppe.kode, k)
      saaSalg++

      // Royaltyen staar eksplisitt per varegruppe og maaned. BP26 har den
      // bare som en samlet konto — her er den finere, og den summeres til
      // samme konto slik at de to aargangene kan sammenlignes.
      const royKr = iRoySite && tekst(rad.celler.get(iRoySite)) === site
        ? tall(rad.celler.get(iRoyKr)) : 0
      if (royKr) {
        const r = m.konti.get('6312') ?? { post: '6312 Royalty', belopKr: 0 }
        r.belopKr += royKr
        m.konti.set('6312', r)
      }
    })
  }

  // ---- Costs: driftskostnader per konto -------------------------------
  {
    let kol: Map<string, number[]> | null = null
    let iAr = 0, iPr = 0, iKonto = 0, iSite = 0, iDebet = 0, iKredit = 0
    const navnPerKonto = new Map<string, string>()

    lesArk(data, (n) => n === ARK_KOST, (rad) => {
      if (!kol) {
        const k = kolonner(rad.celler)
        if (!k.has('vb acno')) return
        kol = k
        // I «Costs» staar aar og periode FORAN kontoen.
        const anker = k.get('vb acno')![0]
        const e = (navn: string) => iBlokk(k, navn, anker, -3, 4)
        iKonto = anker
        iAr = e('budget year'); iPr = e('period')
        iSite = e('site id'); iDebet = e('dbcuram'); iKredit = e('crcuram')
        if (!iPr || !iKonto || !iSite || !iDebet) {
          throw new ParserFeil(
            'BP25: «Costs» mangler forventede kolonner i VB-blokken (Period, VB AcNo, Site Id, DbCurAm).',
          )
        }
        return
      }

      const site = tekst(rad.celler.get(iSite))
      const konto = tekst(rad.celler.get(iKonto))
      const pr = Number.parseInt(tekst(rad.celler.get(iPr)), 10)
      if (!/^\d{3,5}$/.test(site) || !/^\d{4}$/.test(konto) || !(pr >= 1 && pr <= 12)) return

      const ar = iAr ? Number.parseInt(tekst(rad.celler.get(iAr)), 10) : NaN
      if (ar >= 2000 && ar <= 2100) grunnlagsaar.add(ar)

      // Kontonavnet staar bare paa den foerste raden i hver blokk.
      const navn = tekst(rad.celler.get(8))
      if (navn && !navnPerKonto.has(konto)) navnPerKonto.set(konto, navn)

      const belop = tall(rad.celler.get(iDebet)) - (iKredit ? tall(rad.celler.get(iKredit)) : 0)
      if (belop === 0) return
      const m = hent(site).maaneder[pr - 1]
      const post = `${konto} ${navnPerKonto.get(konto) ?? ''}`.trim()
      const k = m.konti.get(konto) ?? { post, belopKr: 0 }
      k.belopKr += belop
      if (k.post === konto && navnPerKonto.has(konto)) k.post = post
      m.konti.set(konto, k)
      saaKost++
    })
  }

  if (!saaSalg && !saaKost) {
    throw new ParserFeil('BP25: fant ingen budsjettrader i «CR-Sales» eller «Costs».')
  }

  // FELLE 1: grunnlagsperioden slutter i august, saa budsjettet gjelder
  // aaret etter det siste grunnlagsaaret. Fila sier aldri 2025 selv.
  const ar = grunnlagsaar.size ? Math.max(...grunnlagsaar) + 1 : null

  const ut: BpStasjon[] = []
  for (const s of stasjoner.values()) {
    const maaneder: BpMaaned[] = s.maaneder.map((m) => ({
      maned: m.maned,
      salgKr: m.salgKr,
      varekostKr: m.varekostKr,
      bruttoKr: m.salgKr - m.varekostKr,
      // FELLE 2: splitten finnes ikke i denne malen. Se toppen av fila.
      timelonnKr: 0,
      fastlonnKr: 0,
      kategorier: [...m.kategorier].map(([kode, k]) => ({ kode, ...k })),
      konti: [...m.konti].map(([kode, k]) => ({ kode, ...k })),
    }))
    if (maaneder.every((m) => m.salgKr === 0 && m.konti.length === 0)) continue
    // Timebudsjettet finnes ikke i 2025-malen; det kom foerst med BP26.
    ut.push({ butikknummer: s.butikknummer, timerAar: null, maaneder })
  }

  return { rapporttype: 'st1_bp', ar, stasjoner: ut }
}
