// =====================================================================
// Hva stopper meg akkurat nå?
//
// Bemanningssiden hadde fem tilstander som hver for seg gjør planen
// ubrukelig, spredt over tretten seksjoner: manglende årsramme sto i
// seksjon tre, manglende bemannet vindu som en setning i samme avsnitt
// mens skjemaet lå i seksjon seks, og kontraktunderdekningen — den med
// juridisk regning — i seksjon elleve.
//
// Mønsteret sier at nivå 1 på en arbeidsflyt er «hvor langt er jeg
// kommet, og hva stopper meg». Det fantes ikke noe sted.
//
// TRE VALG SOM AVGJØR OM SVARET ER RIKTIG:
//
// HARDE BLOKKERINGER FØR MYKE FUNN. Uten årsramme eller bemannet vindu
// finnes det ingen plan i det hele tatt. Å vise «stillingene er for
// små» da ville vært å kommentere en plan som ikke er regnet ut.
//
// «RAMMEN ER FOR STRAM» SLÅR «MANGLER VINDU». Dekker ikke årsrammen
// engang minimumsbemanningen, får man en plan ved å legge inn vinduet —
// men den er feil, og feilen ser ut som butikksjefens problem mens den
// er eierens. Da skal hun be om mer ramme, ikke fylle ut flere skjemaer.
//
// KONTRAKT FØR KAPASITET. At stillingene ikke rekker er et vaktproblem
// som løses med en ekstravakt. At timene jobbes uten at kontrakten
// dekker dem er et krav om fast stilling etter aml. § 14-4 a, og det
// vokser stille i tolv måneder før noen ser det.
// =====================================================================

import type { Tiltak } from '@/lib/ansatt/plandekning'

export type Blokkering =
  | 'mangler_ramme'
  | 'ramme_for_stram'
  | 'mangler_vindu'
  | 'kontrakt_underdekning'
  | 'stillinger_for_smaa'
  | 'klar'

/** Hvilket oppsett som løser blokkeringen, når det finnes ett. */
export type Handling = 'import' | 'vindu' | 'stilling'

export type Steg = {
  blokkering: Blokkering
  /** true = det finnes ingen plan å se på før dette er løst. */
  stopper: boolean
  /** Én linje, egnet som undertittel. */
  tittel: string
  /** Hva man gjør med det. */
  forklaring: string
  handling?: Handling
}

export type Tilstand = {
  /** Finnes en årsramme for måneden (forretningsplanen er lastet opp). */
  harRamme: boolean
  /** false = minimumsbemanningen koster mer enn hele årsrammen. */
  gjennomforbar: boolean
  /** Timer årsrammen mangler når den ikke er gjennomførbar. */
  underskudd: number
  /** Finnes minst ett bemannet vindu som har trådt i kraft. */
  harVindu: boolean
  /** Timer til disposisjon denne måneden, når planen er regnet ut. */
  disponible: number | null
  /** Fra plandekning(). null = ikke nok bekreftede kontrakter til å måle. */
  kontraktTiltak: Tiltak | null
  /** Udekkede timer i året. */
  kontraktUdekket: number
  /** Fra kapasitet(): tilgjengelige stillingstimer / planlagte. */
  stillingsdekning: number | null
}

const heltall = new Intl.NumberFormat('nb-NO', { maximumFractionDigits: 0 })

/**
 * Under dette rekker ikke stillingene, og noen må ta ekstravakter
 * uansett hvor god planen er. Samme grense som siden alt bruker.
 */
const DEKNING_GRENSE = 0.95

export function nesteSteg(t: Tilstand): Steg {
  if (!t.harRamme) {
    return {
      blokkering: 'mangler_ramme',
      stopper: true,
      tittel: 'Ingen timeramme for denne måneden',
      forklaring: 'Årsrammen kommer fra forretningsplanen. Uten den vet ingen hvor mange '
        + 'timer måneden har, og det er eier som laster den opp under Import.',
      handling: 'import',
    }
  }

  if (!t.gjennomforbar) {
    return {
      blokkering: 'ramme_for_stram',
      stopper: true,
      tittel: `Rammen dekker ikke minimumsbemanningen — ${heltall.format(Math.round(t.underskudd))} timer for lite i året`,
      forklaring: 'Dette løses ikke ved å flytte timer mellom måneder, og ikke av flere '
        + 'skjemaer her. Enten må åpningstiden kortes ned, eller så er rammen for stram. '
        + 'Si ifra til eier.',
    }
  }

  if (!t.harVindu) {
    return {
      blokkering: 'mangler_vindu',
      stopper: true,
      tittel: 'Mangler bemannet vindu',
      forklaring: 'Planen trenger å vite når det står folk i butikken — ikke når døra '
        + 'åpner. Legg inn én rad per ukedag, så regnes forslaget ut med en gang.',
      handling: 'vindu',
    }
  }

  // Herfra finnes det en plan. Det som gjenstår er funn i den, ikke
  // hindringer for å lage den.
  if (t.kontraktTiltak === 'ny_stilling') {
    return {
      blokkering: 'kontrakt_underdekning',
      stopper: false,
      tittel: `Stillingene er for små for planen — ${heltall.format(Math.round(t.kontraktUdekket))} timer i året uten kontraktdekning`,
      forklaring: 'Planen går trolig opp i praksis, men timene jobbes uten at kontrakten '
        + 'dekker dem. Etter aml. § 14-4 a kan de senere kreves som fast stilling. '
        + 'Se «Bærer kontraktene planen?» under.',
      handling: 'stilling',
    }
  }

  if (t.stillingsdekning !== null && t.stillingsdekning < DEKNING_GRENSE) {
    return {
      blokkering: 'stillinger_for_smaa',
      stopper: false,
      tittel: 'Stillingene rekker ikke denne måneden',
      forklaring: 'Noen må ta ekstravakter uansett hvor god planen er. Det er et '
        + 'vaktproblem, ikke et planproblem — men det er greit å vite før du setter opp.',
      handling: 'stilling',
    }
  }

  return {
    blokkering: 'klar',
    stopper: false,
    tittel: t.disponible !== null
      ? `Planen er klar — ${heltall.format(Math.round(t.disponible))} timer til disposisjon`
      : 'Planen er klar',
    forklaring: 'Ingenting stopper opp. Gå gjennom uka under og juster oppsettet om noe '
      + 'ikke stemmer med hvordan dere faktisk jobber.',
  }
}
