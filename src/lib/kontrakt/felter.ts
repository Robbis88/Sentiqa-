// =====================================================================
// Hvilke felt fylles av systemet, og hvilke må noen svare på?
//
// Poenget med å generere kontrakter er at butikksjefen ikke skal taste
// inn noe systemet allerede vet. Av elleve felt i Virkes mal for fast
// ansettelse kommer åtte fra data vi har — resten er reelle valg.
//
// Klammer i malene betyr TO ting, og de må ikke blandes:
//
//   [stillingsprosent]   et felt. Kort, ett ord, skal fylles ut.
//   [Arbeidstaker er …]  et alternativ. En hel setning som skal
//                        beholdes eller slettes, ikke fylles.
//
// Vi fyller bare det første slaget. Alternativene står igjen som
// klammer, synlige, og butikksjefen tar stilling til dem i Word. Å
// slette en setning automatisk er å endre en juridisk gjennomgått
// avtale uten at noen leste den.
// =====================================================================

export type Ansettelsesform = 'fast' | 'midlertidig' | 'tilkalling'
export type Rolle = 'ansatt' | 'ass_butikksjef' | 'butikksjef'

/** Et felt er kort og uten setningstegn. En setning er et alternativ. */
export function erUtfyllingsfelt(navn: string): boolean {
  if (navn.length > 40) return false
  if (/[.!?]/.test(navn.trim().slice(0, -1))) return false
  // «37,5/35,5» og «6» er valg, men korte — de regnes som felt.
  return navn.trim().split(/\s+/).length <= 4
}

/**
 * Er hun under 18 på den datoen avtalen gjelder fra?
 *
 * Ikke et spørsmål i skjemaet: alderen følger av fødselsdatoen, og et
 * spørsmål er noe noen kan svare feil på. Svaret avgjør både hvilken mal
 * som brukes og hvilke arbeidstidsregler som gjelder (aml. kap. 11).
 *
 * Regnet på kalenderdato, ikke millisekunder — hun fyller 18 på dagen,
 * ikke etter 6574 døgn.
 */
export function erMindreaarig(fodselsdato: string | null, paaDato: string): boolean {
  if (!fodselsdato) return false
  const [aa, mm, dd] = fodselsdato.split('-').map(Number)
  const [ba, bm, bd] = paaDato.split('-').map(Number)
  const alder = ba - aa - (bm < mm || (bm === mm && bd < dd) ? 1 : 0)
  return alder < 18
}

export type Kilde = 'system' | 'kjede' | 'spor'

export type Feltdef = { navn: string; kilde: Kilde; forklaring: string }

/**
 * Hvor hvert felt kommer fra.
 *
 * `system` fylles fra data vi har. `kjede` settes én gang for hele
 * kjeden. `spor` må butikksjefen svare på hver gang.
 */
export const FELTKILDER: Feltdef[] = [
  { navn: 'Navn på arbeidsgiver', kilde: 'kjede', forklaring: 'Fra kjedens innstillinger' },
  { navn: 'organisasjonsnummer', kilde: 'kjede', forklaring: 'Fra kjedens innstillinger' },
  { navn: 'forretningsadresse', kilde: 'kjede', forklaring: 'Fra kjedens innstillinger' },
  { navn: '10.', kilde: 'kjede', forklaring: 'Lønningsdato' },
  { navn: '6', kilde: 'kjede', forklaring: 'Prøvetid i måneder' },
  { navn: 'Navn på arbeidstaker', kilde: 'system', forklaring: 'Fra ansattlisten' },
  { navn: 'fødselsdato', kilde: 'system', forklaring: 'Fra ansattkortet' },
  { navn: 'stillingsprosent', kilde: 'system', forklaring: 'Fra bekreftet stilling' },
  { navn: 'timelønn', kilde: 'system', forklaring: 'Fra registrert timesats' },
  { navn: 'stasjonsnavn', kilde: 'system', forklaring: 'Fra stasjonen' },
  { navn: 'adresse', kilde: 'system', forklaring: 'Stasjonens adresse' },
  { navn: '37,5/35,5', kilde: 'system', forklaring: 'Følger skiftordningen' },
  { navn: '40/38,5', kilde: 'system', forklaring: 'Følger skiftordningen' },
  { navn: 'stillingstittel', kilde: 'spor', forklaring: 'Hva stillingen heter' },
  { navn: 'dato, måned, år', kilde: 'spor', forklaring: 'Tiltredelsesdato' },
  { navn: 'beskrivelse', kilde: 'spor', forklaring: 'Stillingsbeskrivelse' },
  { navn: 'dato', kilde: 'spor', forklaring: 'Dato for årlig lønnsvurdering' },
]

const kildeFor = new Map(FELTKILDER.map((f) => [f.navn, f]))

export type Grunnlag = {
  kjede: { navn: string; orgNr: string | null; standardfelt: Record<string, string> }
  stasjon: { navn: string; adresse: string | null }
  ansatt: {
    navn: string
    fodselsdato: string | null
    stillingsprosent: number | null
    timesats: number | null
    skiftordning: 'ordinaer' | 'to_skift' | null
  }
  svar: Record<string, string>
}

const dato = (iso: string | null) =>
  (iso ? iso.slice(8, 10) + '.' + iso.slice(5, 7) + '.' + iso.slice(0, 4) : '')

/**
 * Bygger verdiene til malen.
 *
 * Felt uten verdi utelates — da står klammen igjen i dokumentet, og det
 * er synlig. Et tomt hull er det ikke.
 */
export function byggVerdier(g: Grunnlag): Record<string, string> {
  const ut: Record<string, string> = {}
  const sett = (navn: string, verdi: string | null | undefined) => {
    if (verdi != null && String(verdi).trim() !== '') ut[navn] = String(verdi)
  }

  sett('Navn på arbeidsgiver', g.kjede.navn)
  sett('organisasjonsnummer', g.kjede.orgNr)
  for (const [k, v] of Object.entries(g.kjede.standardfelt)) sett(k, v)

  sett('stasjonsnavn', g.stasjon.navn)
  sett('adresse', g.stasjon.adresse)

  sett('Navn på arbeidstaker', g.ansatt.navn)
  sett('fødselsdato', dato(g.ansatt.fodselsdato))
  if (g.ansatt.stillingsprosent != null) sett('stillingsprosent', String(g.ansatt.stillingsprosent))
  if (g.ansatt.timesats != null) {
    sett('timelønn', g.ansatt.timesats.toFixed(2).replace('.', ','))
  }
  // Ukentlig arbeidstid følger skiftordningen, ikke et valg per kontrakt.
  if (g.ansatt.skiftordning) {
    sett('37,5/35,5', g.ansatt.skiftordning === 'to_skift' ? '35,5' : '37,5')
    sett('40/38,5', g.ansatt.skiftordning === 'to_skift' ? '38,5' : '40')
  }

  for (const [k, v] of Object.entries(g.svar)) sett(k, v)
  return ut
}

/** Felt malen har, men som ingen har gitt verdi til. */
export function manglerVerdi(
  feltIMal: string[],
  verdier: Record<string, string>,
): Feltdef[] {
  return feltIMal
    .filter(erUtfyllingsfelt)
    .filter((f) => !(f in verdier))
    .map((f) => kildeFor.get(f) ?? { navn: f, kilde: 'spor' as const, forklaring: 'Ukjent felt i malen' })
}

/** Alternativsetningene — de skal leses, ikke fylles. */
export function alternativer(feltIMal: string[]): string[] {
  return feltIMal.filter((f) => !erUtfyllingsfelt(f))
}
