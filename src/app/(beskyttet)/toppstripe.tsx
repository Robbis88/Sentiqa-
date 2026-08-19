import Link from 'next/link'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import type { Brukerrolle } from '@/lib/auth/typer'
import { erLeder } from '@/lib/auth/roller'
import { visVelger } from '@/lib/stasjonsvalg'
import type { Stasjonskontekst as Kontekst } from '@/lib/stasjonskontekst'
import { Kommandopalett } from './kommandopalett'
import { Stasjonskontekst } from './stasjonskontekst'

// =====================================================================
// Toppstripen.
//
// INNEHOLDER BARE DET SOM FINNES. Ingen knapp her er en plassholder for
// noe som skal komme — en knapp som ikke gjør noe lærer folk å ignorere
// knapper.
//
// Kommandopaletten er ikke ny og er ikke bygget her. Den har ligget i
// systemet hele tiden, søker i navigasjonen og kan sende et helt
// spørsmål videre til assistenten. Den står igjen fordi den virker.
//
// Stasjonskonteksten vises kun når det finnes noe å velge mellom.
// Butikksjefen med én stasjon får ingen velger — en nedtrekksliste med
// ett valg ber om en beslutning som ikke finnes.
// =====================================================================

type Props = {
  rolle: Brukerrolle
  navn: string
  uleste: number
  kontekst: Kontekst
  /** Punktene kommandopaletten kan hoppe til. */
  menypunkter: { sti: string; tekst: string; gruppe: string }[]
}

export function Toppstripe({ rolle, navn, uleste, kontekst, menypunkter }: Props) {
  return (
    <header className="toppstripe">
      {erLeder(rolle) && <Kommandopalett punkter={menypunkter} />}

      {visVelger(kontekst.stasjoner, kontekst.tillatAlle) && (
        <Stasjonskontekst
          stasjoner={kontekst.stasjoner}
          valgt={kontekst.valgt}
          tillatAlle={kontekst.tillatAlle}
        />
      )}

      <span className="bruker">
        {navn}
        <span className="rolle-pip">{ROLLE_ETIKETT[rolle]}</span>
      </span>

      <div className="topp-hoyre">
        <Link href="/varsler" className="klokke-lenke" aria-label="Varsler">
          🔔
          {uleste > 0 && <span className="varsel-teller">{uleste}</span>}
        </Link>
        <Link
          href="/sikkerhet"
          className="klokke-lenke"
          aria-label="Sikkerhet"
          title="To-faktor / sikkerhet"
        >
          🔒
        </Link>
        <form action={loggUt}>
          <button type="submit" className="logg-ut">Logg ut</button>
        </form>
      </div>
    </header>
  )
}
