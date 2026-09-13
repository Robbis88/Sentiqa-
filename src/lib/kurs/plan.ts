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
  DRIFT_BEGREP, LOFTESTENGER, loftestang, type Klasse, type Loftestang, type LoftestangId,
} from './loftestenger'
import { erBra, erIlle, retning, type Kurs } from './retning'
import {
  gate, kastdom, kasttall, MANGLER,
  type Gate, type Kastdom, type Kastsats, type Kastmaaned,
} from './kastvurdering'

export type Svinnserie = {
  /** Maanedene retningen kan regnes paa. Tom naar serien er blokkert. */
  rader: Maanedstall[]
  blokkert: boolean
  /** `null` naar serien er brukbar. Ellers hvorfor den ikke er det. */
  aarsak: string | null
}

/**
 * Serien `matkast` og `usynlig_rest` kan maales paa.
 *
 * =====================================================================
 * Å FJERNE EN MANGLENDE MÅNED ER IKKE DET SAMME SOM Å HÅNDTERE DEN
 * =====================================================================
 *
 * Foerste utgave filtrerte bort ALLE maaneder uten svinngrunnlag. Det
 * er riktig for desember 2025, som ligger FORAN vinduet - men galt for
 * et hull MIDT i det.
 *
 * Mangler mars, blir januar, februar og april tre jevnt fordelte
 * punkter i regresjonen. Avstanden mellom februar og april er dobbelt
 * saa lang som mellom januar og februar, og stigningstallet lyver. Et
 * komprimert hull er en oppdiktet maaling.
 *
 * REGELEN: maanedene UTEN grunnlag maa utgjoere en sammenhengende
 * PREFIKS. Alt annet blokkerer retningen.
 *
 *   [des, jan, feb, mar]   des mangler   ->  OK, serien er jan-mar
 *   [jan, feb, mar, apr]   mar mangler   ->  BLOKKERT, hull
 *   [jan, feb, mar, apr]   apr mangler   ->  BLOKKERT, siste maaned
 *
 * Den siste er egen fordi den ikke er et hull: serien er sammenhengende,
 * men den slutter for tidlig. Da er «naa» en eldre maaned presentert som
 * denne, og det er verre enn ingen konklusjon.
 *
 * MAALT 2026-09-13, kontroll 4: alle 35 stasjonsmaanedene januar-juli
 * har 55-61 svinnrader. INGEN interne hull finnes i dagens data, saa
 * blokkeringen er bevist inert - den staar for at fellen ikke skal slaa
 * til naar en fil en gang mangler.
 *
 * NIVAAET er ikke blokkert av dette. En blokkert retning betyr at
 * loeftestangen ikke faar en konklusjon her; P2s confidence gate
 * erstatter dette med en aarsak flaten kan vise.
 */
export function svinnserie(h: readonly Maanedstall[]): Svinnserie {
  const foerste = h.findIndex((m) => m.harSvinndata)
  if (foerste === -1) {
    return { rader: [], blokkert: true, aarsak: 'Ingen måned har svinngrunnlag.' }
  }
  const resten = h.slice(foerste)
  const manglende = resten.filter((m) => !m.harSvinndata)
  if (manglende.length > 0) {
    const sisteMangler = !resten[resten.length - 1].harSvinndata
    return {
      rader: [],
      blokkert: true,
      aarsak: sisteMangler
        ? `Siste måned mangler svinngrunnlag (${resten[resten.length - 1].maaned}).`
        : `Hull i serien: ${manglende.map((m) => m.maaned).join(', ')} mangler svinngrunnlag.`,
    }
  }
  return { rader: resten, blokkert: false, aarsak: null }
}

/** Maanedene som har svinngrunnlag, uten aa vurdere hull. */
export function medSvinngrunnlag(h: readonly Maanedstall[]): Maanedstall[] {
  return h.filter((m) => m.harSvinndata)
}

export type Maanedstall = {
  /** ISO, første i måneden. */
  maaned: string
  omsetningKr: number
  omsetningBudsjettKr: number
  /** Bruttofortjeneste. Brukes til å verdsette omsetningsvekst. */
  bruttoKr: number
  matsalgKr: number
  /**
   * Synlig matkast. `null` naar stasjonsmaaneden ikke har svinnrader.
   *
   * `0213` sluttet aa `coalesce`-e dette til 0: fem desembermaaneder
   * 2025 hadde ekte matomsetning og INGEN svinnrader, og nullen gjorde
   * dem til perfekte maaneder. 0 betyr fra naa av null kroner.
   */
  matkastKr: number | null
  /** Manko utenom mat og vask. Positivt tall er mangel. `null` = ukjent. */
  usynligRestKr: number | null
  /** Usynlig svinn paa MATgruppen: teoretisk BF - faktisk BF - synlig kast. */
  usynligMatKr: number | null
  /** Antall svinnrader med `avviksstatus = 'avvik'`. Port 4. */
  avvikAntall: number | null
  /** Antall rader som traff `kode like '12%'`. Port 6. */
  matRader: number | null
  /** Har maaneden svinngrunnlag i det hele tatt? */
  harSvinndata: boolean
  /** `gruppe` eller `eldre_grunnlag`. `null` naar grunnlaget mangler. */
  datastatus: string | null
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
  /** Stasjonens id. Satsen maa bevises aa hoere til nettopp den. */
  stasjonId: string
  /** Eldste først. Trenger minst tre for at retning skal bety noe. */
  historikk: readonly Maanedstall[]
  leverandorer: readonly Leverandorrad[]
  /**
   * Budsjettert kastprosent for stasjonen, fra `kastbudsjett`.
   *
   * `null` naar delingsfila for aaret ikke er lastet opp. Da blokkerer
   * confidence gate matkastanalysen med aarsak - den regner ikke mot
   * 0 %, som ville gjort hver stasjon katastrofal.
   */
  kastsats: Kastsats | null
  /**
   * Port 7: teksten fra `forbehold.ts` for `mat_svinn_stasjon`, eller
   * `null` naar ingen gjelder. PAAKREVD - en glemt forbeholdssjekk
   * skal ikke bli en aapen port.
   */
  forbehold: string | null
  /**
   * Port 9: butikknummeret stasjonen er kjent under. `null` naar
   * stasjonen ikke har et, og da kan ikke satsen bevises aa hoere til
   * den. Portene 4 og 6 leses av maanedsraden.
   */
  butikknummer: string | null
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
  /**
   * Synlig matkast mot omsetningsjustert budsjett.
   *
   * `dom` er `null` naar confidence gate blokkerte - da baerer
   * `blokkering` aarsaken, og flaten viser den i stedet for et tall.
   * Aldri 0 som stand-in.
   */
  matkast: { dom: Kastdom | null; blokkering: string | null }
  /**
   * Usynlig svinn, HELT SEPARAT fra synlig kast.
   *
   * De maales ulikt og betyr ulike ting: synlig kast er registrert i
   * haandterminalen, usynlig er `teoretisk BF - faktisk BF - synlig
   * kast`. Fortegnet beholdes - pluss er manko, minus er overskudd, og
   * et overskudd er ikke automatisk en gevinst.
   *
   * `null` naar maaneden mangler svinngrunnlag.
   */
  usynlig: Usynligvurdering
  /**
   * Kunne hovedtiltaket velges?
   *
   * `mulig: false` betyr at det fantes flere kandidater, men ingen
   * kroneverdi aa sammenligne dem med - da er INGEN valgt, og flaten
   * skal si hvorfor i stedet for aa vise en vilkaarlig vinner.
   */
  rangering: { mulig: boolean; kandidater: string[] }
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
    // MATKAST MAALES IKKE HER, OG SKAL IKKE KUNNE GJOERE DET.
    //
    // En kommentar som sier «matkast gaar ikke gjennom kroneloypa» er
    // sann helt til noen fjerner `continue`-en i loekka. Da ville
    // kastKRONER stille bestemt tiltaket igjen - nettopp feilen som ga
    // en stasjon 1,0 prosentpoeng over budsjett en BEKREFTELSE.
    //
    // Derfor kaster den. `vurderMatkast` er den eneste veien.
    case 'matkast':
      throw new Error(
        'matkast maales mot kastbudsjettet, ikke i kroner. '
        + 'Bruk vurderMatkast() - se byggMaanedsplan.',
      )
    // `usynlig_rest` maales paa svinnarket og trenger serievakten. En
    // blokkert serie gir `[]`, `retning([])` gir `null`, og da hopper
    // `byggMaanedsplan` over loeftestangen. Ingen konklusjon er riktig
    // svar naar grunnlaget har hull.
    case 'usynlig_rest': return svinnserie(h).rader.map((m) => m.usynligRestKr ?? 0)
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

/**
 * Matkastdommen for siste maaned, med confidence gate foran.
 *
 * Gaten kjoeres paa SISTE maaned, fordi det er den som konkluderes paa.
 * Serien bak den er allerede vaktet av `svinnserie()` - port 8.
 */
const som = (m: Maanedstall): Kastmaaned => ({
  maaned: m.maaned, matsalgKr: m.matsalgKr, matkastKr: m.matkastKr,
  harSvinndata: m.harSvinndata, datastatus: m.datastatus,
})

/**
 * Hva portene faktisk beviser - og hva de ikke gjoer.
 *
 * PORT 6, `mat_rader > 0`: beviser at MATGRUPPEN BLE FUNNET i denne
 * stasjonsmaaneden. Den beviser IKKE at den historiske kodemappingen er
 * verifisert. Skifter St1 fra `12xxx` til noe annet, slaar porten inn
 * med én gang; endrer de betydningen av `12010` uten aa endre nummeret,
 * ser porten ingenting. Det er en annen sak, og den er ikke lukket.
 *
 * PORT 9, `stasjonId` og `aar`: beviser at satsraden vi leste hoerer til
 * den stasjonen vi regner for. Den beviser IKKE at NAVNEKOBLINGEN under
 * delingsfil-importen var riktig. Delingsfila har ikke butikknummer -
 * `lagreKastbudsjett` slaar opp paa navn - og en feilkobling DER ville
 * gitt en konsistent, men gal, `stasjon_id` som denne porten godtar.
 * Kontroll 3 mot produksjon er beviset for den; porten er beviset for at
 * ingenting har flyttet seg etterpaa.
 */
function portene(
  d: Maanedsdata, m: Maanedstall, serieblokkering: string | null,
): Gate {
  return gate({
    maaned: som(m),
    sats: d.kastsats,
    //   4 avstemming  <- avvik_antall  (0214)
    //   6 kodemapping <- mat_rader     (0214)
    //   7 forbehold   <- forbehold.ts, mat_svinn_stasjon
    //   9 identitet   <- butikknummer + satsens stasjon_id og aar
    //
    // `null` betyr «ikke maalt», og det LUKKER porten.
    avstemt: m.avvikAntall === 0,
    kodemappingSikker: (m.matRader ?? 0) > 0,
    forbehold: d.forbehold,
    serieblokkering,
    stasjonBevist: d.kastsats !== null
      && d.butikknummer !== null
      && d.kastsats.stasjonId === d.stasjonId
      && d.kastsats.aar === Number(m.maaned.slice(0, 4)),
  })
}

function vurderMatkast(d: Maanedsdata): { dom: Kastdom | null; blokkering: string | null } {
  const serie = svinnserie(d.historikk)
  const siste = d.historikk[d.historikk.length - 1]
  if (!siste) return { dom: null, blokkering: MANGLER }

  // =====================================================================
  // HVER MAANED I SERIEN GAAR GJENNOM PORTENE, IKKE BARE DEN SISTE
  // =====================================================================
  //
  // Foerste utgave portet bare `siste`. Men `kastdom` regner trend over
  // HELE serien og teller «over budsjett X av 7» over hele serien - saa
  // en maaned midt i med `avvik_antall > 0`, `mat_rader = 0` eller
  // `datastatus = 'eldre_grunnlag'` slapp gjennom uten aa bli sett, og
  // var likevel med i baade retningen og tellingen.
  //
  // Serien er den samme som dommen regner paa. Foerste maaned som feiler
  // blokkerer alt, og aarsaken navngir maaneden.
  for (const m of serie.rader) {
    const g = portene(d, m, serie.aarsak)
    if (!g.kanKonkludere) {
      const naar = m === siste ? '' : ` (${m.maaned})`
      return { dom: null, blokkering: `${MANGLER}.${naar} ${g.aarsak}` }
    }
  }
  if (serie.rader.length === 0) {
    return { dom: null, blokkering: `${MANGLER}. ${serie.aarsak ?? 'Ingen måned å måle.'}` }
  }

  const tall = serie.rader.map((m) => kasttall(som(m), d.kastsats as Kastsats))
  return { dom: kastdom(tall), blokkering: null }
}

/**
 * Usynlig svinn, for seg selv.
 *
 * Ingen budsjettsats, ingen prosent mot matomsetning, ingen
 * sammenslaaing med synlig kast. Bare nivaaet og retningen, med
 * fortegnet i behold.
 */
function vurderUsynlig(d: Maanedsdata): Usynligvurdering {
  const tom: Usynligvurdering =
    { naaKr: null, kurs: null, blokkering: MANGLER, usikker: false, aarsakUsikker: null, vindu: 0 }
  const serie = svinnserie(d.historikk)
  if (serie.blokkert) return { ...tom, blokkering: `${MANGLER}. ${serie.aarsak}` }

  // `usynligMatKr`, IKKE `usynligRestKr`. Rest er alt utenom mat, vask
  // og pant - en annen stoerrelse, og aa presentere den som usynlig
  // matsvinn ville vaert feil tall under riktig navn.
  //
  // MATGRUPPEN MAA VAERE FUNNET I HVER MAANED. `0215` gjoer
  // `usynlig_mat_kr` til NULL naar `mat_rader = 0`, men en eldre base
  // eller en fremtidig endring kan gi 0. Vi spoer derfor `matRader`
  // direkte: en 0 uten matrader er «ikke funnet», ikke «ingen manko».
  const utenMatgruppe = serie.rader.filter((m) => (m.matRader ?? 0) === 0)
  if (utenMatgruppe.length > 0) {
    return {
      ...tom,
      blokkering: `${MANGLER}. Matgruppen ble ikke funnet i `
        + `${utenMatgruppe.map((m) => m.maaned).join(', ')}.`,
    }
  }
  const verdier = serie.rader.map((m) => m.usynligMatKr).filter((v): v is number => v !== null)
  if (verdier.length !== serie.rader.length || verdier.length === 0) return tom

  const naaKr = verdier[verdier.length - 1]
  const v = usynligretning(verdier)

  return {
    naaKr,
    kurs: v.kurs,
    blokkering: null,
    usikker: v.usikker,
    aarsakUsikker: v.aarsak,
    vindu: v.vindu,
  }
}

/** Hvor mange maaneder retningsvinduet er. Foerste versjon: tre. */
export const USYNLIG_VINDU = 3

/**
 * Kan uforklart matavvik faa en retning, og i saa fall hvilken?
 *
 * =====================================================================
 * TRE SAMMENHENGENDE MAANEDER, IKKE TO POSITIVE HVOR SOM HELST
 * =====================================================================
 *
 * Foerste regel var `naaKr < 0 || positive <= 1`. Den godkjente en
 * retning saa snart serien hadde to positive maaneder - uansett hvor.
 *
 * Maalt paa Dale januar-juli 2026:
 *
 *     jan +19 034   feb -6 333   mar -2 062   apr -9 992
 *     mai  -2 958   jun -5 643   jul +31 902
 *
 * To positive (januar og juli) med fem negative imellom passerte, og
 * juli fikk en trend. Snittet de seks foregaaende maanedene var -1 326;
 * juli er +31 902. Det er ikke en utvikling, det er et sprang.
 *
 * ---------------------------------------------------------------------
 * REGELEN
 *
 *   1  De tre siste validerte maanedene maa ha SAMME FORTEGN.
 *   2  Siste maaned maa ikke vaere en ekstrem enkeltmaaling:
 *      |siste| <= 3 x median(|tidligere validerte maaneder|).
 *   3  RETNINGEN REGNES PAA VINDUET, ikke paa hele serien. Brukes tre
 *      maaneder som bevis for at retningen finnes, maa retningen ogsaa
 *      maales paa de tre - ellers beviser vinduet noe annet enn det som
 *      vises.
 *
 * Punkt 2 maaler mot ALLE tidligere validerte maaneder, ikke bare de to
 * andre i vinduet: to tall gir en skjoer median. Maalt paa Kelsars fem
 * stasjoner gir begge lesningene samme utfall - `usynlig.test.ts`
 * holder begge.
 *
 * ---------------------------------------------------------------------
 * «OPP» I ET POSITIVT UFORKLART AVVIK BETYR VERRE. «Ned» betyr bedre,
 * men ikke noedvendigvis loest: Laguneparken faller tre maaneder paa
 * rad og ligger fortsatt +1 405.
 */
export function usynligretning(verdier: readonly number[]): {
  kurs: Kurs | null
  usikker: boolean
  aarsak: string | null
  /** Maanedene retningen faktisk er regnet paa. Tom naar den mangler. */
  vindu: number
} {
  if (verdier.length < USYNLIG_VINDU) {
    return {
      kurs: null, usikker: true, vindu: 0,
      aarsak: `Færre enn ${USYNLIG_VINDU} måneder med grunnlag. `
        + 'For kort til å si en retning.',
    }
  }

  const vindu = verdier.slice(-USYNLIG_VINDU)
  const siste = vindu[vindu.length - 1]
  const tidligere = verdier.slice(0, -1)

  // 1 SAMME FORTEGN. Null teller med begge veier - en maaned paa null
  //   bryter ikke en serie, men snur den heller ikke.
  const alleOver = vindu.every((x) => x >= 0)
  const alleUnder = vindu.every((x) => x <= 0)
  if (!alleOver && !alleUnder) {
    return {
      kurs: null, usikker: true, vindu: 0,
      aarsak: `Fortegnet skifter i de siste ${USYNLIG_VINDU} månedene. `
        + 'Usikker enkeltmåling — kontroller telling, periodisering og '
        + 'fakturaflyt før tiltak.',
    }
  }

  // 2 INGEN EKSTREM ENKELTMAALING.
  const median = (a: readonly number[]): number => {
    const s = [...a].sort((x, y) => x - y)
    const m = Math.floor(s.length / 2)
    return s.length % 2 === 0 ? (s[m - 1] + s[m]) / 2 : s[m]
  }
  const med = tidligere.length > 0 ? median(tidligere.map(Math.abs)) : 0
  if (med > 0 && Math.abs(siste) > 3 * med) {
    return {
      kurs: null, usikker: true, vindu: 0,
      aarsak: 'Siste måned er mer enn tre ganger medianen av de foregående. '
        + 'Usikker enkeltmåling — kontroller telling, periodisering og '
        + 'fakturaflyt før tiltak.',
    }
  }

  // 3 RETNINGEN PAA VINDUET.
  return { kurs: retning(vindu), usikker: false, aarsak: null, vindu: USYNLIG_VINDU }
}

export type Usynligvurdering = {
  naaKr: number | null
  kurs: Kurs | null
  blokkering: string | null
  /** Fortegnsskifte eller ekstrem enkeltmaaling i vinduet. */
  usikker: boolean
  aarsakUsikker: string | null
  /**
   * Antall maaneder retningen er regnet paa. `0` naar den mangler.
   *
   * Flaten MAA si perioden: «har oekt de siste tre maanedene», ikke
   * bare «stigende». Ellers presenteres en tremaanedersbevegelse som en
   * stabil trend for hele aaret.
   */
  vindu: number
}

/** Kroneverdien matkasttiltak rangeres paa: avviket mot budsjettet. */
function matkastverdi(v: Kastdom | null, satser: Satser | null): number {
  if (!v || v.slag !== 'tiltak' || !satser) return 0
  // Marginforbedring: en svinngevinst beholdes i sin helhet.
  return verdiAvGevinst({ type: 'margin', kroner: Math.abs(v.naa.avvikKr) }, satser) * 12
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
    // MATKAST GAAR IKKE GJENNOM KRONELOYPA I DET HELE TATT.
    //
    // Den gamle veien var `serieFor -> erIlle/erBra -> kronerIAret`, og
    // den maaler kastKRONER. En stasjon over budsjett med fallende
    // kroner havnet i `bra` og kunne bli presentert som en BEKREFTELSE
    // mens den laa 1 prosentpoeng over kastbudsjettet hver maaned.
    //
    // Maalt paa et moteksempel 2026-09-13: «Riktig vei 4 maaneder paa
    // rad. Naa paa 28 000 kroner.» Nivaaet avgjoer, og nivaaet er
    // `matkast.dom`.
    if (l.id === 'matkast') continue
    const serie = serieFor(l.id, d.historikk)
    const kurs = retning(serie)
    if (!kurs) continue
    vurdert.push({ l, serie, kurs, naa: serie[serie.length - 1] })
  }

  // =====================================================================
  // MATKAST: NIVAAET AVGJOER, IKKE RETNINGEN
  // =====================================================================
  //
  // `serieFor('matkast')` brukes IKKE lenger - verken til dommen eller
  // til rangeringen. Loekka over hopper over matkast, dommen kommer av
  // avviket mot budsjettet, og `matkastverdi()` rangerer paa det samme
  // avviket. Kastkronene naar ikke inn i denne beslutningen noe sted.
  //
  // Maalt paa Kelsar jan-jul: paa tre av fem stasjoner gir de to
  // maalestokkene motsatt svar. Lone stiger 7 252 kroner og ligger under
  // budsjett fem av sju maaneder.
  const matkast = vurderMatkast(d)

  // =====================================================================
  // EN MANGLENDE KRONEVERDI ER IKKE NULL KRONER
  // =====================================================================
  //
  // `?? 0` sto her. Uten royaltysatser ga `kronerIAret` `null` paa HVERT
  // punkt, alle ble 0, og `sort` lot da REKKEFOELGEN I `LOFTESTENGER`
  // avgjoere hvem som var «stoerst». I motvind beholdes bare det
  // stoerste, saa flaten fikk ett vilkaarlig valgt tiltak - og fordi
  // lista da hadde lengde 1, ble advarselen om manglende rangering
  // heller ikke vist.
  //
  // Aa merke en liste som urangert ETTER at motoren har kastet de andre
  // kandidatene, er ingen aerlighet.
  const verdi = (v: Verdi): number | null => kronerIAret(v, siste, d.satser)
  const sorter = (a: Verdi[]) =>
    [...a].sort((x, y) => (verdi(y) ?? 0) - (verdi(x) ?? 0))

  const illeRaa = vurdert.filter((v) => erIlle(v.kurs, v.l.god))
  const bra = sorter(vurdert.filter((v) => erBra(v.kurs, v.l.god)))

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

  // MATKASTPUNKTET, bygget av dommen og ikke av kroneserien.
  //
  // Teksten er `matkast.dom.tekst` ordrett. Den generiske «Gaatt feil
  // vei ... naa paa X kroner» maaler kastkroner, og det er nettopp den
  // setningen som fortalte en stasjon over budsjett at den gjorde det
  // bra.
  const matkastpunkt: Planpunkt | null = matkast.dom
    ? {
        slag: matkast.dom.slag === 'tiltak' ? 'tiltak' : 'bekreftelse',
        loftestang: 'matkast',
        tittel: loftestang('matkast').navn,
        tekst: matkast.dom.tekst,
        kronerIAret: d.satser
          ? verdiAvGevinst(
              { type: 'margin', kroner: Math.abs(matkast.dom.naa.avvikKr) }, d.satser) * 12
          : null,
      }
    : null

  const matkasttiltak = matkast.dom?.slag === 'tiltak' ? matkastpunkt : null
  const matkastbekreftelse = matkast.dom?.slag === 'bekreftelse' ? matkastpunkt : null

  // ALLE kandidatene, ikke bare den foerste. Matkast maales i avviket mot
  // kastbudsjettet, de andre i kroner i aaret - men begge gaar gjennom
  // `verdiAvGevinst`, saa de er sammenlignbare NAAR satsene finnes.
  const kandidater: { navn: string; verdi: number | null; punkt: Planpunkt }[] = [
    ...(matkasttiltak
      ? [{
          navn: loftestang('matkast').navn,
          verdi: d.satser ? matkastverdi(matkast.dom, d.satser) : null,
          punkt: matkasttiltak,
        }]
      : []),
    ...illeRaa.map((v) => ({ navn: v.l.navn, verdi: verdi(v), punkt: tiltak(v) })),
  ]

  // KAN DE SAMMENLIGNES? Bare naar HVER kandidat har en kroneverdi.
  const kanRangeres = kandidater.every((k) => k.verdi !== null)
  const maaVelges = kandidater.length > 1


  // RANGERING PAA AVVIK MOT BUDSJETT, ikke paa kronetrend.
  //
  // Kan kandidatene IKKE sammenlignes, og det er flere enn én, velges
  // ingen. Da ville valget vaert rekkefoelgen i `LOFTESTENGER`, og en
  // vilkaarlig rekkefoelge skal ikke presenteres som «stoerst».
  const stoersteTiltak = (): Planpunkt | null => {
    if (kandidater.length === 0) return null
    if (kandidater.length === 1) return kandidater[0].punkt
    if (!kanRangeres) return null
    return [...kandidater].sort((a, b) => (b.verdi as number) - (a.verdi as number))[0].punkt
  }

  if (dom === 'medvind') {
    // Bekreftelsen: matkast under budsjett teller, og den er maalt mot
    // et budsjett i stedet for mot forrige maaned.
    if (matkastbekreftelse) punkter.push(matkastbekreftelse)
    else if (bra[0]) punkter.push(bekreftelse(bra[0]))
    // NESTE løftestang, ikke «fortsett sånn».
    const neste = stoersteTiltak()
    if (neste) punkter.push(neste)
  } else if (dom === 'motvind') {
    // ÉN ting. Den største.
    const neste = stoersteTiltak()
    if (neste) punkter.push(neste)
  } else {
    // Flat: ingen retning å melde. Da er den største som går feil vei
    // fortsatt verdt å nevne, men ingen bekreftelse — flatt er ikke ros.
    const neste = stoersteTiltak()
    if (neste) punkter.push(neste)
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
    matkast,
    usynlig: vurderUsynlig(d),
    rangering: {
      mulig: kanRangeres || !maaVelges,
      kandidater: kandidater.map((k) => k.navn),
    },
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
