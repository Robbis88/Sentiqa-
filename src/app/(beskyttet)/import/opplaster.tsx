'use client'
import { useActionState } from 'react'
import { lastOppFiler, type OpplastingTilstand } from './handlinger'

export function Opplaster() {
  const [tilstand, handling, venter] = useActionState<OpplastingTilstand, FormData>(
    lastOppFiler,
    undefined,
  )

  return (
    <form action={handling} className="opplaster">
      <input
        type="file"
        name="filer"
        multiple
        accept=".csv,.txt,.xlsx,.xls,.pdf"
        required
      />
      <button type="submit" disabled={venter}>
        {venter ? 'Laster opp …' : 'Last opp'}
      </button>

      {tilstand?.ok === true ? (
        <div role="status">
          <p className="ok">
            {tilstand.antall} fil(er) mottatt – venter på behandling
            {tilstand.hoppet > 0 ? ` · ${tilstand.hoppet} hoppet over (allerede lastet opp)` : ''}.
          </p>
          {tilstand.feilet.length > 0 ? (
            <p className="feil">{tilstand.feilet.length} fil(er) feilet: {tilstand.feilet.join('; ')}</p>
          ) : null}
        </div>
      ) : null}
      {tilstand?.ok === false ? (
        <p className="feil" role="alert">
          {tilstand.feil}
        </p>
      ) : null}
    </form>
  )
}
