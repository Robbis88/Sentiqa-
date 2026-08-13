'use client'
import { useActionState } from 'react'
import {
  opprettOppgave, sendTilTablet, settSomFokus, type SignalTilstand,
} from './signal-handlinger'

// En knapp per handling, hver med sin egen tilstand. Bekreftelsen står ved
// knappen som ble trykket — ikke i en toast som forsvinner før den er lest.
function Knapp({
  handling, tekst, tittel, detalj, stasjonId, primar = false,
}: {
  handling: (t: SignalTilstand, fd: FormData) => Promise<SignalTilstand>
  tekst: string
  tittel: string
  detalj: string
  stasjonId?: string
  primar?: boolean
}) {
  const [tilstand, kjor, venter] = useActionState<SignalTilstand, FormData>(handling, undefined)
  return (
    <form action={kjor} className="sq-knapp-form">
      <input type="hidden" name="tittel" value={tittel} />
      <input type="hidden" name="tekst" value={detalj} />
      {stasjonId ? <input type="hidden" name="stasjon_id" value={stasjonId} /> : null}
      <button type="submit" className={`sq-knapp ${primar ? 'primar' : ''}`} disabled={venter || Boolean(tilstand?.ok)}>
        {tilstand?.ok ?? (venter ? '…' : tekst)}
      </button>
      {tilstand?.feil ? <span className="sq-feil">{tilstand.feil}</span> : null}
    </form>
  )
}

export function SignalKnapper({
  tittel, detalj, stasjonId,
}: { tittel: string; detalj: string; stasjonId?: string }) {
  return (
    <>
      <Knapp handling={opprettOppgave} tekst="Opprett oppgave" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
      <Knapp handling={settSomFokus} tekst="Sett som fokus" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
      <Knapp handling={sendTilTablet} tekst="Send til tablet" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
    </>
  )
}
