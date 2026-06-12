'use client'
import { useActionState, useState, useTransition } from 'react'
import { opprettInnlegg, formulerNyhet, type RedTilstand } from './handlinger'

const TONER = [
  { v: 'nøytral og informativ', t: 'Nøytral' },
  { v: 'entusiastisk og positiv', t: 'Entusiastisk' },
  { v: 'kort og rett på sak', t: 'Kort' },
]

export function NyttInnlegg() {
  const [tilstand, handling, venter] = useActionState<RedTilstand, FormData>(opprettInnlegg, undefined)
  const [tittel, setTittel] = useState('')
  const [innhold, setInnhold] = useState('')
  const [ide, setIde] = useState('')
  const [tone, setTone] = useState(TONER[0].v)
  const [aiVenter, start] = useTransition()
  const [aiFeil, setAiFeil] = useState<string | null>(null)

  function foreslaa() {
    setAiFeil(null)
    start(async () => {
      const r = await formulerNyhet(ide, tone)
      if ('feil' in r) { setAiFeil(r.feil); return }
      setTittel(r.tittel)
      setInnhold(r.innhold)
    })
  }

  return (
    <form action={handling} className="skjema">
      <div className="ai-nyhet">
        <label className="felt">
          <span>💡 Hva skal nyheten handle om? La AI-en skrive et utkast.</span>
          <textarea
            value={ide}
            onChange={(e) => setIde(e.target.value)}
            rows={2}
            placeholder="f.eks. ny svinn-rapport på dashbordet, sommerkampanje på kaffe, viktig oppdatering om rutiner …"
          />
        </label>
        <div className="ai-nyhet-rad">
          <select value={tone} onChange={(e) => setTone(e.target.value)} aria-label="Tone">
            {TONER.map((t) => <option key={t.v} value={t.v}>{t.t}</option>)}
          </select>
          <button type="button" className="liten" onClick={foreslaa} disabled={aiVenter || ide.trim().length < 3}>
            {aiVenter ? 'Skriver …' : '✨ Foreslå tekst'}
          </button>
        </div>
        {aiFeil ? <p className="feil" role="alert">{aiFeil}</p> : null}
        <p className="undertittel">Forslaget fyller inn feltene under — du kan redigere fritt før du lagrer.</p>
      </div>

      <label className="felt"><span>Tittel</span><input name="tittel" value={tittel} onChange={(e) => setTittel(e.target.value)} placeholder="Sommerkampanje 2026" required /></label>
      <label className="felt"><span>Innhold</span><textarea name="innhold" value={innhold} onChange={(e) => setInnhold(e.target.value)} rows={6} required /></label>
      <label className="felt avkryss"><input type="checkbox" name="publiser" defaultChecked /> <span>Publiser med en gang</span></label>
      {tilstand?.ok ? <p className="ok" role="status">Lagret.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
      <button type="submit" disabled={venter}>{venter ? 'Lagrer …' : 'Lagre innlegg'}</button>
    </form>
  )
}
