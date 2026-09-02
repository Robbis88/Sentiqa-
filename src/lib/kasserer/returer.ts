import { erSystemnummer, nokGrunnlag, per100, MIN_BONGER } from './rate'

// =====================================================================
// RETURER PER KASSERER — TALLET SOM ALLEREDE LÅ DER
//
// 2. september 2026 spurte Robert assistenten hvem som hadde flest
// returer på Laguneparken. Den svarte:
//
//   «Kassererstatistikken bryter dessverre ikke ned på enkeltansatt/
//    kasserer i dette oppslaget … For å finne det må du gå direkte inn
//    i kassesystemet.»
//
// Verktøyet HENTET `kasserer_nr` og `kasserer_navn` fra basen. Det kastet
// dem i `form()`, som grupperte på stasjon alene. Nedbrytningen manglet
// ikke — den ble kastet på veien ut, og assistenten sendte ham til
// kassesystemet etter data den hadde i hånden.
//
// ---------------------------------------------------------------------
// RETURER ALENE, ALDRI SUMMERT
//
// `rate.ts` måler de tre avvikstypene samlet, og der er det riktig.
// Her er det ikke: makulert er 71–83 % av avvikskronene, så en samlet
// rate måler makulering og kaller det returer.
//
// ---------------------------------------------------------------------
// PER 100 BONGER, IKKE I KRONER
//
// Ekte returer følger kunder, og kunder følger bonger. Rangeres det på
// kroner, rangeres den som ekspederer mest. Samme grunn som i `rate.ts`.
//
// ---------------------------------------------------------------------
// TO HALVDELER, IKKE EN TREND
//
// Målingen i `kasserer_fordeling.sql` sier at svingningen INNI én
// kasserer er større enn spennet MELLOM dem. Et nivå kan derfor ikke
// skille personer — men et TRINN kan si at noe forandret seg.
//
// Perioden deles på midten og de to halvdelene stilles ved siden av
// hverandre. Det er ikke en regresjon og skal ikke være det: to tall en
// leser kan sammenligne selv slår en helning ingen kan etterprøve.
// =====================================================================

/** Én dagsrad fra `kassererstatistikk`. */
export type Dagsrad = {
  stasjon_id: string
  kasserer_nr: string
  kasserer_navn: string | null
  dato: string
  bonger: number | null
  retur_antall: number | null
  retur_belop: number | null
}

export type Returbilde = {
  stasjon: string
  kasserer_nr: string
  /** Navnet nummeret bar. En opplysning, ikke en nøkkel — se `rate.ts`. */
  navn: string | null
  /** Sant når nummeret bar flere navn i perioden. Da er navnet ikke en identitet. */
  navn_tvetydig: boolean
  /** Kassa selv (999999 o.l.). Vises, men rangeres aldri sammen med folk. */
  er_kassa: boolean
  bonger: number
  returer: number
  retur_kr: number
  /** Null når grunnlaget er for tynt til å regne rate — se MIN_BONGER. */
  retur_per_100: number | null
  /** Null når det ikke finnes returer å regne snitt av. */
  snitt_kr_per_retur: number | null
  /** Førske halvdel av perioden, returer per 100 bonger. */
  forst_per_100: number | null
  /** Siste halvdel. Sammen med `forst_per_100` viser de et trinn. */
  sist_per_100: number | null
  /** Dagene med flest returer for denne kassa — der kvitteringene hentes. */
  toppdager: { dato: string; returer: number; kr: number }[]
  /** Satt når raten ikke skal leses. Fri tekst, ment for et menneske. */
  merknad?: string
}

const tall = (v: number | null | undefined) => (Number.isFinite(v as number) ? (v as number) : 0)
const rund = (v: number | null, d = 1) =>
  v == null ? null : Math.round(v * 10 ** d) / 10 ** d

/**
 * Returer per kasserer for en periode.
 *
 * `navnFor` oversetter stasjons-id til noe et menneske kjenner igjen.
 * Rekkefølgen er kassa sist, deretter synkende rate — men BARE blant de
 * som har nok grunnlag. Uten det ville en kasse med 12 bonger og én
 * retur ligget øverst, og lista ville pekt på en tilfeldighet.
 */
export function returerPerKasserer(
  rader: Dagsrad[],
  navnFor: Map<string, string>,
): Returbilde[] {
  type Sekk = {
    stasjon_id: string; nr: string; navn: Set<string>
    bonger: number; returer: number; kr: number
    dager: Map<string, { returer: number; kr: number }>
  }
  const per = new Map<string, Sekk>()
  const datoer = new Set<string>()

  for (const r of rader) {
    if (!r.kasserer_nr) continue
    datoer.add(r.dato)
    // NØKKELEN ER (stasjon, nummer). Numrene starter på nytt per stasjon,
    // så nr. 5 på Lone og nr. 5 på Dale er to forskjellige mennesker.
    const k = `${r.stasjon_id}|${r.kasserer_nr}`
    const s = per.get(k) ?? {
      stasjon_id: r.stasjon_id, nr: r.kasserer_nr, navn: new Set<string>(),
      bonger: 0, returer: 0, kr: 0, dager: new Map(),
    }
    if (r.kasserer_navn && r.kasserer_navn.trim() && r.kasserer_navn !== 'Not Available') {
      s.navn.add(r.kasserer_navn.trim())
    }
    s.bonger += tall(r.bonger)
    s.returer += tall(r.retur_antall)
    s.kr += tall(r.retur_belop)
    if (tall(r.retur_antall) > 0) {
      const d = s.dager.get(r.dato) ?? { returer: 0, kr: 0 }
      d.returer += tall(r.retur_antall)
      d.kr += tall(r.retur_belop)
      s.dager.set(r.dato, d)
    }
    per.set(k, s)
  }

  // Midtpunktet er en DATO, ikke halve radene. Kasserere jobber ulike
  // dager, og en deling på radtall ville gitt hver av dem sitt eget skille.
  const sortert = [...datoer].sort()
  const midt = sortert.length > 1 ? sortert[Math.floor(sortert.length / 2)] : null

  const halvdel = (s: Sekk, foer: boolean) => {
    if (!midt) return null
    let b = 0, ret = 0
    for (const r of rader) {
      if (r.stasjon_id !== s.stasjon_id || r.kasserer_nr !== s.nr) continue
      if (foer ? r.dato >= midt : r.dato < midt) continue
      b += tall(r.bonger); ret += tall(r.retur_antall)
    }
    return nokGrunnlag(b, Math.round(MIN_BONGER / 2)) ? rund(per100(ret, b)) : null
  }

  const ut: Returbilde[] = [...per.values()].map((s) => {
    const kassa = erSystemnummer(s.nr)
    const nok = nokGrunnlag(s.bonger)
    return {
      stasjon: navnFor.get(s.stasjon_id) ?? s.stasjon_id,
      kasserer_nr: s.nr,
      navn: s.navn.size === 1 ? [...s.navn][0] : s.navn.size > 1 ? [...s.navn].join(' / ') : null,
      navn_tvetydig: s.navn.size > 1,
      er_kassa: kassa,
      bonger: Math.round(s.bonger),
      returer: Math.round(s.returer),
      retur_kr: Math.round(s.kr),
      retur_per_100: nok ? rund(per100(s.returer, s.bonger)) : null,
      snitt_kr_per_retur: s.returer > 0 ? rund(s.kr / s.returer, 0) : null,
      forst_per_100: nok ? halvdel(s, true) : null,
      sist_per_100: nok ? halvdel(s, false) : null,
      toppdager: [...s.dager.entries()]
        .sort((a, b) => b[1].returer - a[1].returer || a[0].localeCompare(b[0]))
        .slice(0, 6)
        .map(([dato, d]) => ({ dato, returer: Math.round(d.returer), kr: Math.round(d.kr) })),
      ...(kassa
        ? { merknad: 'Kassa selv, ikke en person. Rangeres ikke sammen med kasserere.' }
        : !nok
          ? { merknad: `Under ${MIN_BONGER} bonger — raten er støy og er utelatt.` }
          : s.navn.size > 1
            ? { merknad: 'Nummeret bar flere navn i perioden. Navnet er ikke en identitet her.' }
            : {}),
    }
  })

  return ut.sort((a, b) => {
    if (a.er_kassa !== b.er_kassa) return a.er_kassa ? 1 : -1
    const ar = a.retur_per_100, br = b.retur_per_100
    if (ar == null && br == null) return b.bonger - a.bonger
    if (ar == null) return 1
    if (br == null) return -1
    return br - ar || a.kasserer_nr.localeCompare(b.kasserer_nr)
  })
}
