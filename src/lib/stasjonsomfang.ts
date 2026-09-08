// =====================================================================
// ET TALL SOM SPENNER OVER FLERE STASJONER MÅ SI DET
//
// En butikksjef kan ha flere stasjoner. Leser en side en tabell med
// `stasjon_id` UTEN å filtrere, gir RLS alle stasjonene hen når — og
// tallet på skjermen blir en sum over dem.
//
// Det er ikke feil i seg selv. Det er feil når det ikke står noe sted.
// «12 svar · snitt 4,2» leses som «min stasjon», og en leder som
// sammenligner med det hen husker fra én butikk får et tall som ikke
// stemmer med noe.
//
// Samme familie som `SKJUL_OMS_KODER` og drivstoffet: to tall som ser
// sammenlignbare ut og ikke er det.
//
// ---------------------------------------------------------------------
// HVORFOR EN TEKST OG IKKE EN FILTRERING
//
// Fordi aggregatet ofte er RIKTIG. En butikksjef med tre stasjoner har
// ansvar for tre stasjoner, og pulsen for alle tre er det hen skal se.
// Å tvinge inn en stasjonsvelger overalt ville vært å svare på et
// spørsmål ingen stilte.
//
// Det som mangler er én setning om hva tallet dekker.
// =====================================================================

/**
 * Setningen som sier hva tallene dekker, eller `null` når det ikke er
 * noe å si.
 *
 * **Én stasjon gir null med vilje.** «Tallene dekker alle 1 stasjonene
 * dine» er støy, og en merknad som står der uansett slutter folk å
 * lese — samme grunn som at `hoppetNotat` er null når alt kom med.
 */
export function omfangstekst(antallStasjoner: number): string | null {
  if (antallStasjoner < 2) return null
  return `Tallene dekker alle ${antallStasjoner} stasjonene dine.`
}

/** Setter omfanget etter en undertittel, når det er noe å si. */
export function medOmfang(undertittel: string, antallStasjoner: number): string {
  const omfang = omfangstekst(antallStasjoner)
  return omfang ? `${undertittel} ${omfang}` : undertittel
}
