// easy@work «Basis Export» — faktiske stemplinger per ansatt.
//
// Dette er den eneste kilden til hvem som faktisk står i butikken når.
// Salgstallene sier hvor mange kunder som kom; denne sier hvor mange hender
// som tok imot dem. Uten den kan bemanningsplanen bare foreslå, aldri måle.
//
// Parseren tar TEKST, ikke PDF. PDF-en gjøres om til tekst ett annet sted
// (pdf.ts, som er server-only fordi den drar inn unpdf). Da lar dette laget
// seg teste uten en fil på disk, og en fremtidig CSV-eksport fra easy@work
// treffer samme kode.

import type { Rapporttype } from './typer'

const MND = [
  'januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember',
] as const

export type Stempling = {
  ansattNr: string
  ansattNavn: string
  dato: string // ISO yyyy-mm-dd
  fraTid: string // HH:MM
  tilTid: string // HH:MM — «00:00» betyr midnatt, altså slutten av dagen
  minutter: number
  betalt: boolean
  lokasjon: string // «St1 - Bønes» — per rad, ikke per fil
}

export type StemplingResultat = {
  rapporttype: 'easyatwork_stempling'
  // Flertall med vilje. En eksport KAN inneholde flere stasjoner, og en
  // parser som returnerte «lokasjonen» ville lagt alle radene paa den
  // forste. Importlaget grupperer paa denne og matcher hver for seg.
  lokasjoner: string[]
  fraDato: string
  tilDato: string
  stemplinger: Stempling[]
}

// PDF-utpakking legger linjeskift midt inne i felter: «Betalt\ntid» og
// «Carmen\nValentina\nToro». Alt arbeid skjer derfor på én normalisert linje.
const flat = (tekst: string) => tekst.replace(/\s+/g, ' ').trim()

const TYPEFELT = /Betalt tid|Ubetalt tid|Pause/g

const POST = new RegExp(
  String.raw`(\d{1,2}) (${MND.join('|')}) (\d{4}) ` + // forretningsdato
  String.raw`(\d+) ` + // stemplingsnummer
  String.raw`(.+?) ` + // ansattnavn
  String.raw`(Betalt tid|Ubetalt tid|Pause) ` +
  String.raw`(\d{2}:\d{2}) (\d{2}:\d{2})` + // fra, til
  String.raw`(?: (\d+)t)?(?: (\d+)m)?`, // lengde
  'gi',
)

export function erStemplingFil(tekst: string): boolean {
  const t = flat(tekst)
  return /Forretningsdato/i.test(t) && /Stemplingsnummer/i.test(t)
}

// easy@work kan eksportere den samme rapporten som CSV. Det formatet er
// laget for maskiner og ikke for oyet, saa det skal foretrekkes: kolonnene
// staar navngitt i toppen, feltene er sitert, og lengden er desimaltimer
// i stedet for «5t 58m». Én eksport dekket 19 maaneder i én fil.
const erCsv = (tekst: string) => {
  const forste = tekst.split(/\r?\n/, 1)[0] ?? ''
  return forste.includes(',') && /Forretningsdato/i.test(forste)
}

// Minimal CSV-lesing: siterte felt med komma inni, og "" som escapet
// anforselstegn. Holder for dette formatet og sparer en avhengighet.
function csvRader(tekst: string): string[][] {
  const rader: string[][] = []
  let rad: string[] = []
  let felt = ''
  let iSitat = false
  for (let i = 0; i < tekst.length; i++) {
    const c = tekst[i]
    if (iSitat) {
      if (c === '"' && tekst[i + 1] === '"') { felt += '"'; i++ }
      else if (c === '"') iSitat = false
      else felt += c
    } else if (c === '"') iSitat = true
    else if (c === ',') { rad.push(felt); felt = '' }
    else if (c === '\n') { rad.push(felt); rader.push(rad); rad = []; felt = '' }
    else if (c !== '\r') felt += c
  }
  if (felt !== '' || rad.length > 0) { rad.push(felt); rader.push(rad) }
  return rader.filter((r) => r.some((f) => f.trim() !== ''))
}

const DATO = new RegExp(String.raw`(\d{1,2}) (${MND.join('|')}) (\d{4})`, 'i')

function parseCsv(tekst: string): Stempling[] {
  const rader = csvRader(tekst.replace(/^\uFEFF/, ''))
  const hode = rader[0].map((h) => h.trim().toLowerCase())
  const kol = (navn: string) => hode.indexOf(navn)
  const iDato = kol('forretningsdato')
  const iNr = kol('stemplingsnummer')
  const iNavn = kol('ansatt')
  const iType = kol('type')
  const iFra = kol('fra')
  const iTil = kol('til')
  const iLengde = kol('lengde')
  const iLok = kol('lokasjon')
  if ([iDato, iNr, iNavn, iType, iFra, iTil].some((i) => i < 0)) {
    throw new Error('CSV-en mangler en av kolonnene Forretningsdato/Stemplingsnummer/Ansatt/Type/Fra/Til.')
  }

  return rader.slice(1).map((r, n) => {
    const d = (r[iDato] ?? '').trim().match(DATO)
    if (!d) throw new Error(`Rad ${n + 2}: forsto ikke datoen «${r[iDato]}».`)
    const mnd = MND.indexOf(d[2].toLowerCase() as (typeof MND)[number]) + 1
    // Gaar vakten over midnatt, skriver easy@work hele datoen i Til-feltet:
    // «15 februar 2025 00:00». Klokkeslettet er det siste i strengen uansett.
    const tid = (v: string) => {
      const m = [...(v ?? '').matchAll(/(\d{1,2}):(\d{2})/g)].pop()
      if (!m) throw new Error(`Rad ${n + 2}: forsto ikke klokkeslettet «${v}».`)
      return `${m[1].padStart(2, '0')}:${m[2]}`
    }
    return {
      ansattNr: (r[iNr] ?? '').trim(),
      ansattNavn: (r[iNavn] ?? '').replace(/\s+/g, ' ').trim(),
      dato: `${d[3]}-${String(mnd).padStart(2, '0')}-${d[1].padStart(2, '0')}`,
      fraTid: tid(r[iFra]),
      tilTid: tid(r[iTil]),
      // Lengden staar i desimaltimer (5.88), ikke «5t 53m».
      minutter: Math.round(Number((r[iLengde] ?? '0').trim().replace(',', '.')) * 60),
      betalt: (r[iType] ?? '').trim().toLowerCase() === 'betalt tid',
      lokasjon: (iLok >= 0 ? (r[iLok] ?? '') : '').replace(/\s+/g, ' ').trim(),
    }
  })
}

export function gjenkjennStempling(tekst: string): Rapporttype {
  return erStemplingFil(tekst) ? 'easyatwork_stempling' : 'ukjent'
}

/**
 * Leser alle stemplinger ut av teksten.
 *
 * Kaster hvis antall poster ikke stemmer med antall typefelt i teksten.
 *
 * Det er ikke overforsiktighet. Første versjon av denne parseren mistet 25 %
 * av postene — hvert navn med `ø`, fordi tegnklassen for navn ikke hadde den,
 * og hver post der mellomrommet foran «Betalt tid» manglet. Feilen var helt
 * stille: resultatet så konsistent ut over tre måneder, og analysen på det
 * konkluderte med at stasjonen sto ubemannet halve kveldene. Den var bemannet.
 * De tapte postene var kveldsvaktene, fordi tre av dem het Løvfall, Forstrønen
 * og Toro.
 *
 * En parser som mister rader i stillhet er verre enn en som kaster.
 */
export function parseStempling(tekst: string): StemplingResultat {
  const t = flat(tekst)
  if (!erStemplingFil(t)) {
    throw new Error('Ikke en Basis Export — mangler Forretningsdato/Stemplingsnummer.')
  }

  const csv = erCsv(tekst)
  const forventet = csv
    ? csvRader(tekst.replace(/^\uFEFF/, '')).length - 1
    : (t.match(TYPEFELT) ?? []).length
  const stemplinger: Stempling[] = csv ? parseCsv(tekst) : []

  for (const m of csv ? [] : t.matchAll(POST)) {
    const [, dag, maaned, ar, nr, navn, type, fra, til, timer, min] = m
    const mnd = MND.indexOf(maaned.toLowerCase() as (typeof MND)[number]) + 1
    stemplinger.push({
      ansattNr: nr,
      ansattNavn: navn.replace(/\s+/g, ' ').trim(),
      dato: `${ar}-${String(mnd).padStart(2, '0')}-${dag.padStart(2, '0')}`,
      fraTid: fra,
      tilTid: til,
      minutter: Number(timer ?? 0) * 60 + Number(min ?? 0),
      betalt: type.toLowerCase() === 'betalt tid',
      lokasjon: '', // settes under - PDF-en har den bare som lopende tekst
    })
  }

  if (stemplinger.length !== forventet) {
    throw new Error(
      `Stemplingsfila har ${forventet} poster, men bare ${stemplinger.length} lot seg lese. ` +
      'Formatet har trolig endret seg — importen stoppes framfor å lagre et ufullstendig bilde.',
    )
  }
  if (stemplinger.length === 0) {
    throw new Error('Fant ingen stemplinger i fila.')
  }

  // PDF-en har lokasjonen som lopende tekst bak hver post, ikke i en kolonne.
  // Finner vi nøyaktig én, gjelder den hele fila. Finner vi flere, nekter vi -
  // en gjetning her ville lagt en hel stasjons timer på en annen, og det
  // ville ingen oppdaget.
  if (!csv) {
    const funnet = [...new Set(
      [...t.matchAll(/St1\s*-\s*[A-Za-zÆØÅæøåÉéÜü .'-]+/g)]
        .map((m) => m[0].replace(/\s+/g, ' ').replace(/[\s-]+$/, '').trim()),
    )]
    if (funnet.length > 1) {
      throw new Error(
        `Fila inneholder flere stasjoner (${funnet.join(', ')}). `
        + 'Eksporter én stasjon om gangen, eller bruk CSV-formatet, som har lokasjon per rad.',
      )
    }
    for (const s of stemplinger) s.lokasjon = funnet[0] ?? ''
  }

  const datoer = stemplinger.map((s) => s.dato).sort()
  return {
    rapporttype: 'easyatwork_stempling',
    lokasjoner: [...new Set(stemplinger.map((s) => s.lokasjon))].filter(Boolean),
    fraDato: datoer[0],
    tilDato: datoer[datoer.length - 1],
    stemplinger,
  }
}

/**
 * Vakter, ikke stemplinger.
 *
 * Folk stempler ut og inn igjen på samme vakt — 13 av 132 postene i juli var
 * under 45 minutter. Teller man dem som vakter, blir snittlengden meningsløs
 * (4,9 t i stedet for 6,0). Sammenhengende poster på samme dag for samme
 * person slås derfor sammen når det er under en time mellom dem.
 */
export function vakter(stemplinger: Stempling[]): Stempling[] {
  const sortert = [...stemplinger]
    .filter((s) => s.betalt)
    .sort((a, b) => (a.ansattNr + a.dato + a.fraTid).localeCompare(b.ansattNr + b.dato + b.fraTid))

  const ut: Stempling[] = []
  for (const s of sortert) {
    const forrige = ut[ut.length - 1]
    const samme = forrige && forrige.ansattNr === s.ansattNr && forrige.dato === s.dato
    if (samme && minutterMellom(forrige.tilTid, s.fraTid) <= 60) {
      forrige.tilTid = s.tilTid
      forrige.minutter += s.minutter
      continue
    }
    ut.push({ ...s })
  }
  return ut
}

const iMin = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5))
function minutterMellom(fra: string, til: string): number {
  const d = iMin(til) - iMin(fra)
  return d < 0 ? d + 24 * 60 : d
}
