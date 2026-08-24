'use client'
import { useActionState } from 'react'
import { opprettKonkurranse, type KonkTilstand } from './handlinger'

export function NyKonkurranse() {
  const [tilstand, handling, venter] = useActionState<KonkTilstand, FormData>(opprettKonkurranse, undefined)

  return (
    <form action={handling} className="skjema konk-skjema">
      <label className="felt"><span>Navn</span><input name="navn" placeholder="Pølsekampen" required /></label>
      <label className="felt"><span>Hva måles (beskrivelse)</span><input name="kpi" placeholder="Omsetning pølse" required /></label>
      <div className="rad-2">
        <label className="felt">
          <span>Måltype</span>
          <select name="maaltype" defaultValue="omsetning">
            <option value="omsetning">Omsetning (kr)</option>
            <option value="antall">Antall (stk)</option>
          </select>
        </label>
        <label className="felt"><span>Varegruppekode (valgfri)</span><input name="varegruppe_kode" placeholder="tom = all omsetning" /></label>
      </div>
      <div className="rad-2">
        <label className="felt"><span>Fra</span><input type="date" name="periode_start" required /></label>
        <label className="felt"><span>Til</span><input type="date" name="periode_slutt" required /></label>
      </div>
      <div className="rad-2">
        <label className="felt"><span>Pengepremie (kr)</span><input name="premie_kr" inputMode="decimal" placeholder="1000" /></label>
        <label className="felt"><span>Premie-tekst (valgfri)</span><input name="premie_tekst" placeholder="f.eks. pizza til hele teamet" /></label>
      </div>
      {tilstand?.ok ? <p className="ok" role="status">Konkurranse opprettet.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter} className="primar">{venter ? 'Oppretter …' : 'Opprett konkurranse'}</button>
    </form>
  )
}
