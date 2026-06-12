'use client'
import { useRouter } from 'next/navigation'

// Kompakt nedtrekks-velger for stasjon. Navigerer med query-param og beholder
// øvrige parametre (dato/periode). Brukes på /salg og /regnskap.
export function StasjonsVelger({
  stasjoner,
  valgtId,
  basePath,
  bevar = {},
  param = 'stasjon',
}: {
  stasjoner: { id: string; navn: string }[]
  valgtId: string | null
  basePath: string
  bevar?: Record<string, string>
  param?: string
}) {
  const router = useRouter()

  function bytt(verdi: string) {
    const p = new URLSearchParams(bevar)
    if (verdi) p.set(param, verdi)
    const qs = p.toString()
    router.push(qs ? `${basePath}?${qs}` : basePath)
  }

  return (
    <label className="stasjonsvelger">
      <span>📍 Stasjon</span>
      <select value={valgtId ?? ''} onChange={(e) => bytt(e.target.value)}>
        <option value="">Alle stasjoner samlet</option>
        {stasjoner.map((s) => (
          <option key={s.id} value={s.id}>{s.navn}</option>
        ))}
      </select>
    </label>
  )
}
