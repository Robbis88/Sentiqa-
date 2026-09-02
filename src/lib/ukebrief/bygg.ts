// =====================================================================
// Ukebriefen — byggingen.
//
// Ren funksjon: `Ukedata` inn, `Ukebrief` ut. Ingen database, ingen
// klokke, ingen tilfeldighet. Samme uke gir samme brev hver gang, og det
// er hele poenget — et brev som endrer seg mellom to kjøringer kan ikke
// etterprøves av den som fikk det forrige mandag.
//
// Rangeringen er `signaler.ts` sin. Kategorisignalene er `avdelingsSignaler`
// sine, uendret. Det som er nytt her er grunnlaget, retningen og
// handlingene — og de tre reglene som holder brevet ærlig:
//
//   1. Et signal uten data foreslår ingenting. Det havner under «hva vi
//      ikke vet», ikke blant funnene.
//   2. Ingen handling uten et signal. Hver anbefaling bærer `id`-en til
//      tallet den kommer fra.
//   3. Aldri mer enn fem. Et brev med tolv gjøremål blir ingen gjøremål.
// =====================================================================

import { rangerSignaler, avdelingsSignaler, pulsOverskrift, type RaaSignal } from '@/lib/signaler'
import type { Briefsignal, Handling, Rangert, Ukebrief, Ukedata } from './type'

/** Fem er ikke et designvalg, det er et lesevalg. Over dette slutter en
    liste å være en prioritering og blir en oversikt. */
export const MAKS_HANDLINGER = 5
/** Per bolk i brevet. Resten finnes fortsatt inne i Sentiqa. */
export const MAKS_PER_BOLK = 4

/** Under dette er utviklingen støy, ikke nyhet. */
const SALG_MIN_PST = 3
/** Avvik mot BP under dette er innenfor det en uke svinger uansett. */
const BP_MIN_KR = 15000
/** En kategori må vokse minst så mye i kroner for å regnes som god nyhet. */
const VEKST_MIN_KR = 5000
/** … og minst så mange prosentpoeng bedre enn butikken. */
const VEKST_MIN_PP = 25
/** Timeforbruk over rammen varsles først her — rammen er selv avledet. */
const TIMER_MIN_AVVIK = 5

const kr = (n: number) => `${Math.abs(Math.round(n)).toLocaleString('nb-NO')} kr`
const pst = (n: number) => `${Math.abs(n).toFixed(0)} %`

// --- ISO-ukenummer ---------------------------------------------------
// Torsdagsregelen: uke 1 er uken som inneholder årets første torsdag.
// Regnes på UTC-middag, som resten av datoaritmetikken i prosjektet.
export function ukenummer(isoMandag: string): number {
  const d = new Date(`${isoMandag}T12:00:00Z`)
  const torsdag = new Date(d)
  torsdag.setUTCDate(d.getUTCDate() + 3)
  const nyttar = new Date(Date.UTC(torsdag.getUTCFullYear(), 0, 1, 12))
  return Math.round((torsdag.getTime() - nyttar.getTime()) / 86400000 / 7) + 1
}

/**
 * Uken briefen skal handle om: den siste som er HELT FERDIG.
 *
 * Første utgave tok «nest nyeste uke med data», som er riktig bare når
 * den nyeste er halv. Stopper importen på en søndag, er den nyeste uken
 * allerede komplett — og da hoppet forvalget en uke for langt tilbake og
 * viste uke 34 når uke 35 var ferdig og full av tall.
 *
 * Regelen er kalenderen, ikke posisjonen i lista: ta den nyeste uken hvis
 * søndag har passert. `mandager` er nyeste først.
 */
export function sisteHeleUke(mandager: string[], idag: string): string | null {
  for (const m of mandager) {
    const sondag = new Date(`${m}T12:00:00Z`)
    sondag.setUTCDate(sondag.getUTCDate() + 6)
    if (sondag.toISOString().slice(0, 10) < idag) return m
  }
  // Bare halve uker å velge mellom — da er den nyeste det ærligste vi har,
  // og `hull` forteller leseren at dagene mangler.
  return mandager[0] ?? null
}

// --- Signalkildene ---------------------------------------------------

function salgssignaler(d: Ukedata): Briefsignal[] {
  const ut: Briefsignal[] = []
  const diff = d.omsetning - d.omsetningIfjor
  const vekst = d.omsetningIfjor > 0 ? (diff / d.omsetningIfjor) * 100 : 0

  if (d.omsetningIfjor > 0 && Math.abs(vekst) >= SALG_MIN_PST) {
    const opp = diff > 0
    ut.push({
      id: 'salg-ifjor',
      merke: 'Salg',
      tittel: opp ? 'Omsetningen er over fjoråret' : 'Omsetningen er under fjoråret',
      endring: `${opp ? '↑' : '↓'} ${pst(vekst)}`,
      detalj: `${kr(d.omsetning)} mot ${kr(d.omsetningIfjor)} samme uke i fjor — ${kr(diff)} ${opp ? 'mer' : 'mindre'}.`,
      niva: opp ? 'info' : vekst <= -10 ? 'kritisk' : 'folg',
      lenke: '/salg',
      konsekvensKr: diff,
      grunnlag: 'fakta',
      retning: opp ? 'bra' : 'darlig',
    })
  }

  // BP nevnes bare når den finnes. En stasjon uten budsjett for perioden
  // skal ikke få «0 kr i budsjett» presentert som et krav den bommet på.
  if (d.bpUke !== null && d.bpUke > 0) {
    const bpDiff = d.omsetning - d.bpUke
    if (Math.abs(bpDiff) >= BP_MIN_KR) {
      const over = bpDiff > 0
      ut.push({
        id: 'salg-bp',
        merke: 'Budsjett',
        tittel: over ? 'Over budsjett for uken' : 'Under budsjett for uken',
        endring: `${over ? '+' : '−'} ${kr(bpDiff)}`,
        detalj:
          `${kr(d.omsetning)} mot ukens andel av månedsbudsjettet på ${kr(d.bpUke)}. ` +
          'Ukesandelen er fordelt fra måneden etter ukedagsmønsteret i fjor, ikke lest av et ukesbudsjett.',
        niva: over ? 'info' : 'folg',
        lenke: '/businessplan',
        konsekvensKr: bpDiff,
        // Fordelt, ikke avlest — derfor indikasjon. Det står også i detaljen,
        // så leseren kan vurdere forbeholdet selv.
        grunnlag: 'indikasjon',
        retning: over ? 'bra' : 'darlig',
        handling: over ? undefined : 'Se hvilke dager som drar ned, og om de har en bemanning som forklarer det.',
      })
    }
  }
  return ut
}

function kategorisignaler(d: Ukedata): Briefsignal[] {
  const butikkPst = d.omsetningIfjor > 0
    ? ((d.omsetning - d.omsetningIfjor) / d.omsetningIfjor) * 100
    : 0

  // Nedsiden er allerede løst, og løst riktig: den måler mot butikken,
  // ikke mot null. Vi arver den i stedet for å skrive en variant.
  const ned: Briefsignal[] = avdelingsSignaler({
    avdelinger: d.avdelinger,
    omsetning: d.omsetning,
    omsetningIfjor: d.omsetningIfjor,
  }).map((s: RaaSignal): Briefsignal => ({
    ...s,
    grunnlag: 'fakta',
    retning: 'darlig',
    handling: `Sjekk om ${s.tittel.toLowerCase()} har hatt hull i hylla eller endret plassering.`,
  }))

  // Oppsiden finnes ikke i motoren — den leter etter avvik, og vekst er
  // ikke et avvik. Men et brev som bare er dårlig nytt blir ikke lest to
  // ganger.
  const opp: Briefsignal[] = []
  for (const a of d.avdelinger) {
    if (a.ifjor <= 0) continue
    const kroner = a.omsetning - a.ifjor
    if (kroner < VEKST_MIN_KR) continue
    if (a.vekstPst - butikkPst < VEKST_MIN_PP) continue
    opp.push({
      id: `avd-opp-${a.kode}`,
      merke: 'Salg',
      tittel: a.navn,
      endring: `↑ ${pst(a.vekstPst)}`,
      detalj:
        `${kr(kroner)} mer enn i fjor. Butikken samlet ${butikkPst >= 0 ? 'steg' : 'falt'} ` +
        `${pst(butikkPst)} — denne kategorien drar oppover av seg selv.`,
      niva: 'info',
      lenke: '/salg',
      konsekvensKr: kroner,
      grunnlag: 'fakta',
      retning: 'bra',
    })
  }
  return [...ned, ...opp]
}

function utsolgtsignal(d: Ukedata): Briefsignal[] {
  if (d.utsolgt.length === 0) return []
  const tapt = d.utsolgt.reduce((a, u) => a + u.taptKr, 0)
  const verst = [...d.utsolgt].sort((a, b) => b.taptKr - a.taptKr)[0]
  const dager = Math.max(...d.utsolgt.map((u) => u.dager))
  return [{
    id: 'utsolgt',
    merke: 'Varer',
    tittel: d.utsolgt.length === 1 ? `${verst.navn} kan ha gått tom` : `${d.utsolgt.length} varer kan ha gått tom`,
    endring: `≈ ${kr(tapt)} tapt`,
    detalj:
      `${verst.navn} solgte jevnt og har så null salg ${verst.dager} dager på rad. ` +
      'Det passer med tomt i hylla, men det passer også med avregistrering eller feil varenummer — ' +
      'tallet er et anslag, ikke en måling.',
    niva: tapt >= 10000 ? 'kritisk' : 'folg',
    lenke: '/utsolgt',
    konsekvensKr: tapt,
    dager,
    // «Kan ha gått tom.» Systemet har ikke sett hylla.
    grunnlag: 'hypotese',
    retning: 'darlig',
    handling: `Sjekk om ${verst.navn} står i hylla nå, og hvorfor den ikke ble bestilt.`,
  }]
}

function treffsignal(d: Ukedata): Briefsignal[] {
  if (d.treff === null) {
    return [{
      id: 'treff-mangler',
      merke: 'Produksjon',
      tittel: 'Produksjonstreff er ikke vurdert',
      detalj: 'Det finnes ingen treffmålinger for uken. Det betyr ikke at treffet var godt.',
      niva: 'info',
      lenke: '/produksjonsplan/treffsikkerhet',
      grunnlag: 'mangler_data',
      retning: 'darlig',
    }]
  }
  const god = d.treff.snittTreffPst >= 80
  return [{
    id: 'treff',
    merke: 'Produksjon',
    tittel: god ? 'Produksjonen treffer godt' : 'Produksjonen bommer på planen',
    endring: `${d.treff.snittTreffPst.toFixed(0)} %`,
    detalj: `${d.treff.antall} målinger i uken, snitt ${d.treff.snittTreffPst.toFixed(0)} % treff mot plan.`,
    niva: god ? 'info' : 'folg',
    lenke: '/produksjonsplan/treffsikkerhet',
    grunnlag: 'fakta',
    retning: god ? 'bra' : 'darlig',
    handling: god ? undefined : 'Se hvilke kategorier som bommer mest, og om startprosenten bør justeres.',
  }]
}

function timesignal(d: Ukedata): Briefsignal[] {
  if (d.timer.ukesramme === null) {
    return [{
      id: 'timer-mangler',
      merke: 'Bemanning',
      tittel: 'Timeforbruk er ikke målt mot ramme',
      detalj: 'Det finnes ingen bemanningsramme for måneden, så ukens andel kan ikke regnes ut.',
      niva: 'info',
      lenke: '/bemanning',
      grunnlag: 'mangler_data',
      retning: 'darlig',
    }]
  }
  const avvik = d.timer.brukt - d.timer.ukesramme
  if (Math.abs(avvik) < TIMER_MIN_AVVIK) return []
  const over = avvik > 0
  return [{
    id: 'timer',
    merke: 'Bemanning',
    tittel: over ? 'Over timerammen for uken' : 'Under timerammen for uken',
    endring: `${over ? '+' : '−'} ${Math.abs(avvik).toFixed(0)} t`,
    detalj:
      `${d.timer.brukt.toFixed(0)} timer stemplet mot ukens andel av månedsrammen på ` +
      `${d.timer.ukesramme.toFixed(0)}. Ukesandelen er fordelt fra måneden — det finnes ingen ukesramme å lese av.`,
    niva: 'folg',
    lenke: '/bemanning',
    // Timene er ekte, sammenligningen er avledet. Derfor indikasjon.
    grunnlag: 'indikasjon',
    retning: over ? 'darlig' : 'bra',
    handling: over ? 'Se hvilke dager som har flest timer, og om de følger kundetrykket.' : undefined,
  }]
}

function tilbakemeldingssignal(d: Ukedata): Briefsignal[] {
  const t = d.tilbakemeldinger
  if (t.antall === 0) return []
  // ANTALL og ULEST — aldri teksten. Meldingene kan gjelde uhell eller
  // krenkelse, og de skal leses inne i Sentiqa med tilgangskontroll, ikke
  // ligge i en innboks som kan videresendes.
  return [{
    id: 'tilbakemelding',
    merke: 'Ansatte',
    tittel: t.antall === 1 ? 'Én melding fra de ansatte' : `${t.antall} meldinger fra de ansatte`,
    endring: t.ulest > 0 ? `${t.ulest} ulest` : 'alle lest',
    detalj: t.harAlvorlig
      ? 'Minst én er merket som uhell, nesten-uhell eller krenkelse. Innholdet står i Sentiqa.'
      : 'Ingen er merket som uhell eller krenkelse. Innholdet står i Sentiqa.',
    niva: t.harAlvorlig ? 'kritisk' : t.ulest > 0 ? 'folg' : 'info',
    lenke: '/tilbakemeldinger',
    grunnlag: 'fakta',
    retning: t.ulest > 0 || t.harAlvorlig ? 'darlig' : 'bra',
    handling: t.ulest > 0 ? 'Les de uleste meldingene før uken begynner.' : undefined,
  }]
}

// --- Sammenstillingen ------------------------------------------------

/**
 * Plukker handlingene.
 *
 * Regelen som betyr noe: et signal uten datagrunnlag foreslår ingenting.
 * Den håndheves HER, og ikke bare ved at kildene lar være å sette
 * `handling` — ellers ville en ny signalkilde som setter begge deler ha
 * sluppet gjennom uten at noe ropte.
 */
export function velgHandlinger(rangerte: Rangert[]): Handling[] {
  const ut: Handling[] = []
  for (const s of rangerte) {
    if (ut.length >= MAKS_HANDLINGER) break
    if (s.grunnlag === 'mangler_data') continue
    if (!s.handling) continue
    ut.push({ tekst: s.handling, fraSignal: s.id })
  }
  return ut
}

function ranger(signaler: Briefsignal[]): Rangert[] {
  const poeng = new Map(rangerSignaler(signaler).map((s) => [s.id, s.poeng]))
  return signaler
    .map((s) => ({ ...s, poeng: poeng.get(s.id) ?? 0 }))
    .sort((a, b) => b.poeng - a.poeng || a.tittel.localeCompare(b.tittel, 'nb'))
}

/**
 * Ingressen. Skrevet ut fra tallene, ikke av en modell.
 *
 * Samme grunn som `pulsOverskrift`: den skal si det samme hver gang for
 * samme tall, og aldri koste et API-kall. En modell som skriver denne
 * setningen ville også kunne finne på å tolke den.
 */
function ingressFor(d: Ukedata, vekst: number, kjent: Rangert[]): string {
  const retning = d.omsetningIfjor <= 0
    ? `${kr(d.omsetning)} omsatt.`
    : `${kr(d.omsetning)} omsatt, ${pst(vekst)} ${vekst >= 0 ? 'over' : 'under'} samme uke i fjor.`
  const antall = kjent.filter((s) => s.retning === 'darlig').length
  if (antall === 0) return `${retning} Ingenting krever oppmerksomhet denne uken.`
  return `${retning} ${antall} ${antall === 1 ? 'ting' : 'ting'} å se på.`
}

export function byggUkebrief(d: Ukedata): Ukebrief {
  const alle: Briefsignal[] = [
    ...salgssignaler(d),
    ...kategorisignaler(d),
    ...utsolgtsignal(d),
    ...treffsignal(d),
    ...timesignal(d),
    ...tilbakemeldingssignal(d),
  ]

  const rangerte = ranger(alle)
  const kjent = rangerte.filter((s) => s.grunnlag !== 'mangler_data')

  const vekst = d.omsetningIfjor > 0
    ? ((d.omsetning - d.omsetningIfjor) / d.omsetningIfjor) * 100
    : 0

  // Hva vi ikke vet: både det vi vet at vi mangler (`hull`) og signalene
  // som ikke kunne vurderes. Begge deler med navn — «noe mangler» er ikke
  // informasjon, «produksjonstreff mangler» er det.
  const viIkkeVet = [
    ...rangerte.filter((s) => s.grunnlag === 'mangler_data').map((s) => `${s.tittel}. ${s.detalj}`),
    ...d.hull.map((h) =>
      `${h.kilde} mangler ${h.dagerMangler} ${h.dagerMangler === 1 ? 'dag' : 'dager'} denne uken.`),
  ]

  const bra = kjent.filter((s) => s.retning === 'bra').slice(0, MAKS_PER_BOLK)
  const oppmerksomhet = kjent.filter((s) => s.retning === 'darlig').slice(0, MAKS_PER_BOLK)

  // Handlingene plukkes fra det brevet FAKTISK VISER, ikke fra alt vi vet.
  // Bolkene kappes ved fire; plukket vi fra hele mengden, kunne en
  // anbefaling stått i brevet uten at tallet bak den var synlig noe sted —
  // og da er den akkurat det regelen skal hindre: et råd uten grunnlag.
  const vist = [...bra, ...oppmerksomhet]
    .sort((a, b) => b.poeng - a.poeng || a.tittel.localeCompare(b.tittel, 'nb'))

  return {
    stasjonNavn: d.stasjonNavn,
    ukeMandag: d.ukeMandag,
    ukenummer: ukenummer(d.ukeMandag),
    overskrift: pulsOverskrift(d.stasjonNavn, vekst),
    ingress: ingressFor(d, vekst, kjent),
    bra,
    oppmerksomhet,
    handlinger: velgHandlinger(vist),
    viIkkeVet,
  }
}
