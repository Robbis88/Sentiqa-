import Link from 'next/link'
import type { AktivAnsatt } from '@/lib/ansatt'
import { loggUt } from '@/lib/auth/handlinger'
import { TabletNav } from './tablet-nav'
import { Bjelle } from './ikoner'
import { Vakt } from './vakt'
import { SprakVelger } from './sprak-velger'
import { AutoRefresh } from './auto-refresh'

// Tablet-skallet — «egen verden» for den delte stasjonskontoen (mørk, stor,
// berøringsvennlig). Andre roller får aldri denne layouten.
export function TabletSkall({
  children,
  aktivAnsatt,
  uleste,
  sprak,
  ord = {},
}: {
  children: React.ReactNode
  aktivAnsatt: AktivAnsatt | null
  uleste: number
  sprak: string
  ord?: Record<string, string>
}) {
  return (
    <div className="tablet">
      <AutoRefresh sekunder={30} />
      <header className="tablet-topp">
        <span className="tablet-merke">Sentiqa</span>
        <div className="tablet-topp-hoyre">
          <SprakVelger aktiv={sprak} />
          <Vakt aktiv={aktivAnsatt} />
          {/* Bjella er ET EKTE IKON - den staar alene, uten ord ved
              siden av, og maa derfor vaere en form og ikke en emoji.
              `Bjelle` finnes fra trinn 02B og arver flatens farge, saa
              den virker paa nettbrettets moerke skall like godt som paa
              lederens lyse toppstripe. En emoji har sine egne farger. */}
          <Link href="/varsler" className="klokke-lenke" aria-label={ord['Varsler'] ?? 'Varsler'}>
            <Bjelle />
            {uleste > 0 && <span className="varsel-teller">{uleste}</span>}
          </Link>
          <form action={loggUt}>
            <button type="submit" className="tablet-utlogg primar">{ord['Logg ut'] ?? 'Logg ut'}</button>
          </form>
        </div>
      </header>
      <TabletNav />
      <main className="tablet-innhold">{children}</main>
    </div>
  )
}
