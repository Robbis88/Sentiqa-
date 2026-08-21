// =====================================================================
// Design-skrallen: tallene får aldri gå opp.
//
// Redesignet ga systemet ett formspråk. Det som får det til å skli fra
// hverandre igjen er ikke store beslutninger — det er nitti små: en
// inline-stil her, en rå tabell der, en emoji som forklarer noe raskere
// enn et ord. Hver enkelt er forsvarlig. Summen er fem selskaper.
//
// HVORFOR SKRALLE OG IKKE PORT: da denne ble skrevet stod tellingen på
// 90 inline-stiler, 54 rå tabeller og 4 bruk av Datatabell. En PASS/FAIL-
// port ville vært rød dag én, og en rød port som ikke kan bli grønn blir
// skrudd av innen uka. Skrallen låser dagens tall og forbyr at de
// vokser. Da konvergerer systemet i stedet for å sklire, og tallrekka i
// git viser hvilken vei det går.
//
// Samme mekanisme som fasit.json — ny dimensjon.
// =====================================================================

export type Designmaal = {
  /** `style={{ … }}` — skal være tokens i CSS, ikke tall i JSX. */
  inlineStil: number
  /** Emoji som ikonografi. Forbudt siden 2026-08-13. */
  emoji: number
  /** `<table>` utenom Datatabell, som løser rulling og tom tilstand. */
  raaTabell: number
  /** `<h1>` utenom Sidehode. */
  raaH1: number
  /** Hardkodet farge. Skal komme fra `var(--…)`. */
  hexFarge: number
}

export const SIGNALER = [
  'inlineStil', 'emoji', 'raaTabell', 'raaH1', 'hexFarge',
] as const

/**
 * Fjerner kommentarer, men ikke strenger.
 *
 * Må gjøres før måling, av to grunner som trekker hver sin vei:
 *
 * DOKUMENTASJON SKAL IKKE STRAFFES. Da emojiene ble fjernet i dag, ble
 * det skrevet kommentarer om hva som sto der før — med emojien i. En
 * teller som leser kommentarer ville meldt dem som brudd, og dermed
 * gjort det dyrere å forklare enn å slette i stillhet.
 *
 * OG DEN MÅ IKKE GJØRE SEG BLIND. En naiv `//`-stripping spiser resten
 * av linja fra `https://` inne i en href. Da synker tallene, alt ser
 * bedre ut, og skrallen har sluttet å se. Derfor en liten tilstands-
 * maskin som kjenner forskjell på en skråstrek i kode og en i tekst.
 */
export function utenKommentarer(kilde: string): string {
  let ut = ''
  let i = 0
  type Modus = 'kode' | 'enkel' | 'dobbel' | 'backtick' | 'linje' | 'blokk'
  let modus: Modus = 'kode'

  while (i < kilde.length) {
    const c = kilde[i]
    const neste = kilde[i + 1]

    if (modus === 'kode') {
      if (c === '/' && neste === '/') { modus = 'linje'; i += 2; continue }
      if (c === '/' && neste === '*') { modus = 'blokk'; i += 2; continue }
      if (c === "'") modus = 'enkel'
      else if (c === '"') modus = 'dobbel'
      else if (c === '`') modus = 'backtick'
      ut += c
      i++
      continue
    }

    if (modus === 'linje') {
      if (c === '\n') { modus = 'kode'; ut += c }
      i++
      continue
    }

    if (modus === 'blokk') {
      if (c === '*' && neste === '/') { modus = 'kode'; i += 2; continue }
      // Behold linjeskift, ellers kollapser linjenumre i feilmeldinger.
      if (c === '\n') ut += c
      i++
      continue
    }

    // Inne i en streng. Escape-tegn hopper over neste tegn, så en
    // apostrof i «it\'s» ikke avslutter strengen.
    if (c === '\\') { ut += c + (neste ?? ''); i += 2; continue }
    if ((modus === 'enkel' && c === "'")
      || (modus === 'dobbel' && c === '"')
      || (modus === 'backtick' && c === '`')) modus = 'kode'
    ut += c
    i++
  }

  return ut
}

/**
 * Emoji, men ikke funksjonelle glyffer.
 *
 * Kryss (✕), hake (✓) og dra-håndtak (⠿) er beholdt med vilje — de gjør
 * en jobb ord ikke gjør på en knapp.
 *
 * DEN FØRSTE UTGAVEN VAR HALVBLIND, og det er verdt å skrive ned
 * hvorfor. Den lette etter surrogatpar (emoji utenfor BMP) eller
 * variasjonsvelgeren U+FE0F, og antok at alt annet var typografi. Men
 * en håndfull emoji er ETT kodepunkt inne i BMP, med emoji-utseende som
 * standard, uten å be om det: ✅ (U+2705) og ❗ (U+2757) er begge slike.
 * De sto på nettbrettet gjennom hele bølge 5 mens tellingen sa null —
 * og ❗ bar alvor helt alene, som symbol, uten ord ved siden av.
 *
 * Unicode har allerede navnet på skillet vi mente. `Emoji_Presentation`
 * er «tegnes som emoji uten å be om det», så vi slipper å gjette på
 * kodepunktområder:
 *
 *   \p{Emoji_Presentation}           🥐 😣 ✅ ❗ — emoji av natur
 *   \p{Extended_Pictographic}\uFE0F  ⚠️ ✉️     — tekst som ber om emoji
 *
 * ✓ ✕ ▲ ▼ ↩ › er piktografiske eller typografiske, men har
 * Emoji_Presentation=No og ingen U+FE0F. De står, som før.
 */
const EMOJI = /\p{Emoji_Presentation}|\p{Extended_Pictographic}\uFE0F/gu

export function maal(kilde: string): Designmaal {
  const k = utenKommentarer(kilde)
  const tell = (re: RegExp) => (k.match(re) ?? []).length
  return {
    inlineStil: tell(/style=\{\{/g),
    emoji: tell(EMOJI),
    raaTabell: tell(/<table\b/g),
    raaH1: tell(/<h1\b/g),
    hexFarge: tell(/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/g),
  }
}

export function summer(alle: Designmaal[]): Designmaal {
  return alle.reduce((a, m) => ({
    inlineStil: a.inlineStil + m.inlineStil,
    emoji: a.emoji + m.emoji,
    raaTabell: a.raaTabell + m.raaTabell,
    raaH1: a.raaH1 + m.raaH1,
    hexFarge: a.hexFarge + m.hexFarge,
  }), { inlineStil: 0, emoji: 0, raaTabell: 0, raaH1: 0, hexFarge: 0 })
}

/** Signalene som har vokst. Tom = alt i orden. */
export function vokst(
  fasit: Designmaal,
  naa: Designmaal,
): { signal: string; fra: number; til: number }[] {
  return SIGNALER
    .filter((s) => naa[s] > fasit[s])
    .map((s) => ({ signal: s, fra: fasit[s], til: naa[s] }))
}
