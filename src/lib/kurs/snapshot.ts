// Analysen slik den ble beregnet, frosset.
//
// =====================================================================
// DET SOM GODKJENNES, LAGRES OG SENDES ER SAMME ØYEBLIKKSBILDE
// =====================================================================
//
// Eieren leser et utkast, tar stilling og slipper det. Regnet vi
// analysen på nytt når sida åpnes eller e-posten bygges, kunne
// butikksjefen fått andre tall enn de eieren godkjente — uten at noen
// hadde gjort noe galt. En reimport, en ny delingsfil eller en rettet
// migrasjon holder for å flytte dem.
//
// Derfor lagres beregningen som den var, med nok versjonsinformasjon
// til at en gammel plan kan forklares i ettertid.
//
// ---------------------------------------------------------------------
// `null` ER IKKE BLOKKERT
//
// En plan uten snapshot ble aldri analysert med denne motoren — den er
// eldre enn den. Flaten sier «Ikke beregnet», ikke «blokkert»: blokkert
// betyr at vi prøvde og stoppet med en årsak, og det er en helt annen
// beskjed til den som leser.

import type { Kastdom } from './kastvurdering'
import type { Kurs } from './retning'
import type { Maanedsplan } from './plan'

/**
 * Et navn, ikke et tidspunkt eller en hash.
 *
 * Samme form som `PARSERVERSJON`: en versjon man kan si høyt i et møte,
 * og som endres når REGELEN endres — ikke når en linje flyttes.
 */
export const ANALYSEVERSJON = 'p2-kastbudsjett-1'

type Felles = {
  analyseversjon: string
  /** ISO, første i måneden analysen gjelder. */
  beregnetForMaaned: string
  beregnetTid: string
}

export type Matkastsnapshot = Felles & {
  dom: Kastdom | null
  blokkering: string | null
}

export type Usynligsnapshot = Felles & {
  naaKr: number | null
  kurs: Kurs | null
  /** Antall måneder retningen er regnet på. `0` når den mangler. */
  vindu: number
  usikker: boolean
  aarsakUsikker: string | null
  blokkering: string | null
}

export function lagSnapshot(plan: Maanedsplan, naa = new Date()): {
  matkast: Matkastsnapshot
  usynlig: Usynligsnapshot
} {
  const felles: Felles = {
    analyseversjon: ANALYSEVERSJON,
    beregnetForMaaned: plan.maaned,
    beregnetTid: naa.toISOString(),
  }
  return {
    matkast: { ...felles, dom: plan.matkast.dom, blokkering: plan.matkast.blokkering },
    usynlig: {
      ...felles,
      naaKr: plan.usynlig.naaKr,
      kurs: plan.usynlig.kurs,
      vindu: plan.usynlig.vindu,
      usikker: plan.usynlig.usikker,
      aarsakUsikker: plan.usynlig.aarsakUsikker,
      blokkering: plan.usynlig.blokkering,
    },
  }
}

// =====================================================================
// LESING
// =====================================================================
//
// Kolonnene er `jsonb` og kommer tilbake som `unknown`. Disse to
// funksjonene er den eneste veien inn, og de sier `null` på alt de ikke
// kjenner igjen — en halv struktur skal ikke bli halve tall på flaten.

const tall = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v)
const tekst = (v: unknown): v is string => typeof v === 'string'
const obj = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v)

/**
 * Bare STOETTEDE versjoner slipper gjennom.
 *
 * En ukjent `analyseversjon` er ikke et snapshot vi kan tegne - formen
 * kan ha endret seg. Da er «ikke beregnet» riktig svar, ikke en
 * runtime-feil i `analysevisning`.
 */
export const STOTTEDE_VERSJONER: readonly string[] = [ANALYSEVERSJON]

function erFelles(o: Record<string, unknown>): boolean {
  return tekst(o.analyseversjon)
    && STOTTEDE_VERSJONER.includes(o.analyseversjon)
    && tekst(o.beregnetForMaaned)
    && tekst(o.beregnetTid)
}

/**
 * `Kurs` slik `retning()` lager den, eller `null`.
 *
 * =====================================================================
 * `null` OG «MANGLER» ER TO FORSKJELLIGE TING
 * =====================================================================
 *
 * `kurs: null` er en MAALING: serien fantes, men hadde ikke nok
 * punkter til en retning. Det er en gyldig tilstand, og flaten sier
 * «ingen retning ennaa».
 *
 * At noekkelen `kurs` ikke finnes i det hele tatt er noe annet: da er
 * snapshotet ufullstendig, skrevet av en annen motor eller klippet i
 * to. Der skal leseren si `null` og flaten «ikke beregnet».
 *
 * Foerste utgave skrev `erKurs(v.kurs ?? null)`. `??` gjoer nettopp den
 * forskjellen usynlig - et manglende felt ble til en gyldig `null`, og
 * vakten godkjente et halvt snapshot mens den saa ut til aa maale noe.
 * Derfor sjekkes NOEKKELEN foerst, og `erKurs` tar aldri imot
 * `undefined`.
 */
function erKurs(v: unknown): boolean {
  if (v === null) return true
  if (!obj(v)) return false
  return (v.vei === 'opp' || v.vei === 'ned' || v.vei === 'flat')
    && tall(v.paaRad) && tall(v.endring) && tall(v.spenn)
}

/** Noekkelen finnes OG verdien er gyldig. */
function harKurs(o: Record<string, unknown>): boolean {
  return 'kurs' in o && erKurs(o.kurs)
}

/**
 * HELE STRUKTUREN FLATEN LESER, ikke bare at feltene finnes.
 *
 * Foerste utgave sjekket tre strenger og at `dom` og `blokkering` var
 * til stede, og typecastet resten. Et snapshot uten `dom.naa`, med
 * `faktiskPst` som tekst, eller uten `kurs` slapp gjennom og krasjet
 * foerst naar `analysevisning` skulle formatere det.
 */
function erKasttall(v: unknown): boolean {
  if (!obj(v)) return false
  return tekst(v.maaned)
    && tall(v.matsalgKr) && tall(v.synligKastKr)
    && tall(v.faktiskPst) && tall(v.budsjettPst)
    && tall(v.justertBudsjettKr) && tall(v.avvikKr) && tall(v.avvikPstpoeng)
    && typeof v.gunstig === 'boolean'
}

function erKastdom(v: unknown): boolean {
  if (!obj(v)) return false
  return (v.slag === 'tiltak' || v.slag === 'observer' || v.slag === 'bekreftelse')
    && erKasttall(v.naa)
    && harKurs(v)
    && tall(v.ugunstige) && tall(v.antallMaaneder)
    && tekst(v.tekst)
}

export function lesMatkast(v: unknown): Matkastsnapshot | null {
  if (!obj(v)) return null
  if (!erFelles(v)) return null
  const blokkert = v.blokkering === null || tekst(v.blokkering)
  if (!blokkert) return null
  // `dom: null` ER gyldig - det er en blokkert analyse. Men er den der,
  // maa HELE den vaere der.
  if (v.dom !== null && !erKastdom(v.dom)) return null
  if (v.dom === null && !tekst(v.blokkering)) return null
  return v as unknown as Matkastsnapshot
}

/**
 * Kunne hovedtiltaket velges? Utfallet slik motoren lagret det.
 *
 * =====================================================================
 * DEN TREDJE JSONB-KOLONNEN, OG DEN ENESTE SOM IKKE HADDE EN LESER
 * =====================================================================
 *
 * `matkast` og `usynlig` gikk gjennom `lesMatkast`/`lesUsynlig`.
 * `rangering` ble typecastet i sida og sendt rett til komponenten med
 * `?? { mulig: true, kandidater: [] }`. To feil i samme linje:
 *
 *   1  EN OEDELAGT STRUKTUR KRASJET FLATEN. `{}` eller en tekst passerte
 *      casten, og `rangeringstekst()` leste `r.kandidater.length` paa
 *      noe som ikke hadde `kandidater`.
 *
 *   2  EN GAMMEL PLAN BLE FRISKMELDT. `null` betyr «laget foer feltet
 *      fantes» - vi vet ikke hva den motoren gjorde. Fallbacken gjorde
 *      det om til «rangeringen var mulig, og ingen kandidater fantes»,
 *      og da kunne flaten skrive «Ingen av loeftestengene peker feil vei
 *      denne maaneden» om en plan ingen har maalt.
 *
 * Derfor: `null` ut herfra betyr IKKE TILGJENGELIG, og flaten sier det.
 */
export type Rangeringsnapshot = { mulig: boolean; kandidater: string[] }

export function lesRangering(v: unknown): Rangeringsnapshot | null {
  if (!obj(v)) return null
  if (typeof v.mulig !== 'boolean') return null
  if (!Array.isArray(v.kandidater)) return null
  if (!v.kandidater.every(tekst)) return null
  return { mulig: v.mulig, kandidater: [...(v.kandidater as string[])] }
}

export function lesUsynlig(v: unknown): Usynligsnapshot | null {
  if (!obj(v)) return null
  if (!erFelles(v)) return null
  if (typeof v.usikker !== 'boolean' || !tall(v.vindu)) return null
  if (!(v.naaKr === null || tall(v.naaKr))) return null
  if (!(v.aarsakUsikker === null || tekst(v.aarsakUsikker))) return null
  if (!(v.blokkering === null || tekst(v.blokkering))) return null
  if (!harKurs(v)) return null
  // Uten blokkering MAA det finnes et tall. Et snapshot som verken har
  // verdi eller aarsak er en halv struktur.
  if (v.blokkering === null && v.naaKr === null) return null
  return v as unknown as Usynligsnapshot
}
