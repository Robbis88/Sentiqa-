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

function erFelles(o: Record<string, unknown>): boolean {
  return typeof o.analyseversjon === 'string'
    && typeof o.beregnetForMaaned === 'string'
    && typeof o.beregnetTid === 'string'
}

export function lesMatkast(v: unknown): Matkastsnapshot | null {
  if (!v || typeof v !== 'object') return null
  const o = v as Record<string, unknown>
  if (!erFelles(o)) return null
  if (!('dom' in o) || !('blokkering' in o)) return null
  return o as unknown as Matkastsnapshot
}

export function lesUsynlig(v: unknown): Usynligsnapshot | null {
  if (!v || typeof v !== 'object') return null
  const o = v as Record<string, unknown>
  if (!erFelles(o)) return null
  if (typeof o.usikker !== 'boolean' || typeof o.vindu !== 'number') return null
  return o as unknown as Usynligsnapshot
}
