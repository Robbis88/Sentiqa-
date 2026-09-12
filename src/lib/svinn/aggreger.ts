// =====================================================================
// SVINNAGGREGATENE — UTE AV SIDENE, INN I EN TESTBAR FUNKSJON
// =====================================================================
//
// De fire kodeleserne summerte hver sin vei, inne i en side eller en
// AI-prompt. Ingen av dem kunne derfor bevises: «gir dagens data samme
// tall etter endringen?» er et spørsmål man må kunne kjøre.
//
// Summeringen er IKKE endret. Det som er lagt til er ett steg først:
// grunnlaget velges per stasjonsmåned i `grunnlag.ts`, og aggregatet
// regner på det ene nivået valget landet på. Før reimport er det de
// samme radene som før, og tallene er identiske til øret.
//
// Hver funksjon returnerer `datastatus` sammen med tallet. Et svinntall
// uten grunnlag er et tall ingen kan etterprøve.
// =====================================================================

import { gruppekodeFor } from './nivaa'
import {
  iGrunnlaget, velgGrunnlagPerNoekkel, type Datastatus, type Grunnlagsrad,
} from './grunnlag'

/** Nøkkelen et grunnlagsvalg tas på: én stasjon, én måned. */
export function stasjonsmaaned(
  r: { stasjon_id?: string | null; periode?: string | null },
): string {
  return `${r.stasjon_id ?? 'uten'}|${r.periode ?? 'alle'}`
}

// ---------------------------------------------------------------------
// 1) KAST OG USYNLIG PER STASJON  (admin-dashbord)
// ---------------------------------------------------------------------

export type Stasjonsrad = Grunnlagsrad & {
  stasjon_id: string | null
  periode?: string | null
  kast: number | null
  usynlig_kr: number | null
}

export type Stasjonssum = {
  stasjonId: string
  kastKr: number
  usynligKr: number
  datastatus: Datastatus
  aarsak: string
}

export function svinnPerStasjon(rader: readonly Stasjonsrad[]): Stasjonssum[] {
  const { perNoekkel } = velgGrunnlagPerNoekkel(rader, stasjonsmaaned)
  const ut = new Map<string, Stasjonssum>()

  for (const [noekkel, valg] of perNoekkel) {
    const stasjonId = noekkel.split('|')[0]
    if (stasjonId === 'uten') continue // kjederader hører ikke i en stasjonsliste
    const rad = ut.get(stasjonId) ?? {
      stasjonId, kastKr: 0, usynligKr: 0, datastatus: valg.datastatus, aarsak: valg.aarsak,
    }
    for (const r of valg.rader) {
      rad.kastKr += r.kast ?? 0
      rad.usynligKr += r.usynlig_kr ?? 0
    }
    // Den svakeste statusen vinner: er én måned på eldre grunnlag, er
    // stasjonens sum det.
    if (valg.datastatus === 'utilgjengelig'
      || (valg.datastatus === 'eldre_grunnlag' && rad.datastatus === 'gruppe')) {
      rad.datastatus = valg.datastatus
      rad.aarsak = valg.aarsak
    }
    ut.set(stasjonId, rad)
  }

  return [...ut.values()]
}

// ---------------------------------------------------------------------
// 2) MANKO, OVERSKUDD OG TOPPLISTE  (analyse-siden)
// ---------------------------------------------------------------------
//
// Toppliste-delen er grunnen til at nivå MÅ velges her. Grupperaden er
// per definisjon større enn hver av produktradene sine, så på et blandet
// utvalg ville lista vist «120 Mat» der spørsmålet er HVILKEN vare som
// svinner. Totalen skal komme fra gruppen, detaljen fra produktene — og
// derfor har topplista sitt eget, eksplisitte nivåvalg.

export type Mankorad = Grunnlagsrad & {
  stasjon_id: string | null
  periode?: string | null
  navn: string
  kode?: string | null
  salg?: number | null
  usynlig_kr: number | null
  usynlig_pst?: number | null
}

export type Mankosum<T> = {
  stasjonId: string
  mankoKr: number
  overskuddKr: number
  /** Forklaringen. Alltid produktnivå når det finnes, ellers grunnlaget. */
  topp: T[]
  bunn: T[]
  datastatus: Datastatus
  aarsak: string
}

export function mankoPerStasjon<T extends Mankorad>(rader: readonly T[]): Mankosum<T>[] {
  const { perNoekkel } = velgGrunnlagPerNoekkel(rader, stasjonsmaaned)
  const perStasjon = new Map<string, { total: T[]; status: Datastatus; aarsak: string }>()

  for (const [noekkel, valg] of perNoekkel) {
    const stasjonId = noekkel.split('|')[0]
    if (stasjonId === 'uten') continue
    const b = perStasjon.get(stasjonId) ?? { total: [], status: valg.datastatus, aarsak: valg.aarsak }
    b.total.push(...valg.rader)
    if (valg.datastatus === 'utilgjengelig'
      || (valg.datastatus === 'eldre_grunnlag' && b.status === 'gruppe')) {
      b.status = valg.datastatus
      b.aarsak = valg.aarsak
    }
    perStasjon.set(stasjonId, b)
  }

  return [...perStasjon.entries()].map(([stasjonId, b]) => {
    let mankoKr = 0, overskuddKr = 0
    for (const r of b.total) {
      const v = r.usynlig_kr ?? 0
      if (v > 0) mankoKr += v
      else overskuddKr += v
    }
    // FORKLARINGEN: produktradene, uansett hvilket nivå totalen kom fra.
    // Finnes de ikke (fase 1 har bare produktrader, som da ER totalen),
    // brukes de samme radene.
    //
    // `iGrunnlaget` MAA staa her ogsaa. Foerste utgave hentet forklaringen
    // rett fra raa rader, og da ledet `1490 Diesel` med 9 999 kroner i
    // usynlig topplista over «hvilken vare svinner». Totalen var riktig
    // og forklaringen var feil - den vondeste formen. Testen fant den.
    const detaljer = rader.filter((r) => iGrunnlaget(r)
      && stasjonsmaaned(r).startsWith(`${stasjonId}|`))
    const produkter = detaljer.filter((r) => r.nivaa === 'produkt' || r.nivaa == null)
    const forklaring = produkter.length > 0 ? produkter : b.total
    const sortert = [...forklaring].sort((x, y) => (y.usynlig_kr ?? 0) - (x.usynlig_kr ?? 0))
    return {
      stasjonId,
      mankoKr: Math.round(mankoKr),
      overskuddKr: Math.round(overskuddKr),
      topp: sortert.filter((s) => (s.usynlig_kr ?? 0) > 0).slice(0, 5),
      bunn: sortert.filter((s) => (s.usynlig_kr ?? 0) < 0).slice(-5).reverse(),
      datastatus: b.status,
      aarsak: b.aarsak,
    }
  }).sort((x, y) => y.mankoKr - x.mankoKr)
}

// ---------------------------------------------------------------------
// 3) KAST OG USYNLIG PER VAREGRUPPE  (fokus, kastbudsjett)
// ---------------------------------------------------------------------
//
// Her satt dobbeltellingen tydeligst: begge leserne nøklet på kodens tre
// første siffer (`12010 → 120`). Grupperaden `120` gir `120` gjennom
// samme regel, så etter reimport ville mat blitt lagt til to ganger —
// én gang som gruppe og én gang som summen av produktene sine.

export type Gruppesumrad = Grunnlagsrad & {
  stasjon_id?: string | null
  periode?: string | null
  kode: string | null
  kast: number | null
  usynlig_kr: number | null
}

export type Gruppesum = {
  gruppe: string
  kastKr: number
  usynligKr: number
}

export function svinnPerGruppe(
  rader: readonly Gruppesumrad[],
): { grupper: Gruppesum[]; datastatus: Datastatus; aarsak: string } {
  const { perNoekkel, alleRader, samletStatus } = velgGrunnlagPerNoekkel(rader, stasjonsmaaned)
  const kart = new Map<string, Gruppesum>()

  for (const r of alleRader) {
    // Grupperaden ER gruppekoden sin; produktraden peker på sin gruppe.
    const g = r.nivaa === 'gruppe' ? (r.kode ?? null) : gruppekodeFor(r.kode ?? '')
    if (!g) continue
    const rad = kart.get(g) ?? { gruppe: g, kastKr: 0, usynligKr: 0 }
    rad.kastKr += r.kast ?? 0
    rad.usynligKr += r.usynlig_kr ?? 0
    kart.set(g, rad)
  }

  const foerste = [...perNoekkel.values()][0]
  return {
    grupper: [...kart.values()].sort((a, b) => a.gruppe.localeCompare(b.gruppe)),
    datastatus: samletStatus,
    aarsak: samletStatus === 'gruppe'
      ? 'Grupperaden eier totalen.'
      : (foerste?.aarsak ?? 'Ingen svinnrader.'),
  }
}
