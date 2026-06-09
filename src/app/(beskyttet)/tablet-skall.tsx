import Link from 'next/link'
import type { AktivAnsatt } from '@/lib/ansatt'
import { TabletNav } from './tablet-nav'
import { Vakt } from './vakt'

// Tablet-skallet — «egen verden» for den delte stasjonskontoen (mørk, stor,
// berøringsvennlig). Andre roller får aldri denne layouten.
export function TabletSkall({
  children,
  aktivAnsatt,
  uleste,
}: {
  children: React.ReactNode
  aktivAnsatt: AktivAnsatt | null
  uleste: number
}) {
  return (
    <div className="tablet">
      <header className="tablet-topp">
        <span className="tablet-merke">Sentiqa</span>
        <div className="tablet-topp-hoyre">
          <Vakt aktiv={aktivAnsatt} />
          <Link href="/varsler" className="klokke-lenke" aria-label="Varsler">
            🔔{uleste > 0 && <span className="varsel-teller">{uleste}</span>}
          </Link>
        </div>
      </header>
      <TabletNav />
      <main className="tablet-innhold">{children}</main>
    </div>
  )
}
