import { SPRAK } from '@/lib/sprak'
import { setSprak } from './sprak-handlinger'

export function SprakVelger({ aktiv }: { aktiv: string }) {
  return (
    <div className="sprak-velger">
      {SPRAK.map((s) => (
        <form action={setSprak} key={s.kode}>
          <input type="hidden" name="kode" value={s.kode} />
          <button type="submit" className={`sprak-flagg ${aktiv === s.kode ? 'aktiv' : ''}`} title={s.navn} aria-label={s.navn}>
            {s.flagg}
          </button>
        </form>
      ))}
    </div>
  )
}
