'use client'
import { useActionState, useState } from 'react'
import { settAnsattnummer, type AnsattTilstand } from './handlinger'

// =====================================================================
// Ansattnummeret, redigerbart der det står.
//
// Nummeret kommer fra Azets etter at den ansatte er opprettet, så det å
// fylle det inn i ettertid er den VANLIGE veien — ikke unntaket. Da kan
// det ikke ligge bak en redigeringsside; det må stå i lista, der man ser
// hvem som mangler.
//
// Lagre-knappen vises først når noe er endret. Ellers står det en rad
// med knapper som ikke gjør noe, og da slutter man å se dem.
// =====================================================================

export function AnsattnummerFelt(
  { id, nummer }: { id: string; nummer: string | null },
) {
  const [tilstand, handling, venter] = useActionState<AnsattTilstand, FormData>(
    settAnsattnummer, undefined,
  )
  const [verdi, settVerdi] = useState(nummer ?? '')
  const endret = verdi.trim() !== (nummer ?? '')

  return (
    <form action={handling} className="ansattnr-form">
      <input type="hidden" name="id" value={id} />
      <input
        name="ansatt_nr"
        inputMode="numeric"
        maxLength={10}
        value={verdi}
        onChange={(e) => settVerdi(e.target.value)}
        placeholder="Mangler"
        aria-label="Ansattnummer"
        className={nummer ? undefined : 'mangler'}
      />
      {endret && (
        <button type="submit" className="liten primar" disabled={venter}>
          {venter ? '…' : 'Lagre'}
        </button>
      )}
      {tilstand?.feil ? <span className="feil">{tilstand.feil}</span> : null}
    </form>
  )
}
