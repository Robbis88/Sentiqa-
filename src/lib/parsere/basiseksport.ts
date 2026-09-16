// easy@work «Basis Export», CSV-varianten.
//
// =====================================================================
// HVORFOR DENNE FILA I DET HELE TATT
//
// Daglig lønnskost kan ikke se hvor arbeidet skjedde. Den HAR en
// `Lokasjon`-kolonne, og `lonnsgrunnlag.ts` leser den per dagslinje —
// men målt over 4 620 dagslinjer i 23 filer er den lik `Hovedlokasjon`
// uten ett eneste unntak. Kolonnen finnes; den bærer aldri ny
// informasjon.
//
// Følgen er verre enn at timene mangler. En ansatt som jobbet hele
// måneden på en annen stasjon står i sin egen stasjons fil med NULL
// timer. Hun forsvinner ikke — hun dukker opp som en troverdig null.
// På Bønes i juli 2026 gjaldt det 97,31 timer og 15 191 kroner: 10,9 %
// av stasjonens konto 503, og feilen går alltid samme vei — for lite
// lønn, altså for mye lønnsrom.
//
// Basis Export bærer `Lokasjon` PER RAD, og den er arbeidsstedet.
//
// ---------------------------------------------------------------------
// DEN ANDRE FORMEN LIGGER I `stempling.ts`
//
// Samme rapport kan hentes som PDF. Den parseren tar tekst og leter med
// regex fordi PDF-en ikke har kolonner. Denne tar CSV-en, som har en
// ordentlig topprad. Begge gir `Stempling`, så resten av systemet skal
// ikke merke hvilken vei fila kom.
//
// ---------------------------------------------------------------------
// «FRA» ER IKKE ALLTID ET KLOKKESLETT
//
// Krysser vakten døgnet, skriver easy@work av og til HELE datoen i
// `Fra`:
//
//     Forretningsdato  2026-07-31
//     Fra              «1 august 2026 00:00»
//     Til              «00:55»
//
// Fire slike rader i Dales fil for 2025-04 → 2026-07. En parser som
// bare leste klokkeslettet ville fått `NaN` — eller verre, riktig
// timetall på feil ukedag, og dermed feil tillegg. Derfor bærer
// `Basisstempling` både forretningsdatoen og datoen arbeidet faktisk
// startet.
// =====================================================================

import type { Rapporttype } from './typer'
import type { Stempling } from './stempling'

const MND = [
  'januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember',
] as const

/**
 * En stempling fra Basis Export.
 *
 * `dato` er FORRETNINGSDATOEN — den easy@work fører vakten på, og den
 * lønnsarteksporten grupperer etter. `fraDato` er datoen arbeidet
 * faktisk begynte. De er like for alt annet enn døgnkryssende vakter,
 * og det er `fraDato` tilleggsfordelingen må bruke: en vakt som starter
 * 1. august er mandag selv om den føres på søndag 31. juli.
 */
export type Basisstempling = Stempling & { fraDato: string }

/**
 * En rad slik fila faktisk skrev den.
 *
 * `Basisstempling` er det MOTOREN trenger. Denne er det IMPORTEN trenger:
 * to felt til som skal bevares i `basisvakt`, men som ingen beregning
 * leser.
 *
 * Egen type framfor aa utvide `Basisstempling`, fordi den brukes som
 * fixture i flere tester. Et nytt paakrevd felt der ville tvunget fram
 * endringer i vakter som ikke har noe med kilden aa gjoere - og en diff
 * som roerer en vakt uten grunn er en diff ingen leser noeye.
 */
export type Basisrad = Basisstempling & {
  /**
   * Easy@Works eget timetall, ubehandlet. `null` naar feltet ikke lot
   * seg lese som et tall.
   *
   * Den er den mer presise av de to - `Fra` og `Til` er kuttet til hele
   * minutt, mens `Lengde` baerer sekundene - og det er den kronefila
   * stemmer med. Motoren priser likevel intervallet i dag. HVILKEN som
   * skal vaere oekonomisk fasit er ikke avgjort her; kilden bevarer
   * begge, og valget tas naar begge er maalt mot kronefilene.
   */
  lengde: number | null
  /** Raa `Type`: «Betalt tid», «Ubetalt tid», «Pause». `betalt` utledes av den. */
  type: string
}

/**
 * En vakt der «Lengde» og klokkeslettene ikke kan forenes.
 *
 * MÅLT: én rad av 7 943 i sju filer. «09:10–11:00» med `Lengde` 25,82 —
 * nøyaktig ett døgn for mye, altså en glemt utstempling.
 *
 * Den blir IKKE priset, og den blir IKKE gjettet på. Å tolke den som 25
 * timers arbeid ville lagt inn kostnad som ikke finnes; å anta hvilken
 * dag vakten egentlig startet ville vært en slutning dataene ikke
 * bærer. Den skal fram til et menneske og rettes i easy@work — samme
 * prinsipp som for utdaterte satser: korrekt Easy-data inn, ellers
 * varsler Sentiqa.
 */
export type Lengdeavvik = {
  /**
   * Hva som gjorde raden uleselig.
   *
   *   `lengde`     «Lengde» og klokkeslettene kan ikke forenes
   *   `lokasjon`   raden mangler arbeidssted
   */
  grunn: 'lengde' | 'lokasjon'
  ansattNr: string
  ansattNavn: string
  dato: string
  /**
   * Datoen arbeidet begynte. Baeres ogsaa her, selv om en avvist rad
   * aldri prises: den skal LAGRES, og en rad som lagres uten fra_dato
   * kan ikke skilles fra en doegnkryssende vakt senere.
   */
  fraDato: string
  fraTid: string
  tilTid: string
  lokasjon: string
  /** Raa `Type`, og den utledede boolen. Bevares av samme grunn. */
  type: string
  betalt: boolean
  /** Intervallet i minutter. `intervallTimer` er den avrundede formen. */
  minutter: number
  /** Det fila oppgir. */
  lengde: number
  /** Det klokkeslettene gir. */
  intervallTimer: number
}

export type BasiseksportResultat = {
  rapporttype: Extract<Rapporttype, 'easyatwork_stempling'>
  /** Flertall med vilje — se `stempling.ts`. Én eksport kan bære flere. */
  lokasjoner: string[]
  fraDato: string
  tilDato: string
  stemplinger: Basisrad[]
  /** Vakter som ikke lot seg lese. Tom liste er det normale. */
  avvik: Lengdeavvik[]
}

// Minimal CSV-lesing, samme form som i `lonnsgrunnlag.ts`, `lonnsart.ts`
// og `stempling.ts`. Å dele den mellom fire parsere ville bundet dem
// sammen for lite gevinst.
function csvRader(tekst: string): string[][] {
  const rader: string[][] = []
  let rad: string[] = []
  let felt = ''
  let iSitat = false
  for (let i = 0; i < tekst.length; i++) {
    const c = tekst[i]
    if (iSitat) {
      if (c === '"') {
        if (tekst[i + 1] === '"') { felt += '"'; i++ } else iSitat = false
      } else felt += c
      continue
    }
    if (c === '"') { iSitat = true; continue }
    if (c === ',') { rad.push(felt); felt = ''; continue }
    if (c === '\n') { rad.push(felt); rader.push(rad); rad = []; felt = ''; continue }
    if (c === '\r') continue
    felt += c
  }
  if (felt !== '' || rad.length) { rad.push(felt); rader.push(rad) }
  return rader
}

const noekkel = (s: string): string =>
  s.trim().toLowerCase().replace(/^﻿/, '').replace(/\s+/g, ' ')

/** «1 juli 2026» → «2026-07-01». Null hvis det ikke er en dato. */
export function norskDato(s: string): string | null {
  const m = s.trim().match(/^(\d{1,2})\.?\s+([A-Za-zÆØÅæøå]+)\s+(\d{4})$/)
  if (!m) return null
  const i = MND.indexOf(m[2].toLowerCase() as typeof MND[number])
  if (i < 0) return null
  return `${m[3]}-${String(i + 1).padStart(2, '0')}-${m[1].padStart(2, '0')}`
}

/** «1 august 2026 00:00» → dato + klokkeslett. Null for et bart klokkeslett. */
function datoOgTid(s: string): { dato: string; tid: string } | null {
  const m = s.trim().match(/^(\d{1,2}\.?\s+[A-Za-zÆØÅæøå]+\s+\d{4})\s+(\d{1,2}):(\d{2})$/)
  if (!m) return null
  const dato = norskDato(m[1])
  if (!dato) return null
  return { dato, tid: `${m[2].padStart(2, '0')}:${m[3]}` }
}

const KLOKKE = /^(\d{1,2}):(\d{2})$/

/**
 * Et klokkeslett, eller null.
 *
 * MINUTTENE MÅ VALIDERES, IKKE BARE TIMENE. Første utgave sjekket bare
 * `time > 24`. «12:75» slapp da gjennom og ble til 13:15 i `Date.UTC`,
 * som regner over av seg selv — en umulig verdi ville blitt et
 * troverdig tidspunkt en time for sent, uten at noe ble rødt.
 *
 * «24:00» godtas som slutten av døgnet; det er samme betydning som
 * «00:00» har i `Til`. Andre timer over 23 finnes ikke.
 */
function tid(s: string): string | null {
  const m = s.trim().match(KLOKKE)
  if (!m) return null
  const t = Number(m[1])
  const min = Number(m[2])
  if (min > 59) return null
  if (t > 24 || (t === 24 && min !== 0)) return null
  return `${m[1].padStart(2, '0')}:${m[2]}`
}

const tall = (s: string): number => {
  const t = (s ?? '').replace(/\s| /g, '').replace(',', '.')
  if (t === '') return NaN
  const n = Number(t)
  return Number.isFinite(n) ? n : NaN
}

/**
 * Ser dette ut som Basis Export?
 *
 * `Forretningsdato` er kolonnen ingen av de andre eksportene har.
 * Lønnsgrunnlaget deler `Stemplingsnummer` med denne, men har `Dato` og
 * `Hovedlokasjon` — og kravet om at `Hovedlokasjon` IKKE finnes holder
 * de to fra hverandre selv om easy@work en dag legger til en kolonne.
 */
export function erBasiseksportFil(tekst: string): boolean {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  if (!rader.length) return false
  const nk = rader[0].map(noekkel)
  return nk.includes('forretningsdato')
    && nk.includes('stemplingsnummer')
    && nk.includes('lokasjon')
    && !nk.includes('hovedlokasjon')
}

/**
 * Leser Basis Export.
 *
 * KASTER HELLER ENN Å HOPPE OVER. En rad vi ikke forstår er timer som
 * stille blir borte, og manglende timer ser ut som en rolig måned —
 * samme innsats som at lønnsgrunnlaget kaster på en ukjent kolonne.
 */
export function lesBasiseksport(tekst: string): BasiseksportResultat {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  if (!rader.length) throw new Error('Basis Export var tom.')
  const nk = rader[0].map(noekkel)

  const k = (navn: string): number => {
    const i = nk.indexOf(navn)
    if (i < 0) throw new Error(`Basis Export mangler kolonnen «${navn}».`)
    return i
  }
  const iDato = k('forretningsdato')
  const iNr = k('stemplingsnummer')
  const iNavn = k('ansatt')
  const iType = k('type')
  const iFra = k('fra')
  const iTil = k('til')
  const iLengde = k('lengde')
  const iLok = k('lokasjon')

  const stemplinger: Basisrad[] = []
  const avvik: Lengdeavvik[] = []
  const lokasjoner = new Set<string>()
  const datoer: string[] = []

  for (const r of rader.slice(1)) {
    if (!r.some((c) => c.trim() !== '')) continue
    const raaDato = (r[iDato] ?? '').trim()
    if (raaDato === '') continue
    const dato = norskDato(raaDato)
    if (!dato) throw new Error(`Ugyldig forretningsdato i Basis Export: «${raaDato}».`)

    // `Fra` bærer av og til hele datoen — se toppen av fila.
    const raaFra = (r[iFra] ?? '').trim()
    const medDato = datoOgTid(raaFra)
    const fraDato = medDato?.dato ?? dato
    const fraTid = medDato?.tid ?? tid(raaFra)
    if (!fraTid) throw new Error(`Ugyldig «Fra» i Basis Export på ${dato}: «${raaFra}».`)

    const raaTil = (r[iTil] ?? '').trim()
    const tilTid = tid(raaTil)
    if (!tilTid) throw new Error(`Ugyldig «Til» i Basis Export på ${dato}: «${raaTil}».`)

    const minutter = minutterMellom(fraDato, fraTid, tilTid)

    // LENGDEN ER EN PÅSTAND VI KONTROLLERER, IKKE EN VI STOLER PÅ.
    // Skiller `Lengde` lag med intervallet, betyr én av de to noe annet
    // enn vi tror — og da er hver time på fila i tvil, ikke bare den ene
    // raden. Samme innsats som «KOPIEN MÅ VÆRE EN KOPI» i
    // lønnsgrunnlaget.
    //
    // TOLERANSEN ER IKKE VILKÅRLIG, OG DEN ER IKKE JUSTERT FOR Å FÅ
    // GRØNT. `Fra` og `Til` er kuttet til hele minutt, mens `Lengde`
    // bærer sekundene: en vakt stemplet 12:06:__ til 18:00 står med
    // «12:06» og `Lengde` 5,88. Kuttet kan koste inntil 59 sekunder i
    // hver ende, altså knapt to minutter = 0,033 timer. 0,04 ligger like
    // over det og fanger fortsatt en `Lengde` som betyr noe annet — en
    // som inkluderte pausen ville bommet med en halvtime.
    //
    // MERK at `Lengde` dermed er den mer presise av de to. Det er den
    // kronefila stemmer med. Tilleggsfordelingen må uansett ha
    // klokkeslettene for å finne døgn- og timegrensene, og drifta det
    // gir er målt: 653,32 mot 653,11 timer på Bønes juli — 0,03 %.
    const lengde = tall(r[iLengde] ?? '')

    if (Number.isFinite(lengde) && Math.abs(lengde - minutter / 60) > 0.04) {
      // RAPPORTERES, IKKE KASTET PAA. En glemt utstempling skal ikke
      // stenge en hel aarsfil ute - men den skal heller ikke prises.
      avvik.push({
        grunn: 'lengde',
        ansattNr: (r[iNr] ?? '').trim(),
        ansattNavn: (r[iNavn] ?? '').trim(),
        dato,
        fraDato,
        fraTid,
        tilTid,
        lokasjon: (r[iLok] ?? '').trim(),
        type: (r[iType] ?? '').trim(),
        betalt: (r[iType] ?? '').trim().toLowerCase() === 'betalt tid',
        minutter,
        lengde,
        intervallTimer: Math.round((minutter / 60) * 100) / 100,
      })
      continue
    }

    const lokasjon = (r[iLok] ?? '').trim()
    // ARBEIDSSTEDET ER HELE POENGET MED DENNE FILA. En rad uten
    // lokasjon kan ikke føres noe sted, og en tom streng ville blitt sin
    // egen «stasjon» — timene havnet i en gruppe ingen ser på, mens den
    // ekte stasjonen så komplett ut. Det er nøyaktig formen på det
    // hullet vi bygde denne modulen for å lukke.
    if (lokasjon === '') {
      avvik.push({
        grunn: 'lokasjon',
        ansattNr: (r[iNr] ?? '').trim(),
        ansattNavn: (r[iNavn] ?? '').trim(),
        dato,
        fraDato,
        fraTid,
        tilTid,
        lokasjon,
        type: (r[iType] ?? '').trim(),
        betalt: (r[iType] ?? '').trim().toLowerCase() === 'betalt tid',
        minutter,
        lengde,
        intervallTimer: Math.round((minutter / 60) * 100) / 100,
      })
      continue
    }
    lokasjoner.add(lokasjon)
    datoer.push(dato)

    stemplinger.push({
      ansattNr: (r[iNr] ?? '').trim(),
      ansattNavn: (r[iNavn] ?? '').trim(),
      dato,
      fraDato,
      fraTid,
      tilTid,
      minutter,
      // Betalt tid er den eneste typen som er observert i noen av de sju
      // filene. `Ubetalt tid` og `Pause` finnes i PDF-varianten, så de
      // skal fortsatt kjennes igjen — men de skal ikke prises.
      betalt: (r[iType] ?? '').trim().toLowerCase() === 'betalt tid',
      lokasjon,
      // BEVARES, IKKE BRUKT HER. Se `Basisrad`.
      lengde: Number.isFinite(lengde) ? lengde : null,
      type: (r[iType] ?? '').trim(),
    })
  }

  if (!stemplinger.length) throw new Error('Basis Export hadde ingen stemplinger.')
  datoer.sort()
  return {
    rapporttype: 'easyatwork_stempling',
    lokasjoner: [...lokasjoner].filter(Boolean).sort(),
    fraDato: datoer[0],
    tilDato: datoer[datoer.length - 1],
    stemplinger,
    avvik,
  }
}

/**
 * Minutter mellom to klokkeslett på et døgn som kan krysses.
 *
 * TRE TILFELLER, OG DE MÅ SKILLES.
 *
 *   til > fra        vanlig vakt, samme døgn
 *   til < fra        vakten krysser midnatt
 *   til == fra       NULL minutter — ikke et døgn
 *
 * Det siste er ikke teoretisk. MÅLT: «16:00–16:00» med `Lengde` 0,01 og
 * «05:00–05:00» med `Lengde` 0. En regel som sa «slutt ≤ start betyr
 * neste døgn» gjorde dem til 24 timer hver, og `Lengde`-kontrollen over
 * fanget det — men bare fordi den fantes.
 *
 * «Til 00:00» er unntaket fra unntaket: der BETYR det midnatt, altså
 * slutten av døgnet. En vakt 18:00–00:00 er seks timer, ikke minus seks.
 */
export function minutterMellom(dato: string, fra: string, til: string): number {
  const [Y, M, D] = dato.split('-').map(Number)
  const [fh, fm] = fra.split(':').map(Number)
  const [th, tm] = til.split(':').map(Number)
  const start = Date.UTC(Y, M - 1, D, fh, fm)
  let slutt = Date.UTC(Y, M - 1, D, th, tm)
  if (slutt === start) return 0
  if (slutt < start) slutt += 86_400_000
  return Math.round((slutt - start) / 60_000)
}
