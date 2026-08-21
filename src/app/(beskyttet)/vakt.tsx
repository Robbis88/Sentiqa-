'use client'
import { useActionState } from 'react'
import { checkInn, checkUt, type VaktTilstand } from './vakt-handlinger'

export function Vakt({ aktiv }: { aktiv: { id: string; navn: string } | null }) {
  const [tilstand, handling, venter] = useActionState<VaktTilstand, FormData>(checkInn, undefined)

  if (aktiv) {
    return (
      <div className="vakt">
        <span className="vakt-navn">{aktiv.navn}</span>
        <form action={checkUt}><button type="submit" className="liten">Logg av</button></form>
      </div>
    )
  }
  return (
    <form action={handling} className="vakt">
      <input name="pin" inputMode="numeric" maxLength={6} placeholder="PIN" aria-label="PIN" className="vakt-pin" />
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Vakt'}</button>
      {tilstand?.feil ? <span className="vakt-feil">{tilstand.feil}</span> : null}
    </form>
  )
}
