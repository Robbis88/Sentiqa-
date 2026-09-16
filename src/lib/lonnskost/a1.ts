// A1: estimert konto 503 per faktisk arbeidssted.
//
// =====================================================================
// HER MOETES DE FIRE KONTRAKTENE. INGEN AV DEM SVEKKES.
//
//   kilder.ts       har stasjonsmaaneden begge Easy-kildene?
//   identitet.ts    hvem er personen bak nummeret?
//   prisbarhet.ts   kan personen timeprises denne maaneden?
//   tilleggs*.ts    hvilke arter en vakt utloeser, og hva de koster
//
// Denne fila kobler dem. Den finner ikke opp en eneste regel.
//
// ---------------------------------------------------------------------
// `beregnArbeidssted` STAAR UROERT
//
// Den gamle motoren baerer maalingen paa -0,402 % over fem
// kontrollmaaneder og har en annen inngangsform (`Basisstempling[]` +
// `Prisregister[]`). Aa bygge om den samtidig som vi kobler en ny
// produksjonskjede ville gjort begge endringene umulige aa vurdere hver
// for seg. Den beholdes som maale- og regresjonsanker.
//
// Noeyaktigheten arves av at `fordelVakt` og `belopFor` er UENDRET - det
// er de som baerer tallet, ikke rammen rundt.
//
// ---------------------------------------------------------------------
// TRE NIVAAER, OG DE DELER IKKE FELTNAVN
//
//   kildemangel   ingen kroner i det hele tatt. Ikke 0, ikke "minimum 0"
//   komplett      `konto503Kr`
//   minimum       `minimum503Kr` + eksplisitt upriset arbeid
//
// At kostnadsfeltet HETER noe forskjellig er ikke pynt: en flate kan
// ikke lese et minimum som om det var komplett ved et uhell.
//
// ---------------------------------------------------------------------
// BEVARING AV BETALTE MINUTTER
//
// Hver `Arbeidsrad` ender i NOEYAKTIG ETT `Radutfall`. Da er
//
//   betalteMinutter = prisede + forklarte + uprisede
//
// sant VED KONSTRUKSJON, ikke ved disiplin - et minutt kan ikke falle ut
// av pipelinen, bare havne i feil boette. Ubetalte staar for seg.
//
// Maalt paa Boenes august 2026: 41 926 = 36 362 + 1 484 + 4 080.
//
// Invariantet sjekkes likevel i kjoeretid og KASTER. Den sjekken kan i
// teorien ikke utloeses - og den staar der fordi det er nettopp den
// slags "kan ikke skje" som skjer etter en refaktorering. Et tapt minutt
// pynter tallet, og et pent tall er det farligste vi kan produsere.
//
// ---------------------------------------------------------------------
// TO FORBEHOLD SOM ALLTID FOELGER TALLET
//
// De er MODELLBEGRENSNINGER, ikke mangler i den aktuelle beregningen.
// Derfor gjoer de ikke maaneden `minimum`: gjorde de det, ville ingen
// maaned noen gang vaert komplett, og skillet ville sluttet aa bety noe.
//
//   OVERTID   Basis Export sier ikke hvilke timer som er overtid.
//             Art 96 ser ut til aa vaere "timer over 10 paa en dag" - 6
//             av 8 observasjoner - men 6 av 8 er ikke en regel. Art 97
//             avhenger av PLANLAGT vakt, som Basis Export ikke har.
//
//   1410      Regelen er maalt paa fem helligdager i Dale mai 2026 og
//             paa pinseaften fra kl. 15. De oevrige seks dagene i lista
//             foelger norsk lov, ikke en maaling. Paaskeaften, julaften
//             og nyttaarsaften utloeser IKKE 1410 i dag - er det feil,
//             er A1 for lav i april og desember.
//
// `komplett` betyr komplett FOR A1-KONTRAKTEN. Det betyr ikke lik Easys
// kronefil, og de to skal aldri forveksles.
// =====================================================================

import type { Arbeidsrad } from './arbeidstid'
import type { Kilder, MedBeggeKilder, Registerrad } from './kilder'
import { avgjorIdentitet, type Identitet } from './identitet'
import {
  avgjorPrisbarhet,
  type Avtaleoppslag, type Prisbarhet, type Registerobservasjon,
} from './prisbarhet'
import { fordelVakt, TIMEART } from '@/lib/lonn/tilleggsfordeling'
import { belopFor } from '@/lib/lonn/tilleggssats'

export type Artsum = { timer: number; belopKr: number }

/** Hvorfor kjent arbeid ikke lot seg prise. Uttoemmende mot dagens typer. */
export type Uprisetgrunn =
  | 'ukjent_nummer'
  | 'motstrid_navn'
  | 'motstrid_kollisjon'
  | 'motstrid_bro'
  | 'mangler_sats'
  | 'ukjent_enhet'
  | 'avvist_rad'
  | 'flere_lokasjoner'
  | 'dublett'

/**
 * Hva som skjedde med ÉN arbeidstidsrad.
 *
 * De fire er gjensidig utelukkende, og en `Vurdertrad` kan ikke
 * konstrueres uten et utfall. Det er det som gjoer bevaringen sann.
 */
export type Radutfall =
  | {
    slag: 'priset'
    timesats: number
    belopKr: number
    perArt: Record<string, Artsum>
    /** Satsen kom fra en annen stasjon enn arbeidsstedet. */
    innlaant: boolean
  }
  | {
    slag: 'forklart'
    grunn: 'maanedslonn' | 'fastlonn_klassifisert'
    prisbarhet: Prisbarhet
  }
  | { slag: 'upriset'; grunn: Uprisetgrunn; forklaring: string }
  | { slag: 'ubetalt' }

export type Vurdertrad = { rad: Arbeidsrad; utfall: Radutfall }

export type Personresultat = {
  ansattNr: string
  /** Navnet slik BASIS EXPORT skrev det. Ikke registerets. */
  navn: string
  identitet: Identitet
  /** `null` naar identiteten ikke er koblet - da ble prisbarhet aldri spurt. */
  prisbarhet: Prisbarhet | null
  betalteMinutter: number
  prisedeMinutter: number
  forklarteMinutter: number
  uprisedeMinutter: number
  ubetalteMinutter: number
  belopKr: number
  perArt: Record<string, Artsum>
  innlaant: boolean
}

export type Upriset = {
  ansattNr: string
  navn: string
  grunn: Uprisetgrunn
  minutter: number
  forklaring: string
}

type Felles = {
  stasjonId: string
  maaned: string
  /** Revisjonskjeden: hver eneste rad, med sitt utfall. */
  rader: Vurdertrad[]
  personer: Personresultat[]
  betalteMinutter: number
  prisedeMinutter: number
  forklarteMinutter: number
  uprisedeMinutter: number
  ubetalteMinutter: number
  perArt: Record<string, Artsum>
  /** Delmengde av 503-beloepet. ALDRI noe som legges oppaa. */
  innlaantKr: number
  innlaanteNr: string[]
  /**
   * Rader som kollapset paa kildens egen identitet.
   *
   * `basisvakt` har allerede `unique (stasjon_id, kilde_maaned, ansatt_nr,
   * fra_dato, fra_tid, til_tid, betalt)`, og vi leser én stasjonsmaaned.
   * Tallet skal derfor vaere 0, og er det et funn hvis det ikke er det.
   */
  dubletter: number
  /** Distinkte arbeidssteder radene oppgir. Skal vaere nøyaktig ett. */
  lokasjoner: string[]
  /** Modellbegrensninger som foelger tallet ut. Gjoer ikke maaneden minimum. */
  forbehold: string[]
}

export type A1Beregning =
  | (Felles & { status: 'komplett'; konto503Kr: number })
  | (Felles & { status: 'minimum'; minimum503Kr: number; upriset: Upriset[] })

export type A1Resultat =
  | {
    status: 'kildemangel'
    stasjonId: string
    maaned: string
    kilde: Exclude<Kilder, { status: 'begge' }>
  }
  | A1Beregning

const OVERTIDSFORBEHOLD =
  'Overtid (lønnsart 96 og 97) inngår ikke. Basis Export sier ikke hvilke '
  + 'timer som er overtid, og art 97 avhenger av planlagt vakt som fila ikke '
  + 'har. Et avvik mot easy@works kronefil kan skyldes dette.'

const HELLIGDAGSFORBEHOLD =
  'Helligdagstillegget (1410) er målt mot easy@work på fem helligdager i mai '
  + '2026 og på pinseaften fra kl. 15. De øvrige seks helligdagene følger '
  + 'norsk lov, ikke en måling. Påskeaften, julaften og nyttårsaften utløser '
  + 'ikke 1410 i dag — er det feil, er tallet for lavt i april og desember.'

/** Samme avrunding som `arbeidssted.ts`. Se hodet i `beregnA1`. */
const rund = (n: number): number => Math.round(n * 100) / 100

const leggTil = (mål: Record<string, Artsum>, art: string, timer: number, kr: number) => {
  const f = mål[art] ?? { timer: 0, belopKr: 0 }
  f.timer = rund(f.timer + timer)
  f.belopKr = rund(f.belopKr + kr)
  mål[art] = f
}

const UPRISET_TEKST: Record<Uprisetgrunn, string> = {
  ukjent_nummer: 'Nummeret finnes ikke i registeret for måneden.',
  motstrid_navn: 'Registeret og Basis Export sier ulike navn om nummeret.',
  motstrid_kollisjon: 'Nummeret finnes i to stasjoners register samme måned.',
  motstrid_bro: 'Både nummeret og nummerbroas mål finnes i registeret.',
  mangler_sats: 'easy@work sa «Time», men oppga ingen sats.',
  ukjent_enhet: 'easy@work oppga hverken «Time» eller «Måned». Enheten er ukjent.',
  avvist_rad: 'Vakten lot seg ikke lese av parseren og er ikke prisbar.',
  flere_lokasjoner: 'Stasjonsmåneden oppgir flere arbeidssteder. Kronene kan '
    + 'ikke plasseres sikkert.',
  dublett: 'Raden har samme identitet som en tidligere rad — samme ansatt, '
    + 'fra-dato, klokkeslett og betaltstatus. `basisvakt` sin egen UNIQUE '
    + 'utelukker det, så kilden har brutt sin kontrakt. Timene telles, men '
    + 'prises ikke på nytt.',
}

/**
 * Beregner A1 for én stasjonsmåned som HAR begge kildene.
 *
 * Signaturen er `MedBeggeKilder`, ikke `Kilder`. Da er «503 = 0 fordi
 * kilden manglet» ikke en tilstand noen kan skrive ved et uhell.
 *
 * ---------------------------------------------------------------------
 * AVRUNDINGEN ER REPLIKERT, IKKE FORBEDRET
 *
 * `belopFor` runder til øre per (art, rad), og akkumulatoren runder til
 * to desimaler per steg. Det er ikke optimalt — å summere avrundede tall
 * driver — men det er nøyaktig slik −0,402 % ble målt. Å endre den mens
 * vi kobler ville gjort målingen usammenlignbar. En senere port kan måle
 * sluttavrunding mot den, med bevis.
 */
export function beregnA1(
  kilder: MedBeggeKilder,
  avtale: Avtaleoppslag,
): A1Beregning {
  const { stasjonId, maaned, arbeidstid, register } = kilder

  // Kandidatene: stasjonens egne PLUSS kryssradene. Det er hele
  // registeret motoren har lov til å se, og `avgjorIdentitet` avgjør
  // resten.
  const kandidater = [...register.egne, ...register.kryss]
  const slaaOpp = (nr: string) => kandidater.filter((r) => r.ansattNr === nr)

  // MÅNEDEN KOMMER FRA DEN GATEDE REGISTERMÅNEDEN, ikke fra noe annet.
  // Det er her — og bare her — en julisats kunne priset august.
  const somObservasjon = (r: Registerrad): Registerobservasjon => ({
    stasjonId: r.stasjonId,
    ansattNr: r.ansattNr,
    maaned: register.maaned,
    timesats: r.timesats,
    betalingsfrekvens: r.betalingsfrekvens,
  })
  const registeret = (sId: string, nr: string): Registerobservasjon | null => {
    const t = kandidater.find((r) => r.stasjonId === sId && r.ansattNr === nr)
    return t ? somObservasjon(t) : null
  }

  // ETT ARBEIDSSTED, ELLERS INGEN PRISING.
  //
  // `lagreBasisvakt` krever én entydig stasjon per fil, og alle åtte
  // kontrollfilene har nøyaktig én lokasjon. Dukker det opp to, vet vi
  // ikke hvor kronene hører hjemme — og da priser vi ingen av dem.
  const lokasjoner = [...new Set(
    arbeidstid.rader.map((r) => r.lokasjon.trim()).filter(Boolean),
  )].sort()
  const flereLokasjoner = lokasjoner.length > 1

  // DUBLETTIDENTITETEN ER KILDENS EGEN, lest av `0219`:
  // unique (stasjon_id, kilde_maaned, ansatt_nr, fra_dato, fra_tid,
  //         til_tid, betalt). Vi står allerede inne i én (stasjon, måned).
  //
  // `dato` er IKKE med — forretningsdatoen deltar ikke i identiteten.
  // Den gamle motorens smalere nøkkel manglet `til_tid` og `betalt` og
  // ville kollapset både den ekte dobbeltstemplingen på Bønes 1009 og et
  // betalt/ubetalt-par.
  const sett = new Set<string>()
  let dubletter = 0

  const vurderte: Vurdertrad[] = []
  // Identiteten og prisbarheten regnes der de avgjoeres, og noteres for
  // personen FOERSTE gang. Foerste utgave regnet dem om igjen i en andre
  // loekke og brukte `ukoblet` som sentinel - to steder som kan skille
  // lag, og en tilstand som betyr to ting.
  const personIdentitet = new Map<string, Identitet>()
  const personPrisbarhet = new Map<string, Prisbarhet>()
  const noter = (nr: string, i: Identitet, pb?: Prisbarhet) => {
    if (!personIdentitet.has(nr)) personIdentitet.set(nr, i)
    if (pb && !personPrisbarhet.has(nr)) personPrisbarhet.set(nr, pb)
  }

  for (const rad of arbeidstid.rader) {
    const unik = [
      rad.ansattNr, rad.fraDato, rad.fraTid, rad.tilTid, String(rad.betalt),
    ].join('|')
    const upriset = (grunn: Uprisetgrunn, forklaring?: string): Vurdertrad => ({
      rad,
      utfall: { slag: 'upriset', grunn, forklaring: forklaring ?? UPRISET_TEKST[grunn] },
    })

    // EN DUBLETT ER KJENT ARBEID VI NEKTER AA PRISE, ikke en rad som
    // forsvinner.
    //
    // Foerste utgave gjorde `dubletter++; continue`. Da ble raden aldri
    // en `Vurdertrad`, revisjonskjeden kunne ikke peke paa den, og
    // maaneden kunne fortsatt melde seg som `komplett` selv om kilden
    // hadde brutt sin egen UNIQUE. Bevaringen holdt - men over et
    // datasett motoren stilltiende hadde krympet. Det er nettopp den
    // formen vi bygger for aa unngaa.
    //
    // Den ORIGINALE raden beholdes. Ingen syntetisk erstatning, ingen
    // reduksjon til bare minutter: revisjonskjeden skal kunne vise
    // foerste observasjon som priset og den andre som dublett.
    //
    // ---------------------------------------------------------------
    // TO AKSER, OG DE BLANDES IKKE
    //
    // `dubletter` teller BRUDD PAA KILDENS RADIDENTITET - et
    // dataintegritetsfunn, uansett om raden er betalt.
    //
    // `Radutfall` foelger radens OEKONOMISKE status. En UBETALT dublett
    // er ingen oekonomisk usikkerhet i 503: det er ikke arbeid vi
    // skulle priset. Den blir derfor `ubetalt`, ikke `upriset`.
    //
    // Foerste utgave av denne rettelsen gjorde den til `upriset`
    // uansett. Da ble en ubetalt dublett talt som BETALT arbeid, og den
    // eksterne bevaringsvakten kastet - hele stasjonsmaaneden ble en
    // exception i stedet for det `minimum`-resultatet hele B2d er
    // bygget for. Funnet av Vercel Agent Review paa cb8fdfc, og
    // reprodusert foer det ble rettet.
    //
    // Vakten gjorde jobben sin. Feilen laa i klassifiseringen FOER
    // aggregeringen, og det er der den er rettet.
    if (sett.has(unik)) {
      dubletter++
      vurderte.push(rad.betalt
        ? upriset('dublett')
        : { rad, utfall: { slag: 'ubetalt' } })
      continue
    }
    sett.add(unik)

    if (!rad.betalt) {
      vurderte.push({ rad, utfall: { slag: 'ubetalt' } })
      continue
    }

    if (flereLokasjoner) { vurderte.push(upriset('flere_lokasjoner')); continue }
    if (rad.avvikGrunn !== null) { vurderte.push(upriset('avvist_rad')); continue }

    // IDENTITET FØR PRISBARHET. `avgjorPrisbarhet` tar `Koblet`, så en
    // motstrid KAN IKKE nå prisberegningen.
    const identitet = avgjorIdentitet(
      { ansattNr: rad.ansattNr, ansattNavn: rad.ansattNavn },
      slaaOpp,
    )
    noter(rad.ansattNr, identitet)
    if (identitet.status === 'ukoblet') {
      vurderte.push(upriset('ukjent_nummer')); continue
    }
    if (identitet.status === 'motstrid') {
      const grunn: Uprisetgrunn = identitet.grunn === 'navn'
        ? 'motstrid_navn'
        : identitet.grunn === 'kollisjon' ? 'motstrid_kollisjon' : 'motstrid_bro'
      vurderte.push(upriset(grunn, identitet.forklaring)); continue
    }

    const prisbarhet = avgjorPrisbarhet(identitet, registeret, avtale)
    noter(rad.ansattNr, identitet, prisbarhet)

    if (prisbarhet.status === 'maanedslonn' || prisbarhet.status === 'fastlonn_klassifisert') {
      // FORKLART, IKKE NULL KRONER. Timene telles og årsaken følger med;
      // de bidrar bare ikke til den TIMEBEREGNEDE 503-komponenten.
      vurderte.push({
        rad,
        utfall: { slag: 'forklart', grunn: prisbarhet.status, prisbarhet },
      })
      continue
    }
    if (prisbarhet.status === 'mangler_sats') {
      vurderte.push(upriset('mangler_sats')); continue
    }
    if (prisbarhet.status === 'ukjent_enhet') {
      vurderte.push(upriset('ukjent_enhet')); continue
    }

    // PRISBAR. `fraDato`, ikke `dato`: en vakt som starter 1. august men
    // føres på 31. juli skal ha mandagens satser.
    const perArt: Record<string, Artsum> = {}
    let belopKr = 0
    for (const [art, timer] of fordelVakt(rad.fraDato, rad.fraTid, rad.minutter)) {
      const kr = belopFor(art, timer, prisbarhet.timesats)
      belopKr = rund(belopKr + kr)
      leggTil(perArt, art, timer, kr)
    }
    vurderte.push({
      rad,
      utfall: {
        slag: 'priset',
        timesats: prisbarhet.timesats,
        belopKr,
        perArt,
        innlaant: identitet.registerStasjonId !== stasjonId,
      },
    })
  }

  // ------------------------------------------------------------ SUMMER
  let betalteMinutter = 0
  let prisedeMinutter = 0
  let forklarteMinutter = 0
  let uprisedeMinutter = 0
  let ubetalteMinutter = 0
  let belop = 0
  let innlaantKr = 0
  const perArt: Record<string, Artsum> = {}
  const innlaanteNr = new Set<string>()
  const upriset: Upriset[] = []
  const perPerson = new Map<string, Personresultat>()

  for (const { rad, utfall } of vurderte) {
    const p = perPerson.get(rad.ansattNr) ?? {
      ansattNr: rad.ansattNr,
      navn: rad.ansattNavn,
      identitet: personIdentitet.get(rad.ansattNr)
        ?? { status: 'ukoblet', grunn: 'ukjent_nummer' },
      prisbarhet: personPrisbarhet.get(rad.ansattNr) ?? null,
      betalteMinutter: 0,
      prisedeMinutter: 0,
      forklarteMinutter: 0,
      uprisedeMinutter: 0,
      ubetalteMinutter: 0,
      belopKr: 0,
      perArt: {},
      innlaant: false,
    }
    perPerson.set(rad.ansattNr, p)

    if (utfall.slag === 'ubetalt') {
      ubetalteMinutter += rad.minutter
      p.ubetalteMinutter += rad.minutter
      continue
    }

    betalteMinutter += rad.minutter
    p.betalteMinutter += rad.minutter

    if (utfall.slag === 'priset') {
      prisedeMinutter += rad.minutter
      p.prisedeMinutter += rad.minutter
      belop = rund(belop + utfall.belopKr)
      p.belopKr = rund(p.belopKr + utfall.belopKr)
      for (const [art, sum] of Object.entries(utfall.perArt)) {
        leggTil(perArt, art, sum.timer, sum.belopKr)
        leggTil(p.perArt, art, sum.timer, sum.belopKr)
      }
      if (utfall.innlaant) {
        // DELMENGDE, ALDRI TILLEGG.
        innlaantKr = rund(innlaantKr + utfall.belopKr)
        innlaanteNr.add(rad.ansattNr)
        p.innlaant = true
      }
    } else if (utfall.slag === 'forklart') {
      forklarteMinutter += rad.minutter
      p.forklarteMinutter += rad.minutter
    } else {
      uprisedeMinutter += rad.minutter
      p.uprisedeMinutter += rad.minutter
      const f = upriset.find((u) => u.ansattNr === rad.ansattNr && u.grunn === utfall.grunn)
      if (f) f.minutter += rad.minutter
      else upriset.push({
        ansattNr: rad.ansattNr,
        navn: rad.ansattNavn,
        grunn: utfall.grunn,
        minutter: rad.minutter,
        forklaring: utfall.forklaring,
      })
    }
  }

  // BEVARINGEN. Kan i teorien ikke feile - og står her fordi det er
  // nettopp den slags som skjer etter en refaktorering. Et tapt minutt
  // pynter tallet.
  // KILDEN EIER UNIVERSET, IKKE MOTOREN.
  //
  // Det interne invariantet under beviser at ingenting forsvant MELLOM
  // boettene. Denne beviser at boettene til sammen dekker det leseren
  // faktisk leverte - motoren faar ikke selv definere mengden den
  // deretter beviser at den har bevart.
  if (betalteMinutter !== arbeidstid.betalteMinutter) {
    throw new Error(
      `A1 mistet minutter foer fordelingen: kilden ga `
      + `${arbeidstid.betalteMinutter} betalte minutter, motoren saa `
      + `${betalteMinutter} paa ${stasjonId} ${maaned}.`,
    )
  }

  const gjortRede = prisedeMinutter + forklarteMinutter + uprisedeMinutter
  if (gjortRede !== betalteMinutter) {
    throw new Error(
      `A1 mistet minutter: ${betalteMinutter} betalte, men ${gjortRede} gjort `
      + `rede for (${prisedeMinutter} prisede, ${forklarteMinutter} forklarte, `
      + `${uprisedeMinutter} uprisede) på ${stasjonId} ${maaned}.`,
    )
  }

  const felles: Felles = {
    stasjonId,
    maaned,
    rader: vurderte,
    personer: [...perPerson.values()].sort((a, b) => b.betalteMinutter - a.betalteMinutter),
    betalteMinutter,
    prisedeMinutter,
    forklarteMinutter,
    uprisedeMinutter,
    ubetalteMinutter,
    perArt,
    innlaantKr,
    innlaanteNr: [...innlaanteNr].sort(),
    dubletter,
    lokasjoner,
    forbehold: [OVERTIDSFORBEHOLD, HELLIGDAGSFORBEHOLD],
  }

  // `minimum` er reservert for KJENT ARBEID I DENNE BEREGNINGEN som ikke
  // lot seg prise eller forklare. Modellbegrensningene over gjør den
  // aldri minimum - gjorde de det, ville ingen måned noen gang vært
  // komplett, og skillet ville sluttet å bety noe.
  if (uprisedeMinutter > 0) {
    return {
      ...felles,
      status: 'minimum',
      minimum503Kr: belop,
      upriset: upriset.sort((a, b) => b.minutter - a.minutter),
    }
  }
  return { ...felles, status: 'komplett', konto503Kr: belop }
}

/**
 * A1 for én stasjonsmåned, uansett kildetilstand.
 *
 * Mangler en kilde, finnes det ikke noe kostnadsresultat - ikke `0 kr`,
 * ikke «minimum 0», ingen kostnadsrad. `kildemangel` bærer ingen
 * kronefelter i det hele tatt.
 */
export function a1ForStasjonsmaaned(
  kilder: Kilder,
  avtale: Avtaleoppslag,
): A1Resultat {
  if (kilder.status !== 'begge') {
    return {
      status: 'kildemangel',
      stasjonId: kilder.stasjonId,
      maaned: kilder.maaned,
      kilde: kilder,
    }
  }
  return beregnA1(kilder, avtale)
}

/** Lønnsarten som bærer selve timene. Tilleggene teller de samme på nytt. */
export { TIMEART }
