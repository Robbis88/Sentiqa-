// Månedsplanen til butikksjefen.
//
// =====================================================================
// MEDVIND OG MOTVIND FÅR IKKE SAMME PLAN
// =====================================================================
//
//   MEDVIND  →  bekreft det som går bra, og gi dem NESTE løftestang.
//               Det beste tidspunktet å ta fatt på noe nytt er når du
//               allerede vinner.
//   MOTVIND  →  ÉN ting. Den største. Ikke fem.
//
// En liste med fem tiltak til noen som holder på å miste grepet er ikke
// en plan, det er en anklage. Og «fortsett sånn» til noen som vinner er
// ikke en plan i det hele tatt.
//
// ---------------------------------------------------------------------
// TEKSTEN SKRIVES UT AV TALLENE, IKKE AV EN MODELL
//
// Samme regel som `ingressFor` i ukebriefen: samme tall skal gi samme
// setning hver gang, og ingen modell skal kunne finne på å tolke den. Et
// brev som sender seg selv har ingen til å ta forbehold for seg.
//
// ---------------------------------------------------------------------
// TRE TING PLANEN ALDRI GJØR
//
//   1. Nevner en kostnadslinje utenfor `BUTIKKSJEF_BEGREP`.
//   2. Bryter opp lønn. Total mot totalt budsjett, aldri splitten.
//   3. Ber om en endring på noe klassifisert som FØLGE.
//
// Alle tre er felt av tester med kanarifugl. Den tredje er den lettest
// glemte: en følge ligger ofte over budsjett, ser ut som et funn, og
// «få ned 590» betyr i praksis «betal mindre pensjon».

import { verdiAvGevinst, type Satser } from '@/lib/royalty'
import {
  DRIFT_BEGREP, LOFTESTENGER, type Klasse, type Loftestang, type LoftestangId,
} from './loftestenger'
import { erBra, erIlle, retning, type Kurs } from './retning'

export type Maanedstall = {
  /** ISO, første i måneden. */
  maaned: string
  omsetningKr: number
  omsetningBudsjettKr: number
  /** Bruttofortjeneste. Brukes til å verdsette omsetningsvekst. */
  bruttoKr: number
  matsalgKr: number
  matkastKr: number
  /** Manko utenom mat og vask. Positivt tall er mangel. */
  usynligRestKr: number
  personalKr: number
  personalBudsjettKr: number
  paavirkbarDriftKr: number
  paavirkbarDriftBudsjettKr: number
  resultatKr: number
}

/** Én linje fra `bilagssum`, for den siste måneden. */
export type Leverandorrad = {
  begrep: string | null
  tekst: string
  belopKr: number
  antall: number
}

export type Maanedsdata = {
  stasjonNavn: string
  /** Eldste først. Trenger minst tre for at retning skal bety noe. */
  historikk: readonly Maanedstall[]
  leverandorer: readonly Leverandorrad[]
  /**
   * Royaltysatsene. `null` når kjeden ikke har lastet opp BP med dem —
   * og da vises INGEN kroneverdier. Feiler lukket: et tall uten satser
   * ville vært brutto utgitt for netto.
   */
  satser: Satser | null
}

export type Dom = 'medvind' | 'motvind' | 'flat'

export type Planpunkt = {
  slag: 'bekreftelse' | 'tiltak'
  loftestang: LoftestangId
  tittel: string
  tekst: string
  /** `null` når satsene mangler. Ikke 0 — det ville vært en påstand. */
  kronerIAret: number | null
  /** Hvem pengene gikk til, når linja har en leverandør som peker seg ut. */
  leverandor?: string
}

export type Maanedsplan = {
  stasjonNavn: string
  maaned: string
  dom: Dom
  ingress: string
  punkter: Planpunkt[]
  /** Sagt rett ut når planen ikke kunne regne kroner. */
  merknad: string | null
}

// --- hjelpere ---------------------------------------------------------

const kr = (n: number) =>
  (n < 0 ? '−' : '') + Math.round(Math.abs(n)).toLocaleString('nb-NO').replace(/ /g, ' ')

const fortegn = (n: number) => (n >= 0 ? '+' : '−')
  + Math.round(Math.abs(n)).toLocaleString('nb-NO').replace(/ /g, ' ')

type Verdi = { l: Loftestang; serie: number[]; kurs: Kurs; naa: number }

/** Tallet løftestangen måles på, per måned. */
function serieFor(id: LoftestangId, h: readonly Maanedstall[]): number[] {
  switch (id) {
    case 'omsetning': return h.map((m) => m.omsetningKr - m.omsetningBudsjettKr)
    case 'matkast': return h.map((m) => m.matkastKr)
    case 'usynlig_rest': return h.map((m) => m.usynligRestKr)
    case 'personal': return h.map((m) => m.personalKr - m.personalBudsjettKr)
    case 'paavirkbar_drift':
      return h.map((m) => m.paavirkbarDriftKr - m.paavirkbarDriftBudsjettKr)
  }
}

/**
 * Hva bevegelsen i denne løftestangen er verdt i året.
 *
 * GÅR GJENNOM `verdiAvGevinst`, alltid. Forskjellen mellom en
 * marginforbedring (royaltyfri) og en volumvekst (betaler satsen) er
 * nettopp den som er lett å miste når regnestykket ligger spredt.
 */
function kronerIAret(v: Verdi, m: Maanedstall, satser: Satser | null): number | null {
  if (!satser) return null
  const perMaaned = Math.abs(v.kurs.endring)
  if (v.l.gevinst === 'margin') {
    return verdiAvGevinst({ type: 'margin', kroner: perMaaned }, satser) * 12
  }
  const margin = m.omsetningKr > 0 ? m.bruttoKr / m.omsetningKr : 0.5
  return verdiAvGevinst(
    { type: 'volum', omsetningKr: perMaaned, bruttomargin: margin, kanal: 'ordinaer' },
    satser,
  ) * 12
}

/**
 * Leverandøren som peker seg ut på driftslinja.
 *
 * Bare begreper butikksjefen skal se, og bare de som er SPAK. En
 * leverandør som er en følge — WashTec på vaskemaskinen — skal ikke stå
 * i en plan som ber om noe.
 */
function stoersteLeverandor(
  rader: readonly Leverandorrad[],
  klasseFor: (r: Leverandorrad) => Klasse,
): Leverandorrad | null {
  const aktuelle = rader
    .filter((r) => r.begrep !== null && (DRIFT_BEGREP as readonly string[]).includes(r.begrep))
    .filter((r) => klasseFor(r) === 'spak')
    .filter((r) => r.belopKr > 0)
  if (aktuelle.length === 0) return null
  return aktuelle.reduce((a, b) => (b.belopKr > a.belopKr ? b : a))
}

// --- selve planen -----------------------------------------------------

export type Byggopsjoner = {
  /**
   * Hvilken klasse en leverandørrad hører til. Avgjøres per stasjon:
   * `634` er WashTec på en stasjon med vask, kjøl og bygg på Dale.
   * Standard er `spak` — den som kaller vet bedre.
   */
  klasseFor?: (r: Leverandorrad) => Klasse
}

export function byggMaanedsplan(d: Maanedsdata, o: Byggopsjoner = {}): Maanedsplan {
  const klasseFor = o.klasseFor ?? (() => 'spak' as Klasse)
  const siste = d.historikk[d.historikk.length - 1]
  if (!siste) throw new Error('byggMaanedsplan: tom historikk')

  const resKurs = retning(d.historikk.map((m) => m.resultatKr))
  const dom: Dom = resKurs === null || resKurs.vei === 'flat'
    ? 'flat'
    : resKurs.vei === 'opp' ? 'medvind' : 'motvind'

  // BARE SPAKER. En følge kan ligge over budsjett hele året uten at noen
  // kan gjøre noe, og et tiltak på den er en beskjed om å gjøre det
  // umulige.
  const vurdert: Verdi[] = []
  for (const l of LOFTESTENGER) {
    if (l.klasse !== 'spak') continue
    const serie = serieFor(l.id, d.historikk)
    const kurs = retning(serie)
    if (!kurs) continue
    vurdert.push({ l, serie, kurs, naa: serie[serie.length - 1] })
  }

  const verdi = (v: Verdi) => kronerIAret(v, siste, d.satser) ?? 0
  const ille = vurdert.filter((v) => erIlle(v.kurs, v.l.god))
    .sort((a, b) => verdi(b) - verdi(a))
  const bra = vurdert.filter((v) => erBra(v.kurs, v.l.god))
    .sort((a, b) => verdi(b) - verdi(a))

  const punkter: Planpunkt[] = []

  const tiltak = (v: Verdi): Planpunkt => {
    const lev = v.l.id === 'paavirkbar_drift'
      ? stoersteLeverandor(d.leverandorer, klasseFor)
      : null
    const deler = [
      `Den har gått feil vei ${v.kurs.paaRad >= 3 ? `${v.kurs.paaRad} måneder på rad` : 'de siste månedene'}.`,
      `Nå på ${kr(v.naa)} kroner.`,
    ]
    if (lev) {
      deler.push(`Størst: ${lev.tekst}, ${kr(lev.belopKr)} kroner på ${lev.antall} ${lev.antall === 1 ? 'bilag' : 'bilag'}.`)
    }
    return {
      slag: 'tiltak',
      loftestang: v.l.id,
      tittel: v.l.navn,
      tekst: `${deler.join(' ')} ${v.l.forklaring}`,
      kronerIAret: kronerIAret(v, siste, d.satser),
      ...(lev ? { leverandor: lev.tekst } : {}),
    }
  }

  const bekreftelse = (v: Verdi): Planpunkt => ({
    slag: 'bekreftelse',
    loftestang: v.l.id,
    tittel: v.l.navn,
    tekst: v.kurs.paaRad >= 3
      ? `Riktig vei ${v.kurs.paaRad} måneder på rad. Nå på ${kr(v.naa)} kroner.`
      : `Riktig vei. Nå på ${kr(v.naa)} kroner.`,
    kronerIAret: kronerIAret(v, siste, d.satser),
  })

  if (dom === 'medvind') {
    if (bra[0]) punkter.push(bekreftelse(bra[0]))
    // NESTE løftestang, ikke «fortsett sånn».
    if (ille[0]) punkter.push(tiltak(ille[0]))
  } else if (dom === 'motvind') {
    // ÉN ting. Den største.
    if (ille[0]) punkter.push(tiltak(ille[0]))
  } else {
    // Flat: ingen retning å melde. Da er den største som går feil vei
    // fortsatt verdt å nevne, men ingen bekreftelse — flatt er ikke ros.
    if (ille[0]) punkter.push(tiltak(ille[0]))
  }

  const resSerie = d.historikk.map((m) => m.resultatKr)
  const ingress = (() => {
    const naa = `Resultatet i ${maanedsnavn(siste.maaned)} er ${kr(siste.resultatKr)} kroner.`
    if (d.historikk.length < 2) return naa
    const foerst = resSerie[0]
    const endring = siste.resultatKr - foerst
    const fra = `I ${maanedsnavn(d.historikk[0].maaned)} var det ${kr(foerst)}.`
    if (dom === 'flat') return `${naa} ${fra} Det har holdt seg jevnt.`
    return `${naa} ${fra} Det er ${fortegn(endring)} på ${d.historikk.length} måneder.`
  })()

  return {
    stasjonNavn: d.stasjonNavn,
    maaned: siste.maaned,
    dom,
    ingress,
    punkter,
    merknad: d.satser
      ? null
      : 'Kroneverdier vises ikke: kjeden mangler royaltysatser fra BP, og '
        + 'uten dem ville tallene vært bruttofortjeneste utgitt for netto.',
  }
}

const MAANEDER = [
  'januar', 'februar', 'mars', 'april', 'mai', 'juni',
  'juli', 'august', 'september', 'oktober', 'november', 'desember',
]

export function maanedsnavn(iso: string): string {
  const m = Number(iso.slice(5, 7))
  return MAANEDER[m - 1] ?? iso
}
