'use client'
import { usePathname } from 'next/navigation'
import { Faner } from '@/components/ui/faner'
import { FANEGRUPPER, type Punkt } from './navigasjon'
import type { Brukerrolle } from '@/lib/auth/typer'

// =====================================================================
// Fanene, tegnet i layoutet — ikke i hver side.
//
// Alternativet var å legge <Faner> i femten sider. Det ville vært femten
// steder å glemme det, og dypere sider som /rutiner/oppsett/[id] ville
// mistet fanerada uten at noen la merke til det.
//
// Her regnes gruppen ut fra stien, og siden trenger ikke vite at den er
// en fane i det hele tatt.
// =====================================================================

/** Gruppen stien hører til — lengste treff, så /rutiner ikke slår /rutiner/oppsett. */
function gruppeFor(sti: string) {
  let beste: { tittel: string; faner: Punkt[] } | null = null
  let lengde = -1
  for (const g of FANEGRUPPER) {
    for (const f of g.faner) {
      if ((sti === f.sti || sti.startsWith(`${f.sti}/`)) && f.sti.length > lengde) {
        beste = g
        lengde = f.sti.length
      }
    }
  }
  return beste
}

export function Fanerad({ rolle }: { rolle: Brukerrolle }) {
  const sti = usePathname() ?? ''
  const gruppe = gruppeFor(sti)
  if (!gruppe) return null

  const mine = gruppe.faner.filter((f) => f.roller.includes(rolle))
  // Én fane er ikke faner. Da er det bare en side, og en fanerad med ett
  // valg er støy som later som den er navigasjon.
  if (mine.length < 2) return null

  return <Faner faner={mine.map((f) => ({ sti: f.sti, tekst: f.tekst }))} />
}
