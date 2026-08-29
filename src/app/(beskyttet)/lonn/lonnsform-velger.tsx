'use client'
import { useKvittering } from '@/components/ui/kvittering'

import { settLonnsform, type Tilstand } from './handlinger'
import { LONNSFORM_NAVN, type Lonnsform } from '@/lib/lonn/lonnsform'

/**
 * Ett valg per ansatt, rett i tabellen der man ser timene.
 *
 * Lagrer ved endring framfor med egen knapp: står det ti uavklarte i
 * lista, er ti knappetrykk ti anledninger til å hoppe over en.
 */
export function LonnsformVelger(
  { stasjonId, ansattNr, navn, verdi }:
  { stasjonId: string; ansattNr: string; navn: string; verdi: Lonnsform | null },
) {
  const [tilstand, handling, venter] = useKvittering<Tilstand, FormData>(
    settLonnsform, undefined)
  return (
    <form action={handling}>
      <input type="hidden" name="stasjon_id" value={stasjonId} />
      <input type="hidden" name="ansatt_nr" value={ansattNr} />
      <input type="hidden" name="navn" value={navn} />
      {/* Navnet står i raden ved siden av, men en skjermleser leser ikke
          raden — uten aria-label er dette «kombinasjonsboks» ti ganger. */}
      <select
        name="lonnsform"
        aria-label={`Lønnsform for ${navn}`}
        defaultValue={verdi ?? ''}
        disabled={venter}
        onChange={(e) => e.currentTarget.form?.requestSubmit()}
      >
        <option value="" disabled>Velg …</option>
        {(Object.keys(LONNSFORM_NAVN) as Lonnsform[]).map((k) => (
          <option key={k} value={k}>{LONNSFORM_NAVN[k]}</option>
        ))}
      </select>
      {tilstand?.feil && <span className="feil" role="alert">{tilstand.feil}</span>}
    </form>
  )
}
