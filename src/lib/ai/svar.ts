// =====================================================================
// Konvolutten hvert leseverktøy svarer i.
//
// PORT 0 fant at alle verktøyene skrev `const { data } = await ...` og
// returnerte radene rått. Da ble en RLS-blokkering, en timeout, et view
// som ikke finnes og «det er faktisk null rader» til nøyaktig samme
// utdata: `[]`. Modellen kunne ikke skille dem, fordi forskjellen ble
// kastet før den nådde fram.
//
// Derfor: ingen verktøy returnerer en naken liste. Alle returnerer
// `Verktoysvar`, som bærer HVA som ble spurt om, HVA som kom tilbake, og
// HVORFOR det eventuelt er tomt.
//
// «Ingen rad» blir aldri til 0. Det er to forskjellige påstander om
// verden, og bare den ene er en måling.
// =====================================================================

/**
 * Tilstandene et leseverktøy kan ende i.
 *
 * Rekkefølgen her ER prioriteringen i `byggSvar` — den øverste som
 * treffer vinner, fordi det er den som forklarer mest. Endrer du
 * rekkefølgen, endrer du hva brukeren får høre.
 */
export const DATASTATUS = [
  /**
   * Sentiqa har ikke dataene som kreves — kilden finnes ikke.
   *
   * Ligger over `feil` med vilje: «viewet finnes ikke» er en mer presis
   * diagnose enn «noe gikk galt», og den peker på en migrasjon som ikke
   * er kjørt framfor på et driftsproblem.
   */
  'mangler_kilde',
  /** Databasen eller verktøyet feilet. Svaret er ukjent, ikke tomt. */
  'feil',
  /** Rollen har ikke lov å lese domenet. Ikke det samme som at det er tomt. */
  'ingen_tilgang',
  /** Alt som ble spurt om ligger utenfor brukerens autoriserte scope. */
  'utenfor_scope',
  /** Stasjonene er i scope, men ingen har registrert noe for perioden. */
  'ingen_registrering',
  /** Målt, og verdien er faktisk null. Dette ER et svar. */
  'malt_null',
  /** Det finnes tall, men perioden er ikke ferdig og kan ikke vurderes ferdig. */
  'ufullstendig_periode',
  /** Data finnes, perioden er komplett. */
  'ok',
] as const

export type Datastatus = (typeof DATASTATUS)[number]

/** Menneskelesbar forklaring per status — går rett inn i modellen. */
export const STATUS_FORKLARING: Record<Datastatus, string> = {
  feil:
    'Oppslaget feilet. Du VET IKKE om det finnes data. Si at oppslaget '
    + 'feilet — påstå aldri at det ikke finnes noe.',
  ingen_tilgang:
    'Brukerens rolle har ikke lesetilgang til dette domenet. Si det '
    + 'rett ut, og hvem som kan svare i stedet.',
  mangler_kilde:
    'Sentiqa har ikke dataene som kreves for å svare på dette. Si '
    + 'nøyaktig det — ikke gjett, og ikke tolk det som at alt er i orden.',
  utenfor_scope:
    'Det som ble spurt om ligger utenfor brukerens tilgang. Oppgi ingen '
    + 'tall, ingen plassering og ingen antydning om andre stasjoner.',
  ingen_registrering:
    'Stasjonene er innenfor tilgangen, men ingenting er registrert for '
    + 'perioden. Dette betyr IKKE at verdien er null — det betyr at '
    + 'ingen har registrert noe. Si det som det er.',
  malt_null:
    'Målt, og verdien er faktisk null. Dette er et ekte svar, ikke '
    + 'manglende data.',
  ufullstendig_periode:
    'Perioden er ikke ferdig. Tallene er foreløpige og kan ikke brukes '
    + 'til en endelig vurdering. Si at perioden er ufullstendig.',
  ok: 'Data finnes og perioden er komplett.',
}

export type Periodeinfo = {
  fra: string
  til: string
  opplosning: 'dag' | 'maaned' | 'aar'
  /** Usant når perioden strekker seg til i dag eller framover. */
  komplett: boolean
}

export type Scopeinfo = {
  /** Butikknumre det faktisk ble spurt om, etter at scope var avgjort. */
  forespurt: string[]
  /** Butikknumre som ga minst én rad. */
  besvart: string[]
  /** I scope, men uten rad for perioden — «ikke registrert», ikke 0. */
  uten_registrering: string[]
  /** Skrevet av brukeren, men utenfor tilgangen. Aldri spurt om i basen. */
  utenfor_tilgang: string[]
}

export type Verktoysvar<T = unknown> = {
  domene: string
  status: Datastatus
  /** Hva statusen betyr. Modellen skal aldri måtte gjette semantikken. */
  betyr: string
  /** Tabellene/viewene svaret faktisk er lest fra. */
  kilder: string[]
  scope: Scopeinfo
  periode: Periodeinfo | null
  /** Usant når noe ble utelatt — avkorting, manglende stasjon, delvis periode. */
  komplett: boolean
  data: T[]
  /** Verktøy som kan besvare det samme fra en annen vinkel. */
  neste: string[]
  merknad: string[]
  feil?: string
}

const TOM_SCOPE: Scopeinfo = {
  forespurt: [],
  besvart: [],
  uten_registrering: [],
  utenfor_tilgang: [],
}

export type ByggInput<T> = {
  domene: string
  kilder: string[]
  data?: T[]
  scope?: Partial<Scopeinfo>
  periode?: Periodeinfo | null
  /**
   * Sett når databasen eller verktøyet feilet. Vinner over alt unntatt
   * `manglerKilde`, som er den mer presise diagnosen av de to.
   */
  feil?: string
  /** Sett når kilden ikke finnes i basen (view droppet, migrasjon ikke kjørt). */
  manglerKilde?: boolean
  /** Sett når rollen ikke har lov å lese domenet i det hele tatt. */
  ingenTilgang?: boolean
  /**
   * Sett når radene finnes og alle målte verdier er null. Kalleren må
   * avgjøre dette — bare den vet hvilke felter som ER målingen.
   */
  maltNull?: boolean
  /** Sett når noe ble avkortet eller utelatt av andre grunner. */
  avkortet?: boolean
  neste?: string[]
  merknad?: string[]
}

/**
 * Bygger konvolutten og avgjør statusen. Kalleren oppgir fakta, ikke
 * konklusjon — det er nettopp fordi hvert verktøy tidligere konkluderte
 * på egen hånd at de konkluderte forskjellig.
 */
export function byggSvar<T>(inn: ByggInput<T>): Verktoysvar<T> {
  const scope: Scopeinfo = { ...TOM_SCOPE, ...inn.scope }
  const data = inn.data ?? []
  const merknad = [...(inn.merknad ?? [])]

  const status: Datastatus = inn.manglerKilde
    ? 'mangler_kilde'
    : inn.feil
      ? 'feil'
      : inn.ingenTilgang
        ? 'ingen_tilgang'
        : scope.forespurt.length === 0 && scope.utenfor_tilgang.length > 0
          ? 'utenfor_scope'
          : data.length === 0
            ? 'ingen_registrering'
            : inn.maltNull
              ? 'malt_null'
              : inn.periode && !inn.periode.komplett
                ? 'ufullstendig_periode'
                : 'ok'

  // Stasjoner utenfor tilgang nevnes, men aldri med tall og aldri med
  // en bekreftelse på at de finnes. «Ikke i ditt tilgangsområde» sier
  // ingenting om verden utenfor brukerens egen kjede.
  if (scope.utenfor_tilgang.length > 0) {
    merknad.push(
      `Utenfor tilgangen og derfor ikke spurt om: ${scope.utenfor_tilgang.join(', ')}. `
      + 'Oppgi ingen tall, ingen rangering og ingen relativ plassering for disse.',
    )
  }

  // Den viktigste linja i fila. En stasjon som mangler rad skal aldri
  // falle ut av svaret i stillhet — det var nøyaktig slik Dale forsvant.
  if (scope.uten_registrering.length > 0) {
    merknad.push(
      `Ingen registrering for: ${scope.uten_registrering.join(', ')}. `
      + 'Dette er ikke det samme som null — ingen har registrert noe.',
    )
  }

  if (inn.periode && !inn.periode.komplett) {
    merknad.push(
      `Perioden ${inn.periode.fra}–${inn.periode.til} er ikke ferdig. `
      + 'Tallene er foreløpige.',
    )
  }

  const komplett =
    status === 'ok'
    && !inn.avkortet
    && scope.uten_registrering.length === 0
    && scope.utenfor_tilgang.length === 0

  return {
    domene: inn.domene,
    status,
    betyr: STATUS_FORKLARING[status],
    kilder: inn.kilder,
    scope,
    periode: inn.periode ?? null,
    komplett,
    data,
    neste: inn.neste ?? [],
    merknad,
    ...(inn.feil ? { feil: inn.feil } : {}),
  }
}

/** Sant når svaret ikke inneholder brukbare tall — da bør modellen lete videre. */
export function borLeteVidere(svar: Verktoysvar): boolean {
  return (
    svar.status === 'ingen_registrering'
    || svar.status === 'mangler_kilde'
    || svar.status === 'feil'
  )
}
