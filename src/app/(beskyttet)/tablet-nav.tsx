'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useT } from './oversett-kontekst'

const FANER = [
  { sti: '/oversikt', tekst: 'Hjem', ikon: '🏠' },
  { sti: '/rutiner', tekst: 'Rutineskjema', ikon: '✅' },
  { sti: '/anvisninger', tekst: 'Anvisninger', ikon: '📖' },
  { sti: '/lenker', tekst: 'Lenker', ikon: '🔗' },
]

export function TabletNav() {
  const sti = usePathname()
  const t = useT()
  return (
    <nav className="tablet-nav">
      {FANER.map((f) => {
        const aktiv = sti === f.sti || (f.sti !== '/oversikt' && sti.startsWith(f.sti))
        return (
          <Link key={f.sti} href={f.sti} className={`tablet-fane ${aktiv ? 'aktiv' : ''}`}>
            <span className="tablet-fane-ikon">{f.ikon}</span>
            <span className="tablet-fane-tekst">{t(f.tekst)}</span>
          </Link>
        )
      })}
    </nav>
  )
}
