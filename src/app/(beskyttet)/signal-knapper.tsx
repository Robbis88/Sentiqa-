'use client'
import { useActionState } from 'react'
import {
  opprettOppgave, sendTilTablet, settSomFokus, skjulSignal, type SignalTilstand,
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

// Skjuling er en annen slags handling enn de tre andre: den endrer ikke
// noe i driften, den utsetter bare saken. Derfor egen form med signal-id.
function Skjul({ signalId, stasjonId }: { signalId: string; stasjonId?: string }) {
  const [tilstand, kjor, venter] = useActionState<SignalTilstand, FormData>(skjulSignal, undefined)
  return (
    <form action={kjor} className="sq-knapp-form">
      <input type="hidden" name="signal_id" value={signalId} />
      {stasjonId ? <input type="hidden" name="stasjon_id" value={stasjonId} /> : null}
      <button type="submit" className="sq-knapp sq-dempet" disabled={venter || Boolean(tilstand?.ok)}>
        {tilstand?.ok ?? (venter ? '…' : 'Skjul i 7 dager')}
      </button>
      {tilstand?.feil ? <span className="sq-feil">{tilstand.feil}</span> : null}
    </form>
  )
}

export function SignalKnapper({
  signalId, tittel, detalj, stasjonId,
}: { signalId: string; tittel: string; detalj: string; stasjonId?: string }) {
  return (
    <>
      <Knapp handling={opprettOppgave} tekst="Opprett oppgave" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
      <Knapp handling={settSomFokus} tekst="Sett som fokus" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
      <Knapp handling={sendTilTablet} tekst="Send til tablet" tittel={tittel} detalj={detalj} stasjonId={stasjonId} />
      <Skjul signalId={signalId} stasjonId={stasjonId} />
    </>
  )
}
