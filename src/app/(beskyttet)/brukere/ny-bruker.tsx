'use client'
import { useState } from 'react'
import { useKvittering } from '@/components/ui/kvittering'

import { opprettBruker, type BrukerTilstand } from './handlinger'

export function NyBruker({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] = useKvittering<BrukerTilstand, FormData>(opprettBruker, undefined)
  // =================================================================
  // TO FELT OG EN «VIS»-BRYTER, OG DE LØSER HVER SIN TING
  //
  // Gjentakelsen fanger skrivefeilen når passordet er skjult.
  // Bryteren finnes fordi en TABLET-konto skal tastes inn på et
  // nettbrett etterpå — da må den som oppretter den kunne lese den.
  // Uten bryteren gjettes passordet inn på enheten, og da er man
  // tilbake til en konto ingen kommer inn på.
  //
  // Skjult som standard: skjermen står ofte i et rom med andre folk.
  // =================================================================
  const [vis, setVis] = useState(false)

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
      <label className="felt">
        <span>Passord (min. 8 tegn)</span>
        <input name="passord" type={vis ? 'text' : 'password'} autoComplete="new-password" required />
      </label>
      <label className="felt">
        <span>Gjenta passord</span>
        <input
          name="passord_gjenta"
          type={vis ? 'text' : 'password'}
          autoComplete="new-password"
          required
        />
      </label>
      <label className="avkryss">
        <input type="checkbox" checked={vis} onChange={(e) => setVis(e.target.checked)} />
        {' '}Vis passordet
      </label>

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
      <button type="submit" disabled={venter} className="primar">{venter ? 'Oppretter …' : 'Opprett bruker'}</button>
    </form>
  )
}
