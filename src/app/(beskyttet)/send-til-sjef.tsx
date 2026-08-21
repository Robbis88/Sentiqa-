'use client'
import { useState, useActionState } from 'react'
import { sendTilbakemelding, type TilbakeResultat } from './tilbakemeldinger/handlinger'
import { useT } from './oversett-kontekst'

// Ikonene er borte. Alvoret ligger i ORDET - «Krenkelse fra kunde» sier
// mer enn et forbudsskilt - og en <option> er dessuten det ene stedet
// der ingen stil naar inn: emojien ble tegnet av operativsystemet, i
// sine egne farger, midt i nattflata.
const TYPER = [
  { v: 'generelt', navn: 'Generelt' },
  { v: 'uhell', navn: 'Uhell' },
  { v: 'nestenuhell', navn: 'Nestenuhell' },
  { v: 'krenkelse', navn: 'Krenkelse fra kunde' },
]

export function SendTilSjef() {
  const oversett = useT()
  const [aapen, setAapen] = useState(false)
  const [tilstand, handling, venter] = useActionState<TilbakeResultat | undefined, FormData>(sendTilbakemelding, undefined)

  if (tilstand?.ok) return <p className="ok send-sjef-takk">{oversett('Sendt til butikksjef')}</p>
  if (!aapen) return <button type="button" className="send-sjef-knapp" onClick={() => setAapen(true)}>{oversett('Send melding til butikksjef')}</button>

  return (
    <form action={handling} className="send-sjef">
      <select name="alvorlighet" defaultValue="generelt">
        {TYPER.map((ty) => <option key={ty.v} value={ty.v}>{oversett(ty.navn)}</option>)}
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
