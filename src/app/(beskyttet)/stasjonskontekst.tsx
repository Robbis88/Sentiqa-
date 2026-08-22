'use client'
import { useRef, useState } from 'react'
import { useFormStatus } from 'react-dom'
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
//
// BYTTET MÅ SES, IKKE BARE SKJE. Robert, 2026-08-22: «klarer ikke å
// velge mellom stasjonene … må være noe som indikerer at du har byttet
// stasjon.»
//
// Den byttet faktisk — men flere sider navngir ikke stasjonen sin, så
// et vellykket bytte så ut som ingenting. Et valg som ikke kvitterer er
// et valg brukeren prøver på nytt, og til slutt slutter å stole på.
//
// Derfor to ting: en tilstand mens det står på, og navnet på stasjonen
// etterpå. Begge i et `aria-live`-område, så en skjermleser hører det
// samme som øyet ser.
// =====================================================================

/**
 * «Bytter …» mens handlingen står på.
 *
 * Egen komponent fordi `useFormStatus` bare leser status fra skjemaet
 * OVER seg. Ligger den i samme komponent som `<form>`, er den alltid
 * `false` — en felle som gir en indikator som ser riktig ut og aldri
 * lyser.
 */
function Kvittering({ navn }: { navn: string }) {
  const { pending } = useFormStatus()
  return (
    <span className="sq-stasjonssvar" aria-live="polite">
      {pending ? 'Bytter …' : navn}
    </span>
  )
}

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
  // Navnet vises fra det øyeblikket brukeren velger, ikke først når
  // serveren svarer. Ellers står det gamle navnet mens siden laster,
  // og det er nettopp da man lurer på om klikket gikk gjennom.
  const [nettoppValgt, settValgt] = useState<string | null>(null)
  // Nullstilles naar serveren har levert et nytt valg: uten dette ville
  // et bytte som ikke gikk gjennom staatt igjen som om det gjorde det.
  const [sist, settSist] = useState(valgt)
  if (sist !== valgt) {
    settSist(valgt)
    settValgt(null)
  }

  const navnFor = (id: string | null) => {
    if (id === null || id === 'alle') return 'Alle stasjoner'
    const s = stasjoner.find((x) => x.id === id)
    return s ? stasjonsnavn(s) : ''
  }

  return (
    <form action={settStasjon} ref={ref} className="sq-stasjonskontekst">
      <label>
        {/* Etiketten er skjult visuelt, men ikke for skjermlesere: uten
            den er dette bare «kombinasjonsboks» i toppen av hver side. */}
        <span className="sq-skjult">Stasjon</span>
        <select
          name="stasjon"
          defaultValue={valgt ?? 'alle'}
          onChange={(e) => {
            settValgt(e.target.value)
            ref.current?.requestSubmit()
          }}
        >
          {tillatAlle && <option value="alle">Alle stasjoner</option>}
          {stasjoner.map((s) => (
            <option key={s.id} value={s.id}>{stasjonsnavn(s)}</option>
          ))}
        </select>
      </label>
      <Kvittering navn={navnFor(nettoppValgt ?? valgt)} />
      {/* Uten JavaScript blir dette en vanlig knapp. Med, er den unødvendig. */}
      <noscript><button type="submit" className="liten">Bytt</button></noscript>
    </form>
  )
}
