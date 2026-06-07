'use client'
import { useActionState } from 'react'
import { lastOppFaktura, type FakturaTilstand } from './handlinger'

export function Opplaster({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<FakturaTilstand, FormData>(
    lastOppFaktura,
    undefined,
  )

  return (
    <form action={handling} className="stasjon-skjema">
      <label className="felt">
        <span>Faktura (PDF/bilde)</span>
        <input type="file" name="faktura" accept=".pdf,image/png,image/jpeg" required />
      </label>
      <label className="felt">
        <span>Stasjon (valgfri)</span>
        <select name="stasjon_id" defaultValue="">
          <option value="">(ingen / felles)</option>
          {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
        </select>
      </label>
      <button type="submit" disabled={venter}>{venter ? 'Leser faktura …' : 'Last opp & les'}</button>
      {tilstand?.ok ? <p className="ok" role="status">Lest: {tilstand.leverandor}.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
