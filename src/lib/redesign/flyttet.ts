// =====================================================================
// Seksjoner som er FLYTTET, ikke tapt.
//
// Vakthunden feller når en seksjon forsvinner fra en rute, og den skal
// fortsette å gjøre det. Men en seksjon som er flyttet til en annen rute
// ser nøyaktig ut som en som er slettet — begge er borte fra der de sto.
// Uten et sted å si forskjellen har man to dårlige valg: slå av vakten,
// eller aldri flytte noe.
//
// Derfor denne fila. Å stå her er ikke et fritak. Det er en PÅSTAND som
// `vakthund.test.ts` prøver å motbevise, med fem krav per rad:
//
//   1. borte fra `fra`          ellers er den ikke flyttet
//   2. finnes på `til`          ellers er den tapt
//   3. samme capability         komponenten som rendrer den skal ha
//                               fulgt med, ikke bli skrevet på nytt
//   4. samme rolle              den som så den før, skal se den nå
//   5. navigerbar               `til` skal være lenket fra `naaddFra`
//
// Slutter én av dem å holde, feller vakten på DENNE fila i stedet — og
// da er erklæringen selv beviset som brast. En rad som ikke lenger
// stemmer skal fjernes, ikke oppdateres til å passe.
// =====================================================================

export type Flytting = {
  /** Seksjonsnavnet slik `seksjoner()` leser det ut av kilden. */
  seksjon: string
  fra: string
  til: string
  /** Ruta som skal lenke til `til`. Uten en vei er flyttingen et tap. */
  naaddFra: string
  /** Komponenten som bærer capabilityen. Skal finnes i `til` sitt tre. */
  komponent: string
  hvorfor: string
}

/**
 * Bølge 5: økonomi og engasjement ut av «I dag».
 *
 * Nettbrettets hjem svarer på ett spørsmål — hva skal jeg gjøre nå. Fire
 * blokker svarte på et annet: hvordan ligger butikken an. De sto under
 * køen, på flata som står åpen hele skiftet, og gjorde den til tolv
 * blokker der tre av dem krevde noe av henne.
 *
 * De er ikke fjernet. De er samlet på `/vaar-stasjon`, som nås med én rad
 * fra «I dag» — og den raden er punkt 5 i beviset over.
 *
 * SKILLS-SCORE STÅR IKKE HER, og det er ikke en forglemmelse: den
 * rendres i et `<span>`, ikke en overskrift, så `seksjoner()` teller den
 * ikke som en seksjon. Den flyttet med de andre. Vakten kan bare bevise
 * det den kan se, og skal ikke påstå mer.
 */
export const FLYTTEDE_SEKSJONER: Flytting[] = [
  {
    seksjon: "t('Vår premiesaldo')",
    fra: '/oversikt',
    til: '/vaar-stasjon',
    naaddFra: '/oversikt',
    komponent: 'premie-saldo',
    hvorfor: 'Kroner. Nivå 1 på nettbrettet skal ikke vise økonomi.',
  },
  {
    seksjon: "t('Vekst mot i fjor')",
    fra: '/oversikt',
    til: '/vaar-stasjon',
    naaddFra: '/oversikt',
    komponent: 'VekstKort',
    hvorfor: 'Omsetning mot fjoråret er analyse, ikke dagens arbeid.',
  },
  {
    seksjon: 'Måling',
    fra: '/oversikt',
    til: '/vaar-stasjon',
    naaddFra: '/oversikt',
    komponent: 'MalekortTablet',
    hvorfor: 'Rangering mot andre butikker svarer på «hvordan ligger vi an».',
  },
]

/**
 * Seksjoner som har byttet NAVN på samme rute.
 *
 * Et eget slag, og verdt å skille fra en flytting: seksjonen står der
 * den alltid har stått, men uttrykket vakten leser navnet ut av er
 * skrevet om. Vakten ser en borte og en ny, og kan ikke vite at det er
 * den samme.
 *
 * Kravet her er strengere enn for en flytting: `til` skal finnes på
 * SAMME rute, i samme kjøring. Er den ikke det, er dette ikke en
 * omskriving — det er et tap med en pen forklaring.
 */
export type Omskriving = {
  fra: string
  til: string
  rute: string
  hvorfor: string
}

export const OMSKREVNE_SEKSJONER: Omskriving[] = [
  {
    fra: "dynamisk:t(overskrift(alle.length))",
    til: 'dynamisk:tittel',
    rute: '/oversikt',
    hvorfor:
      'Køens overskrift kunne ikke oversettes så lenge tallet lå inne i '
      + 'frasen: «4 ting igjen» finnes ikke i noen ordliste, og kan ikke '
      + 'finnes, fordi det er én variant per tall. Nå setter overskrift() '
      + 'den sammen med t() inni seg, og uttrykket har fått et navn '
      + 'vakten kan lese.',
  },
]
