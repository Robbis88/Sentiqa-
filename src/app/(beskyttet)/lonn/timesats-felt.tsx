'use client'
import { useActionState, useRef } from 'react'
import { settTimesats, type Tilstand } from './handlinger'

/**
 * Timesatsen, redigerbar rett i kontrolltabellen.
 *
 * Lagrer når feltet forlates, ikke ved hvert tastetrykk — og bare hvis
 * verdien faktisk er endret. Tabber man seg gjennom ti rader uten å røre
 * noe, skal det ikke bli ti skrivinger.
 *
 * Satsen er en kontroll, ikke et lønnsgrunnlag: Visma-fila bærer timer,
 * Azets holder satsene. Derfor kan den endres når som helst, og et tomt
 * felt fjerner den igjen.
 */
export function TimesatsFelt(
  { stasjonId, ansattNr, navn, verdi }:
  { stasjonId: string; ansattNr: string; navn: string; verdi: number | null },
) {
  const [tilstand, handling, venter] = useActionState<Tilstand, FormData>(
    settTimesats, undefined)
  const start = verdi != null ? String(verdi).replace('.', ',') : ''
  const forrige = useRef(start)

  return (
    <form action={handling}>
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <input type="hidden" name="navn" value={navn} />
      {/* inputMode=decimal gir talltastatur på mobil, men lar 196,02 stå
          med komma — type=number avviser komma i norsk locale. */}
      <input
        name="timesats"
        inputMode="decimal"
        aria-label={`Timesats for ${navn}`}
        defaultValue={start}
        placeholder="—"
        disabled={venter}
        style={{ width: '5.5rem', textAlign: 'right' }}
        onBlur={(e) => {
          if (e.currentTarget.value.trim() === forrige.current.trim()) return
          forrige.current = e.currentTarget.value
          e.currentTarget.form?.requestSubmit()
        }}
      />
      {tilstand?.feil && <span className="feil" role="alert">{tilstand.feil}</span>}
    </form>
  )
}
