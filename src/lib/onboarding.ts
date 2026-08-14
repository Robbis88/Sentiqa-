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
    anbefaltDager: 365,
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
    hentesFra: 'Kjedens BP-fil, én gang i året',
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
]

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
