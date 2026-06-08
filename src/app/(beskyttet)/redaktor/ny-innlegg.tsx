'use client'
import { useActionState } from 'react'
import { opprettInnlegg, type RedTilstand } from './handlinger'

export function NyttInnlegg() {
  const [tilstand, handling, venter] = useActionState<RedTilstand, FormData>(opprettInnlegg, undefined)

  return (
    <form action={handling} className="skjema">
      <label className="felt"><span>Tittel</span><input name="tittel" placeholder="Sommerkampanje 2026" required /></label>
      <label className="felt"><span>Innhold</span><textarea name="innhold" rows={5} required /></label>
      <label className="felt avkryss"><input type="checkbox" name="publiser" defaultChecked /> <span>Publiser med en gang</span></label>
      {tilstand?.ok ? <p className="ok" role="status">Lagret.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter}>{venter ? 'Lagrer …' : 'Lagre innlegg'}</button>
    </form>
  )
}
