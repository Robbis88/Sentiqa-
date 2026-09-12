// =====================================================================
// HVER SEKSJON I `regnskapslinjer` SKAL VÆRE TATT STILLING TIL
// =====================================================================
//
// `0192` stengte butikksjefen ute fra `driftskostnader` og `resultat`
// med en SVARTELISTE på seksjon, og skrev begrunnelsen ned:
//
//   «En hvitliste over SEKSJONER ville fått en ny seksjon til å
//    forsvinne i stillhet for butikksjefen.»
//
// Avveiningen var riktig, og den har en bakside som slo til: **en ny
// seksjon slipper inn i stillhet i stedet.** `bp_kostnad` kom til med
// BP-importen og bærer hver eneste BP-konto per stasjon — inkludert
// `5010 Faste lønninger`, som på en stasjon med én fastlønnet er én
// persons lønn. Den lå åpen for butikksjefen over PostgREST fra den
// dagen den ble skrevet, til `0204`.
//
// Det er samme form som `tenant_dekning.sql` fant for tabeller:
// **en ting som faller mellom stolene ser nøyaktig ut som en ting uten
// problemer.** Svaret er det samme: ingen får være uklassifisert.
//
// En ny seksjon her uten en linje i `SEKSJONER` gjør
// `seksjoner.test.ts` rød. Det er meningen — den koster ett minutt å
// klassifisere og kan ellers stå åpen i månedsvis.
// =====================================================================

/**
 * Hva butikksjefen får se av en seksjon.
 *
 * `ja`          — hele seksjonen, for egne stasjoner.
 * `nei`         — ingenting. Policyen må ha en `seksjon <> '...'`-arm.
 * `hvitlistet`  — deler av den, etter en regel i policyen (i dag: `begrep`).
 */
export type Seksjonstilgang = 'ja' | 'nei' | 'hvitlistet'

export type Seksjonspost = {
  tilgang: Seksjonstilgang
  /** Hvorfor. En klassifisering uten begrunnelse er en gjetning. */
  hvorfor: string
}

export const SEKSJONER: Record<string, Seksjonspost> = {
  omsetning: {
    tilgang: 'ja',
    hvorfor: 'Butikksjefens eget salg per avdeling. Drivstoff og pant '
      + 'holdes utenfor i visningen (SKJUL_OMS_KODER), ikke i policyen — '
      + 'det er en produktregel om hva som er butikkdrift, ikke en grense.',
  },
  bruttofortjeneste: {
    tilgang: 'ja',
    hvorfor: 'Butikksjefen har ingen resultatlinje å måles på; brutto er '
      + 'det nærmeste hun kommer, og hele /regnskap hviler på den.',
  },
  driftskostnader: {
    tilgang: 'hvitlistet',
    hvorfor: 'Bare kostnadene hun kan påvirke. Hvitlista står i `begrep` '
      + 'og ikke i kode (0203): 628 betydde «Leie driftsmidler» før '
      + 'februar 2026, så en grense i tall viser leasing som renovasjon '
      + 'på hver rad fra den gamle epoken. `begrep is null` faller '
      + 'utenfor — ukjent betyr skjult.',
  },
  resultat: {
    tilgang: 'nei',
    hvorfor: 'Stasjonens bunnlinje er eierens. Den bærer royalty, FSA, '
      + 'husleie og finans — alt butikksjefen ikke rår over, og å måle '
      + 'henne på den ville vært å be henne fikse noe hun ikke styrer.',
  },
  nokkeltall: {
    tilgang: 'ja',
    hvorfor: 'St1s egne nøkkeltall per stasjon: timer, timesats, lønns% '
      + 'av omsetning. Det ER butikksjefens styringstall, og «Timelønn - '
      + 'antall timer» er eneste sted faktiske timer finnes i rapporten.',
  },
  bp_omsetning: {
    tilgang: 'ja',
    hvorfor: 'BP-ens salgsbudsjett per varegruppe for måneder som ennå '
      + 'ikke er avlagt. Butikksjefen leser den ekte: /salg og '
      + 'ukebriefen henter `seksjon in (omsetning, bp_omsetning)` for å '
      + 'vise hva måneden skulle gitt.',
  },
  bp_bruttofortjeneste: {
    tilgang: 'ja',
    hvorfor: 'Samme som bp_omsetning, for brutto. Butikksjefen måles på '
      + 'brutto, så budsjettet for en åpen måned hører til på hennes side.',
  },
  bp_kostnad: {
    tilgang: 'nei',
    hvorfor: 'BÆRER HVER BP-KONTO PER STASJON — 5010 Faste lønninger, '
      + '6312 Royalty, husleie, forsikring. På en stasjon med én '
      + 'fastlønnet er 5010 én persons lønn. Robert: «butikksjefene skal '
      + 'aldri se noe annet enn total lønnsbudsjett. aldri budsjett på '
      + 'fastlønn.» Stengt i 0204. Ingen butikksjefflate leser den: '
      + '/lonnskost henter BP fra `bp_linje` (0155), som er eierens alene.',
  },
}

/** Seksjonene som skal ha en `seksjon <> '...'`-arm i policyen. */
export function stengteSeksjoner(): string[] {
  return Object.entries(SEKSJONER)
    .filter(([, p]) => p.tilgang === 'nei')
    .map(([n]) => n)
    .sort()
}
