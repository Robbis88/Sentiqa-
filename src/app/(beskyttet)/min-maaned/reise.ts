import type { Felt, Okonomibilde } from '@/lib/okonomi/bilde'

// =====================================================================
// PLAN -> PROGNOSE -> FASIT, SOM TRE AVLESNINGER
// =====================================================================
//
// Produktmodellen er PLAN -> tidlige data -> PROGNOSE -> forklaring ->
// handling -> FASIT. Butikksjefen ser i dag bare tallene; hun ser ikke
// HVOR i sløyfa måneden hennes står, og derfor leser hun et anslag og en
// fasit som om de var like sikre.
//
// Denne fila svarer på det ene spørsmålet «hvor er måneden nå?».
//
// ---------------------------------------------------------------------
// DEN DØMMER IKKE. DEN LESER TRE FELT.
// ---------------------------------------------------------------------
//
// Ingen ny sannhetsregel bor her, og det er med vilje:
//
//   PLAN      `bilde.bpLonn.kilde === 'plan'`. `bilde.ts` gir det feltet
//             nøyaktig to verdier — `plan` når BP finnes for måneden, og
//             `mangler` når den ikke gjør det.
//   PROGNOSE  finnes det et felt merket `prognose` blant dem flaten
//             faktisk viser? Kilden er satt av `byggOkonomibilde`; her
//             telles den bare.
//   FASIT     `bilde.dekning.regnskap`. Satt av `byggDekning`.
//
// Ingen aritmetikk, ingen terskel, ingen egen mening om hva som er
// «sikkert nok». Skulle det stått en regel her, ville den vært den andre
// sannheten hele E3 ble bygget for å unngå.
//
// ---------------------------------------------------------------------
// FELTENE SENDES INN, DE VELGES IKKE HER
// ---------------------------------------------------------------------
//
// Samme grep som `Lonnsblokk` gjør med `sikkerhetsgrad`: spørsmålet er
// «hvor står det du SER», ikke «hvor står et bilde du ikke får se».
// Bygges lista av de samme `Felt`-ene som rendres, kan de to ikke skille
// lag.
//
// ---------------------------------------------------------------------
// «ERSTATTET» ER IKKE «MANGLER»
// ---------------------------------------------------------------------
//
// En avlagt måned har ingen felt merket `prognose` — fasiten har tatt
// over hvert eneste. Sto prognosesteget da som `mangler`, ville stripa
// påstått at måneden aldri hadde et anslag, og det er en påstand om noe
// vi ikke vet. `erstattet` sier det som faktisk er tilfellet: anslaget er
// ikke lenger det som gjelder.
//
// Motsatt vei står `plan: mangler` som det den er. En måned uten BP HAR
// ingen plan, også når regnskapet er avlagt — og det er verdt å vite,
// ikke noe å skjule bak et hakemerke.
// =====================================================================

export type Fasetilstand = 'har' | 'mangler' | 'erstattet'

export type Fase = {
  id: 'plan' | 'prognose' | 'fasit'
  /** Ordet på stripa. Store bokstaver settes i CSS, ikke her. */
  tittel: string
  tilstand: Fasetilstand
  /** Én setning om hva tilstanden betyr for måneden. */
  forklaring: string
}

const TEKST: Record<Fase['id'], Record<Fasetilstand, string>> = {
  plan: {
    har: 'BP-en har satt en lønnsramme for måneden.',
    mangler: 'BP mangler for måneden, så det finnes ingen ramme å måle mot.',
    // Planen blir aldri erstattet. Den er dokumentet, ikke et anslag.
    erstattet: 'BP-en har satt en lønnsramme for måneden.',
  },
  prognose: {
    har: 'Tidlige tall er inne, og minst ett tall på siden er anslått.',
    mangler: 'Ingen tidlige tall er kommet ennå.',
    erstattet: 'Regnskapet har tatt over. Anslagene gjelder ikke lenger.',
  },
  fasit: {
    har: 'Regnskapet er avlagt. Tallene er avstemt.',
    mangler: 'Regnskapet er ikke avlagt ennå.',
    erstattet: 'Regnskapet er avlagt. Tallene er avstemt.',
  },
}

/**
 * Hvor måneden står, som tre steg.
 *
 * `felter` skal være nøyaktig de feltene flaten viser. Se over.
 */
export function reisen(bilde: Okonomibilde, felter: readonly Felt[]): Fase[] {
  const harFasit = bilde.dekning.regnskap
  const harPlan = bilde.bpLonn.kilde === 'plan'
  const harPrognose = felter.some((f) => f.kilde === 'prognose')

  const fase = (id: Fase['id'], tittel: string, tilstand: Fasetilstand): Fase =>
    ({ id, tittel, tilstand, forklaring: TEKST[id][tilstand] })

  return [
    fase('plan', 'Plan', harPlan ? 'har' : 'mangler'),
    fase('prognose', 'Prognose', harFasit ? 'erstattet' : harPrognose ? 'har' : 'mangler'),
    fase('fasit', 'Fasit', harFasit ? 'har' : 'mangler'),
  ]
}

/**
 * Månedens tilstand, i klartekst under stasjonsnavnet.
 *
 * =====================================================================
 * ÉN SETNING I STEDET FOR EN STRIPE MED TRE
 * =====================================================================
 *
 * Reisestripa er riktig, men den svarer på «kan jeg stole på tallet» —
 * og det er ikke spørsmålet den som åpner siden har. Hun spør hvordan
 * måneden går. Stripa flyttes derfor under «Vis grunnlaget», og denne
 * ene linja bærer det leseren trenger på første skjerm.
 *
 * TO AVLESNINGER, INGEN NY REGEL:
 *
 *   `dekning.regnskap`   avlagt eller ikke
 *   `dekning.salgsdager` hvor mange av dagene som KUNNE hatt tall som
 *                        faktisk har det — `muligeSalgsdager` sin egen
 *                        nevner, ikke månedens lengde
 *
 * DEKNINGEN NEVNES BARE FOR EN MÅNED SOM PÅGÅR. En avlagt måned har
 * regnskapet som fasit, og `byggDekning` melder derfor ingen mangler for
 * den — å vise en dagsteller der ville vært en opplysning om noe som
 * ikke lenger betyr noe.
 */
export function maanedsstatus(bilde: Okonomibilde): string {
  if (bilde.dekning.regnskap) return 'Måneden er ferdig. Regnskapet er avlagt.'
  const { har, av } = bilde.dekning.salgsdager
  if (av === 0) return 'Måneden har ikke begynt.'
  return `Måneden pågår. ${har} av ${av} mulige dager har tall.`
}

/**
 * Steget måneden STÅR på, til overskriften.
 *
 * Det seneste som er nådd. `null` når ingen er det — en måned uten BP,
 * uten tidlige tall og uten regnskap finnes knapt, men den skal ikke få
 * en overskrift som påstår noe.
 */
export function naavaerendeFase(faser: readonly Fase[]): Fase | null {
  for (const id of ['fasit', 'prognose', 'plan'] as const) {
    const f = faser.find((x) => x.id === id)
    if (f && f.tilstand === 'har') return f
  }
  return null
}
