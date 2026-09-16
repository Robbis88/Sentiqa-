import type { A1Resultat, Uprisetgrunn } from './a1'

// =====================================================================
// FRA MOTORENS RESULTAT TIL EN SMAL, SERIALISERBAR VISNINGSMODELL.
//
// `A1Resultat` baerer hele revisjonskjeden - 107 `Vurdertrad` med nestede
// identiteter og prisbarheter for Boenes august. Aa sende den til en
// blokk som viser fire tall ville vaert sloesing, og den ville dratt
// interne navn med seg helt ut i markup.
//
// ---------------------------------------------------------------------
// KORTET ARVER DEN STRUKTURELLE SIKKERHETEN, IKKE BARE TALLENE
//
// `kildemangel` har BOKSTAVELIG TALT ikke et `kroner`-felt. Vi proever
// ikke aa huske at UI-et ikke skal vise «0 kr» - vi gjoer den
// misvisende fremstillingen vanskelig aa uttrykke.
//
// Det er samme grep som `Kilder` og `A1Beregning` gjoer i motoren, og
// det skal holdes gjennom hele UI-laget: en kontrakt som gjoer loegnen
// vanskelig slaar en kommentar som ber utvikleren huske paa den.
//
// ---------------------------------------------------------------------
// TIMER REGNES AV MINUTTER, ALDRI MOTSATT
//
// Minutter er beregningsgrunnlaget hele veien. Her - og bare her -
// gjoeres de om til timer for visning. Gikk konverteringen andre veien,
// ville avrunding sneket seg inn i et tall som skal vaere eksakt.
// =====================================================================

export type Kildemangel = 'register' | 'arbeidstid' | 'begge'

export type Uprisetperson = {
  ansattNr: string
  navn: string
  timer: number
  grunn: Uprisetgrunn
}

export type A1Kort =
  | {
    status: 'kildemangel'
    maaned: string
    mangler: Kildemangel
    /** Kjent betalt arbeidstid uten sats. Bare naar registeret mangler. */
    timer?: number
    personer?: number
  }
  | {
    status: 'minimum' | 'komplett'
    maaned: string
    kroner: number
    betalteTimer: number
    prisedeTimer: number
    forklarteTimer: number
    upriseteTimer: number
    /** Andel av betalt tid som ble priset. `null` naar det ikke er betalt tid. */
    andelPriset: number | null
    uprisetePersoner: Uprisetperson[]
    /** Delmengde av `kroner`, aldri et tillegg. */
    innlaantKr: number
    innlaanteNr: string[]
    /**
     * Datakvalitet, en ANNEN akse enn oekonomisk usikkerhet.
     *
     * En ubetalt dublett staar her uten aa gjoere maaneden `minimum`.
     * En betalt dublett staar her OG i `upriseteTimer`.
     */
    dataavvik: { dubletter: number; avvisteVakter: number }
    /** Helligdagstimer i DETTE tallet. 0 betyr at 1410-forbeholdet ikke er aktivt. */
    helligdagstimer: number
    forbehold: string[]
  }

/** Minutter til timer med to desimaler. Ett sted, én gang. */
const timer = (minutter: number): number => Math.round(minutter / 60 * 100) / 100

export function tilA1Kort(r: A1Resultat): A1Kort {
  if (r.status === 'kildemangel') {
    const k = r.kilde
    if (k.status === 'mangler_register') {
      return {
        status: 'kildemangel', maaned: r.maaned, mangler: 'register',
        timer: k.timer, personer: k.personer,
      }
    }
    return {
      status: 'kildemangel', maaned: r.maaned,
      mangler: k.status === 'mangler_arbeidstid' ? 'arbeidstid' : 'begge',
    }
  }

  const uprisete = r.status === 'minimum'
    ? r.upriset.map((u) => ({
      ansattNr: u.ansattNr, navn: u.navn, timer: timer(u.minutter), grunn: u.grunn,
    }))
    : []

  return {
    status: r.status,
    maaned: r.maaned,
    kroner: r.status === 'minimum' ? r.minimum503Kr : r.konto503Kr,
    betalteTimer: timer(r.betalteMinutter),
    prisedeTimer: timer(r.prisedeMinutter),
    forklarteTimer: timer(r.forklarteMinutter),
    upriseteTimer: timer(r.uprisedeMinutter),
    andelPriset: r.betalteMinutter === 0
      ? null
      : Math.round(r.prisedeMinutter / r.betalteMinutter * 1000) / 10,
    uprisetePersoner: uprisete,
    innlaantKr: r.innlaantKr,
    innlaanteNr: r.innlaanteNr,
    dataavvik: {
      dubletter: r.dubletter,
      avvisteVakter: r.rader.filter((v) =>
        v.utfall.slag === 'upriset' && v.utfall.grunn === 'avvist_rad').length,
    },
    helligdagstimer: r.perArt['1410']?.timer ?? 0,
    forbehold: r.forbehold,
  }
}
