'use client'
import { useActionState } from 'react'
import { leggTilSjekkpunkt, type SjekkTilstand } from './handlinger'

export function NyttSjekkpunkt({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<SjekkTilstand, FormData>(
    leggTilSjekkpunkt,
    undefined,
  )

  return (
    <form action={handling} className="stasjon-skjema">
      <label className="felt">
        <span>Stasjon</span>
        <select name="stasjon_id" required defaultValue="">
          <option value="" disabled>Velg …</option>
          {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
        </select>
      </label>
      <label className="felt">
        <span>Spørsmål</span>
        <input name="sporsmaal" placeholder="Er diskene fulle?" required />
      </label>
      <label className="felt">
        <span>Klokkeslett</span>
        <input name="klokkeslett" type="time" />
      </label>
      <label className="felt avkryss">
        <input type="checkbox" name="kritisk" />
        <span>Kritisk</span>
      </label>
      <button type="submit" disabled={venter} className="primar">{venter ? 'Lagrer …' : 'Legg til'}</button>
      {tilstand?.ok ? <p className="ok" role="status">Sjekkpunkt lagt til.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
