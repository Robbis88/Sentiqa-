import type { InnloggetBruker } from '@/lib/auth/typer'
import type { Scope } from './scope'

/** Deterministisk presentasjonstekst oppå samme backend-avvisning. */
export function erStigBønesOgSpørUtenfor(
  bruker: InnloggetBruker,
  scope: Scope | undefined,
  melding: string,
): boolean {
  if (bruker.rolle !== 'butikksjef' || !/^stig(?:\s|$)/i.test(bruker.fulltNavn?.trim() ?? '')) return false
  if (!scope?.stasjoner.some((s) => /bønes|bones/i.test(s.navn))) return false
  return /\bdale\b|\badministrat(?:or|iv|ion)?\b|\badmin\b/i.test(melding)
}
