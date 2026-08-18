'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

// =====================================================================
// Faner mellom sider som hører sammen.
//
// Dette er IKKE klienttilstand. Hver fane er en ekte rute, og fanen er
// en lenke. Det er hele poenget:
//
//   /rutiner, /rutiner/min, /rutiner/oversikt og /rutiner/oppsett er
//   fire menypunkter i dag. De er én ting sett fra fire vinkler.
//
// Som faner blir de ett menypunkt — men rutene består, dyplenker virker,
// og vakthunden ser at ingenting forsvant. Menyen faller fra 48 til
// rundt 28 uten at systemet mister en eneste side.
//
// Hadde fanene vært tilstand i stedet for ruter, hadde vi byttet fire
// synlige sider mot én side med skjult innhold. Det er ikke det samme.
// =====================================================================

export type Fane = {
  sti: string
  tekst: string
  /** Tall ved siden av navnet — «3» på en fane som krever noe. */
  antall?: number
}

/**
 * Hvilken fane er aktiv?
 *
 * Lengste treff vinner. Ellers ville `/rutiner` vært aktiv samtidig som
 * `/rutiner/oppsett`, siden den ene er prefiks av den andre — og to
 * markerte faner er verre enn ingen.
 */
export function aktivFane(stier: string[], sti: string): string | null {
  const treff = stier
    .filter((s) => sti === s || sti.startsWith(`${s}/`))
    .sort((a, b) => b.length - a.length)
  return treff[0] ?? null
}

export function Faner({ faner }: { faner: Fane[] }) {
  const sti = usePathname()
  const aktiv = aktivFane(faner.map((f) => f.sti), sti ?? '')

  return (
    // role=tablist ville lovet piltast-navigasjon som lenker ikke gir.
    // Dette ER en navigasjon, og skjermlesere skal få vite nettopp det.
    <nav className="sq-faner" aria-label="Underområder">
      {faner.map((f) => (
        <Link
          key={f.sti}
          href={f.sti}
          className={`sq-fane${f.sti === aktiv ? ' aktiv' : ''}`}
          aria-current={f.sti === aktiv ? 'page' : undefined}
        >
          {f.tekst}
          {f.antall !== undefined && f.antall > 0 && (
            <span className="sq-fane-antall">{f.antall}</span>
          )}
        </Link>
      ))}
    </nav>
  )
}
