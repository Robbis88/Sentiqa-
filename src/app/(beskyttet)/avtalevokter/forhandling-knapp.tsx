'use client'
import { useState, useTransition } from 'react'
import { forhandling } from './handlinger'

export function ForhandlingKnapp({ leverandor }: { leverandor: string }) {
  const [venter, start] = useTransition()
  const [utkast, setUtkast] = useState<string | null>(null)

  return (
    <div className="forhandling">
      <button
        type="button"
        className="liten"
        disabled={venter}
        onClick={() =>
          start(async () => {
            const fd = new FormData()
            fd.set('leverandor', leverandor)
            const res = await forhandling(fd)
            setUtkast(res.ok ? (res.utkast ?? '') : `Feil: ${res.feil}`)
          })
        }
      >
        {venter ? 'Skriver …' : 'Forhandlings-utkast'}
      </button>
      {utkast != null && <textarea className="utkast" readOnly value={utkast} rows={12} />}
    </div>
  )
}
