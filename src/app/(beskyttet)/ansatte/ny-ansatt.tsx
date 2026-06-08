'use client'
import { useActionState } from 'react'
import { leggTilAnsatt, type AnsattTilstand } from './handlinger'

export function NyAnsatt({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useActionState<AnsattTilstand, FormData>(leggTilAnsatt, undefined)

  return (
    <form action={handling} className="rutine-form">
      <input name="navn" placeholder="Navn" required />
      <select name="stasjon_id" required defaultValue={stasjoner.length === 1 ? stasjoner[0].id : ''}>
        {stasjoner.length !== 1 && <option value="" disabled>Stasjon …</option>}
        {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
      </select>
      <input name="pin" inputMode="numeric" maxLength={6} placeholder="PIN (4–6 siffer)" required />
      <button type="submit" className="liten" disabled={venter}>{venter ? '…' : 'Legg til'}</button>
      {tilstand?.ok ? <span className="ok">Lagt til.</span> : null}
      {tilstand?.feil ? <span className="feil">{tilstand.feil}</span> : null}
    </form>
  )
}
