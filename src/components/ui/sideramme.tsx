import type { ReactNode } from 'react'

/**
 * Innholdsspalten på en side.
 *
 * =====================================================================
 * DEN TAR IKKE IMOT EN BREDDE, OG DET ER HELE POENGET
 * =====================================================================
 *
 * Før denne fantes, falt sidebredden ut av om siden tilfeldigvis brukte
 * `className="kort"`: `.innhold .kort { max-width: 880px }` var den eneste
 * breddereglen i systemet. Målt over alle 71 sider var bare ett av åtte
 * mønstre entydig — `/analyse` var smal og `/salg` bred uten at noen hadde
 * bestemt det. Se `SPALTE` i `src/lib/redesign/monstre.ts` for tallene.
 *
 * Bredden bestemmes derfor av rutens mønster, ikke av siden. Skallet leser
 * `monsterFor(sti)` og setter `data-bredde` på `.innhold`; rammen leser den
 * gjennom `--sq-spalte`. En side som vil være «litt bredere» har ingen
 * knapp å trykke på — den må endre mønsteret sitt, og da endrer den det for
 * alle sider av samme sort. Det er meningen.
 *
 * Rammen eier også den vertikale rytmen (`gap`), slik at avstanden mellom
 * seksjoner er den samme uansett om siden bruker kort, tabeller eller rå
 * elementer. Kort inni rammen får derfor verken egen maksbredde eller egen
 * toppmarg — begge deler ville lagt seg oppå rammens.
 */
export function Sideramme({ children }: { children: ReactNode }) {
  return <div className="sq-sideramme">{children}</div>
}
