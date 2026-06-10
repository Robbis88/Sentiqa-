'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useState } from 'react'

type Seksjon = { tittel: string; punkter: { sti: string; tekst: string }[] }

export function Sidemeny({ seksjoner }: { seksjoner: Seksjon[] }) {
  const [apen, setApen] = useState(false)
  const sti = usePathname()

  return (
    <>
      <button className="meny-hamburger" aria-label="Åpne meny" onClick={() => setApen(true)}>☰</button>
      {apen && <div className="meny-overlay" onClick={() => setApen(false)} aria-hidden />}

      <aside className={`sidemeny ${apen ? 'apen' : ''}`}>
        <div className="merke">Sentiqa</div>
        <nav>
          {seksjoner.map((s) => (
            <div className="meny-seksjon" key={s.tittel || 'topp'}>
              {s.tittel ? <span className="meny-tittel">{s.tittel}</span> : null}
              {s.punkter.map((p) => (
                <Link
                  key={p.sti}
                  href={p.sti}
                  aria-current={sti === p.sti ? 'page' : undefined}
                  onClick={() => setApen(false)}
                >
                  {p.tekst}
                </Link>
              ))}
            </div>
          ))}
        </nav>
        <div className="meny-bunn">
          <span>R-G Invest AS</span>
          <span>Org.nr 937 861 621</span>
        </div>
      </aside>
    </>
  )
}
