// =====================================================================
// Innsyn etter GDPR art. 15: alt vi har om én person, i ett dokument.
//
// Kravet er «en kopi av personopplysningene». Ikke en oppsummering, og
// ikke bare det som er lett å hente ut.
//
// DEN VANSKELIGE DELEN ER IKKE Å HENTE DATAENE. Det er at samme person
// finnes under TRE ULIKE IDENTITETER som ikke er koblet:
//
//   ansatt_nr      fra easy@work. Stabil. Bærer stemplinger, ansattkort,
//                  kontrakter.
//   ansatte.id     PIN-en på nettbrettet. Bærer rutiner, sjekkpunkt,
//                  IK-avlesninger, puls-svar, merker.
//   navn           fritekst. Bærer ferie/fravær og faste vakter.
//
// De to første kan bare knyttes sammen på navn, og navn er ikke en
// nøkkel: to kan hete det samme, og folk gifter seg.
//
// Derfor MERKER eksporten hvordan hver del ble funnet. En kopi som ser
// komplett ut, men er koblet på et usikkert navnetreff, er verre enn en
// som sier fra. Den ansatte skal kunne se hva vi ikke er sikre på.
// =====================================================================

export type Kobling = 'ansattnummer' | 'navn'

export type Seksjon = {
  tittel: string
  kobling: Kobling
  /** Kort forklaring på hva dette er, i klarspråk. */
  hva: string
  kolonner: string[]
  rader: (string | number | null)[][]
}

export type Innsyn = {
  navn: string
  ansattNr: string
  stasjon: string
  kjede: string
  /** ISO-dato eksporten ble laget. */
  laget: string
  oppbevaringMaaneder: number
  seksjoner: Seksjon[]
}

const verdi = (v: string | number | null) =>
  (v === null || v === '' ? '—' : String(v).replace(/\|/g, '\\|'))

/**
 * Skriver innsynet som Markdown.
 *
 * Markdown framfor JSON fordi mottakeren er et menneske, ikke et system.
 * Art. 15 krever en kopi hun kan lese; art. 20 (dataportabilitet) er en
 * annen rettighet med et annet format, og den er ikke denne.
 */
export function innsynTilMarkdown(d: Innsyn): string {
  const ut: string[] = []

  ut.push(`# Personopplysninger om ${d.navn}`)
  ut.push('')
  ut.push(`| | |`)
  ut.push(`|---|---|`)
  ut.push(`| Arbeidsgiver | ${d.kjede} |`)
  ut.push(`| Arbeidssted | ${d.stasjon} |`)
  ut.push(`| Ansattnummer | ${d.ansattNr} |`)
  ut.push(`| Utskrift laget | ${d.laget} |`)
  ut.push(`| Oppbevaringstid | ${d.oppbevaringMaaneder} måneder etter siste aktivitet |`)
  ut.push('')

  ut.push('## Om denne utskriften')
  ut.push('')
  ut.push(
    'Dette er en kopi av personopplysningene arbeidsgiver har registrert om deg '
    + 'i Sentiqa, etter personvernforordningen artikkel 15.')
  ut.push('')
  ut.push(
    'Opplysningene er lagret på tre ulike måter, og det står under hver del '
    + 'hvordan den ble funnet:')
  ut.push('')
  ut.push('- **Koblet på ansattnummer** — sikker kobling. Nummeret er ditt alene.')
  ut.push(
    '- **Koblet på navn** — usikker kobling. Heter noen andre det samme, kan '
    + 'listen inneholde deres opplysninger eller mangle dine. Si fra hvis noe '
    + 'ser feil ut.')
  ut.push('')

  const tomme = d.seksjoner.filter((s) => s.rader.length === 0)
  const fylte = d.seksjoner.filter((s) => s.rader.length > 0)

  for (const s of fylte) {
    ut.push(`## ${s.tittel}`)
    ut.push('')
    ut.push(`*${s.hva}*`)
    ut.push('')
    ut.push(`Koblet på **${s.kobling}**. ${s.rader.length} `
      + `${s.rader.length === 1 ? 'oppføring' : 'oppføringer'}.`)
    ut.push('')
    ut.push(`| ${s.kolonner.join(' | ')} |`)
    ut.push(`|${s.kolonner.map(() => '---').join('|')}|`)
    for (const r of s.rader) ut.push(`| ${r.map(verdi).join(' | ')} |`)
    ut.push('')
  }

  // Det vi IKKE har er også et svar. Uten denne lista ser en tom
  // kategori ut som noe vi glemte å sjekke.
  if (tomme.length > 0) {
    ut.push('## Kategorier uten registreringer')
    ut.push('')
    ut.push('Vi har sjekket disse og funnet ingenting om deg:')
    ut.push('')
    for (const s of tomme) ut.push(`- ${s.tittel} — ${s.hva}`)
    ut.push('')
  }

  ut.push('## Dine rettigheter')
  ut.push('')
  ut.push(
    'Du kan kreve at feil opplysninger rettes, og at opplysninger slettes når '
    + 'de ikke lenger er nødvendige. Lønnsgrunnlag må likevel oppbevares i fem '
    + 'år etter bokføringsloven, og kan ikke slettes før den tiden er ute.')
  ut.push('')
  ut.push(
    'Mener du opplysningene behandles feil, kan du klage til Datatilsynet.')
  ut.push('')

  return ut.join('\n')
}

/** Filnavn til nedlastingen. */
export const innsynFilnavn = (navn: string, dato: string) =>
  `Personopplysninger - ${navn.replace(/[^\wÆØÅæøå -]/g, '')} - ${dato}.md`

/**
 * Hele måneder mellom to datoer.
 *
 * Avgjør hvem som havner på slettelista, og feilen har en farlig
 * retning: teller den for høyt, slettes data FØR fristen er ute. Derfor
 * trekkes en måned fra når dagen i måneden ikke er nådd — 15. mai til
 * 14. november er fem måneder, ikke seks.
 *
 * Basen kontrollerer det samme en gang til i slett_person(); dette er
 * bare for å vise riktig liste.
 */
export function maanederSiden(fra: string, til: string): number {
  const [a1, m1, d1] = fra.split('-').map(Number)
  const [a2, m2, d2] = til.split('-').map(Number)
  return (a2 - a1) * 12 + (m2 - m1) - (d2 < d1 ? 1 : 0)
}
