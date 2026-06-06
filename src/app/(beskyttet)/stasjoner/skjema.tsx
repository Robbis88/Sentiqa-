'use client'
import { useActionState } from 'react'
import { leggTilStasjon, type StasjonTilstand } from './handlinger'

const TYPER: { verdi: string; tekst: string }[] = [
  { verdi: 'utfart', tekst: 'Utfart' },
  { verdi: 'pendler', tekst: 'Pendler' },
  { verdi: 'bydel', tekst: 'Bydel/lokal' },
  { verdi: 'gjennomfart', tekst: 'Gjennomfart/hovedvei' },
  { verdi: 'sentrum', tekst: 'Sentrum' },
]

export function StasjonSkjema() {
  const [tilstand, handling, venter] = useActionState<StasjonTilstand, FormData>(
    leggTilStasjon,
    undefined,
  )

  return (
    <form action={handling} className="stasjon-skjema">
      <label className="felt">
        <span>Butikknummer</span>
        <input name="butikknummer" inputMode="numeric" placeholder="4177" required />
      </label>
      <label className="felt">
        <span>Navn</span>
        <input name="navn" placeholder="St1 Lone" required />
      </label>
      <label className="felt">
        <span>Stasjonstype</span>
        <select name="stasjonstype" defaultValue="pendler">
          {TYPER.map((t) => (
            <option key={t.verdi} value={t.verdi}>{t.tekst}</option>
          ))}
        </select>
      </label>
      <label className="felt">
        <span>Svinnterskel %</span>
        <input name="svinnterskel" inputMode="decimal" placeholder="2,8" />
      </label>
      <button type="submit" disabled={venter}>
        {venter ? 'Lagrer …' : 'Legg til'}
      </button>

      {tilstand?.ok ? <p className="ok" role="status">Stasjon lagt til.</p> : null}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
