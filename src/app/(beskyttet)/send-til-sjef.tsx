'use client'
import { useState, useActionState } from 'react'
import { sendTilbakemelding, type TilbakeResultat } from './tilbakemeldinger/handlinger'
import { useT } from './oversett-kontekst'

const TYPER = [
  { v: 'generelt', ikon: '💬', navn: 'Generelt' },
  { v: 'uhell', ikon: '🩹', navn: 'Uhell' },
  { v: 'nestenuhell', ikon: '⚠️', navn: 'Nestenuhell' },
  { v: 'krenkelse', ikon: '🚫', navn: 'Krenkelse fra kunde' },
]

export function SendTilSjef() {
  const oversett = useT()
  const [aapen, setAapen] = useState(false)
  const [tilstand, handling, venter] = useActionState<TilbakeResultat | undefined, FormData>(sendTilbakemelding, undefined)

  if (tilstand?.ok) return <p className="ok send-sjef-takk">{oversett('Sendt til butikksjef')} 💬</p>
  if (!aapen) return <button type="button" className="send-sjef-knapp" onClick={() => setAapen(true)}>✉️ {oversett('Send melding til butikksjef')}</button>

  return (
    <form action={handling} className="send-sjef">
      <select name="alvorlighet" defaultValue="generelt">
        {TYPER.map((ty) => <option key={ty.v} value={ty.v}>{ty.ikon} {oversett(ty.navn)}</option>)}
      </select>
      <textarea name="tekst" rows={3} placeholder={oversett('Hva vil du si til sjefen?')} required />
      <input name="involvert_beskrivelse" placeholder={oversett('Beskrivelse av involvert kunde (valgfri)')} />
      <div className="send-sjef-knapper">
        <button type="button" className="liten" onClick={() => setAapen(false)}>{oversett('Avbryt')}</button>
        <button type="submit" disabled={venter}>{venter ? oversett('Sender …') : oversett('Send')}</button>
      </div>
      {tilstand?.feil ? <p className="feil">{tilstand.feil}</p> : null}
    </form>
  )
}
