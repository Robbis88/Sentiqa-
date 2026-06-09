import Link from 'next/link'
import type { AktivAnsatt } from '@/lib/ansatt'
import { loggUt } from '@/lib/auth/handlinger'
import { TabletNav } from './tablet-nav'
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
}: {
  children: React.ReactNode
  aktivAnsatt: AktivAnsatt | null
  uleste: number
  sprak: string
}) {
  return (
    <div className="tablet">
      <AutoRefresh sekunder={30} />
      <header className="tablet-topp">
        <span className="tablet-merke">Sentiqa</span>
        <div className="tablet-topp-hoyre">
          <SprakVelger aktiv={sprak} />
          <Vakt aktiv={aktivAnsatt} />
          <Link href="/varsler" className="klokke-lenke" aria-label="Varsler">
            🔔{uleste > 0 && <span className="varsel-teller">{uleste}</span>}
          </Link>
          <form action={loggUt}>
            <button type="submit" className="tablet-utlogg">Logg ut</button>
          </form>
        </div>
      </header>
      <TabletNav />
      <main className="tablet-innhold">{children}</main>
    </div>
  )
}
