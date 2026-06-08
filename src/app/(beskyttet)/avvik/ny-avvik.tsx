'use client'
import { useActionState } from 'react'
import { opprettAvvik, type AvvikTilstand } from './handlinger'

export function NyAvvik({ stasjoner, idag }: { stasjoner: { id: string; navn: string }[]; idag: string }) {
  const [tilstand, handling, venter] = useActionState<AvvikTilstand, FormData>(opprettAvvik, undefined)

  return (
    <form action={handling} className="skjema avvik-skjema">
      <div className="rad-2">
        <label className="felt">
          <span>Stasjon</span>
          <select name="stasjon_id" required defaultValue={stasjoner.length === 1 ? stasjoner[0].id : ''}>
            {stasjoner.length !== 1 && <option value="" disabled>Velg …</option>}
            {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
          </select>
        </label>
        <label className="felt">
          <span>Dato</span>
          <input type="date" name="dato" defaultValue={idag} required />
        </label>
      </div>

      <fieldset className="felt">
        <span>Kategori</span>
        <label className="radio"><input type="radio" name="kategori" value="produkt" defaultChecked /> Produkt – hurtigmat (varsle marked@st1.no)</label>
        <label className="radio"><input type="radio" name="kategori" value="utstyr" /> Utstyr – hurtigmat (retail@st1.no + leverandør)</label>
      </fieldset>

      <label className="felt">
        <span>Beskrivelse av avvik/reklamasjon samt evt. årsak</span>
        <textarea name="beskrivelse" rows={3} required />
      </label>
      <label className="felt">
        <span>Avviksbehandling / strakstiltak</span>
        <textarea name="strakstiltak" rows={2} />
      </label>
      <label className="felt">
        <span>Korrigerende tiltak (forhindre gjentakelse)</span>
        <textarea name="korrigerende" rows={2} />
      </label>
      <div className="rad-2">
        <label className="felt">
          <span>Frist for gjennomføring</span>
          <input type="date" name="frist" />
        </label>
        <label className="felt">
          <span>Varslet videre til</span>
          <input name="varslet_til" placeholder="marked@st1.no / leverandør" />
        </label>
      </div>

      {tilstand?.ok ? <p className="ok" role="status">Avvik registrert.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter}>{venter ? 'Lagrer …' : 'Registrer avvik'}</button>
    </form>
  )
}
