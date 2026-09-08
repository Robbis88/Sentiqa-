// =====================================================================
// EN KONTO ST1 HAR LAGT TIL, OG VI IKKE VET NAVNET PÅ
//
// Kontoplanen står som `KONTO_NAVN` i `src/lib/parsere/regnskap.ts`.
// Møter parseren en kode som ikke står der, skriver den `Konto 739` som
// posttekst og går videre. Ingen får vite det.
//
// Sonden mot produksjon 2026-09-08 fant to slike — `739` og `745`. De er
// på 0 og 512 kroner, altså uten betydning i seg selv. **Mekanismen er
// det ikke.**
//
// Fra `0192` er `BUTIKKSJEF_KOSTNAD_KODER` en RLS-grense, ikke bare et
// visningsfilter. En ukjent konto havner da automatisk på eierens side —
// og det er riktig som standard, siden vi ikke vet hva den er. Men legger
// St1 til en konto butikksjefen SKAL kunne påvirke, blir den usynlig for
// hen uten at noe sier fra. Da er utfallet av en tenantregel avgjort av
// at ingen oppdaterte en oppslagstabell.
//
// Samme form som `hoppetNotat`, `utenEan` og stasjonsdekningen: en stille
// utelatelse er verre enn en synlig merknad.
// =====================================================================

/** Posten parseren skriver når kontoplanen ikke kjenner koden. */
const FALLBACK = /^Konto \d+$/

type Linje = { seksjon?: unknown; kode?: unknown; post?: unknown }

/**
 * Kodene i settet som parseren ikke fant navn til.
 *
 * Leser POSTTEKSTEN, ikke kontoplanen. Da kan denne bo utenfor parseren
 * uten å duplisere lista — og den følger automatisk med når noen legger
 * til et navn.
 */
export function ukjenteKontoer(linjer: readonly Linje[]): string[] {
  const ut = new Set<string>()
  for (const l of linjer) {
    if (l.seksjon !== 'driftskostnader') continue
    if (typeof l.post !== 'string' || !FALLBACK.test(l.post)) continue
    if (typeof l.kode === 'string' && l.kode) ut.add(l.kode)
  }
  return [...ut].sort()
}

/**
 * Merknaden, eller null når alle kontoene har navn.
 *
 * NAVNGIR KODENE, ikke bare antallet — samme grunn som i `hoppede.ts`:
 * «2 ukjente kontoer» tvinger leseren til å gjette hvilke, og da blir
 * merknaden noe man ser bort fra.
 */
export function ukjentKontoNotat(koder: readonly string[]): string | null {
  if (koder.length === 0) return null
  const liste = koder.join(', ')
  return `Kontoplanen kjenner ikke ${koder.length === 1 ? 'konto' : 'kontoene'} `
    + `${liste}. Linjene er lagret, men står som «Konto ${koder[0]}» i stedet `
    + 'for et navn — og en ukjent konto regnes som eierens, altså skjult for '
    + 'butikksjefen (0192). Er den noe butikksjefen skal kunne påvirke, må den '
    + 'inn i KONTO_NAVN og i BUTIKKSJEF_DRIFT_KODER.'
}
