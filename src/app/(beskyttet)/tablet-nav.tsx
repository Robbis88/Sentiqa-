'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useT } from './oversett-kontekst'
import { TABLETMENY } from './navigasjon'

// Listen bor i navigasjon.ts, sammen med resten av navigasjonen. Da ser
// vakthunden den, og et tap her kan ikke gaa upaaaktet hen.
const FANER = TABLETMENY

export function TabletNav() {
  const sti = usePathname()
  const t = useT()
  return (
    <nav className="tablet-nav">
      {FANER.map((f) => {
        const aktiv = sti === f.sti || (f.sti !== '/oversikt' && sti.startsWith(f.sti))
        return (
          <Link key={f.sti} href={f.sti} className={`tablet-fane ${aktiv ? 'aktiv' : ''}`}>
            <span className="tablet-fane-tekst">{t(f.tekst)}</span>
          </Link>
        )
      })}
    </nav>
  )
}
