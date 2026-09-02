// =====================================================================
// Hva mangler før systemet kan gjøre jobben sin?
//
// En ny retailer skal komme i gang selv. Det vanskeligste er ikke å
// laste opp en fil — det er å vite HVILKE filer, og hva hver av dem
// låser opp. Uten det blir svaret «last opp alt», og da laster ingen
// opp noe.
//
// Derfor måles det som faktisk ligger i basen, per stasjon, og
// sammenlignes med hva hver analyse trenger. Beskjeden er alltid
// konkret: hva mangler, for hvilke stasjoner, og hva du får når det er
// på plass.
//
// Ingen prosentbar. En prosentbar sier «du er 60 % ferdig» og skjuler at
// de siste 40 er den ene fila som gjør at bemanningsplanen virker.
// =====================================================================

import { TIMESALG_ANBEFALTE_DAGER } from './historikk'

export type Kildemaaling = {
  noekkel: string
  /** Antall stasjoner som har data i det hele tatt. */
  stasjonerMedData: number
  /** Dager dekket, målt på stasjonen med minst. */
  dagerDekket: number
  sisteDato: string | null
}

export type Kildekrav = {
  noekkel: string
  navn: string
  /** Hvor fila hentes fra. En setning, ikke en veiledning. */
  hentesFra: string
  /** Hva den låser opp. Skrevet som en gevinst, ikke som en funksjon. */
  laserOpp: string
  /** Dager som trengs for at analysen skal være til å stole på. */
  anbefaltDager: number
  /** Uten denne virker ingenting av det som avhenger av den. */
  kritisk: boolean
}

export type Onboardingsteg = Kildekrav & {
  status: 'mangler' | 'tynt' | 'ufullstendig' | 'ok'
  beskjed: string
  stasjonerMedData: number
  stasjonerTotalt: number
  dagerDekket: number
  sisteDato: string | null
}

// Rekkefølgen er avhengighetenes, ikke alfabetisk: salgstallene bærer
// alt, kundene bærer bemanningen, stemplingene bærer målingen.
export const KILDER: Kildekrav[] = [
  {
    noekkel: 'st1_salgsstatistikk',
    navn: 'Salgsstatistikk per varegruppe',
    hentesFra: 'St1-rapport 0714, daglig',
    laserOpp: 'Omsetning, bruttofortjeneste, kategorier og svinn. Alt annet bygger på denne.',
    anbefaltDager: 90,
    kritisk: true,
  },
  {
    noekkel: 'timesalg',
    navn: 'Timesalg med inne- og utekunder',
    hentesFra: 'St1-rapport 0603, daglig',
    laserOpp: 'Når på døgnet kundene faktisk er der — grunnlaget for hele bemanningsplanen.',
    // IKKE 365. Bemanningen leser fra 1. januar to år tilbake
    // (`timesalgFra`), fordi helligdagsfaktorene måles per dato og ett år
    // gir hver rød dag én gang. Tallet sto her og i bemanningen hver for
    // seg, og de skilte lag: 365 dager ga grønt mens halve grunnlaget
    // manglet. Nå leser begge samme konstant.
    anbefaltDager: TIMESALG_ANBEFALTE_DAGER,
    kritisk: true,
  },
  {
    noekkel: 'stempling',
    navn: 'Stemplinger per ansatt',
    hentesFra: 'easy@work, «Basis Export», helst som CSV',
    laserOpp: 'Hva som faktisk har vært bemannet: taket per time, helligdagsmønsteret, '
      + 'stillingsprosent og planen målt mot virkeligheten.',
    anbefaltDager: 365,
    kritisk: false,
  },
  {
    noekkel: 'bemanning_maned',
    navn: 'Forretningsplan (BP)',
    // TO FILER, ETT KRAV. Delingsfila (`st1_delingsfil`) skriver timene
    // inn i årgangen BP-fila oppretter. Uten den har rammen kroner, men
    // ingen timer.
    //
    // GJENSTÅENDE: målingen teller rader i `bemanning_maned` og ser ikke
    // om timene kom. En BP uten delingsfil viser «På plass».
    hentesFra: 'Kjedens BP-fil og delingsfila med timer, én gang i året',
    laserOpp: 'Årets timeramme og lønnsbudsjett per stasjon.',
    anbefaltDager: 0,
    kritisk: true,
  },
  {
    noekkel: 'regnskapslinjer',
    navn: 'Regnskapsrapport',
    hentesFra: 'Regnskapsføreren, hver måned',
    laserOpp: 'Faktisk lønn og timer mot budsjett, og avvikene som utløser varsler.',
    anbefaltDager: 0,
    kritisk: false,
  },
  // ---------------------------------------------------------------
  // DE TRE SOM MANGLET.
  //
  // Systemet har tatt imot dem hele tiden — de står i `Rapporttype` og
  // har hver sin lagringsarm i `import/kjerne.ts` — men onboardinglista
  // kjente dem ikke. `onboardingsteg()` går over KILDER, så en måling
  // uten oppføring her ble kastet i stillhet: en retailer kunne se en
  // komplett liste og likevel ha to tomme moduler.
  //
  // Ingen av dem er kritiske: mangler de, mangler sin modul, og resten
  // av systemet svarer riktig. Det er nettopp derfor de kunne bli borte.
  // ---------------------------------------------------------------
  {
    noekkel: 'kassererstatistikk',
    navn: 'Kassererstatistikk',
    hentesFra: 'St1-rapport 0018, daglig',
    laserOpp: 'Retur, makulert og slettet per kasse. Måler kassa, ikke personen — '
      + 'flere ansatte deler ofte samme kassenummer.',
    anbefaltDager: 90,
    kritisk: false,
  },
  {
    noekkel: 'svinn',
    navn: 'Varetransaksjoner (svinn)',
    hentesFra: 'St1-rapport 0452, ved behov',
    laserOpp: 'Hva som faktisk kastes, ført mot kost — og hvilke varer det gjelder.',
    // FØRES NÅR NOE KASTES, IKKE HVER DAG. En dag uten svinnføring er en
    // normal dag. Terskelen måler at det finnes føringer i det hele tatt,
    // ikke at hver dag har en (se migrasjon 0159).
    anbefaltDager: 30,
    kritisk: false,
  },
]

/**
 * Hvilken kilde hver opplastbar rapporttype fyller.
 *
 * KILDER er prosa og skjønn — navn, gevinst, terskel. DETTE er koblingen
 * som gjør at lista kan MÅLES mot hva systemet faktisk tar imot, og som
 * `onboarding.dekning.test.ts` bruker til å nekte at en ny rapporttype
 * legges til uten at noen har tatt stilling til hva den betyr for en ny
 * retailer.
 *
 * Nøklene skal være hver `Rapporttype` med en lagringsarm i
 * `import/kjerne.ts`, unntatt `ukjent`.
 */
export const TYPE_TIL_KILDE: Record<string, string> = {
  st1_salgsstatistikk: 'st1_salgsstatistikk',
  st1_salesperhour_inneute: 'timesalg',
  st1_cashierstats: 'kassererstatistikk',
  salgsgrid_varetrans: 'svinn',
  regnskap_resultat: 'regnskapslinjer',
  easyatwork_stempling: 'stempling',
  st1_bp: 'bemanning_maned',
  // Delingsfila skriver timene inn i årgangen BP-fila oppretter. Samme
  // krav, to filer — ikke en egen kilde å måle dekning på.
  st1_delingsfil: 'bemanning_maned',
}

/**
 * Setter status på hver kilde mot det som faktisk ligger inne.
 *
 * `stasjonerTotalt` er antall stasjoner retaileren har. En kilde som
 * dekker tre av fem stasjoner er ikke «ok» — bemanningsplanen for de to
 * andre er da bygget på ingenting, og det er verre enn å mangle helt,
 * fordi det ser ferdig ut.
 */
export function onboardingsteg(
  malinger: Kildemaaling[],
  stasjonerTotalt: number,
  krav: Kildekrav[] = KILDER,
): Onboardingsteg[] {
  const funn = new Map(malinger.map((m) => [m.noekkel, m]))

  return krav.map((k) => {
    const m = funn.get(k.noekkel)
    const felles = {
      ...k,
      stasjonerMedData: m?.stasjonerMedData ?? 0,
      stasjonerTotalt,
      dagerDekket: m?.dagerDekket ?? 0,
      sisteDato: m?.sisteDato ?? null,
    }

    if (!m || m.stasjonerMedData === 0) {
      return {
        ...felles,
        status: 'mangler' as const,
        beskjed: `Ikke lastet opp ennå. ${k.hentesFra}.`,
      }
    }

    if (m.stasjonerMedData < stasjonerTotalt) {
      const mangler = stasjonerTotalt - m.stasjonerMedData
      return {
        ...felles,
        status: 'ufullstendig' as const,
        beskjed: `Mangler for ${mangler} av ${stasjonerTotalt} stasjoner. `
          + 'De stasjonene får ingen analyse på dette — og det ser ferdig ut uten å være det.',
      }
    }

    if (k.anbefaltDager > 0 && m.dagerDekket < k.anbefaltDager) {
      return {
        ...felles,
        status: 'tynt' as const,
        beskjed: `${m.dagerDekket} dager lastet opp. `
          + `Analysen blir vesentlig bedre fra ${k.anbefaltDager} dager — `
          + 'da har vi hver ukedag, hver måned og hver røde dag minst én gang.',
      }
    }

    return {
      ...felles,
      status: 'ok' as const,
      beskjed: k.anbefaltDager > 0
        ? `${m.dagerDekket} dager for alle stasjoner.`
        : 'På plass for alle stasjoner.',
    }
  })
}

/** Én setning øverst: hva er det viktigste som mangler akkurat nå? */
export function nesteSteg(steg: Onboardingsteg[]): Onboardingsteg | null {
  const rang = { mangler: 0, ufullstendig: 1, tynt: 2, ok: 3 }
  const igjen = steg
    .filter((s) => s.status !== 'ok')
    // Kritiske først, så etter hvor ille det står til, så etter rekkefølgen
    // i KILDER — som er avhengighetenes rekkefølge.
    .sort((a, b) =>
      Number(b.kritisk) - Number(a.kritisk) || rang[a.status] - rang[b.status])
  return igjen[0] ?? null
}
