import { Unzip, UnzipInflate } from 'fflate'
import { ParserFeil } from './felles'

// =====================================================================
// Å LESE ETT ARK UT AV EN STOR ARBEIDSBOK — UTEN Å LASTE DEN
//
// ExcelJS har to lesemåter, og begge feiler på St1s BP-maler:
//
//   full innlasting   riktig, men BP25 koster 2,1 GB heap og 9 sekunder.
//                     «CR-Sales» alene er 97 MB utpakket XML, fordi arket
//                     er formatert helt ned til rad 1 048 576.
//
//   strømming         billig, men MISTER VERDIER I STILLHET. Excel skriver
//                     en delt formel én gang med `ref`, og lar de øvrige
//                     cellene peke tilbake med bare `si`:
//
//                       <c r="AA4"><f t="shared" ref="AA4:AA17" si="5">…</f><v>352897.52</v></c>
//                       <c r="AA5"><f t="shared" si="5"/><v>324980.60</v></c>
//
//                     Den bufrede `<v>` står der i begge. ExcelJS' strømmeleser
//                     gir den bare for den første. Målt på BP25: 60 av 576
//                     salgsrader kom gjennom, og Laguneparkens Mat ble
//                     352 898 — som er januar alene — i stedet for 4 651 908.
//
// EN SLIK FEIL ROPER IKKE. Den gir et tall som ser ut som et tall, og et
// budsjett som ser ut som et budsjett. Derfor leses XML-en her direkte:
// `<v>` tas som den står, uansett hvilken form formelen rundt har.
//
// Minnebruken er konstant. Fila pakkes ut i biter, og bare det arket vi
// spør etter blir dekomprimert i det hele tatt — de øvrige hoppes over
// uten å røres.
// =====================================================================

export type Celleverdi = string | number | null

/** Én rad. `celler` er glissen — bare celler som faktisk har innhold. */
export type XlsxRad = { nr: number; celler: Map<number, Celleverdi> }

// A→1, Z→26, AA→27. Kolonnereferansen står i hver celles `r`-attributt.
function kolonnenummer(bokstaver: string): number {
  let n = 0
  for (let i = 0; i < bokstaver.length; i++) {
    n = n * 26 + (bokstaver.charCodeAt(i) - 64)
  }
  return n
}

const ENTITETER: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'",
}
function avkod(s: string): string {
  if (!s.includes('&')) return s
  return s.replace(/&(?:#(\d+)|#x([0-9a-fA-F]+)|(\w+));/g, (hele, des, hex, navn) => {
    if (des) return String.fromCodePoint(Number(des))
    if (hex) return String.fromCodePoint(Number.parseInt(hex, 16))
    return ENTITETER[navn] ?? hele
  })
}

/**
 * Pakker ut de delene av zip-en som `vil()` sier ja til, og gir dem videre
 * som tekst. Deler vi ikke vil ha blir aldri dekomprimert.
 *
 * `paaBit` kalles med hver bit etter hvert som den kommer, slik at et 97 MB
 * ark kan behandles uten å ligge i minnet samtidig.
 */
function pakkUt(
  data: Uint8Array,
  vil: (navn: string) => boolean,
  paaBit: (navn: string, tekst: string, ferdig: boolean) => void,
): void {
  const uz = new Unzip()
  uz.register(UnzipInflate)
  const dekodere = new Map<string, TextDecoder>()
  uz.onfile = (fil) => {
    if (!vil(fil.name)) return
    dekodere.set(fil.name, new TextDecoder('utf-8'))
    fil.ondata = (feil, bit, ferdig) => {
      if (feil) throw new ParserFeil(`Klarte ikke pakke ut «${fil.name}»: ${feil.message}`)
      const d = dekodere.get(fil.name)!
      paaBit(fil.name, d.decode(bit, { stream: !ferdig }), ferdig)
    }
    fil.start()
  }
  uz.push(data, true)
}

/** Samler en hel (liten) del til én streng. */
function lesHele(data: Uint8Array, navn: string): string {
  let ut = ''
  pakkUt(data, (n) => n === navn, (_n, t) => { ut += t })
  return ut
}

// «<si><t>Mat</t></si>» → ['Mat']. Rik tekst har flere <t> i samme <si>;
// de skal settes sammen, ikke velges mellom.
function delteStrenger(xml: string): string[] {
  const ut: string[] = []
  for (const m of xml.matchAll(/<si>([\s\S]*?)<\/si>/g)) {
    let s = ''
    for (const t of m[1].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)) s += t[1]
    ut.push(avkod(s))
  }
  return ut
}

/**
 * Arknavnene, i bokas rekkefølge. Leser bare `xl/workbook.xml` — noen få
 * kilobyte — så en fil kan kjennes igjen uten at noe ark pakkes ut.
 */
export function arknavn(data: Uint8Array | ArrayBuffer): string[] {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data)
  const wb = lesHele(bytes, 'xl/workbook.xml')
  if (!wb) throw new ParserFeil('Fant ingen xl/workbook.xml – er dette en xlsx-fil?')
  // TRIMMET. Et arknavn med mellomrom bak ser identisk ut i Excel, og
  // `'timer '.includes('timer')` er sant mens `navn.includes('timer')`
  // på en liste er usant. En gjenkjenning som feiler på et usynlig tegn
  // gir «ukjent filtype» på en fil som er helt i orden.
  return [...wb.matchAll(/<sheet\b[^>]*\/?>/g)]
    .map((m) => avkod(m[0].match(/\bname="([^"]*)"/)?.[1] ?? '').trim())
    .filter(Boolean)
}

/** Finner hvilken XML-del et ark ligger i. Rekkefølgen i zip-en sier ingenting. */
function arkdel(data: Uint8Array, velg: (navn: string) => boolean): { del: string; navn: string } {
  const wb = lesHele(data, 'xl/workbook.xml')
  const rels = lesHele(data, 'xl/_rels/workbook.xml.rels')
  if (!wb) throw new ParserFeil('Fant ingen xl/workbook.xml – er dette en xlsx-fil?')

  const stier = new Map<string, string>()
  for (const m of rels.matchAll(/<Relationship\b[^>]*>/g)) {
    const id = m[0].match(/\bId="([^"]+)"/)?.[1]
    const mal = m[0].match(/\bTarget="([^"]+)"/)?.[1]
    if (id && mal) stier.set(id, mal.startsWith('/') ? mal.slice(1) : `xl/${mal.replace(/^\.\//, '')}`)
  }

  const funnet: string[] = []
  for (const m of wb.matchAll(/<sheet\b[^>]*\/?>/g)) {
    // Trimmet, som i `arknavn`. Sto det bare det ene stedet, ville
    // gjenkjenningen sagt ja til fila og lesingen så ikke funnet arket.
    const navn = avkod(m[0].match(/\bname="([^"]*)"/)?.[1] ?? '').trim()
    const rid = m[0].match(/\br:id="([^"]+)"/)?.[1]
    funnet.push(navn)
    if (navn && rid && velg(navn)) {
      const del = stier.get(rid)
      if (!del) throw new ParserFeil(`Arket «${navn}» har ingen del i workbook.xml.rels.`)
      return { del, navn }
    }
  }
  throw new ParserFeil(`Fant ikke arket. Arkene i fila er: ${funnet.join(', ')}.`)
}

/**
 * Leser ett navngitt ark rad for rad.
 *
 * `velg` får hvert arknavn og skal si ja til det ene vi vil ha. `paaRad`
 * kalles én gang per rad som har innhold; tomme rader hoppes over uten å
 * bygges. Kaster hvis arket ikke finnes — et tomt resultat og et fraværende
 * ark må ikke se like ut.
 */
export function lesArk(
  data: Uint8Array | ArrayBuffer,
  velg: (arknavn: string) => boolean,
  paaRad: (rad: XlsxRad) => void,
): { arknavn: string; antallRader: number } {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data)
  const { del, navn } = arkdel(bytes, velg)
  const delte = delteStrenger(lesHele(bytes, 'xl/sharedStrings.xml'))

  let rest = ''
  let antall = 0

  const behandle = (tekst: string, ferdig: boolean) => {
    rest += tekst
    // Radene tas ut etter hvert som de blir hele. Halen blir liggende til
    // neste bit — en rad kan godt være delt midt over av en zip-bit.
    for (;;) {
      const start = rest.indexOf('<row ')
      if (start < 0) break
      const slutt = rest.indexOf('</row>', start)
      if (slutt < 0) {
        // Kan være en tom, selvlukkende rad: <row r="9" .../>
        const selvlukket = /<row\b[^>]*\/>/.exec(rest.slice(start))
        if (selvlukket && selvlukket.index === 0) {
          rest = rest.slice(start + selvlukket[0].length)
          continue
        }
        break
      }
      const raa = rest.slice(start, slutt)
      rest = rest.slice(slutt + 6)
      const nr = Number.parseInt(raa.match(/\br="(\d+)"/)?.[1] ?? '0', 10)
      const celler = new Map<number, Celleverdi>()
      for (const c of raa.matchAll(/<c\b([^>]*?)(\/>|>([\s\S]*?)<\/c>)/g)) {
        const attr = c[1]
        const innhold = c[3] ?? ''
        const ref = attr.match(/\br="([A-Z]+)\d+"/)?.[1]
        if (!ref) continue
        const type = attr.match(/\bt="([^"]+)"/)?.[1] ?? 'n'

        let verdi: Celleverdi = null
        if (type === 'inlineStr') {
          let s = ''
          for (const t of innhold.matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)) s += t[1]
          verdi = avkod(s)
        } else {
          // DET AVGJØRENDE: <v> tas som den står. Om formelen rundt er
          // vanlig, delt med `ref`, eller delt med bare `si`, spiller ingen
          // rolle — den bufrede verdien er den samme.
          const v = innhold.match(/<v[^>]*>([\s\S]*?)<\/v>/)?.[1]
          if (v === undefined) continue
          if (type === 's') verdi = delte[Number.parseInt(v, 10)] ?? null
          else if (type === 'str' || type === 'e') verdi = avkod(v)
          else if (type === 'b') verdi = v === '1' ? 1 : 0
          else {
            const n = Number(v)
            verdi = Number.isFinite(n) ? n : avkod(v)
          }
        }
        if (verdi !== null && verdi !== '') celler.set(kolonnenummer(ref), verdi)
      }
      if (celler.size) {
        antall++
        paaRad({ nr, celler })
      }
    }
    if (ferdig) rest = ''
  }

  pakkUt(bytes, (n) => n === del, (_n, t, ferdig) => behandle(t, ferdig))
  return { arknavn: navn, antallRader: antall }
}
