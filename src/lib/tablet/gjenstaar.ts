// =====================================================================
// Hva gjenstår på skiftet mitt?
//
// Nettbrettets hjem er i dag et rutenett av fliser — Rutineskjema,
// Anvisninger, Lenker, Merker, Premier — der alt ser like viktig ut. Da
// må den som står der selv finne ut hva som haster, og det var jobben
// systemet skulle gjøre.
//
// Målestokken er en sekstenåring på sin første arbeidsdag. Hun skal få
// nettbrettet i hånden og se hva som skal gjøres, uten at butikksjefen
// forklarer systemet.
//
// Derfor: én liste, kort, i rekkefølge. Ikke moduler — gjøremål.
// =====================================================================

export type Slag = 'sjekkpunkt' | 'rutine' | 'oppgave' | 'produksjon'

export type Gjoeremaal = {
  id: string
  tekst: string
  /** Hvor man går for å gjøre det. Ett trykk, ikke en meny. */
  sti: string
  slag: Slag
  kritisk: boolean
  /** «14:00» — når det skulle vært gjort. Null når det ikke har et tidspunkt. */
  klokkeslett: string | null
}

/**
 * Hvor mange som vises før resten skjules.
 *
 * Tre er ikke tilfeldig. Har man ti ting foran seg, velger man ingen —
 * og en liste som ikke kan bli tom, motiverer ikke. Resten telles opp,
 * så ingenting er skjult, bare stilt i kø.
 */
export const VIS_ANTALL = 3

export type Kilder = {
  sjekkpunkter: {
    id: string
    sporsmaal: string
    kritisk: boolean
    klokkeslett?: string | null
  }[]
  /** Rutiner som gjenstår i dag: forventet minus utført. */
  rutinerIgjen: number
  oppgaver: { id: string; tittel: string; fullfort: boolean; frist: string | null }[]
  produksjon: { plan: number; lagd: number } | null
}

/**
 * Alt som gjenstår, i den rekkefølgen det bør gjøres.
 *
 * Kritisk først — det er mattilsynskrav og kjøletemperaturer. Deretter
 * det som har et klokkeslett, tidligst først, fordi det er det som er
 * mest på etterskudd. Til slutt det uten tidspunkt.
 */
export function gjenstaar(k: Kilder): Gjoeremaal[] {
  const ut: Gjoeremaal[] = []

  for (const s of k.sjekkpunkter) {
    ut.push({
      id: `sjekk-${s.id}`,
      tekst: s.sporsmaal,
      sti: '/sjekkpunkt',
      slag: 'sjekkpunkt',
      kritisk: s.kritisk,
      klokkeslett: s.klokkeslett ?? null,
    })
  }

  // Rutinene samles til ÉN linje. Står det femten rutiner igjen, er femten
  // linjer en vegg — «15 rutiner igjen» er det samme svaret, lesbart.
  if (k.rutinerIgjen > 0) {
    ut.push({
      id: 'rutiner',
      tekst: k.rutinerIgjen === 1 ? '1 rutine igjen' : `${k.rutinerIgjen} rutiner igjen`,
      sti: '/rutiner',
      slag: 'rutine',
      kritisk: false,
      klokkeslett: null,
    })
  }

  for (const o of k.oppgaver) {
    if (o.fullfort) continue
    ut.push({
      id: `oppg-${o.id}`,
      tekst: o.tittel,
      sti: '/oversikt',
      slag: 'oppgave',
      kritisk: false,
      klokkeslett: null,
    })
  }

  // Produksjonen teller bare når den faktisk ligger etter. En plan som er
  // i rute er ikke et gjøremål.
  if (k.produksjon && k.produksjon.plan > 0 && k.produksjon.lagd < k.produksjon.plan) {
    ut.push({
      id: 'produksjon',
      tekst: `${k.produksjon.plan - k.produksjon.lagd} produkter igjen å lage`,
      sti: '/produksjonsplan',
      slag: 'produksjon',
      kritisk: false,
      klokkeslett: null,
    })
  }

  return ut.sort((a, b) => {
    if (a.kritisk !== b.kritisk) return a.kritisk ? -1 : 1
    // Med klokkeslett før uten: det som skulle vært gjort 08:00 haster
    // mer enn noe som ikke har et tidspunkt i det hele tatt.
    if ((a.klokkeslett === null) !== (b.klokkeslett === null)) {
      return a.klokkeslett === null ? 1 : -1
    }
    if (a.klokkeslett && b.klokkeslett && a.klokkeslett !== b.klokkeslett) {
      return a.klokkeslett < b.klokkeslett ? -1 : 1
    }
    return 0
  })
}

/** Overskriften over lista. Skrevet som et menneske ville sagt det. */
export function overskrift(antall: number): string {
  if (antall === 0) return 'Alt er gjort'
  if (antall === 1) return '1 ting igjen'
  return `${antall} ting igjen`
}
