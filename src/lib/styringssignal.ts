// =====================================================================
// `redirect()` og `notFound()` er ikke feil. De er styringssignaler.
//
// Begge kaster med vilje, og Next kjenner dem igjen paa `digest`. Fanger
// en klient dem i en vanlig `catch`, skjer det motsatte av det som var
// meningen: navigeringen uteblir, og brukeren faar en feilmelding om
// noe som ikke er feil.
//
// SLIK SAA DET UT. AI-boblen hadde `catch { ... 'Noe gikk galt' }` rundt
// serverhandlingen. Naar sesjonen loep ut, gjorde `hentInnloggetBruker()`
// `redirect('/logg-inn')` - og boblen svarte «Noe gikk galt. Prøv
// igjen.» Brukeren proevde igjen. Samme svar. Ingen vei ut, og
// ingenting i loggen: en redirect logges paa `info`, ikke som feil.
//
// Robert brukte en halvtime paa aa feilsoeke en assistent som virket,
// men som ikke fikk vite hvem han var.
// =====================================================================

/** Sant for feil Next bruker som styringssignal (redirect, notFound). */
export function erStyringssignal(e: unknown): boolean {
  const digest = (e as { digest?: unknown } | null)?.digest
  return typeof digest === 'string'
    && (digest.startsWith('NEXT_REDIRECT') || digest === 'NEXT_NOT_FOUND')
}

/**
 * Kaster videre hvis feilen er et styringssignal. Kall den foerst i
 * enhver `catch` rundt en serverhandling — ellers spiser fangsten
 * navigeringen.
 */
export function slippStyringssignal(e: unknown): void {
  if (erStyringssignal(e)) throw e
}
