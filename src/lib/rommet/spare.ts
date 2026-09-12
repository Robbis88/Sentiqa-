import { DRIFT_BEGREP } from '@/lib/kurs/loftestenger'

// =====================================================================
// HVOR KAN DU SPARE — OG HVA SOM SKILLER ET FUNN FRA ET TALL
// =====================================================================
//
// Robert, 2026-09-12: «lag en live demo med ekte tall der vi får bedre
// kostnadkontroll».
//
// Grunnlaget er `bilagssum` — tolv måneders leverandørdetalj som følger
// hver regnskapsfil. Den lå på null rader i produksjon til i dag, fordi
// steget bare fantes i den ene av to importveier.
//
// ---------------------------------------------------------------------
// EN KOSTNAD KAN BARE SAMMENLIGNES NÅR DEN ER DELT PÅ NOE
//
// Laguneparken bruker mer på renhold enn Bønes. Laguneparken er også
// dobbelt så stor. Kroner mot kroner sier ingenting; **kroner per krone
// omsetning** sier noe.
//
// ---------------------------------------------------------------------
// OG DET STØRSTE FUNNET LIGGER PÅ TVERS AV KONTOENE
//
// `627 Renhold` og `633 Forbruksmateriell` er to kontoer og samme
// leverandør: ASKO Vest. Hver linje ser rimelig ut alene. Slått sammen
// og delt på omsetning bruker Lone dobbelt så mye per krone som Varden.
//
// Derfor grupperes det på LEVERANDØR, ikke på konto. Kontoen er hvor
// regnskapsføreren la beløpet; leverandøren er hvem du kan ringe.
//
// ---------------------------------------------------------------------
// DE FALSKE FUNNENE ER STØRRE ENN DE EKTE
//
// En naiv sammenligning av driftskostnader mellom Kelsars stasjoner gir
// 1,68 millioner i «potensial» som ikke finnes: `630 Leie` og `634 Rep`
// er vaskemaskinen, og **Dale har ingen vask**. Dale blir alltid
// «billigst», og planen ber deg jage noe som ikke er der.
//
// Derfor: bare `DRIFT_BEGREP` sammenlignes — utvalget der en forskjell
// mellom to stasjoner faktisk betyr noe. Leie, forsikring og telefon er
// faste avtaler og står utenfor.
// =====================================================================

/** Én rad fra `bilagssum`, slik siden leser den. */
export type Bilagsrad = {
  stasjon_id: string | null
  periode: string
  begrep: string | null
  tekst: string
  belop_kr: number | null
  antall: number | null
}

/** Omsetning per stasjon, nevneren. Fra `v_kurs_maanedstall`. */
export type Omsetningsrad = {
  stasjon_id: string
  maaned: string
  omsetning_kr: number | null
}

export type Stasjon = { id: string; navn: string; butikknummer: string }

export type Leverandorfunn = {
  /** Leverandørnavnet slik det står i bilaget. */
  leverandor: string
  /** Begrepene beløpet er fordelt på — ofte flere, og det er poenget. */
  begreper: string[]
  /** Per stasjon: kroner, andel av omsetning, og antall bilag. */
  per: Array<{
    stasjonId: string
    navn: string
    kroner: number
    andel: number | null
    bilag: number
  }>
  /** Stasjonen med lavest andel. Målestokken, ikke et mål. */
  beste: { navn: string; andel: number } | null
  /**
   * Hva de andre ville brukt på den bestes andel, per år.
   *
   * `null` når vi ikke kan regne det: mangler omsetning, eller bare én
   * stasjon har leverandøren. **Én stasjon er ingen sammenligning.**
   */
  aarligKr: number | null
  /** Hvor mange måneder grunnlaget dekker. Skalerer til år. */
  maaneder: number
}

/** Leverandørnavn som ikke er en leverandør. */
const IKKE_NAVN = [
  /^inng[aå]ende faktura$/i,
  /^utg[aå]ende faktura$/i,
  /^differanse$/i,
  /^korreksjon/i,
  /^betalt med bankkort$/i,
  /^filimport/i,
  /^\d[\d\s.,-]*$/,          // rene fakturanummer
  /^\d{2}\.\d{2}\.\d{4}/,    // periodetekster: «01.07.2026 30.09.2026»
]

/**
 * Er teksten et leverandørnavn vi kan handle på?
 *
 * EN RAD UTEN NAVN ER IKKE ET FUNN. «Inngående faktura» er
 * regnskapsførerens samlepost, et fakturanummer er ikke noen du kan
 * ringe, og en periodetekst er en avtaleperiode. De skal ikke bli
 * tiltak — men de skal heller ikke forsvinne fra summene, så de telles
 * som «uten navn».
 */
export function erLeverandor(tekst: string): boolean {
  const t = tekst.trim()
  if (t.length < 3) return false
  return !IKKE_NAVN.some((r) => r.test(t))
}

/** Normalisert nøkkel: samme leverandør skrives ulikt mellom måneder. */
export function leverandornokkel(tekst: string): string {
  return tekst
    .toLowerCase()
    .replace(/\b(as|asa|ans|da|sa|ltd|inc)\b/g, '')
    .replace(/[^\wæøå]+/gu, ' ')
    .trim()
}

const rund = (n: number) => Math.round(n * 100) / 100

/**
 * Finner leverandørene der stasjonene skiller seg, sortert på hva
 * forskjellen er verdt i året.
 *
 * `minstStasjoner` er 2 med vilje: én stasjon er ingen sammenligning, og
 * et «funn» på én stasjon er bare et beløp.
 */
export function finnSparefunn(
  bilag: readonly Bilagsrad[],
  omsetning: readonly Omsetningsrad[],
  stasjoner: readonly Stasjon[],
  minstStasjoner = 2,
): Leverandorfunn[] {
  const navn = new Map(stasjoner.map((s) => [s.id, s.navn]))

  // Omsetning per stasjon, summert over månedene grunnlaget dekker.
  const omsPer = new Map<string, number>()
  const maanedsett = new Set<string>()
  for (const o of omsetning) {
    maanedsett.add(o.maaned.slice(0, 7))
    omsPer.set(o.stasjon_id, (omsPer.get(o.stasjon_id) ?? 0) + Number(o.omsetning_kr ?? 0))
  }
  const maaneder = maanedsett.size

  // Bare begrepene der en forskjell mellom stasjoner betyr noe.
  const tillatt = new Set<string>(DRIFT_BEGREP)

  type Samlet = {
    leverandor: string
    begreper: Set<string>
    per: Map<string, { kroner: number; bilag: number }>
  }
  const per = new Map<string, Samlet>()

  for (const b of bilag) {
    if (!b.stasjon_id || !b.begrep || !tillatt.has(b.begrep)) continue
    if (!erLeverandor(b.tekst)) continue
    const n = leverandornokkel(b.tekst)
    if (!n) continue
    let s = per.get(n)
    if (!s) {
      s = { leverandor: b.tekst.trim(), begreper: new Set(), per: new Map() }
      per.set(n, s)
    }
    s.begreper.add(b.begrep)
    const f = s.per.get(b.stasjon_id) ?? { kroner: 0, bilag: 0 }
    f.kroner += Number(b.belop_kr ?? 0)
    f.bilag += Number(b.antall ?? 0)
    s.per.set(b.stasjon_id, f)
  }

  const ut: Leverandorfunn[] = []
  for (const s of per.values()) {
    const rader = [...s.per.entries()]
      .filter(([, f]) => f.kroner > 0)
      .map(([id, f]) => {
        const oms = omsPer.get(id) ?? 0
        return {
          stasjonId: id,
          navn: navn.get(id) ?? id,
          kroner: rund(f.kroner),
          andel: oms > 0 ? f.kroner / oms : null,
          bilag: f.bilag,
        }
      })
      .sort((a, b) => b.kroner - a.kroner)

    if (rader.length < minstStasjoner) continue

    const medAndel = rader.filter((r): r is typeof r & { andel: number } => r.andel != null)
    const beste = medAndel.length >= minstStasjoner
      ? medAndel.reduce((a, b) => (b.andel < a.andel ? b : a))
      : null

    // HVA FORSKJELLEN ER VERDT. Hver stasjon over den bestes andel, ned
    // til den andelen — skalert til et år. Ikke et mål, en målestokk:
    // at én stasjon KLARER 0,57 % er beviset på at det er mulig.
    let aarligKr: number | null = null
    if (beste && maaneder > 0) {
      const sum = medAndel.reduce((a, r) => {
        const oms = omsPer.get(r.stasjonId) ?? 0
        return a + Math.max(0, r.kroner - beste.andel * oms)
      }, 0)
      aarligKr = rund((sum / maaneder) * 12)
    }

    ut.push({
      leverandor: s.leverandor,
      begreper: [...s.begreper].sort(),
      per: rader,
      beste: beste ? { navn: beste.navn, andel: beste.andel } : null,
      aarligKr,
      maaneder,
    })
  }

  return ut.sort((a, b) => (b.aarligKr ?? 0) - (a.aarligKr ?? 0))
}

/**
 * Hva grunnlaget dekker. Vises fordi et funn uten omfang er et tall.
 */
export function omfang(bilag: readonly Bilagsrad[]): {
  linjer: number
  kroner: number
  maaneder: number
  eldste: string | null
  nyeste: string | null
  utenNavn: number
} {
  const m = new Set<string>()
  let kroner = 0
  let utenNavn = 0
  for (const b of bilag) {
    m.add(b.periode.slice(0, 7))
    kroner += Number(b.belop_kr ?? 0)
    if (!erLeverandor(b.tekst)) utenNavn++
  }
  const sortert = [...m].sort()
  return {
    linjer: bilag.length,
    kroner: rund(kroner),
    maaneder: m.size,
    eldste: sortert[0] ?? null,
    nyeste: sortert[sortert.length - 1] ?? null,
    utenNavn,
  }
}
