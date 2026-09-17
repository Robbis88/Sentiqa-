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

// ---------------------------------------------------------------------
// VASK ER EN EGEN SANNHET, OG DET ER MÅLT
// ---------------------------------------------------------------------
//
// På vask betyr negativt `usynlig_kr` at vi finner MER brutto enn kassa
// tilsier (Robert, 2026-09-17). Det er gunstig — og det er nettopp derfor
// det er farlig i en sum: et gunstig vaskavvik trekker ned et reelt
// positivt svinn i varegruppene lederen faktisk styrer.
//
// Målt i produksjon, juli 2026 (`src/lib/vaskneting.test.ts`):
//
//   Varden   øvrig +14 696   vask −28 622   total −13 926
//   Bønes    øvrig +12 196   vask −14 713   total  −2 516
//
// Begge står med MINUS i eierens rangering — altså «usynlig overskudd»,
// gode nyheter — mens øvrig drift har over 12 000 kr i manko.
//
// ---------------------------------------------------------------------
// `erVask` BRUKER IKKE `avdelingAv`, OG DET ER MED VILJE
// ---------------------------------------------------------------------
//
// `mot-budsjett.ts` sin `avdelingAv` krever NØYAKTIG fem siffer og gir
// `null` for gruppekoden `210`. Etter reimporten er det nettopp
// grupperadene `velgGrunnlag` velger — målt 2026-09-17: 91 rader inn,
// 0 igjen etter det filteret. Gjenbrukte vi den her, ville vasken falt
// tilbake i «øvrig» i stillhet, og porten hatt null virkning.
//
// Derfor leses avdelingen som de tre første sifrene på begge nivåene:
// `210` og `21010` gir begge `210`.
//
// IKKE EN GENERELL TAKSONOMI. Settet sier at vask holdes utenfor ÉN
// styringsflate. Det klassifiserer ikke de øvrige varegruppene etter
// påvirkbarhet — den vurderingen er ikke gjort, og navnene her later
// ikke som den er det.
// ---------------------------------------------------------------------

/** Avdelingene som er vask. Strukturell kode, aldri navn. */
export const VASKAVDELINGER: ReadonlySet<string> = new Set(['210', '211'])

/**
 * Hører varegruppen til en vaskavdeling?
 *
 * Tar både gruppenivå (`210`) og produktnivå (`21014`). `200 Bil` og
 * `130 Varm drikke` treffer ikke — det første ligner i navn, det andre
 * står i `MOTPOSTER`, og ingen av delene gjør dem til vask.
 */
export function erVask(kode: string | null): boolean {
  const k = (kode ?? '').trim()
  if (!/^\d{3}/.test(k)) return false
  return VASKAVDELINGER.has(k.slice(0, 3))
}

export type Stasjonsrad = Grunnlagsrad & {
  stasjon_id: string | null
  periode?: string | null
  /** Varegruppekoden. PÅKREVD: uten den kan vask ikke skilles ut, og et
   *  manglende felt ville gjort hele vasken til «øvrig» i stillhet. */
  kode: string | null
  kast: number | null
  usynlig_kr: number | null
}

export type Stasjonssum = {
  stasjonId: string
  kastKr: number
  /** RÅTOTALEN, uendret. Alle varegrupper, vask inkludert. */
  usynligKr: number
  /** Bare vaskavdelingene. */
  vaskKr: number
  /** `usynligKr − vaskKr`. Styringstallet for eierens svinnrangering. */
  utenVaskKr: number
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
      stasjonId, kastKr: 0, usynligKr: 0, vaskKr: 0, utenVaskKr: 0,
      datastatus: valg.datastatus, aarsak: valg.aarsak,
    }
    for (const r of valg.rader) {
      rad.kastKr += r.kast ?? 0
      const v = r.usynlig_kr ?? 0
      // RÅTOTALEN FØRST, OG DEN ER UENDRET. Splitten legges ved siden
      // av — den trekker ingenting fra `usynligKr`, så hver eksisterende
      // leser ser nøyaktig samme tall som før.
      rad.usynligKr += v
      if (erVask(r.kode)) rad.vaskKr += v
      else rad.utenVaskKr += v
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
