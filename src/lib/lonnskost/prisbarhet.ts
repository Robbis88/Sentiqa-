// Kan denne personen timeprises i denne måneden?
//
// =====================================================================
// AKSE TO. IDENTITETEN ER ALLEREDE AVGJORT.
//
// `identitet.ts` svarer på HVEM. Denne fila svarer bare på hvordan en
// allerede sikkert koblet person skal behandles økonomisk — og den kan
// ikke kalles med noe annet: inngangen er `Koblet`, ikke `Identitet`.
//
// Den prøver derfor aldri å redde en `ukoblet` eller en `motstrid`. En
// person vi ikke vet hvem er, har ingen prisbarhet å avgjøre.
//
// Den regner heller ingen kroner. Det er B2d.
//
// ---------------------------------------------------------------------
// AVTALEN SLÅS OPP PÅ REGISTERSTASJONEN, ALDRI PÅ ARBEIDSSTEDET
//
// MÅLT mot hvordan systemet allerede gjør det, ikke valgt:
//
//   `import/kjerne.ts`  bygger Map<stasjon_id, Map<ansatt_nr, …>> og
//                       anvender den per stasjon — stasjonen hvis FIL
//                       bar personen
//   `lonn/page.tsx`     leser `.eq('stasjon_id', valgt.id)`
//
// Begge steder er avtalen en egenskap ved ANSETTELSESFORHOLDET på
// hjemstasjonen, ikke ved stedet arbeidet tilfeldigvis skjedde.
// Produksjon 2026-09-16 sier det samme: Sandras `fastlonn` ligger på
// Lone, som er hennes registerstasjon; Mariettas `timelonn` på Bønes,
// som er hennes. Varden har ingen rad på 1018.
//
// Carmen arbeider på Bønes mens ansettelseskonteksten hennes er Lone.
// Oppslaget går derfor på (Lone, 1104265).
//
// ---------------------------------------------------------------------
// ET GLOBALT OPPSLAG ER IKKE MULIG Å SKRIVE HER
//
// `Avtaleoppslag` tar stasjonen som første argument. Skal noen slå opp
// globalt på `ansatt_nr`, må de endre typen — og da står de foran
// valget i stedet for å gli forbi det.
//
// Hvorfor det betyr noe, med ekte tall: `(Lone, 118)` er `fastlonn`.
// Slo vi opp globalt, ville en hvilken som helst annen stasjons 118
// blitt fastlønnsklassifisert, og timene hennes sluttet å bli priset —
// for lite lønn, altså for stort grønt lønnsrom.
//
// ---------------------------------------------------------------------
// «Måned» ER ET VETO. «Time» ER IKKE ET BEVIS.
//
// Easys egen uttalelse om måneden slår alt: sier kilden `maaned`, er
// tallet månedslønn og skal ikke ganges med timer. 48 736 × 193 ser
// ikke ut som en feil, det ser ut som en katastrofe ingen kan forklare.
//
// Men `time` beviser ikke at personen ikke er fastlønnet. Sandra sto
// med `Time`/285 i august og ble klassifisert som fastlønnet 8.
// september. Derfor står avtalen på trinn 2, etter månedens egen
// uttalelse og før alt annet.
//
// ---------------------------------------------------------------------
// UKJENT ENHET ER IKKE MANGLENDE SATS
//
// `0220` og B1 brukte en hel port på at `betalingsfrekvens = null`
// betyr UKJENT og aldri implisitt `time`. En regel som sa «har timesats
// → prisbar» ville opphevet hele den garantien i én linje.
//
// De to er heller ikke det samme problemet:
//
//   ukjent_enhet   Easy har ikke sagt hva tallet ER. Vi vet ennå ikke
//                  engang om personen skal ha en timesats.
//   mangler_sats   Easy har EKSPLISITT sagt Time, men satsen mangler.
//
// Mangler begge, er `ukjent_enhet` den primære feilen. Derfor bærer den
// `timesats: number | null` — ikke fordi satsen alltid finnes, men
// fordi den kan gjøre det, og fordi årsaken skal være sann.
//
// Begge gjør senere datagrunnlaget til `minimum` (B2c). Det er ikke en
// grunn til å slå dem sammen: en ærlig årsak er hele forskjellen på et
// varsel noen kan rette og et varsel ingen forstår.
// =====================================================================

import type { Betalingsfrekvens } from '@/lib/parsere/lonnsgrunnlag'
import type { Lonnsform } from '@/lib/lonn/lonnsform'
import type { Identitet } from './identitet'

/** Bare en sikkert koblet identitet kommer inn hit. */
export type Koblet = Extract<Identitet, { status: 'koblet' }>

/** Én stasjons observasjon om én person i én måned — `lonnsregister`. */
export type Registerobservasjon = {
  stasjonId: string
  ansattNr: string
  /** `yyyy-mm`. Satsen hører til en måned, ikke til en person. */
  maaned: string
  timesats: number | null
  /** `null` = UKJENT enhet. Aldri det samme som `time`. */
  betalingsfrekvens: Betalingsfrekvens | null
}

export type Avtalerad = {
  lonnsform: Lonnsform | null
  /**
   * `ansatt_avtale.oppdatert_tid`, `yyyy-mm-dd`.
   *
   * MERK: tabellen har ingen «gyldig fra». Dette er sist gang raden ble
   * SKREVET, ikke datoen klassifiseringen begynte å gjelde. Røres raden
   * senere for et annet felt, flytter datoen seg. `anvendtBakover` sier
   * derfor bare det den kan vite.
   */
  sistSatt: string
}

/**
 * Avtalen for ÉN stasjon og ett nummer.
 *
 * Stasjonen er første argument med vilje. Et globalt oppslag på
 * `ansatt_nr` lar seg ikke skrive mot denne typen.
 */
export type Avtaleoppslag = (
  stasjonId: string,
  ansattNr: string,
) => Avtalerad | null

/** Observasjonen som lå til grunn, bevart så klassifiseringen kan forklares. */
export type Easyobservasjon = {
  betalingsfrekvens: Betalingsfrekvens | null
  timesats: number | null
}

export type Prisbarhet =
  /** Timene kan ganges med satsen. */
  | {
    status: 'prisbar'
    timesats: number
    kilde: { stasjonId: string; maaned: string }
  }
  /** Kilden sier tallet er månedslønn. Timene telles, men prises ikke. */
  | { status: 'maanedslonn'; belop: number | null }
  /** Et menneske har klassifisert personen som fastlønnet på hjemstasjonen. */
  | {
    status: 'fastlonn_klassifisert'
    proveniens: 'ansatt_avtale'
    stasjonId: string
    sistSatt: string
    /** Ble klassifiseringen sist skrevet ETTER månedens utgang? */
    anvendtBakover: boolean
    /** Hva Easy sa om måneden. Omskrives aldri. */
    easyObservasjon: Easyobservasjon
  }
  /** Easy sa `Time`, men ingen sats. Ikke null kroner — ukjent kroner. */
  | { status: 'mangler_sats' }
  /** Easy sa hverken `Time` eller `Måned`. Vi vet ikke hva tallet er. */
  | { status: 'ukjent_enhet'; timesats: number | null }
  /**
   * Et menneske har klassifisert personen som fastlønnet PÅ
   * ARBEIDSSTASJONEN, uten at lønnsfila kjenner nummeret.
   *
   * EGEN VARIANT, IKKE ET NULLBART FELT PÅ `fastlonn_klassifisert`.
   * Den eldre bygger på en registerrad og bærer derfor Easys egen
   * uttalelse om måneden. Her finnes ingen slik rad, og dermed heller
   * ingen observasjon å bevare. Gjorde vi `easyObservasjon` nullbar,
   * ville den svakere påstanden lånt den sterkeres bevisform — og
   * ingenting i typen ville lenger sagt hvilken av dem man leser.
   *
   * MERK at `stasjonId` her er ARBEIDSSTASJONEN, ikke registerstasjonen.
   * Det er en egen, smalere gren, ikke en fallback for avtaleoppslag
   * generelt: en KOBLET person slås fortsatt opp på registerstasjonen.
   */
  | {
    status: 'fastlonn_uten_register'
    proveniens: 'ansatt_avtale'
    /** Stasjonen arbeidet ble utført på. Det finnes ingen registerstasjon. */
    arbeidsstasjonId: string
    sistSatt: string
    /** Ble klassifiseringen sist skrevet ETTER månedens utgang? */
    anvendtBakover: boolean
  }

const MAANED = /^\d{4}-\d{2}$/

/** Siste dag i måneden, i UTC så en sommertidssone ikke flytter datoen. */
function sisteDag(maaned: string): string {
  const [aar, mnd] = maaned.split('-').map(Number)
  return new Date(Date.UTC(aar, mnd, 0)).toISOString().slice(0, 10)
}

/**
 * Avgjør hvordan en sikkert identifisert person skal behandles.
 *
 * @param identitet svaret fra `avgjorIdentitet`, og bare et `koblet` et
 * @param registeret månedens registerrad, slått opp på stasjon og nummer
 * @param avtale `ansatt_avtale`, slått opp på REGISTERSTASJONEN
 *
 * KASTER om registerraden ikke finnes. Identiteten kom fra den; er den
 * borte når vi spør igjen, er noe galt i kallstedet, og et stille svar
 * ville sett ut som en person uten sats.
 */
export function avgjorPrisbarhet(
  identitet: Koblet,
  registeret: (stasjonId: string, ansattNr: string) => Registerobservasjon | null,
  avtale: Avtaleoppslag,
  // DEN KOBLEDE VEIEN KAN IKKE PRODUSERE `fastlonn_uten_register`.
  // Returtypen sier det, i stedet for at en kommentar ber om det: en
  // person som HAR en registerrad hører til `fastlonn_klassifisert`,
  // som bærer Easys observasjon. Uten denne utelukkelsen ville
  // kallstedet i `a1.ts` måttet håndtere en gren som aldri kan oppstå,
  // og de to bevisformene ville begynt å gli over i hverandre.
): Exclude<Prisbarhet, { status: 'fastlonn_uten_register' }> {
  const obs = registeret(identitet.registerStasjonId, identitet.lonnsnr)
  if (!obs) {
    throw new Error(
      `Ingen registerrad for ${identitet.lonnsnr} på stasjon `
      + `${identitet.registerStasjonId}. Identiteten kom fra den raden.`,
    )
  }
  if (!MAANED.test(obs.maaned)) {
    throw new Error(`Ugyldig måned «${obs.maaned}». Forventet yyyy-mm.`)
  }

  // 1. MÅNEDENS EGEN UTTALELSE OM MÅNEDEN SLÅR ALT.
  if (obs.betalingsfrekvens === 'maaned') {
    return { status: 'maanedslonn', belop: obs.timesats }
  }

  // 2. STASJONSBUNDET FASTLØNNSVETO.
  //
  // BARE `fastlonn`, ikke `tilkalling`. En tilkallingsvikar får betalt
  // for timene sine — de føres bare utenom Visma-fila. Kostnaden er
  // ekte, og å fjerne den ville gjort lønnskosten for lav. Samme regel
  // som `import/kjerne.ts` alt følger.
  //
  // `null` er ikke fastlønn. Uavklart er et spørsmål, ikke en verdi.
  const rad = avtale(identitet.registerStasjonId, identitet.lonnsnr)
  if (rad?.lonnsform === 'fastlonn') {
    return {
      status: 'fastlonn_klassifisert',
      proveniens: 'ansatt_avtale',
      stasjonId: identitet.registerStasjonId,
      sistSatt: rad.sistSatt,
      anvendtBakover: rad.sistSatt > sisteDag(obs.maaned),
      easyObservasjon: {
        betalingsfrekvens: obs.betalingsfrekvens,
        timesats: obs.timesats,
      },
    }
  }

  // 3. UKJENT ENHET FØR MANGLENDE SATS.
  //
  // Mangler begge, vet vi ikke engang at personen SKAL ha en timesats.
  // Å kalle det `mangler_sats` ville vært en sann setning om noe vi
  // ikke har grunnlag for å påstå.
  if (obs.betalingsfrekvens === null) {
    return { status: 'ukjent_enhet', timesats: obs.timesats }
  }

  // 4. Easy sa EKSPLISITT `Time`, men ga ingen sats.
  if (obs.timesats === null) return { status: 'mangler_sats' }

  // 5. Enhet og tall, begge fra samme måned.
  return {
    status: 'prisbar',
    timesats: obs.timesats,
    kilde: { stasjonId: obs.stasjonId, maaned: obs.maaned },
  }
}

/**
 * Er et UKOBLET nummer eksplisitt klassifisert som fastlønnet her?
 *
 * Denne funksjonen finnes fordi `avgjorPrisbarhet` krever en `Koblet`,
 * og en fastlønnet som ikke står i lønnsfila får aldri en identitet.
 * Gren 2 der inne er dermed strukturelt uoppnåelig for nettopp den
 * personen den er laget for.
 *
 * TRE TING DEN IKKE GJØR, OG DET ER HELE POENGET:
 *
 *   Den utleder ingenting. Bare en eksplisitt `fastlonn` teller. `null`
 *   er uavklart, `timelonn` er et nei, og et manglende oppslag er et
 *   nei. Fravær av registerrad er ALDRI i seg selv fastlønn — det er
 *   den slutningen som ville gjort hvert datahull til gratis arbeid.
 *
 *   Den kobler ikke på navn. Den tar et nummer og en stasjon.
 *
 *   Den kan ikke bære kroner. Returtypen har ikke noe beløpsfelt, og
 *   utfallet den fører til er `forklart`, som heller ikke har det.
 *
 * `null` betyr «ikke klassifisert», og kalleren skal da fortsette til
 * sitt vanlige `upriset`-utfall.
 */
export function fastlonnUtenRegister(
  arbeidsstasjonId: string,
  ansattNr: string,
  maaned: string,
  avtale: Avtaleoppslag,
): Extract<Prisbarhet, { status: 'fastlonn_uten_register' }> | null {
  if (!MAANED.test(maaned)) {
    throw new Error(`Ugyldig måned «${maaned}». Forventet yyyy-mm.`)
  }

  // ARBEIDSSTASJONEN, fordi det ikke finnes noen registerstasjon. Dette
  // er en egen gren, ikke en ny hovedregel: en koblet person slås
  // fortsatt opp på registerstasjonen sin i `avgjorPrisbarhet`.
  const rad = avtale(arbeidsstasjonId, ansattNr)
  if (rad?.lonnsform !== 'fastlonn') return null

  return {
    status: 'fastlonn_uten_register',
    proveniens: 'ansatt_avtale',
    arbeidsstasjonId,
    sistSatt: rad.sistSatt,
    anvendtBakover: rad.sistSatt > sisteDag(maaned),
  }
}
