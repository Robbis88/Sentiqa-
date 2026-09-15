// =====================================================================
// DEKNING: HVA SOM FAKTISK VAR KOMMET INN DA BILDET BLE BYGGET
// =====================================================================
//
// `byggOkonomibilde` tar `Dekning` ferdig inn — den kan ikke telle
// selv, fordi `bildevakt.test.ts` feller all aritmetikk i den fila. En
// kalenderlengde er ikke sammenstillerens jobb.
//
// Her er den jobben.
//
// ---------------------------------------------------------------------
// «AV» ER IKKE MÅNEDENS LENGDE I EN MÅNED SOM IKKE ER OVER
// ---------------------------------------------------------------------
//
// Den 8. september har måneden 30 dager, men bare 7 av dem KAN ha
// salgstall — dagens fil kommer i morgen. Måler vi 7 av 30, står den
// inneværende måneden som 77 % mangelfull hver eneste dag, og det er
// nettopp den måneden hele lønnsrommet er bygget for.
//
// En melding som alltid står, leses ikke. Så nevneren er dagene som
// KUNNE vært der, ikke dagene måneden har.
//
// ---------------------------------------------------------------------
// RETNINGEN PÅ FEILEN, OG HVA VI FAKTISK KAN VITE
// ---------------------------------------------------------------------
//
// Både manglende salgsdager og manglende bilvaskuker gjør anslaget for
// LAVT: omsetningen som skalerer BP-bruttoen blir for liten, og
// bilvaskbidraget legges bare på når uka er registrert.
//
// `for_hoyt` er med i typen fra E3, men INGEN av dagens innganger
// produserer den. Det står her i klartekst i stedet for å bli gjettet:
// en retning vi ikke kan begrunne, skal være `ukjent`. Å oppgi en
// retning vi ikke vet, er verre enn å la være — flaten skriver en hel
// setning på grunnlag av den.
// =====================================================================

import type { Dekning } from './bilde'

/** Antall dager i `yyyy-mm`. */
function dagerIMaaned(maaned: string): number {
  const [ar, mnd] = maaned.split('-').map(Number)
  return new Date(Date.UTC(ar, mnd, 0)).getUTCDate()
}

/**
 * Hvor mange dager i måneden som KAN ha salgstall.
 *
 * For en måned som er over: alle. For den inneværende: fram til i går,
 * fordi dagens salgsfil ikke er kommet ennå. For en måned fram i tid:
 * null — der finnes ingenting å mangle.
 *
 * `naa` er et argument og ikke `new Date()` inne i funksjonen: en regel
 * som leser klokka selv kan ikke prøves, og da måtte testen enten
 * hoppe over grensetilfellene eller fryse tiden globalt.
 */
export function muligeSalgsdager(maaned: string, naa: Date): number {
  const denne = naa.toISOString().slice(0, 7)
  if (maaned < denne) return dagerIMaaned(maaned)
  if (maaned > denne) return 0
  // I GÅR, IKKE I DAG. Dagens fil kommer i morgen, så å telle i dag
  // ville gjort hver måned mangelfull med nøyaktig én dag, bestandig.
  return Math.max(0, naa.getUTCDate() - 1)
}

/** ISO-uke og -år for en dato. Mandag er dag 1; uke 1 eier 4. januar. */
function isoUke(d: Date): { ar: number; uke: number } {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))
  const dag = t.getUTCDay() === 0 ? 7 : t.getUTCDay()
  t.setUTCDate(t.getUTCDate() + 4 - dag)
  const ar = t.getUTCFullYear()
  const nyttaar = new Date(Date.UTC(ar, 0, 1))
  const uke = Math.ceil(((t.getTime() - nyttaar.getTime()) / 86400000 + 1) / 7)
  return { ar, uke }
}

/**
 * Hvor mange bilvaskuker måneden burde hatt rapport for.
 *
 * =====================================================================
 * EN UKE ER IKKE VENTET FØR DEN ER OVER
 * =====================================================================
 *
 * Bilvaskrapporten kommer per uke, etter uka. Teller vi den
 * inneværende uka som forventet, står det en mangel der hver eneste
 * dag fram til søndag — og en melding som alltid står, leses ikke.
 *
 * Så bare uker som er AVSLUTTET teller: siste dag i uka må være i går
 * eller før. Samme grense som `muligeSalgsdager`, og av samme grunn.
 */
export function forventedeBilvaskUker(maaned: string, naa: Date): number {
  return avslutteteUkerIMaaned(maaned, naa).size
}

/**
 * Ukenøklene (`år-uke`) måneden venter rapport for.
 *
 * SAMME SETT SOM TELLES, IKKE ET PARALLELT. Kallstedet må kunne avgjøre
 * hvilke av de REGISTRERTE ukene som hører til måneden, og gjorde det
 * med sin egen regel, ville teller og nevner målt to forskjellige ting
 * — og en måned kunne fått flere uker enn den ventet.
 */
export function avslutteteUkerIMaaned(maaned: string, naa: Date): Set<string> {
  const [ar, mnd] = maaned.split('-').map(Number)
  const sisteDag = new Date(Date.UTC(ar, mnd, 0)).getUTCDate()
  // I GÅR er siste dag vi kan kreve noe for. Se `muligeSalgsdager`.
  const igaar = new Date(Date.UTC(
    naa.getUTCFullYear(), naa.getUTCMonth(), naa.getUTCDate() - 1,
  ))

  const uker = new Set<string>()
  for (let dag = 1; dag <= sisteDag; dag++) {
    const d = new Date(Date.UTC(ar, mnd - 1, dag))
    // Uka må være AVSLUTTET: søndagen i den må ligge på eller før i går.
    const isoDag = d.getUTCDay() === 0 ? 7 : d.getUTCDay()
    const sondag = new Date(d)
    sondag.setUTCDate(d.getUTCDate() + (7 - isoDag))
    if (sondag.getTime() > igaar.getTime()) continue
    const { ar: uAr, uke } = isoUke(d)
    uker.add(`${uAr}-${uke}`)
  }
  return uker
}

export type Dekningsinput = {
  maaned: string
  /** Distinkte datoer med butikksalg i måneden, fra `v_butikksalg_dag`. */
  salgsdagerHar: number
  /** Bilvaskuker registrert for måneden. */
  bilvaskUkerHar: number
  /** Bilvaskuker måneden burde hatt. Null når vi ikke kan si det. */
  bilvaskUkerAv: number | null
  /** Har easy@work-fila landet for måneden? */
  lonnsfil: boolean
  /** Er måneden avlagt i regnskapet? */
  regnskap: boolean
  naa: Date
}

/**
 * Hva som var kommet inn, og hva det gjør med anslaget.
 *
 * EN AVLAGT MÅNED HAR INGEN MANGLER som betyr noe for tallet.
 * Regnskapet er fasit; at en salgsfil manglet i juli endrer ikke hva
 * juli ble. Uten dette ville hver avlagt måned båret en advarsel om et
 * anslag som for lengst er erstattet.
 */
export function byggDekning(inn: Dekningsinput): Dekning {
  const avSalg = muligeSalgsdager(inn.maaned, inn.naa)
  const manglerSalg = Math.max(0, avSalg - inn.salgsdagerHar)
  const manglerVask = inn.bilvaskUkerAv === null
    ? 0
    : Math.max(0, inn.bilvaskUkerAv - inn.bilvaskUkerHar)

  const mangler: string[] = []
  // AVLAGT MÅNED: ingen mangler oppgis. Se funksjonskommentaren.
  if (!inn.regnskap) {
    if (manglerSalg > 0) {
      mangler.push(manglerSalg === 1 ? '1 salgsdag' : `${manglerSalg} salgsdager`)
    }
    if (manglerVask > 0) {
      mangler.push(manglerVask === 1 ? '1 bilvaskuke' : `${manglerVask} bilvaskuker`)
    }
  }

  return {
    salgsdager: { har: inn.salgsdagerHar, av: avSalg },
    bilvaskUker: { har: inn.bilvaskUkerHar, av: inn.bilvaskUkerAv ?? inn.bilvaskUkerHar },
    lonnsfil: inn.lonnsfil,
    regnskap: inn.regnskap,
    mangler,
    // BEGGE MANGLENE PEKER SAMME VEI. Se toppkommentaren om hvorfor
    // `for_hoyt` ikke settes her.
    retningPaaFeil: mangler.length > 0 ? 'for_lavt' : 'ukjent',
  }
}
