'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useState } from 'react'

type Seksjon = { tittel: string; punkter: { sti: string; tekst: string }[] }

// Progressiv avdekking: gruppen du står i er åpen, resten er foldet sammen.
// Med 32 punkter synlig samtidig blir menyen en innholdsfortegnelse man må
// lese; med én gruppe åpen blir den et sted man er.
//
// Overstyring per gruppe huskes i økten, så den som vil ha alt åpent får det.
export function Sidemeny({ seksjoner }: { seksjoner: Seksjon[] }) {
  const [apen, setApen] = useState(false)
  const [overstyrt, setOverstyrt] = useState<Record<string, boolean>>({})
  const sti = usePathname()

  const inneholderAktiv = (s: Seksjon) =>
    s.punkter.some((p) => sti === p.sti || sti.startsWith(`${p.sti}/`))
  const erApen = (s: Seksjon) => overstyrt[s.tittel] ?? inneholderAktiv(s)

  return (
    <>
      <button className="meny-hamburger" aria-label="Åpne meny" onClick={() => setApen(true)}>☰</button>
      {apen && <div className="meny-overlay" onClick={() => setApen(false)} aria-hidden />}

      <aside className={`sidemeny ${apen ? 'apen' : ''}`}>
        <div className="merke">Sentiqa</div>
        <nav>
          {seksjoner.map((s) => {
            const lenker = s.punkter.map((p) => (
              <Link
                key={p.sti}
                href={p.sti}
                aria-current={sti === p.sti ? 'page' : undefined}
                onClick={() => setApen(false)}
              >
                {p.tekst}
              </Link>
            ))

            // Gruppen uten tittel (I dag) er alltid synlig — den er startpunktet.
            if (!s.tittel) {
              return <div className="meny-seksjon" key="topp">{lenker}</div>
            }

            const vis = erApen(s)
            return (
              <div className={`meny-seksjon ${vis ? 'apen' : ''}`} key={s.tittel}>
                <button
                  type="button"
                  className="meny-tittel"
                  aria-expanded={vis}
                  onClick={() => setOverstyrt((o) => ({ ...o, [s.tittel]: !vis }))}
                >
                  <span>{s.tittel}</span>
                  <svg className="meny-pil" width="10" height="10" viewBox="0 0 10 10" aria-hidden="true">
                    <path d="M3.2 1.8 6.6 5 3.2 8.2" fill="none" stroke="currentColor"
                      strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </button>
                {vis ? lenker : null}
              </div>
            )
          })}
        </nav>
        <div className="meny-bunn">
          <span>R-G Invest AS</span>
          <span>Org.nr 937 861 621</span>
        </div>
      </aside>
    </>
  )
}
