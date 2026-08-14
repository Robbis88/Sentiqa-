// =====================================================================
// Hva slags dag er dette — for DENNE stasjonen?
//
// Skjærtorsdag på Bønes og skjærtorsdag på Laguneparken er ikke samme
// dag. Den ene ligger ved en utfartsvei og fylles opp; den andre ligger
// ved et kjøpesenter som er stengt og tømmes. En modell som regner ut
// «helligdag = 70 % av normal» tar feil på begge to.
//
// Kalenderen er deterministisk (helligdager.ts vet når skjærtorsdag er).
// Effekten er det ikke. Den måles fra stasjonens egen historikk:
//
//   dagfaktor = kunder den dagen  /  kunder på en vanlig samme ukedag
//
// Utfartsdager trenger ingen liste. De ER dagene som avviker oppover fra
// ukedagsnormalen, og det er nøyaktig det tallet vi regner ut. Fredagen
// før påske havner på plass av seg selv, med den størrelsen den har for
// den stasjonen.
//
// LØNN: en rød dag koster 100 % tillegg. Planleggeren regner i timer, så
// uten et påslag ser 1. mai ut som en helt vanlig fredag. Ti røde dager
// bemannet som søndager kan spise en halv månedsramme uten at noe tall
// viser det.
// =====================================================================

import { helligdagNavn, paaskedag } from './helligdager'

// Aftenene er roede fra klokka 15. Julaften, nyttaarsaften, paaskeaften og
// pinseaften - de fire som faktisk har halv dag i tariffen. Dagen for 1. mai
// og dagen for 17. mai har det IKKE, saa en regel om «dagen for en rod dag»
// ville tatt for mye.
//
// Konsekvensen er at kostnaden ikke er en egenskap ved dagen, men ved TIMEN:
// julaften 10:00 koster en, julaften 16:00 koster to.
const AFTEN_FRA_TIME = 15

function aftenerForAar(year: number): Map<string, string> {
  const p = paaskedag(year)
  const dagFor = (iso: string) => {
    const d = new Date(`${iso}T12:00:00Z`)
    d.setUTCDate(d.getUTCDate() - 1)
    return d.toISOString().slice(0, 10)
  }
  const pinsedag = (() => {
    const d = new Date(`${p}T12:00:00Z`)
    d.setUTCDate(d.getUTCDate() + 49)
    return d.toISOString().slice(0, 10)
  })()
  return new Map([
    [dagFor(p), 'Påskeaften'],
    [dagFor(pinsedag), 'Pinseaften'],
    [`${year}-12-24`, 'Julaften'],
    [`${year}-12-31`, 'Nyttårsaften'],
  ])
}

const aftenCache = new Map<number, Map<string, string>>()
export function aftenNavn(iso: string): string | null {
  const year = Number(iso.slice(0, 4))
  if (!year) return null
  let m = aftenCache.get(year)
  if (!m) { m = aftenerForAar(year); aftenCache.set(year, m) }
  return m.get(iso) ?? null
}

export type Dagtype = 'vanlig' | 'rod' | 'aften'

export type Dagsprofil = {
  dato: string
  ukedag: number // isodow 1–7
  type: Dagtype
  navn: string | null // «Skjærtorsdag» når den er rød
  /** Kundetrykk mot en vanlig samme ukedag. 1 = som normalt. */
  faktor: number
  /** Hvor mange historiske dager faktoren bygger på. 0 = ren gjetning. */
  grunnlag: number
  /** Fra hvilken klokketime timene koster dobbelt. null = ingen. */
  rodFraTime: number | null
}

/**
 * Hva én time denne dagen trekker fra rammen.
 *
 * 100 % tillegg betyr at en rød time koster to. På en aften gjelder det
 * bare fra klokka 15 — julaften 10:00 er en vanlig time, julaften 16:00
 * er ikke det.
 */
export function timekostnad(p: { rodFraTime: number | null }, time: number): number {
  return p.rodFraTime !== null && time >= p.rodFraTime ? RODT_PAASLAG : 1
}

export type Dagsobservasjon = { dato: string; kunder: number }

const isodow = (iso: string) => {
  const d = new Date(`${iso}T12:00:00Z`).getUTCDay()
  return d === 0 ? 7 : d
}

const median = (t: number[]) => {
  if (t.length === 0) return 0
  const s = [...t].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

// Faktoren kappes. En enkelt dag med tidobbelt kundetall er en festival
// eller en feil i dataene, og ingen av delene skal styre en månedsplan.
const MIN_FAKTOR = 0.3
const MAKS_FAKTOR = 2.5

/** Røde dager koster 100 % tillegg — én time trekker to fra rammen. */
export const RODT_PAASLAG = 2

/**
 * Profil for hver dato i en måned, målt mot stasjonens egen historikk.
 *
 * `historikk` er kunder per dato, gjerne 12–24 måneder. Normalen for en
 * ukedag er MEDIANEN av vanlige (ikke røde) dager med samme ukedag — ikke
 * snittet, som ville latt julaften og 17. mai dra opp den vanlige onsdagen.
 *
 * Røde dager sammenlignes med SIN EGEN dag i fjor når vi har den:
 * skjærtorsdag mot skjærtorsdag. Har vi ikke det, brukes gjennomsnittet av
 * de røde dagene vi har, og til slutt ukedagsnormalen. `grunnlag` sier
 * hvilket av dem som gjaldt, så UI-et kan skille et målt tall fra en
 * antagelse.
 */
export function dagsprofiler(
  datoer: string[],
  historikk: Dagsobservasjon[],
): Dagsprofil[] {
  const vanligePerUkedag = new Map<number, number[]>()
  const rodePerNavn = new Map<string, number[]>()
  const alleRode: number[] = []

  for (const h of historikk) {
    if (h.kunder <= 0) continue
    const navn = helligdagNavn(h.dato) ?? aftenNavn(h.dato)
    if (navn) {
      const liste = rodePerNavn.get(navn) ?? []
      liste.push(h.kunder)
      rodePerNavn.set(navn, liste)
      alleRode.push(h.kunder)
    } else {
      const u = isodow(h.dato)
      const liste = vanligePerUkedag.get(u) ?? []
      liste.push(h.kunder)
      vanligePerUkedag.set(u, liste)
    }
  }

  const normalFor = (u: number) => median(vanligePerUkedag.get(u) ?? [])
  // Alle vanlige dager under ett — brukes som nevner for røde dager, som
  // ikke har en meningsfull «samme ukedag» å måles mot (1. juledag flytter
  // seg gjennom uka).
  const normaltOverhodet = median([...vanligePerUkedag.values()].flat())

  return datoer.map((dato) => {
    const u = isodow(dato)
    const rodNavn = helligdagNavn(dato)
    const aften = rodNavn ? null : aftenNavn(dato)
    const navn = rodNavn ?? aften
    const type: Dagtype = rodNavn ? 'rod' : aften ? 'aften' : 'vanlig'
    const rodFraTime = rodNavn ? 0 : aften ? AFTEN_FRA_TIME : null

    if (!navn) {
      // Vanlige dager ER normalen. Ukedagsformen ligger allerede i
      // planleggerens kundeprofil, så her er faktoren 1.
      const n = vanligePerUkedag.get(u)?.length ?? 0
      return { dato, ukedag: u, type, navn: null, faktor: 1, grunnlag: n, rodFraTime }
    }

    const egne = rodePerNavn.get(navn) ?? []
    const nevner = normaltOverhodet || normalFor(u)
    if (nevner <= 0) {
      return { dato, ukedag: u, type, navn, faktor: 1, grunnlag: 0, rodFraTime }
    }

    const teller = egne.length > 0
      ? median(egne)
      : alleRode.length > 0 ? median(alleRode) : 0
    if (teller <= 0) {
      return { dato, ukedag: u, type, navn, faktor: 1, grunnlag: 0, rodFraTime }
    }

    const raa = teller / nevner
    return {
      dato,
      ukedag: u,
      type,
      navn,
      faktor: Math.min(MAKS_FAKTOR, Math.max(MIN_FAKTOR, raa)),
      grunnlag: egne.length,
      rodFraTime,
    }
  })
}

/** Alle datoer i en måned, ISO-formatert. */
export function datoerIMaaned(ar: number, maned: number): string[] {
  const antall = new Date(Date.UTC(ar, maned, 0)).getUTCDate()
  return Array.from({ length: antall }, (_, i) =>
    `${ar}-${String(maned).padStart(2, '0')}-${String(i + 1).padStart(2, '0')}`)
}

/**
 * Hva de røde dagene i måneden koster ekstra, i timer.
 *
 * Ikke en advarsel om at de finnes — et tall. Bemanner du 1. mai som en
 * vanlig fredag, forsvinner det en fredag til av rammen uten at noen har
 * bestemt det.
 */
export function rodtPaaslagTimer(
  profiler: Dagsprofil[],
  /** Timene stasjonen er bemannet denne dagen, som klokketimer. */
  timerPerDag: (p: Dagsprofil) => number[],
): number {
  return profiler.reduce(
    (sum, p) => sum + timerPerDag(p).reduce((a, t) => a + (timekostnad(p, t) - 1), 0),
    0,
  )
}
