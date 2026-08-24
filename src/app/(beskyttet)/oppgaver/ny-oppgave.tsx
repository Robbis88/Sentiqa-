'use client'
import { useActionState } from 'react'
import { leggTilOppgave, type OppgaveTilstand } from './handlinger'

export function NyOppgave({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<OppgaveTilstand, FormData>(
    leggTilOppgave,
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
        <span>Tittel</span>
        <input name="tittel" placeholder="Bestill mer kaffe" required />
      </label>
      <label className="felt">
        <span>Beskrivelse</span>
        <input name="beskrivelse" placeholder="(valgfri)" />
      </label>
      <label className="felt">
        <span>Frist</span>
        <input name="frist" type="date" />
      </label>
      <label className="felt avkryss">
        <input name="vis_paa_tablet" type="checkbox" />
        <span>Vis som melding på tableten (ansatte kan kvittere «utført»)</span>
      </label>
      <label className="felt">
        <span>Bilde-lenke (valgfri)</span>
        <input name="bilde_url" type="url" placeholder="https://…" />
      </label>
      <button type="submit" disabled={venter} className="primar">{venter ? 'Lagrer …' : 'Legg til'}</button>
      {tilstand?.ok ? <p className="ok" role="status">Oppgave lagt til.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
