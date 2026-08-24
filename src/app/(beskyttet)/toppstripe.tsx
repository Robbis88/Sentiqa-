import Link from 'next/link'
import { loggUt } from '@/lib/auth/handlinger'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import type { Brukerrolle } from '@/lib/auth/typer'
import { erLeder } from '@/lib/auth/roller'
import { visVelger } from '@/lib/stasjonsvalg'
import type { Stasjonskontekst as Kontekst } from '@/lib/stasjonskontekst'
import { Kommandopalett } from './kommandopalett'
import { Stasjonskontekst } from './stasjonskontekst'
import { Bjelle, Laas } from './ikoner'

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
//
// TRE SONER, IKKE FIRE SØSKEN. Stripa var `display: flex` med
// `space-between` og fire barn — og ingen `gap`. Hierarkiet oppstod
// dermed av innholdets bredde: stasjonsteksten kunne støte rett inntil
// brukernavnet, og på skjermbildet fra 2026-08-24 sto det «4185 St1
// DaleRobert» som ett ord.
//
// Nå: søk til venstre, stasjonskontekst i midten, bruker og handlinger
// til høyre. Sonene har faste roller uansett hva som er i dem — er
// søket eller velgeren borte for denne rollen, blir høyre stående
// høyre.
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
      <div className="topp-sone topp-venstre">
        {erLeder(rolle) && <Kommandopalett punkter={menypunkter} />}
      </div>

      <div className="topp-sone topp-midt">
        {visVelger(kontekst.stasjoner, kontekst.tillatAlle) && (
          <Stasjonskontekst
            stasjoner={kontekst.stasjoner}
            valgt={kontekst.valgt}
            tillatAlle={kontekst.tillatAlle}
          />
        )}
      </div>

      <div className="topp-sone topp-hoyre">
        <span className="bruker">
          {/* Bare navnet kortes ned ved trangt vindu. Rollemerket er
              kort og må stå helt — et halvt «Butikkssj» sier mindre enn
              ingenting. */}
          <span className="brukernavn">{navn}</span>
          <span className="rolle-pip">{ROLLE_ETIKETT[rolle]}</span>
        </span>
        {/* Tallet står i aria-label, ikke bare som et badge: en
            skjermleser som bare sier «Varsler» utelater akkurat det som
            gjør at man går dit. */}
        <Link
          href="/varsler"
          className="klokke-lenke"
          aria-label={uleste > 0 ? `Varsler — ${uleste} uleste` : 'Varsler'}
          // Laasen hadde `title`, bjella ikke. Med musa fikk man
          // forklaring paa det ene ikonet og ikke det andre.
          title={uleste > 0 ? `Varsler — ${uleste} uleste` : 'Varsler'}
        >
          <Bjelle />
          {uleste > 0 && <span className="varsel-teller">{uleste}</span>}
        </Link>
        <Link
          href="/sikkerhet"
          className="klokke-lenke"
          aria-label="Sikkerhet"
          title="To-faktor / sikkerhet"
        >
          <Laas />
        </Link>
        <form action={loggUt}>
          <button type="submit" className="logg-ut">Logg ut</button>
        </form>
      </div>
    </header>
  )
}
