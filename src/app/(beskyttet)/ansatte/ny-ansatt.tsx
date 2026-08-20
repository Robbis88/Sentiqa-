'use client'
import { useActionState } from 'react'
import { Felt, Velg } from '@/components/ui/felt'
import { Knapp } from '@/components/ui/knapp'
import { leggTilAnsatt, type AnsattTilstand } from './handlinger'

// =====================================================================
// Ny ansatt.
//
// SAMME SERVERHANDLING, SAMME VALIDERING, SAMME FELTNAVN. Skjemaet er
// bygget om til primitivene, ikke om til noe annet: `leggTilAnsatt` og
// zod-skjemaet i handlinger.ts er urørt, og feltene heter fortsatt
// navn, stasjon_id, pin og ansatt_nr. En serverhandling som må endres
// for at et skjema skal bli penere, er et skjema som har endret mening.
//
// Det som er nytt er at feltene har ETIKETTER som komponenten krever, og
// hjelpetekst knyttet til feltet med aria-describedby i stedet for et
// avsnitt som svever under.
// =====================================================================

export function NyAnsatt({ stasjoner }: { stasjoner: { id: string; navn: string }[] }) {
  const [tilstand, handling, venter] =
    useActionState<AnsattTilstand, FormData>(leggTilAnsatt, undefined)

  return (
    <form action={handling} className="sq-skjema">
      <Felt
        etikett="Navn"
        name="navn"
        placeholder="Kari Nordmann"
        required
      />

      <Velg
        etikett="Stasjon"
        name="stasjon_id"
        required
        defaultValue={stasjoner.length === 1 ? stasjoner[0].id : ''}
      >
        {stasjoner.length !== 1 && <option value="" disabled>Velg …</option>}
        {stasjoner.map((s) => <option key={s.id} value={s.id}>{s.navn}</option>)}
      </Velg>

      <Felt
        etikett="PIN"
        name="pin"
        inputMode="numeric"
        maxLength={6}
        required
        hjelp="4–6 siffer. Vises aldri igjen etter lagring — noter den nå."
      />

      {/* Valgfritt: nummeret kommer fra Azets, ofte etter at hun er
          opprettet her. Kan legges inn i lista senere. */}
      <Felt
        etikett="Ansattnummer"
        name="ansatt_nr"
        inputMode="numeric"
        maxLength={10}
        hjelp="Fra Azets. Uten det kan hun ikke stemple eller komme med i lønnsfila."
      />

      <div className="knapperad">
        <Knapp type="submit" variant="primar" disabled={venter}>
          {venter ? 'Lagrer …' : 'Legg til'}
        </Knapp>
        {tilstand?.ok ? <span className="ok">Lagt til.</span> : null}
      </div>

      {/* role="alert": feilen kommer etter innsending, og den som bruker
          skjermleser skal høre den uten å lete seg tilbake opp i skjemaet. */}
      {tilstand?.feil ? <p className="feil" role="alert">{tilstand.feil}</p> : null}
    </form>
  )
}
