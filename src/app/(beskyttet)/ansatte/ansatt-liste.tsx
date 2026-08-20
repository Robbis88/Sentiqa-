'use client'
import { useMemo, useState } from 'react'
import { Liste, Rad } from '@/components/ui/liste'
import { Status } from '@/components/ui/status'
import { Sok, Filter } from '@/components/ui/sok'
import { Velg } from '@/components/ui/felt'
import { Knapp } from '@/components/ui/knapp'
import { Tomtilstand } from '@/components/ui/side'
import { AnsattnummerFelt } from './ansattnummer-felt'
import { deaktiverAnsatt } from './handlinger'

// =====================================================================
// Ansattlista.
//
// SØKET ER KLIENTSIDE og rører verken URL, server eller database. Hele
// lista er hentet uansett — den er på titalls rader, ikke tusener — så
// et serversøk ville vært en rundtur for å filtrere noe nettleseren
// allerede har. Blir lista stor nok til at den ikke lastes hel, er
// serversøk riktig, og da er det en funksjonell endring, ikke en
// designendring.
//
// STATUS VISES BARE NÅR DEN BETYR NOE. Sida lister kun aktive ansatte —
// spørringen filtrerer på det — så «Aktiv» ville stått likt på hver
// eneste rad. En status som aldri varierer er ikke informasjon, den er
// støy med farge på. Det som FAKTISK varierer er om ansattnummeret
// mangler, og det er også det eneste som krever noe av lederen: uten
// nummer kan hun verken stemple eller komme med i lønnsfila.
//
// INGEN KNAPP PÅ HVER RAD. «Deaktiver» lå som en egen kolonne med en
// knapp per ansatt — en destruktiv handling gjentatt tjue ganger, i en
// kolonne som stjal plass fra navnet. Nå ligger den bak radens egen
// meny, som åpnes med tastatur og mus, og bekreftes før den kjøres.
// =====================================================================

export type Ansatt = {
  id: string
  navn: string
  stasjon_id: string
  ansatt_nr: string | null
}

type Props = {
  ansatte: Ansatt[]
  /** id → «4185 Dale». Bygget på serveren, der stasjonene alt er hentet. */
  stasjonsnavn: Record<string, string>
  /** Vises bare når det er mer enn én å velge mellom. */
  stasjoner: { id: string; navn: string }[]
  nyAnsattPanel: React.ReactNode
}

export function AnsattListe({ ansatte, stasjonsnavn, stasjoner, nyAnsattPanel }: Props) {
  const [sok, settSok] = useState('')
  const [stasjon, settStasjon] = useState('')

  const treff = useMemo(() => {
    const s = sok.trim().toLowerCase()
    return ansatte.filter((a) => {
      if (stasjon && a.stasjon_id !== stasjon) return false
      if (!s) return true
      // Søker i navn OG nummer: lederen som leter etter noen hun bare
      // kjenner nummeret på, fra en lønnsfil eller en vaktliste, skal
      // finne henne.
      return a.navn.toLowerCase().includes(s)
        || (a.ansatt_nr ?? '').includes(s)
        || (stasjonsnavn[a.stasjon_id] ?? '').toLowerCase().includes(s)
    })
  }, [ansatte, sok, stasjon, stasjonsnavn])

  if (ansatte.length === 0) {
    return (
      <Tomtilstand
        tittel="Ingen ansatte ennå"
        forklaring={
          'Legg inn de som jobber her, så kan de sjekke inn med PIN på '
          + 'nettbrettet og kvittere for rutiner og temperaturer.'
        }
        handling={nyAnsattPanel}
      />
    )
  }

  const filtreAktive = stasjon ? 1 : 0

  return (
    <>
      <div className="sq-listetopp">
        <Sok
          verdi={sok}
          onEndre={settSok}
          plassholder="Søk etter navn eller nummer"
          merkelapp="Søk etter ansatt"
        />
        {/* Filteret finnes bare når det er noe å filtrere PÅ. Én stasjon
            gir en nedtrekksliste med ett valg, altså en beslutning som
            ikke finnes. */}
        {stasjoner.length > 1 && (
          <Filter antall={filtreAktive}>
            <Velg
              etikett="Stasjon"
              skjultEtikett
              value={stasjon}
              onChange={(e) => settStasjon(e.target.value)}
            >
              <option value="">Alle stasjoner</option>
              {stasjoner.map((s) => (
                <option key={s.id} value={s.id}>{s.navn}</option>
              ))}
            </Velg>
          </Filter>
        )}
      </div>

      {/* aria-live: den som filtrerer med skjermleser skal høre at
          antallet endret seg, uten å måtte lete i lista etterpå. */}
      <p className="undertittel sq-listetall" aria-live="polite">
        {treff.length === ansatte.length
          ? `${ansatte.length} aktive`
          : `${treff.length} av ${ansatte.length}`}
      </p>

      {treff.length === 0 ? (
        <Tomtilstand
          tittel="Ingen treff"
          forklaring="Prøv et annet navn eller nummer, eller fjern filteret."
        />
      ) : (
        <Liste merkelapp="Ansatte">
          {treff.map((a) => (
            <Rad
              key={a.id}
              primaer={a.navn}
              sekundaer={stasjonsnavn[a.stasjon_id] ?? '—'}
              status={a.ansatt_nr ? undefined : (
                <Status nivaa="handling">Mangler nummer</Status>
              )}
              metadata={<AnsattnummerFelt id={a.id} nummer={a.ansatt_nr} />}
              handlinger={<Deaktiver id={a.id} navn={a.navn} />}
            />
          ))}
        </Liste>
      )}
    </>
  )
}

/**
 * Deaktivering, bak et steg.
 *
 * Handlingen er den samme som før — samme serverhandling, samme felt,
 * samme myke sletting. Det som er endret er at den ikke lenger står som
 * en knapp på hver rad. To trykk, og det andre sier hvem det gjelder:
 * en «Deaktiver»-knapp uten navn i seg er lett å treffe på feil rad.
 */
function Deaktiver({ id, navn }: { id: string; navn: string }) {
  const [spor, settSpor] = useState(false)

  if (!spor) {
    return (
      <Knapp
        variant="ghost"
        liten
        onClick={() => settSpor(true)}
        aria-label={`Deaktiver ${navn}`}
      >
        Deaktiver
      </Knapp>
    )
  }

  return (
    <form action={deaktiverAnsatt} className="sq-bekreft">
      <input type="hidden" name="id" value={id} />
      <Knapp variant="destruktiv" liten type="submit">
        Bekreft
      </Knapp>
      <Knapp variant="ghost" liten onClick={() => settSpor(false)}>
        Avbryt
      </Knapp>
    </form>
  )
}
