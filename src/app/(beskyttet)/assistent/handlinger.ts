'use server'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { kjorAssistent, type Melding, type AssistentSvar } from '@/lib/ai/assistent'

// Chatbot er ikke for tablet-brukere (§8: ingen AI-tilgang der).
export async function spørAssistent(
  historikk: Melding[],
  melding: string,
): Promise<AssistentSvar> {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'butikkbruker_tablet' || bruker.rolle === 'plattform_redaktor') {
    return { svar: 'Du har ikke tilgang til AI-assistenten.', kilder: [] }
  }
  return kjorAssistent(bruker, historikk.slice(-10), melding)
}
