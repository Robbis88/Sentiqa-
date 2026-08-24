import type { Brukerrolle } from '@/lib/auth/typer'
import { erLeder } from '@/lib/auth/roller'
import type { Stasjonskontekst as Kontekst } from '@/lib/stasjonskontekst'
import { Sidemeny } from './sidemeny'
import { Toppstripe } from './toppstripe'
import { Fanerad } from './fanerad'
import { AiBoble } from './ai-boble'

// =====================================================================
// Desktop-skallet.
//
// Lå i layout.tsx sammen med tilgangskontroll, to-faktor-gate,
// stasjonsoppslag og nettbrettforgreningen. Skilt ut fordi de to
// tingene har ulik levetid: gaten endres når sikkerhetskravene endres,
// skallet endres når designet gjør det. Blandet i én fil måtte man lese
// begge for å endre den ene.
//
// NETTBRETTET KOMMER ALDRI HIT. Forgreningen ligger i layout.tsx og skal
// bli der: nettbrettet har egen informasjonsarkitektur, ikke en smalere
// utgave av denne. Se TabletSkall.
// =====================================================================

type Seksjon = { tittel: string; punkter: { sti: string; tekst: string }[] }

type Props = {
  /** Nøkler den lagrede AI-samtalen, saa den ikke foelger med til neste bruker. */
  brukerId: string
  rolle: Brukerrolle
  navn: string
  uleste: number
  kontekst: Kontekst
  seksjoner: Seksjon[]
  children: React.ReactNode
}

export function Appskall({
  brukerId, rolle, navn, uleste, kontekst, seksjoner, children,
}: Props) {
  const menypunkter = seksjoner.flatMap((s) =>
    s.punkter.map((p) => ({ ...p, gruppe: s.tittel })))

  return (
    <div className="skall">
      <Sidemeny seksjoner={seksjoner} />

      <div className="hoved">
        <Toppstripe
          rolle={rolle}
          navn={navn}
          uleste={uleste}
          kontekst={kontekst}
          menypunkter={menypunkter}
        />
        {/* Landemerket heter noe. Med to nav-elementer på siden — menyen
            og fanene — er «navigasjon» to ganger ubrukelig i en
            skjermleserliste. */}
        <main className="innhold" id="innhold">
          <Fanerad rolle={rolle} />
          {children}
        </main>
      </div>

      {erLeder(rolle) && <AiBoble navn={navn.split(' ')[0]} brukerId={brukerId} />}
    </div>
  )
}
