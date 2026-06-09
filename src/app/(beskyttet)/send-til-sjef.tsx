'use client'
import { useState, useActionState } from 'react'
import { sendTilbakemelding, type TilbakeResultat } from './tilbakemeldinger/handlinger'

const TYPER = [
  { v: 'generelt', e: '💬 Generelt' },
  { v: 'uhell', e: '🩹 Uhell' },
  { v: 'nestenuhell', e: '⚠️ Nestenuhell' },
  { v: 'krenkelse', e: '🚫 Krenkelse fra kunde' },
]

export function SendTilSjef() {
  const [aapen, setAapen] = useState(false)
  const [tilstand, handling, venter] = useActionState<TilbakeResultat | undefined, FormData>(sendTilbakemelding, undefined)

  if (tilstand?.ok) return <p className="ok send-sjef-takk">Sendt til butikksjef 💬</p>
  if (!aapen) return <button type="button" className="send-sjef-knapp" onClick={() => setAapen(true)}>✉️ Send melding til butikksjef</button>

  return (
    <form action={handling} className="send-sjef">
      <select name="alvorlighet" defaultValue="generelt">
        {TYPER.map((t) => <option key={t.v} value={t.v}>{t.e}</option>)}
      </select>
      <textarea name="tekst" rows={3} placeholder="Hva vil du si til sjefen?" required />
      <input name="involvert_beskrivelse" placeholder="Beskrivelse av involvert kunde (valgfri)" />
      <div className="send-sjef-knapper">
        <button type="button" className="liten" onClick={() => setAapen(false)}>Avbryt</button>
        <button type="submit" disabled={venter}>{venter ? 'Sender …' : 'Send'}</button>
      </div>
      {tilstand?.feil ? <p className="feil">{tilstand.feil}</p> : null}
    </form>
  )
}
