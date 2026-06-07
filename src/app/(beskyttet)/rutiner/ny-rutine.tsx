'use client'
import { useActionState } from 'react'
import { leggTilRutine, type RutineTilstand } from './handlinger'

export function NyRutine({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<RutineTilstand, FormData>(
    leggTilRutine,
    undefined,
  )

  return (
    <form action={handling} className="stasjon-skjema">
      <label className="felt">
        <span>Stasjon</span>
        <select name="stasjon_id" required defaultValue="">
          <option value="" disabled>Velg …</option>
          {stasjoner.map((s) => (
            <option key={s.id} value={s.id}>{s.navn}</option>
          ))}
        </select>
      </label>
      <label className="felt">
        <span>Tittel</span>
        <input name="tittel" placeholder="Tøm søppel" required />
      </label>
      <label className="felt">
        <span>Beskrivelse</span>
        <input name="beskrivelse" placeholder="(valgfri)" />
      </label>
      <label className="felt avkryss">
        <input type="checkbox" name="paakrevd_bilde" />
        <span>Krev bildebevis</span>
      </label>
      <button type="submit" disabled={venter}>{venter ? 'Lagrer …' : 'Legg til rutine'}</button>
      {tilstand?.ok ? <p className="ok" role="status">Rutine lagt til.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
