import { rutineGjelder, skjemaAktiv, type OsloNaa, type Vaktvindu } from '../rutineskjema'

// =====================================================================
// KØEN ER VAKTA HENNES, IKKE DØGNET OG IKKE MÅNEDEN
//
// Nettbrettets kø har vært feil to ganger, og begge gangene var tallet
// riktig regnet — bare på feil spørsmål:
//
//   «123 rutiner igjen»   var periodens tall, tretti dager. Et etterslep
//                         på under 6 % lest som dagens jobb.
//   «67 rutiner igjen»    ville vært døgnets tall, altså alle skiftene.
//                         Sant, men ikke hennes: hun står på morgenvakt
//                         og kan ikke gjøre kveldens rutiner.
//
// Den som holder nettbrettet skal se det hun kan gjøre nå. Alt annet er
// en beskjed om at hun ligger etter noe hun ikke rår over.
//
// ---------------------------------------------------------------------
// HVORFOR DEN BOR HER OG IKKE PÅ SIDA
//
// `/rutiner` regner det samme inne i JSX-en sin. Skrev hjemskjermen sin
// egen kopi, ville kortet og sida sagt to ulike tall om samme jobb — og
// da er vi tilbake til to tall som ser sammenlignbare ut uten å være
// det, som er formen halve dette systemet er bygget for å nekte.
//
// Regelen er ren: gi den skjemaene, rutinene, hva som er gjort, og
// klokka. Den trenger ingen database, og den kan derfor bevises.
// =====================================================================

export type Skift = {
  id: string
  tid_start: string
  tid_slutt: string
  ukedager: number[]
}

export type Rutine = {
  id: string
  skjema_id: string
  ukedager: number[]
  opprettet_dato: string
}

export type Vakt = { skjema: Skift; vindu: Vaktvindu }

/**
 * Vakta man STÅR i nå.
 *
 * KJERNEN VINNER OVER NÅDEN. Overlappen på ±60 minutter gjør at morgen
 * (04–15) og kveld (15–24) begge er «aktive» klokka 15:20. Begge skal
 * være tilgjengelige — den som avslutter dagvakta skal rekke å hake av —
 * men bare én av dem er den man står i, og det er den køen skal telle.
 * Ellers ble Bønes' 36 + 19 til 55 rutiner i én haug.
 *
 * Er ingen i kjernen (altså: vi er bare i nåden rundt en vakt), telles
 * de aktive. Da er nåden alt vi har.
 */
export function vaktenNaa(skjemaer: Skift[], naa: OsloNaa): Vakt[] {
  const aktive = skjemaer
    .map((skjema) => ({ skjema, vindu: skjemaAktiv(skjema, naa) }))
    .filter((v) => v.vindu.aktiv)
  const kjerne = aktive.filter((v) => v.vindu.kjerne)
  return kjerne.length > 0 ? kjerne : aktive
}

export type Skiftkoe = {
  igjen: number
  totalt: number
  /** Datoene utføringene må hentes for — en nattvakt hører til i går. */
  vaktdatoer: string[]
}

/**
 * Hvor mye som gjenstår på vakta.
 *
 * `gjortPerDato` er avhukingene per VAKTDATO, ikke per kalenderdato. En
 * vakt over midnatt hører til dagen den startet, og en avhuking klokka
 * 01 om natta hører til gårsdagens vakt.
 *
 * ET TOMT SKJEMA ER IKKE EN VAKT. Bønes hadde et «morgen»-skjema
 * 06:00–14:00 med null rutiner ved siden av det ekte på 04:00–15:00.
 * Det gjorde ingenting annet enn å telle som en aktiv vakt. Her ville
 * det bare lagt null til null — men det skal ikke kunne dukke opp som en
 * vakt med «0 igjen» heller, så det utelates.
 */
export function skiftkoe(
  vakter: Vakt[],
  rutiner: Rutine[],
  gjortPerDato: Map<string, Set<string>>,
): Skiftkoe {
  let igjen = 0
  let totalt = 0
  const datoer = new Set<string>()

  for (const { skjema, vindu } of vakter) {
    const mine = rutiner
      .filter((r) => r.skjema_id === skjema.id && rutineGjelder(r, vindu))
    if (mine.length === 0) continue
    datoer.add(vindu.vaktdato)
    const gjort = gjortPerDato.get(vindu.vaktdato) ?? new Set<string>()
    totalt += mine.length
    igjen += mine.filter((r) => !gjort.has(r.id)).length
  }

  return { igjen, totalt, vaktdatoer: [...datoer] }
}
