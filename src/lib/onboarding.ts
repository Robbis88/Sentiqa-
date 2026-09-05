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

/**
 * Et krav som IKKE er en fil.
 *
 * `Kildekrav` beskriver noe som lastes opp: den har `hentesFra`,
 * `anbefaltDager` og en siste dato. Men ikke alt en ny kjede maa ha paa
 * plass er data. Ukebriefen kan ikke sendes til en stasjon uten
 * butikksjef, og det er ikke en fil som mangler — det er et oppsett.
 *
 * Fram til 2026-09-03 fantes det ingen plass til slike krav. Konsekvensen
 * var den samme som en vakt som slutter aa se: onboardingen saa komplett
 * ut mens en modul ikke kunne gjoere jobben sin.
 */
export type Oppsettkrav = {
  noekkel: string
  navn: string
  /** Hvor i Sentiqa det gjoeres. En setning, ikke en veiledning. */
  gjoresI: string
  laserOpp: string
  kritisk: boolean
}

export type Oppsettmaaling = {
  noekkel: string
  /** Stasjoner der oppsettet faktisk er paa plass. */
  stasjonerMedOppsett: number
}

export type Onboardingsteg = {
  noekkel: string
  navn: string
  laserOpp: string
  kritisk: boolean
  /** En fil som lastes opp, eller et oppsett som gjoeres. */
  slag: 'kilde' | 'oppsett'
  /** Hvor det kommer fra: fila hentes her, eller oppsettet gjoeres her.
      Ett felt, fordi det er én kolonne for leseren. */
  hvor: string
  status: 'mangler' | 'tynt' | 'ufullstendig' | 'ok'
  beskjed: string
  stasjonerMedData: number
  stasjonerTotalt: number
  /** 0 for oppsettskrav — de har ingen historikk aa dekke. */
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
    // MÅNEDSFORDELINGEN, ikke årsrammen. Timebudsjettet er en egen
    // kilde (`bp_timer`) fordi det kan komme fra to ulike filer — se der.
    hentesFra: 'Kjedens BP-fil, én gang i året',
    laserOpp: 'Lønnsbudsjettet fordelt på måneder — kurven planleggeren leser.',
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
  {
    noekkel: 'bp_timer',
    navn: 'Timebudsjett for året',
    // HVILKEN FIL DET ER, AVHENGER AV MALEN — og det skal ikke bli et
    // steg ingen kan fullføre. BP26 bærer timene selv; en kjede på nytt
    // format skal aldri laste opp en delingsfil. Er malen den gamle
    // (til og med BP25), står `timer_aar` som null, og timene kommer
    // som delingsfila i stedet.
    hentesFra: 'Følger BP-fila i det nye formatet. På den gamle malen: delingsfila med timer',
    laserOpp: 'Kroner per time. Uten den kan lønn ikke måles mot rammen, '
      + 'og analysen lar være å love det.',
    anbefaltDager: 0,
    kritisk: true,
  },
  {
    noekkel: 'kastbudsjett',
    navn: 'Kastbudsjett per varegruppe',
    // SAMME FIL SOM TIMENE, ANNET ARK. Delingsfila kommer i to varianter:
    // den ene har «Timer» og ti undergruppeark, den andre bare Mat og
    // Vask — men med usynlig svinn. Begge godtas, og begge fyller dette.
    hentesFra: 'Delingsfila fra St1 — samme fil som timebudsjettet',
    laserOpp: 'Hvor mye stasjonen har lov til å kaste. Uten den kan svinnet '
      + 'måles og vises, men ikke sies om det er for mye.',
    anbefaltDager: 0,
    // IKKE KRITISK. Mangler den, virker svinnsida som før — den viser
    // hva som ble kastet, bare uten et krav å holde det opp mot. Å gjøre
    // den kritisk ville stoppet en kjede som ikke har fått fila ennå.
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
  // Delingsfila fyller `bp_aar.timer_aar` for kjeder på den gamle malen.
  // Den er ikke et eget krav — kravet er at timene FINNES, og på nytt
  // format kommer de med BP-fila.
  // Delingsfila fyller TO kilder: timene (paa den gamle malen) og
  // kastbudsjettet. `TYPE_TIL_KILDE` er én-til-én, saa den peker paa
  // timene - de er det kritiske. Kastbudsjettet maales av sin egen arm i
  // `v_datadekning` og trenger ingen oppfoering her.
  st1_delingsfil: 'bp_timer',
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
      noekkel: k.noekkel, navn: k.navn, laserOpp: k.laserOpp, kritisk: k.kritisk,
      slag: 'kilde' as const,
      hvor: k.hentesFra,
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

/**
 * Krav som ikke er filer.
 *
 * SKAL UTLEDES, ALDRI GJENTAS. Maalingen leser den samme koblingen
 * utsendingen selv leser (`butikksjef_stasjoner`), saa lista og modulen
 * ikke kan skille lag. En haandholdt hake her ville vaert en andre
 * sannhet om det samme — se «Én sannhet, ikke to» i AGENTS.md.
 */
export const OPPSETT: Oppsettkrav[] = [
  {
    noekkel: 'butikksjef_paa_stasjon',
    navn: 'Butikksjef på hver stasjon',
    gjoresI: 'Brukere → Ny bruker, eller Endre stasjoner',
    laserOpp: 'Den ukentlige lederbriefen på e-post mandag morgen. '
      + 'En stasjon uten butikksjef har ingen å sende til.',
    kritisk: false,
  },
]

/**
 * Setter status paa hvert oppsettskrav.
 *
 * Samme tre utfall som kildene, og med vilje samme ord: «ufullstendig»
 * betyr det samme her — noen stasjoner er dekket, andre ikke, og det ser
 * ferdig ut uten aa vaere det.
 */
export function oppsettsteg(
  malinger: Oppsettmaaling[],
  stasjonerTotalt: number,
  krav: Oppsettkrav[] = OPPSETT,
): Onboardingsteg[] {
  const funn = new Map(malinger.map((m) => [m.noekkel, m]))

  return krav.map((k) => {
    const dekket = funn.get(k.noekkel)?.stasjonerMedOppsett ?? 0
    const felles = {
      noekkel: k.noekkel, navn: k.navn, laserOpp: k.laserOpp, kritisk: k.kritisk,
      slag: 'oppsett' as const,
      hvor: k.gjoresI,
      stasjonerMedData: dekket,
      stasjonerTotalt,
      dagerDekket: 0,
      sisteDato: null,
    }

    if (dekket === 0) {
      return { ...felles, status: 'mangler' as const, beskjed: `Ikke satt opp ennå. ${k.gjoresI}.` }
    }
    if (dekket < stasjonerTotalt) {
      const mangler = stasjonerTotalt - dekket
      return {
        ...felles,
        status: 'ufullstendig' as const,
        beskjed: `Mangler for ${mangler} av ${stasjonerTotalt} stasjoner. `
          + 'De stasjonene blir hoppet over — og det ser ferdig ut uten å være det.',
      }
    }
    return { ...felles, status: 'ok' as const, beskjed: 'På plass for alle stasjoner.' }
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
