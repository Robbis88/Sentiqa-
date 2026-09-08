// easy@work lønnsgrunnlag — timer og antall per ansatt per dag.
//
// =====================================================================
// DEN TREDJE EKSPORTEN, OG DEN ENESTE SOM FINNES OVERALT
//
//     Basis Export     når var noen på jobb           → `stempling.ts`
//     lønnsarter       timer OG kroner                → `lonnsart.ts`
//     lønnsgrunnlag    timer og antall, ingen kroner  → denne
//
// `lonnsart.ts` avviste denne fila med en skrevet begrunnelse: kroner
// måtte da regnes av satstabellen, og «to veier til samme sum er to
// steder de kan skille lag». Resonnementet holdt; premisset gjorde det
// ikke. Lønnsarteksporten finnes bare for TRE av fem stasjoner. For de
// to andre var alternativet ikke et dårligere tall, men ingen tall.
//
// Satsene ligger i `lib/lonn/tilleggssats.ts` og er MÅLT mot
// kronefilene, ikke lest av overenskomsten. Én av dem hadde blitt gal
// den andre veien — se kommentaren der.
//
// ---------------------------------------------------------------------
// FILA ER EN RAPPORT MED DELSUMMER, IKKE EN LISTE
//
// Fire nivåer ligger om hverandre i de samme kolonnene:
//
//     stasjonssum       Lokasjon satt, Dato tom, ingen ansatt
//     ansattsum         Hovedlokasjon satt, Dato tom
//     ansatt per sted   Lokasjon OG Hovedlokasjon satt, Dato tom
//     dagslinje         Dato satt                          ← den eneste
//
// Leses alt, tredobles timene. Det ville ikke sett ut som en feil; det
// ville sett ut som en stasjon med altfor høy bemanning. Bare
// dagslinjene leses.
//
// ---------------------------------------------------------------------
// KOLONNER SLÅS OPP PÅ NAVN, ALDRI PÅ POSISJON
//
// Rapporten er satt sammen av kolonner noen har huket av i easy@work.
// Legger noen til én til, forskyves alt til høyre for den — og en
// parser som teller fra venstre ville lest tillegg som kjøregodtgjørelse
// uten å si fra. Navnet er det eneste som er stabilt.
// =====================================================================

import type { Rapporttype } from './typer'
import type { Lonnsartlinje } from './lonnsart'
import { belopFor } from '@/lib/lonn/tilleggssats'

/**
 * Kolonnenavnet, redusert til det som faktisk skiller lønnsartene.
 *
 * ===================================================================
 * HVER STASJON HAR SIN EGEN KOLONNEOPPSETNING
 * ===================================================================
 * Rapporten settes sammen av avhukede kolonner i easy@work, og det er
 * gjort per stasjon. Laguneparken og Lone leverte samme rapport for
 * samme måned med ulike navn OG ulik rekkefølge:
 *
 *     Laguneparken   «Etterbetaling Tillegg lørdag (antall)»
 *     Lone           «Etterbetaling Tillegg lørdag (antall)»   likt
 *
 *     Laguneparken   «50% O.tidstillegg dag»
 *     Lone           «50% Overtidstillegg Timelønnede (Timer)»  ulikt
 *
 * Prefikset «Etterbetaling » og halen «(antall)» / «(Timer)» bærer
 * ingen informasjon om hvilken lønnsart det er. De strippes, og resten
 * slås opp i `LONNSART`. Det som ikke treffes der, er fortsatt et funn.
 */
const noekkel = (navn: string): string => navn
  .trim()
  .toLowerCase()
  .replace(/^etterbetaling\s+/, '')
  .replace(/\s*\((?:antall|timer|antall km|beløp[^)]*)\)\s*$/, '')
  .replace(/\s+/g, ' ')

/**
 * Lønnsart → alle kolonnenavnene som har betydd den, normalisert.
 *
 * ETIKETTEN ER NØKKELEN i `lonnsart_linje`, så den må være den samme i
 * begge filene der de beskriver det samme. Da er en ny opplasting en
 * retting, ikke en dublett.
 *
 * Overtiden er unntaket, og det er med vilje. Lønnsarteksporten skiller
 * seks varianter (96 dag/uke, 97 dag/uke/dag man-lør 00-06/uke søn);
 * denne fila har to kolonner som hver bærer summen av sine. Å låne en
 * av variantetikettene ville påstått en presisjon fila ikke har, så de
 * får sitt eget navn — og importen passer på at de to filene ikke
 * legges oppå hverandre.
 *
 * Lones navn på dem — «50 % Overtidstillegg Timelønnede» — er dessuten
 * det mest presise av de to: Laguneparkens «O.tidstillegg dag 100 %
 * søn» bærer ALL 100 %-overtid, ikke bare søndagens.
 */
const LONNSART: { kode: string; tekst: string; navn: string[] }[] = [
  { kode: '2', tekst: '2 Timelønn', navn: ['timer'] },
  { kode: '12', tekst: '12 Sykelønn', navn: ['sykelønn'] },
  { kode: '1429', tekst: '1429 Tillegg hverdag 18-21', navn: ['tillegg hverdag 18-21'] },
  { kode: '1430', tekst: '1430 Tillegg hverdag 21-24', navn: ['tillegg hverdag 21-24'] },
  { kode: '1431', tekst: '1431 Tillegg hverdag 00-06', navn: ['tillegg hverdag 00-06'] },
  { kode: '1432', tekst: '1432 Tillegg lørdag', navn: ['tillegg lørdag'] },
  { kode: '1433', tekst: '1433 Tillegg søndag 00-06', navn: ['tillegg søndag 00-06'] },
  { kode: '1434', tekst: '1434 Tillegg søndag 06-18', navn: ['tillegg søndag 06-18'] },
  { kode: '1435', tekst: '1435 Tillegg søndag 18-24', navn: ['tillegg søndag 18-24'] },
  {
    kode: '96',
    tekst: '96 Overtidstillegg 50 %',
    navn: ['50% o.tidstillegg dag', '50% overtidstillegg timelønnede'],
  },
  {
    kode: '97',
    tekst: '97 Overtidstillegg 100 %',
    navn: ['o.tidstillegg dag 100% søn', '100% overtidstillegg timelønnede'],
  },
]

const KOLONNE = new Map(
  LONNSART.flatMap((a) => a.navn.map((n) => [n, a] as const)),
)

/** Feltene som beskriver raden, ikke en lønnsart. */
const RADFELT = new Set([
  'stemplingsnummer', 'ansatt', 'lønn', 'betalingsfrekvens',
  'lokasjon', 'hovedlokasjon', 'dato',
])

/**
 * Kolonner som bærer de ordinære timene en gang til.
 *
 * ===================================================================
 * PÅSTANDEN KONTROLLERES, DEN ANTAS IKKE
 * ===================================================================
 * Begge rapportene hadde en slik kolonne, med hvert sitt navn:
 * Laguneparken «Etterbetaling Ordinære timer (antall)», Lone
 * «Timelønn». Begge er identiske med `Timer` på øret i hver eneste
 * dagslinje — 158 og 124 av dem. Leses de med, dobles timelønna, og
 * lønnsandelen ser ut som en stasjon som har mistet kontrollen.
 *
 * Men «denne kolonnen er en kopi» er en antakelse om en fil vi ikke
 * har sett ennå. Derfor sjekkes den mot `Timer` rad for rad ved hver
 * lesing: skiller de lag, betyr kolonnen noe annet enn vi tror, og
 * fila avvises i stedet for å bli lest halvveis.
 */
const KOPI_AV_TIMER = new Set(['ordinære timer', 'timelønn'])

export type LonnsgrunnlagResultat = {
  rapporttype: 'easyatwork_lonnsgrunnlag'
  lokasjoner: string[]
  fraDato: string
  tilDato: string
  linjer: Lonnsartlinje[]
}

// Minimal CSV-lesing, samme form som i `stempling.ts` og `lonnsart.ts`.
// Å dele den mellom tre parsere ville bundet dem sammen for lite gevinst.
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

const ISO_DATO = /^\d{4}-\d{2}-\d{2}$/

const tall = (s: string): number => {
  const t = (s ?? '').replace(/ /g, '').replace(/\s/g, '').replace(',', '.')
  if (t === '') return 0
  const n = Number(t)
  return Number.isFinite(n) ? n : NaN
}

/** Rada med kolonnenavnene. Den står ikke først — over den ligger perioden. */
function finnTopprad(rader: string[][]): number {
  for (let i = 0; i < Math.min(rader.length, 10); i++) {
    if ((rader[i]?.[0] ?? '').trim() === 'Stemplingsnummer') return i
  }
  return -1
}

/**
 * Ser dette ut som lønnsgrunnlaget?
 *
 * `Betalingsfrekvens` er kolonnen ingen av de andre eksportene har.
 * Basis Export deler `Stemplingsnummer` med denne, men har
 * `Forretningsdato` der denne har `Dato` — og den kjennes uansett igjen
 * først. Kravet om `Timer` holder en fremtidig eksport med de samme to
 * kolonnene, men uten noe å telle, ute.
 */
export function erLonnsgrunnlagFil(tekst: string): boolean {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  const i = finnTopprad(rader)
  if (i < 0) return false
  const nk = rader[i].map(noekkel)
  return nk.includes('betalingsfrekvens') && nk.includes('timer')
}

export function gjenkjennLonnsgrunnlag(tekst: string): Rapporttype {
  return erLonnsgrunnlagFil(tekst) ? 'easyatwork_lonnsgrunnlag' : 'ukjent'
}

/**
 * Leser dagslinjene ut av lønnsgrunnlaget og priser dem.
 *
 * KASTER PÅ ALT DEN IKKE FORSTÅR — en ukjent kolonne med en verdi i, en
 * dato som ikke er ISO, en timesats som mangler. En stille utelatelse
 * her blir til lønnskost som ikke finnes, og det ser ut som en god
 * måned.
 */
export function lesLonnsgrunnlag(tekst: string): LonnsgrunnlagResultat {
  const rader = csvRader(tekst.replace(/^﻿/, ''))
  const iTopp = finnTopprad(rader)
  if (iTopp < 0) throw new Error('Fant ingen topprad med «Stemplingsnummer».')
  const navn = rader[iTopp].map((x) => x.trim())

  const noekler = navn.map(noekkel)

  // EN KOLONNE VI IKKE KJENNER ER ET FUNN, IKKE EN DETALJ. Rapporten
  // settes sammen av avhukede kolonner i easy@work, og en ny av dem er
  // en lønnsart vi ikke priser. Den skal si fra — men først når den
  // faktisk bærer et tall, ellers ville en tom valgfri kolonne stengt
  // hele fila ute. Ni slike sto tomme i august 2026: matpenger,
  // ansvarstillegg, kjøregodtgjørelse, helligdagsgodtgjørelse,
  // overtid for fastlønnede, fastlønn og vasketillegg.
  const ukjente = navn
    .map((n, i) => ({ n, i, nk: noekler[i] }))
    .filter(({ n, nk }) => n !== ''
      && !RADFELT.has(nk) && !KOPI_AV_TIMER.has(nk) && !KOLONNE.has(nk))

  // Kolonnene som skal bære de samme timene som `Timer`. Påstanden
  // kontrolleres per rad under.
  const kopier = navn
    .map((n, i) => ({ n, i, nk: noekler[i] }))
    .filter(({ nk }) => KOPI_AV_TIMER.has(nk))

  const k = (nk: string): number => {
    const i = noekler.indexOf(nk)
    if (i < 0) throw new Error(`Lønnsgrunnlaget mangler kolonnen «${nk}».`)
    return i
  }
  const iNr = k('stemplingsnummer')
  const iNavn = k('ansatt')
  const iSats = k('lønn')
  const iLok = k('lokasjon')
  const iHoved = k('hovedlokasjon')
  const iDato = k('dato')
  const iTimer = k('timer')

  const linjer: Lonnsartlinje[] = []
  const lokasjoner = new Set<string>()
  const datoer: string[] = []

  for (const r of rader.slice(iTopp + 1)) {
    const dato = (r[iDato] ?? '').trim()
    if (dato === '') continue // delsum — se toppen av fila
    if (!ISO_DATO.test(dato)) throw new Error(`Ugyldig dato i lønnsgrunnlaget: «${dato}».`)

    for (const { n, i } of ukjente) {
      const v = tall(r[i] ?? '')
      if (v) {
        throw new Error(
          `Lønnsgrunnlaget har kolonnen «${n}» med verdi ${v}, og den har ingen `
          + 'lønnsart i Sentiqa. Kroner kan ikke regnes før den er kartlagt mot '
          + 'lønnsarteksporten.',
        )
      }
    }

    // KOPIEN MÅ VÆRE EN KOPI. Skiller den lag med `Timer`, betyr
    // kolonnen noe annet enn vi tror, og da er hver time på fila i
    // tvil — ikke bare den ene raden.
    const timerHer = tall(r[iTimer] ?? '')
    for (const { n, i } of kopier) {
      const v = tall(r[i] ?? '')
      if (Math.abs(v - timerHer) > 0.005) {
        throw new Error(
          `Kolonnen «${n}» skulle bære de samme timene som «Timer», men står `
          + `med ${v} mot ${timerHer} på ${dato}. Den er ikke en kopi, og må `
          + 'kartlegges mot lønnsarteksporten før fila kan leses.',
        )
      }
    }

    const timesats = tall(r[iSats] ?? '')
    if (!Number.isFinite(timesats)) {
      throw new Error(`Ugyldig timesats «${r[iSats]}» på ${dato}.`)
    }
    const lokasjon = (r[iLok] ?? '').trim() || (r[iHoved] ?? '').trim()
    lokasjoner.add(lokasjon)
    datoer.push(dato)

    for (const art of LONNSART) {
      const i = noekler.findIndex((nk) => art.navn.includes(nk))
      if (i < 0) continue // valgfri kolonne, ikke med i denne rapporten
      const timer = tall(r[i] ?? '')
      if (!Number.isFinite(timer)) {
        throw new Error(`Ugyldig antall i «${navn[i]}» på ${dato}.`)
      }
      if (timer === 0) continue
      linjer.push({
        ansattNr: (r[iNr] ?? '').trim(),
        ansattNavn: (r[iNavn] ?? '').trim(),
        dato,
        lonnsart: art.kode,
        lonnsartTekst: art.tekst,
        timer,
        belopKr: belopFor(art.kode, timer, timesats),
        lokasjon,
      })
    }
  }

  if (!linjer.length) throw new Error('Lønnsgrunnlaget hadde ingen dagslinjer.')
  datoer.sort()
  return {
    rapporttype: 'easyatwork_lonnsgrunnlag',
    lokasjoner: [...lokasjoner].filter(Boolean).sort(),
    fraDato: datoer[0],
    tilDato: datoer[datoer.length - 1],
    linjer,
  }
}
