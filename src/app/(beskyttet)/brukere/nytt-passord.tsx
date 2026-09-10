'use client'
import { useState } from 'react'
import { useKvittering } from '@/components/ui/kvittering'
import type { Kvittering } from '@/lib/kvittering'
import { settNyttPassord } from './handlinger'

// =====================================================================
// Eierens vei inn når e-posten ikke er en vei.
//
// SAMME TRE FELT SOM VED OPPRETTELSE, og av samme grunn: gjentakelsen
// fanger skrivefeilen, og «vis passordet» finnes fordi et tablet-passord
// skal tastes inn på et nettbrett etterpå. Kan man ikke lese det man
// nettopp skrev, gjetter man det inn på enheten — og da er kontoen like
// låst som før, bare på en ny måte.
// =====================================================================

export function NyttPassord({ profilId, navn }: { profilId: string; navn: string }) {
  const [tilstand, handling, venter] = useKvittering<Kvittering, FormData>(settNyttPassord, undefined)
  const [vis, setVis] = useState(false)

  return (
    <form action={handling} className="skjema">
      <input type="hidden" name="profil_id" value={profilId} />

      <label className="felt">
        <span>Nytt passord for {navn} (min. 8 tegn)</span>
        <input name="passord" type={vis ? 'text' : 'password'} autoComplete="new-password" required minLength={8} />
      </label>
      <label className="felt">
        <span>Gjenta passord</span>
        <input name="passord_gjenta" type={vis ? 'text' : 'password'} autoComplete="new-password" required minLength={8} />
      </label>
      <label className="avkryss">
        <input type="checkbox" checked={vis} onChange={(e) => setVis(e.target.checked)} />
        {' '}Vis passordet
      </label>

      {tilstand?.ok ? <p className="ok" role="status">{tilstand.ok}</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter} className="primar">
        {venter ? 'Setter …' : 'Sett nytt passord'}
      </button>
    </form>
  )
}
