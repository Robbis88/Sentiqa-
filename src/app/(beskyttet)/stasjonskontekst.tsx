'use client'
import { useRef } from 'react'
import { settStasjon } from './stasjon-handlinger'
import { stasjonsnavn, type Stasjon } from '@/lib/stasjonsvalg'

// =====================================================================
// Stasjonsvelgeren, ett sted.
//
// Ti sider spurte om dette hver for seg. Butikksjefen med én stasjon
// svarte ti ganger og fikk aldri et annet svar — og eieren måtte velge
// på nytt for hver side han gikk til.
//
// Vises ikke i det hele tatt når det bare finnes ett alternativ. En
// nedtrekksliste med ett valg ber om en beslutning som ikke finnes.
// =====================================================================

export function Stasjonskontekst({
  stasjoner,
  valgt,
  tillatAlle,
}: {
  stasjoner: Stasjon[]
  /** null = alle stasjoner samlet. */
  valgt: string | null
  tillatAlle: boolean
}) {
  const ref = useRef<HTMLFormElement>(null)

  return (
    <form action={settStasjon} ref={ref} className="sq-stasjonskontekst">
      <label>
        {/* Etiketten er skjult visuelt, men ikke for skjermlesere: uten
            den er dette bare «kombinasjonsboks» i toppen av hver side. */}
        <span className="sq-skjult">Stasjon</span>
        <select
          name="stasjon"
          defaultValue={valgt ?? 'alle'}
          onChange={() => ref.current?.requestSubmit()}
        >
          {tillatAlle && <option value="alle">Alle stasjoner</option>}
          {stasjoner.map((s) => (
            <option key={s.id} value={s.id}>{stasjonsnavn(s)}</option>
          ))}
        </select>
      </label>
      {/* Uten JavaScript blir dette en vanlig knapp. Med, er den unødvendig. */}
      <noscript><button type="submit" className="liten">Bytt</button></noscript>
    </form>
  )
}
