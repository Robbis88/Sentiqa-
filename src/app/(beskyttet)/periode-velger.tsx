'use client'
import { useRouter } from 'next/navigation'
import type { PeriodeGruppe } from '@/lib/perioder'

// Nedtrekksvelger for regnskapsperiode, gruppert på år (<optgroup>). Navigerer
// med ?periode= og beholder øvrige parametre. Samme stil som StasjonsVelger.
export function PeriodeVelger({
  valgt, grupper, basePath, bevar = {},
}: {
  valgt: string
  grupper: PeriodeGruppe[]
  basePath: string
  bevar?: Record<string, string>
}) {
  const router = useRouter()
  function bytt(verdi: string) {
    const p = new URLSearchParams(bevar)
    p.set('periode', verdi)
    router.push(`${basePath}?${p.toString()}`)
  }
  return (
    <label className="stasjonsvelger">
      <span>📅 Periode</span>
      <select value={valgt} onChange={(e) => bytt(e.target.value)}>
        {grupper.map((g) => (
          <optgroup key={g.aar} label={g.aar}>
            {g.valg.map((v) => <option key={v.verdi} value={v.verdi}>{v.navn}</option>)}
          </optgroup>
        ))}
      </select>
    </label>
  )
}
