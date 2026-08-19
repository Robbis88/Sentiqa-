'use client'
import { useActionState } from 'react'
import { leggTilAnsatt, type AnsattTilstand } from './handlinger'

export function NyAnsatt({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<AnsattTilstand, FormData>(leggTilAnsatt, undefined)

  return (
    <form action={handling} className="rutine-form">
      <label className="felt"><span>Navn</span>
        <input name="navn" placeholder="Kari Nordmann" required />
      </label>
      <label className="felt"><span>Stasjon</span>
        <select name="stasjon_id" required defaultValue={stasjoner.length === 1 ? stasjoner[0].id : ''}>
          {stasjoner.length !== 1 && <option value="" disabled>Velg …</option>}
          {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
        </select>
      </label>
      <label className="felt sq-smalt"><span>PIN (4–6 siffer)</span>
        <input name="pin" inputMode="numeric" maxLength={6} required />
      </label>
      {/* Valgfritt: nummeret kommer fra Azets, ofte etter at hun er
          opprettet her. Kan legges inn i lista senere. */}
      <label className="felt sq-smalt"><span>Ansattnummer</span>
        <input
          name="ansatt_nr" inputMode="numeric" maxLength={10}
          aria-describedby="ansattnr-hjelp"
        />
      </label>
      <p id="ansattnr-hjelp" className="undertittel">
        Kommer fra Azets. Har du det ikke ennå, kan du legge det inn senere —
        men hun kan ikke stemple eller komme med i lønnsfila før det er på plass.
      </p>
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Legg til'}</button>
      {tilstand?.ok ? <span className="ok">Lagt til.</span> : null}
      {tilstand?.feil ? <span className="feil">{tilstand.feil}</span> : null}
    </form>
  )
}
