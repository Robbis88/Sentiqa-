'use client'
import { useKvittering } from '@/components/ui/kvittering'

import { settSkiftordning, type Tilstand } from './handlinger'
import { SKIFTNAVN, TIMER_PER_UKE, type Skiftordning } from '@/lib/lonn/tariff'

// =====================================================================
// SKIFTORDNING FOR ÉN ANSATT
//
// Knappen «Sett arbeidstid etter satsen» leser ordningen ut av
// timesatsen og tier når satsen er tvetydig — ligger den mellom to
// tarifftrinn, peker den ikke på én kolonne.
//
// **De som falt utenfor kunne ikke settes i det hele tatt.** På Bønes
// gjaldt det tre av ti, og overtidsgrensen deres sto som «antatt 37,5»
// for alltid. En snarvei som dekker de fleste er god; en snarvei som er
// ENESTE vei er en blindvei for resten.
//
// UKETIMETALLET STÅR I VALGET, ikke bare navnet. «To skift» sier
// ingenting til den som skal velge; «to skift · 35,5 t/uke» sier hva det
// betyr for overtidsgrensen — som er hele grunnen til at feltet finnes.
// =====================================================================

const ORDNINGER = Object.keys(SKIFTNAVN) as Skiftordning[]

export function Skiftvelger(
  { stasjonId, ansattNr, navn, verdi }:
  { stasjonId: string; ansattNr: string; navn: string; verdi: Skiftordning | null },
) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(
    settSkiftordning, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <input type="hidden" name="navn" value={navn} />
      <select
        name="skiftordning"
        // Navnet står i raden ved siden av, men en skjermleser leser
        // ikke raden — uten dette er det «kombinasjonsboks» ti ganger.
        aria-label={`Arbeidstid for ${navn}`}
        defaultValue={verdi ?? ''}
        disabled={venter}
        // Lagrer ved endring, ikke med egen knapp: står det ti uavklarte
        // i lista, er ti knappetrykk ti anledninger til å hoppe over en.
        onChange={(e) => e.currentTarget.form?.requestSubmit()}
      >
        <option value="" disabled>Velg …</option>
        {ORDNINGER.map((k) => (
          <option key={k} value={k}>
            {`${SKIFTNAVN[k]} · ${TIMER_PER_UKE[k].toLocaleString('nb-NO')} t/uke`}
          </option>
        ))}
      </select>
      {tilstand?.feil && <span className="feil" role="alert">{tilstand.feil}</span>}
    </form>
  )
}
