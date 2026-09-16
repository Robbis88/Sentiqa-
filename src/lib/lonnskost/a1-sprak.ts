import type { Uprisetgrunn, Radutfall } from './a1'

// =====================================================================
// FRA MOTORENS SPRAAK TIL BRUKERENS.
//
// Ren funksjon. Ingen React, ingen databaselesing, ingen import fra
// `app/`. Den kan testes alene, og det er hele grunnen til at den er en
// egen fil: oversettingen er der en misvisende fremstilling faktisk
// oppstaar, og da skal den ha sin egen vakt.
//
// ---------------------------------------------------------------------
// INGEN INTERNE NAVN PAA SKJERMEN
//
// `Vurdertrad`, `Uprisetgrunn`, `a1_registeroppslag`, `motstrid`,
// `kildemangel` og `komplett` er kontraktsnavn, ikke norsk. En bruker
// skal aldri se dem. `a1-sprak.test.ts` leser hver eneste tekst her og
// feiler paa et hvert av dem.
//
// ---------------------------------------------------------------------
// «KOMPLETT» SIES ALDRI
//
// Statusen betyr komplett FOR A1-MODELLEN: hver registrerte time er
// priset eller forklart. Den betyr ikke at hele loennskosten er med -
// overtid staar fortsatt utenfor. Aa skrive «komplett» paa skjermen
// ville vaert sant om modellen og usant om loenna.
//
// Derfor skriver vi hva det FAKTISK betyr, og forbeholdet staar under
// uansett status.
// =====================================================================

/** Hvorfor kjent arbeid ikke ble priset, i klartekst. */
export const UPRISET_GRUNN: Readonly<Record<Uprisetgrunn, string>> = {
  ukjent_nummer: 'Finnes ikke i lønnsgrunnlaget for måneden',
  motstrid_navn: 'Lønnsgrunnlaget har et annet navn på dette nummeret',
  motstrid_kollisjon: 'Nummeret finnes på to stasjoner denne måneden',
  motstrid_bro: 'Nummeret er koblet til to ulike lønnsnumre',
  mangler_sats: 'easy@work oppga timelønn, men ingen sats',
  ukjent_enhet: 'easy@work oppga ikke om beløpet er time- eller månedslønn',
  avvist_rad: 'Vakten kunne ikke leses — trolig en glemt utstempling',
  dublett: 'Samme vakt er registrert to ganger',
  flere_lokasjoner: 'Måneden oppgir flere arbeidssteder',
}

/** Hvorfor arbeid er forklart, men ikke timepriset. */
export const FORKLART_GRUNN: Readonly<Record<
  'maanedslonn' | 'fastlonn_klassifisert' | 'fastlonn_uten_register', string
>> = {
  // ALDRI «0 kr». Personen koster - loenna kommer bare ikke fra timene.
  maanedslonn: 'Månedslønn i easy@work — timene telles, men prises ikke time for time',
  fastlonn_klassifisert: 'Klassifisert som fastlønnet — timene telles, men prises ikke time for time',
  // SAMME SETNING som over, med vilje. Forskjellen paa de to er
  // BEVISSTYRKE, ikke hva som skjedde med timene, og brukeren skal
  // ikke lese to formuleringer for samme utfall. Proveniensen ligger i
  // `Prisbarhet` for den som trenger den.
  fastlonn_uten_register: 'Klassifisert som fastlønnet — timene telles, men prises ikke time for time',
}

/** Hva som skjedde med én vakt, i klartekst. */
export function utfallstekst(u: Radutfall): string {
  switch (u.slag) {
    case 'priset': return u.innlaant ? 'Priset — sats fra en annen stasjon' : 'Priset'
    case 'forklart': return FORKLART_GRUNN[u.grunn]
    case 'upriset': return UPRISET_GRUNN[u.grunn]
    case 'ubetalt': return 'Ubetalt tid'
  }
}

/**
 * Overskriften for et kostnadstall.
 *
 * «Minst» er en del av tallet, ikke pynt: det skiller «dette er hva det
 * koster» fra «dette er det minste det kan koste».
 */
export function beloepsledetekst(status: 'minimum' | 'komplett'): string {
  return status === 'minimum' ? 'Minst' : 'Beregnet'
}

/**
 * Hva statusen betyr, sagt uten kontraktsord.
 *
 * Merk at 'komplett' IKKE blir til ordet «komplett». Se hodet.
 */
export function statusforklaring(status: 'minimum' | 'komplett'): string {
  return status === 'minimum'
    ? 'Noe kjent arbeid kunne ikke prises sikkert. Det faktiske beløpet er høyere.'
    : 'Alle registrerte timer er priset eller forklart.'
}

/** Hva som mangler når måneden ikke kan beregnes. */
export const KILDEMANGEL: Readonly<Record<'register' | 'arbeidstid' | 'begge', string>> = {
  register: 'Lønnsgrunnlaget fra easy@work mangler for denne måneden',
  arbeidstid: 'Arbeidstiden fra easy@work mangler for denne måneden',
  begge: 'Både arbeidstid og lønnsgrunnlag mangler for denne måneden',
}

/**
 * Modellforbeholdene, kort nok til en linje.
 *
 * Den utfyllende teksten ligger i `a1.ts` sine `forbehold`, som foelger
 * resultatet ut. Denne er sammendraget som alltid staar synlig - ogsaa
 * naar status er 'komplett'.
 */
export const FORBEHOLD_KORT =
  'Overtid er ikke med. Helligdagstillegget er delvis målt.'
