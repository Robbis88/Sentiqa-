// =====================================================================
// Svinn per maaned: kost mot kost, og en aerlig tomhet.
//
// DEN GAMLE PROSENTEN VAR ALT SVINN DELT PAA MATSALGET. To feil i samme
// brook: omfanget matchet ikke (kiosk, tobakk og bilvask svinner, men
// talte ikke i nevneren), og enheten matchet ikke (kostpris delt paa
// omsetning). Produksjonsdata 2026-08-24 bekreftet at
// `nettopris_total` er kostpris - 97-99 % av EAN-ene med baade svinn og
// salg laa innenfor 15 % av enhetskosten, mot 0-1,5 % for utsalgsprisen.
//
// Her er regelen: kost mot kost, samme stasjon, samme varegruppe,
// samme maaned.
//
// ---------------------------------------------------------------------
// TRE TILSTANDER SOM IKKE ER DEN SAMME
//
//   0 %          maalt, og det svant ingenting. Et svar.
//   ikke maalbart  det finnes ingen nevner. IKKE et svar.
//   ikke koblet   kronene er ekte, men har ingen salgsmotpart.
//
// Den midterste er hele grunnen til at `prosent` returnerer `null` og
// ikke 0. Et manglende tall som vises som null ser ut som en maaling,
// og da tas det for en. Det er den samme sykdommen som gikk gjennom
// AI-laget i august: stillhet som likner et godkjent svar.
// =====================================================================

/** Én rad fra `v_svinn_maaned`. */
export type Svinnrad = {
  stasjon_id: string
  maned: string
  gruppe_kode: string | null
  gruppe_navn: string | null
  koblet: boolean
  svinn_kr: number
  svinn_antall: number
  svinn_linjer: number
  /** Null naar gruppa ikke har salg i perioden. Da finnes ingen nevner. */
  varekost_kr: number | null
  omsetning_kr: number | null
  solgt_antall: number | null
}

/** Én rad fra `v_svinn_dekning`. */
export type Dekningsrad = {
  stasjon_id: string
  maned: string
  dager_registrert: number
  dager_i_maaned: number
  dager_hittil: number
  siste_registrering: string | null
  /** Snitt antall dager mellom tellinger. Null naar det bare er én. */
  snitt_intervall_dager: number | null
}

export type Kategori = {
  kode: string | null
  navn: string
  svinnKr: number
  svinnAntall: number
  varekostKr: number | null
  /** Null = ikke maalbart. Aldri 0 naar nevneren mangler. */
  prosent: number | null
}

export type Dekning = {
  registrert: number
  mulige: number
  /** Andel av dagene som har passert, ikke av hele maaneden. */
  andel: number
  komplett: boolean
  siste: string | null
  /**
   * Snitt antall dager mellom foeringene, eller null.
   *
   * MATEN KASTES HVER DAG. Det som varierer er naar det blir foert:
   * de fleste foerer foer de gaar hjem, noen skriver det ned og
   * butikksjefen foerer det dagen etter eller samler opp flere dager.
   * `dato` er transaksjonsdatoen fra rapport 0452 - altsaa naar det
   * ble slaatt inn, ikke naar maten ble kastet.
   */
  intervall: number | null
  /**
   * Ligger foeringene mer enn halvannen dag fra hverandre i snitt?
   *
   * SIER IKKE HVORFOR. Enten ble noe ikke foert, eller flere dager ble
   * foert samlet - og de to ser like ut i `dato` alene. Forskjellen
   * betyr alt: i det ene tilfellet er maanedens kroner de samme, i det
   * andre er de for lave.
   */
  spredt: boolean
}

export type Maanedsbilde = {
  maned: string
  /**
   * Ble det registrert svinn i det hele tatt denne maaneden?
   *
   * EN MAANED UTEN REGISTRERING ER IKKE EN MAANED UTEN SVINN. Uten
   * dette skillet faar en maaned med salg og null telling `0 kr` og
   * `0,0 %` - to tall som ser ut som gode nyheter, og som staar side om
   * side med ekte maalinger i maaned-for-maaned-tabellen.
   */
  registrert: boolean
  /** Antall svinnlinjer i maaneden. Null linjer = ingenting ble talt. */
  linjer: number
  /** Alt svinn i kroner, koblet og ikke koblet. */
  totalKr: number
  kobletKr: number
  ikkeKobletKr: number
  /** Andel av kronene som lot seg kategorisere. */
  kobletAndel: number | null
  /** Nevneren: varekost paa solgte varer i hele butikken. */
  varekostKr: number | null
  /** Totalprosent. Null naar varekosten mangler. */
  prosent: number | null
  kategorier: Kategori[]
  dekning: Dekning | null
}

/**
 * Svinnprosent, eller ingenting.
 *
 * NULL NAAR NEVNEREN MANGLER ELLER ER NULL. En divisjon paa null gir
 * Infinity, og Infinity formatert blir «∞ %» eller «NaN» - begge er
 * paastander systemet ikke har dekning for. En tom nevner betyr at vi
 * ikke vet, og det skal staa.
 *
 * MEN 0 SVINN MOT EN EKTE NEVNER ER 0 %, og det er et svar. Forskjellen
 * mellom «null» og «vet ikke» er hele poenget med denne funksjonen.
 */
export function prosent(svinnKr: number, varekostKr: number | null): number | null {
  if (varekostKr == null) return null
  if (!Number.isFinite(varekostKr) || varekostKr <= 0) return null
  if (!Number.isFinite(svinnKr)) return null
  return (svinnKr / varekostKr) * 100
}

/** Avrundet til én desimal, eller null. Formatering hoerer hjemme ett sted. */
export function prosentAvrundet(svinnKr: number, varekostKr: number | null): number | null {
  const p = prosent(svinnKr, varekostKr)
  return p == null ? null : Math.round(p * 10) / 10
}

/**
 * Dekning for maaneden.
 *
 * MAALES MOT DAGER SOM HAR PASSERT, ikke mot hele maaneden. En
 * inneveaerende maaned med 8 av 8 registrerte dager har full dekning -
 * den er bare ikke ferdig. Blandes de to, ser hver paagaaende maaned ut
 * som en med hull.
 */
export function byggDekning(rad: Dekningsrad | undefined): Dekning | null {
  if (!rad) return null
  const mulige = Math.max(0, rad.dager_hittil)
  return {
    registrert: rad.dager_registrert,
    mulige,
    andel: mulige > 0 ? rad.dager_registrert / mulige : 0,
    komplett: rad.dager_hittil >= rad.dager_i_maaned,
    siste: rad.siste_registrering,
    intervall: rad.snitt_intervall_dager,
    // TO FOERINGER ER EN AVSTAND, IKKE ET MOENSTER. Under tre
    // maalepunkter er snittet bare avstanden mellom to datoer.
    spredt: rad.dager_registrert >= 3
      && rad.snitt_intervall_dager != null
      && rad.snitt_intervall_dager >= 1.5,
  }
}

/**
 * Samler radene for én maaned til ett bilde.
 *
 * IKKE KOBLET SVINN BEHOLDES I TOTALEN. 16-24 % av svinnkronene lar seg
 * ikke koble til en varegruppe - varmmat paa produksjonskode,
 * ingredienser, bulk. De kronene er ekte. Kastes de ut, ser stasjonen
 * ut til aa svinne mindre enn den gjoer, og totalen blir feil i den
 * ene retningen ingen oppdager.
 *
 * De faar sin egen linje i stedet, uten prosent, saa brukeren ser
 * hvor mye av bildet som ikke er kategorisert.
 */
export function byggMaaned(
  maned: string,
  rader: Svinnrad[],
  dekningsrad?: Dekningsrad,
): Maanedsbilde {
  const mine = rader.filter((r) => r.maned === maned)

  // AGGREGERT PER GRUPPE, ikke én rad per rad. Ser eieren hele
  // clusteret, kommer «Mat» én gang per stasjon - og uten denne
  // samlingen ville topplista hatt fem Mat-linjer i stedet for én sum.
  const perGruppe = new Map<string, Kategori>()
  let ikkeKobletKr = 0
  let ikkeKobletAntall = 0
  let linjer = 0

  // Nevneren er HELE butikkens varekost, ogsaa fra grupper uten svinn.
  // Summeres bare gruppene som svinner, blir nevneren for liten og
  // prosenten for hoey - samme feil som den gamle beregningen, bare
  // et hakk finere.
  let varekostKr: number | null = null

  for (const r of mine) {
    if (r.varekost_kr != null) varekostKr = (varekostKr ?? 0) + r.varekost_kr
    linjer += r.svinn_linjer

    if (!r.koblet || r.gruppe_kode == null) {
      ikkeKobletKr += r.svinn_kr
      ikkeKobletAntall += r.svinn_antall
      continue
    }
    const f = perGruppe.get(r.gruppe_kode)
    if (f) {
      f.svinnKr += r.svinn_kr
      f.svinnAntall += r.svinn_antall
      if (r.varekost_kr != null) f.varekostKr = (f.varekostKr ?? 0) + r.varekost_kr
    } else {
      perGruppe.set(r.gruppe_kode, {
        kode: r.gruppe_kode,
        navn: r.gruppe_navn ?? r.gruppe_kode,
        svinnKr: r.svinn_kr,
        svinnAntall: r.svinn_antall,
        varekostKr: r.varekost_kr,
        prosent: null,
      })
    }
  }

  // Prosenten regnes ETTER summeringen. Regnet den per rad og
  // gjennomsnittet tatt etterpaa, ville en liten stasjon telt like mye
  // som en stor - og snittet av prosenter er ikke prosenten av summen.
  const kategorier = [...perGruppe.values()]
    .filter((k) => k.svinnKr !== 0 || k.svinnAntall !== 0)
    .map((k) => ({ ...k, prosent: prosentAvrundet(k.svinnKr, k.varekostKr) }))

  kategorier.sort((a, b) => b.svinnKr - a.svinnKr)

  const kobletKr = kategorier.reduce((a, k) => a + k.svinnKr, 0)
  const totalKr = kobletKr + ikkeKobletKr

  if (ikkeKobletKr !== 0 || ikkeKobletAntall !== 0) {
    kategorier.push({
      kode: null,
      navn: 'Ikke koblet',
      svinnKr: ikkeKobletKr,
      svinnAntall: ikkeKobletAntall,
      varekostKr: null,
      prosent: null,
    })
  }

  // INGEN LINJER, INGEN MAALING. `full outer join` gjoer at en maaned
  // kan ha salgsrader uten en eneste svinnrad - da er 0 kr ikke et
  // maalt null, det er fravaeret av en telling.
  const registrert = linjer > 0

  return {
    maned,
    registrert,
    linjer,
    totalKr,
    kobletKr,
    ikkeKobletKr,
    kobletAndel: totalKr > 0 ? kobletKr / totalKr : null,
    varekostKr,
    prosent: registrert ? prosentAvrundet(totalKr, varekostKr) : null,
    kategorier,
    dekning: byggDekning(dekningsrad),
  }
}

/**
 * Er to maaneder sammenlignbare?
 *
 * IKKE EN KVALITETSDOM. Den sier ikke at 40 % dekning er «daarlig» -
 * den sier at 40 mot 90 ikke er det samme grunnlaget, og at en
 * utvikling mellom dem kan vaere registreringsvane snarere enn svinn.
 * Terskelen er ikke funnet paa: den er «dobbelt saa mange hull», som
 * er det groveste avviket man kan kalle likt.
 */
export function sammenlignbare(a: Dekning | null, b: Dekning | null): boolean {
  if (!a || !b) return false
  const hullA = 1 - a.andel
  const hullB = 1 - b.andel
  if (hullA <= 0.05 && hullB <= 0.05) return true
  const storst = Math.max(hullA, hullB)
  const minst = Math.min(hullA, hullB)
  return storst <= minst * 2
}

/** Maanedene som finnes i radene, nyeste foerst. */
export function maanederI(rader: Svinnrad[]): string[] {
  return [...new Set(rader.map((r) => r.maned))].sort().reverse()
}
