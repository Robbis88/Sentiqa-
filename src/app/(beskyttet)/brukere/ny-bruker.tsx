'use client'
import { useActionState } from 'react'
import { opprettBruker, type BrukerTilstand } from './handlinger'

export function NyBruker({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<BrukerTilstand, FormData>(opprettBruker, undefined)

  return (
    <form action={handling} className="skjema">
      <label className="felt">
        <span>Rolle</span>
        <select name="rolle" defaultValue="butikksjef">
          <option value="butikksjef">Butikksjef (egen innlogging)</option>
          <option value="butikkbruker_tablet">Tablet-konto (delt på stasjonen)</option>
        </select>
      </label>
      <label className="felt"><span>Navn</span><input name="navn" placeholder="Navn / «Tablet Bønes»" required /></label>
      <label className="felt"><span>E-post (innlogging)</span><input name="epost" type="email" placeholder="navn@firma.no" required /></label>
      <label className="felt"><span>Passord (min. 8 tegn)</span><input name="passord" type="password" autoComplete="new-password" required /></label>

      <fieldset className="felt">
        <span>Stasjoner brukeren får tilgang til</span>
        <div className="stasjon-valg">
          {stasjoner.map((s) => (
            <label className="avkryss" key={s.id}>
              <input type="checkbox" name="stasjon_ids" value={s.id} /> {s.navn}
            </label>
          ))}
        </div>
      </fieldset>

      {tilstand?.ok ? <p className="ok" role="status">Bruker opprettet.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter}>{venter ? 'Oppretter …' : 'Opprett bruker'}</button>
    </form>
  )
}
